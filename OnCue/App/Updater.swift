import SwiftUI
import AppKit
import Security
import OnCueCore

/// Checks GitHub Releases for a newer OnCue and offers it. Never checks, downloads or installs
/// while a window is in Live Mode. Installs only a copy signed by the same Apple team as this
/// one and accepted by Gatekeeper (notarised); otherwise it offers to open the DMG instead.
final class Updater: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AvailableUpdate)
        case downloading(AvailableUpdate, Double)
        case installing(AvailableUpdate)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published var panelOpen = false
    private var lastCheck: Date?
    private var timer: Timer?
    private var session: URLSession?
    private var downloading: AvailableUpdate?
    private var window: NSWindow?

    static var live: Bool { LiveLock.holder != nil }

    var current: AppVersion {
        let info = Bundle.main.infoDictionary ?? [:]
        let build = Int(info["CFBundleVersion"] as? String ?? "") ?? 0
        return AppVersion(info["CFBundleShortVersionString"] as? String ?? "0", build: build) ?? AppVersion("0")!
    }

    /// Starts the background checks (at launch, then every half hour it decides whether 6 hours
    /// have passed). The first check waits a minute so launching stays quick.
    func start() {
        guard timer == nil, !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--") }) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.tick() }
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        let profile = MachineProfileModel.shared.profile
        guard UpdateCheck.shouldCheck(lastCheck: lastCheck, now: Date(), live: Self.live, enabled: profile.checkForUpdates) else { return }
        check(manual: false)
    }

    /// Asks GitHub for the latest release. A manual check always shows the result; a background
    /// check only speaks up when there is something new (and not skipped).
    func check(manual: Bool) {
        if case .downloading = state { showPanel(); return }
        if Self.live {
            if manual { state = .failed("Updates wait until you leave Live Mode."); showPanel() }
            return
        }
        lastCheck = Date()
        state = .checking
        if manual { showPanel() }
        var request = URLRequest(url: UpdateCheck.latestReleaseURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("OnCue/\(current)", forHTTPHeaderField: "User-Agent")
        let skipped = manual ? "" : MachineProfileModel.shared.profile.skippedUpdate
        let current = self.current
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let error {
                    self.state = manual ? .failed("Couldn't reach GitHub: \(error.localizedDescription)") : .idle
                } else if code == 404 {
                    self.state = manual ? .upToDate : .idle        // no release published yet
                } else if code != 200 {
                    self.state = manual ? .failed("GitHub answered \(code). Try again later.") : .idle
                } else if let data, let update = UpdateCheck.update(fromRelease: data, current: current, skipped: skipped) {
                    self.state = .available(update)
                    if !Self.live { self.showPanel() }
                } else {
                    self.state = manual ? .upToDate : .idle
                }
            }
        }.resume()
    }

    func skip(_ update: AvailableUpdate) {
        MachineProfileModel.shared.update { $0.skippedUpdate = UpdateCheck.skipKey(update) }
        state = .idle
        closePanel()
    }

    func download(_ update: AvailableUpdate) {
        guard !Self.live else { state = .failed("Updates wait until you leave Live Mode."); return }
        downloading = update
        state = .downloading(update, 0)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        session.downloadTask(with: update.dmgURL).resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let u = downloading, totalBytesExpectedToWrite > 0 else { return }
        state = .downloading(u, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let u = downloading else { return }
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("OnCue/Updates", isDirectory: true)
        let dmg = folder.appendingPathComponent(u.dmgName)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: dmg)
            try FileManager.default.moveItem(at: location, to: dmg)
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                throw UpdateError("The download failed (\(http.statusCode)).")
            }
            state = .installing(u)
            let current = Bundle.main.bundleURL
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try UpdateInstaller.prepare(dmg: dmg, replacing: current) }
                DispatchQueue.main.async { self.finish(result, update: u, dmg: dmg) }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { state = .failed("The download stopped: \(error.localizedDescription)") }
        session.finishTasksAndInvalidate()
    }

    private func finish(_ result: Result<UpdateInstaller.Prepared, Error>, update: AvailableUpdate, dmg: URL) {
        switch result {
        case .success(let prepared):
            guard !Self.live else {
                try? FileManager.default.removeItem(at: prepared.staged)
                state = .failed("Live Mode started during the download, so the update was not installed. Check again after the show.")
                return
            }
            do {
                try UpdateInstaller.relaunch(with: prepared)
                NSApp.terminate(nil)
            } catch {
                state = .failed(error.localizedDescription)
            }
        case .failure(let error):
            state = .failed(error.localizedDescription + " You can open the downloaded DMG and install it by hand.")
            downloadedDMG = dmg
        }
    }

    /// Set when the automatic install was refused, so the person can still open the DMG.
    @Published private(set) var downloadedDMG: URL?

    func openDownloadedDMG() {
        if let dmg = downloadedDMG { NSWorkspace.shared.open(dmg) }
    }

    // MARK: Panel

    func showPanel() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420), styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "Software Update"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: UpdateView(updater: self))
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            self?.window = nil
        }
    }

    func closePanel() { window?.close() }
}

struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Verifies a downloaded DMG and swaps the app after OnCue quits.
enum UpdateInstaller {
    struct Prepared {
        /// The new app copied next to the running one, ready to swap in.
        let staged: URL
        let target: URL
    }

    static func prepare(dmg: URL, replacing target: URL) throws -> Prepared {
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("OnCueUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        let app = mount.appendingPathComponent("OnCue.app")
        guard FileManager.default.fileExists(atPath: app.path) else { throw UpdateError("The DMG has no OnCue.app.") }

        // Same maker as this copy: a valid signature from the same Apple team, same bundle id.
        guard let myTeam = teamID(of: Bundle.main.bundleURL) else {
            throw UpdateError("This copy of OnCue isn't signed with a Developer ID, so it can't check who made the update.")
        }
        guard let theirTeam = teamID(of: app), theirTeam == myTeam else {
            throw UpdateError("The update isn't signed by the same developer as this copy, so it was not installed.")
        }
        guard Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError("The DMG holds a different app.")
        }
        // Notarised: Gatekeeper accepts it.
        do { try run("/usr/sbin/spctl", ["--assess", "--type", "execute", app.path]) }
        catch { throw UpdateError("Gatekeeper didn't accept the update (it may not be notarised).") }

        let folder = target.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw UpdateError("OnCue can't write to \(folder.path).")
        }
        let staged = folder.appendingPathComponent(".OnCue-update.app")
        try? FileManager.default.removeItem(at: staged)
        try run("/usr/bin/ditto", [app.path, staged.path])
        return Prepared(staged: staged, target: target)
    }

    /// Starts a small script that waits for OnCue to quit (2 minutes at most), moves the old
    /// copy to the Trash, puts the new one in its place and opens it.
    static func relaunch(with p: Prepared) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first?.path ?? (NSHomeDirectory() + "/.Trash")
        let old = "\(trash)/OnCue (previous) \(Int(Date().timeIntervalSince1970)).app"
        let script = """
        for i in $(seq 1 240); do kill -0 \(pid) 2>/dev/null || break; sleep 0.5; done
        if kill -0 \(pid) 2>/dev/null; then rm -rf \(q(p.staged.path)); exit 1; fi
        mv \(q(p.target.path)) \(q(old)) && mv \(q(p.staged.path)) \(q(p.target.path)) || { [ -d \(q(old)) ] && mv \(q(old)) \(q(p.target.path)); exit 1; }
        open \(q(p.target.path))
        """
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("oncue-update-\(pid).sh")
        try script.write(to: file, atomically: true, encoding: .utf8)
        try run("/bin/sh", ["-c", "nohup /bin/sh \(q(file.path)) >/dev/null 2>&1 &"])
    }

    static func teamID(of url: URL) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(code, flags, nil) == errSecSuccess else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        let team = dict[kSecCodeInfoTeamIdentifier as String] as? String
        return (team?.isEmpty ?? true) ? nil : team
    }

    private static func q(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        try p.run()
        p.waitUntilExit()
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard p.terminationStatus == 0 else { throw UpdateError("\(URL(fileURLWithPath: tool).lastPathComponent) failed: \(text.prefix(200))") }
        return text
    }
}

/// Help › Software Update: what's new and the choice to install, later or skip.
struct UpdateView: View {
    @ObservedObject var updater: Updater

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline).font(.ocHeading).foregroundStyle(Gallery.ink)
                    Text("You have OnCue \(updater.current) (\(updater.current.build)).").font(.ocMeta).foregroundStyle(Gallery.dim)
                }
            }
            content
        }
        .padding(Space.l)
        .frame(width: 520, height: 420, alignment: .topLeading)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    private var headline: String {
        switch updater.state {
        case .idle, .checking: return "Checking for updates…"
        case .upToDate: return "OnCue is up to date"
        case .available(let u): return "OnCue \(u.version) is available"
        case .downloading(let u, _): return "Downloading OnCue \(u.version)…"
        case .installing(let u): return "Checking and installing OnCue \(u.version)…"
        case .failed: return "Update not installed"
        }
    }

    @ViewBuilder private var content: some View {
        switch updater.state {
        case .available(let u):
            ScrollView {
                Text(u.notes.isEmpty ? "No release notes." : u.notes).font(.ocBody).foregroundStyle(Gallery.dim)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .padding(Space.s)
            .background(Gallery.well, in: RoundedRectangle(cornerRadius: Radius.m))
            Text("OnCue quits as usual (it asks about anything unsaved), swaps in the new version and reopens. The old copy goes to the Trash.")
                .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Skip This Version") { updater.skip(u) }.buttonStyle(QuietButtonStyle())
                Spacer()
                Button("Later") { updater.closePanel() }.buttonStyle(QuietButtonStyle())
                Button("Install and Relaunch") { updater.download(u) }
                    .buttonStyle(QuietButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
                    .disabled(Updater.live)
            }
            if Updater.live {
                Text("Leave Live Mode to install.").font(.ocMeta).foregroundStyle(Gallery.amber)
            }
        case .downloading(_, let progress):
            ProgressView(value: progress).tint(Gallery.selection)
            Spacer()
        case .failed(let message):
            Text(message).font(.ocBody).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            Spacer()
            HStack {
                if updater.downloadedDMG != nil {
                    Button("Open the DMG") { updater.openDownloadedDMG() }.buttonStyle(QuietButtonStyle())
                }
                Spacer()
                Button("Try Again") { updater.check(manual: true) }.buttonStyle(QuietButtonStyle())
                Button("Close") { updater.closePanel() }.buttonStyle(QuietButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
            }
        case .upToDate:
            Spacer()
            HStack { Spacer(); Button("OK") { updater.closePanel() }.buttonStyle(QuietButtonStyle(prominent: true)).keyboardShortcut(.defaultAction) }
        default:
            ProgressView().controlSize(.small)
            Spacer()
        }
    }
}

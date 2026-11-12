import AppKit
import OnCueCore

/// Launch check used by CI: `OnCue --smoke-test <folder>`.
///
/// Runs inside the real app, after launch, through NSDocumentController (the same document system
/// SwiftUI's DocumentGroup uses for File > New, Save and Open):
///   1. the machine profile is created in <folder>/profile,
///   2. a new untitled project window opens,
///   3. the project is saved to <folder>/smoke.oncue (a package with project.json and Backups/),
///   4. the window is closed,
///   5. the file is reopened in a window, and its contents are checked.
/// Results go to stdout and <folder>/smoke-result.txt. Exit code 0 = pass.
enum SmokeTest {
    private static var lines: [String] = []
    private static var folder: URL!

    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--smoke-test"), i + 1 < args.count else { return }
        folder = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { finish(false, "timed out after 90 s") }
        log("app launched (pid \(ProcessInfo.processInfo.processIdentifier))")

        // Give DocumentGroup a moment to finish its own launch work.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { step1() }
    }

    private static func step1() {
        let profileDir = folder.appendingPathComponent("profile", isDirectory: true)
        let store = MachineProfileStore(directory: profileDir)
        guard FileManager.default.fileExists(atPath: store.fileURL.path) else {
            return finish(false, "machine profile was not created")
        }
        log("machine profile created at \(store.fileURL.path)")

        let dc = NSDocumentController.shared
        let doc: NSDocument
        do {
            doc = try dc.openUntitledDocumentAndDisplay(true)
        } catch {
            return finish(false, "could not create a new project: \(error.localizedDescription)")
        }
        let typeName = doc.fileType ?? dc.defaultType ?? "com.nishanpani.oncue.show"
        log("new project opened (type \(typeName), windows: \(doc.windowControllers.count))")

        let url = folder.appendingPathComponent("smoke.oncue")
        try? FileManager.default.removeItem(at: url)
        doc.save(to: url, ofType: typeName, for: .saveAsOperation) { error in
            if let error { return finish(false, "save failed: \(error.localizedDescription)") }
            log("saved to \(url.path)")
            doc.close()
            log("window closed")
            step2(url)
        }
    }

    private static func step2(_ url: URL) {
        let saved: Project
        do {
            guard case .project(let p) = try ProjectPackage.read(at: url) else {
                return finish(false, "saved file is not a project")
            }
            saved = p
        } catch {
            return finish(false, "saved file could not be read back: \(error.localizedDescription)")
        }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let backups = (try? FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent("Backups").path))?.count ?? 0
        guard isDir.boolValue, saved.schemaVersion == Project.currentSchemaVersion, saved.sceneCount >= 1,
              saved.cameras.count >= 1, backups >= 1 else {
            return finish(false, "saved project has unexpected contents (package \(isDir.boolValue), format \(saved.schemaVersion), scenes \(saved.sceneCount), cameras \(saved.cameras.count), backups \(backups))")
        }
        log("saved project verified: package, format \(saved.schemaVersion), \(saved.playlists.count) playlist(s), \(saved.sceneCount) scene(s), \(saved.cameras.count) camera(s), \(backups) backup(s) inside, \(saved.frameRate.label) fps")

        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { doc, _, error in
            if let error { return finish(false, "reopen failed: \(error.localizedDescription)") }
            guard let doc else { return finish(false, "reopen returned no document") }
            log("reopened \(doc.fileURL?.lastPathComponent ?? "?") (windows: \(doc.windowControllers.count))")
            doc.close()
            finish(true, "create, save, close and reopen all succeeded")
        }
    }

    private static func log(_ s: String) {
        let line = "[smoke] \(s)"
        lines.append(line)
        print(line)
        fflush(stdout)
    }

    private static func finish(_ ok: Bool, _ message: String) {
        log((ok ? "PASS: " : "FAIL: ") + message)
        let report = lines.joined(separator: "\n") + "\n"
        try? report.write(to: folder.appendingPathComponent("smoke-result.txt"), atomically: true, encoding: .utf8)
        exit(ok ? 0 : 1)
    }
}

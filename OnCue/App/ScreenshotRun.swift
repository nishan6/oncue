import AppKit
import OnCueCore

/// `OnCue --screenshots <folder>`: writes the sample production to disk, opens it in two real
/// windows (one on a song, one on a segment), and saves PNGs of each window. Used by CI to show
/// the actual interface, rendered by the app itself.
enum ScreenshotRun {
    private static var folder: URL!

    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--screenshots"), i + 1 < args.count else { return }
        folder = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { finish("timed out", ok: false) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { openShows() }
    }

    /// Window file names and the images they produce.
    private static let shots: [(file: String, image: String)] = [
        ("Live at the Arena.oncue", "workspace-timeline.png"),
        ("Live at the Arena (split).oncue", "workspace-split.png"),
        ("Live at the Arena (list).oncue", "workspace-list.png"),
    ]

    private static func openShows() {
        // Timeline: the opener, shot 6 selected (blue ring; the next shot carries a green bar).
        let timeline = Show.sample()
        let song = timeline.items[0].id
        WorkspaceModel.seedState(showID: timeline.id, itemID: song,
                                 shotIDs: [timeline.shotRows(forItem: song)[5].id], editor: .timeline)

        // Timeline and list: the talk break, timed in seconds, nothing selected (item inspector).
        let split = Show.sample()
        WorkspaceModel.seedState(showID: split.id, itemID: split.items[2].id, shotIDs: [], editor: .split)

        // List: the ballad, shot 3 selected.
        let list = Show.sample()
        let ballad = list.items[1].id
        WorkspaceModel.seedState(showID: list.id, itemID: ballad,
                                 shotIDs: [list.shotRows(forItem: ballad)[2].id], editor: .list)

        let urls = shots.map { folder.appendingPathComponent($0.file) }
        do {
            for (show, url) in zip([timeline, split, list], urls) { try ShowFileIO.write(show, to: url) }
        } catch {
            return finish("could not write sample shows: \(error.localizedDescription)", ok: false)
        }

        open(urls[0]) {
            open(urls[1]) {
                open(urls[2]) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) { capture() }
                }
            }
        }
    }

    private static func open(_ url: URL, then next: @escaping () -> Void) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { doc, _, error in
            if let error { return finish("open failed: \(error.localizedDescription)", ok: false) }
            if let window = doc?.windowControllers.first?.window {
                window.setFrame(NSRect(x: 40, y: 40, width: 1440, height: 900), display: true)
            }
            next()
        }
    }

    private static func capture() {
        let docs = NSDocumentController.shared.documents
        let windows = docs.compactMap { $0.windowControllers.first?.window }
        var saved = 0
        for doc in docs {
            guard let window = doc.windowControllers.first?.window else { continue }
            window.makeKeyAndOrderFront(nil)
            guard let view = window.contentView?.superview ?? window.contentView else { continue }
            view.layoutSubtreeIfNeeded()
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            let file = doc.fileURL?.lastPathComponent ?? ""
            let name = shots.first { $0.file == file }?.image ?? "workspace-\(saved).png"
            do {
                try png.write(to: folder.appendingPathComponent(name))
                saved += 1
                print("[screenshots] saved \(name) (\(Int(view.bounds.width))x\(Int(view.bounds.height)))")
            } catch {
                print("[screenshots] could not save \(name): \(error.localizedDescription)")
            }
        }
        finish("saved \(saved) of \(windows.count) window(s)", ok: saved > 0)
    }

    private static func finish(_ message: String, ok: Bool) {
        print("[screenshots] \(ok ? "PASS" : "FAIL"): \(message)")
        fflush(stdout)
        exit(ok ? 0 : 1)
    }
}

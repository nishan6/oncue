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

    private static func openShows() {
        // Song view: the opener, with shot 6 selected (red = this shot, green = next).
        let songShow = Show.sample()
        let song = songShow.items[0].id
        let songRows = songShow.shotRows(forItem: song)
        WorkspaceModel.seedState(showID: songShow.id, itemID: song, shotIDs: [songRows[5].id])

        // Segment view: the talk break, nothing selected (shows the item inspector).
        let segShow = Show.sample()
        let seg = segShow.items[2].id
        WorkspaceModel.seedState(showID: segShow.id, itemID: seg, shotIDs: [])

        let songURL = folder.appendingPathComponent("Live at the Arena.oncue")
        let segURL = folder.appendingPathComponent("Live at the Arena (segment).oncue")
        do {
            try ShowFileIO.write(songShow, to: songURL)
            try ShowFileIO.write(segShow, to: segURL)
        } catch {
            return finish("could not write sample shows: \(error.localizedDescription)", ok: false)
        }

        open(songURL) {
            open(segURL) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { capture() }
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
            let isSegment = doc.fileURL?.lastPathComponent.contains("(segment)") ?? false
            let name = isSegment ? "workspace-segment.png" : "workspace-song.png"
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

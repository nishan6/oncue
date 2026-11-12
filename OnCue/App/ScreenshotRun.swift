import SwiftUI
import AppKit
import AVFoundation
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
        ("Live at the Arena (live).oncue", "live-mode.png"),
        ("Live at the Arena (compact).oncue", "workspace-compact.png"),
    ]

    private static func openShows() {
        // Timeline: the opener, shot 6 selected (blue ring; the next shot carries a green bar).
        var timeline = Show.sample()
        let song = timeline.items[0].id
        // A generated song file under the timeline, so the media lane is in the picture.
        if let audio = makeDemoAudio(seconds: timeline.runLength(forItem: song) ?? 60) {
            timeline.updateItem(song) { $0.media = ItemMedia(path: audio.path, kind: .audio, offset: 0) }
        }
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

        // Live Mode: the opener with shot 6 on air.
        let live = Show.sample()
        WorkspaceModel.seedState(showID: live.id, itemID: live.items[0].id, shotIDs: [], editor: .timeline)
        WorkspaceModel.openLive[live.id] = 5

        // A smaller window: the timeline on the segment, with a shot selected.
        let compact = Show.sample()
        let seg = compact.items[2].id
        WorkspaceModel.seedState(showID: compact.id, itemID: seg,
                                 shotIDs: [compact.shotRows(forItem: seg)[3].id], editor: .timeline)

        renderExports(Show.sample())

        let urls = shots.map { folder.appendingPathComponent($0.file) }
        do {
            for (show, url) in zip([timeline, split, list, live, compact], urls) { try ShowFileIO.write(show, to: url) }
        } catch {
            return finish("could not write sample shows: \(error.localizedDescription)", ok: false)
        }

        open(urls[0]) {
            open(urls[1]) {
                open(urls[2]) {
                    open(urls[3]) {
                        open(urls[4], size: NSSize(width: 1180, height: 760)) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { capture() }
                        }
                    }
                }
            }
        }
    }

    private static func open(_ url: URL, size: NSSize = NSSize(width: 1440, height: 900), then next: @escaping () -> Void) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { doc, _, error in
            if let error { return finish("open failed: \(error.localizedDescription)", ok: false) }
            if let window = doc?.windowControllers.first?.window {
                window.setFrame(NSRect(x: 40, y: 40, width: size.width, height: size.height), display: true)
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
        let windowsMessage = "saved \(saved) of \(windows.count) window(s)"
        captureSheets { sheets in
            finish(windowsMessage + ", \(sheets) sheet(s)", ok: saved > 0)
        }
    }

    /// The sheets and Settings, each hosted in its own window with a sample show, captured the same way.
    private static var sheetWindows: [NSWindow] = []
    private static var sheetModel: WorkspaceModel?

    private static func captureSheets(done: @escaping (Int) -> Void) {
        var show = Show.sample()
        show.addOSCTarget(name: "Resolume")
        show.addMonitor(name: "Backstage", kind: .gallery)
        let riser = show.addMonitor(name: "Camera riser", kind: .cameras)
        let firstThree = show.sortedCameras.prefix(3).map(\.id)
        show.updateMonitor(riser) { $0.cameraIDs = firstThree }
        show.settings.nightLabel = "Night 2, Pune"
        show.saveVersion(name: "After rehearsal")
        show.renameItem(show.items[1].id, to: show.items[1].title + " ")
        show.saveVersion(name: "Before Live, Night 1", automatic: true)
        let model = WorkspaceModel()
        model.attach(document: .constant(ShowDocument(show: show)), undoManager: nil)
        sheetModel = model
        let sheets: [(String, AnyView, NSSize)] = [
            ("sheet-show-setup.png", AnyView(ShowSetupView(show: show, model: model, tab: .monitors)), NSSize(width: 860, height: 640)),
            ("sheet-preshow-check.png", AnyView(PreShowCheckView(show: show, model: model)), NSSize(width: 640, height: 620)),
            ("sheet-export.png", AnyView(ExportView(show: show, model: model)), NSSize(width: 480, height: 470)),
            ("sheet-tour.png", AnyView(TourView(show: show, model: model)), NSSize(width: 980, height: 640)),
            ("sheet-versions.png", AnyView(VersionsView(show: show, model: model)), NSSize(width: 560, height: 520)),
            ("sheet-settings.png", AnyView(MachineProfileView().environmentObject(MachineProfileModel())), NSSize(width: 540, height: 680)),
        ]
        for (k, (_, view, size)) in sheets.enumerated() {
            let w = NSWindow(contentRect: NSRect(x: CGFloat(40 + k * 20), y: CGFloat(40 + k * 20), width: size.width, height: size.height),
                             styleMask: [.titled], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
            w.orderFront(nil)
            sheetWindows.append(w)
        }
        // Let the pre-show check and the tour's log scan finish.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            var saved = 0
            for (w, sheet) in zip(sheetWindows, sheets) {
                guard let view = w.contentView else { continue }
                view.layoutSubtreeIfNeeded()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]),
                   (try? png.write(to: folder.appendingPathComponent(sheet.0))) != nil {
                    saved += 1
                    print("[screenshots] saved \(sheet.0)")
                }
            }
            done(saved)
        }
    }

    private static func finish(_ message: String, ok: Bool) {
        print("[screenshots] \(ok ? "PASS" : "FAIL"): \(message)")
        fflush(stdout)
        exit(ok ? 0 : 1)
    }

    /// The printable exports of the sample show: the PDFs themselves and their first pages as PNGs.
    private static func renderExports(_ show: Show) {
        let exports: [(String, Data)] = [
            ("export-camera-script", show.cameraScriptPDF(paper: .a4)),
            ("export-call-sheets", show.callSheetsPDF(paper: .a4)),
        ]
        for (name, data) in exports {
            try? data.write(to: folder.appendingPathComponent(name + ".pdf"))
            guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider),
                  let page = doc.page(at: 1) else { continue }
            let box = page.getBoxRect(.mediaBox)
            let scale: CGFloat = 2
            guard let ctx = CGContext(data: nil, width: Int(box.width * scale), height: Int(box.height * scale), bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: box.width * scale, height: box.height * scale))
            ctx.scaleBy(x: scale, y: scale)
            ctx.drawPDFPage(page)
            guard let image = ctx.makeImage() else { continue }
            let rep = NSBitmapImageRep(cgImage: image)
            try? rep.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name + ".png"))
        }
        MainActor.assumeIsolated { renderPlot(show) }
        try? show.scriptCSV().write(to: folder.appendingPathComponent("export-script.csv"), atomically: true, encoding: .utf8)
        if let edl = show.markerEDL(itemID: show.items[0].id, fps: 25) {
            try? edl.write(to: folder.appendingPathComponent("export-markers.edl"), atomically: true, encoding: .utf8)
        }
    }

    /// The camera plot with every camera placed and a few turned, as the editor draws it.
    @MainActor private static func renderPlot(_ show: Show) {
        var s = show
        s.placeRemainingCameras()
        let cams = s.sortedCameras
        if cams.count >= 3 {
            s.placeCamera(cams[1].id, x: 0.15, y: 0.4)
            s.updatePlotMarker(cams[1].id) { $0.angle = 60; $0.note = "Pit left"; $0.lens = "Ronin" }
            s.placeCamera(cams[2].id, x: 0.85, y: 0.4)
            s.updatePlotMarker(cams[2].id) { $0.angle = 300; $0.note = "Pit right" }
        }
        let canvas = PlotCanvas(show: s, plot: s.plot, selected: cams.first?.id, dragging: nil, turning: nil)
            .frame(width: 1100, height: 700)
            .background(Gallery.panel)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        if let cg = renderer.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) {
            try? png.write(to: folder.appendingPathComponent("export-plot.png"))
        }
    }

    /// A WAV with a pulsing, swelling tone: drum-like hits on every beat at 120 BPM.
    private static func makeDemoAudio(seconds: Double) -> URL? {
        let url = folder.appendingPathComponent("demo-song.wav")
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1),
              let file = try? AVAudioFile(forWriting: url, settings: format.settings) else { return nil }
        let frames = AVAudioFrameCount(seconds * 22_050)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let out = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / 22_050
            let beat = t.truncatingRemainder(dividingBy: 0.5)
            let hit = exp(-beat * 18)
            let swell = 0.35 + 0.3 * sin(t / seconds * .pi * 3).magnitude
            out[i] = Float((hit * 0.6 + swell * 0.4) * sin(t * 2 * .pi * 110) * 0.9)
        }
        try? file.write(from: buffer)
        return url
    }
}

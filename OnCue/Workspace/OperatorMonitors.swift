import SwiftUI
import AppKit
import OnCueCore

/// Opens the show's operator monitors as windows: full screen on their display when it is
/// connected, otherwise as an ordinary window on this screen (so a missing display never hides one).
final class MonitorWindows: ObservableObject {
    @Published private(set) var isOpen = false
    private var windows: [NSWindow] = []

    func open(model: WorkspaceModel, engine: EngineController, show: Show) {
        close()
        for (k, monitor) in show.settings.monitors.enumerated() {
            let content = MonitorRoot(monitorID: monitor.id, model: model, engine: engine)
            let host = NSHostingView(rootView: content)
            let window: NSWindow
            if !monitor.screenName.isEmpty, let screen = NSScreen.screens.first(where: { $0.localizedName == monitor.screenName }) {
                window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
                window.setFrame(screen.frame, display: true)
                window.level = .normal
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            } else {
                window = NSWindow(contentRect: NSRect(x: 80 + k * 30, y: 80 + k * 30, width: 1024, height: 600),
                                  styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
                window.title = "\(monitor.name) – \(show.name)"
            }
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(LivePalette.base)
            window.contentView = host
            window.orderFront(nil)
            windows.append(window)
        }
        isOpen = !windows.isEmpty
    }

    func close() {
        windows.forEach { $0.close() }
        windows = []
        isOpen = false
    }
}

/// Reads the live show from the window's model so script changes reach the monitor.
private struct MonitorRoot: View {
    let monitorID: UUID
    @ObservedObject var model: WorkspaceModel
    @ObservedObject var engine: EngineController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let show = model.show
            if let monitor = show.settings.monitors.first(where: { $0.id == monitorID }) {
                MonitorContent(monitor: monitor, show: show, engine: engine, now: context.date)
            } else {
                Text("This monitor was deleted in Show Setup.").font(.ocHeading).foregroundStyle(Gallery.faint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(LivePalette.base)
        .preferredColorScheme(.dark)
    }
}

private struct MonitorContent: View {
    let monitor: MonitorConfig
    let show: Show
    let engine: EngineController
    let now: Date

    var body: some View {
        let status = engine.status
        let snap = show.crewSnapshot(status: status, position: status.position, running: status.positionMoving, scriptVersion: 0, now: now)
        VStack(spacing: 0) {
            MonitorHeader(monitor: monitor, show: show, snap: snap)
            switch monitor.kind {
            case .gallery:
                VStack(spacing: Space.l) {
                    if RundownTiming.applies(to: show) {
                        LiveRundownStrip(timing: RundownTiming(show: show, log: engine.log, itemID: status.itemID, now: now))
                    }
                    NowNextPanels(show: show, item: show.item(status.itemID), cursor: status.cursor, takenAt: status.takenAt,
                                  secondsToNext: status.secondsToNext, now: now)
                    UpcomingStrip(show: show, cursor: status.cursor)
                    Spacer(minLength: 0)
                }
                .padding(Space.xl)
            case .cameras:
                MonitorCameraGrid(show: show, snap: snap,
                                  cameraIDs: monitor.cameraIDs.isEmpty ? show.sortedCameras.map(\.id) : monitor.cameraIDs)
            case .shotlist:
                MonitorShotlist(show: show, snap: snap)
            case .countdown:
                MonitorCountdown(show: show, snap: snap)
            }
        }
    }
}

private struct MonitorHeader: View {
    let monitor: MonitorConfig
    let show: Show
    let snap: CrewSnapshot

    var body: some View {
        HStack(spacing: Space.l) {
            Text(snap.itemTitle).font(.system(size: 26, weight: .bold)).foregroundStyle(Gallery.ink).lineLimit(1)
            if !snap.section.isEmpty {
                Text(snap.section).font(.system(size: 20, weight: .medium)).foregroundStyle(Gallery.dim)
            }
            Spacer()
            if snap.paused {
                Text("PAUSED").font(.system(size: 20, weight: .heavy)).foregroundStyle(Gallery.amber)
            } else if snap.freeMode {
                Text("FREE MODE").font(.system(size: 20, weight: .heavy)).foregroundStyle(Gallery.amber)
            }
            Text(monitor.name).font(.ocMeta).foregroundStyle(Gallery.faint)
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.m)
        .background(LivePalette.panel)
    }
}

/// One tile per camera: big number, tally, countdown to its next shot and what it is.
private struct MonitorCameraGrid: View {
    let show: Show
    let snap: CrewSnapshot
    let cameraIDs: [UUID]

    var body: some View {
        let cams = cameraIDs.compactMap(show.camera)
        let shots = snap.items.first?.shots ?? []
        let nowIndex = shots.firstIndex { $0.id == snap.nowShotID } ?? -1
        let upcoming = Array(shots.dropFirst(nowIndex + 1))
        let columns = cams.count <= 1 ? 1 : (cams.count <= 4 ? 2 : (cams.count <= 9 ? 3 : 4))
        GeometryReader { geo in
            let rows = Int(ceil(Double(max(cams.count, 1)) / Double(columns)))
            let h = (geo.size.height - Space.xl * 2 - CGFloat(rows - 1) * Space.m) / CGFloat(rows)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.m), count: columns), spacing: Space.m) {
                ForEach(cams) { cam in
                    let next = upcoming.first { $0.camera == cam.number }
                    let onAir = snap.program == cam.number
                    let onPreview = !onAir && snap.preview == cam.number
                    MonitorCameraTile(camera: cam, onAir: onAir, onPreview: onPreview, next: next)
                        .frame(height: max(h, 120))
                }
            }
            .padding(Space.xl)
        }
    }
}

private struct MonitorCameraTile: View {
    let camera: Camera
    let onAir: Bool
    let onPreview: Bool
    let next: CrewShot?

    var body: some View {
        GeometryReader { geo in
            let numeral = min(geo.size.height * 0.55, geo.size.width * 0.35)
            HStack(spacing: Space.l) {
                Text("\(camera.number)")
                    .font(Font.cameraNumeral(numeral))
                    .foregroundStyle(camera.swiftUIColor)
                    .minimumScaleFactor(0.5)
                VStack(alignment: .leading, spacing: 6) {
                    Text(onAir ? "ON AIR" : (onPreview ? "STAND BY" : "CLEAR"))
                        .font(.system(size: numeral * 0.28, weight: .heavy))
                        .foregroundStyle(onAir ? Gallery.tally : (onPreview ? Gallery.next : Gallery.faint))
                    Text(camera.displayName + (camera.operatorName.isEmpty ? "" : " · \(camera.operatorName)"))
                        .font(.system(size: numeral * 0.16, weight: .medium)).foregroundStyle(Gallery.dim).lineLimit(1)
                    if let next {
                        Text(next.text.isEmpty ? "Shot \(next.number)" : next.text)
                            .font(.system(size: numeral * 0.17, weight: .semibold)).foregroundStyle(Gallery.ink).lineLimit(2)
                        if let s = next.secondsUntil {
                            Text(clockText(s)).font(.readout(numeral * 0.3, weight: .bold))
                                .foregroundStyle(s < 5 ? Gallery.amber : Gallery.ink)
                        }
                    } else if !onAir {
                        Text("No more shots in this song").font(.system(size: numeral * 0.15)).foregroundStyle(Gallery.faint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Space.l)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
            .background(onAir ? Gallery.tally.opacity(0.14) : LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.l))
            .overlay(RoundedRectangle(cornerRadius: Radius.l)
                .strokeBorder(onAir ? Gallery.tally : (onPreview ? Gallery.next : Color.clear), lineWidth: 6))
        }
    }
}

/// The song's shots, the one on air highlighted and kept in view.
private struct MonitorShotlist: View {
    let show: Show
    let snap: CrewSnapshot

    var body: some View {
        let shots = snap.items.first?.shots ?? []
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(shots, id: \.id) { shot in
                        let cam = shot.camera.flatMap { show.camera(number: $0) }
                        let isNow = shot.id == snap.nowShotID, isNext = shot.id == snap.nextShotID
                        HStack(spacing: Space.l) {
                            Text("\(shot.number)").font(.readout(22)).foregroundStyle(Gallery.faint).frame(width: 50, alignment: .trailing)
                            Text(shot.camera.map(String.init) ?? "–").font(Font.cameraNumeral(30))
                                .foregroundStyle(cam?.swiftUIColor ?? Gallery.faint).frame(width: 70)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shot.text.isEmpty ? (cam?.displayName ?? "No camera") : shot.text)
                                    .font(.system(size: 22, weight: isNow ? .bold : .medium)).foregroundStyle(Gallery.ink)
                                if !shot.note.isEmpty { Text(shot.note).font(.system(size: 17)).foregroundStyle(Gallery.dim) }
                            }
                            Spacer()
                            Text(shot.position).font(.readout(18)).foregroundStyle(Gallery.faint)
                            if let s = shot.secondsUntil {
                                Text(clockText(s)).font(.readout(22, weight: .semibold)).foregroundStyle(Gallery.ink).frame(width: 90, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, Space.l)
                        .background(isNow ? Gallery.tally.opacity(0.18) : (isNext ? Gallery.next.opacity(0.12) : LivePalette.panel),
                                    in: RoundedRectangle(cornerRadius: Radius.m))
                        .overlay(RoundedRectangle(cornerRadius: Radius.m).strokeBorder(isNow ? Gallery.tally : (isNext ? Gallery.next : .clear), lineWidth: 2))
                        .id(shot.id)
                    }
                }
                .padding(Space.xl)
            }
            .onChange(of: snap.nowShotID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.25)) }
            }
            .onAppear { if let id = snap.nowShotID { proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.25)) } }
        }
    }
}

/// The next cut, as large as the screen allows.
private struct MonitorCountdown: View {
    let show: Show
    let snap: CrewSnapshot

    var body: some View {
        let next = snap.items.first?.shots.first { $0.id == snap.nextShotID }
        let cam = next?.camera.flatMap { show.camera(number: $0) }
        GeometryReader { geo in
            VStack(spacing: Space.l) {
                Spacer(minLength: 0)
                Text(next?.secondsUntil.map(clockText) ?? "–")
                    .font(.readout(min(geo.size.height * 0.42, geo.size.width * 0.28), weight: .bold))
                    .foregroundStyle((next?.secondsUntil ?? 99) < 5 ? Gallery.amber : Gallery.ink)
                    .minimumScaleFactor(0.3)
                if let next {
                    HStack(spacing: Space.l) {
                        Text("NEXT").font(.system(size: geo.size.height * 0.06, weight: .heavy)).foregroundStyle(Gallery.next)
                        Text(next.camera.map(String.init) ?? "–").font(Font.cameraNumeral(geo.size.height * 0.12))
                            .foregroundStyle(cam?.swiftUIColor ?? Gallery.faint)
                        Text(next.text.isEmpty ? (cam?.displayName ?? "") : next.text)
                            .font(.system(size: geo.size.height * 0.05, weight: .semibold)).foregroundStyle(Gallery.dim).lineLimit(1)
                    }
                } else {
                    Text("Last shot of this song").font(.system(size: geo.size.height * 0.05)).foregroundStyle(Gallery.faint)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

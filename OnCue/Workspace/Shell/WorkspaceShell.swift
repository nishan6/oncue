import SwiftUI
import AVKit
import OnCueCore

// The edit-mode window: a top bar (production, song navigation, timecode, LIVE), an icon rail
// on the far left that switches the side panel, the side panel itself, the viewer at the top
// right and the song's timeline across the bottom. Panels resize with split views.

/// What the side panel shows. The rail picks one.
enum RailPanel: String, CaseIterable, Identifiable {
    case info, rundown, media, sources, controls, crew, setup
    var id: String { rawValue }

    var title: String {
        switch self {
        case .info: return "Info"
        case .rundown: return "Running Order"
        case .media: return "Media"
        case .sources: return "Sources"
        case .controls: return "Controls"
        case .crew: return "Crew"
        case .setup: return "Show"
        }
    }

    var symbol: String {
        switch self {
        case .info: return "info.circle"
        case .rundown: return "list.number"
        case .media: return "play.rectangle"
        case .sources: return "video"
        case .controls: return "bolt"
        case .crew: return "person.2"
        case .setup: return "gearshape"
        }
    }
}

/// The edit-mode layout.
struct WorkspaceShell: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @State private var rail: RailPanel = .info

    var body: some View {
        VStack(spacing: 0) {
            ShowTopBar(show: show, model: model)
            Rectangle().fill(Deck.seam).frame(height: 1)
            HStack(spacing: 0) {
                SideRail(selection: $rail)
                Rectangle().fill(Deck.seam).frame(width: 1)
                HSplitView {
                    SidePanel(show: show, model: model, panel: rail)
                        .frame(minWidth: 300, idealWidth: 380, maxWidth: 560)
                    VSplitView {
                        ViewerPanel(show: show, model: model)
                            .frame(minHeight: 150, idealHeight: 300)
                        Group {
                            if let item = show.item(model.selectedItemID) {
                                ItemEditorView(show: show, item: item, model: model)
                                    .id(item.id)
                            } else {
                                EmptyProductionView(model: model, hasItems: !show.items.isEmpty)
                            }
                        }
                        .frame(minHeight: 300)
                    }
                    .frame(minWidth: 560)
                }
            }
        }
        .background(Deck.base)
        // Selecting a shot or cue brings the Info panel back, so its properties are in view.
        .onChange(of: model.selectedShotIDs) { _, ids in if !ids.isEmpty && rail != .info { rail = .info } }
        .onChange(of: model.selectedCueID) { _, id in if id != nil && rail != .info { rail = .info } }
    }
}

// MARK: - Top bar

/// Production name and frame rate on the left; song navigation in the middle; the song's
/// timecode and length, and the LIVE button, on the right.
struct ShowTopBar: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let items = show.items
        let index = items.firstIndex { $0.id == model.selectedItemID }
        let item = show.item(model.selectedItemID)
        ZStack {
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(show.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Deck.ink).lineLimit(1)
                    Text("\(items.count) \(items.count == 1 ? "item" : "items") · \(show.cameraCount) cameras")
                        .font(.ocMeta).foregroundStyle(Deck.faint).lineLimit(1)
                }
                .frame(maxWidth: 260, alignment: .leading)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(timecodeText(item)).font(.readout(12, weight: .semibold)).foregroundStyle(Deck.dim)
                    Text(lengthText(item)).font(.readout(12, weight: .bold)).foregroundStyle(Deck.ink)
                }
                LiveButton(live: model.isLive) { model.toggleLive() }
            }

            HStack(spacing: Space.s) {
                NavArrow(symbol: "chevron.left", help: "Previous song or segment (⌘[)", enabled: (index ?? 0) > 0) {
                    model.selectItem(offset: -1)
                }
                if let item, let index {
                    Text("\(index + 1)")
                        .font(.readout(15, weight: .bold))
                        .foregroundStyle(Deck.ink)
                        .frame(minWidth: 28, minHeight: 28)
                        .background(RoundedRectangle(cornerRadius: Radius.s).strokeBorder(Deck.ink.opacity(0.55), lineWidth: 1.2))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(.system(size: 12.5, weight: .bold)).foregroundStyle(Deck.ink).lineLimit(1)
                        Text(item.kind == .song ? "Song" : "Segment").font(.ocMeta).foregroundStyle(Deck.faint)
                    }
                    .frame(minWidth: 120, alignment: .leading)
                } else {
                    Text("No song selected").font(.ocMeta).foregroundStyle(Deck.faint)
                }
                NavArrow(symbol: "chevron.right", help: "Next song or segment (⌘])",
                         enabled: index.map { $0 + 1 < items.count } ?? false) {
                    model.selectItem(offset: 1)
                }
            }
        }
        .padding(.horizontal, Space.l)
        .frame(height: 46)
        .background(Deck.bar)
    }

    private func timecodeText(_ item: RundownItem?) -> String {
        guard let item else { return "--:--:--:--" }
        if !item.ltcStart.isEmpty { return item.ltcStart }
        if let p = model.media.position(in: item) { return item.format(max(p, 0)) }
        return item.timeBase == .order ? "NEXT" : item.format(item.timeBase == .bars ? 1 : 0)
    }

    private func lengthText(_ item: RundownItem?) -> String {
        guard let item else { return "" }
        if let run = show.runLength(forItem: item.id) { return clockText(run) }
        if item.plannedDuration > 0 { return clockText(item.plannedDuration) }
        return "–:––"
    }
}

private struct NavArrow: View {
    let symbol: String
    let help: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? Deck.dim : Deck.faint.opacity(0.4))
                .frame(width: 26, height: 26)
                .interactive()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }
}

/// LIVE: grey when editing, solid red when Live Mode is on.
struct LiveButton: View {
    let live: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("LIVE")
                .font(.system(size: 11.5, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(live ? Color.white : Deck.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(live ? Deck.live : (hovering ? Deck.keyHover : Deck.key), in: RoundedRectangle(cornerRadius: Radius.m))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(live ? "Leave Live Mode (⌘L)" : "Enter Live Mode (⌘L)")
    }
}

// MARK: - Rail

/// The icon column on the far left: one button per side panel.
struct SideRail: View {
    @Binding var selection: RailPanel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(RailPanel.allCases) { panel in
                Button { selection = panel } label: {
                    Image(systemName: panel.symbol)
                        .font(.system(size: 15, weight: selection == panel ? .semibold : .regular))
                        .foregroundStyle(selection == panel ? Deck.accent : Deck.dim)
                        .frame(width: 34, height: 34)
                        .background(selection == panel ? Deck.accent.opacity(0.16) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Radius.m))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(panel.title)
            }
            Spacer()
        }
        .padding(.top, Space.s)
        .frame(width: 46)
        .background(Deck.bar)
    }
}

// MARK: - Side panel

struct SidePanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    let panel: RailPanel

    var body: some View {
        Group {
            switch panel {
            case .info:
                VSplitView {
                    InspectorView(show: show, model: model)
                        .frame(minHeight: 160)
                    CameraBank(show: show, model: model)
                        .frame(minHeight: 120, idealHeight: 210)
                }
            case .rundown:
                RunningOrderView(show: show, model: model)
            case .media:
                MediaPoolPanel(show: show, model: model)
            case .sources:
                SourcesPanel(show: show, model: model)
            case .controls:
                ControlsPanel(show: show, model: model)
            case .crew:
                ScrollView {
                    CrewPagePopover(crew: model.crew)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Gallery.panel)
            case .setup:
                ShowToolsPanel(show: show, model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Gallery.panel)
    }
}

/// Panel title row used by the side panels.
struct DeckPanelTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Deck.ink)
            Spacer()
            trailing
        }
        .padding(.horizontal, Space.l)
        .frame(height: 38)
    }
}

extension DeckPanelTitle where Trailing == EmptyView {
    init(title: String) { self.title = title; self.trailing = EmptyView() }
}

// MARK: - Camera bank

/// The cameras as solid colour keys. Click sets the camera on the selected shots (or adds a
/// shot when none is selected); Option-click always adds a shot.
struct CameraBank: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Deck.seam).frame(height: 1)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60, maximum: 90), spacing: 6)], spacing: 6) {
                    ForEach(show.sortedCameras) { cam in
                        CameraKey(camera: cam, tally: model.tally(forCamera: cam.id)) {
                            model.useCamera(cam.id, newShot: NSEvent.modifierFlags.contains(.option))
                        }
                    }
                    Button { model.addCamera() } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Deck.dim)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(RoundedRectangle(cornerRadius: Radius.m).strokeBorder(Deck.seam, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    }
                    .buttonStyle(.plain)
                    .help("New camera")
                }
                .padding(Space.m)
            }
            HStack {
                Text(model.selectedShotIDs.isEmpty ? "Click a camera to add a shot" : "Click sets the camera · ⌥-click adds a shot")
                    .font(.ocMeta).foregroundStyle(Deck.faint).lineLimit(1)
                Spacer()
                IconButton(symbol: "slider.horizontal.3", help: "Manage cameras (⌥⌘C)") { model.cameraManagerOpen = true }
            }
            .padding(.horizontal, Space.m)
            .padding(.bottom, Space.xs)
        }
        .background(Gallery.panel)
    }
}

/// One camera key: solid in the camera's colour with its number, name underneath. A white ring
/// marks the selected shot's camera, a dashed ring the next shot's.
struct CameraKey: View {
    let camera: Camera
    let tally: TallyState
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(camera.number)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(camera.inkColor)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(camera.swiftUIColor.opacity(hovering ? 1 : 0.9), in: RoundedRectangle(cornerRadius: Radius.m))
                    .overlay {
                        switch tally {
                        case .current:
                            RoundedRectangle(cornerRadius: Radius.m + 2).inset(by: -2.5).stroke(Color.white, lineWidth: 2)
                        case .next:
                            RoundedRectangle(cornerRadius: Radius.m + 2).inset(by: -2.5)
                                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        case .off:
                            EmptyView()
                        }
                    }
                Text(camera.name.isEmpty ? (camera.operatorName.isEmpty ? " " : camera.operatorName) : camera.displayName)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Deck.faint)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(camera.operatorName.isEmpty ? "Camera \(camera.number), \(camera.displayName)"
              : "Camera \(camera.number), \(camera.displayName), operated by \(camera.operatorName)")
        .accessibilityLabel("Camera \(camera.number)\(tally.label(live: false).map { ", \($0)" } ?? "")")
    }
}

// MARK: - Viewer

/// The song's video (a PGM recording) with a timecode readout; a drop zone to load media when
/// the song has none.
struct ViewerPanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let item = show.item(model.selectedItemID)
        VStack(spacing: 0) {
            HStack(spacing: Space.s) {
                Text("VIEWER").font(.system(size: 10.5, weight: .bold)).tracking(0.6).foregroundStyle(Deck.faint)
                Spacer()
                if let item, item.media?.kind == .video {
                    IconButton(symbol: "macwindow.on.rectangle", help: "Float the video in its own window") {
                        model.media.showVideo(title: item.title)
                    }
                }
            }
            .padding(.horizontal, Space.m)
            .frame(height: 28)
            ZStack(alignment: .topTrailing) {
                Color.black
                if let item, let media = item.media, media.resolvedURL() != nil {
                    if media.kind == .video {
                        PlayerSurface(player: model.media.player)
                            .onAppear { model.media.prepare(item) }
                    } else {
                        VStack(spacing: Space.s) {
                            Image(systemName: "waveform").font(.system(size: 30, weight: .light)).foregroundStyle(Deck.faint)
                            Text(media.name).font(.ocMeta).foregroundStyle(Deck.dim).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if let item {
                    Button { MediaPlayer.choose(for: item, model: model) } label: {
                        VStack(spacing: Space.s) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Deck.dim)
                                .frame(width: 54, height: 38)
                                .background(Deck.key, in: RoundedRectangle(cornerRadius: Radius.m))
                            Text("Load song audio or a PGM recording").font(.ocMeta).foregroundStyle(Deck.faint)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if let item {
                    TimecodeBadge(item: item, player: model.media)
                        .padding(Space.m)
                }
            }
            .clipped()
        }
        .background(Deck.base)
    }
}

/// The media position over the viewer.
private struct TimecodeBadge: View {
    let item: RundownItem
    @ObservedObject var player: MediaPlayer

    var body: some View {
        let p = player.position(in: item)
        Text(p.map { item.format(max($0, 0)) } ?? (item.ltcStart.isEmpty ? "--:--" : item.ltcStart))
            .font(.readout(14, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Radius.s).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

/// AVPlayer drawn in the viewer, without controls (the timeline and keyboard drive it).
struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        v.player = player
        return v
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        if view.player !== player { view.player = player }
    }
}

// MARK: - Media panel

/// Every song's media: what is loaded, what is missing, and a button to load media for the
/// selected song.
struct MediaPanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @State private var filter: MediaFilter = .all

    enum MediaFilter: String, CaseIterable, Identifiable {
        case all = "All", video = "Video", audio = "Audio"
        var id: String { rawValue }
    }

    var body: some View {
        let entries = show.items.compactMap { item -> (RundownItem, ItemMedia)? in
            guard let m = item.media else { return nil }
            switch filter {
            case .all: return (item, m)
            case .video: return m.kind == .video ? (item, m) : nil
            case .audio: return m.kind == .audio ? (item, m) : nil
            }
        }
        VStack(alignment: .leading, spacing: 0) {
            DeckPanelTitle(title: "Media") {
                if let item = show.item(model.selectedItemID) {
                    Button { MediaPlayer.choose(for: item, model: model) } label: { Label("Load", systemImage: "plus") }
                        .buttonStyle(QuietButtonStyle())
                        .help("Load song audio or a PGM recording for \(item.title)")
                }
            }
            Picker("Filter", selection: $filter) {
                ForEach(MediaFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.s)
            if entries.isEmpty {
                Text("No media yet. Load song audio or a PGM recording for a song to plan against it.")
                    .font(.ocMeta).foregroundStyle(Deck.faint)
                    .padding(Space.l)
                Spacer()
            } else {
                List(entries, id: \.0.id, selection: $model.selectedItemID) { item, media in
                    HStack(spacing: Space.s) {
                        Image(systemName: media.kind == .video ? "film" : "waveform")
                            .foregroundStyle(media.resolvedURL() == nil ? Deck.warn : Deck.dim)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(media.name).font(.ocBody).foregroundStyle(Deck.ink).lineLimit(1)
                            Text(media.resolvedURL() == nil ? "\(item.title) · missing" : item.title)
                                .font(.ocMeta).foregroundStyle(media.resolvedURL() == nil ? Deck.warn : Deck.faint).lineLimit(1)
                        }
                    }
                    .tag(item.id)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: - Sources panel

/// The cameras as a table: number, colour, name, operator and switcher input.
struct SourcesPanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckPanelTitle(title: "Sources") {
                IconButton(symbol: "plus", help: "New camera") { model.addCamera() }
                Button("Manage…") { model.cameraManagerOpen = true }
                    .buttonStyle(QuietButtonStyle())
                    .help("Names, operators, colours and inputs (⌥⌘C)")
            }
            HStack(spacing: Space.s) {
                Text("#").frame(width: 30, alignment: .leading)
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Operator").frame(maxWidth: .infinity, alignment: .leading)
                Text("Input").frame(width: 40, alignment: .trailing)
            }
            .font(.ocMeta).foregroundStyle(Deck.faint)
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.xs)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(show.sortedCameras) { cam in
                        HStack(spacing: Space.s) {
                            CameraChip(camera: cam, size: 20).frame(width: 30, alignment: .leading)
                            Text(cam.displayName).font(.ocBody).foregroundStyle(Deck.ink).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(cam.operatorName.isEmpty ? "–" : cam.operatorName).font(.ocBody).foregroundStyle(Deck.dim).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(cam.input > 0 ? "\(cam.input)" : "–").font(.readout(12)).foregroundStyle(Deck.dim)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .padding(.horizontal, Space.l)
                        .frame(height: 30)
                        .background(Deck.row)
                    }
                }
            }
        }
    }
}

// MARK: - Controls panel

/// Everything that can drive OnCue or be driven by it, with the place to set each up.
struct ControlsPanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DeckPanelTitle(title: "Controls")
                group("Switchers", detail: switcherSummary, symbol: "rectangle.3.group",
                      action: ("Show Setup…", { model.switcherSetupOpen = true }))
                group("Timing in", detail: "MIDI clock, LTC, MTC and OSC position. Choose the sources for this Mac in Settings; choose what each song follows in its header.",
                      symbol: "metronome", action: nil)
                group("Controllers", detail: "Keyboard, Akai APC40 mkII, any MIDI controller by MIDI learn, and Stream Deck through Companion.",
                      symbol: "slider.horizontal.below.square.filled.and.square", action: nil)
                group("Trigger routes", detail: "\(model.project.properties.triggerRoutes.count) \(model.project.properties.triggerRoutes.count == 1 ? "route" : "routes"): OSC, MIDI, MIDI Show Control and Art-Net from Companion, a grandMA3, the playback rig or a pedal.",
                      symbol: "point.3.connected.trianglepath.dotted", action: ("Trigger Routes…", { model.triggerRoutesOpen = true }))
                group("OSC out", detail: "\(show.oscTargets.count) \(show.oscTargets.count == 1 ? "target" : "targets") (Resolume, Disguise, CasparCG, lighting desks).",
                      symbol: "antenna.radiowaves.left.and.right", action: ("Show Setup…", { model.switcherSetupOpen = true }))
                group("PTZ", detail: "\(show.ptzCameras.count) PTZ \(show.ptzCameras.count == 1 ? "camera" : "cameras"): Panasonic, Sony VISCA over IP, VISCA over TCP, ATEM macros or Companion.",
                      symbol: "video.badge.ellipsis", action: ("Show Setup…", { model.switcherSetupOpen = true }))
                HStack {
                    SettingsLink { Label("This Mac's settings…", systemImage: "desktopcomputer") }
                        .buttonStyle(QuietButtonStyle())
                    Spacer()
                }
                .padding(Space.l)
            }
        }
    }

    private var switcherSummary: String {
        let names = show.switchers.map(\.name).filter { !$0.isEmpty }
        return names.isEmpty ? "No switcher set up yet." : names.joined(separator: ", ")
    }

    private func group(_ title: String, detail: String, symbol: String, action: (String, () -> Void)?) -> some View {
        HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Deck.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ocBodyStrong).foregroundStyle(Deck.ink)
                Text(detail).font(.ocMeta).foregroundStyle(Deck.faint).fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.0, action: action.1).buttonStyle(QuietButtonStyle()).padding(.top, 3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.l)
        .padding(.vertical, Space.m)
        .background(Deck.row)
        .padding(.bottom, 1)
    }
}

// MARK: - Show tools panel

/// The production-wide tools in one place.
struct ShowToolsPanel: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DeckPanelTitle(title: "Show")
                tool("Show Setup", "Switchers, outputs, OSC, PTZ, monitors", "rectangle.3.group", "⌥⌘S") { model.switcherSetupOpen = true }
                tool("Cameras", "Numbers, names, operators, colours, inputs", "video", "⌥⌘C") { model.cameraManagerOpen = true }
                tool("Trigger Routes", "OSC, MIDI, MSC and Art-Net in", "point.3.connected.trianglepath.dotted", "⌥⌘R") { model.triggerRoutesOpen = true }
                tool("Pre-show Check", "Switchers, inputs, script, devices", "checklist", "⌥⌘K") { model.preShowCheckOpen = true }
                tool("Camera Plot", "Cameras on the venue plan", "map", "⌥⌘P") { model.plotOpen = true }
                tool("Export", "Script and call sheet PDFs, CSV, EDL", "square.and.arrow.up", "⇧⌘E") { model.exportOpen = true }
                tool("Tour", "Tonight's name, nights compared", "calendar", nil) { model.tourOpen = true }
                tool("Versions", "Named versions inside the show file", "clock.arrow.circlepath", nil) { model.versionsOpen = true }
                tool("Draft from EDL", "New songs from an edit decision list", "doc.badge.plus", nil) { DraftSource.chooseEDL(model: model) }
                tool("Draft from Switch Log", "New songs from a night's cuts", "doc.text.magnifyingglass", nil) { DraftSource.chooseLog(model: model) }
            }
        }
    }

    private func tool(_ title: String, _ detail: String, _ symbol: String, _ shortcut: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.m) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Deck.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.ocBodyStrong).foregroundStyle(Deck.ink)
                    Text(detail).font(.ocMeta).foregroundStyle(Deck.faint).lineLimit(1)
                }
                Spacer(minLength: 0)
                if let shortcut {
                    Text(shortcut).font(.readout(11)).foregroundStyle(Deck.faint)
                }
            }
            .padding(.horizontal, Space.l)
            .frame(height: 44)
            .background(Deck.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.bottom, 1)
    }
}

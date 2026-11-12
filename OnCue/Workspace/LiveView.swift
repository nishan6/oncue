import SwiftUI
import OnCueCore

// Live Mode: the script as a gallery display. NOW and NEXT dominate; the camera grid shows which
// camera is on program (PGM) and preview (PVW) according to the script position.
//
// What is real here: stepping (NEXT, back, section jumps, song changes) and the clock, which
// measures time since the current shot was taken. What is not built yet is said plainly in the
// status bar: OnCue does not drive a switcher or follow MIDI clock or LTC until the show engine.

enum LivePalette {
    static let base = Color(hex: "#0A0B0D")
    static let panel = Color(hex: "#121317")
    static let raised = Color(hex: "#1A1C21")
}

struct LiveView: View {
    let show: Show
    let cursor: LiveCursor
    @ObservedObject var model: WorkspaceModel
    @FocusState private var focused: Bool

    var body: some View {
        let item = show.item(cursor.itemID)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: Space.l) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        NowNextPanels(show: show, item: item, cursor: cursor, takenAt: model.liveTakenAt, now: context.date)
                    }
                    UpcomingStrip(show: show, cursor: cursor)
                    LiveCameraGrid(show: show, cursor: cursor)
                }
                .padding(Space.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Rectangle().fill(Gallery.hairline).frame(width: 1)
                LiveControls(show: show, item: item, cursor: cursor, model: model)
                    .frame(width: 280)
            }
        }
        .background(LivePalette.base)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .onKeyPress(.space) { model.liveAdvance(); return .handled }
        .onKeyPress(.rightArrow) { model.liveAdvance(); return .handled }
        .onKeyPress(.leftArrow) { model.liveBack(); return .handled }
        .onExitCommand { model.exitLive() }
    }
}

// MARK: - Status bar

/// Live Mode's context in the window toolbar: LIVE, the song or segment, and the section on air.
struct LiveToolbarContext: View {
    let show: Show
    let cursor: LiveCursor

    var body: some View {
        let item = show.item(cursor.itemID)
        let now = show.liveNow(cursor)
        let section = item?.sections.first { $0.id == now?.sectionID }
        HStack(spacing: Space.m) {
            HStack(spacing: 6) {
                Circle().fill(Gallery.tally).frame(width: 8, height: 8)
                Text("LIVE").font(.system(size: 11, weight: .heavy)).tracking(1.2).foregroundStyle(Gallery.tally)
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Gallery.tally.opacity(0.14), in: Capsule())
            VStack(alignment: .leading, spacing: 0) {
                Text(item?.title ?? "No item").font(.ocHeading).foregroundStyle(Gallery.ink)
                Text(section?.name ?? (cursor.isStandingBy ? "Standing by" : show.name))
                    .font(.ocMeta).foregroundStyle(Gallery.dim)
            }
        }
    }
}

/// Live Mode's status in the window toolbar: timing source, mode, switcher, and Exit.
struct LiveToolbarStatus: View {
    let show: Show
    let cursor: LiveCursor
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let item = show.item(cursor.itemID)
        HStack(spacing: Space.s) {
            StatusChip(symbol: "hand.tap", label: "Timing", value: "Manual NEXT",
                       help: "Live Mode steps on NEXT. This item is planned for \(item?.syncMode.label ?? "manual") timing, which follows once the show engine is built.")
            StatusChip(symbol: "rectangle.on.rectangle", label: "Mode", value: "Display only",
                       help: "OnCue shows the calls; it does not cut the switcher yet.")
            StatusChip(symbol: "cable.connector.slash", label: "Switcher", value: "Not connected", warning: true,
                       help: "Switcher control comes with the show engine.")
            Button { model.exitLive() } label: { Label("Exit Live", systemImage: "xmark") }
                .buttonStyle(QuietButtonStyle())
                .help("Back to editing (Esc or ⌘L)")
        }
    }
}

struct StatusChip: View {
    let symbol: String
    let label: String
    let value: String
    var warning = false
    let help: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                .foregroundStyle(warning ? Gallery.amber : Gallery.dim)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Gallery.faint)
                Text(value).font(.ocLabel).foregroundStyle(warning ? Gallery.amber : Gallery.ink)
            }
        }
        .padding(.horizontal, Space.s + 2)
        .frame(height: 30)
        .background(LivePalette.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        .help(help)
    }
}

// MARK: - NOW / NEXT

struct NowNextPanels: View {
    let show: Show
    let item: RundownItem?
    let cursor: LiveCursor
    let takenAt: Date?
    let now: Date

    var body: some View {
        let onAir = show.liveNow(cursor)
        let next = show.liveNext(cursor)
        let elapsed = takenAt.map { now.timeIntervalSince($0) }
        let remaining: Double? = {
            guard let length = onAir?.lengthSeconds, let elapsed else { return nil }
            return length - elapsed
        }()
        HStack(spacing: Space.l) {
            LiveShotPanel(role: .current, show: show, item: item, row: onAir,
                          timeLabel: "On air", timeValue: elapsed.map(liveClock),
                          emptyText: "Standing by. Press NEXT to take the first shot.")
            LiveShotPanel(role: .next, show: show, item: item, row: next,
                          timeLabel: remaining == nil ? (next == nil ? "" : "On NEXT") : (remaining! >= 0 ? "Planned in" : "Over plan"),
                          timeValue: remaining.map { $0 >= 0 ? liveClock($0) : "+" + liveClock(-$0) },
                          timeWarning: (remaining ?? 0) < 0,
                          emptyText: "End of \(item?.kind == .segment ? "segment" : "song")")
        }
        .frame(height: 290)
    }
}

func liveClock(_ s: Double) -> String {
    let v = max(s, 0)
    let m = Int(v) / 60
    let sec = v - Double(m * 60)
    return String(format: "%d:%04.1f", m, sec)
}

struct LiveShotPanel: View {
    let role: TallyState
    let show: Show
    let item: RundownItem?
    let row: ShotRow?
    let timeLabel: String
    let timeValue: String?
    var timeWarning = false
    let emptyText: String

    var body: some View {
        let camera = show.camera(row?.cue.cameraID)
        let accent = role.color
        VStack(alignment: .leading, spacing: 0) {
            // Role bar: tally tag, role, shot reference, clock.
            HStack(alignment: .center, spacing: Space.s) {
                TallyTag(state: role, live: true)
                Text(role == .current ? "NOW" : "NEXT")
                    .font(.system(size: 15, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(accent)
                if let row {
                    Text("Shot \(row.number)").font(.system(size: 13, weight: .medium)).foregroundStyle(Gallery.dim)
                    if let item {
                        Text(item.format(row.cue.at)).font(.readout(13)).foregroundStyle(Gallery.faint)
                    }
                }
                Spacer()
                if let timeValue {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(timeLabel).font(.system(size: 11, weight: .medium)).foregroundStyle(Gallery.faint)
                        Text(timeValue)
                            .font(.system(size: 30, weight: .semibold).monospacedDigit())
                            .foregroundStyle(timeWarning ? Gallery.amber : Gallery.ink)
                            .contentTransition(.numericText())
                    }
                } else if !timeLabel.isEmpty {
                    Text(timeLabel).font(.system(size: 12, weight: .medium)).foregroundStyle(Gallery.faint)
                }
            }
            .frame(height: 48)

            if let row {
                HStack(alignment: .center, spacing: Space.l + 4) {
                    LiveCameraBlock(camera: camera, missing: row.cue.cameraID != nil && camera == nil)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(camera?.displayName ?? "No camera")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(camera == nil ? Gallery.amber : Gallery.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let op = camera?.operatorName, !op.isEmpty {
                            Text(op).font(.system(size: 16, weight: .medium)).foregroundStyle(Gallery.dim)
                        }
                        if !row.cue.text.isEmpty {
                            Text(row.cue.text)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Gallery.ink)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                        if !row.cue.note.isEmpty {
                            Text(row.cue.note).font(.system(size: 14).italic()).foregroundStyle(Gallery.dim).lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
                HStack(spacing: Space.s) {
                    Pill(text: row.cue.transition == .cut ? "CUT" : "MIX",
                         color: row.cue.transition == .cut ? Gallery.dim : Gallery.selection,
                         filled: row.cue.transition == .auto)
                    if let length = row.lengthSeconds {
                        Text(String(format: "%.1f s planned", length)).font(.readout(12)).foregroundStyle(Gallery.faint)
                    }
                    Spacer()
                    if let section = item?.sections.first(where: { $0.id == row.sectionID }) {
                        Text(section.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Gallery.faint)
                    }
                }
            } else {
                Spacer()
                Text(emptyText).font(.system(size: 18, weight: .medium)).foregroundStyle(Gallery.faint)
                Spacer()
            }
        }
        .padding(.horizontal, Space.xl)
        .padding(.bottom, Space.l)
        .padding(.top, Space.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [accent.opacity(row == nil ? 0 : 0.10), LivePalette.panel.opacity(0)],
                           startPoint: .top, endPoint: .center)
        )
        .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.l + 2))
        .clipShape(RoundedRectangle(cornerRadius: Radius.l + 2))
        .overlay(RoundedRectangle(cornerRadius: Radius.l + 2)
            .strokeBorder(row == nil ? Gallery.hairline : accent.opacity(0.85), lineWidth: role == .next ? 3 : 2))
        .animation(.easeOut(duration: 0.15), value: row?.id)
    }
}

/// The camera on a NOW / NEXT card: its colour, the number large enough to read across a gallery.
struct LiveCameraBlock: View {
    let camera: Camera?
    let missing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.l)
                .fill(camera?.swiftUIColor ?? Gallery.key)
            if let camera {
                Text("\(camera.number)")
                    .font(.cameraNumeral(58))
                    .foregroundStyle(camera.inkColor)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 6)
            } else {
                Image(systemName: missing ? "exclamationmark" : "questionmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Gallery.amber)
            }
        }
        .frame(width: 128, height: 112)
    }
}

// MARK: - Upcoming and cameras

struct UpcomingStrip: View {
    let show: Show
    let cursor: LiveCursor

    var body: some View {
        let upcoming = show.liveUpcoming(cursor, limit: 6)
        VStack(alignment: .leading, spacing: Space.s) {
            Text("After next").sectionLabel()
            if upcoming.isEmpty {
                Text("Nothing after next in this \(show.item(cursor.itemID)?.kind == .segment ? "segment" : "song").")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
                    .frame(height: 52, alignment: .leading)
            } else {
                HStack(spacing: Space.s) {
                    ForEach(upcoming) { row in
                        let cam = show.camera(row.cue.cameraID)
                        HStack(spacing: Space.s) {
                            CameraChip(camera: cam, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cam?.displayName ?? "No camera").font(.ocBodyStrong).foregroundStyle(Gallery.ink).lineLimit(1)
                                Text(row.cue.text.isEmpty ? "Shot \(row.number)" : row.cue.text)
                                    .font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Space.s)
                        .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                        .background(LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.m))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(cam?.swiftUIColor ?? Gallery.key).frame(width: 3)
                                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.m, bottomLeadingRadius: Radius.m))
                        }
                    }
                }
            }
        }
    }
}

struct LiveCameraGrid: View {
    let show: Show
    let cursor: LiveCursor

    var body: some View {
        let pgm = show.liveNow(cursor)?.cue.cameraID
        let pvw = show.liveNext(cursor)?.cue.cameraID
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text("Cameras").sectionLabel()
                Spacer()
                Text("Tally follows the script position").font(.ocMeta).foregroundStyle(Gallery.faint)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.s)], alignment: .leading, spacing: Space.s) {
                ForEach(show.sortedCameras) { cam in
                    SourceButton(camera: cam, tally: cam.id == pgm ? .current : (cam.id == pvw ? .next : .off),
                                 live: true, width: 150, height: 62, numeral: 28)
                }
            }
        }
    }
}

// MARK: - Controls

struct LiveControls: View {
    let show: Show
    let item: RundownItem?
    let cursor: LiveCursor
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let now = show.liveNow(cursor)
        VStack(alignment: .leading, spacing: Space.l) {
            Button { model.liveAdvance() } label: {
                VStack(spacing: 6) {
                    Text("NEXT").font(.system(size: 24, weight: .heavy)).tracking(3)
                    if let next = show.liveNext(cursor) {
                        let cam = show.camera(next.cue.cameraID)
                        HStack(spacing: 6) {
                            CameraChip(camera: cam, size: 18)
                            Text(cam?.displayName ?? "No camera").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Gallery.ink)
                    }
                    Text("Space").font(.system(size: 10.5, weight: .medium)).foregroundStyle(Gallery.faint)
                }
                .frame(maxWidth: .infinity, minHeight: 112)
            }
            .buttonStyle(LiveKeyStyle(color: Gallery.next))
            .disabled(show.liveNext(cursor) == nil)
            .help("Take the next shot (Space or →)")

            Button { model.liveBack() } label: {
                Label("Back one shot", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(LiveKeyStyle(color: Gallery.dim, subtle: true))
            .disabled(cursor.isStandingBy)
            .help("Back one shot (←)")

            if let item, !item.sections.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Sections").sectionLabel()
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(item.sortedSections) { section in
                                let active = now?.sectionID == section.id
                                Button { model.liveJump(toSection: section.id) } label: {
                                    HStack {
                                        Text(section.name).font(.ocBodyStrong)
                                        Spacer()
                                        Text(item.format(section.at)).font(.readout(11)).foregroundStyle(Gallery.faint)
                                    }
                                    .foregroundStyle(active ? Gallery.ink : Gallery.dim)
                                    .padding(.horizontal, Space.s)
                                    .frame(height: 28)
                                    .background(active ? LivePalette.raised : Color.clear, in: RoundedRectangle(cornerRadius: Radius.s))
                                    .overlay(alignment: .leading) {
                                        if active { Rectangle().fill(Gallery.tally).frame(width: 2) }
                                    }
                                    .contentShape(Rectangle())
                                    .interactive()
                                }
                                .buttonStyle(.plain)
                                .help("Jump to \(section.name): takes its first shot")
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Running order").sectionLabel()
                HStack(spacing: Space.s) {
                    Button { model.liveMoveItem(by: -1) } label: { Label("Previous", systemImage: "backward.end") }
                        .help("Previous song or segment (⌘[)")
                    Button { model.liveMoveItem(by: 1) } label: { Label("Next item", systemImage: "forward.end") }
                        .help("Next song or segment (⌘])")
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(LivePalette.panel)
    }
}

/// Large, high-contrast key for live operation.
struct LiveKeyStyle: ButtonStyle {
    let color: Color
    var subtle = false

    func makeBody(configuration: Configuration) -> some View {
        LiveKey(configuration: configuration, color: color, subtle: subtle)
    }

    private struct LiveKey: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        let subtle: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(subtle ? Gallery.ink : color)
                .background(fill, in: RoundedRectangle(cornerRadius: Radius.l))
                .overlay(RoundedRectangle(cornerRadius: Radius.l)
                    .strokeBorder(subtle ? Gallery.hairline : color.opacity(enabled ? 0.9 : 0.3), lineWidth: subtle ? 1 : 2))
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }

        private var fill: Color {
            if subtle { return configuration.isPressed ? Gallery.pressed : (hovering ? LivePalette.raised : Color.clear) }
            return color.opacity(configuration.isPressed ? 0.28 : (hovering ? 0.18 : 0.12))
        }
    }
}

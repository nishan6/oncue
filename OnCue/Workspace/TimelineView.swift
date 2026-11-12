import SwiftUI
import AppKit
import OnCueCore

// The song or segment as horizontal tracks on a shared ruler: sections, the vision (shots) track,
// lyrics, notes and FX. Blocks are selected by clicking, moved by dragging, trimmed by dragging a
// shot's right edge, and added by double-clicking a track. Every change goes through
// WorkspaceModel, as in the shot list.

// MARK: - Geometry

struct TimelineMetrics {
    let item: RundownItem
    /// Points per unit of the item's time base (beat, second or step).
    let unit: CGFloat

    var origin: Double { item.timeBase == .order ? 1 : 0 }
    func x(_ position: Double) -> CGFloat { CGFloat(position - origin) * unit }
    func position(_ x: CGFloat) -> Double { Double(x / unit) + origin }

    static func baseUnit(for item: RundownItem) -> CGFloat {
        switch item.timeBase {
        case .bars: return 9
        case .seconds: return 6
        case .order: return 100
        }
    }

    /// Where a dragged block lands, snapped. In NEXT order a block lands between two steps.
    func dragTarget(from start: Double, dx: CGFloat) -> Double {
        let raw = start + Double(dx / unit)
        if item.timeBase == .order {
            let r = max(1, raw.rounded())
            if r == start { return start }
            return r > start ? r + 0.5 : r - 0.5
        }
        return Show.snap(raw, for: item)
    }

    /// Visual offset of a block while it is dragged (follows the snap in timed items).
    func dragOffset(from start: Double, dx: CGFloat) -> CGFloat {
        if item.timeBase == .order { return dx }
        return x(dragTarget(from: start, dx: dx)) - x(start)
    }
}

enum TimelineLayout {
    static let headerWidth: CGFloat = 124
    static let toolbar: CGFloat = 30
    static let ruler: CGFloat = 24
    static let sections: CGFloat = 30
    static let cueLane: CGFloat = 30
    static let hiddenLane: CGFloat = 16
    static let tail: CGFloat = 260

    static func lanes(for item: RundownItem) -> [TimelineLane] {
        var all: [TimelineLane] = [.sections, .shots]
        if item.kind == .song { all.append(.lyrics) }
        all += [.notes, .fx]
        return all
    }

    static func height(of lane: TimelineLane, hidden: Bool, shotHeight: CGFloat) -> CGFloat {
        if lane == .shots { return shotHeight }
        if hidden { return hiddenLane }
        return lane == .sections ? sections : cueLane
    }

    /// Height of everything except the vision track.
    static func chromeHeight(for item: RundownItem, hidden: Set<TimelineLane>) -> CGFloat {
        let lanes = lanes(for: item).filter { $0 != .shots }
        let others = lanes.reduce(0) { $0 + height(of: $1, hidden: hidden.contains($1), shotHeight: 0) + 1 }
        return toolbar + ruler + 1 + others + 1
    }
}

extension TimelineLane {
    var symbol: String {
        switch self {
        case .sections: return "square.split.diagonal"
        case .shots: return "video.fill"
        case .lyrics: return "quote.opening"
        case .notes: return "note.text"
        case .fx: return "sparkles"
        }
    }

    var tone: Color {
        switch self {
        case .sections: return Gallery.dim
        case .shots: return Gallery.ink
        case .lyrics: return Gallery.lyric
        case .notes: return Gallery.note
        case .fx: return Gallery.fx
        }
    }
}

/// Ruler and grid marks for the visible scale.
struct RulerMark {
    let x: CGFloat
    let major: Bool
    let label: String?

    static func marks(item: RundownItem, metrics: TimelineMetrics, width: CGFloat) -> [RulerMark] {
        var marks: [RulerMark] = []
        let unit = metrics.unit
        switch item.timeBase {
        case .bars:
            let bpb = max(item.beatsPerBar, 1)
            let barWidth = CGFloat(bpb) * unit
            let every = [1, 2, 4, 8, 16, 32, 64].first { CGFloat($0) * barWidth >= 36 } ?? 64
            var bar = 0
            while true {
                let x = metrics.x(Double(bar * bpb))
                if x > width { break }
                marks.append(RulerMark(x: x, major: true, label: bar % every == 0 ? "\(bar + 1)" : nil))
                if unit >= 7 {
                    for beat in 1..<bpb {
                        marks.append(RulerMark(x: metrics.x(Double(bar * bpb + beat)), major: false, label: nil))
                    }
                }
                bar += 1
            }
        case .seconds:
            let every = [1, 2, 5, 10, 15, 30, 60, 120, 300].first { CGFloat($0) * unit >= 46 } ?? 300
            let minor = every >= 5 ? Double(every) / 5 : 1
            var t = 0.0
            while true {
                let x = metrics.x(t)
                if x > width { break }
                let isLabel = Int(t.rounded()) % every == 0 && abs(t - t.rounded()) < 1e-6
                marks.append(RulerMark(x: x, major: isLabel, label: isLabel ? clock(t) : nil))
                t += minor
            }
        case .order:
            var step = 1
            while true {
                let x = metrics.x(Double(step))
                if x > width { break }
                marks.append(RulerMark(x: x, major: true, label: "\(step)"))
                step += 1
            }
        }
        return marks
    }

    private static func clock(_ s: Double) -> String {
        let v = Int(s.rounded())
        return String(format: "%d:%02d", v / 60, v % 60)
    }
}

// MARK: - Editor

struct TimelineEditorView: View {
    let show: Show
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel
    var shotHeight: CGFloat
    @FocusState private var focused: Bool
    @State private var scrollRequest: ScrollRequest?

    var body: some View {
        let metrics = TimelineMetrics(item: item, unit: TimelineMetrics.baseUnit(for: item) * CGFloat(model.zoom))
        let end = show.itemEnd(forItem: item.id)
        let width = metrics.x(end) + TimelineLayout.tail
        let lanes = TimelineLayout.lanes(for: item)
        GeometryReader { geo in
            VStack(spacing: 0) {
                TimelineToolbar(item: item, model: model) {
                    let available = geo.size.width - TimelineLayout.headerWidth - 40
                    let units = max(end - metrics.origin, 1)
                    model.zoom = min(max(Double(available) / (Double(TimelineMetrics.baseUnit(for: item)) * units), 0.15), 6)
                }
                HStack(alignment: .top, spacing: 0) {
                    TrackHeaderColumn(show: show, lanes: lanes, shotHeight: shotHeight, model: model)
                    Rectangle().fill(Gallery.hairline).frame(width: 1)
                    ScrollView(.horizontal) {
                        TimelineCanvas(show: show, item: item, model: model, metrics: metrics, width: width,
                                       lanes: lanes, shotHeight: shotHeight, focus: { focused = true })
                            .background(HorizontalScrollDriver(request: scrollRequest))
                    }
                    .scrollIndicators(.visible)
                    .onAppear { reveal(metrics) }
                    .onChange(of: item.id) { _, _ in reveal(metrics) }
                    .onChange(of: model.scrollTarget) { _, target in
                        guard let target, let uuid = UUID(uuidString: target) else { return }
                        scroll(to: uuid, metrics: metrics)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .background(Gallery.canvas)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(characters: .decimalDigits) { press in
            model.typeCameraDigit(press.characters)
            return .handled
        }
        .onKeyPress(.return) {
            model.addShot()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            model.selectAdjacentShot(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            model.selectAdjacentShot(1)
            return .handled
        }
        .onDeleteCommand { model.deleteSelection() }
    }

    /// Brings the restored or current selection into view once the timeline has laid out.
    private func reveal(_ metrics: TimelineMetrics) {
        if model.editorMode == .timeline { DispatchQueue.main.async { focused = true } }
        for delay in [0.15, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let rows = show.shotRows(forItem: item.id)
                if let first = rows.first(where: { model.selectedShotIDs.contains($0.id) }) {
                    scroll(to: first.id, metrics: metrics)
                } else if let cue = model.selectedCueID {
                    scroll(to: cue, metrics: metrics)
                }
            }
        }
    }

    /// Centres a shot, section or cue in the visible part of the timeline.
    private func scroll(to id: UUID, metrics: TimelineMetrics) {
        let x: CGFloat
        if let span = show.shotSpans(forItem: item.id).first(where: { $0.id == id }) {
            x = (metrics.x(span.start) + metrics.x(span.end)) / 2
        } else if let section = item.sections.first(where: { $0.id == id }) {
            x = metrics.x(section.at) + 200
        } else if let cue = show.cue(id, inItem: item.id) {
            x = metrics.x(cue.at)
        } else {
            return
        }
        scrollRequest = ScrollRequest(x: x, serial: (scrollRequest?.serial ?? 0) + 1)
    }
}

struct ScrollRequest: Equatable {
    let x: CGFloat
    let serial: Int
}

/// Scrolls the enclosing horizontal scroll view so a content x position sits in the middle.
/// (Timeline blocks are drawn with offsets, so they cannot be targets of ScrollViewReader.)
struct HorizontalScrollDriver: NSViewRepresentable {
    let request: ScrollRequest?

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard let request, context.coordinator.lastSerial != request.serial else { return }
        context.coordinator.lastSerial = request.serial
        DispatchQueue.main.async {
            guard let scrollView = view.enclosingScrollView else { return }
            let clip = scrollView.contentView
            let visible = clip.bounds.width
            let contentWidth = scrollView.documentView?.frame.width ?? 0
            let originX = max(0, min(request.x - visible / 2, contentWidth - visible))
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                clip.animator().setBoundsOrigin(NSPoint(x: originX, y: clip.bounds.origin.y))
            }
            scrollView.reflectScrolledClipView(clip)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastSerial = -1
    }
}

struct TimelineToolbar: View {
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel
    let fit: () -> Void

    var body: some View {
        HStack(spacing: Space.s) {
            Label(snapText, systemImage: "rectangle.split.3x1")
                .labelStyle(.titleAndIcon)
                .font(.ocMeta)
                .foregroundStyle(Gallery.faint)
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundStyle(Gallery.faint)
                .help("Double-click a track to add. Drag a block to move it; drag a shot's right edge to trim. Double-click a block to edit it. Type a camera number to set it; ← and → step through shots.")
            Spacer(minLength: Space.s)
            IconButton(symbol: "minus", help: "Zoom out (⌘-)", size: 20) { model.changeZoom(by: 1 / 1.4) }
            Slider(value: Binding(get: { log2(model.zoom) }, set: { model.zoom = pow(2, $0) }), in: log2(0.15)...log2(6))
                .controlSize(.mini)
                .frame(width: 110)
                .help("Zoom")
            IconButton(symbol: "plus", help: "Zoom in (⌘=)", size: 20) { model.changeZoom(by: 1.4) }
            Text("\(Int((model.zoom * 100).rounded()))%")
                .font(.readout(10))
                .foregroundStyle(Gallery.faint)
                .frame(width: 36, alignment: .trailing)
            Button("Fit", action: fit)
                .buttonStyle(QuietButtonStyle())
                .help("Fit the whole song or segment in the window")
        }
        .padding(.horizontal, Space.m)
        .frame(height: TimelineLayout.toolbar)
        .background(Gallery.panel)
    }

    private var snapText: String {
        switch item.timeBase {
        case .bars: return "Snaps to the beat"
        case .seconds: return "Snaps to half seconds"
        case .order: return "NEXT order"
        }
    }
}

// MARK: - Track headers

struct TrackHeaderColumn: View {
    let show: Show
    let lanes: [TimelineLane]
    let shotHeight: CGFloat
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Color.clear.frame(height: TimelineLayout.ruler)
            ForEach(lanes) { lane in
                TrackHeaderCell(lane: lane, subtitle: lane == .shots ? (show.mainOutput?.name ?? "Program") : nil,
                                hidden: model.hiddenLanes.contains(lane), locked: model.lockedLanes.contains(lane),
                                height: TimelineLayout.height(of: lane, hidden: model.hiddenLanes.contains(lane), shotHeight: shotHeight),
                                model: model)
            }
        }
        .frame(width: TimelineLayout.headerWidth, alignment: .topLeading)
        .background(Gallery.hairline)
        .background(Gallery.panel)
    }
}

struct TrackHeaderCell: View {
    let lane: TimelineLane
    let subtitle: String?
    let hidden: Bool
    let locked: Bool
    let height: CGFloat
    @ObservedObject var model: WorkspaceModel
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1)
                .fill(lane.tone.opacity(hidden ? 0.35 : 0.9))
                .frame(width: 2)
                .padding(.vertical, hidden ? 3 : 6)
            if !hidden {
                Image(systemName: lane.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Gallery.dim)
                    .frame(width: 14)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(lane.label)
                    .font(hidden ? .ocMeta : .ocLabel)
                    .foregroundStyle(hidden ? Gallery.faint : Gallery.ink)
                    .lineLimit(1)
                    .fixedSize()
                if let subtitle, !hidden {
                    Text(subtitle).font(.ocMeta).foregroundStyle(Gallery.faint).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if lane != .shots, hovering || hidden {
                toggle(symbol: hidden ? "eye.slash" : "eye", on: hidden,
                       help: hidden ? "Show the \(lane.label.lowercased()) track" : "Hide the \(lane.label.lowercased()) track (its cues are kept)") {
                    model.toggleLaneHidden(lane)
                }
            }
            if !hidden, hovering || locked {
                toggle(symbol: locked ? "lock.fill" : "lock.open", on: locked,
                       help: locked ? "Unlock this track" : "Lock this track against edits") {
                    model.toggleLaneLocked(lane)
                }
            }
        }
        .padding(.leading, Space.s)
        .padding(.trailing, Space.xs)
        .frame(width: TimelineLayout.headerWidth, height: height)
        .background(hovering ? Gallery.raised : Gallery.panel)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private func toggle(symbol: String, on: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(on ? Gallery.amber : Gallery.dim)
                .frame(width: 18, height: 16)
                .interactive()
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Canvas

struct TimelineCanvas: View {
    let show: Show
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel
    let metrics: TimelineMetrics
    let width: CGFloat
    let lanes: [TimelineLane]
    let shotHeight: CGFloat
    let focus: () -> Void

    var body: some View {
        let spans = show.shotSpans(forItem: item.id)
        let sections = show.sectionSpans(forItem: item.id)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 1) {
                RulerLane(item: item, metrics: metrics, width: width)
                ForEach(lanes) { lane in
                    laneView(lane, spans: spans, sections: sections)
                }
            }
            SelectionMarker(position: selectedPosition(spans), metrics: metrics, height: totalHeight)
        }
        .frame(width: width, alignment: .topLeading)
        .background(Gallery.hairline)
    }

    @ViewBuilder
    private func laneView(_ lane: TimelineLane, spans: [ShotSpan], sections: [SectionSpan]) -> some View {
        let hidden = lane != .shots && model.hiddenLanes.contains(lane)
        let locked = model.lockedLanes.contains(lane)
        if hidden {
            LaneBackground(item: item, metrics: metrics, width: width)
                .frame(width: width, height: TimelineLayout.hiddenLane)
                .opacity(0.5)
        } else {
            switch lane {
            case .sections:
                SectionLane(item: item, spans: sections, metrics: metrics, width: width, locked: locked, model: model, focus: focus)
            case .shots:
                ShotLane(show: show, item: item, spans: spans, metrics: metrics, width: width, height: shotHeight,
                         locked: locked, model: model, focus: focus)
            case .lyrics, .notes, .fx:
                CueLane(kind: lane.trackKind ?? .notes, lane: lane, show: show, item: item, metrics: metrics, width: width,
                        locked: locked, model: model, focus: focus)
            }
        }
    }

    private var totalHeight: CGFloat {
        lanes.reduce(TimelineLayout.ruler) { total, lane in
            total + 1 + TimelineLayout.height(of: lane, hidden: model.hiddenLanes.contains(lane), shotHeight: shotHeight)
        }
    }

    private func selectedPosition(_ spans: [ShotSpan]) -> Double? {
        if let first = spans.first(where: { model.selectedShotIDs.contains($0.id) }) { return first.start }
        if let cue = model.selectedCueID { return show.cue(cue, inItem: item.id)?.at }
        return nil
    }
}

/// A thin line through every track at the selected block's start.
struct SelectionMarker: View {
    let position: Double?
    let metrics: TimelineMetrics
    let height: CGFloat

    var body: some View {
        if let position {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Gallery.selection.opacity(0.85))
                    .frame(width: 1.5, height: height)
                PlayheadHead()
                    .fill(Gallery.selection)
                    .frame(width: 11, height: 9)
                    .offset(y: TimelineLayout.ruler - 10)
            }
            .frame(width: 11, height: height, alignment: .top)
            .offset(x: metrics.x(position) - 5.5)
            .allowsHitTesting(false)
        }
    }
}

/// Downward-pointing head of the playhead, sitting on the ruler.
struct PlayheadHead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.45))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.45))
        p.closeSubpath()
        return p
    }
}

struct RulerLane: View {
    let item: RundownItem
    let metrics: TimelineMetrics
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            for mark in RulerMark.marks(item: item, metrics: metrics, width: size.width) {
                var tick = Path()
                tick.move(to: CGPoint(x: mark.x + 0.5, y: size.height - (mark.major ? 9 : 4)))
                tick.addLine(to: CGPoint(x: mark.x + 0.5, y: size.height))
                context.stroke(tick, with: .color(mark.major ? Gallery.dim : Gallery.faint), lineWidth: 1)
                if let label = mark.label {
                    let text = Text(label).font(.readout(10, weight: .semibold)).foregroundStyle(Gallery.dim)
                    context.draw(text, at: CGPoint(x: mark.x + 4, y: 8), anchor: .leading)
                }
            }
        }
        .frame(width: width, height: TimelineLayout.ruler)
        .background(Gallery.panel)
    }
}

/// Dark lane with bar (or time) lines.
struct LaneBackground: View {
    let item: RundownItem
    let metrics: TimelineMetrics
    let width: CGFloat

    var body: some View {
        Canvas { context, size in
            let bpb = max(item.beatsPerBar, 1)
            for mark in RulerMark.marks(item: item, metrics: metrics, width: size.width) where mark.major {
                var line = Path()
                line.move(to: CGPoint(x: mark.x + 0.5, y: 0))
                line.addLine(to: CGPoint(x: mark.x + 0.5, y: size.height))
                var strong = mark.label != nil
                if item.timeBase == .bars {
                    let bar = Int((metrics.position(mark.x) / Double(bpb)).rounded())
                    strong = bar % 4 == 0
                }
                context.stroke(line, with: .color(Color.white.opacity(strong ? 0.07 : 0.035)), lineWidth: 1)
            }
        }
        .background(Gallery.well)
        .contentShape(Rectangle())
    }
}

// MARK: - Drag state

struct TimelineDrag: Equatable {
    enum Kind: Equatable { case move, trim }
    let id: UUID
    let kind: Kind
    var dx: CGFloat
}

private var extendSelectionModifiers: Bool {
    let flags = NSEvent.modifierFlags
    return flags.contains(.command) || flags.contains(.shift)
}

// MARK: - Vision track

struct ShotLane: View {
    let show: Show
    let item: RundownItem
    let spans: [ShotSpan]
    let metrics: TimelineMetrics
    let width: CGFloat
    let height: CGFloat
    let locked: Bool
    @ObservedObject var model: WorkspaceModel
    let focus: () -> Void
    @State private var drag: TimelineDrag?

    var body: some View {
        let nextID = nextShotID
        ZStack(alignment: .topLeading) {
            LaneBackground(item: item, metrics: metrics, width: width)
                .gesture(SpatialTapGesture(count: 2).onEnded { value in
                    focus()
                    guard !locked else { return }
                    model.addShot(at: Show.snap(metrics.position(value.location.x), for: item))
                })
                .onTapGesture {
                    model.clearSelection()
                    focus()
                }
            ForEach(Array(spans.enumerated()), id: \.element.id) { k, span in
                block(span, next: k + 1 < spans.count ? spans[k + 1] : nil,
                      afterNext: k + 2 < spans.count ? spans[k + 2] : nil, isNext: span.id == nextID)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    /// The shot after the single selected shot (shown with a green bar).
    private var nextShotID: UUID? {
        guard model.selectedShotIDs.count == 1, let sel = model.selectedShotIDs.first,
              let k = spans.firstIndex(where: { $0.id == sel }), k + 1 < spans.count else { return nil }
        return spans[k + 1].id
    }

    private func block(_ span: ShotSpan, next: ShotSpan?, afterNext: ShotSpan?, isNext: Bool) -> some View {
        let x = metrics.x(span.start)
        var w = max(metrics.x(span.end) - x, 6)
        var dx: CGFloat = 0
        if let drag, drag.id == span.id {
            if drag.kind == .move { dx = metrics.dragOffset(from: span.start, dx: drag.dx) }
            if drag.kind == .trim, let next {
                let target = trimTarget(span: span, next: next, afterNext: afterNext, dx: drag.dx)
                w = max(metrics.x(target) - x, 6)
            }
        }
        let editing = Binding(get: { model.editingCueID == span.id },
                              set: { if !$0, model.editingCueID == span.id { model.editingCueID = nil } })
        return ShotBlock(span: span, item: item, camera: show.camera(span.row.cue.cameraID), width: w, height: height - 8,
                         selected: model.selectedShotIDs.contains(span.id), isNext: isNext)
            .overlay(alignment: .trailing) {
                if let next, !locked { trimHandle(span: span, next: next, afterNext: afterNext) }
            }
            .popover(isPresented: editing, arrowEdge: .bottom) {
                ShotQuickEditor(show: show, cue: span.row.cue, model: model)
            }
            .contextMenu { shotMenu(span) }
            .offset(x: x + dx, y: 4)
            .zIndex(drag?.id == span.id ? 1 : 0)
            .onTapGesture(count: 2) {
                model.selectShot(span.id, extending: false)
                if !locked { model.editingCueID = span.id }
            }
            .onTapGesture {
                model.selectShot(span.id, extending: extendSelectionModifiers)
                focus()
            }
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { value in
                    if drag == nil {
                        if !model.selectedShotIDs.contains(span.id) { model.selectShot(span.id, extending: false) }
                        focus()
                    }
                    drag = TimelineDrag(id: span.id, kind: .move, dx: value.translation.width)
                }
                .onEnded { value in
                    drag = nil
                    model.moveCue(span.id, to: metrics.dragTarget(from: span.start, dx: value.translation.width))
                }, including: locked ? .none : .all)
    }

    private func trimHandle(span: ShotSpan, next: ShotSpan, afterNext: ShotSpan?) -> some View {
        TrimHandle(active: drag?.id == span.id && drag?.kind == .trim)
            .gesture(DragGesture(minimumDistance: 1)
                .onChanged { value in drag = TimelineDrag(id: span.id, kind: .trim, dx: value.translation.width) }
                .onEnded { value in
                    drag = nil
                    let target = trimTarget(span: span, next: next, afterNext: afterNext, dx: value.translation.width)
                    model.moveCue(next.id, to: target)
                })
            .help("Drag to trim: moves the start of the next shot")
    }

    /// Trimming moves the next shot's start, kept between this shot and the one after the next.
    private func trimTarget(span: ShotSpan, next: ShotSpan, afterNext: ShotSpan?, dx: CGFloat) -> Double {
        let unit = Show.snapUnit(for: item)
        let raw = metrics.dragTarget(from: next.start, dx: dx)
        let low = span.start + unit
        let high = (afterNext?.start ?? .infinity) - unit
        return min(max(raw, low), max(high, low))
    }

    @ViewBuilder
    private func shotMenu(_ span: ShotSpan) -> some View {
        Menu("Camera") {
            ForEach(show.sortedCameras) { cam in
                Button("\(cam.number)  \(cam.displayName)") {
                    model.selectShot(span.id, extending: false)
                    model.useCamera(cam.id, newShot: false)
                }
            }
        }
        Button(span.row.cue.transition == .cut ? "Make It a Mix" : "Make It a Cut") {
            model.setTransition(span.row.cue.transition == .cut ? .auto : .cut, for: [span.id])
        }
        Button("Edit…") {
            model.selectShot(span.id, extending: false)
            model.editingCueID = span.id
        }
        Divider()
        Button("Duplicate") { model.selectShot(span.id, extending: false); model.duplicateSelectedShots() }
        Button("Delete", role: .destructive) { model.selectShot(span.id, extending: false); model.deleteSelectedShots() }
    }
}

/// Right-edge grip of a shot: invisible until hovered, then a bright bar with a resize cursor.
struct TrimHandle: View {
    let active: Bool
    @State private var hovering = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.clear
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(hovering || active ? 0.9 : 0))
                .frame(width: 3)
                .padding(.vertical, 6)
                .padding(.trailing, 2)
        }
        .frame(width: 8)
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
    }
}

/// Triangle in the upper left of a block: the shot comes in with a mix.
struct MixRamp: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct ShotBlock: View {
    let span: ShotSpan
    let item: RundownItem
    let camera: Camera?
    let width: CGFloat
    let height: CGFloat
    let selected: Bool
    let isNext: Bool
    @State private var hovering = false

    var body: some View {
        let cue = span.row.cue
        let ink = camera?.inkColor ?? Gallery.ink
        let mix = cue.transition == .auto
        ZStack(alignment: .topLeading) {
            Rectangle().fill(camera?.swiftUIColor ?? Gallery.key)
            if mix {
                MixRamp()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: min(20, width * 0.4), height: min(20, height * 0.5))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(camera.map { "\($0.number)" } ?? "?")
                        .font(.cameraNumeral(numeralSize))
                        .foregroundStyle(camera == nil ? Gallery.amber : ink)
                    if width > 96, let camera {
                        Text(camera.displayName)
                            .font(.umd(11))
                            .lineLimit(1)
                            .opacity(0.85)
                    }
                    Spacer(minLength: 0)
                    if !span.row.issues.isEmpty {
                        Circle().fill(Gallery.amber).frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
                    }
                }
                if height > 54, width > 44, !cue.text.isEmpty {
                    Text(cue.text)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(height > 110 ? 3 : 1)
                }
                if height > 96, width > 70, !cue.note.isEmpty {
                    Text(cue.note)
                        .font(.system(size: 10).italic())
                        .lineLimit(2)
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
                if width > 40 {
                    HStack(spacing: 4) {
                        Text(duration).font(.readout(10, weight: .semibold))
                        Spacer(minLength: 0)
                        if width > 80 {
                            Text(String(format: "#%02d", span.row.number)).font(.readout(10)).opacity(0.7)
                        }
                    }
                }
            }
            .foregroundStyle(ink)
            .padding(.leading, mix ? 9 : 6)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
        }
        .frame(width: max(width - 1, 3), height: height)
        .overlay(Color.white.opacity(hovering && !selected ? 0.08 : 0))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .onHover { hovering = $0 }
        .overlay(alignment: .bottom) {
            if isNext {
                Rectangle().fill(Gallery.next).frame(height: 4).clipShape(RoundedRectangle(cornerRadius: 1))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white, lineWidth: selected ? 2 : 0))
        .overlay(RoundedRectangle(cornerRadius: 5).inset(by: -2).stroke(Gallery.selection, lineWidth: selected ? 2 : 0))
        .frame(width: max(width - 1, 3), alignment: .leading)
        .help(help)
    }

    private var numeralSize: CGFloat {
        let byHeight = min(max(height * 0.28, 15), 34)
        return width < 30 ? min(byHeight, 13) : byHeight
    }

    private var duration: String {
        let length = span.end - span.start
        switch item.timeBase {
        case .order:
            return "NEXT"
        case .bars:
            let secs = item.seconds(for: length)
            let bars = length / Double(max(item.beatsPerBar, 1))
            if width > 120 {
                return String(format: "%@ bar%@  %.1fs", bars == bars.rounded() ? "\(Int(bars))" : String(format: "%.1f", bars),
                              bars == 1 ? "" : "s", secs)
            }
            return String(format: "%.1fs", secs)
        case .seconds:
            return length >= 60 ? TimeFormat.mmss(length).replacingOccurrences(of: ".0", with: "") : String(format: "%.1fs", length)
        }
    }

    private var help: String {
        var parts = ["Shot \(span.row.number) at \(item.format(span.start))"]
        parts.append(camera.map { "Camera \($0.number) \($0.displayName)" } ?? "No camera")
        if !span.row.cue.text.isEmpty { parts.append(span.row.cue.text) }
        parts.append(span.row.cue.transition == .cut ? "Cut" : "Mix")
        parts += span.row.issues.map(\.message)
        return parts.joined(separator: "\n")
    }
}

/// Double-click a shot on the timeline: edit its camera, description, note and transition in place.
struct ShotQuickEditor: View {
    let show: Show
    let cue: Cue
    @ObservedObject var model: WorkspaceModel
    @State private var text = ""
    @State private var note = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CameraTile(camera: show.camera(cue.cameraID), missing: cue.cameraID != nil && show.camera(cue.cameraID) == nil,
                           size: 44, compact: true)
                Menu(show.camera(cue.cameraID).map { "\($0.number)  \($0.displayName)" } ?? "Choose a camera") {
                    ForEach(show.sortedCameras) { cam in
                        Button("\(cam.number)  \(cam.label)") {
                            model.selectShot(cue.id, extending: false)
                            model.useCamera(cam.id, newShot: false)
                        }
                    }
                }
                .fixedSize()
                Spacer()
                Picker("Transition", selection: Binding(get: { show.cue(cue.id, inItem: model.selectedItemID ?? UUID())?.transition ?? cue.transition },
                                                         set: { model.setTransition($0, for: [cue.id]) })) {
                    Text("Cut").tag(TransitionKind.cut)
                    Text("Mix").tag(TransitionKind.auto)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            TextField("Describe the shot", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { model.editingCueID = nil }
            TextField("Note for the operator", text: $note)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.editingCueID = nil }
        }
        .padding(14)
        .frame(width: 340)
        .onAppear {
            text = cue.text
            note = cue.note
            DispatchQueue.main.async { focused = true }
        }
        .onDisappear {
            let t = text, n = note
            guard t != cue.text || n != cue.note else { return }
            model.updateShot(cue.id, "Edit Shot") { $0.text = t; $0.note = n }
        }
    }
}

// MARK: - Sections track

struct SectionLane: View {
    let item: RundownItem
    let spans: [SectionSpan]
    let metrics: TimelineMetrics
    let width: CGFloat
    let locked: Bool
    @ObservedObject var model: WorkspaceModel
    let focus: () -> Void
    @State private var drag: TimelineDrag?

    var body: some View {
        ZStack(alignment: .topLeading) {
            LaneBackground(item: item, metrics: metrics, width: width)
                .gesture(SpatialTapGesture(count: 2).onEnded { value in
                    guard !locked else { return }
                    model.addSection(at: Show.snap(metrics.position(value.location.x), for: item))
                })
                .onTapGesture { model.clearSelection(); focus() }
            ForEach(spans) { span in block(span) }
        }
        .frame(width: width, height: TimelineLayout.sections, alignment: .topLeading)
    }

    private func block(_ span: SectionSpan) -> some View {
        let x = metrics.x(span.start)
        let w = max(metrics.x(span.end) - x, 8)
        let dx = drag?.id == span.id ? metrics.dragOffset(from: span.start, dx: drag!.dx) : 0
        let editing = Binding(get: { model.editingSectionID == span.id },
                              set: { if !$0, model.editingSectionID == span.id { model.editingSectionID = nil } })
        return HStack(spacing: 6) {
            Text(span.section.name)
                .font(.ocLabel)
                .foregroundStyle(Gallery.ink)
                .lineLimit(1)
            if w > 110 {
                Text(item.format(span.start)).font(.readout(10, weight: .regular)).foregroundStyle(Gallery.faint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.s)
        .frame(width: max(w - 1, 4), height: TimelineLayout.sections, alignment: .leading)
        .background(Color.white.opacity(0.035))
        .overlay(alignment: .leading) { Rectangle().fill(Gallery.ink.opacity(0.55)).frame(width: 2) }
        .popover(isPresented: editing, arrowEdge: .bottom) {
            SectionQuickEditor(section: span.section, model: model)
        }
        .contextMenu {
            Button("Rename…") { model.editingSectionID = span.id }
            Button("New Shot Here") { model.addShot(inSection: span.id) }
            Divider()
            Button("Delete Section", role: .destructive) { model.deleteSection(span.id) }
        }
        .offset(x: x + dx, y: 0)
        .zIndex(drag?.id == span.id ? 1 : 0)
        .onTapGesture(count: 2) { if !locked { model.editingSectionID = span.id } }
        .onTapGesture { model.scrollTarget = span.id.uuidString; focus() }
        .gesture(DragGesture(minimumDistance: 4)
            .onChanged { value in drag = TimelineDrag(id: span.id, kind: .move, dx: value.translation.width) }
            .onEnded { value in
                drag = nil
                let target = metrics.dragTarget(from: span.start, dx: value.translation.width)
                if target != span.start { model.setSectionPosition(span.id, position: target) }
            }, including: locked ? .none : .all)
        .help("\(span.section.name) at \(item.format(span.start)). Drag to move its start, double-click to rename.")
    }
}

struct SectionQuickEditor: View {
    let section: SongSection
    @ObservedObject var model: WorkspaceModel
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Section name").font(.umd(11)).foregroundStyle(Gallery.dim)
            TextField("Verse, chorus, bridge…", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { model.editingSectionID = nil }
        }
        .padding(14)
        .frame(width: 260)
        .onAppear { name = section.name; DispatchQueue.main.async { focused = true } }
        .onDisappear {
            let n = name.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty, n != section.name { model.renameSection(section.id, to: n) }
        }
    }
}

// MARK: - Lyrics, notes and FX tracks

struct CueLane: View {
    let kind: TrackKind
    let lane: TimelineLane
    let show: Show
    let item: RundownItem
    let metrics: TimelineMetrics
    let width: CGFloat
    let locked: Bool
    @ObservedObject var model: WorkspaceModel
    let focus: () -> Void
    @State private var drag: TimelineDrag?

    var body: some View {
        let cues = show.trackCues(kind, inItem: item.id)
        let end = show.itemEnd(forItem: item.id)
        ZStack(alignment: .topLeading) {
            LaneBackground(item: item, metrics: metrics, width: width)
                .gesture(SpatialTapGesture(count: 2).onEnded { value in
                    focus()
                    guard !locked else { return }
                    model.addTrackCue(kind, at: Show.snap(metrics.position(value.location.x), for: item))
                })
                .onTapGesture { model.clearSelection(); focus() }
            ForEach(Array(cues.enumerated()), id: \.element.id) { k, cue in
                block(cue, until: k + 1 < cues.count ? cues[k + 1].at : end)
            }
        }
        .frame(width: width, height: TimelineLayout.cueLane, alignment: .topLeading)
    }

    private func block(_ cue: Cue, until next: Double) -> some View {
        let x = metrics.x(cue.at)
        let span = max(metrics.x(next) - x, 8)
        // Lyrics run until the next line; notes and FX are points in time with a label.
        let w = lane == .lyrics ? span : min(span, 220)
        let dx = drag?.id == cue.id ? metrics.dragOffset(from: cue.at, dx: drag!.dx) : 0
        let selected = model.selectedCueID == cue.id
        let editing = Binding(get: { model.editingCueID == cue.id },
                              set: { if !$0, model.editingCueID == cue.id { model.editingCueID = nil } })
        return HStack(spacing: 4) {
            Text(label(cue))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(cue.text.isEmpty && kind != .fx ? Gallery.faint : Gallery.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .frame(width: max(w - 1, 6), height: TimelineLayout.cueLane - 6, alignment: .leading)
        .background(lane.tone.opacity(0.18), in: RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .leading) { Rectangle().fill(lane.tone).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white, lineWidth: selected ? 1.5 : 0))
        .overlay(RoundedRectangle(cornerRadius: 5).inset(by: -2).stroke(Gallery.selection, lineWidth: selected ? 2 : 0))
        .popover(isPresented: editing, arrowEdge: .bottom) {
            CueQuickEditor(kind: kind, cue: cue, model: model)
        }
        .contextMenu {
            Button("Edit…") { model.selectedCueID = cue.id; model.editingCueID = cue.id }
            Divider()
            Button("Delete", role: .destructive) { model.selectedCueID = cue.id; model.deleteSelectedCue() }
        }
        .offset(x: x + dx, y: 3)
        .zIndex(drag?.id == cue.id || selected ? 1 : 0)
        .onTapGesture(count: 2) {
            model.selectedCueID = cue.id
            if !locked { model.editingCueID = cue.id }
        }
        .onTapGesture {
            model.selectedCueID = cue.id
            focus()
        }
        .gesture(DragGesture(minimumDistance: 4)
            .onChanged { value in
                if drag == nil { model.selectedCueID = cue.id; focus() }
                drag = TimelineDrag(id: cue.id, kind: .move, dx: value.translation.width)
            }
            .onEnded { value in
                drag = nil
                model.moveCue(cue.id, to: metrics.dragTarget(from: cue.at, dx: value.translation.width))
            }, including: locked ? .none : .all)
        .help(help(cue))
    }

    private func label(_ cue: Cue) -> String {
        switch kind {
        case .fx:
            let action = cue.fxAction?.label ?? "FX"
            return cue.text.isEmpty ? action : "\(action): \(cue.text)"
        case .lyrics:
            return cue.text.isEmpty ? "Lyric" : cue.text
        default:
            return cue.text.isEmpty ? "Note" : cue.text
        }
    }

    private func help(_ cue: Cue) -> String {
        "\(lane.label) at \(item.format(cue.at))\n\(label(cue))\nDouble-click to edit, drag to move."
    }
}

/// Double-click a lyric, note or FX cue: edit it in place.
struct CueQuickEditor: View {
    let kind: TrackKind
    let cue: Cue
    @ObservedObject var model: WorkspaceModel
    @State private var text = ""
    @State private var action: FXAction = .macro
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.umd(11)).foregroundStyle(Gallery.dim)
            if kind == .fx {
                Picker("Action", selection: $action) {
                    ForEach(FXAction.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                Text("FX cues are part of the script. They run on the switcher once the show engine is built.")
                    .font(.system(size: 11))
                    .foregroundStyle(Gallery.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { model.editingCueID = nil }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            text = cue.text
            action = cue.fxAction ?? .macro
            DispatchQueue.main.async { focused = true }
        }
        .onDisappear {
            let t = text, a = action, isFX = kind == .fx
            guard t != cue.text || (isFX && a != cue.fxAction) else { return }
            model.updateCue(cue.id, "Edit \(title)") { c in
                c.text = t
                if isFX { c.fxAction = a }
            }
        }
    }

    private var title: String {
        switch kind {
        case .lyrics: return "Lyric"
        case .fx: return "FX cue"
        default: return "Note"
        }
    }

    private var placeholder: String {
        switch kind {
        case .lyrics: return "Lyric line"
        case .fx: return "Label, e.g. band name lower third"
        default: return "Note for the gallery"
        }
    }
}

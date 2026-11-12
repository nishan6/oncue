import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnCueCore

/// Production › Camera Plot: every camera's position and direction on the venue plan.
/// Drag a camera to move it, drag the dot at the end of its view to turn it.
struct CameraPlotView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?
    /// Live drag state, committed as one undo step when the drag ends.
    @State private var dragging: (id: UUID, x: Double, y: Double)?
    @State private var turning: (id: UUID, angle: Double)?

    private var plot: CameraPlot { show.plot }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                sidebar.frame(width: 230)
                Rectangle().fill(Gallery.hairline).frame(width: 1)
                PlotCanvas(show: show, plot: plot, selected: selected, dragging: dragging, turning: turning,
                           select: { selected = $0 },
                           drag: { id, x, y in dragging = (id, x, y) },
                           endDrag: { id, x, y in
                               dragging = nil
                               model.edit("Move Camera") { $0.placeCamera(id, x: x, y: y) }
                           },
                           turn: { id, a in turning = (id, a) },
                           endTurn: { id, a in
                               turning = nil
                               model.edit("Turn Camera") { $0.updatePlotMarker(id) { $0.angle = a } }
                           },
                           drop: { id, x, y in
                               selected = id
                               model.edit("Place Camera") { $0.placeCamera(id, x: x, y: y) }
                           })
                    .padding(Space.l)
            }
        }
        .frame(width: 1120, height: 760)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Space.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Camera plot").font(.ocTitle).foregroundStyle(Gallery.ink)
                Text("Drag cameras onto the plan. Drag the dot at the end of a camera's view to turn it.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim)
            }
            Spacer()
            Button(plot.background == nil ? "Import Plan…" : "Replace Plan…") { importPlan() }
                .buttonStyle(QuietButtonStyle())
                .help("A venue drawing or a CAD export as PNG, JPEG or PDF (first page)")
            if plot.background != nil {
                Slider(value: Binding(get: { plot.backgroundOpacity },
                                      set: { v in model.edit("Plan Opacity") { $0.plot.backgroundOpacity = v } }),
                       in: 0.15...1)
                    .frame(width: 90)
                    .help("Plan brightness")
                Button("Remove Plan") { model.edit("Remove Plan") { $0.plot.background = nil } }
                    .buttonStyle(QuietButtonStyle())
            }
            Toggle("View cones", isOn: Binding(get: { plot.showCones },
                                               set: { v in model.edit("View Cones") { $0.plot.showCones = v } }))
                .toggleStyle(.checkbox)
            Button("Export Image…") { exportImage() }
                .buttonStyle(QuietButtonStyle())
            Button("Done") { dismiss() }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
        }
        .padding(Space.l)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(show.sortedCameras.filter { $0.kind == .camera }) { cam in
                        let marker = plot.marker(cam.id)
                        Button { selected = cam.id } label: {
                            HStack(spacing: Space.s) {
                                CameraChip(camera: cam, size: 22)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(cam.displayName).font(.ocLabel).foregroundStyle(Gallery.ink).lineLimit(1)
                                    Text(marker == nil ? "Not on the plot" : (marker!.note.isEmpty ? cam.operatorName : marker!.note))
                                        .font(.ocMeta).foregroundStyle(marker == nil ? Gallery.faint : Gallery.dim).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, Space.s)
                            .padding(.vertical, 5)
                            .background(selected == cam.id ? Gallery.selection.opacity(0.18) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: Radius.s))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onDrag { NSItemProvider(object: cam.id.uuidString as NSString) }
                    }
                }
                .padding(Space.s)
            }
            if !show.unplottedCameras.isEmpty {
                Button("Place the rest at front of house") {
                    model.edit("Place Cameras") { $0.placeRemainingCameras() }
                }
                .buttonStyle(QuietButtonStyle())
                .padding(.horizontal, Space.m)
                .padding(.bottom, Space.s)
            }
            Rectangle().fill(Gallery.hairline).frame(height: 1)
            markerInspector.padding(Space.m)
        }
        .background(Gallery.base)
    }

    @ViewBuilder private var markerInspector: some View {
        if let id = selected, let cam = show.camera(id) {
            if let marker = plot.marker(id) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Camera \(cam.number)").font(.ocHeading).foregroundStyle(Gallery.ink)
                    CommitField(placeholder: "Position, e.g. FOH riser", value: marker.note, font: .ocBody) { v in
                        model.edit("Camera Position Name") { $0.updatePlotMarker(id) { $0.note = v } }
                        return true
                    }
                    CommitField(placeholder: "Lens or body", value: marker.lens, font: .ocBody) { v in
                        model.edit("Camera Lens") { $0.updatePlotMarker(id) { $0.lens = v } }
                        return true
                    }
                    HStack {
                        Text("Facing").font(.ocMeta).foregroundStyle(Gallery.dim)
                        Slider(value: Binding(get: { turning?.id == id ? turning!.angle : marker.angle },
                                              set: { turning = (id, $0) }),
                               in: 0...359) { editing in
                            if !editing, let t = turning { turning = nil; model.edit("Turn Camera") { $0.updatePlotMarker(t.id) { $0.angle = t.angle } } }
                        }
                        Text("\(Int(marker.angle))°").font(.readout(11)).foregroundStyle(Gallery.dim).frame(width: 34, alignment: .trailing)
                    }
                    Button("Take off the plot") {
                        model.edit("Remove from Plot") { $0.removeFromPlot(id) }
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("Camera \(cam.number)").font(.ocHeading).foregroundStyle(Gallery.ink)
                    Text("Drag it onto the plan, or put it in the middle and move it from there.")
                        .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
                    Button("Put on the plot") { model.edit("Place Camera") { $0.placeCamera(id, x: 0.5, y: 0.5) } }
                        .buttonStyle(QuietButtonStyle(prominent: true))
                }
            }
        } else {
            Text("Select a camera to name its position, lens and direction.")
                .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Plan image

    private func importPlan() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .pdf, .tiff, .heic]
        panel.prompt = "Use as Plan"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url), let data = PlanImage.prepare(image) else {
            model.errorMessage = "\(url.lastPathComponent) couldn't be read as an image."
            return
        }
        model.edit("Import Plan") { $0.plot.background = data }
    }

    @MainActor private func exportImage() {
        let renderer = ImageRenderer(content:
            PlotCanvas(show: show, plot: plot, selected: nil, dragging: nil, turning: nil, printing: true)
                .frame(width: 1600, height: 1100)
                .background(Gallery.well)
                .environment(\.colorScheme, .dark))
        renderer.scale = 1
        guard let cg = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            model.errorMessage = "The plot couldn't be drawn as an image."
            return
        }
        FileSaver.save(png, name: "\(show.name) – Camera plot", type: .png, model: model)
    }
}

/// Plan images are kept with the show, so they are scaled down and stored as JPEG.
enum PlanImage {
    static func prepare(_ image: NSImage, maxSide: CGFloat = 2400) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = NSSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSRect(origin: .zero, size: target).fill()
        image.draw(in: NSRect(origin: .zero, size: target))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
}

/// The plan with the cameras on it. Also used, without interaction, to export the plot.
struct PlotCanvas: View {
    let show: Show
    let plot: CameraPlot
    let selected: UUID?
    let dragging: (id: UUID, x: Double, y: Double)?
    let turning: (id: UUID, angle: Double)?
    var printing = false
    /// Live tally: the camera on program and on preview are lit, the rest dimmed.
    var live: UUID? = nil
    var next: UUID? = nil
    var tally = false
    var select: (UUID?) -> Void = { _ in }
    var drag: (UUID, Double, Double) -> Void = { _, _, _ in }
    var endDrag: (UUID, Double, Double) -> Void = { _, _, _ in }
    var turn: (UUID, Double) -> Void = { _, _ in }
    var endTurn: (UUID, Double) -> Void = { _, _ in }
    var drop: (UUID, Double, Double) -> Void = { _, _, _ in }

    var body: some View {
        GeometryReader { geo in
            let area = planRect(in: geo.size)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Radius.l).fill(Gallery.well)
                plan(area)
                ForEach(plot.markers) { marker in
                    if let cam = show.camera(marker.cameraID) {
                        markerView(marker, cam, area)
                    }
                }
                if !printing, plot.markers.isEmpty {
                    Text("Drag cameras from the list onto the plan")
                        .font(.ocBody).foregroundStyle(Gallery.faint)
                        .position(x: area.midX, y: area.midY)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { select(nil) }
            .onDrop(of: [.text], isTargeted: nil) { providers, point in
                guard !printing, let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let text = object as? String, let id = UUID(uuidString: text) else { return }
                    let x = (point.x - area.minX) / area.width, y = (point.y - area.minY) / area.height
                    DispatchQueue.main.async { drop(id, x, y) }
                }
                return true
            }
        }
    }

    /// Where the plan sits: the image's aspect, or 16:10 for the grid.
    private func planRect(in size: CGSize) -> CGRect {
        var aspect: CGFloat = 1.6
        if let data = plot.background, let img = NSImage(data: data), img.size.height > 0 { aspect = img.size.width / img.size.height }
        let inset: CGFloat = 16
        let w = size.width - inset * 2, h = size.height - inset * 2
        let fitW = min(w, h * aspect)
        let fitH = fitW / aspect
        return CGRect(x: (size.width - fitW) / 2, y: (size.height - fitH) / 2, width: fitW, height: fitH)
    }

    @ViewBuilder private func plan(_ area: CGRect) -> some View {
        if let data = plot.background, let img = NSImage(data: data) {
            Image(nsImage: img)
                .resizable()
                .frame(width: area.width, height: area.height)
                .opacity(plot.backgroundOpacity)
                .offset(x: area.minX, y: area.minY)
        } else {
            Canvas { ctx, _ in
                let step = area.width / 16
                var x = area.minX
                while x <= area.maxX + 0.5 {
                    var p = Path(); p.move(to: CGPoint(x: x, y: area.minY)); p.addLine(to: CGPoint(x: x, y: area.maxY))
                    ctx.stroke(p, with: .color(Gallery.ink.opacity(0.05)), lineWidth: 1)
                    x += step
                }
                var y = area.minY
                while y <= area.maxY + 0.5 {
                    var p = Path(); p.move(to: CGPoint(x: area.minX, y: y)); p.addLine(to: CGPoint(x: area.maxX, y: y))
                    ctx.stroke(p, with: .color(Gallery.ink.opacity(0.05)), lineWidth: 1)
                    y += step
                }
                // The stage along the top edge.
                let stage = CGRect(x: area.minX + area.width * 0.2, y: area.minY, width: area.width * 0.6, height: area.height * 0.22)
                ctx.fill(Path(roundedRect: stage, cornerRadius: 4), with: .color(Gallery.raised))
                ctx.draw(Text(plot.stageLabel).font(.ocHeading).foregroundColor(Gallery.faint), at: CGPoint(x: stage.midX, y: stage.midY))
            }
        }
    }

    private func markerView(_ marker: PlotMarker, _ cam: Camera, _ area: CGRect) -> some View {
        markerBody(marker, cam, area)
            .opacity(tally && live != marker.cameraID && next != marker.cameraID ? 0.35 : 1)
            .animation(.easeOut(duration: 0.12), value: live)
    }

    private func markerBody(_ marker: PlotMarker, _ cam: Camera, _ area: CGRect) -> some View {
        let mx = dragging?.id == marker.cameraID ? dragging!.x : marker.x
        let my = dragging?.id == marker.cameraID ? dragging!.y : marker.y
        let angle = turning?.id == marker.cameraID ? turning!.angle : marker.angle
        let center = CGPoint(x: area.minX + mx * area.width, y: area.minY + my * area.height)
        let color = cam.swiftUIColor
        let isSelected = selected == marker.cameraID
        let isLive = tally && live == marker.cameraID
        let isNext = tally && !isLive && next == marker.cameraID
        let ring: Color = isLive ? Gallery.tally : (isNext ? Gallery.next : (isSelected ? Gallery.ink : Gallery.well))
        let reach: CGFloat = min(area.width, area.height) * 0.16
        let radians = CGFloat((angle - 90) * .pi / 180)
        let tip = CGPoint(x: center.x + cos(radians) * reach, y: center.y + sin(radians) * reach)

        return ZStack(alignment: .topLeading) {
            if plot.showCones {
                Path { p in
                    p.move(to: center)
                    p.addArc(center: center, radius: reach, startAngle: .degrees(angle - 90 - 20), endAngle: .degrees(angle - 90 + 20), clockwise: false)
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [(isLive ? Gallery.tally : color).opacity(isLive ? 0.7 : 0.45), color.opacity(0.04)],
                                     startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: UnitPoint(x: 0.5 + cos(radians) * 0.5, y: 0.5 + sin(radians) * 0.5)))
                .allowsHitTesting(false)
            }
            // Label.
            VStack(alignment: .leading, spacing: 0) {
                Text(cam.displayName).font(.ocLabel).foregroundStyle(Gallery.ink)
                let sub = [marker.note, marker.lens, cam.operatorName].filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty { Text(sub).font(.ocMeta).foregroundStyle(Gallery.dim) }
            }
            .lineLimit(1)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Gallery.well.opacity(0.75), in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
            .position(x: center.x, y: center.y + 34)
            .allowsHitTesting(false)

            // The camera itself.
            Text("\(cam.number)")
                .font(Font.cameraNumeral(15))
                .foregroundStyle(Gallery.well)
                .frame(width: 32, height: 32)
                .background(color, in: Circle())
                .overlay(Circle().strokeBorder(ring, lineWidth: isLive || isNext ? 3.5 : (isSelected ? 2.5 : 1.5)))
                .shadow(color: isLive ? Gallery.tally.opacity(0.9) : (isNext ? Gallery.next.opacity(0.8) : .black.opacity(0.4)),
                        radius: isLive || isNext ? 12 : 3, y: isLive || isNext ? 0 : 1)
                .scaleEffect(isLive ? 1.35 : (isNext ? 1.15 : 1))
                .position(center)
                .gesture(printing ? nil : DragGesture(minimumDistance: 1, coordinateSpace: .local)
                    .onChanged { v in
                        select(marker.cameraID)
                        drag(marker.cameraID, clamp((v.location.x - area.minX) / area.width), clamp((v.location.y - area.minY) / area.height))
                    }
                    .onEnded { v in
                        endDrag(marker.cameraID, clamp((v.location.x - area.minX) / area.width), clamp((v.location.y - area.minY) / area.height))
                    })
                .onTapGesture { select(marker.cameraID) }

            // Turning handle.
            if isSelected && !printing {
                Circle()
                    .fill(Gallery.ink)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(color, lineWidth: 2))
                    .position(tip)
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in turn(marker.cameraID, bearing(from: center, to: v.location)) }
                        .onEnded { v in endTurn(marker.cameraID, bearing(from: center, to: v.location)) })
                    .help("Drag to turn the camera")
            }
        }
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }

    /// Degrees clockwise from straight up.
    private func bearing(from a: CGPoint, to b: CGPoint) -> Double {
        var deg = atan2(b.y - a.y, b.x - a.x) * 180 / .pi + 90
        if deg < 0 { deg += 360 }
        return deg.rounded()
    }
}

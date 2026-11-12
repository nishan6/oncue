import Foundation

/// A camera on the plot: where it stands on the venue plan and which way it looks.
public struct PlotMarker: Codable, Hashable, Identifiable {
    public var id: UUID { cameraID }
    public var cameraID: UUID
    /// Position on the plan, 0...1 across and down.
    public var x: Double
    public var y: Double
    /// Direction the camera looks, in degrees clockwise from straight up the plan.
    public var angle: Double = 0
    /// Lens or body, e.g. "86x box", "Ronin RS3".
    public var lens: String = ""
    /// Position name or note, e.g. "FOH riser", "Pit left".
    public var note: String = ""

    public init(cameraID: UUID, x: Double, y: Double, angle: Double = 0, lens: String = "", note: String = "") {
        self.cameraID = cameraID
        self.x = x
        self.y = y
        self.angle = angle
        self.lens = lens
        self.note = note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        cameraID = try c.value("cameraID", UUID())
        x = try c.value("x", 0.5)
        y = try c.value("y", 0.5)
        angle = try c.value("angle", 0.0)
        lens = try c.value("lens", "")
        note = try c.value("note", "")
    }
}

/// The camera plot: a venue plan (an image the person imports, or a plain grid) with every camera's
/// position and direction, to share with the crew and keep with the show.
public struct CameraPlot: Codable, Equatable {
    public var markers: [PlotMarker] = []
    /// The venue plan image (PNG or JPEG), when one was imported.
    public var background: Data?
    public var backgroundOpacity: Double = 0.7
    /// Label drawn at the stage edge when there is no plan image.
    public var stageLabel: String = "Stage"
    public var showCones: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        markers = try c.value("markers", [])
        background = try c.value("background", Data?.none)
        backgroundOpacity = try c.value("backgroundOpacity", 0.7)
        stageLabel = try c.value("stageLabel", "Stage")
        showCones = try c.value("showCones", true)
    }

    public func marker(_ cameraID: UUID) -> PlotMarker? { markers.first { $0.cameraID == cameraID } }
}

extension Show {
    /// Puts a camera on the plot (or moves it), clamped to the plan.
    public mutating func placeCamera(_ cameraID: UUID, x: Double, y: Double) {
        guard camera(cameraID) != nil else { return }
        let cx = min(max(x, 0), 1), cy = min(max(y, 0), 1)
        if let i = plot.markers.firstIndex(where: { $0.cameraID == cameraID }) {
            plot.markers[i].x = cx
            plot.markers[i].y = cy
        } else {
            plot.markers.append(PlotMarker(cameraID: cameraID, x: cx, y: cy))
        }
    }

    public mutating func updatePlotMarker(_ cameraID: UUID, _ change: (inout PlotMarker) -> Void) {
        guard let i = plot.markers.firstIndex(where: { $0.cameraID == cameraID }) else { return }
        change(&plot.markers[i])
        var a = plot.markers[i].angle.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        plot.markers[i].angle = a
    }

    public mutating func removeFromPlot(_ cameraID: UUID) {
        plot.markers.removeAll { $0.cameraID == cameraID }
    }

    /// Cameras not yet on the plot.
    public var unplottedCameras: [Camera] {
        sortedCameras.filter { plot.marker($0.id) == nil }
    }

    /// Places every unplotted camera in a row along the front of house edge, looking at the stage.
    public mutating func placeRemainingCameras() {
        let rest = unplottedCameras
        guard !rest.isEmpty else { return }
        for (k, cam) in rest.enumerated() {
            let x = (Double(k) + 1) / Double(rest.count + 1)
            plot.markers.append(PlotMarker(cameraID: cam.id, x: x, y: 0.85))
        }
    }

    /// Drops markers whose camera was deleted.
    public mutating func prunePlot() {
        let ids = Set(cameras.map(\.id))
        plot.markers.removeAll { !ids.contains($0.cameraID) }
    }
}

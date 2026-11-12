import XCTest
@testable import OnCueCore

final class CameraPlotTests: XCTestCase {
    func testPlaceMoveRotateRemove() {
        var show = Show.starter()
        let cams = show.sortedCameras
        show.placeCamera(cams[0].id, x: 0.3, y: 1.4)
        XCTAssertEqual(show.plot.marker(cams[0].id)?.y, 1, "clamped to the plan")
        show.placeCamera(cams[0].id, x: 0.4, y: 0.5)
        XCTAssertEqual(show.plot.markers.count, 1)
        XCTAssertEqual(show.plot.marker(cams[0].id)?.x, 0.4)
        show.updatePlotMarker(cams[0].id) { $0.angle = -90; $0.lens = "86x box" }
        XCTAssertEqual(show.plot.marker(cams[0].id)?.angle, 270)
        show.placeCamera(UUID(), x: 0.5, y: 0.5)
        XCTAssertEqual(show.plot.markers.count, 1, "unknown cameras are ignored")
        XCTAssertEqual(show.unplottedCameras.count, cams.count - 1)
        show.placeRemainingCameras()
        XCTAssertTrue(show.unplottedCameras.isEmpty)
        XCTAssertEqual(show.plot.marker(cams[0].id)?.x, 0.4, "placed cameras stay put")
        show.removeFromPlot(cams[1].id)
        XCTAssertNil(show.plot.marker(cams[1].id))
        _ = show.deleteCamera(cams[0].id)
        XCTAssertNil(show.plot.marker(cams[0].id), "deleting a camera takes it off the plot")
    }

    func testPlotSurvivesSavingAndOldFiles() throws {
        var show = Show.starter()
        show.placeCamera(show.sortedCameras[0].id, x: 0.2, y: 0.8)
        show.updatePlotMarker(show.sortedCameras[0].id) { $0.note = "FOH riser" }
        show.plot.background = Data([1, 2, 3])
        let data = try JSONEncoder().encode(show)
        let back = try JSONDecoder().decode(Show.self, from: data)
        XCTAssertEqual(back.plot, show.plot)

        // A show saved before plots existed opens with an empty plot.
        var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        dict.removeValue(forKey: "plot")
        let old = try JSONDecoder().decode(Show.self, from: JSONSerialization.data(withJSONObject: dict))
        XCTAssertTrue(old.plot.markers.isEmpty)
        XCTAssertNil(old.plot.background)
    }
}

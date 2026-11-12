import XCTest
@testable import OnCueCore

final class TourTests: XCTestCase {
    private func night(_ show: Show, start: Date, label: String, late: Double, skipLast: Bool) -> SwitchLog {
        let main = show.mainOutput!
        var log = SwitchLog(showID: show.id, showName: show.name, started: start, night: label, operators: ["1": "Sam"])
        let song = show.items[0]
        let rows = show.shotRows(forItem: song.id)
        for (k, row) in rows.enumerated() {
            let t = start.addingTimeInterval(Double(k) * 4)
            log.entries.append(SwitchLogEntry(kind: .scripted, date: t, outputID: main.id, cameraID: row.cue.cameraID,
                                              itemID: song.id, shotNumber: row.number, mode: "cut"))
            if skipLast && k == rows.count - 1 { continue }
            let cam = show.camera(row.cue.cameraID)
            log.entries.append(SwitchLogEntry(kind: .cut, date: t.addingTimeInterval(late), switcherID: main.switcherID,
                                              input: cam?.input, cameraID: cam?.id, itemID: song.id, mode: "cut"))
        }
        // The next song starts, closing the first one's run.
        log.entries.append(SwitchLogEntry(kind: .scripted, date: start.addingTimeInterval(Double(rows.count) * 4), outputID: main.id,
                                          itemID: show.items[1].id, shotNumber: 1, mode: "cut"))
        return log
    }

    func testNightsCompared() throws {
        let show = Show.sample()
        let rows = show.shotRows(forItem: show.items[0].id)
        let d1 = Date(timeIntervalSince1970: 1_800_000_000), d2 = d1.addingTimeInterval(86_400)
        let other = SwitchLog(showID: UUID(), showName: "Other", started: d1)
        let tour = TourComparison(show: show, logs: [night(show, start: d2, label: "Night 2", late: 0.2, skipLast: true),
                                                     night(show, start: d1, label: "Night 1", late: 0.1, skipLast: false), other])
        XCTAssertEqual(tour.nights.map(\.log.night), ["Night 1", "Night 2"], "oldest first, other shows left out")
        let first = try XCTUnwrap(tour.nights[0].items[show.items[0].id])
        XCTAssertEqual(first.scripted, rows.count)
        XCTAssertEqual(first.hits, rows.count)
        XCTAssertEqual(first.averageOffset!, 0.1, accuracy: 1e-3)
        XCTAssertEqual(first.length!, Double(rows.count) * 4, accuracy: 1e-6)
        let second = try XCTUnwrap(tour.nights[1].items[show.items[0].id])
        XCTAssertEqual(second.hits, rows.count - 1)
        XCTAssertEqual(tour.nights[1].log.operators["1"], "Sam")
    }

    func testOldLogsWithoutTourFieldsStillOpen() throws {
        let show = Show.sample()
        let log = night(show, start: Date(timeIntervalSince1970: 1_800_000_000), label: "", late: 0, skipLast: false)
        var json = try JSONSerialization.jsonObject(with: log.encoded()) as! [String: Any]
        json.removeValue(forKey: "night")
        json.removeValue(forKey: "operators")
        let back = try SwitchLog.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(back.night, "")
        XCTAssertEqual(back.entries.count, log.entries.count)
        XCTAssertFalse(back.nightName.isEmpty, "falls back to the date")
    }

    func testLoadLogsFromFolder() throws {
        let show = Show.sample()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("oncue-tour-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let log = night(show, start: Date(), label: "Night 1", late: 0, skipLast: false)
        try log.encoded().write(to: folder.appendingPathComponent(log.fileName))
        try Data("junk".utf8).write(to: folder.appendingPathComponent("broken.\(SwitchLog.fileExtension)"))
        XCTAssertEqual(TourComparison.loadLogs(in: folder).count, 1)
    }
}

import XCTest
import CoreGraphics
@testable import OnCueCore

/// Script and switch log exports: CSV, EDL and PDF.
final class ExportTests: XCTestCase {

    func testCSVQuoting() {
        XCTAssertEqual(CSV.line(["a", "b,c", "say \"hi\"", "two\nlines"]), "a,\"b,c\",\"say \"\"hi\"\"\",\"two\nlines\"")
    }

    func testScriptCSVHasEveryShot() {
        let show = Show.sample()
        let csv = show.scriptCSV()
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        let total = show.items.reduce(0) { $0 + show.shotRows(forItem: $1.id).count }
        XCTAssertEqual(lines.count, total + 1, "header plus one line per main-output shot")
        XCTAssertTrue(lines[0].hasPrefix("Item,Kind,Output,Shot,Position"))
        let first = show.shotRows(forItem: show.items[0].id)[0]
        let cam = show.camera(first.cue.cameraID)!
        XCTAssertTrue(lines[1].contains(",\(cam.number),"))
        XCTAssertTrue(lines[1].hasPrefix(CSV.field(show.items[0].title)))
    }

    func testTimecodeMath() {
        XCTAssertEqual(EDLTimecode.string(frames: 25 * 3600 + 25 * 61 + 3, fps: 25), "01:01:01:03")
        XCTAssertEqual(EDLTimecode.parse("01:01:01:03", fps: 25), 25 * 3600 + 25 * 61 + 3)
        XCTAssertEqual(EDLTimecode.frames(seconds: 1.5, fps: 30), 45)
    }

    private func logWithCuts(_ show: Show, timecodes: Bool) -> SwitchLog {
        let main = show.mainOutput!.switcherID!
        let cams = show.sortedCameras
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var log = SwitchLog(showID: show.id, showName: show.name, started: start)
        for (k, offset) in [0.0, 2.0, 5.5].enumerated() {
            log.entries.append(SwitchLogEntry(kind: .cut, date: start.addingTimeInterval(offset),
                                              timecode: timecodes ? EDLTimecode.string(frames: 25 * 3600 + Int(offset * 25), fps: 25) : nil,
                                              switcherID: main, input: cams[k].input, cameraID: cams[k].id,
                                              itemID: show.items[0].id, shotNumber: k + 1, mode: "Auto cut"))
        }
        log.entries.append(SwitchLogEntry(kind: .scripted, date: start.addingTimeInterval(8), outputID: show.mainOutput!.id,
                                          cameraID: cams[0].id, itemID: show.items[0].id, shotNumber: 4, mode: "Auto cut"))
        return log
    }

    func testSwitchLogEDLUsesLTC() {
        let show = Show.sample()
        let edl = logWithCuts(show, timecodes: true).edl(show: show, fps: 25)
        let events = edl.components(separatedBy: "\n").filter { $0.first?.isNumber == true }
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(edl.hasPrefix("TITLE: \(show.name)\nFCM: NON-DROP FRAME"))
        let cams = show.sortedCameras
        XCTAssertTrue(events[0].hasPrefix("001  CAM\(cams[0].number)"))
        XCTAssertTrue(events[0].hasSuffix("01:00:00:00 01:00:02:00 01:00:00:00 01:00:02:00"))
        XCTAssertTrue(events[1].hasSuffix("01:00:02:00 01:00:05:12 01:00:02:00 01:00:05:12"), events[1])
        // The last cut runs to the last logged moment (2.5 s later).
        XCTAssertTrue(events[2].hasSuffix("01:00:05:12 01:00:08:00 01:00:05:12 01:00:08:00"), events[2])
        XCTAssertTrue(edl.contains("* FROM CLIP NAME: \(cams[1].number) \(cams[1].displayName)"))
        XCTAssertTrue(edl.contains("* COMMENT: \(show.items[0].title)"))
    }

    func testSwitchLogEDLFallsBackToTimeOfDay() {
        let show = Show.sample()
        let log = logWithCuts(show, timecodes: false)
        let edl = log.edl(show: show, fps: 25)
        let events = edl.components(separatedBy: "\n").filter { $0.first?.isNumber == true }
        XCTAssertEqual(events.count, 3)
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: log.entries[0].date)
        let tod = String(format: "%02d:%02d:%02d:00", c.hour!, c.minute!, c.second!)
        XCTAssertTrue(events[0].contains(" \(tod) "), events[0])
    }

    func testSwitchLogCSV() {
        let show = Show.sample()
        let csv = logWithCuts(show, timecodes: true).csv(show: show)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 5)
        XCTAssertTrue(lines[1].contains(",Cut,"))
        XCTAssertTrue(lines[4].contains(",Scripted,"))
        XCTAssertTrue(lines[1].contains("01:00:00:00"))
    }

    func testMarkerEDL() {
        let show = Show.sample()
        let song = show.items[0]
        let edl = show.markerEDL(itemID: song.id, fps: 25)!
        let rows = show.shotRows(forItem: song.id)
        XCTAssertEqual(edl.components(separatedBy: "|M:").count - 1, rows.count)
        XCTAssertTrue(edl.contains("|M:Shot 1 "))
        let second = 25 * 3600 + EDLTimecode.frames(seconds: song.seconds(for: rows[1].cue.at), fps: 25)
        XCTAssertTrue(edl.contains("002  001      V     C        \(EDLTimecode.string(frames: second, fps: 25))"))
        // Order-based segments have no times to mark.
        var s = Show.starter()
        s.updateItem(s.items[0].id) { $0.timeBase = .order }
        XCTAssertNil(s.markerEDL(itemID: s.items[0].id, fps: 25))
    }

    private func pageCount(_ data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider) else { return 0 }
        return doc.numberOfPages
    }

    func testCameraScriptPDF() {
        let show = Show.sample()
        let all = show.cameraScriptPDF(paper: .a4)
        XCTAssertGreaterThanOrEqual(pageCount(all), show.items.count, "each song starts a page")
        let one = show.cameraScriptPDF(itemIDs: [show.items[0].id], paper: .letter)
        XCTAssertGreaterThanOrEqual(pageCount(one), 1)
        XCTAssertLessThan(pageCount(one), pageCount(all))
        // A long song runs over several pages.
        var long = Show.starter()
        let song = long.items[0].id
        for k in 0..<120 { long.addShot(inItem: song, cameraID: long.sortedCameras[k % 3].id, at: Double(k * 4)) }
        XCTAssertGreaterThan(pageCount(long.cameraScriptPDF(itemIDs: [song])), 2)
    }

    func testCallSheetsOnePerCamera() {
        let show = Show.sample()
        let data = show.callSheetsPDF(paper: .a4)
        XCTAssertGreaterThanOrEqual(pageCount(data), show.cameras.count)
        XCTAssertLessThan(pageCount(show.callSheetsPDF(cameraIDs: [show.sortedCameras[0].id])), pageCount(data))
        XCTAssertEqual(pageCount(Show().callSheetsPDF()), 1, "empty show still gives a page saying so")
    }

    func testResolveMarkerColour() {
        XCTAssertEqual(EDL.markerColor("#2050FF"), "Blue")
        XCTAssertEqual(EDL.markerColor("#FFD030"), "Yellow")
        XCTAssertEqual(EDL.markerColor(nil), "Blue")
    }
}

import XCTest
@testable import OnCueCore

final class RundownTimingTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Three segments of 10, 5 and 20 minutes; the third must be off by 21:00.
    private func show() -> Show {
        var show = Show.starter()
        show.items = [RundownItem(kind: .segment, title: "Pre-show", timeBase: .seconds, plannedDuration: 600),
                      RundownItem(kind: .segment, title: "Draft", timeBase: .seconds, plannedDuration: 300),
                      RundownItem(kind: .segment, title: "Finals", timeBase: .seconds, plannedDuration: 1200, hardOut: "21:00")]
        return show
    }

    private func at(_ hh: Int, _ mm: Int, _ ss: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: hh, minute: mm, second: ss))!
    }

    private func log(_ show: Show, _ calls: [(Int, Date)]) -> SwitchLog {
        var log = SwitchLog(showID: show.id, showName: show.name, started: calls[0].1)
        for (k, (index, date)) in calls.enumerated() {
            log.entries.append(SwitchLogEntry(kind: .scripted, date: date, outputID: show.mainOutput?.id,
                                              itemID: show.items[index].id, shotNumber: k + 1, mode: "display"))
        }
        return log
    }

    func testRunsFromTheLog() {
        let s = show()
        let l = log(s, [(0, at(20, 0)), (0, at(20, 3)), (1, at(20, 11)), (1, at(20, 12))])
        let runs = RundownTiming.runs(log: l, mainOutput: s.mainOutput?.id)
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(runs[0].length, 660)
        XCTAssertNil(runs[1].ended)
    }

    func testOverUnderAndHardOut() {
        let s = show()
        // Pre-show ran 11 minutes (1 over); Draft has run 3 minutes.
        let l = log(s, [(0, at(20, 0)), (1, at(20, 11))])
        let t = RundownTiming(show: s, log: l, itemID: s.items[1].id, now: at(20, 14), calendar: calendar)
        XCTAssertEqual(t.planned, 300)
        XCTAssertEqual(t.elapsed, 180)
        XCTAssertEqual(t.remaining, 120)
        XCTAssertEqual(t.showOffset, 60)
        XCTAssertEqual(t.finishedPlanned, 1)
        XCTAssertNil(t.hardOutIn)
        // Draft ends 20:16, Finals 20 minutes later at 20:36: 24 minutes spare for the 21:00 out.
        XCTAssertEqual(t.forecastEnd, at(20, 36))
        XCTAssertEqual(t.nextHardOut?.title, "Finals")
        XCTAssertEqual(t.nextHardOut?.margin, 24 * 60)

        // Finals on air at 20:50, started 20:45: 10 minutes to its hard out, and it will run 5 late.
        let l2 = log(s, [(0, at(20, 0)), (1, at(20, 11)), (2, at(20, 45))])
        let f = RundownTiming(show: s, log: l2, itemID: s.items[2].id, now: at(20, 50), calendar: calendar)
        XCTAssertEqual(f.hardOutIn, 600)
        XCTAssertEqual(f.showOffset, 60 + 1740, "Draft ran 34 minutes against 5")
        XCTAssertEqual(f.nextHardOut?.margin, -300)
    }

    func testOverrunShowsNegativeRemaining() {
        let s = show()
        let l = log(s, [(0, at(20, 0))])
        let t = RundownTiming(show: s, log: l, itemID: s.items[0].id, now: at(20, 12), calendar: calendar)
        XCTAssertEqual(t.remaining, -120)
        // The overrun pushes the forecast: nothing more of Pre-show, then 5 + 20 minutes.
        XCTAssertEqual(t.forecastEnd, at(20, 37))
    }

    func testDeadlineAcrossMidnight() {
        let late = at(23, 30)
        XCTAssertEqual(RundownTiming.deadline("00:15", around: late, calendar: calendar), at(23, 30).addingTimeInterval(45 * 60))
        XCTAssertEqual(RundownTiming.deadline("23:00", around: at(0, 30), calendar: calendar)?.timeIntervalSince(at(0, 30)), -90 * 60)
        XCTAssertEqual(RundownTiming.deadline("21:40", around: at(8, 40), calendar: calendar), at(21, 40), "tonight, not last night")
        XCTAssertNil(RundownTiming.deadline("25:00", around: late, calendar: calendar))
    }

    func testAppliesOnlyWhenTimed() {
        XCTAssertTrue(RundownTiming.applies(to: show()))
        XCTAssertFalse(RundownTiming.applies(to: Show.starter()))
    }
}

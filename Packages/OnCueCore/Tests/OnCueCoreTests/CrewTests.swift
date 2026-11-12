import XCTest
@testable import OnCueCore

/// The crew page: what phones are sent, comments, and the HTTP server itself on localhost.
final class CrewTests: XCTestCase {

    private func show() -> (Show, UUID) {
        var show = Show.starter()
        let song = show.items[0].id
        show.updateItem(song) { $0.sections = [SongSection(name: "Verse", at: 0), SongSection(name: "Chorus", at: 8)] }
        for (k, at) in [0.0, 4, 8].enumerated() {
            show.addShot(inItem: song, cameraID: show.sortedCameras[k].id, at: at)
        }
        return (show, song)
    }

    private func status(item: UUID, index: Int, position: Double) -> EngineStatus {
        EngineStatus(itemID: item, index: index, position: position, transport: .running, modes: [:], pauseReason: nil,
                     freeMode: false, loopSectionID: nil, takenAt: nil, secondsToNext: nil, timing: .internalClock,
                     timingSignal: true, tempo: nil, timecode: nil, switchers: [], hints: [], logFile: nil, cutCount: 0)
    }

    func testReviewSnapshotHasEveryItem() {
        let (show, _) = show()
        let snap = show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 3)
        XCTAssertFalse(snap.live)
        XCTAssertEqual(snap.items.count, show.items.count)
        XCTAssertEqual(snap.items[0].shots.map(\.camera), [1, 2, 3])
        XCTAssertEqual(snap.items[0].shots.map(\.number), [1, 2, 3])
        XCTAssertNil(snap.items[0].shots[1].secondsUntil, "no countdown outside Live Mode")
        XCTAssertEqual(snap.cameras.count, show.cameras.count)
        XCTAssertEqual(snap.scriptVersion, 3)
    }

    func testLiveSnapshotTallyAndCountdown() {
        let (show, song) = show()
        let item = show.item(song)!
        let snap = show.crewSnapshot(status: status(item: song, index: 0, position: 2), position: 2, running: true, scriptVersion: 0)
        XCTAssertTrue(snap.live)
        XCTAssertEqual(snap.items.count, 1)
        XCTAssertEqual(snap.program, 1, "script on air when no switcher reports")
        XCTAssertEqual(snap.preview, 2)
        XCTAssertEqual(snap.section, "Verse")
        let rows = show.shotRows(forItem: song)
        XCTAssertEqual(snap.nowShotID, rows[0].id.uuidString)
        XCTAssertEqual(snap.nextShotID, rows[1].id.uuidString)
        XCTAssertNil(snap.items[0].shots[0].secondsUntil, "past shots have no countdown")
        XCTAssertEqual(snap.items[0].shots[1].secondsUntil!, item.seconds(for: 2), accuracy: 1e-9)
        XCTAssertEqual(snap.items[0].shots[2].secondsUntil!, item.seconds(for: 6), accuracy: 1e-9)

        let still = show.crewSnapshot(status: status(item: song, index: 0, position: 2), position: 2, running: false, scriptVersion: 0)
        XCTAssertNil(still.items[0].shots[1].secondsUntil, "no countdown while nothing moves")
    }

    func testCommentsFromThePage() {
        var (show, song) = show()
        let cue = show.shotRows(forItem: song)[1].id
        XCTAssertTrue(show.addComment(itemID: song.uuidString, cueID: cue.uuidString, author: "  ", text: " Too wide here "))
        XCTAssertFalse(show.addComment(itemID: song.uuidString, cueID: cue.uuidString, author: "A", text: "   "))
        XCTAssertFalse(show.addComment(itemID: UUID().uuidString, cueID: nil, author: "A", text: "Unknown song"))
        XCTAssertEqual(show.comments.count, 1)
        XCTAssertEqual(show.comments[0].author, "Crew")
        XCTAssertEqual(show.comments[0].text, "Too wide here")
        let snap = show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 0)
        XCTAssertEqual(snap.items[0].shots[1].comments.map(\.text), ["Too wide here"])
        show.setCommentResolved(show.comments[0].id, true)
        XCTAssertTrue(show.comments[0].resolved)
        show.deleteComment(show.comments[0].id)
        XCTAssertTrue(show.comments.isEmpty)
    }

    func testRequestParsingWaitsForTheBody() {
        let head = "POST /api/comment?x=1 HTTP/1.1\r\nHost: a\r\nContent-Length: 5\r\n\r\n"
        XCTAssertNil(HTTPRequest.parse(Data((head + "ab").utf8)))
        let r = HTTPRequest.parse(Data((head + "abcde").utf8))
        XCTAssertEqual(r?.method, "POST")
        XCTAssertEqual(r?.path, "/api/comment")
        XCTAssertEqual(r.map { String(decoding: $0.body, as: UTF8.self) }, "abcde")
        XCTAssertNil(HTTPRequest.parse(Data("GET / HTTP/1.1\r\n".utf8)))
    }

    func testServerOnLocalhost() throws {
        let (show, _) = show()
        let server = CrewServer()
        let ready = expectation(description: "listening")
        var port: UInt16 = 0
        server.start(port: 0) { result in
            if case .success(let p) = result { port = p }
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)
        defer { server.stop() }
        XCTAssertGreaterThan(port, 0)
        server.update(show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 7))

        // The page.
        let page = try fetch("http://127.0.0.1:\(port)/")
        XCTAssertTrue(String(decoding: page, as: UTF8.self).contains("Which camera are you on?"))

        // The state (give the server queue a moment to store it).
        var state: [String: Any] = [:]
        for _ in 0..<20 {
            let data = try fetch("http://127.0.0.1:\(port)/api/state")
            state = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if state["scriptVersion"] as? Int == 7 { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertEqual(state["scriptVersion"] as? Int, 7)
        XCTAssertEqual(state["showName"] as? String, show.name)

        // A comment arrives on the main thread.
        let commented = expectation(description: "comment")
        server.onComment = { item, cue, author, text in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(author, "Cam 2")
            XCTAssertEqual(text, "Lens change")
            XCTAssertEqual(item, "i")
            XCTAssertNil(cue)
            commented.fulfill()
        }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/comment")!)
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"itemID":"i","author":"Cam 2","text":"Lens change"}"#.utf8)
        let posted = expectation(description: "posted")
        var statusCode = 0
        URLSession.shared.dataTask(with: request) { _, response, _ in
            statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            posted.fulfill()
        }.resume()
        wait(for: [posted, commented], timeout: 5)
        XCTAssertEqual(statusCode, 204)

        // Unknown paths.
        XCTAssertEqual(try status("http://127.0.0.1:\(port)/nope"), 404)
    }

    func testEventStreamSendsStateAndUpdates() throws {
        var (show, _) = show()
        let server = CrewServer()
        let ready = expectation(description: "listening")
        var port: UInt16 = 0
        server.start(port: 0) { result in
            if case .success(let p) = result { port = p }
            ready.fulfill()
        }
        wait(for: [ready], timeout: 5)
        defer { server.stop() }
        server.update(show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 1))
        Thread.sleep(forTimeInterval: 0.1)

        let reader = StreamReader()
        let clientsSeen = expectation(description: "client counted")
        server.onClientsChanged = { if $0 == 1 { clientsSeen.fulfill() } }
        let task = reader.session.dataTask(with: URL(string: "http://127.0.0.1:\(port)/events")!)
        task.resume()
        defer { task.cancel() }
        wait(for: [clientsSeen], timeout: 5)
        XCTAssertTrue(reader.wait(for: #""scriptVersion":1"#, timeout: 5), "first event carries the state")

        show.name = "Renamed"
        server.update(show.crewSnapshot(status: nil, position: nil, running: false, scriptVersion: 2))
        XCTAssertTrue(reader.wait(for: #""scriptVersion":2"#, timeout: 5), "updates are pushed")
        XCTAssertTrue(reader.text.contains("Renamed"))
    }

    // MARK: Helpers

    private func fetch(_ url: String) throws -> Data {
        let done = expectation(description: url)
        var result: Data?
        URLSession.shared.dataTask(with: URL(string: url)!) { data, _, _ in result = data; done.fulfill() }.resume()
        wait(for: [done], timeout: 5)
        return try XCTUnwrap(result)
    }

    private func status(_ url: String) throws -> Int {
        let done = expectation(description: url)
        var code = 0
        URLSession.shared.dataTask(with: URL(string: url)!) { _, r, _ in code = (r as? HTTPURLResponse)?.statusCode ?? 0; done.fulfill() }.resume()
        wait(for: [done], timeout: 5)
        return code
    }
}

/// Collects a streaming response as it arrives.
private final class StreamReader: NSObject, URLSessionDataDelegate {
    private let lock = NSLock()
    private var buffer = Data()
    lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    var text: String { lock.lock(); defer { lock.unlock() }; return String(decoding: buffer, as: UTF8.self) }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock(); buffer.append(data); lock.unlock()
    }

    func wait(for needle: String, timeout: TimeInterval) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if text.contains(needle) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return false
    }
}

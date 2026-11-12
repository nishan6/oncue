import XCTest
@testable import OnCueCore

final class MediaPoolTests: XCTestCase {
    func testGuessKind() {
        XCTAssertEqual(MediaKind.guess(for: URL(fileURLWithPath: "/a/Click 128.wav")), .songAudio)
        XCTAssertEqual(MediaKind.guess(for: URL(fileURLWithPath: "/a/intro.MOV")), .playerClip)
        XCTAssertEqual(MediaKind.guess(for: URL(fileURLWithPath: "/a/logo.png")), .still)
        XCTAssertNil(MediaKind.guess(for: URL(fileURLWithPath: "/a/notes.txt")))
    }

    func testUsageImportAndUnused() {
        var p = Project.starter(name: "T", frameRate: .r25)
        p.playlists[0].items[0].media = ItemMedia(path: "/show/song1.wav", kind: .audio)
        XCTAssertEqual(p.collectItemMedia(), 1)
        XCTAssertEqual(p.collectItemMedia(), 0, "only once")
        let new = p.importMedia([("/show/Intro loop.mov", nil, .playerClip, 12), ("/show/logo.png", nil, .still, nil),
                                 ("/show/song1.wav", nil, .songAudio, nil)])
        XCTAssertEqual(new.count, 2, "song1.wav is already in the pool")
        let item = p.playlists[0].items[0].id
        var show = p.show(playlist: nil)
        if let c = show.addTrackCue(.player, inItem: item, at: 0) {
            show.updateCue(c, inItem: item) { $0.clip = "Intro loop" }
        }
        p.apply(show, playlist: p.playlists[0].id)
        let clip = p.media.first { $0.name == "Intro loop" }!
        XCTAssertEqual(p.mediaUsage(clip).count, 1)
        XCTAssertEqual(p.mediaUsage(p.media[0]).first?.place, .itemMedia)
        XCTAssertEqual(p.unusedMedia.map(\.name), ["logo"])
    }

    func testRelinkUpdatesSongs() {
        var p = Project.starter(name: "T", frameRate: .r25)
        p.playlists[0].items[0].media = ItemMedia(path: "/old/song1.wav", kind: .audio)
        p.collectItemMedia()
        p.relink(p.media[0].id, to: "/new/song1.wav", bookmark: nil)
        XCTAssertEqual(p.media[0].path, "/new/song1.wav")
        XCTAssertEqual(p.playlists[0].items[0].media?.path, "/new/song1.wav")
    }

    func testRelinkByFolderNeverGuesses() {
        let a = MediaAsset(path: "/old/Show A/intro.mov", kind: .playerClip)
        let b = MediaAsset(path: "/old/Show B/intro.mov", kind: .playerClip)
        let c = MediaAsset(path: "/old/x/logo.png", kind: .still)
        let d = MediaAsset(path: "/old/y/gone.wav", kind: .songAudio)
        let found = MediaRelink.matches(missing: [a, b, c, d], candidates: [
            "/drive/Show A/intro.mov", "/drive/Show B/intro.mov", "/drive/gfx/LOGO.png",
        ])
        XCTAssertEqual(found[a.id], "/drive/Show A/intro.mov")
        XCTAssertEqual(found[b.id], "/drive/Show B/intro.mov")
        XCTAssertEqual(found[c.id], "/drive/gfx/LOGO.png")
        XCTAssertNil(found[d.id])
        let ambiguous = MediaRelink.matches(missing: [MediaAsset(path: "/o/z/intro.mov", kind: .playerClip)],
                                            candidates: ["/d/1/intro.mov", "/d/2/intro.mov"])
        XCTAssertTrue(ambiguous.isEmpty)
    }

    func testPoolRoundTrip() throws {
        var p = Project.starter(name: "T", frameRate: .r25)
        p.importMedia([("/show/logo.png", nil, .still, nil)])
        p.media[0].notes = "Sponsor"
        let data = try ProjectCoding.encode(p)
        guard case .project(let back) = try ProjectCoding.decode(data) else { return XCTFail("not a project") }
        XCTAssertEqual(back.media.first?.notes, "Sponsor")
        XCTAssertEqual(back.media.first?.kind, .still)
        XCTAssertEqual(back.media.first?.name, "logo")
    }
}

import Foundation

extension Show {
    /// A realistic sample production: eight cameras, three songs and a segment with scripted shots.
    /// Built only through the public editing API, so it doubles as an end-to-end editing check.
    public static func sample() -> Show {
        var show = Show.starter()
        show.name = "Live at the Arena"
        show.items.removeAll()

        // Cameras 1-4 exist in the starter show; name them and add 5-8.
        let crew: [(String, String)] = [("Wide", "Arjun"), ("Centre", "Meera"), ("Stage left", "Kabir"),
                                        ("Stage right", "Sana"), ("Jib", "Rohan"), ("Drums", "Isha"),
                                        ("Steadicam", "Dev"), ("Crowd", "Tara")]
        while show.cameras.count < crew.count { show.addCamera() }
        for (k, cam) in show.sortedCameras.enumerated() where k < crew.count {
            show.updateCamera(cam.id) { $0.name = crew[k].0; $0.operatorName = crew[k].1 }
        }
        let cams = show.sortedCameras.map(\.id)

        // Song 1: four on the floor, sections and a dense cut.
        let opener = show.addSong(title: "Neon Skyline")
        show.updateItem(opener) { $0.bpm = 128; $0.sections = [] }
        let sec1 = ["Intro", "Verse 1", "Pre-chorus", "Chorus", "Verse 2", "Chorus 2", "Outro"]
        let lengths = [8, 16, 8, 16, 16, 16, 8]
        var bar = 0
        for (k, name) in sec1.enumerated() {
            show.addSection(toItem: opener, name: name, at: Double(bar * 4))
            bar += lengths[k]
        }
        let openerShots: [(Int, Int, String, String, TransitionKind)] = [
            (0, 1, "Wide, lights up", "Hold for the reveal", .auto), (4, 5, "Jib push in", "Slow, land on the vocalist", .cut),
            (8, 2, "Vocals, mid", "", .cut), (12, 3, "Guitar, tight on hands", "", .cut),
            (16, 2, "Vocals, close", "Hold eyeline", .cut), (20, 6, "Drums, overhead", "", .cut),
            (24, 7, "Steadicam orbit", "Clockwise, start stage left", .auto), (28, 4, "Keys, mid", "", .cut),
            (32, 1, "Wide, chorus hit", "", .cut), (34, 8, "Crowd, hands up", "", .cut),
            (36, 2, "Vocals, close", "", .cut), (40, 5, "Jib high wide", "", .auto),
            (48, 3, "Guitar solo, tight", "Follow the neck", .cut), (56, 2, "Vocals, mid", "", .cut),
            (64, 1, "Wide", "", .cut), (68, 8, "Crowd", "", .cut), (72, 5, "Jib sweep", "", .auto),
            (80, 2, "Vocals, close, final line", "", .cut), (84, 1, "Wide, blackout", "Hold to black", .auto)
        ]
        for s in openerShots { addSampleShot(&show, opener, bars: s.0, cam: cams[s.1 - 1], text: s.2, note: s.3, transition: s.4) }
        let openerLyrics: [(Int, String)] = [
            (8, "City lights are calling out my name"), (12, "Running through the static of the rain"),
            (24, "Hold on, hold on"), (32, "We are the neon skyline"), (36, "Burning till the morning light"),
            (40, "Every window tells a story"), (56, "We are the neon skyline"), (60, "Burning till the morning light")
        ]
        for l in openerLyrics { show.addTrackCue(.lyrics, inItem: opener, at: Double(l.0 * 4), text: l.1) }
        for n in [(32, "Pyro on the chorus hit"), (48, "Solo: stay on guitar until the chorus")] {
            show.addTrackCue(.notes, inItem: opener, at: Double(n.0 * 4), text: n.1)
        }
        if let id = show.addTrackCue(.fx, inItem: opener, at: 0, text: "Band name lower third") {
            show.updateCue(id, inItem: opener) { $0.fxAction = .dskOn }
        }
        if let id = show.addTrackCue(.fx, inItem: opener, at: 8 * 4, text: "Lower third off") {
            show.updateCue(id, inItem: opener) { $0.fxAction = .dskOff }
        }
        if let id = show.addTrackCue(.fx, inItem: opener, at: 86 * 4, text: "Fade to black") {
            show.updateCue(id, inItem: opener) { $0.fxAction = .fadeToBlack }
        }

        // Song 2: slow ballad, long shots.
        let ballad = show.addSong(title: "Monsoon Letters")
        show.updateItem(ballad) { $0.bpm = 72; $0.beatsPerBar = 3; $0.sections = [] }
        for (k, name) in ["Intro", "Verse", "Chorus", "Bridge", "Final chorus"].enumerated() {
            show.addSection(toItem: ballad, name: name, at: Double(k * 8 * 3))
        }
        let balladShots: [(Int, Int, String, String)] = [
            (0, 5, "Jib descending", "Very slow"), (6, 2, "Vocals, close", ""), (12, 7, "Steadicam, side profile", ""),
            (16, 1, "Wide, warm wash", ""), (22, 2, "Vocals, extreme close", "Only if she closes her eyes"),
            (28, 8, "Crowd, phone lights", ""), (34, 3, "Guitar, soft focus", ""), (40, 2, "Vocals, close", "")
        ]
        for s in balladShots {
            addSampleShot(&show, ballad, bars: s.0, beatsPerBar: 3, cam: cams[s.1 - 1], text: s.2, note: s.3, transition: .auto)
        }
        for l in [(8, "Paper boats along the window"), (16, "Every drop a word you left me"), (24, "Somewhere past the rain")] {
            show.addTrackCue(.lyrics, inItem: ballad, at: Double(l.0 * 3), text: l.1)
        }

        // Segment: talk break, timed in seconds.
        let talk = show.addSegment(title: "Crowd talk break")
        show.updateItem(talk) { $0.plannedDuration = 180; $0.hardOut = "21:40"; $0.sections = [] }
        show.addSection(toItem: talk, name: "Welcome", at: 0)
        show.addSection(toItem: talk, name: "Band intros", at: 60)
        let talkShots: [(Double, Int, String)] = [(0, 2, "Vocals, mid, talking"), (20, 8, "Crowd reaction"),
                                                   (40, 1, "Wide"), (60, 3, "Guitarist, intro"), (75, 6, "Drummer, intro"),
                                                   (90, 4, "Keys, intro"), (110, 2, "Vocals, mid")]
        for s in talkShots {
            if let id = show.addShot(inItem: talk, cameraID: cams[s.1 - 1], at: s.0) {
                show.updateCue(id, inItem: talk) { $0.text = s.2 }
            }
        }
        for n in [(0.0, "Host walks to centre"), (60.0, "Intros follow the host's order"), (150.0, "30 s warning to the host")] {
            show.addTrackCue(.notes, inItem: talk, at: n.0, text: n.1)
        }

        // Encore: no click, NEXT per shot.
        let encore = show.addSong(title: "Encore: Homecoming")
        show.updateItem(encore) { $0.sections = [] }
        show.setTimeBase(.order, forItem: encore)
        show.updateItem(encore) { $0.syncMode = .next }
        for (cam, text) in [(1, "Wide"), (2, "Vocals, close"), (8, "Crowd singing"), (5, "Jib over the crowd"), (1, "Wide, confetti")] {
            if let id = show.addShot(inItem: encore, cameraID: cams[cam - 1]) {
                show.updateCue(id, inItem: encore) { $0.text = text }
            }
        }
        return show
    }

    private static func addSampleShot(_ show: inout Show, _ item: UUID, bars: Int, beatsPerBar: Int = 4,
                                      cam: UUID, text: String, note: String, transition: TransitionKind) {
        guard let id = show.addShot(inItem: item, cameraID: cam, at: Double(bars * beatsPerBar)) else { return }
        show.updateCue(id, inItem: item) { c in
            c.text = text
            c.note = note
            c.transition = transition
        }
    }
}

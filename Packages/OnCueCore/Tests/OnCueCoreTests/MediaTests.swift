import XCTest
import AVFoundation
@testable import OnCueCore

final class MediaTests: XCTestCase {
    /// One second of silence, then one second of a half-level tone.
    private func makeAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oncue-\(UUID().uuidString).wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88_200)!
        buffer.frameLength = 88_200
        let samples = buffer.floatChannelData![0]
        for i in 0..<88_200 { samples[i] = i < 44_100 ? 0 : 0.5 * sin(Float(i) * 2 * .pi * 440 / 44_100) }
        try file.write(from: buffer)
        return url
    }

    func testWaveformPeaks() throws {
        let url = try makeAudio()
        defer { try? FileManager.default.removeItem(at: url) }
        let w = try Waveform.load(url: url, peaksPerSecond: 50)
        XCTAssertEqual(w.duration, 2, accuracy: 0.05)
        XCTAssertEqual(Double(w.peaks.count), 100, accuracy: 2)
        XCTAssertLessThan(w.peak(from: 0.1, to: 0.9), 0.02, "silence")
        XCTAssertEqual(Double(w.peak(from: 1.1, to: 1.9)), 0.5, accuracy: 0.05, "tone at half level")
        XCTAssertEqual(ItemMedia.kind(of: url), .audio)
    }

    func testMediaTimeMapping() {
        var item = RundownItem(title: "Song")
        item.bpm = 120
        XCTAssertNil(item.mediaTime(at: 0))
        item.media = ItemMedia(path: "/tmp/x.wav", kind: .audio, offset: 3.5)
        XCTAssertEqual(item.mediaTime(at: 8), 7.5, "8 beats at 120 = 4 s after the song start at 3.5 s")
        XCTAssertEqual(item.position(atMediaTime: 7.5), 8)
        item.timeBase = .seconds
        XCTAssertEqual(item.mediaTime(at: 10), 13.5)
        XCTAssertNil(ItemMedia(path: "/nope/missing.wav", kind: .audio).resolvedURL())
    }

    func testMediaSurvivesSaving() throws {
        var show = Show.starter()
        show.updateItem(show.items[0].id) { $0.media = ItemMedia(path: "/Volumes/Show/song.wav", kind: .audio, offset: 1.25) }
        let back = try ShowCoding.decode(ShowCoding.encode(show))
        XCTAssertEqual(back.items[0].media, show.items[0].media)
    }
}

final class TempoTests: XCTestCase {
    /// Kick-like hits at a tempo, from a first beat, over a quiet tone (a crude song).
    private func song(bpm: Double, firstBeat: Double, seconds: Double, rate: Double = 11_025) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        let period = 60 / bpm
        for i in 0..<n {
            let t = Double(i) / rate
            out[i] = Float(0.05 * sin(t * 2 * .pi * 220))
            if t >= firstBeat {
                let since = (t - firstBeat).truncatingRemainder(dividingBy: period)
                let beatIndex = Int((t - firstBeat) / period)
                let level = beatIndex % 4 == 0 ? 0.9 : 0.6
                out[i] += Float(level * exp(-since * 30) * sin(since * 2 * .pi * 60))
            }
        }
        return out
    }

    func testDetectsTempoAndFirstBeat() throws {
        for (bpm, first) in [(128.0, 0.41), (92.0, 1.2), (174.0, 0.05)] {
            let est = try XCTUnwrap(TempoDetector.detect(samples: song(bpm: bpm, firstBeat: first, seconds: 30), sampleRate: 11_025))
            // Half or double tempo is a matter of taste (the editor offers ×2 and ÷2); within that, exact.
            let octave = [bpm, bpm / 2, bpm * 2].min { abs($0 - est.bpm) < abs($1 - est.bpm) }!
            XCTAssertEqual(est.bpm, octave, accuracy: 1.0, "\(bpm) BPM")
            if bpm < 150 { XCTAssertEqual(octave, bpm, "common tempos are not halved or doubled") }
            // The first beat found may be any beat; it must sit on the grid.
            let period = 60 / max(bpm, octave)
            var off = (est.firstBeat - first).truncatingRemainder(dividingBy: period)
            if off > period / 2 { off -= period }
            if off < -period / 2 { off += period }
            XCTAssertEqual(off, 0, accuracy: 0.03, "\(bpm) BPM phase")
            XCTAssertGreaterThan(est.confidence, 0.2)
        }
    }

    func testSilenceHasNoTempo() {
        XCTAssertNil(TempoDetector.detect(samples: [Float](repeating: 0, count: 11_025 * 10), sampleRate: 11_025))
    }
}

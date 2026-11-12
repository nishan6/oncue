import Foundation
import AVFoundation

/// Reads a file's first audio track as mono samples at a chosen rate.
public enum AudioSamples {
    public static func read(url: URL, sampleRate: Double, maxSeconds: Double? = nil) throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        if let maxSeconds {
            reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: maxSeconds, preferredTimescale: 600))
        }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32,
                                       AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false,
                                       AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: sampleRate]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()
        var samples: [Float] = []
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var chunk = [Float](repeating: 0, count: length / 4)
            chunk.withUnsafeMutableBytes { raw in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            samples += chunk
        }
        if reader.status == .failed, let error = reader.error { throw error }
        return samples
    }
}

/// Tempo and first beat of a song, from its audio: an onset envelope (rise in loudness), its
/// autocorrelation for the beat period, then the phase that lines beats up with the onsets.
public struct TempoEstimate: Equatable {
    public let bpm: Double
    /// Seconds into the file of the first beat.
    public let firstBeat: Double
    /// 0...1: how clearly the beat stands out. Below about 0.3 the guess is weak.
    public let confidence: Double

    public init(bpm: Double, firstBeat: Double, confidence: Double) {
        self.bpm = bpm
        self.firstBeat = firstBeat
        self.confidence = confidence
    }
}

public enum TempoDetector {
    static let rate: Double = 11_025
    static let hop = 128

    public static func detect(url: URL, maxSeconds: Double = 120) throws -> TempoEstimate? {
        detect(samples: try AudioSamples.read(url: url, sampleRate: rate, maxSeconds: maxSeconds), sampleRate: rate)
    }

    public static func detect(samples: [Float], sampleRate: Double, minBPM: Double = 60, maxBPM: Double = 200) -> TempoEstimate? {
        let frameRate = sampleRate / Double(hop)
        let window = hop * 4
        guard samples.count > window * 8 else { return nil }

        // Onset envelope: positive change in log energy, frame by frame.
        var energies: [Double] = []
        var i = 0
        while i + window <= samples.count {
            var e: Double = 0
            for k in i..<(i + window) { let v = Double(samples[k]); e += v * v }
            energies.append(log(1e-9 + e / Double(window)))
            i += hop
        }
        var onset = [Double](repeating: 0, count: energies.count)
        for k in 1..<energies.count { onset[k] = max(0, energies[k] - energies[k - 1]) }
        // Remove the slow trend so loud sections don't dominate.
        let mean = onset.reduce(0, +) / Double(onset.count)
        onset = onset.map { max(0, $0 - mean) }
        guard onset.contains(where: { $0 > 0 }) else { return nil }

        // Autocorrelation over the beat periods allowed, weighted toward common tempos.
        let minLag = Int((60 / maxBPM) * frameRate), maxLag = Int((60 / minBPM) * frameRate)
        guard maxLag < onset.count / 2, minLag > 1 else { return nil }
        var scores = [Double](repeating: 0, count: maxLag + 2)
        var zero: Double = 0
        for k in 0..<onset.count { zero += onset[k] * onset[k] }
        for lag in max(1, minLag - 1)...(maxLag + 1) {
            var s: Double = 0
            for k in 0..<(onset.count - lag) { s += onset[k] * onset[k + lag] }
            scores[lag] = s
        }
        var best = minLag
        var bestValue = -Double.infinity
        for lag in minLag...maxLag {
            let bpm = 60 * frameRate / Double(lag)
            // Gentle preference around 120 BPM (log scale) to settle half/double tempo.
            let w = exp(-0.5 * pow(log2(bpm / 120) / 1.2, 2))
            // A real beat also shows at twice its period.
            let double = 2 * lag < scores.count ? scores[2 * lag] : 0
            let v = (scores[lag] + 0.5 * double) * w
            if v > bestValue { bestValue = v; best = lag }
        }
        // Sub-frame period by parabolic interpolation.
        var period = Double(best)
        if best > 1, best + 1 < scores.count {
            let a = scores[best - 1], b = scores[best], c = scores[best + 1]
            let d = a - 2 * b + c
            if d < 0 { period += 0.5 * (a - c) / d }
        }

        // Phase: the offset whose beat train collects the most onset.
        var bestPhase = 0
        var phaseValue = -Double.infinity
        for phase in 0..<max(1, Int(period.rounded())) {
            var s: Double = 0
            var t = Double(phase)
            while Int(t.rounded()) < onset.count {
                let k = Int(t.rounded())
                s += onset[k] + 0.5 * (k > 0 ? onset[k - 1] : 0) + 0.5 * (k + 1 < onset.count ? onset[k + 1] : 0)
                t += period
            }
            if s > phaseValue { phaseValue = s; bestPhase = phase }
        }

        // Refine: find the actual onset peak near each predicted beat and fit a straight line
        // through them. The autocorrelation period is only close, and a small period error
        // adds up over a song and drags the first beat off the grid; the fit removes that.
        var phase = Double(bestPhase)
        let fit = refineBeatGrid(onset: onset, phase: phase, period: period)
        if let fit { period = fit.period; phase = fit.phase }
        let bpm = 60 * frameRate / period

        // Frame k's energy covers samples k·hop ..< k·hop + window, so an attack at time T shows
        // as the rise into the frame whose window first reaches past it.
        let firstBeat = max(0, (phase * Double(hop) + Double(window - hop)) / sampleRate)

        let confidence = zero > 0 ? min(1, max(0, scores[best] / zero)) : 0
        return TempoEstimate(bpm: (bpm * 100).rounded() / 100, firstBeat: firstBeat, confidence: confidence)
    }

    /// Least-squares line through the onset peaks nearest each predicted beat (in onset frames).
    /// Returns nil when too few beats stand out to trust a fit.
    static func refineBeatGrid(onset: [Double], phase: Double, period: Double) -> (phase: Double, period: Double)? {
        guard period > 1, let peak = onset.max(), peak > 0 else { return nil }
        let threshold = 0.3 * peak
        var beats: [Double] = []
        var positions: [Double] = []
        var n = 0
        while true {
            let centre = phase + Double(n) * period
            if centre >= Double(onset.count) { break }
            let lo = max(0, Int((centre - period / 4).rounded()))
            let hi = min(onset.count - 1, Int((centre + period / 4).rounded()))
            if hi > lo {
                var k = lo
                for j in lo...hi where onset[j] > onset[k] { k = j }
                if onset[k] >= threshold {
                    var p = Double(k)
                    if k > 0, k + 1 < onset.count {
                        let a = onset[k - 1], b = onset[k], c = onset[k + 1]
                        let d = a - 2 * b + c
                        if d < 0 { p += 0.5 * (a - c) / d }
                    }
                    beats.append(Double(n))
                    positions.append(p)
                }
            }
            n += 1
        }
        guard beats.count >= 4 else { return nil }
        let count = Double(beats.count)
        let meanN = beats.reduce(0, +) / count
        let meanP = positions.reduce(0, +) / count
        var sxy: Double = 0
        var sxx: Double = 0
        for (x, y) in zip(beats, positions) {
            sxy += (x - meanN) * (y - meanP)
            sxx += (x - meanN) * (x - meanN)
        }
        guard sxx > 0 else { return nil }
        let slope = sxy / sxx
        guard slope > 1 else { return nil }
        var start = meanP - slope * meanN
        while start - slope >= 0 { start -= slope }
        while start < 0 { start += slope }
        return (start, slope)
    }
}

import Foundation
import AVFoundation

/// Song audio or a PGM recording loaded under a song's timeline to plan against.
/// The file stays where it is; the show keeps its path (and a bookmark, so a moved file is found).
public struct ItemMedia: Codable, Hashable {
    public enum Kind: String, Codable { case audio, video }
    public var path: String
    public var bookmark: Data?
    public var kind: Kind
    /// Where the song's start (position 0) is in the file, in seconds.
    public var offset: Double = 0

    public init(path: String, bookmark: Data? = nil, kind: Kind, offset: Double = 0) {
        self.path = path
        self.bookmark = bookmark
        self.kind = kind
        self.offset = offset
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        path = try c.value("path", "")
        bookmark = try c.value("bookmark", Data?.none)
        kind = try c.enumValue("kind", .audio)
        offset = try c.value("offset", 0.0)
    }

    public var name: String { (path as NSString).lastPathComponent }

    /// The file, following the bookmark when it moved.
    public func resolvedURL() -> URL? {
        if let bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path) { return url }
        }
        let url = URL(fileURLWithPath: path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public static func kind(of url: URL) -> Kind {
        let asset = AVURLAsset(url: url)
        return asset.tracks(withMediaType: .video).isEmpty ? .audio : .video
    }
}

extension RundownItem {
    /// Media time (seconds in the file) at a position in the song.
    public func mediaTime(at position: Double) -> Double? {
        guard let media else { return nil }
        return media.offset + seconds(for: position - (timeBase == .order ? 1 : 0))
    }

    /// Position in the song for a media time (inverse of mediaTime).
    public func position(atMediaTime t: Double) -> Double? {
        guard let media else { return nil }
        let s = t - media.offset
        switch timeBase {
        case .bars: return s * max(bpm, 1) / 60
        case .seconds: return s
        case .order: return s + 1
        }
    }
}

/// Peaks of a file's audio for drawing: the loudest sample in each slice, 0...1.
public struct Waveform: Equatable {
    public let peaksPerSecond: Double
    public let peaks: [Float]
    public let duration: Double

    public func peak(from t0: Double, to t1: Double) -> Float {
        guard !peaks.isEmpty, t1 > 0 else { return 0 }
        let a = max(0, Int(t0 * peaksPerSecond)), b = min(peaks.count, max(a + 1, Int(ceil(t1 * peaksPerSecond))))
        guard a < b else { return 0 }
        return peaks[a..<b].max() ?? 0
    }

    /// Reads the first audio track (of an audio or video file). Video without sound gives no peaks.
    public static func load(url: URL, peaksPerSecond: Double = 100) throws -> Waveform {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return Waveform(peaksPerSecond: peaksPerSecond, peaks: [], duration: duration.isFinite ? duration : 0)
        }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
                                       AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                                       AVLinearPCMIsNonInterleaved: false, AVNumberOfChannelsKey: 1, AVSampleRateKey: 8000]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()
        let perPeak = max(1, Int(8000 / peaksPerSecond))
        var peaks: [Float] = []
        peaks.reserveCapacity(Int(max(duration, 1) * peaksPerSecond) + 1)
        var current: Int16 = 0
        var count = 0
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var data = [Int16](repeating: 0, count: length / 2)
            data.withUnsafeMutableBytes { raw in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: raw.baseAddress!)
            }
            for sample in data {
                let m = sample == Int16.min ? Int16.max : abs(sample)
                if m > current { current = m }
                count += 1
                if count == perPeak {
                    peaks.append(Float(current) / Float(Int16.max))
                    current = 0
                    count = 0
                }
            }
        }
        if count > 0 { peaks.append(Float(current) / Float(Int16.max)) }
        if reader.status == .failed, let error = reader.error { throw error }
        return Waveform(peaksPerSecond: peaksPerSecond, peaks: peaks, duration: duration.isFinite ? duration : Double(peaks.count) / peaksPerSecond)
    }
}

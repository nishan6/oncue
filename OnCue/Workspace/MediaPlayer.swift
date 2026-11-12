import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers
import OnCueCore

/// Plays a song's audio or PGM video for planning, and keeps its waveform.
final class MediaPlayer: ObservableObject {
    @Published private(set) var itemID: UUID?
    @Published private(set) var playing = false
    /// Media time, seconds.
    @Published private(set) var time: Double = 0
    @Published private(set) var waveforms: [String: Waveform] = [:]
    @Published private(set) var loading: Set<String> = []
    @Published var videoWindowOpen = false

    let player = AVPlayer()
    private var loadedPath: String?
    private var observer: Any?
    private var videoWindow: NSWindow?

    init() {
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: .main) { [weak self] t in
            guard let self else { return }
            self.time = CMTimeGetSeconds(t)
            let isPlaying = self.player.rate != 0
            if isPlaying != self.playing { self.playing = isPlaying }
        }
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
    }

    /// Makes the player ready for an item's media (and starts reading its waveform).
    func prepare(_ item: RundownItem) {
        guard let media = item.media, let url = media.resolvedURL() else { return }
        if loadedPath != url.path {
            player.pause()
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            loadedPath = url.path
            time = 0
        }
        itemID = item.id
        loadWaveform(url)
    }

    func loadWaveform(_ url: URL) {
        let key = url.path
        guard waveforms[key] == nil, !loading.contains(key) else { return }
        loading.insert(key)
        DispatchQueue.global(qos: .userInitiated).async {
            let w = try? Waveform.load(url: url)
            DispatchQueue.main.async {
                self.loading.remove(key)
                if let w { self.waveforms[key] = w }
            }
        }
    }

    func waveform(for item: RundownItem) -> Waveform? {
        item.media?.resolvedURL().flatMap { waveforms[$0.path] }
    }

    func toggle(_ item: RundownItem) {
        prepare(item)
        guard player.currentItem != nil else { return }
        if player.rate != 0 { player.pause() } else { player.play() }
    }

    func pause() { player.pause() }

    /// Seeks to a song position (frame accurate).
    func seek(_ item: RundownItem, position: Double) {
        prepare(item)
        guard let t = item.mediaTime(at: position) else { return }
        let target = max(0, t)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        time = target
    }

    /// The song position the player is at, when it plays this item's media.
    func position(in item: RundownItem) -> Double? {
        guard itemID == item.id, item.media != nil else { return nil }
        return item.position(atMediaTime: time)
    }

    func unload() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        loadedPath = nil
        itemID = nil
        closeVideo()
    }

    // MARK: Video window

    func showVideo(title: String) {
        if let w = videoWindow { w.makeKeyAndOrderFront(nil); return }
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .minimal
        let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 640, height: 360),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        w.title = title
        w.contentView = view
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.contentAspectRatio = NSSize(width: 16, height: 9)
        w.makeKeyAndOrderFront(nil)
        videoWindow = w
        videoWindowOpen = true
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
            self?.videoWindow = nil
            self?.videoWindowOpen = false
        }
    }

    func closeVideo() {
        videoWindow?.close()
        videoWindow = nil
        videoWindowOpen = false
    }

    // MARK: Choosing a file

    /// Asks for song audio or a PGM video and attaches it to the item.
    static func choose(for item: RundownItem, model: WorkspaceModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .movie, .mpeg4Movie, .quickTimeMovie, .wav, .mp3, .aiff]
        panel.prompt = "Load Under Timeline"
        panel.message = "Song audio or a PGM recording to plan against."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard AVURLAsset(url: url).isPlayable else {
            model.errorMessage = "\(url.lastPathComponent) can't be played on this Mac."
            return
        }
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let media = ItemMedia(path: url.path, bookmark: bookmark, kind: ItemMedia.kind(of: url))
        model.edit("Load Media") { $0.updateItem(item.id) { $0.media = media } }
    }
}

// MARK: - Timeline lane

/// The waveform under the timeline. Click or drag to scrub.
struct MediaLane: View {
    let item: RundownItem
    @ObservedObject var player: MediaPlayer
    let metrics: TimelineMetrics
    let width: CGFloat

    var body: some View {
        let waveform = player.waveform(for: item)
        let missing = item.media?.resolvedURL() == nil
        ZStack(alignment: .leading) {
            LaneBackground(item: item, metrics: metrics, width: width)
            if let waveform, let media = item.media {
                Canvas { ctx, size in
                    let mid = size.height / 2
                    var path = Path()
                    let step: CGFloat = 2
                    var x: CGFloat = 0
                    while x < size.width {
                        let t0 = item.mediaTime(at: metrics.position(x)) ?? 0
                        let t1 = item.mediaTime(at: metrics.position(x + step)) ?? 0
                        if t1 > 0, t0 < waveform.duration {
                            let p = CGFloat(waveform.peak(from: max(t0, 0), to: t1))
                            let h = max(1, p * (size.height - 6) / 2)
                            path.addRect(CGRect(x: x, y: mid - h, width: step - 0.5, height: h * 2))
                        }
                        x += step
                    }
                    ctx.fill(path, with: .color(media.kind == .video ? Gallery.selection.opacity(0.55) : Gallery.next.opacity(0.5)))
                    // Where the file starts and ends.
                    for t in [0, waveform.duration] {
                        if let p = item.position(atMediaTime: t) {
                            let ex = metrics.x(p)
                            ctx.fill(Path(CGRect(x: ex, y: 0, width: 1, height: size.height)), with: .color(Gallery.faint.opacity(0.6)))
                        }
                    }
                }
                .allowsHitTesting(false)
            } else if missing {
                Text("\(item.media?.name ?? "Media") is missing. Load it again from the media menu.")
                    .font(.ocMeta).foregroundStyle(Gallery.amber).padding(.leading, Space.s)
            } else {
                Text("Reading \(item.media?.name ?? "")…").font(.ocMeta).foregroundStyle(Gallery.faint).padding(.leading, Space.s)
            }
        }
        .frame(width: width, height: TimelineLayout.mediaLane)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            player.seek(item, position: metrics.position(v.location.x))
        })
        .onAppear { player.prepare(item) }
        .onChange(of: item.media) { _, _ in player.prepare(item) }
        .help("Click or drag to scrub")
    }
}

/// Where the media player is, through every track.
struct MediaPlayhead: View {
    let item: RundownItem
    @ObservedObject var player: MediaPlayer
    let metrics: TimelineMetrics
    let height: CGFloat

    var body: some View {
        if let p = player.position(in: item) {
            ZStack(alignment: .top) {
                Rectangle().fill(Gallery.amber).frame(width: 1.5, height: height)
                PlayheadHead().fill(Gallery.amber).frame(width: 11, height: 9).offset(y: TimelineLayout.ruler - 10)
            }
            .frame(width: 11, height: height, alignment: .top)
            .offset(x: metrics.x(p) - 5.5)
            .allowsHitTesting(false)
        }
    }
}

/// Toolbar controls for the item's media: load, play, offset, video window.
struct MediaControls: View {
    let item: RundownItem
    @ObservedObject var model: WorkspaceModel
    @ObservedObject var player: MediaPlayer
    @State private var menuOpen = false

    var body: some View {
        HStack(spacing: 4) {
            if item.media != nil {
                IconButton(symbol: player.playing && player.itemID == item.id ? "pause.fill" : "play.fill",
                           help: "Play or pause the media (⌥Space)", size: 22) { player.toggle(item) }
                if let p = player.position(in: item) {
                    Text(item.format(max(p, item.timeBase == .order ? 1 : 0)))
                        .font(.readout(10.5)).foregroundStyle(Gallery.amber).frame(minWidth: 44, alignment: .leading)
                }
            }
            Button { menuOpen.toggle() } label: {
                Label(item.media?.name ?? "Media", systemImage: item.media?.kind == .video ? "film" : "waveform")
                    .lineLimit(1)
                    .frame(maxWidth: 160)
            }
            .buttonStyle(QuietButtonStyle())
            .help("Song audio or a PGM recording under the timeline")
            .popover(isPresented: $menuOpen, arrowEdge: .bottom) { popover }
        }
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("Media under the timeline").font(.ocHeading).foregroundStyle(Gallery.ink)
            if let media = item.media {
                Text(media.path).font(.ocMeta).foregroundStyle(Gallery.dim).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                PropertyRow(label: "Song starts at") {
                    CommitField(placeholder: "0.0", value: String(format: "%.2f", media.offset), font: .readout(12), width: 80) { text in
                        guard let v = Double(text.replacingOccurrences(of: ",", with: ".")) else { return false }
                        model.edit("Media Offset") { $0.updateItem(item.id) { $0.media?.offset = v } }
                        return true
                    }
                    Text("s in the file").font(.ocMeta).foregroundStyle(Gallery.faint)
                }
                Button("Song starts at the media playhead") {
                    let t = player.itemID == item.id ? player.time : media.offset
                    model.edit("Media Offset") { $0.updateItem(item.id) { $0.media?.offset = t } }
                }
                .buttonStyle(QuietButtonStyle())
                .help("Play or scrub to the first beat of the song, then press this")
                if media.kind == .video {
                    Button(player.videoWindowOpen ? "Hide Video" : "Show Video") {
                        player.prepare(item)
                        if player.videoWindowOpen { player.closeVideo() } else { player.showVideo(title: "\(item.title) – \(media.name)") }
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                HStack {
                    Button("Replace…") { menuOpen = false; MediaPlayer.choose(for: item, model: model) }
                        .buttonStyle(QuietButtonStyle())
                    Button("Remove") {
                        menuOpen = false
                        player.unload()
                        model.edit("Remove Media") { $0.updateItem(item.id) { $0.media = nil } }
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            } else {
                Text("Load the song's audio or a PGM recording to see its waveform under the shots, scrub through it and play it while you script.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
                Button("Load Audio or Video…") { menuOpen = false; MediaPlayer.choose(for: item, model: model) }
                    .buttonStyle(QuietButtonStyle(prominent: true))
            }
        }
        .padding(Space.l)
        .frame(width: 340)
        .background(Gallery.panel)
    }
}

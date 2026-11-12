import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins
import OnCueCore

/// Runs the crew page for one production window: starts and stops the server, sends it the show
/// and, in Live Mode, the engine's position (at most four times a second), and turns comments
/// from phones into undoable edits.
final class CrewController: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var starting = false
    @Published private(set) var port: UInt16 = 0
    @Published private(set) var clients = 0
    @Published private(set) var error: String?
    @Published var address: String = ""

    private let server = CrewServer()
    private var show: Show?
    private var engine: EngineController?
    private var engineWatch: AnyCancellable?
    private var scriptVersion = 0
    private var lastSent = Date.distantPast
    private var pendingSend = false

    /// Called with a comment from a phone.
    var onComment: ((String?, String?, String, String) -> Void)? {
        didSet { server.onComment = onComment }
    }

    init() {
        server.onClientsChanged = { [weak self] count in self?.clients = count }
    }

    var url: String? {
        guard running, !address.isEmpty else { return nil }
        return "http://\(address):\(port)/"
    }

    func start() {
        let profile = MachineProfileStore().profile
        let addresses = NetworkAddress.all()
        if address.isEmpty || !addresses.contains(where: { $0.address == address }) {
            let chosen = addresses.first { $0.interface == profile.crewInterface || $0.address == profile.crewInterface }
            address = (chosen ?? addresses.first(where: { $0.interface.hasPrefix("en") }) ?? addresses.first)?.address ?? ""
        }
        error = nil
        starting = true
        attempt(port: UInt16(clamping: max(profile.crewPort, 1)), tries: 6)
    }

    /// Tries the configured port, then the next few (another window may hold it).
    private func attempt(port: UInt16, tries: Int) {
        let limitTo = profileRestricts ? address : nil
        server.start(port: port, onlyAddress: limitTo) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let p):
                self.port = p
                self.running = true
                self.starting = false
                self.send(force: true)
            case .failure(let err):
                if tries > 1 {
                    self.attempt(port: port &+ 1, tries: tries - 1)
                } else {
                    self.starting = false
                    self.running = false
                    self.error = "The crew page couldn't start: \(err.localizedDescription)"
                }
            }
        }
    }

    /// Answer only on the chosen network when this Mac names one in Settings.
    private var profileRestricts: Bool { !MachineProfileStore().profile.crewInterface.isEmpty }

    func stop() {
        server.stop()
        running = false
        clients = 0
    }

    func restart() {
        guard running else { return }
        stop()
        start()
    }

    // MARK: - Feeding the page

    func showChanged(_ show: Show) {
        if self.show != nil, self.show != show { scriptVersion += 1 }
        self.show = show
        send(force: true)
    }

    func follow(_ engine: EngineController?) {
        self.engine = engine
        engineWatch = engine?.$status
            .removeDuplicates { a, b in
                a.index == b.index && a.itemID == b.itemID && a.transport == b.transport && a.pauseReason == b.pauseReason
                    && a.freeMode == b.freeMode && a.program == b.program && a.preview == b.preview
                    && abs(a.position - b.position) < 0.5 && a.timingSignal == b.timingSignal
            }
            .sink { [weak self] _ in self?.send() }
        send(force: true)
    }

    private func send(force: Bool = false) {
        guard running, let show else { return }
        let gap = Date().timeIntervalSince(lastSent)
        if !force && gap < 0.25 {
            guard !pendingSend else { return }
            pendingSend = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (0.25 - gap)) { [weak self] in
                self?.pendingSend = false
                self?.send(force: true)
            }
            return
        }
        lastSent = Date()
        let status = engine?.status
        let moving = status.map { $0.transport == .running && ($0.timingSignal || $0.timing == .internalClock) } ?? false
        server.update(show.crewSnapshot(status: status, position: status?.position, running: moving, scriptVersion: scriptVersion))
    }
}

// MARK: - Toolbar control

/// Toolbar button for the crew page: start it, pick the network, show the QR code to scan.
struct CrewPageButton: View {
    @ObservedObject var crew: CrewController
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            Label("Crew Page", systemImage: crew.running ? "iphone.radiowaves.left.and.right" : "iphone")
        }
        .help(crew.running ? "Crew page is on (\(crew.clients) connected)" : "Crew page for phones on the local network")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            CrewPagePopover(crew: crew)
        }
    }
}

struct CrewPagePopover: View {
    @ObservedObject var crew: CrewController
    @State private var addresses = NetworkAddress.all()

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crew page").font(.ocHeading).foregroundStyle(Gallery.ink)
                    Text("Camera operators open it on their phones to see their tally, countdown and next shots.")
                        .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Space.m)
                Toggle("", isOn: Binding(get: { crew.running || crew.starting },
                                         set: { $0 ? crew.start() : crew.stop() }))
                    .toggleStyle(.switch).labelsHidden()
            }

            if addresses.isEmpty {
                Text("This Mac isn't on a network. Connect to the crew Wi-Fi first.")
                    .font(.ocMeta).foregroundStyle(Gallery.amber)
            } else {
                PropertyRow(label: "Network") {
                    Picker("Network", selection: Binding(get: { crew.address }, set: { crew.address = $0; crew.restart() })) {
                        ForEach(addresses) { a in
                            Text("\(a.address)  (\(a.interface))").tag(a.address)
                        }
                    }
                    .labelsHidden()
                }
            }

            if let error = crew.error {
                Text(error).font(.ocMeta).foregroundStyle(Gallery.tally).fixedSize(horizontal: false, vertical: true)
            }

            if let url = crew.url {
                HStack(alignment: .top, spacing: Space.m) {
                    if let qr = QRCode.image(for: url) {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 148, height: 148)
                            .padding(8)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.m))
                    }
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(url).font(.readout(13, weight: .semibold)).foregroundStyle(Gallery.ink).textSelection(.enabled)
                        Button("Copy address") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                        }
                        .buttonStyle(QuietButtonStyle())
                        Text(crew.clients == 1 ? "1 phone following" : "\(crew.clients) phones following")
                            .font(.ocMeta).foregroundStyle(crew.clients > 0 ? Gallery.next : Gallery.faint)
                        Text("Phones must be on the same network. Comments sent from the page appear on the shot in the inspector.")
                            .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if crew.starting {
                Text("Starting…").font(.ocMeta).foregroundStyle(Gallery.dim)
            }
        }
        .padding(Space.l)
        .frame(width: 420)
        .background(Gallery.panel)
        .onAppear { addresses = NetworkAddress.all() }
    }
}

enum QRCode {
    static func image(for text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

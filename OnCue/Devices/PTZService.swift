import Foundation
import Network

/// Recalls PTZ presets. Preset numbers are 1-based in OnCue.
final class PTZService {
    var runATEMMacro: ((UUID?, Int) -> Void)?
    var companion: CompanionClient?

    private let queue = DispatchQueue(label: "oncue.ptz")
    private var sequence: UInt32 = 0
    private var udp: [String: NWConnection] = [:]
    private let http: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 2
        return URLSession(configuration: c)
    }()

    func recall(_ cam: PTZCamera, preset: Int) {
        let p = max(1, preset)
        switch cam.proto {
        case .panasonic:
            // AW-UE series: #Rnn recalls preset nn+1 (00 = preset 1).
            let nn = String(format: "%02d", min(p - 1, 99))
            if let url = URL(string: "http://\(cam.host)/cgi-bin/aw_ptz?cmd=%23R\(nn)&res=1") {
                http.dataTask(with: url).resume()
            }
        case .viscaIP:
            sendViscaIP(cam, command: viscaRecall(p))
        case .viscaTCP:
            sendViscaTCP(cam, command: viscaRecall(p))
        case .atemMacro:
            runATEMMacro?(cam.switcherID, cam.macroBase + p - 1)
        case .companion:
            var b = cam.companionStart
            b.enabled = true
            b.column += p - 1
            b.bank += p - 1
            companion?.press(b)
        }
    }

    /// VISCA "Memory Recall": 8x 01 04 3F 02 pp FF (pp is 0-based).
    private func viscaRecall(_ preset: Int) -> [UInt8] {
        [0x81, 0x01, 0x04, 0x3F, 0x02, UInt8(clamping: preset - 1), 0xFF]
    }

    /// Sony VISCA over IP: 8-byte header (type 0x0100, length, sequence) + VISCA command, UDP 52381.
    private func sendViscaIP(_ cam: PTZCamera, command: [UInt8]) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: cam.port > 0 ? cam.port : 52381)) else { return }
        queue.async {
            self.sequence &+= 1
            var pkt: [UInt8] = [0x01, 0x00, 0x00, UInt8(command.count)]
            let s = self.sequence
            pkt += [UInt8(s >> 24 & 0xFF), UInt8(s >> 16 & 0xFF), UInt8(s >> 8 & 0xFF), UInt8(s & 0xFF)]
            pkt += command
            let key = "\(cam.host):\(port.rawValue)"
            let conn: NWConnection
            if let c = self.udp[key] {
                conn = c
            } else {
                conn = NWConnection(host: NWEndpoint.Host(cam.host), port: port, using: .udp)
                conn.start(queue: self.queue)
                self.udp[key] = conn
            }
            conn.send(content: Data(pkt), completion: .idempotent)
        }
    }

    private func sendViscaTCP(_ cam: PTZCamera, command: [UInt8]) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: cam.port > 0 ? cam.port : 5678)) else { return }
        let conn = NWConnection(host: NWEndpoint.Host(cam.host), port: port, using: .tcp)
        conn.stateUpdateHandler = { st in
            if case .ready = st {
                conn.send(content: Data(command), completion: .contentProcessed { _ in
                    conn.cancel()
                })
            }
        }
        conn.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 3) { conn.cancel() }
    }
}

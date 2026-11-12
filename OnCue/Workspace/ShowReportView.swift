import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnCueCore

/// After the show: Director Stats and scripted vs actual, from a switch log.
struct ShowReportView: View {
    let show: Show
    let log: SwitchLog
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let analysis = ShowAnalysis(log: log, show: show)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show report").font(.ocTitle).foregroundStyle(Gallery.ink)
                    MetaLine(parts: [log.showName, log.started.formatted(date: .abbreviated, time: .shortened),
                                     log.machine.isEmpty ? "" : log.machine])
                }
                Spacer()
                Menu {
                    ForEach([24, 25, 30, 50, 60], id: \.self) { fps in
                        Button("EDL at \(fps) fps") {
                            FileSaver.save(Data(log.edl(show: show, fps: fps).utf8), name: "\(log.showName) – Program cuts",
                                           type: UTType(filenameExtension: "edl") ?? .plainText, model: nil)
                        }
                    }
                    Divider()
                    Button("Switch log (CSV)") {
                        FileSaver.save(Data(log.csv(show: show).utf8), name: "\(log.showName) – Switch log",
                                       type: .commaSeparatedText, model: nil)
                    }
                } label: {
                    Text("Export")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("The program cuts as an EDL for conforming ISO recordings, or every logged event as a spreadsheet")
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HStack(spacing: Space.s) {
                        ReportTile(value: clockText(analysis.duration), label: "On air")
                        ReportTile(value: "\(analysis.cutCount)", label: "Cuts")
                        ReportTile(value: String(format: "%.1f", analysis.cutsPerMinute), label: "Cuts per minute")
                        ReportTile(value: String(format: "%.1f s", analysis.averageShotSeconds), label: "Average shot")
                        ReportTile(value: analysis.scripted.isEmpty ? "–" : "\(analysis.hits)/\(analysis.scripted.count)",
                                   label: "Scripted shots hit")
                        ReportTile(value: analysis.averageOffset.map { String(format: "%+.2f s", $0) } ?? "–",
                                   label: "Average timing", detail: "minus is early")
                    }

                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("On-air time per camera").sectionLabel()
                        let longest = analysis.cameras.map(\.onAirSeconds).max() ?? 1
                        if analysis.cameras.isEmpty {
                            Text("No cuts were reported by a switcher in this log.").font(.ocMeta).foregroundStyle(Gallery.faint)
                        }
                        ForEach(analysis.cameras) { stat in
                            let cam = show.camera(stat.cameraID)
                            HStack(spacing: Space.s) {
                                CameraChip(camera: cam, size: 18)
                                Text(cam?.displayName ?? "Unknown").font(.ocLabel).foregroundStyle(Gallery.ink)
                                    .frame(width: 110, alignment: .leading)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(cam?.swiftUIColor ?? Gallery.key)
                                        .frame(width: max(geo.size.width * stat.onAirSeconds / max(longest, 0.001), 2))
                                }
                                .frame(height: 10)
                                Text(clockText(stat.onAirSeconds)).font(.readout(11)).foregroundStyle(Gallery.dim)
                                    .frame(width: 52, alignment: .trailing)
                                Text("\(stat.shots) shots").font(.ocMeta).foregroundStyle(Gallery.faint)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("Scripted vs actual").sectionLabel()
                        if analysis.scripted.isEmpty {
                            Text("No scripted shots in this log.").font(.ocMeta).foregroundStyle(Gallery.faint)
                        }
                        ForEach(Array(analysis.scripted.enumerated()), id: \.offset) { _, r in
                            let cam = show.camera(r.entry.cameraID)
                            HStack(spacing: Space.s) {
                                Text(r.entry.date.formatted(date: .omitted, time: .standard)).font(.readout(11)).foregroundStyle(Gallery.faint)
                                    .frame(width: 80, alignment: .leading)
                                Text(show.item(r.entry.itemID)?.title ?? "").font(.ocMeta).foregroundStyle(Gallery.dim)
                                    .frame(width: 150, alignment: .leading).lineLimit(1)
                                Text("Shot \(r.entry.shotNumber ?? 0)").font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: 60, alignment: .leading)
                                CameraChip(camera: cam, size: 16)
                                Text(cam?.displayName ?? "No camera").font(.ocLabel).foregroundStyle(Gallery.ink)
                                Spacer()
                                result(r.result)
                            }
                        }
                        if !analysis.offScript.isEmpty {
                            Text("\(analysis.offScript.count) \(analysis.offScript.count == 1 ? "cut" : "cuts") off the script")
                                .font(.ocMeta).foregroundStyle(Gallery.amber)
                        }
                    }
                }
                .padding(Space.l)
            }
        }
        .frame(width: 820, height: 620)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func result(_ r: ShowAnalysis.Result) -> some View {
        switch r {
        case .hit(let offset):
            let early = offset < -0.04, late = offset > 0.04
            Text(early ? String(format: "%.2f s early", -offset) : (late ? String(format: "%.2f s late", offset) : "On time"))
                .font(.readout(11, weight: .semibold))
                .foregroundStyle(abs(offset) > 0.5 ? Gallery.amber : Gallery.next)
        case .missed:
            Text("Missed").font(.readout(11, weight: .semibold)).foregroundStyle(Gallery.tally)
        }
    }
}

struct ReportTile: View {
    let value: String
    let label: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.readout(22, weight: .semibold)).foregroundStyle(Gallery.ink)
            Text(label).font(.ocMeta).foregroundStyle(Gallery.dim)
            if let detail { Text(detail).font(.system(size: 10)).foregroundStyle(Gallery.faint) }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
    }
}

enum SwitchLogPicker {
    /// Asks for a saved switch log and opens it.
    static func choose(completion: @escaping (SwitchLog) -> Void, failure: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: SwitchLog.fileExtension) ?? .json, .json]
        panel.directoryURL = EngineController.defaultLogFolder(MachineProfileStore().profile)
        panel.prompt = "Open Log"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            completion(try SwitchLog.decode(Data(contentsOf: url)))
        } catch {
            failure("That file is not an OnCue switch log: \(error.localizedDescription)")
        }
    }
}

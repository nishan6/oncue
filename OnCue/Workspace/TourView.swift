import SwiftUI
import OnCueCore

/// Production › Tour: name tonight, and compare every night this show has run, from the switch logs.
struct TourView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var logs: [SwitchLog] = []
    @State private var loaded = false

    var body: some View {
        let tour = TourComparison(show: show, logs: logs)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tour").font(.ocTitle).foregroundStyle(Gallery.ink)
                    Text(tour.nights.isEmpty ? "Nights appear here after Live Mode runs with this show."
                                             : "\(tour.nights.count) \(tour.nights.count == 1 ? "night" : "nights") of \(show.name)")
                        .font(.ocMeta).foregroundStyle(Gallery.dim)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)

            HStack(spacing: Space.s) {
                Text("Tonight").font(.ocLabel).foregroundStyle(Gallery.dim)
                CommitField(placeholder: "e.g. Night 3, Pune", value: show.settings.nightLabel, font: .ocBody, width: 260) { text in
                    model.edit("Name Tonight") { $0.settings.nightLabel = text }
                    return true
                }
                Text("Saved in tonight's switch log with who is on each camera.")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            }
            .padding(.horizontal, Space.l)
            .padding(.bottom, Space.m)

            Rectangle().fill(Gallery.hairline).frame(height: 1)

            if !loaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tour.nights.isEmpty {
                Text("No switch logs for this show in \(EngineController.defaultLogFolder(MachineProfileStore().profile)?.path ?? "the log folder").")
                    .font(.ocBody).foregroundStyle(Gallery.faint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    comparison(tour).padding(Space.l)
                }
            }
        }
        .frame(width: 980, height: 640)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .task {
            let folder = EngineController.defaultLogFolder(MachineProfileStore().profile)
            let found = await Task.detached { folder.map(TourComparison.loadLogs(in:)) ?? [] }.value
            logs = found
            loaded = true
        }
    }

    private let labelWidth: CGFloat = 200
    private let nightWidth: CGFloat = 150

    private func comparison(_ tour: TourComparison) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Night headings.
            HStack(alignment: .bottom, spacing: 0) {
                Color.clear.frame(width: labelWidth, height: 1)
                ForEach(tour.nights) { night in
                    Button {
                        dismiss()
                        let log = night.log
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.reportLog = log }
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(night.log.nightName).font(.ocLabel).foregroundStyle(Gallery.ink).lineLimit(1)
                            Text(night.log.started.formatted(date: .abbreviated, time: .shortened)).font(.ocMeta).foregroundStyle(Gallery.faint)
                        }
                        .frame(width: nightWidth, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open this night's report")
                }
            }
            .padding(.bottom, Space.s)

            group("Whole show")
            row("On air", tour.nights.map { clockText($0.analysis.duration) })
            row("Cuts", tour.nights.map { "\($0.analysis.cutCount)" })
            row("Cuts per minute", tour.nights.map { String(format: "%.1f", $0.analysis.cutsPerMinute) })
            row("Scripted shots hit", tour.nights.map { n in n.hitRate.map { "\(Int(($0 * 100).rounded()))%  (\(n.analysis.hits)/\(n.analysis.scripted.count))" } ?? "–" },
                tone: tour.nights.map { $0.hitRate.map(rateTone) ?? Gallery.dim })
            row("Average timing", tour.nights.map { $0.analysis.averageOffset.map { String(format: "%+.2f s", $0) } ?? "–" })
            row("Off the script", tour.nights.map { "\($0.analysis.offScript.count)" })

            group("Crew")
            ForEach(show.sortedCameras) { cam in
                row("\(cam.number)  \(cam.displayName)", tour.nights.map { $0.log.operators["\(cam.number)"] ?? "–" })
            }

            ForEach(show.items) { item in
                if tour.nights.contains(where: { $0.items[item.id] != nil }) {
                    group(item.title)
                    let planned = RundownTiming.plannedLength(item, show: show)
                    row(planned.map { "Length (plan \(clockText($0)))" } ?? "Length",
                        tour.nights.map { $0.items[item.id]?.length.map(clockText) ?? "–" },
                        tone: tour.nights.map { n in
                            guard let planned, let l = n.items[item.id]?.length else { return Gallery.ink }
                            return l - planned > 15 ? Gallery.amber : Gallery.ink
                        })
                    row("Cuts", tour.nights.map { $0.items[item.id].map { "\($0.cuts)" } ?? "–" })
                    row("Shots hit", tour.nights.map { n in n.items[item.id]?.hitRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "–" },
                        tone: tour.nights.map { $0.items[item.id]?.hitRate.map(rateTone) ?? Gallery.dim })
                    row("Average timing", tour.nights.map { $0.items[item.id]?.averageOffset.map { String(format: "%+.2f s", $0) } ?? "–" })
                }
            }
        }
    }

    private func rateTone(_ rate: Double) -> Color { rate >= 0.95 ? Gallery.next : (rate >= 0.8 ? Gallery.ink : Gallery.amber) }

    private func group(_ title: String) -> some View {
        Text(title).sectionLabel()
            .padding(.top, Space.l)
            .padding(.bottom, Space.xs)
    }

    private func row(_ label: String, _ values: [String], tone: [Color]? = nil) -> some View {
        HStack(spacing: 0) {
            Text(label).font(.ocMeta).foregroundStyle(Gallery.dim).frame(width: labelWidth, alignment: .leading).lineLimit(1)
            ForEach(Array(values.enumerated()), id: \.offset) { k, v in
                Text(v).font(.readout(12)).foregroundStyle(tone?[k] ?? Gallery.ink)
                    .frame(width: nightWidth, alignment: .leading).lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

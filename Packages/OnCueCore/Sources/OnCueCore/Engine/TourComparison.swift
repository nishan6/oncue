import Foundation

/// Tour mode: the same show night after night, compared from each night's switch log.
public struct TourComparison {
    public struct ItemNight: Equatable {
        public let length: Double?
        public let cuts: Int
        public let scripted: Int
        public let hits: Int
        public let averageOffset: Double?
        public var hitRate: Double? { scripted > 0 ? Double(hits) / Double(scripted) : nil }
    }

    public struct Night: Identifiable {
        public var id: String { log.fileName }
        public let log: SwitchLog
        public let analysis: ShowAnalysis
        public let items: [UUID: ItemNight]
        public var hitRate: Double? { analysis.scripted.isEmpty ? nil : Double(analysis.hits) / Double(analysis.scripted.count) }
    }

    public let nights: [Night]

    /// Logs of this show only, oldest night first.
    public init(show: Show, logs: [SwitchLog]) {
        let mine = logs.filter { $0.showID == show.id && !$0.entries.isEmpty }.sorted { $0.started < $1.started }
        nights = mine.map { log in
            let runs = RundownTiming.runs(log: log, mainOutput: show.mainOutput?.id)
            var perItem: [UUID: ItemNight] = [:]
            for item in show.items {
                var sub = log
                sub.entries = log.entries.filter { $0.itemID == item.id }
                guard !sub.entries.isEmpty else { continue }
                let a = ShowAnalysis(log: sub, show: show)
                let lengths = runs.filter { $0.itemID == item.id }.compactMap(\.length)
                perItem[item.id] = ItemNight(length: lengths.isEmpty ? nil : lengths.reduce(0, +), cuts: a.cutCount,
                                             scripted: a.scripted.count, hits: a.hits, averageOffset: a.averageOffset)
            }
            return Night(log: log, analysis: ShowAnalysis(log: log, show: show), items: perItem)
        }
    }

    /// Reads every switch log in a folder (files that aren't logs are skipped).
    public static func loadLogs(in folder: URL) -> [SwitchLog] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == SwitchLog.fileExtension }
            .compactMap { try? SwitchLog.decode(Data(contentsOf: $0)) }
    }
}

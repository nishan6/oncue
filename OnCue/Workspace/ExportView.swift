import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnCueCore

/// What can be exported from the script.
enum ScriptExportKind: String, CaseIterable, Identifiable {
    case cameraScript, callSheets, scriptCSV, markers
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cameraScript: return "Camera script (PDF)"
        case .callSheets: return "Call sheets, one per camera (PDF)"
        case .scriptCSV: return "Script (CSV)"
        case .markers: return "Shot markers (EDL)"
        }
    }

    var detail: String {
        switch self {
        case .cameraScript: return "Every shot with its camera, description, operator note, transition and length. Each song or segment starts a new page."
        case .callSheets: return "For operators on comms only: each camera's shots across the show, with the cameras before and after."
        case .scriptCSV: return "Every shot as a spreadsheet row, for Numbers, Excel or Google Sheets."
        case .markers: return "The song's shots as timeline markers in the camera's colour, for DaVinci Resolve. The song starts at 01:00:00:00."
        }
    }

    var fileType: UTType {
        switch self {
        case .cameraScript, .callSheets: return .pdf
        case .scriptCSV: return .commaSeparatedText
        case .markers: return UTType(filenameExtension: "edl") ?? .plainText
        }
    }
}

/// File › Export: pick what, for which songs or cameras, then save.
struct ExportView: View {
    let show: Show
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("export.kind") private var kindRaw = ScriptExportKind.cameraScript.rawValue
    @AppStorage("export.paper") private var paperRaw = PaperSize.localDefault.rawValue
    @State private var wholeShow = true
    @State private var cameraID: UUID?
    @State private var fps = 25

    private var kind: ScriptExportKind { ScriptExportKind(rawValue: kindRaw) ?? .cameraScript }
    private var paper: PaperSize { PaperSize(rawValue: paperRaw) ?? .localDefault }
    private var current: RundownItem? { show.item(model.selectedItemID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Export").font(.ocTitle).foregroundStyle(Gallery.ink).padding(Space.l)

            VStack(alignment: .leading, spacing: Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(ScriptExportKind.allCases) { k in
                        Button { kindRaw = k.rawValue } label: {
                            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                                Image(systemName: kind == k ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(kind == k ? Gallery.selection : Gallery.faint)
                                Text(k.label).font(.ocBody).foregroundStyle(Gallery.ink)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(kind.detail).font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)

                Divider().overlay(Gallery.hairline)

                switch kind {
                case .cameraScript:
                    scopePicker
                    paperPicker
                case .callSheets:
                    PropertyRow(label: "Cameras") {
                        Picker("Cameras", selection: $cameraID) {
                            Text("All cameras").tag(UUID?.none)
                            ForEach(show.sortedCameras) { cam in
                                Text("\(cam.number)  \(cam.displayName)").tag(UUID?.some(cam.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 240)
                    }
                    paperPicker
                case .scriptCSV:
                    Text("Exports the whole show.").font(.ocMeta).foregroundStyle(Gallery.faint)
                case .markers:
                    if let current, current.timeBase != .order {
                        PropertyRow(label: "Song") { Text(current.title).font(.ocBody).foregroundStyle(Gallery.ink) }
                        PropertyRow(label: "Frame rate") {
                            Picker("Frame rate", selection: $fps) {
                                ForEach([24, 25, 30, 50, 60], id: \.self) { Text("\($0) fps").tag($0) }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 120)
                        }
                    } else {
                        Text(current == nil ? "Select a song first." : "\(current!.title) is called on NEXT, so its shots have no times to mark.")
                            .font(.ocMeta).foregroundStyle(Gallery.amber)
                    }
                }
            }
            .padding(.horizontal, Space.l)

            Spacer(minLength: Space.l)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Export…") { export() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canExport)
            }
            .padding(Space.l)
        }
        .frame(width: 480, height: 470)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear {
            fps = Int(show.settings.ltcFPS.rounded())
            if ![24, 25, 30, 50, 60].contains(fps) { fps = 25 }
            if show.items.count > 1, current != nil { wholeShow = false }
        }
    }

    @ViewBuilder private var scopePicker: some View {
        PropertyRow(label: "Songs") {
            Picker("Songs", selection: $wholeShow) {
                Text("Whole show").tag(true)
                if let current { Text(current.title).tag(false) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
    }

    @ViewBuilder private var paperPicker: some View {
        PropertyRow(label: "Paper") {
            Picker("Paper", selection: $paperRaw) {
                ForEach(PaperSize.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }
    }

    private var canExport: Bool {
        kind != .markers || (current.map { $0.timeBase != .order } ?? false)
    }

    private var suggestedName: String {
        switch kind {
        case .cameraScript: return "\(show.name) – Camera script" + (wholeShow || current == nil ? "" : " – \(current!.title)")
        case .callSheets: return "\(show.name) – Call sheets" + (show.camera(cameraID).map { " – Cam \($0.number)" } ?? "")
        case .scriptCSV: return "\(show.name) – Script"
        case .markers: return "\(show.name) – \(current?.title ?? "") markers"
        }
    }

    private func export() {
        let data: Data?
        switch kind {
        case .cameraScript:
            data = show.cameraScriptPDF(itemIDs: wholeShow || current == nil ? [] : [current!.id], paper: paper)
        case .callSheets:
            data = show.callSheetsPDF(cameraIDs: cameraID.map { [$0] } ?? [], paper: paper)
        case .scriptCSV:
            data = Data(show.scriptCSV().utf8)
        case .markers:
            data = current.flatMap { show.markerEDL(itemID: $0.id, fps: fps) }.map { Data($0.utf8) }
        }
        guard let data else { return }
        if FileSaver.save(data, name: suggestedName, type: kind.fileType, model: model) { dismiss() }
    }
}

/// Save panel plus write, reporting failures through the window's alert.
enum FileSaver {
    @discardableResult
    static func save(_ data: Data, name: String, type: UTType, model: WorkspaceModel?) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            let message = "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
            if let model { model.errorMessage = message } else {
                let alert = NSAlert()
                alert.messageText = message
                alert.runModal()
            }
            return false
        }
    }
}

import SwiftUI
import OnCueCore

/// One production window: running order on the left, the selected song or segment in the middle,
/// the inspector on the right. All three panels resize.
struct ShowWorkspaceView: View {
    @Binding var document: ShowDocument
    let fileURL: URL?
    @StateObject private var model = WorkspaceModel()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let show = document.show
        ZStack {
        WorkspaceShell(show: show, model: model)
            .frame(minWidth: 980, minHeight: 640)
        if let engine = model.engine {
            LiveView(show: show, engine: engine, model: model)
                .transition(.opacity)
        }
        }
        .animation(.easeOut(duration: 0.18), value: model.isLive)
        .toolbarBackground(model.isLive ? LivePalette.base : Deck.bar, for: .windowToolbar)
        .toolbarBackground(model.isLive ? .visible : .automatic, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let engine = model.engine {
                    LiveToolbarContext(show: show, engine: engine)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                // Edit mode keeps its controls in the top bar and the rail; Live Mode keeps its
                // status here.
                if let engine = model.engine {
                    CrewPageButton(crew: model.crew)
                    LiveToolbarStatus(show: show, engine: engine, model: model)
                }
            }
        }
        .sheet(isPresented: $model.cameraManagerOpen) {
            CameraManagerView(show: show, model: model)
        }
        .sheet(isPresented: $model.switcherSetupOpen) {
            ShowSetupView(show: show, model: model)
        }
        .sheet(isPresented: $model.exportOpen) {
            ExportView(show: show, model: model)
        }
        .sheet(isPresented: $model.preShowCheckOpen) {
            PreShowCheckView(show: show, model: model)
        }
        .sheet(isPresented: $model.plotOpen) {
            CameraPlotView(show: show, model: model)
        }
        .sheet(isPresented: $model.tourOpen) {
            TourView(show: show, model: model)
        }
        .sheet(isPresented: $model.versionsOpen) {
            VersionsView(show: show, model: model)
        }
        .sheet(item: $model.draftSource) { source in
            DraftScriptView(show: show, source: source, model: model)
        }
        .sheet(item: Binding(get: { model.reportLog.map(ReportBox.init) }, set: { model.reportLog = $0?.log })) { box in
            ShowReportView(show: show, log: box.log)
        }
        .alert("Can't do that", isPresented: Binding(get: { model.errorMessage != nil },
                                                      set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .background(Deck.base)
        .preferredColorScheme(.dark)
        .tint(Deck.accent)
        .focusedSceneObject(model)
        .onAppear { model.attach(document: $document, undoManager: undoManager) }
        .onChange(of: show.id) { _, _ in model.attach(document: $document, undoManager: undoManager) }
        .onChange(of: show) { _, newShow in
            model.validateSelection()
            model.engine?.update(show: newShow)
            model.crew.showChanged(newShow)
            model.scheduleBackup(newShow)
            model.sendShowToBackup(newShow)
        }
        .onDisappear { model.crew.stop() }
    }
}

/// Shown when the production has no songs or segments yet, or none is selected.
struct EmptyProductionView: View {
    @ObservedObject var model: WorkspaceModel
    let hasItems: Bool

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: hasItems ? "sidebar.left" : "music.note.list")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Gallery.faint)
            Text(hasItems ? "Pick a song or segment" : "Start the running order")
                .font(.ocTitle)
                .foregroundStyle(Gallery.ink)
            Text(hasItems ? "Choose one from the running order to script its shots."
                 : "Add the first song or segment, then script its shots on the timeline.")
                .font(.ocBody)
                .foregroundStyle(Gallery.dim)
            if !hasItems {
                HStack(spacing: Space.s) {
                    Button("New Song") { model.addSong() }
                        .buttonStyle(QuietButtonStyle(prominent: true))
                        .keyboardShortcut(.defaultAction)
                    Button("New Segment") { model.addSegment() }
                        .buttonStyle(QuietButtonStyle())
                }
                .padding(.top, Space.s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Gallery.base)
    }
}


/// Identifiable wrapper so a switch log can drive a sheet.
struct ReportBox: Identifiable {
    let log: SwitchLog
    var id: String { log.fileName + "\(log.entries.count)" }
}

import SwiftUI
import OnCueCore

/// One project window: the active playlist's running order on the left, the selected song or
/// segment in the middle, the inspector on the right. All three panels resize.
struct ShowWorkspaceView: View {
    @Binding var document: ProjectDocument
    let fileURL: URL?
    @StateObject private var model = WorkspaceModel()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        let show = document.project.show(playlist: model.activePlaylistID)
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
            VersionsView(project: document.project, model: model)
        }
        .sheet(isPresented: $model.projectPropertiesOpen) {
            ProjectPropertiesView(project: document.project, model: model)
        }
        .sheet(item: Binding(get: { model.newSceneKind.map(SceneKindBox.init) }, set: { model.newSceneKind = $0?.kind })) { box in
            NewSceneSheet(kind: box.kind, project: document.project, show: show, model: model)
        }
        .sheet(item: Binding(get: { model.legacyShow.map(LegacyBox.init) }, set: { _ in })) { box in
            LegacyShowSheet(show: box.show, originalURL: fileURL, model: model)
                .interactiveDismissDisabled()
        }
        .alert("Renumber the scenes?", isPresented: $model.renumberPromptOpen) {
            Button("Renumber") { model.renumberScenes() }
            Button("Keep Numbers", role: .cancel) {}
        } message: {
            Text("The scene numbers no longer follow the running order. Renumber them from \(document.project.properties.sceneDefaults.numberingFrom)? A version is kept first.")
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
        .environment(\.shotVocabulary, document.project.properties.shots)
        .environment(\.projectFrameRate, document.project.frameRate)
        .background(Deck.base)
        .preferredColorScheme(.dark)
        .tint(Deck.accent)
        .focusedSceneObject(model)
        .overlay(alignment: .top) {
            if let notice = model.recoveredNotice {
                NoticeBanner(text: notice) { model.recoveredNotice = nil }
                    .padding(.top, Space.s)
            }
        }
        .onAppear { model.attach(document: $document, fileURL: fileURL, undoManager: undoManager) }
        .onChange(of: show.id) { _, _ in model.attach(document: $document, fileURL: fileURL, undoManager: undoManager) }
        .onChange(of: show) { _, newShow in
            model.validateSelection()
            model.engine?.update(show: newShow)
            model.crew.showChanged(newShow)
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


struct SceneKindBox: Identifiable {
    let kind: ItemKind
    var id: String { kind.rawValue }
}

struct LegacyBox: Identifiable {
    let show: Show
    var id: UUID { show.id }
}

/// A dismissible notice across the top of the window.
struct NoticeBanner: View {
    let text: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: "arrow.uturn.backward.circle").foregroundStyle(Gallery.amber)
            Text(text).font(.ocBody).foregroundStyle(Gallery.ink).fixedSize(horizontal: false, vertical: true)
            IconButton(symbol: "xmark", help: "Dismiss", action: dismiss)
        }
        .padding(Space.m)
        .frame(maxWidth: 620)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).strokeBorder(Gallery.amber.opacity(0.5), lineWidth: 1))
    }
}

/// Identifiable wrapper so a switch log can drive a sheet.
struct ReportBox: Identifiable {
    let log: SwitchLog
    var id: String { log.fileName + "\(log.entries.count)" }
}

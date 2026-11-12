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
        NavigationSplitView {
            RunningOrderView(show: show, model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 400)
        } detail: {
            Group {
                if let item = show.item(model.selectedItemID) {
                    ItemEditorView(show: show, item: item, model: model)
                        .id(item.id)
                        .transition(.opacity)
                } else {
                    EmptyProductionView(model: model, hasItems: !show.items.isEmpty)
                }
            }
            .frame(minWidth: 560)
            .animation(.easeOut(duration: 0.14), value: model.selectedItemID)
        }
        .inspector(isPresented: $model.showInspector) {
            InspectorView(show: show, model: model)
                .inspectorColumnWidth(min: 280, ideal: 320, max: 460)
        }
        if let cursor = model.live {
            LiveView(show: show, cursor: cursor, model: model)
                .transition(.opacity)
        }
        }
        .animation(.easeOut(duration: 0.18), value: model.live == nil)
        .toolbar(model.live == nil ? .visible : .hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.addSong() } label: { Label("New Song", systemImage: "music.note.list") }
                    .help("New song (⌥⌘N)")
                Button { model.addSegment() } label: { Label("New Segment", systemImage: "rectangle.split.3x1") }
                    .help("New segment (⌥⇧⌘N)")
                Button { model.cameraManagerOpen = true } label: { Label("Cameras", systemImage: "video") }
                    .help("Cameras (⌥⌘C)")
                Button { model.enterLive() } label: { Label("Live Mode", systemImage: "dot.radiowaves.left.and.right") }
                    .help("Live Mode (⌘L)")
                Button { model.showInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.right") }
                    .help("Show or hide the inspector (⌥⌘I)")
            }
        }
        .sheet(isPresented: $model.cameraManagerOpen) {
            CameraManagerView(show: show, model: model)
        }
        .alert("Can't do that", isPresented: Binding(get: { model.errorMessage != nil },
                                                      set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .background(Gallery.base)
        .preferredColorScheme(.dark)
        .tint(Gallery.steel)
        .focusedSceneObject(model)
        .onAppear { model.attach(document: $document, undoManager: undoManager) }
        .onChange(of: show.id) { _, _ in model.attach(document: $document, undoManager: undoManager) }
        .onChange(of: show) { _, _ in model.validateSelection() }
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

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
        NavigationSplitView {
            RunningOrderView(show: show, model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 400)
        } detail: {
            Group {
                if let item = show.item(model.selectedItemID) {
                    ItemEditorView(show: show, item: item, model: model)
                } else {
                    EmptyProductionView(model: model, hasItems: !show.items.isEmpty)
                }
            }
            .frame(minWidth: 560)
        }
        .inspector(isPresented: $model.showInspector) {
            InspectorView(show: show, model: model)
                .inspectorColumnWidth(min: 260, ideal: 320, max: 460)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.addSong() } label: { Label("New Song", systemImage: "music.note.list") }
                    .help("New song (⌥⌘N)")
                Button { model.addSegment() } label: { Label("New Segment", systemImage: "rectangle.split.3x1") }
                    .help("New segment (⌥⇧⌘N)")
                Button { model.cameraManagerOpen = true } label: { Label("Cameras", systemImage: "video") }
                    .help("Cameras (⌥⌘C)")
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
        .background(Gallery.canvas)
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
        VStack(spacing: 18) {
            Text(hasItems ? "Pick a song or segment from the running order." : "Start the running order")
                .font(.title(22))
                .foregroundStyle(Gallery.ink)
            if !hasItems {
                Text("Add the first song or segment, then script its shots.")
                    .foregroundStyle(Gallery.dim)
                HStack(spacing: 12) {
                    Button("New Song") { model.addSong() }
                        .keyboardShortcut(.defaultAction)
                    Button("New Segment") { model.addSegment() }
                }
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Gallery.canvas)
    }
}

import SwiftUI
import AppKit
import OnCueCore

@main
struct OnCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var machine = MachineProfileModel.shared
    @StateObject private var library = LibraryModel()

    var body: some Scene {
        // The Project Library is the first window: OnCue opens on it.
        Window("Projects", id: LibraryModel.windowID) {
            LibraryView(library: library)
        }
        .defaultSize(width: 1040, height: 640)

        DocumentGroup(newDocument: ProjectDocument()) { file in
            ShowWorkspaceView(document: file.$document, fileURL: file.fileURL)
                .environmentObject(machine)
                .environmentObject(library)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            WorkspaceCommands()
            LibraryCommands()
        }

        Settings {
            MachineProfileView()
                .environmentObject(machine)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Open on the Project Library, not the system's document Open panel.
        UserDefaults.standard.register(defaults: ["NSShowAppCentricOpenPanelInsteadOfUntitledFile": false])
    }

    /// No untitled project at launch or when the last window closes: the Library is the way in.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `OnCue --smoke-test <folder>` is used by CI to prove the app launches and that a show can
        // be created, saved, closed and reopened through the real document system.
        SmokeTest.runIfRequested()
        // `OnCue --screenshots <folder>` opens the sample production and saves window images.
        ScreenshotRun.runIfRequested()
        // `OnCue --soak <folder> --hours 24 --speed 5`: the long-run memory and timing check.
        SoakTest.runIfRequested()
        Updater.shared.start()
    }
}

/// Bridges this Mac's profile (OnCueCore) to SwiftUI. Lives for the whole app, independent of any
/// open show: opening or closing shows never changes it, and editing it never changes a show.
final class MachineProfileModel: ObservableObject {
    /// The one profile model for the app (Settings, Live Mode, updates).
    static let shared = MachineProfileModel()
    private let store: MachineProfileStore
    @Published private(set) var profile: MachineProfile
    @Published private(set) var issue: String?
    @Published private(set) var saveError: String?

    init(store: MachineProfileStore = MachineProfileStore()) {
        self.store = store
        profile = store.profile
        issue = store.issue
    }

    var fileURL: URL { store.fileURL }

    func update(_ change: (inout MachineProfile) -> Void) {
        do {
            try store.update(change)
            saveError = nil
        } catch {
            saveError = "This Mac's settings could not be saved: \(error.localizedDescription)"
        }
        profile = store.profile
    }
}


/// Window › Project Library (⇧⌘L) and File › Project Properties (⌥⌘,).
struct LibraryCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedObject private var workspace: WorkspaceModel?

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { Updater.shared.check(manual: true) }
        }
        CommandGroup(before: .windowList) {
            Button("Project Library") { openWindow(id: LibraryModel.windowID) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Divider()
        }
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Project Properties…") { workspace?.projectPropertiesOpen = true }
                .keyboardShortcut(",", modifiers: [.command, .option])
                .disabled(workspace == nil)
            Button("Versions…") { workspace?.versionsOpen = true }
                .disabled(workspace == nil)
        }
    }
}

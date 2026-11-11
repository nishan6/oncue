import SwiftUI
import AppKit
import OnCueCore

@main
struct OnCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var machine = MachineProfileModel()

    var body: some Scene {
        DocumentGroup(newDocument: ShowDocument()) { file in
            ShowWindow(document: file.$document, fileURL: file.fileURL)
                .environmentObject(machine)
        }

        Settings {
            MachineProfileView()
                .environmentObject(machine)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `OnCue --smoke-test <folder>` is used by CI to prove the app launches and that a show can
        // be created, saved, closed and reopened through the real document system.
        SmokeTest.runIfRequested()
    }
}

/// Bridges this Mac's profile (OnCueCore) to SwiftUI. Lives for the whole app, independent of any
/// open show: opening or closing shows never changes it, and editing it never changes a show.
final class MachineProfileModel: ObservableObject {
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

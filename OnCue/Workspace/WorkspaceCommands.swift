import SwiftUI
import OnCueCore

/// Menu bar commands for the focused production window. Each has a keyboard shortcut.
struct WorkspaceCommands: Commands {
    @FocusedObject private var workspace: WorkspaceModel?

    var body: some Commands {
        CommandMenu("Production") {
            Group {
            Button("New Song") { workspace?.addSong() }
                .keyboardShortcut("n", modifiers: [.command, .option])
            Button("New Segment") { workspace?.addSegment() }
                .keyboardShortcut("n", modifiers: [.command, .option, .shift])
            Button("New Section") { workspace?.addSection() }
                .keyboardShortcut("e", modifiers: [.command, .option])
            Divider()
            Button("Previous Song or Segment") { workspace?.selectItem(offset: -1) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Song or Segment") { workspace?.selectItem(offset: 1) }
                .keyboardShortcut("]", modifiers: .command)
            Divider()
            Button("Cameras…") { workspace?.cameraManagerOpen = true }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("Show or Hide Inspector") { workspace?.showInspector.toggle() }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
            .disabled(workspace == nil)
        }

        CommandMenu("Shot") {
            Group {
            Button("New Shot") { workspace?.addShot() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Duplicate Shot") { workspace?.duplicateSelectedShots() }
                .keyboardShortcut("d", modifiers: .command)
            Button("Move Shot Up") { workspace?.nudgeSelectedShot(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Move Shot Down") { workspace?.nudgeSelectedShot(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            Button("Switch Cut or Mix") { workspace?.toggleTransitionOfSelection() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Divider()
            Button("Delete Shot") { workspace?.deleteSelectedShots() }
                .keyboardShortcut(.delete, modifiers: .command)
            }
            .disabled(workspace == nil)
        }
    }
}

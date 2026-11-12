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
            Button("Previous Song or Segment") {
                if workspace?.live != nil { workspace?.liveMoveItem(by: -1) } else { workspace?.selectItem(offset: -1) }
            }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Song or Segment") {
                if workspace?.live != nil { workspace?.liveMoveItem(by: 1) } else { workspace?.selectItem(offset: 1) }
            }
                .keyboardShortcut("]", modifiers: .command)
            Divider()
            Button(workspace?.live == nil ? "Enter Live Mode" : "Exit Live Mode") { workspace?.toggleLive() }
                .keyboardShortcut("l", modifiers: .command)
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
            Button("Delete") { workspace?.deleteSelection() }
                .keyboardShortcut(.delete, modifiers: .command)
            }
            .disabled(workspace == nil)
        }

        CommandGroup(after: .toolbar) {
            Group {
            Button("Timeline") { workspace?.editorMode = .timeline }
                .keyboardShortcut("1", modifiers: .command)
            Button("Timeline and List") { workspace?.editorMode = .split }
                .keyboardShortcut("2", modifiers: .command)
            Button("List") { workspace?.editorMode = .list }
                .keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Zoom In") { workspace?.changeZoom(by: 1.4) }
                .keyboardShortcut("=", modifiers: .command)
            Button("Zoom Out") { workspace?.changeZoom(by: 1 / 1.4) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Actual Size") { workspace?.zoom = 1 }
                .keyboardShortcut("0", modifiers: .command)
            }
            .disabled(workspace == nil)
        }
    }
}

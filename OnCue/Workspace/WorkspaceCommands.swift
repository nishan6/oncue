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
                if let engine = workspace?.engine { engine.moveItem(by: -1) } else { workspace?.selectItem(offset: -1) }
            }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Song or Segment") {
                if let engine = workspace?.engine { engine.moveItem(by: 1) } else { workspace?.selectItem(offset: 1) }
            }
                .keyboardShortcut("]", modifiers: .command)
            Divider()
            Button(workspace?.isLive == true ? "Exit Live Mode" : "Enter Live Mode") { workspace?.toggleLive() }
                .keyboardShortcut("l", modifiers: .command)
            Divider()
            Button("Open Switch Log…") {
                SwitchLogPicker.choose { workspace?.reportLog = $0 } failure: { workspace?.errorMessage = $0 }
            }
            Button("Camera Plot…") { workspace?.plotOpen = true }
                .keyboardShortcut("p", modifiers: [.command, .option])
            Button("Tour…") { workspace?.tourOpen = true }
            Button("Pre-show Check…") { workspace?.preShowCheckOpen = true }
                .keyboardShortcut("k", modifiers: [.command, .option])
            Menu("Draft Script") {
                Button("From Switch Log…") { if let w = workspace { DraftSource.chooseLog(model: w) } }
                Button("From EDL…") { if let w = workspace { DraftSource.chooseEDL(model: w) } }
            }
            Button("Export…") { workspace?.exportOpen = true }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Divider()
            Button("Show Setup…") { workspace?.switcherSetupOpen = true }
                .keyboardShortcut("s", modifiers: [.command, .option])
            Button("Cameras…") { workspace?.cameraManagerOpen = true }
                .keyboardShortcut("c", modifiers: [.command, .option])
            Button("Trigger Routes…") { workspace?.triggerRoutesOpen = true }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("Device Status…") { workspace?.deviceStatusOpen = true }
                .keyboardShortcut("d", modifiers: [.command, .option])
            Button("Go To…") { workspace?.paletteOpen = true }
                .keyboardShortcut("k", modifiers: .command)
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
            Button("Switch Cut or Transition") { workspace?.toggleTransitionOfSelection() }
                .keyboardShortcut("t", modifiers: [.command, .option])
            Divider()
            Menu("Quantise") {
                ForEach(workspace?.selectedItem.map { QuantizeGrid.choices(for: $0) } ?? []) { grid in
                    Button(grid.label) { workspace?.quantize(to: grid) }
                }
            }
            .disabled(workspace?.selectedItem?.timeBase == .order)
            Button("Move All From Here…") { workspace?.moveAllOpen = true }
                .disabled(workspace?.moveAllStart == nil || workspace?.selectedItem?.timeBase == .order)
            Button("Select Shots From Here to the End") { workspace?.selectShotsFromHere() }
            Button("Select Shots in This Section") { workspace?.selectShotsInSection() }
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
            Divider()
            Button("Play or Pause Media") {
                if let w = workspace, w.engine == nil, let item = w.show.item(w.selectedItemID), item.media != nil { w.media.toggle(item) }
            }
            .keyboardShortcut(.space, modifiers: .option)
            }
            .disabled(workspace == nil)
        }
    }
}

import SwiftUI
import OnCueCore

/// Settings window: this Mac's hardware profile (never stored in shows).
struct MachineProfileView: View {
    @EnvironmentObject private var machine: MachineProfileModel

    var body: some View {
        Form {
            Section("This Mac") {
                field("Name", \.machineName, prompt: "Main Mac")
            }
            Section("MIDI") {
                field("Clock source", \.midiClockSource, prompt: "IAC Driver Bus 1")
                field("Controller in", \.controllerSource, prompt: "APC40 mkII")
                field("Controller out", \.controllerDestination, prompt: "APC40 mkII")
            }
            Section("Network") {
                field("Crew page interface", \.crewInterface, prompt: "en0")
                field("Companion host", \.companionHost, prompt: "127.0.0.1")
            }
            Section("Backup") {
                field("Role (off, primary, backup)", \.backupRole, prompt: "off")
                field("Primary Mac address", \.primaryHost, prompt: "192.168.10.20")
            }
            if let error = machine.saveError {
                Text(error).foregroundStyle(.red)
            }
            Text("Saved in \(machine.fileURL.path)").font(.footnote).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    private func field(_ label: String, _ key: WritableKeyPath<MachineProfile, String>, prompt: String) -> some View {
        TextField(label, text: Binding(
            get: { machine.profile[keyPath: key] },
            set: { value in machine.update { $0[keyPath: key] = value } }
        ), prompt: Text(prompt))
    }
}

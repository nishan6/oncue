import SwiftUI
import OnCueCore

/// Settings window: this Mac's hardware profile (never stored in shows).
struct MachineProfileView: View {
    @EnvironmentObject private var machine: MachineProfileModel
    @State private var midiSources: [String] = MIDISources.names()
    @State private var audioInputs: [AudioInputDevice] = AudioInputDevice.all()

    var body: some View {
        Form {
            Section("This Mac") {
                field("Name", \.machineName, prompt: "Main Mac")
            }
            Section("MIDI") {
                Picker("Clock source", selection: Binding(get: { machine.profile.midiClockSource },
                                                          set: { v in machine.update { $0.midiClockSource = v } })) {
                    Text("None").tag("")
                    ForEach(midiSources, id: \.self) { Text($0).tag($0) }
                    if !machine.profile.midiClockSource.isEmpty && !midiSources.contains(machine.profile.midiClockSource) {
                        Text("\(machine.profile.midiClockSource) (not connected)").tag(machine.profile.midiClockSource)
                    }
                }
                field("Controller in", \.controllerSource, prompt: "APC40 mkII")
                field("Controller out", \.controllerDestination, prompt: "APC40 mkII")
            }
            Section("LTC") {
                Picker("Audio input", selection: Binding(get: { machine.profile.ltcDeviceUID },
                                                         set: { v in machine.update { $0.ltcDeviceUID = v } })) {
                    Text("Default input").tag("")
                    ForEach(audioInputs) { Text($0.name).tag($0.uid) }
                }
                Stepper("Channel \(machine.profile.ltcChannel + 1)", value: Binding(get: { machine.profile.ltcChannel },
                                                                                set: { v in machine.update { $0.ltcChannel = max(0, v) } }), in: 0...63)
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
        .scrollContentBackground(.hidden)
        .background(Gallery.panel)
        .frame(width: 480)
        .preferredColorScheme(.dark)
        .tint(Gallery.selection)
    }

    private func field(_ label: String, _ key: WritableKeyPath<MachineProfile, String>, prompt: String) -> some View {
        TextField(label, text: Binding(
            get: { machine.profile[keyPath: key] },
            set: { value in machine.update { $0[keyPath: key] = value } }
        ), prompt: Text(prompt))
    }
}

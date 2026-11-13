import SwiftUI
import AppKit
import OnCueCore

/// Settings window: this Mac's hardware profile (never stored in shows).
struct MachineProfileView: View {
    @EnvironmentObject private var machine: MachineProfileModel
    @State private var midiSources: [String] = MIDISources.names()
    @State private var midiDestinations: [String] = MIDIDestinations.names()
    @State private var audioInputs: [AudioInputDevice] = AudioInputDevice.all()
    @State private var audioOutputs: [AudioInputDevice] = AudioInputDevice.allOutputs()

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
                Picker("Controller in", selection: Binding(get: { machine.profile.controllerSource },
                                                           set: { v in machine.update { $0.controllerSource = v } })) {
                    Text("None").tag("")
                    ForEach(midiSources, id: \.self) { Text($0).tag($0) }
                    if !machine.profile.controllerSource.isEmpty && !midiSources.contains(machine.profile.controllerSource) {
                        Text("\(machine.profile.controllerSource) (not connected)").tag(machine.profile.controllerSource)
                    }
                }
                Picker("Controller lights", selection: Binding(get: { machine.profile.controllerDestination },
                                                               set: { v in machine.update { $0.controllerDestination = v } })) {
                    Text("None").tag("")
                    ForEach(midiDestinations, id: \.self) { Text($0).tag($0) }
                    if !machine.profile.controllerDestination.isEmpty && !midiDestinations.contains(machine.profile.controllerDestination) {
                        Text("\(machine.profile.controllerDestination) (not connected)").tag(machine.profile.controllerDestination)
                    }
                }
                Toggle("Pad tally (red program, green preview)", isOn: Binding(get: { machine.profile.apcLEDs },
                                                                                set: { v in machine.update { $0.apcLEDs = v } }))
            }
            Section("LTC") {
                Picker("Audio input", selection: Binding(get: { machine.profile.ltcDeviceUID },
                                                         set: { v in machine.update { $0.ltcDeviceUID = v } })) {
                    Text("Default input").tag("")
                    ForEach(audioInputs) { Text($0.name).tag($0.uid) }
                }
                Stepper("Channel \(machine.profile.ltcChannel + 1)", value: Binding(get: { machine.profile.ltcChannel },
                                                                                set: { v in machine.update { $0.ltcChannel = max(0, v) } }), in: 0...63)
                Picker("LTC output", selection: Binding(get: { machine.profile.ltcOutputMode },
                                                        set: { v in machine.update { $0.ltcOutputMode = v } })) {
                    ForEach(LTCOutputMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                if machine.profile.ltcOutputMode != "off" {
                    Picker("Output device", selection: Binding(get: { machine.profile.ltcOutputDevice },
                                                               set: { v in machine.update { $0.ltcOutputDevice = v } })) {
                        Text("Default output").tag("")
                        ForEach(audioOutputs) { Text($0.name).tag($0.uid) }
                    }
                    Text("Master timecode on both channels of the device while Live Mode is on, at the show's frame rate. Use a spare output: it is loud.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Companion and Stream Deck") {
                field("Companion host", \.companionHost, prompt: "127.0.0.1")
                TextField("Companion port", value: Binding(get: { machine.profile.companionPort },
                                                           set: { v in machine.update { $0.companionPort = v } }), format: .number.grouping(.never))
                Picker("Companion version", selection: Binding(get: { machine.profile.companionVersion },
                                                               set: { v in machine.update { $0.companionVersion = v } })) {
                    Text("3.x or newer").tag("v3")
                    Text("2.x").tag("v2")
                }
                Toggle("Send Live status to Companion variables", isOn: Binding(get: { machine.profile.companionVariables },
                                                                                set: { v in machine.update { $0.companionVariables = v } }))
                TextField("OSC control port", value: Binding(get: { machine.profile.oscControlPort },
                                                             set: { v in machine.update { $0.oscControlPort = v } }), format: .number.grouping(.never))
                Text("Stream Deck keys in Companion send OSC to this Mac on that port: /oncue/next, /oncue/go, /oncue/tapSection, /oncue/panic, /oncue/resume, /oncue/takeCamera/<n>, /oncue/previewCamera/<n>, /oncue/modeCut… Variables: $(custom:oncue_now), oncue_next, oncue_now_name, oncue_next_name, oncue_mode, oncue_countdown, oncue_item, oncue_section, oncue_paused, oncue_free.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Crew network") {
                field("Crew page interface", \.crewInterface, prompt: "en0")
            }
            Section("Backup") {
                HStack {
                    TextField("Backup folder", text: .constant(machine.profile.backupFolder.isEmpty ? "Off" : machine.profile.backupFolder))
                        .disabled(true)
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        panel.prompt = "Back Up Here"
                        if panel.runModal() == .OK, let url = panel.url { machine.update { $0.backupFolder = url.path } }
                    }
                    if !machine.profile.backupFolder.isEmpty {
                        Button("Off") { machine.update { $0.backupFolder = "" } }
                    }
                }
                Text("Every show is copied here a few seconds after each change, with the last 30 copies kept. iCloud Drive, a NAS or a USB drive all work.")
                    .font(.footnote).foregroundStyle(.secondary)
                Picker("This Mac in Live Mode", selection: Binding(get: { machine.profile.backupRole }, set: { v in machine.update { $0.backupRole = v } })) {
                    Text("Runs the show").tag("off")
                    Text("Main, with a backup Mac following").tag("primary")
                    Text("Backup, following the main Mac").tag("backup")
                }
                if machine.profile.backupRole == "backup" {
                    field("Main Mac address", \.primaryHost, prompt: "192.168.10.20")
                }
            }
            Section("Accessibility") {
                Picker("Text size", selection: Binding(get: { machine.profile.textScale }, set: { v in machine.update { $0.textScale = v } })) {
                    Text("Standard").tag(1.0)
                    Text("Large").tag(1.15)
                    Text("Larger").tag(1.3)
                }
                Toggle("Show tally with shapes and words, not only red and green", isOn: Binding(get: { machine.profile.tallyShapes },
                                                                                               set: { v in machine.update { $0.tallyShapes = v } }))
                Text("On air gets a filled circle and PGM, stand by a hollow triangle and PVW, in Live Mode, the monitors and the crew pages.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: Binding(get: { machine.profile.checkForUpdates },
                                                                       set: { v in machine.update { $0.checkForUpdates = v } }))
                HStack {
                    Text("OnCue looks for a new version every 6 hours and asks before installing. It never checks or installs during Live Mode.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Now") { Updater.shared.check(manual: true) }
                }
            }
            if let error = machine.saveError {
                Text(error).foregroundStyle(.red)
            }
            Text("Saved in \(machine.fileURL.path)").font(.footnote).foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Gallery.panel)
        .frame(width: 540, height: 680)
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

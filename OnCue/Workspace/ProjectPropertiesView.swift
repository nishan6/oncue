import SwiftUI
import OnCueCore

/// File › Project Properties: name, artist, venue, show date, frame rate, scene defaults and
/// roles. Edits a copy; nothing changes until OK, and Cancel leaves the project as it was.
struct ProjectPropertiesView: View {
    let project: Project
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Project()
    @State private var loaded = false
    var initialTab = 0
    @State private var tab = 0
    @State private var hasDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("PROJECT PROPERTIES").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            Form {
                TextField("Name", text: $draft.name)
                TextField("Artist", text: $draft.artist)
                TextField("Venue", text: $draft.venue)
                HStack {
                    Toggle("Show date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("", selection: Binding(get: { draft.showDate ?? Date() }, set: { draft.showDate = $0 }),
                                   displayedComponents: .date).labelsHidden()
                    }
                }
                LabeledContent("Frame rate") { FrameRatePicker(rate: $draft.frameRate) }
            }
            Picker("", selection: $tab) {
                Text("Scene defaults").tag(0)
                Text("Shots").tag(2)
                Text("Timecode").tag(3)
                Text("Roles").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 420)

            Group {
                switch tab {
                case 0: sceneDefaults
                case 2: ShotVocabularyEditor(vocab: $draft.properties.shots, countdown: $draft.properties.countdown)
                case 3: chaseSettings
                default: roles
                }
            }
            .padding(Space.m)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
            .background(Gallery.well, in: RoundedRectangle(cornerRadius: Radius.m))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("OK") {
                    var result = draft
                    if !hasDate { result.showDate = nil }
                    model.editProject("Project Properties") { p in
                        p.name = result.name.trimmingCharacters(in: .whitespaces).isEmpty ? p.name : result.name
                        p.artist = result.artist
                        p.venue = result.venue
                        p.showDate = result.showDate
                        if p.frameRate != result.frameRate {
                            p.frameRate = result.frameRate
                            p.settings.ltcFPS = result.frameRate.fps
                            p.quantizePositions()
                        }
                        p.properties = result.properties
                    }
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(!startTimecodeValid)
            }
        }
        .padding(Space.l)
        .frame(width: 680)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !loaded else { return }
            draft = project
            tab = initialTab
            hasDate = project.showDate != nil
            loaded = true
        }
    }

    private var startTimecodeValid: Bool {
        Timecode.frames(draft.properties.sceneDefaults.startTimecode, rate: draft.frameRate) != nil
    }

    private var sceneDefaults: some View {
        let d = $draft.properties.sceneDefaults
        return VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.l) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Starting timecode").font(.ocMeta).foregroundStyle(Gallery.dim)
                    TextField("01:00:00:00", text: d.startTimecode).textFieldStyle(.roundedBorder).frame(width: 130)
                        .font(.readout(12))
                    if !startTimecodeValid {
                        Text("Not a timecode at \(draft.frameRate.label)").font(.ocMeta).foregroundStyle(Gallery.amber)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration").font(.ocMeta).foregroundStyle(Gallery.dim)
                    CommitField(placeholder: "3:00", value: TimeFormat.hms(Double(draft.properties.sceneDefaults.durationSeconds)), width: 100) { text in
                        guard let s = TimeFormat.parseSeconds(text), s >= 0 else { return false }
                        draft.properties.sceneDefaults.durationSeconds = Int(s.rounded())
                        return true
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timecode chase").font(.ocMeta).foregroundStyle(Gallery.dim)
                    Picker("", selection: d.timecodeChase) {
                        Text("Off").tag(false)
                        Text("On").tag(true)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }
            }
            HStack(alignment: .top, spacing: Space.l) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shot numbering mode").font(.ocMeta).foregroundStyle(Gallery.dim)
                    Picker("", selection: d.numberingMode) {
                        ForEach(NumberingMode.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 240)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Numbering from").font(.ocMeta).foregroundStyle(Gallery.dim)
                    Stepper(value: d.numberingFrom, in: 0...9999) {
                        Text("\(draft.properties.sceneDefaults.numberingFrom)").font(.readout(12))
                    }
                }
            }
            Text("Default tracks").font(.ocMeta).foregroundStyle(Gallery.dim)
            VStack(spacing: 4) {
                ForEach(Array(draft.properties.sceneDefaults.tracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: Space.s) {
                        VStack(spacing: 0) {
                            IconButton(symbol: "chevron.up", help: "Move up", size: 18) { moveTrack(index, by: -1) }
                            IconButton(symbol: "chevron.down", help: "Move down", size: 18) { moveTrack(index, by: 1) }
                        }
                        Picker("", selection: d.tracks[index].kind) {
                            ForEach(SceneTrackKind.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                        if track.kind == .edit {
                            Picker("", selection: d.tracks[index].routeTo) {
                                Text("Main output").tag(UUID?.none)
                                ForEach(draft.outputs) { Text($0.name).tag(UUID?.some($0.id)) }
                            }
                            .labelsHidden()
                            .frame(width: 160)
                        }
                        if !track.kind.hasLaneToday {
                            Text("lane arrives in Phase 2").font(.ocMeta).foregroundStyle(Gallery.faint)
                        }
                        Spacer()
                        IconButton(symbol: "xmark.circle", help: "Remove") {
                            draft.properties.sceneDefaults.tracks.remove(at: index)
                        }
                    }
                }
                HStack {
                    Button { draft.properties.sceneDefaults.tracks.append(DefaultTrack(kind: .edit)) } label: {
                        Label("Add track", systemImage: "plus")
                    }
                    .buttonStyle(QuietButtonStyle())
                    Spacer()
                }
            }
        }
    }

    private var chaseSettings: some View {
        let chase = $draft.properties.chase
        return VStack(alignment: .leading, spacing: Space.m) {
            Text("When the timecode OnCue follows drops out mid-song").font(.ocMeta).foregroundStyle(Gallery.dim)
            Picker("", selection: chase.freewheel) {
                ForEach(FreewheelMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            if draft.properties.chase.freewheel == .forSeconds {
                Stepper(value: chase.freewheelSeconds, in: 1...60, step: 1) {
                    Text("Keep running for \(Int(draft.properties.chase.freewheelSeconds)) s, then hold").font(.readout(12))
                }
            }
            Text("Freewheeling, OnCue runs on its own clock from the last frame it read, at the song's tempo, and never past the song's end. When timecode comes back, OnCue follows it again. A trigger route can pause chase on purpose (Show › Trigger Routes).")
                .font(.ocMeta).foregroundStyle(Gallery.faint).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moveTrack(_ index: Int, by delta: Int) {
        var tracks = draft.properties.sceneDefaults.tracks
        let target = index + delta
        guard tracks.indices.contains(index), tracks.indices.contains(target) else { return }
        tracks.swapAt(index, target)
        draft.properties.sceneDefaults.tracks = tracks
    }

    private var roles: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(draft.properties.roles.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: Space.s) {
                    TextField("Role", text: $draft.properties.roles[index].name).textFieldStyle(.roundedBorder)
                    IconButton(symbol: "xmark.circle", help: "Remove this role") {
                        draft.properties.roles.remove(at: index)
                    }
                }
            }
            HStack {
                Button { draft.properties.roles.append(ProjectRole(name: "New role")) } label: { Label("Add role", systemImage: "plus") }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
            }
        }
    }
}

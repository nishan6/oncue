import SwiftUI
import OnCueCore

/// The three pages of the shot inspector.
enum InspectorTab: String, CaseIterable, Identifiable {
    case info, index, reviews
    var id: String { rawValue }
    var label: String {
        switch self {
        case .info: return "Info"
        case .index: return "Index"
        case .reviews: return "Reviews"
        }
    }
}

/// Which vocabulary list a picker edits.
enum VocabularyList: String, Identifiable {
    case size, movement, framing, cast, status, transition
    var id: String { rawValue }
    var noun: String {
        switch self {
        case .size: return "shot size"
        case .movement: return "movement"
        case .framing: return "framing"
        case .cast: return "person or thing on stage"
        case .status: return "status"
        case .transition: return "transition"
        }
    }
}

// MARK: - Shot details (Info page)

/// Size, movement, framing, who is in it, and status. Each list ends with "Add…", which adds a
/// term to this project's list and sets it on the shot.
struct ShotDetailsGroup: View {
    let cues: [Cue]
    let ids: Set<UUID>
    @ObservedObject var model: WorkspaceModel
    @State private var adding: VocabularyList?
    @State private var newLabel = ""

    private var vocab: ShotVocabulary { model.project.properties.shots }

    var body: some View {
        InspectorGroup(title: "Shot") {
            PropertyRow(label: "Size") {
                termMenu(.size, terms: vocab.sizes, value: common(\.shotSize)) { key in
                    model.updateShots(ids, "Shot Size") { $0.shotSize = key }
                }
            }
            PropertyRow(label: "Movement") {
                termMenu(.movement, terms: vocab.movements, value: common(\.movement)) { key in
                    model.updateShots(ids, "Shot Movement") { $0.movement = key }
                }
            }
            PropertyRow(label: "Framing") {
                termMenu(.framing, terms: vocab.framings, value: common(\.framing)) { key in
                    model.updateShots(ids, "Shot Framing") { $0.framing = key }
                }
            }
            PropertyRow(label: "Who") { castMenu }
            PropertyRow(label: "Status") { statusMenu }
        }
        .alert("New \(adding?.noun ?? "")", isPresented: Binding(get: { adding != nil }, set: { if !$0 { adding = nil } })) {
            TextField("Name", text: $newLabel)
            Button("Add") { addTerm() }
            Button("Cancel", role: .cancel) { adding = nil }
        } message: {
            Text("Added to this project's list and set on the selected shot\(ids.count == 1 ? "" : "s"). Edit the lists in Project Properties › Shots.")
        }
    }

    /// The value all selected shots share, or nil when they differ.
    private func common(_ path: KeyPath<Cue, String>) -> String? {
        let values = Set(cues.map { $0[keyPath: path] })
        return values.count == 1 ? values.first : nil
    }

    private func termMenu(_ list: VocabularyList, terms: [ShotTerm], value: String?,
                          set: @escaping (String) -> Void) -> some View {
        Menu {
            Button("None") { set("") }
            Divider()
            ForEach(terms) { term in
                Button {
                    set(term.key)
                } label: {
                    if term.key == value { Label(menuLabel(term), systemImage: "checkmark") } else { Text(menuLabel(term)) }
                }
            }
            Divider()
            Button("Add \(list.noun)…") { newLabel = ""; adding = list }
        } label: {
            Text(display(value, in: terms)).font(.ocBody)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func menuLabel(_ term: ShotTerm) -> String {
        term.short == term.label ? term.label : "\(term.short)  \(term.label)"
    }

    private func display(_ value: String?, in terms: [ShotTerm]) -> String {
        guard let value else { return "Mixed" }
        if value.isEmpty { return "–" }
        return terms.first { $0.key == value }.map { $0.short == $0.label ? $0.label : "\($0.short) · \($0.label)" } ?? "(removed)"
    }

    private var castMenu: some View {
        let everyone = Set(cues.flatMap(\.subjects))
        let inAll = Set(vocab.cast.map(\.key).filter { key in cues.allSatisfy { $0.subjects.contains(key) } })
        let names = vocab.cast.filter { inAll.contains($0.key) }.map(\.label)
        let mixed = everyone.count > inAll.count
        return Menu {
            if vocab.cast.isEmpty {
                Text("No one on the list yet")
            }
            ForEach(vocab.cast) { person in
                let on = inAll.contains(person.key)
                Button {
                    model.updateShots(ids, on ? "Remove from Shot" : "Add to Shot") { cue in
                        if on { cue.subjects.removeAll { $0 == person.key } }
                        else if !cue.subjects.contains(person.key) { cue.subjects.append(person.key) }
                    }
                } label: {
                    if on { Label(person.label, systemImage: "checkmark") } else { Text(person.label) }
                }
            }
            Divider()
            Button("Add person or thing…") { newLabel = ""; adding = .cast }
        } label: {
            Text(names.isEmpty ? (mixed ? "Mixed" : "–") : names.joined(separator: ", ") + (mixed ? " +" : ""))
                .font(.ocBody).lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusMenu: some View {
        let value = common(\.shotStatus)
        return Menu {
            ForEach(vocab.statuses) { status in
                Button {
                    model.updateShots(ids, "Shot Status") { $0.shotStatus = status.key }
                } label: {
                    if status.key == value { Label(status.label, systemImage: "checkmark") } else { Text(status.label) }
                }
            }
            Divider()
            Button("Add status…") { newLabel = ""; adding = .status }
        } label: {
            HStack(spacing: 6) {
                if let value, let term = vocab.status(value) {
                    ShotStatusDot(role: term.role, key: term.key)
                    Text(term.label).font(.ocBody)
                } else {
                    Text(value == nil ? "Mixed" : "(removed)").font(.ocBody)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func addTerm() {
        let label = newLabel.trimmingCharacters(in: .whitespaces)
        guard let list = adding, !label.isEmpty else { adding = nil; return }
        adding = nil
        let key: String
        switch list {
        case .status:
            let term = ShotStatusTerm.custom(label)
            key = term.key
            model.editProject("Add Status") { $0.properties.shots.statuses.append(term) }
            model.updateShots(ids, "Shot Status") { $0.shotStatus = key }
        case .cast:
            let term = ShotTerm.custom(label)
            key = term.key
            model.editProject("Add to Cast") { $0.properties.shots.cast.append(term) }
            model.updateShots(ids, "Add to Shot") { if !$0.subjects.contains(key) { $0.subjects.append(key) } }
        case .size, .movement, .framing:
            let term = ShotTerm.custom(label)
            key = term.key
            model.editProject("Add \(list.noun.capitalized)") { p in
                switch list {
                case .size: p.properties.shots.sizes.append(term)
                case .movement: p.properties.shots.movements.append(term)
                default: p.properties.shots.framings.append(term)
                }
            }
            model.updateShots(ids, "Shot \(list.noun.capitalized)") { cue in
                switch list {
                case .size: cue.shotSize = key
                case .movement: cue.movement = key
                default: cue.framing = key
                }
            }
        case .transition:
            break
        }
    }
}

/// Planned / confirmed / custom statuses as a small dot; cut as a hollow ring.
struct ShotStatusDot: View {
    let role: ShotStatusRole
    let key: String

    var body: some View {
        Group {
            if role == .cut {
                Circle().strokeBorder(Gallery.faint, lineWidth: 1.5)
            } else {
                Circle().fill(key == "confirmed" ? Gallery.next : (key == "planned" ? Gallery.dim : Gallery.selection))
            }
        }
        .frame(width: 8, height: 8)
    }
}

// MARK: - Transition

/// Cut or transition; for a transition, its type (Mix, Dip, Wipe, DVE, Stinger or your own) and
/// length in frames.
struct TransitionEditor: View {
    let cues: [Cue]
    let ids: Set<UUID>
    @ObservedObject var model: WorkspaceModel
    @State private var adding = false
    @State private var newLabel = ""
    @State private var newBase: TransitionStyleBase = .mix

    private var vocab: ShotVocabulary { model.project.properties.shots }

    var body: some View {
        let kinds = Set(cues.map(\.transition))
        let styles = Set(cues.map(\.transitionStyle))
        let frames = Set(cues.map(\.transitionFrames))
        VStack(alignment: .leading, spacing: Space.s) {
            PropertyRow(label: "Transition") {
                Picker("Transition", selection: Binding(get: { kinds.count == 1 ? kinds.first! : .cut },
                                                         set: { model.setTransition($0, for: ids) })) {
                    Text("Cut").tag(TransitionKind.cut)
                    Text("Transition").tag(TransitionKind.auto)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 170)
            }
            if kinds.contains(.auto) {
                PropertyRow(label: "Type") {
                    Menu {
                        ForEach(vocab.transitions) { t in
                            Button {
                                model.updateShots(ids, "Transition Type") { $0.transitionStyle = t.key }
                            } label: {
                                if styles == [t.key] { Label(t.label, systemImage: "checkmark") } else { Text(t.label) }
                            }
                        }
                        Divider()
                        Button("Add transition…") { newLabel = ""; newBase = .mix; adding = true }
                    } label: {
                        Text(styles.count == 1 ? (vocab.transition(styles.first!)?.label ?? "(removed)") : "Mixed").font(.ocBody)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                PropertyRow(label: "Length") {
                    HStack(spacing: 4) {
                        CommitField(placeholder: defaultLengthText(styles: styles),
                                    value: frames.count == 1 ? (frames.first!.map(String.init) ?? "") : "",
                                    font: .readout(13), width: 60) { text in
                            let t = text.trimmingCharacters(in: .whitespaces)
                            if t.isEmpty {
                                model.updateShots(ids, "Transition Length") { $0.transitionFrames = nil }
                                return true
                            }
                            guard let n = Int(t), n >= 0, n <= 999 else { return false }
                            model.updateShots(ids, "Transition Length") { $0.transitionFrames = n }
                            return true
                        }
                        Text("frames").font(.ocMeta).foregroundStyle(Gallery.faint)
                    }
                }
            }
        }
        .alert("New transition", isPresented: $adding) {
            TextField("Name, e.g. Logo sting", text: $newLabel)
            Button("Add") { addTransition() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Added to this project as a Mix. Set its type and length in Project Properties › Shots.")
        }
    }

    private func defaultLengthText(styles: Set<String>) -> String {
        guard styles.count == 1, let t = vocab.transition(styles.first!), let f = t.durationFrames else { return "rate" }
        return "\(f)"
    }

    private func addTransition() {
        let label = newLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        let term = TransitionTerm.custom(label, base: newBase)
        model.editProject("Add Transition") { $0.properties.shots.transitions.append(term) }
        model.updateShots(ids, "Transition Type") { $0.transitionStyle = term.key }
    }
}

// MARK: - Index page

/// Every shot in this scene, compact: number, camera, size and description. Click to select.
struct ShotIndexView: View {
    let show: Show
    let item: RundownItem
    let rows: [ShotRow]
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        let vocab = model.project.properties.shots
        VStack(alignment: .leading, spacing: 1) {
            Text("\(rows.count) shots in \(item.title)").sectionLabel()
                .padding(.horizontal, Space.l).padding(.top, Space.m).padding(.bottom, Space.xs)
            ForEach(rows) { row in
                let selected = model.selectedShotIDs.contains(row.id)
                let cut = vocab.isCut(row.cue)
                Button {
                    model.selectShot(row.id, extending: NSEvent.modifierFlags.contains(.command))
                    model.scrollTarget = row.id.uuidString
                } label: {
                    HStack(spacing: Space.s) {
                        Text("\(row.number)").font(.readout(11)).foregroundStyle(Gallery.faint).frame(width: 26, alignment: .trailing)
                        CameraChip(camera: show.camera(row.cue.cameraID), size: 18)
                        Text(vocab.size(row.cue.shotSize)?.short ?? "").font(.readout(10, weight: .semibold))
                            .foregroundStyle(Gallery.dim).frame(width: 34, alignment: .leading)
                        Text(row.cue.text.isEmpty ? "–" : row.cue.text).font(.ocBody)
                            .foregroundStyle(cut ? Gallery.faint : Gallery.ink).strikethrough(cut, color: Gallery.faint)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(item.format(row.cue.at)).font(.readout(10)).foregroundStyle(Gallery.faint)
                    }
                    .padding(.horizontal, Space.l)
                    .frame(height: 26)
                    .background(selected ? Gallery.selection.opacity(0.22) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Reviews page

/// Rehearsal notes on the selected shot, kept in this project only.
struct ShotReviewsView: View {
    let row: ShotRow
    @ObservedObject var model: WorkspaceModel
    @State private var draft = ""

    var body: some View {
        InspectorGroup(title: "Notes on shot \(row.number)") {
            Text("Kept in this project on this Mac. Nothing is shared.").font(.ocMeta).foregroundStyle(Gallery.faint)
            if row.cue.reviews.isEmpty {
                Text("No notes yet.").font(.ocMeta).foregroundStyle(Gallery.faint).padding(.vertical, Space.xs)
            }
            ForEach(row.cue.reviews) { note in
                HStack(alignment: .top, spacing: Space.s) {
                    Button {
                        model.updateShots([row.id], note.resolved ? "Reopen Note" : "Resolve Note") { cue in
                            if let i = cue.reviews.firstIndex(where: { $0.id == note.id }) { cue.reviews[i].resolved.toggle() }
                        }
                    } label: {
                        Image(systemName: note.resolved ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(note.resolved ? Gallery.next : Gallery.faint)
                    }
                    .buttonStyle(.plain)
                    .help(note.resolved ? "Reopen" : "Mark as done")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text).font(.ocBody)
                            .foregroundStyle(note.resolved ? Gallery.faint : Gallery.ink)
                            .strikethrough(note.resolved, color: Gallery.faint)
                            .fixedSize(horizontal: false, vertical: true)
                        MetaLine(parts: [note.author, note.date.formatted(date: .abbreviated, time: .shortened)])
                    }
                    Spacer(minLength: 0)
                    Button {
                        model.updateShots([row.id], "Delete Note") { $0.reviews.removeAll { $0.id == note.id } }
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Gallery.faint)
                    }
                    .buttonStyle(.plain)
                    .help("Delete note")
                }
                .padding(Space.s)
                .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.s))
            }
            HStack(spacing: Space.s) {
                TextField("Add a note, e.g. late on the cut at rehearsal", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let note = ShotNote(text: text, author: NSFullUserName())
        model.updateShots([row.id], "Add Note") { $0.reviews.append(note) }
        draft = ""
    }
}

// MARK: - Vocabulary in the environment

private struct ShotVocabularyKey: EnvironmentKey {
    static let defaultValue = ShotVocabulary()
}

private struct ProjectFrameRateKey: EnvironmentKey {
    static let defaultValue = FrameRate.r25
}

extension EnvironmentValues {
    var projectFrameRate: FrameRate {
        get { self[ProjectFrameRateKey.self] }
        set { self[ProjectFrameRateKey.self] = newValue }
    }

    /// The open project's shot vocabulary, for rows and blocks that show sizes and transitions.
    var shotVocabulary: ShotVocabulary {
        get { self[ShotVocabularyKey.self] }
        set { self[ShotVocabularyKey.self] = newValue }
    }
}

extension ShotVocabulary {
    /// "CUT", or the transition's short name ("MIX", "DIP", "STING").
    func transitionTag(_ cue: Cue) -> String {
        guard cue.transition == .auto else { return "CUT" }
        return transition(cue.transitionStyle)?.short ?? "MIX"
    }
}

// MARK: - Move All

/// Shot › Move All From Here: opens or closes a gap by moving everything from the selection on.
struct MoveAllSheet: View {
    let item: RundownItem?
    let start: Double?
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var amount = "1"

    private var bars: Bool { item?.timeBase == .bars }
    private var value: Double? { Double(amount.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text("MOVE ALL FROM HERE").font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(Gallery.ink)
            if let item, let start {
                Text("Every shot, cue and section from \(item.format(start)) to the end moves together. Use a negative number to close a gap.")
                    .font(.ocBody).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Space.s) {
                TextField("1", text: $amount).textFieldStyle(.roundedBorder).frame(width: 80).font(.readout(13))
                Text(bars ? "bars (½ = 0.5)" : "seconds").font(.ocBody).foregroundStyle(Gallery.dim)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction)
                Button("Move") {
                    if let value { model.moveAll(by: value) }
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
                .disabled(value == nil || value == 0 || start == nil)
            }
        }
        .padding(Space.l)
        .frame(width: 420)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }
}

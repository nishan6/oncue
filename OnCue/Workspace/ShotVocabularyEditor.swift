import SwiftUI
import OnCueCore

/// Project Properties › Shots: the project's sizes, movements, framings, cast, statuses and
/// transitions, plus the countdown. Built-in terms can be renamed but not removed.
struct ShotVocabularyEditor: View {
    @Binding var vocab: ShotVocabulary
    @Binding var countdown: CountdownSettings
    @State private var list: VocabularyList = .size

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Picker("", selection: $list) {
                Text("Sizes").tag(VocabularyList.size)
                Text("Movement").tag(VocabularyList.movement)
                Text("Framing").tag(VocabularyList.framing)
                Text("Cast").tag(VocabularyList.cast)
                Text("Status").tag(VocabularyList.status)
                Text("Transitions").tag(VocabularyList.transition)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    switch list {
                    case .size: terms($vocab.sizes, short: true)
                    case .movement: terms($vocab.movements, short: true)
                    case .framing: terms($vocab.framings, short: true)
                    case .cast: terms($vocab.cast, short: false)
                    case .status: statuses
                    case .transition: transitions
                    }
                }
            }
            .frame(height: 200)

            Rectangle().fill(Gallery.hairline).frame(height: 1)
            HStack(spacing: Space.l) {
                Text("Countdown").font(.ocMeta).foregroundStyle(Gallery.dim)
                Toggle("Next shot", isOn: $countdown.showNextShot)
                Toggle("Next section", isOn: $countdown.showNextSection)
                Toggle("Standby", isOn: $countdown.showStandby)
                HStack(spacing: 4) {
                    Stepper(value: $countdown.standbySeconds, in: 1...30, step: 1) {
                        Text("\(Int(countdown.standbySeconds)) s before the cut").font(.readout(12))
                    }
                    .disabled(!countdown.showStandby)
                }
            }
            .toggleStyle(.checkbox)
        }
    }

    private func terms(_ terms: Binding<[ShotTerm]>, short: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(terms) { $term in
                HStack(spacing: Space.s) {
                    if short {
                        TextField("Short", text: $term.short).textFieldStyle(.roundedBorder).frame(width: 90)
                            .font(.readout(12))
                    }
                    TextField("Name", text: $term.label).textFieldStyle(.roundedBorder)
                    removeButton(builtIn: term.builtIn) { terms.wrappedValue.removeAll { $0.key == term.key } }
                }
            }
            HStack {
                Button { terms.wrappedValue.append(.custom(list == .cast ? "New person" : "New")) } label: {
                    Label(list == .cast ? "Add person or thing" : "Add", systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle())
                if list == .cast {
                    Text("Who appears in shots: lead vocal, drummer, host, crowd…").font(.ocMeta).foregroundStyle(Gallery.faint)
                }
            }
        }
    }

    private var statuses: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($vocab.statuses) { $status in
                HStack(spacing: Space.s) {
                    ShotStatusDot(role: status.role, key: status.key)
                    TextField("Name", text: $status.label).textFieldStyle(.roundedBorder)
                    Picker("", selection: $status.role) {
                        Text("Runs").tag(ShotStatusRole.active)
                        Text("Greyed out").tag(ShotStatusRole.cut)
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    .disabled(status.builtIn)
                    removeButton(builtIn: status.builtIn) { vocab.statuses.removeAll { $0.key == status.key } }
                }
            }
            Button { vocab.statuses.append(.custom("New status")) } label: { Label("Add status", systemImage: "plus") }
                .buttonStyle(QuietButtonStyle())
        }
    }

    private var transitions: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($vocab.transitions) { $t in
                HStack(spacing: Space.s) {
                    TextField("Short", text: $t.short).textFieldStyle(.roundedBorder).frame(width: 80).font(.readout(12))
                    TextField("Name", text: $t.label).textFieldStyle(.roundedBorder)
                    Picker("", selection: $t.base) {
                        ForEach(TransitionStyleBase.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                    .disabled(t.builtIn)
                    TextField("rate", text: Binding(get: { t.durationFrames.map(String.init) ?? "" },
                                                    set: { t.durationFrames = Int($0.trimmingCharacters(in: .whitespaces)) }))
                        .textFieldStyle(.roundedBorder).frame(width: 50).font(.readout(12))
                        .help("Length in frames. Empty uses the switcher's own rate.")
                    Text("fr").font(.ocMeta).foregroundStyle(Gallery.faint)
                    removeButton(builtIn: t.builtIn) { vocab.transitions.removeAll { $0.key == t.key } }
                }
            }
            HStack {
                Button { vocab.transitions.append(.custom("New transition", base: .mix)) } label: {
                    Label("Add transition", systemImage: "plus")
                }
                .buttonStyle(QuietButtonStyle())
                Text("Scripted only for now: the switcher still runs its own auto transition (see the Phase 2 report).")
                    .font(.ocMeta).foregroundStyle(Gallery.faint)
            }
        }
    }

    @ViewBuilder
    private func removeButton(builtIn: Bool, remove: @escaping () -> Void) -> some View {
        if builtIn {
            Image(systemName: "lock").font(.system(size: 10)).foregroundStyle(Gallery.faint).frame(width: 22)
                .help("Standard term: rename it if you like; it can't be removed")
        } else {
            IconButton(symbol: "xmark.circle", help: "Remove. Shots that use it show “(removed)”.", action: remove)
        }
    }
}

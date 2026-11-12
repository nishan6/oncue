import SwiftUI
import OnCueCore

/// Production › Pre-show Check: runs every check and lists what needs attention first.
struct PreShowCheckView: View {
    @StateObject private var check: PreShowCheck
    @Environment(\.dismiss) private var dismiss
    let model: WorkspaceModel

    init(show: Show, model: WorkspaceModel) {
        _check = StateObject(wrappedValue: PreShowCheck(show: show, profile: MachineProfileStore().profile))
        self.model = model
    }

    private var groups: [String] {
        var seen: [String] = []
        for item in check.items where !seen.contains(item.group) { seen.append(item.group) }
        return seen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pre-show check").font(.ocTitle).foregroundStyle(Gallery.ink)
                    Text(summary).font(.ocMeta).foregroundStyle(summaryColor)
                }
                Spacer()
                Button("Run again") { check.run() }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(check.running)
                Button("Done") { dismiss() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(Space.l)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(group).sectionLabel()
                            ForEach(check.items.filter { $0.group == group }) { item in
                                CheckRow(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.l)
                .padding(.bottom, Space.l)
            }
        }
        .frame(width: 640, height: 620)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
        .onAppear { check.run() }
    }

    private var summary: String {
        if check.running { return "Checking…" }
        if check.failures > 0 { return check.failures == 1 ? "1 problem to fix" : "\(check.failures) problems to fix" }
        if check.warnings > 0 { return check.warnings == 1 ? "Ready, with 1 thing to look at" : "Ready, with \(check.warnings) things to look at" }
        return "Ready"
    }

    private var summaryColor: Color {
        if check.running { return Gallery.dim }
        if check.failures > 0 { return Gallery.tally }
        if check.warnings > 0 { return Gallery.amber }
        return Gallery.next
    }
}

private struct CheckRow: View {
    let item: CheckItem

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            icon.frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.ocLabel).foregroundStyle(Gallery.ink)
                Text(item.detail).font(.ocMeta).foregroundStyle(Gallery.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Space.s)
        .background(item.status == .fail ? Gallery.tally.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    @ViewBuilder private var icon: some View {
        switch item.status {
        case .running: ProgressView().controlSize(.small)
        case .pass: Image(systemName: "checkmark.circle.fill").foregroundStyle(Gallery.next)
        case .warn: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Gallery.amber)
        case .fail: Image(systemName: "xmark.octagon.fill").foregroundStyle(Gallery.tally)
        case .info: Image(systemName: "info.circle").foregroundStyle(Gallery.faint)
        }
    }
}

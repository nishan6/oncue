import SwiftUI

/// OnCue's gallery palette. Red and green carry tally meaning only:
/// red = the selected shot's camera ("this shot"), green = the following shot's camera ("next").
/// Selection and focus use a cool steel tone so they are never confused with tally.
enum Gallery {
    static let canvas = Color(red: 0.067, green: 0.078, blue: 0.094)      // #111418 deep slate
    static let panel = Color(red: 0.094, green: 0.106, blue: 0.129)       // #181B21
    static let raised = Color(red: 0.125, green: 0.141, blue: 0.169)      // #20242B
    static let key = Color(red: 0.165, green: 0.184, blue: 0.220)         // #2A2F38 unlit switcher key
    static let hairline = Color.white.opacity(0.07)
    static let ink = Color(red: 0.914, green: 0.902, blue: 0.875)         // #E9E6DF warm white
    static let dim = Color(red: 0.541, green: 0.576, blue: 0.627)         // #8A93A0
    static let faint = Color(red: 0.36, green: 0.39, blue: 0.43)
    static let tally = Color(red: 0.910, green: 0.125, blue: 0.165)       // #E8202A program red
    static let next = Color(red: 0.122, green: 0.796, blue: 0.357)        // #1FCB5B preview green
    static let amber = Color(red: 1.0, green: 0.69, blue: 0.0)            // #FFB000 warnings
    static let steel = Color(red: 0.42, green: 0.60, blue: 0.82)          // selection / focus
    static let steelFill = Color(red: 0.42, green: 0.60, blue: 0.82).opacity(0.16)
}

extension Font {
    /// Big camera numerals: expanded, heavy, like the legend on a switcher key.
    static func cameraNumeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }
    /// Under-monitor-display labels: condensed and bold.
    static func umd(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold).width(.condensed)
    }
    /// Positions, durations and shot numbers.
    static func readout(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    /// Production and song titles.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.expanded)
    }
}

/// Tally state of a camera relative to the selected shot.
enum TallyState {
    case off, current, next
    var color: Color {
        switch self {
        case .off: return Gallery.hairline
        case .current: return Gallery.tally
        case .next: return Gallery.next
        }
    }
}

/// A camera drawn as a multiviewer tile: number, label strip underneath, tally border.
struct CameraTile: View {
    let number: Int?
    let name: String
    let operatorName: String
    var tally: TallyState = .off
    var size: CGFloat = 64
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Gallery.key
                if let number {
                    Text("\(number)")
                        .font(.cameraNumeral(size * (compact ? 0.42 : 0.40)))
                        .foregroundStyle(tally == .off ? Gallery.ink : Color.white)
                        .minimumScaleFactor(0.5)
                } else {
                    Image(systemName: "questionmark")
                        .font(.system(size: size * 0.28, weight: .bold))
                        .foregroundStyle(Gallery.amber)
                }
            }
            if !compact {
                Text(name.isEmpty ? " " : name)
                    .font(.umd(10))
                    .lineLimit(1)
                    .foregroundStyle(Gallery.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.55))
            }
        }
        .frame(width: size, height: compact ? size * 0.72 : size)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(tally.color, lineWidth: tally == .off ? 1 : 2.5)
        )
        .shadow(color: tally == .off ? .clear : tally.color.opacity(0.45), radius: 6)
        .help(operatorName.isEmpty ? name : "\(name), operated by \(operatorName)")
    }
}

/// Compact labelled value used in the item header ("BPM 128").
struct ReadoutField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.umd(10))
                .foregroundStyle(Gallery.dim)
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Text field styled for the gallery: no bezel, subtle fill on focus.
struct GalleryTextField: View {
    let placeholder: String
    @Binding var text: String
    var font: Font = .system(size: 13)
    var color: Color = Gallery.ink
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(color)
            .focused($focused)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(focused ? Gallery.steelFill : Color.clear, in: RoundedRectangle(cornerRadius: 3))
    }
}

/// Text field that edits a value through parse/format (positions, numbers), committing on Return
/// or when focus leaves, and reverting invalid input.
struct CommitField: View {
    let placeholder: String
    let value: String
    var font: Font = .readout()
    var width: CGFloat? = nil
    var alignment: TextAlignment = .leading
    let commit: (String) -> Bool

    @State private var draft = ""
    @State private var invalid = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $draft)
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .foregroundStyle(invalid ? Gallery.amber : Gallery.ink)
            .focused($focused)
            .frame(width: width)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(focused ? Gallery.steelFill : Color.clear, in: RoundedRectangle(cornerRadius: 3))
            .onAppear { draft = value }
            .onChange(of: value) { _, new in if !focused { draft = new } }
            .onChange(of: focused) { _, isFocused in if !isFocused { apply() } }
            .onSubmit { apply() }
    }

    private func apply() {
        if draft == value { invalid = false; return }
        if commit(draft) {
            invalid = false
        } else {
            invalid = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                invalid = false
                draft = value
            }
        }
    }
}

/// Small pill used for CUT / MIX and item kinds.
struct Pill: View {
    let text: String
    var color: Color = Gallery.dim
    var filled = false

    var body: some View {
        Text(text)
            .font(.umd(10))
            .foregroundStyle(filled ? Color.black : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(filled ? color : Color.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(filled ? 0 : 0.6), lineWidth: 1))
    }
}

/// Panel heading: a short label and optional trailing controls.
struct PanelHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.umd(12))
                .foregroundStyle(Gallery.dim)
            Spacer()
            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// Borderless icon button with a tooltip and optional keyboard shortcut in the help text.
struct IconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Gallery.ink)
                .frame(width: 24, height: 22)
                .background(Gallery.key, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

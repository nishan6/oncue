import SwiftUI

import AppKit
import OnCueCore

/// OnCue's palette: layered graphite, so the camera colours read clearly, like a timeline in a
/// broadcast control or edit suite. Each camera has its own colour. Red and green carry tally
/// meaning only (red = the selected shot's camera, green = the next shot's camera), and a
/// restrained blue ring marks the selection.
enum Gallery {
    static let well = Color(hex: "#161719")      // track lanes, behind the blocks
    static let canvas = Color(hex: "#1D1E22")    // editor background
    static let panel = Color(hex: "#25262B")     // header, sidebars, track headers
    static let raised = Color(hex: "#2F3036")    // fields, section blocks
    static let key = Color(hex: "#3A3B42")       // buttons
    static let hairline = Color.white.opacity(0.08)
    static let ink = Color(hex: "#ECECEE")
    static let dim = Color(hex: "#9C9EA7")
    static let faint = Color(hex: "#676973")
    static let tally = Color(hex: "#E8202A")     // program red
    static let next = Color(hex: "#2ED15F")      // preview green
    static let amber = Color(hex: "#FFB000")     // warnings
    static let selection = Color(hex: "#5B9BFF") // selection ring and focus
    static let steel = selection
    static let steelFill = Color(hex: "#5B9BFF").opacity(0.16)
    static let lyric = Color(hex: "#B9AEE6")
    static let note = Color(hex: "#E6CF8F")
    static let fx = Color(hex: "#8CCFE0")
}

extension Color {
    /// "#RRGGBB" (falls back to grey for anything else).
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        let value = UInt32(digits, radix: 16) ?? 0x808080
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }

    /// Readable text colour on top of a camera colour.
    static func ink(onHex hex: String) -> Color {
        let digits = hex.replacingOccurrences(of: "#", with: "")
        let v = UInt32(digits, radix: 16) ?? 0x808080
        let r = Double((v >> 16) & 0xFF) / 255, g = Double((v >> 8) & 0xFF) / 255, b = Double(v & 0xFF) / 255
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.55 ? Color(hex: "#141518") : Color.white
    }
}

extension Camera {
    var swiftUIColor: Color { Color(hex: resolvedColor) }
    var inkColor: Color { Color.ink(onHex: resolvedColor) }
}

extension Font {
    /// Big camera numerals: heavy, like the legend on a switcher key.
    static func cameraNumeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }
    /// Labels: condensed and semibold.
    static func umd(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold).width(.condensed)
    }
    /// Positions, durations and shot numbers.
    static func readout(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    /// Production and song titles.
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
}

/// Tally state of a camera relative to the selected shot.
enum TallyState {
    case off, current, next
    var color: Color {
        switch self {
        case .off: return Color.black.opacity(0.35)
        case .current: return Gallery.tally
        case .next: return Gallery.next
        }
    }
}

/// A camera as a switcher key: its colour, its number, a name strip and a tally border.
struct CameraTile: View {
    let camera: Camera?
    var missing = false
    var tally: TallyState = .off
    var size: CGFloat = 64
    var compact = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let camera {
                    camera.swiftUIColor
                    Text("\(camera.number)")
                        .font(.cameraNumeral(size * (compact ? 0.40 : 0.38)))
                        .foregroundStyle(camera.inkColor)
                        .minimumScaleFactor(0.5)
                } else {
                    Gallery.key
                    Image(systemName: "questionmark")
                        .font(.system(size: size * 0.26, weight: .bold))
                        .foregroundStyle(Gallery.amber)
                }
            }
            if !compact {
                Text(camera?.displayName ?? (missing ? "Deleted" : "No camera"))
                    .font(.umd(10))
                    .lineLimit(1)
                    .foregroundStyle(Gallery.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.45))
            }
        }
        .frame(width: size, height: compact ? size * 0.72 : size)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(tally.color, lineWidth: tally == .off ? 1 : 3)
        )
        .shadow(color: tally == .off ? .clear : tally.color.opacity(0.5), radius: 6)
        .help(help)
    }

    private var help: String {
        guard let camera else { return missing ? "This camera was deleted" : "No camera chosen" }
        return camera.operatorName.isEmpty ? camera.displayName : "\(camera.displayName), operated by \(camera.operatorName)"
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
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: 6))
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
                .background(Gallery.key, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

import SwiftUI
import AppKit
import OnCueCore

// OnCue design system.
//
// Surfaces are layered charcoal: the window base is darkest, panels sit one step up, controls one
// more. Separation comes from tone and hairlines, not boxes. Colour is reserved for meaning:
// each camera keeps its identity colour; red and green mean program and preview tally (always
// with a label, never colour alone); one restrained blue marks selection and focus.

// MARK: - Tokens

enum Gallery {
    // Surfaces, darkest to lightest.
    static let well = Color(hex: "#0F1012")       // timeline lanes
    static let base = Color(hex: "#141518")       // window base, editor canvas
    static let canvas = base
    static let panel = Color(hex: "#1A1B1F")      // sidebar, inspector, headers
    static let raised = Color(hex: "#212228")     // controls, fields
    static let key = Color(hex: "#2A2C33")        // buttons, pressed fields
    static let hover = Color.white.opacity(0.05)
    static let pressed = Color.white.opacity(0.09)
    static let hairline = Color.white.opacity(0.06)
    static let divider = Color.white.opacity(0.10)

    // Text.
    static let ink = Color(hex: "#F1F1F3")
    static let dim = Color(hex: "#B0B3BC")
    static let faint = Color(hex: "#80838E")

    // Meaning.
    static let tally = Color(hex: "#F0313A")      // program
    static let next = Color(hex: "#2BD167")       // preview
    static let amber = Color(hex: "#FFB020")      // warnings
    static let selection = Color(hex: "#5E9BFF")  // selection, focus
    static let steel = selection
    static let steelFill = Color(hex: "#5E9BFF").opacity(0.16)

    // Track identities.
    static let lyric = Color(hex: "#B5A9EE")
    static let note = Color(hex: "#E9CF8A")
    static let fx = Color(hex: "#7FD0E4")
}

/// Spacing scale (points).
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
}

/// Section label inside panels: small, medium weight, slightly tracked. Never uppercase.
extension Text {
    func sectionLabel() -> some View {
        self.font(.system(size: 11, weight: .semibold)).tracking(0.2).foregroundStyle(Gallery.faint)
    }
}

/// Corner radii: small for blocks and fields, medium for text areas, large for sheets.
enum Radius {
    static let s: CGFloat = 4
    static let m: CGFloat = 6
    static let l: CGFloat = 10
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
        return luminance > 0.55 ? Color(hex: "#121316") : Color.white
    }
}

extension Camera {
    var swiftUIColor: Color { Color(hex: resolvedColor) }
    var inkColor: Color { Color.ink(onHex: resolvedColor) }
}

// MARK: - Type scale

extension Font {
    /// Window-level titles (Live Mode, empty states).
    static let ocDisplay = Font.system(size: 26, weight: .semibold)
    /// Song and segment titles.
    static let ocTitle = Font.system(size: 20, weight: .semibold)
    /// Panel and inspector headings.
    static let ocHeading = Font.system(size: 13.5, weight: .semibold)
    /// Primary content: shot descriptions, item names.
    static let ocBody = Font.system(size: 13, weight: .regular)
    static let ocBodyStrong = Font.system(size: 13, weight: .medium)
    /// Metadata and secondary labels.
    static let ocMeta = Font.system(size: 11.5, weight: .regular)
    static let ocLabel = Font.system(size: 11.5, weight: .medium)
    /// Small tags (CUT, MIX, PGM).
    static let ocTag = Font.system(size: 9.5, weight: .heavy)

    /// Camera numerals: heavy and wide, OnCue's signature.
    static func cameraNumeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }
    /// Positions, durations, counts: tabular figures.
    static func readout(_ size: CGFloat = 12, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    /// Condensed labels where width is tight (camera names on keys and blocks).
    static func umd(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold).width(.condensed)
    }
    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}

// MARK: - Interaction states

/// Hover and press feedback for borderless controls.
struct InteractiveBackground: ViewModifier {
    var radius: CGFloat = Radius.s
    var active = false
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(active ? Gallery.pressed : (hovering ? Gallery.hover : Color.clear),
                        in: RoundedRectangle(cornerRadius: radius))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

extension View {
    func interactive(radius: CGFloat = Radius.s, active: Bool = false) -> some View {
        modifier(InteractiveBackground(radius: radius, active: active))
    }
}

/// Button style with hover and pressed states: quiet by default, blue when prominent.
struct QuietButtonStyle: ButtonStyle {
    var prominent = false
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration, prominent: prominent, destructive: destructive)
    }

    private struct QuietButton: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        let destructive: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(.ocLabel)
                .foregroundStyle(destructive ? Gallery.tally : (prominent ? Color.white : Gallery.ink))
                .padding(.horizontal, Space.s + 2)
                .frame(minHeight: 24)
                .background(background, in: RoundedRectangle(cornerRadius: Radius.s))
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.1), value: hovering)
        }

        private var background: Color {
            if prominent { return Gallery.selection.opacity(configuration.isPressed ? 0.7 : (hovering ? 0.95 : 0.85)) }
            if configuration.isPressed { return Gallery.pressed }
            return hovering ? Gallery.key : Gallery.raised
        }
    }
}

// MARK: - Tally

/// Tally relative to the selected shot (Edit) or the running position (Live).
enum TallyState {
    case off, current, next

    var color: Color {
        switch self {
        case .off: return Color.clear
        case .current: return Gallery.tally
        case .next: return Gallery.next
        }
    }

    /// Text that carries the meaning without colour.
    func label(live: Bool) -> String? {
        switch self {
        case .off: return nil
        case .current: return live ? "PGM" : "SHOT"
        case .next: return live ? "PVW" : "NEXT"
        }
    }
}

/// Small tally tag: filled for program, outlined for preview, so the two also differ in shape.
struct TallyTag: View {
    let state: TallyState
    var live = false

    var body: some View {
        if let text = state.label(live: live) {
            Text(text)
                .font(.ocTag)
                .tracking(0.4)
                .foregroundStyle(state == .current ? Color.white : Gallery.next)
                .padding(.horizontal, 4)
                .frame(height: 14)
                .background(state == .current ? Gallery.tally : Color.clear, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(state == .next ? Gallery.next : Color.clear, lineWidth: 1.2))
        }
    }
}

// MARK: - Camera chips

/// A camera's identity: its colour with its number. Used in lists, inspectors and popovers.
struct CameraChip: View {
    let camera: Camera?
    var missing = false
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.s)
                .fill(camera?.swiftUIColor ?? Gallery.key)
            if let camera {
                Text("\(camera.number)")
                    .font(.cameraNumeral(size * 0.46))
                    .foregroundStyle(camera.inkColor)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 2)
            } else {
                Image(systemName: missing ? "exclamationmark" : "questionmark")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(Gallery.amber)
            }
        }
        .frame(width: size * 1.15, height: size)
        .help(camera.map { $0.operatorName.isEmpty ? $0.displayName : "\($0.displayName), operated by \($0.operatorName)" }
              ?? (missing ? "This camera was deleted" : "No camera chosen"))
    }
}

/// A camera chip with a tally ring.
struct CameraTile: View {
    let camera: Camera?
    var missing = false
    var tally: TallyState = .off
    var size: CGFloat = 64
    var compact = false

    var body: some View {
        CameraChip(camera: camera, missing: missing, size: compact ? size * 0.72 : size)
            .overlay(RoundedRectangle(cornerRadius: Radius.s + 2)
                .inset(by: -3)
                .stroke(tally.color, lineWidth: tally == .off ? 0 : 2))
    }
}

// MARK: - Fields

/// Text field that edits a value through parse/format (positions, numbers), committing on Return
/// or when focus leaves, and reverting invalid input. Borderless until hovered or focused.
struct CommitField: View {
    let placeholder: String
    let value: String
    var font: Font = .readout()
    var width: CGFloat? = nil
    var alignment: TextAlignment = .leading
    let commit: (String) -> Bool

    @State private var draft = ""
    @State private var invalid = false
    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $draft)
            .textFieldStyle(.plain)
            .font(font)
            .multilineTextAlignment(alignment)
            .foregroundStyle(invalid ? Gallery.amber : Gallery.ink)
            .focused($focused)
            .frame(width: width)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(focused ? Gallery.raised : (hovering ? Gallery.hover : Color.clear),
                        in: RoundedRectangle(cornerRadius: Radius.s))
            .overlay(RoundedRectangle(cornerRadius: Radius.s)
                .strokeBorder(focused ? Gallery.selection.opacity(0.8) : Color.clear, lineWidth: 1))
            .onHover { hovering = $0 }
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

/// Multi-line text that commits when editing ends (one undo step per edit, not per keystroke).
struct CommitTextArea: View {
    let placeholder: String
    let value: String
    var minLines = 2
    let commit: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $draft, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.ocBody)
            .foregroundStyle(Gallery.ink)
            .lineLimit(minLines...8)
            .focused($focused)
            .padding(Space.s)
            .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m)
                .strokeBorder(focused ? Gallery.selection.opacity(0.8) : Gallery.hairline, lineWidth: 1))
            .onAppear { draft = value }
            .onChange(of: value) { _, new in if !focused { draft = new } }
            .onChange(of: focused) { _, f in if !f && draft != value { commit(draft) } }
    }
}

/// Inline metadata item in a header: a small label above an editable or read-only value.
struct MetaItem<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.ocMeta)
                .foregroundStyle(Gallery.faint)
                .padding(.leading, 5)
            content
        }
    }
}

/// Inspector row: label on the left, control on the right.
struct PropertyRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: Space.s) {
            Text(label)
                .font(.ocMeta)
                .foregroundStyle(Gallery.dim)
                .frame(width: 72, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 24)
    }
}

/// Inspector group: an optional heading and its content, with a hairline after it.
struct InspectorGroup<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let title {
                Text(title).sectionLabel()
            }
            content
        }
        .padding(.horizontal, Space.l)
        .padding(.top, Space.m)
        .padding(.bottom, Space.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Small components

/// Small text tag: CUT / MIX, Song / Segment.
struct Pill: View {
    let text: String
    var color: Color = Gallery.dim
    var filled = false

    var body: some View {
        Text(text)
            .font(.ocTag)
            .tracking(0.3)
            .foregroundStyle(filled ? Color.white : color)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(filled ? color.opacity(0.85) : color.opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
    }
}

/// Panel heading: a short label and optional trailing controls.
struct PanelHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title).sectionLabel()
            Spacer()
            trailing
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

/// Borderless icon button with hover and press states.
struct IconButton: View {
    let symbol: String
    let help: String
    var active = false
    var size: CGFloat = 24
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Gallery.selection : Gallery.dim)
                .frame(width: size, height: size - 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(IconPressStyle(active: active))
        .help(help)
    }
}

private struct IconPressStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .interactive(active: configuration.isPressed || active)
    }
}

/// A run of metadata separated by dots, e.g. "Song · 128 BPM · 2:38".
struct MetaLine: View {
    let parts: [String]
    var font: Font = .ocMeta
    var color: Color = Gallery.dim

    var body: some View {
        Text(parts.filter { !$0.isEmpty }.joined(separator: "  ·  "))
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// m:ss (or h:mm:ss) for durations.
func clockText(_ seconds: Double) -> String {
    let v = Int(max(seconds, 0).rounded())
    return v >= 3600 ? String(format: "%d:%02d:%02d", v / 3600, (v % 3600) / 60, v % 60) : String(format: "%d:%02d", v / 60, v % 60)
}

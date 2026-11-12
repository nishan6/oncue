import SwiftUI
import OnCueCore

/// The common frame rates, or a rate typed in (e.g. 12.5 or 119.88).
struct FrameRatePicker: View {
    @Binding var rate: FrameRate
    @State private var custom = false
    @State private var typed = ""

    private static let customTag = "custom"

    var body: some View {
        HStack(spacing: Space.s) {
            Picker("Frame rate", selection: Binding(
                get: { custom ? Self.customTag : rate.key },
                set: { key in
                    if key == Self.customTag {
                        custom = true
                        typed = rate.label.replacingOccurrences(of: " DF", with: "")
                    } else if let r = FrameRate(key: key) {
                        custom = false
                        rate = r
                    }
                })) {
                ForEach(FrameRate.presets) { r in Text(r.label).tag(r.key) }
                if !FrameRate.presets.contains(rate) { Text(rate.label).tag(rate.key) }
                Divider()
                Text("Custom…").tag(Self.customTag)
            }
            .labelsHidden()
            .frame(width: 130)
            if custom {
                TextField("fps", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .onSubmit(applyTyped)
                    .onChange(of: typed) { _, _ in applyTyped() }
                Text(FrameRate.custom(Double(typed) ?? 0) == nil ? "1–1000 fps" : "fps")
                    .font(.ocMeta)
                    .foregroundStyle(FrameRate.custom(Double(typed) ?? 0) == nil ? Gallery.amber : Gallery.faint)
            }
        }
    }

    private func applyTyped() {
        if let r = FrameRate.custom(Double(typed.replacingOccurrences(of: ",", with: ".")) ?? 0) { rate = r }
    }
}

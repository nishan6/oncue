import SwiftUI
import AppKit

/// Help › Keyboard Shortcuts (⌘/): every key OnCue answers to, in one place. Turn on System
/// Settings › Keyboard › Keyboard navigation to move between buttons and fields with Tab.
struct KeyboardShortcutsView: View {
    struct ShortcutGroup: Identifiable {
        let title: String
        let keys: [(String, String)]
        var id: String { title }
    }

    static let groups: [ShortcutGroup] = [
        ShortcutGroup(title: "Live Mode", keys: [
            ("Space  or  →", "NEXT shot"), ("←", "Previous shot"), ("Return", "GO / stop the song"),
            ("1 – 99", "Camera to preview (type two digits quickly for 10 and up)"),
            ("C", "Cut preview to program"), ("A", "Auto (mix) preview to program"),
            ("T", "Tap the next section"), ("B", "Tap the beat"), ("L", "Loop this section on or off"),
            ("F", "Free mode on or off"), ("R", "Resume automation"), ("Esc", "Panic: every output to Display"),
            ("⌘[  ⌘]", "Previous or next song"), ("⇧⌘F", "Answer the failover prompt"), ("⌘L", "Leave Live Mode"),
        ]),
        ShortcutGroup(title: "Script", keys: [
            ("Return  or  ⌘Return", "New shot after the selected one"), ("1 – 99", "Camera for the selected shot"),
            ("a – z", "Shot bar: type \"cu push 2s lead vocal\" for the selected shots, Return applies"),
            ("⌥-drag", "Copy a shot or selection"), ("Drag on empty timeline", "Select every shot in that range"),
            ("Pinch  or  ⌘-scroll", "Zoom the timeline at the pointer"),
            ("←  →", "Select the previous or next shot (timeline)"), ("↑  ↓", "Select shots (list)"),
            ("⌥⌘↑  ⌥⌘↓", "Move the shot up or down"), ("⌘D", "Duplicate shot"), ("⌥⌘T", "Switch cut or transition"),
            ("⌘⌫  or  Delete", "Delete the selection"), ("⌥⌘N", "New song"), ("⌥⇧⌘N", "New segment"), ("⌥⌘E", "New section"),
            ("⌘[  ⌘]", "Previous or next song"), ("⌥Space", "Play or pause the song's media"),
        ]),
        ShortcutGroup(title: "Views", keys: [
            ("⌘1  ⌘2  ⌘3", "Timeline, Timeline and List, List"), ("⌘=  ⌘-  ⌘0", "Zoom in, out, actual size"),
            ("⌥⌘I", "Show or hide the inspector"), ("⇧⌘L", "Project Library"),
        ]),
        ShortcutGroup(title: "Windows and tools", keys: [
            ("⌘K", "Go to any song, shot (\"cam 3\", \"#12\") or tool"), ("⌘L", "Enter Live Mode"), ("⌥⌘K", "Pre-show check"), ("⌥⌘D", "Device status"), ("⌥⌘S", "Show setup"),
            ("⌥⌘C", "Cameras"), ("⌥⌘R", "Trigger routes"), ("⌥⌘P", "Camera plot"), ("⇧⌘E", "Export"),
            ("⌥⌘,", "Project properties"), ("⌘,", "Settings (this Mac)"), ("⌘/", "This list"),
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("Turn on System Settings › Keyboard › Keyboard navigation to move between every button and field with Tab and press them with Space.")
                    .font(.ocMeta).foregroundStyle(Gallery.dim).fixedSize(horizontal: false, vertical: true)
                ForEach(Self.groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.title.uppercased()).font(.ocTag).tracking(0.6).foregroundStyle(Gallery.faint)
                        ForEach(Array(group.keys.enumerated()), id: \.offset) { _, pair in
                            HStack(alignment: .firstTextBaseline) {
                                Text(pair.0).font(.readout(13, weight: .semibold)).foregroundStyle(Gallery.ink)
                                    .frame(width: 170, alignment: .leading)
                                Text(pair.1).font(.ocBody).foregroundStyle(Gallery.dim)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .padding(Space.l)
        }
        .frame(width: 560, height: 640)
        .background(Gallery.panel)
        .preferredColorScheme(.dark)
    }

    private static var window: NSWindow?

    static func show() {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 640), styleMask: [.titled, .closable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Keyboard Shortcuts"
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: KeyboardShortcutsView())
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
    }
}

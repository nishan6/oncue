import SwiftUI
import OnCueCore

// Multi View and Full Page monitors (Show Setup › Monitors). Built from the same crew snapshot as
// the browser viewer, so a Mac display and an iPad show the same thing. View only.

/// One column per camera: tally, the shot it has on air, its next shots and the countdown.
struct MultiViewMonitor: View {
    let show: Show
    let snap: CrewSnapshot
    let upcoming: Int
    let cameras: [Int]?

    var body: some View {
        let columns = snap.multiViewColumns(upcoming: upcoming, cameras: cameras)
        GeometryReader { geo in
            let available = geo.size.width - Space.l * 2
            let count = CGFloat(max(columns.count, 1))
            let width = max(220, (available - Space.s * (count - 1)) / count)
            ScrollView(.horizontal, showsIndicators: width * count > available) {
                HStack(alignment: .top, spacing: Space.s) {
                    ForEach(columns, id: \.camera.number) { column in
                        MultiViewColumnView(column: column, color: show.camera(number: column.camera.number)?.swiftUIColor ?? Gallery.faint)
                            .frame(width: width, height: geo.size.height - Space.l * 2)
                    }
                }
                .padding(Space.l)
            }
        }
    }
}

private struct MultiViewColumnView: View {
    let column: MultiViewColumn
    let color: Color

    var body: some View {
        let t = column.tally
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                Text("\(column.camera.number)").font(Font.cameraNumeral(44)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 0) {
                    Text(column.camera.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Gallery.ink).lineLimit(1)
                    if !column.camera.operatorName.isEmpty {
                        Text(column.camera.operatorName).font(.system(size: 13)).foregroundStyle(Gallery.dim).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(t == .program ? "ON AIR" : (t == .preview ? "STAND BY" : "CLEAR"))
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(t == .program ? Gallery.tally : (t == .preview ? Gallery.next : Gallery.faint))
            if let now = column.current {
                ViewerShotCard(shot: now, label: "ON AIR", accent: Gallery.tally)
            }
            if column.upcoming.isEmpty {
                Text("No more shots in this song").font(.system(size: 14)).foregroundStyle(Gallery.faint).padding(.top, Space.s)
            }
            ForEach(Array(column.upcoming.enumerated()), id: \.element.id) { k, shot in
                ViewerShotCard(shot: shot, label: k == 0 ? "NEXT" : nil, accent: k == 0 ? Gallery.next : nil)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(t == .program ? Gallery.tally.opacity(0.12) : LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.l))
        .overlay(RoundedRectangle(cornerRadius: Radius.l)
            .strokeBorder(t == .program ? Gallery.tally : (t == .preview ? Gallery.next : Color.clear), lineWidth: 5))
    }
}

/// A shot with its details, note and countdown.
private struct ViewerShotCard: View {
    let shot: CrewShot
    var label: String?
    var accent: Color?
    var large = false

    var body: some View {
        let scale: CGFloat = large ? 1.35 : 1
        HStack(alignment: .top, spacing: Space.s) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let label {
                        Text(label).font(.system(size: 11 * scale, weight: .heavy)).foregroundStyle(accent ?? Gallery.faint)
                    }
                    Text("#\(shot.number) · \(shot.position)").font(.readout(11 * scale)).foregroundStyle(Gallery.faint)
                    if shot.transition == "mix" { Text("MIX").font(.system(size: 11 * scale, weight: .bold)).foregroundStyle(Gallery.dim) }
                }
                if !shot.text.isEmpty {
                    Text(shot.text).font(.system(size: 16 * scale, weight: .semibold)).foregroundStyle(Gallery.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !shot.details.isEmpty {
                    Text(shot.details).font(.system(size: 13 * scale, weight: .medium)).foregroundStyle(Gallery.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !shot.note.isEmpty {
                    Text(shot.note).font(.system(size: 13 * scale)).foregroundStyle(Gallery.amber)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let s = shot.secondsUntil {
                Text(clockText(s)).font(.readout(20 * scale, weight: .bold))
                    .foregroundStyle(s < 5 ? Gallery.amber : Gallery.ink)
            }
        }
        .padding(Space.s)
        .background(Gallery.raised, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).strokeBorder(accent ?? .clear, lineWidth: 2))
    }
}

/// One camera's shots, large, or the whole script from the shot on air onwards.
struct FullPageMonitor: View {
    let show: Show
    let snap: CrewSnapshot
    /// Camera number, or 0 for the whole script.
    let camera: Int

    var body: some View {
        let page = snap.fullPage(camera: camera)
        let cam = camera > 0 ? show.camera(number: camera) : nil
        VStack(alignment: .leading, spacing: Space.m) {
            if camera > 0 {
                let t = snap.tally(camera: camera)
                HStack(spacing: Space.l) {
                    Text("\(camera)").font(Font.cameraNumeral(96)).foregroundStyle(cam?.swiftUIColor ?? Gallery.faint)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t == .program ? "ON AIR" : (t == .preview ? "STAND BY" : "CLEAR"))
                            .font(.system(size: 40, weight: .heavy))
                            .foregroundStyle(t == .program ? Gallery.tally : (t == .preview ? Gallery.next : Gallery.faint))
                        Text((cam?.displayName ?? "Camera \(camera) is not in this show") + ((cam?.operatorName ?? "").isEmpty ? "" : " · \(cam!.operatorName)"))
                            .font(.system(size: 20, weight: .medium)).foregroundStyle(Gallery.dim)
                    }
                    Spacer()
                    if let next = page.upcoming.first, let s = next.secondsUntil {
                        Text(clockText(s)).font(.readout(72, weight: .bold)).foregroundStyle(s < 5 ? Gallery.amber : Gallery.ink)
                    }
                }
                .padding(Space.l)
                .background(t == .program ? Gallery.tally.opacity(0.14) : LivePalette.panel, in: RoundedRectangle(cornerRadius: Radius.l))
                .overlay(RoundedRectangle(cornerRadius: Radius.l)
                    .strokeBorder(t == .program ? Gallery.tally : (t == .preview ? Gallery.next : Color.clear), lineWidth: 6))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s) {
                    if let now = page.now, camera == 0 || now.camera == camera {
                        row(now, label: "ON AIR", accent: Gallery.tally)
                    }
                    if page.upcoming.isEmpty {
                        Text(camera > 0 ? "No more shots for camera \(camera) in this song" : "Nothing more in this song")
                            .font(.system(size: 20)).foregroundStyle(Gallery.faint).padding(.top, Space.m)
                    }
                    ForEach(Array(page.upcoming.prefix(60).enumerated()), id: \.element.id) { k, shot in
                        row(shot, label: k == 0 ? "NEXT" : nil, accent: k == 0 ? Gallery.next : nil)
                    }
                }
            }
        }
        .padding(Space.xl)
    }

    private func row(_ shot: CrewShot, label: String?, accent: Color?) -> some View {
        let c = shot.camera.flatMap { show.camera(number: $0) }
        return HStack(alignment: .top, spacing: Space.m) {
            if camera == 0 {
                Text(shot.camera.map(String.init) ?? "–").font(Font.cameraNumeral(36))
                    .foregroundStyle(c?.swiftUIColor ?? Gallery.faint).frame(width: 64)
            }
            ViewerShotCard(shot: shot, label: label, accent: accent, large: true)
        }
    }
}

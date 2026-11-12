import Foundation
import CoreGraphics
import CoreText

// Printable PDFs: the camera script (one song or segment per page run, every shot with camera,
// description, operator note, transition and length) and call sheets (one per camera, every shot
// that camera has in the show, with the cameras before and after it).

public enum PaperSize: String, CaseIterable, Identifiable, Codable {
    case a4, letter
    public var id: String { rawValue }
    public var label: String { self == .a4 ? "A4" : "US Letter" }
    public var size: CGSize { self == .a4 ? CGSize(width: 595.28, height: 841.89) : CGSize(width: 612, height: 792) }
    /// US Letter where the system measures in US units, A4 elsewhere.
    public static var localDefault: PaperSize { Locale.current.measurementSystem == .us ? .letter : .a4 }
}

/// A tiny top-down page layout writer over a PDF context.
final class PDFPageWriter {
    let data = NSMutableData()
    private let context: CGContext
    let page: CGRect
    let margin: CGFloat = 40
    private(set) var y: CGFloat = 0
    private(set) var pageNumber = 0
    private var open = false
    var footer: String = ""
    /// Drawn at the top of each page after the first of a run (e.g. the column headings).
    var continuation: (() -> Void)?

    init(paper: PaperSize, title: String) {
        page = CGRect(origin: .zero, size: paper.size)
        var box = page
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        let info: [CFString: Any] = [kCGPDFContextTitle: title, kCGPDFContextCreator: "OnCue"]
        context = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary)!
    }

    var contentWidth: CGFloat { page.width - margin * 2 }
    var bottom: CGFloat { page.height - margin - 18 }
    var remaining: CGFloat { bottom - y }

    func newPage() {
        if open { finishPage() }
        context.beginPDFPage(nil)
        open = true
        pageNumber += 1
        y = margin
    }

    /// Starts a new page when `height` doesn't fit, then repeats the column headings.
    func ensure(_ height: CGFloat) {
        if !open { newPage(); return }
        if y + height > bottom {
            newPage()
            continuation?()
        }
    }

    func advance(_ dy: CGFloat) { y += dy }

    private func finishPage() {
        if !footer.isEmpty {
            let s = PDFText.string(footer, size: 8, color: PDFText.grey)
            draw(s, x: margin, top: page.height - margin + 4, width: contentWidth - 60)
        }
        let n = PDFText.string("\(pageNumber)", size: 8, color: PDFText.grey, align: .right)
        draw(n, x: page.width - margin - 60, top: page.height - margin + 4, width: 60)
        context.endPDFPage()
        open = false
    }

    func finish() -> Data {
        if open { finishPage() }
        context.closePDF()
        return data as Data
    }

    // MARK: Drawing (top-down coordinates)

    func measure(_ s: NSAttributedString, width: CGFloat) -> CGFloat {
        let setter = CTFramesetterCreateWithAttributedString(s)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil,
                                                                CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        return ceil(size.height)
    }

    @discardableResult
    func draw(_ s: NSAttributedString, x: CGFloat, top: CGFloat, width: CGFloat) -> CGFloat {
        let h = measure(s, width: width)
        let setter = CTFramesetterCreateWithAttributedString(s)
        let rect = CGRect(x: x, y: page.height - top - h, width: width, height: h + 1)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()
        return h
    }

    func fill(_ rect: CGRect, color: CGColor, radius: CGFloat = 0) {
        let flipped = CGRect(x: rect.minX, y: page.height - rect.maxY, width: rect.width, height: rect.height)
        context.setFillColor(color)
        context.addPath(CGPath(roundedRect: flipped, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }

    func line(fromX x1: CGFloat, toX x2: CGFloat, at top: CGFloat, color: CGColor = PDFText.rule, width: CGFloat = 0.5) {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.move(to: CGPoint(x: x1, y: page.height - top))
        context.addLine(to: CGPoint(x: x2, y: page.height - top))
        context.strokePath()
    }
}

enum PDFText {
    static let ink = CGColor(srgbRed: 0.08, green: 0.08, blue: 0.1, alpha: 1)
    static let grey = CGColor(srgbRed: 0.42, green: 0.43, blue: 0.47, alpha: 1)
    static let rule = CGColor(srgbRed: 0.82, green: 0.83, blue: 0.86, alpha: 1)
    static let band = CGColor(srgbRed: 0.94, green: 0.945, blue: 0.955, alpha: 1)
    static let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

    static func font(_ size: CGFloat, bold: Bool = false, heavy: Bool = false) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(bold || heavy ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        // Tabular figures so numbers line up in columns.
        let features: [[CFString: Any]] = [[kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                                            kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector]]
        let desc = CTFontDescriptorCreateWithAttributes([kCTFontFeatureSettingsAttribute: features] as CFDictionary)
        var font = CTFontCreateCopyWithAttributes(base, size, nil, desc)
        if heavy, let h = CTFontCreateCopyWithSymbolicTraits(font, size, nil, .boldTrait, .boldTrait) { font = h }
        return font
    }

    static func string(_ text: String, size: CGFloat, bold: Bool = false, heavy: Bool = false, color: CGColor = ink,
                       align: CTTextAlignment = .left, lineSpacing: CGFloat = 1.5) -> NSAttributedString {
        let style: CTParagraphStyle = withUnsafePointer(to: align) { a in
            withUnsafePointer(to: lineSpacing) { sp in
                let settings = [
                    CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: a),
                    CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: sp),
                ]
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
        return NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font(size, bold: bold, heavy: heavy),
            kCTForegroundColorAttributeName as NSAttributedString.Key: color,
            kCTParagraphStyleAttributeName as NSAttributedString.Key: style,
        ])
    }

    /// Joins pieces (text, size, bold, colour) into one paragraph.
    static func compose(_ parts: [(String, CGFloat, Bool, CGColor)]) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for (k, p) in parts.enumerated() where !p.0.isEmpty {
            out.append(string((out.length > 0 && k > 0 ? "\n" : "") + p.0, size: p.1, bold: p.2, color: p.3))
        }
        return out
    }

    static func color(_ hex: String?) -> CGColor {
        guard let (r, g, b) = hex.flatMap(HexColor.rgb) else { return grey }
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// Dark or white text, whichever reads on the camera colour.
    static func onColor(_ hex: String?) -> CGColor {
        guard let (r, g, b) = hex.flatMap(HexColor.rgb) else { return white }
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? ink : white
    }
}

extension Show {

    // MARK: - Camera script

    /// The camera script for the given songs and segments (all when empty), in running order.
    public func cameraScriptPDF(itemIDs: [UUID] = [], paper: PaperSize = .localDefault, date: Date = Date()) -> Data {
        let w = PDFPageWriter(paper: paper, title: "\(name) – Camera script")
        w.footer = "\(name) · Camera script · \(date.formatted(date: .abbreviated, time: .shortened))"
        let chosen = itemIDs.isEmpty ? items : items.filter { itemIDs.contains($0.id) }

        // Columns: shot, position, camera, description + note, transition, length.
        let x0 = w.margin
        let cols: (shot: CGFloat, pos: CGFloat, cam: CGFloat, trans: CGFloat, len: CGFloat) = (30, 52, 118, 34, 44)
        let descX = x0 + cols.shot + cols.pos + cols.cam
        let descW = w.contentWidth - (cols.shot + cols.pos + cols.cam + cols.trans + cols.len)
        let transX = descX + descW
        let lenX = transX + cols.trans

        func headings() {
            let h: [(String, CGFloat, CGFloat, CTTextAlignment)] = [
                ("Shot", x0, cols.shot, .left), ("Position", x0 + cols.shot, cols.pos, .left),
                ("Camera", x0 + cols.shot + cols.pos, cols.cam, .left), ("Description and note", descX, descW, .left),
                ("Trans", transX, cols.trans, .left), ("Length", lenX, cols.len, .right)]
            for (t, x, width, a) in h { w.draw(PDFText.string(t, size: 7.5, bold: true, color: PDFText.grey, align: a), x: x, top: w.y, width: width) }
            w.advance(13)
            w.line(fromX: x0, toX: x0 + w.contentWidth, at: w.y, color: PDFText.ink, width: 0.8)
            w.advance(2)
        }

        if chosen.isEmpty {
            w.newPage()
            w.draw(PDFText.string("This show has no songs or segments yet.", size: 12, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth)
        }

        for item in chosen {
            w.newPage()
            w.continuation = nil
            let rows = shotRows(forItem: item.id)
            // Title block.
            w.advance(w.draw(PDFText.string(name, size: 9, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth) + 2)
            w.advance(w.draw(PDFText.string(item.title, size: 22, bold: true), x: x0, top: w.y, width: w.contentWidth) + 3)
            var meta = [item.kind.label]
            switch item.timeBase {
            case .bars: meta.append("\(Int(item.bpm)) BPM, \(item.beatsPerBar)/4")
            case .seconds: meta.append("Minutes and seconds")
            case .order: meta.append("Called on NEXT")
            }
            meta.append(rows.count == 1 ? "1 shot" : "\(rows.count) shots")
            if let len = runLength(forItem: item.id) { meta.append(String(format: "%d:%02d", Int(len) / 60, Int(len) % 60)) }
            let used = Set(rows.compactMap { $0.cue.cameraID }).count
            meta.append(used == 1 ? "1 camera" : "\(used) cameras")
            w.advance(w.draw(PDFText.string(meta.joined(separator: "   "), size: 9.5, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth) + 16)
            headings()
            w.continuation = {
                w.draw(PDFText.string("\(item.title) (continued)", size: 9, bold: true, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth)
                w.advance(16)
                headings()
            }

            if rows.isEmpty {
                w.advance(8)
                w.draw(PDFText.string("No shots scripted.", size: 10, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth)
                continue
            }

            var lastSection: UUID?? = .none
            for row in rows {
                if lastSection != .some(row.sectionID) {
                    lastSection = .some(row.sectionID)
                    if let section = item.sections.first(where: { $0.id == row.sectionID }) {
                        w.ensure(40)
                        w.advance(6)
                        let label = PDFText.string("\(section.name)   \(item.format(section.at))", size: 8.5, bold: true, color: PDFText.ink)
                        let h = w.measure(label, width: w.contentWidth - 12) + 8
                        w.fill(CGRect(x: x0, y: w.y, width: w.contentWidth, height: h), color: PDFText.band, radius: 2)
                        w.draw(label, x: x0 + 6, top: w.y + 4, width: w.contentWidth - 12)
                        w.advance(h + 2)
                    }
                }
                let cam = camera(row.cue.cameraID)
                let desc = PDFText.compose([
                    (row.cue.text.isEmpty ? (cam?.displayName ?? "No camera") : row.cue.text, 10, false, PDFText.ink),
                    (row.cue.note, 8.5, false, PDFText.grey),
                ])
                let camText = PDFText.compose([(cam?.displayName ?? "No camera", 9.5, true, PDFText.ink), (cam?.operatorName ?? "", 8, false, PDFText.grey)])
                let h = max(w.measure(desc, width: descW - 8), w.measure(camText, width: cols.cam - 30), 20) + 10
                w.ensure(h)
                let top = w.y + 5
                w.draw(PDFText.string("\(row.number)", size: 11, bold: true), x: x0, top: top, width: cols.shot)
                w.draw(PDFText.string(item.format(row.cue.at), size: 9.5, color: PDFText.grey), x: x0 + cols.shot, top: top + 1.5, width: cols.pos)
                let cx = x0 + cols.shot + cols.pos
                w.fill(CGRect(x: cx, y: top, width: 22, height: 18), color: PDFText.color(cam?.resolvedColor), radius: 3)
                w.draw(PDFText.string(cam.map { "\($0.number)" } ?? "–", size: 10.5, heavy: true, color: PDFText.onColor(cam?.resolvedColor), align: .center),
                       x: cx, top: top + 2.5, width: 22)
                w.draw(camText, x: cx + 28, top: top, width: cols.cam - 30)
                w.draw(desc, x: descX, top: top, width: descW - 8)
                w.draw(PDFText.string(row.cue.transition == .cut ? "Cut" : "Mix", size: 9, color: PDFText.grey), x: transX, top: top + 1.5, width: cols.trans)
                w.draw(PDFText.string(row.lengthSeconds.map { String(format: "%.1f s", $0) } ?? "", size: 9, color: PDFText.grey, align: .right),
                       x: lenX, top: top + 1.5, width: cols.len)
                w.advance(h)
                w.line(fromX: x0, toX: x0 + w.contentWidth, at: w.y)
            }
        }
        return w.finish()
    }

    // MARK: - Call sheets

    /// One call sheet per camera (all cameras when empty): every shot that camera has, by song.
    public func callSheetsPDF(cameraIDs: [UUID] = [], paper: PaperSize = .localDefault, date: Date = Date()) -> Data {
        let w = PDFPageWriter(paper: paper, title: "\(name) – Call sheets")
        let cams = cameraIDs.isEmpty ? sortedCameras : sortedCameras.filter { cameraIDs.contains($0.id) }
        let x0 = w.margin
        let cols: (shot: CGFloat, pos: CGFloat, section: CGFloat, around: CGFloat) = (30, 52, 84, 92)
        let descX = x0 + cols.shot + cols.pos + cols.section
        let descW = w.contentWidth - (cols.shot + cols.pos + cols.section + cols.around)
        let aroundX = descX + descW

        if cams.isEmpty {
            w.newPage()
            w.draw(PDFText.string("This show has no cameras yet.", size: 12, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth)
        }

        for cam in cams {
            w.continuation = nil
            w.newPage()
            w.footer = "\(name) · Call sheet · Camera \(cam.number) \(cam.displayName) · \(date.formatted(date: .abbreviated, time: .shortened))"
            // Header: the camera, large, in its colour.
            let badge: CGFloat = 64
            w.fill(CGRect(x: x0, y: w.y, width: badge, height: badge), color: PDFText.color(cam.resolvedColor), radius: 8)
            w.draw(PDFText.string("\(cam.number)", size: 38, heavy: true, color: PDFText.onColor(cam.resolvedColor), align: .center),
                   x: x0, top: w.y + 8, width: badge)
            let tx = x0 + badge + 16
            w.draw(PDFText.string(name, size: 9, color: PDFText.grey), x: tx, top: w.y + 2, width: w.contentWidth - badge - 16)
            w.draw(PDFText.string(cam.displayName, size: 22, bold: true), x: tx, top: w.y + 15, width: w.contentWidth - badge - 16)
            var all: [(RundownItem, ShotRow, Camera?, Camera?)] = []
            for item in items {
                let rows = shotRows(forItem: item.id)
                for (k, row) in rows.enumerated() where row.cue.cameraID == cam.id {
                    all.append((item, row, k > 0 ? camera(rows[k - 1].cue.cameraID) : nil,
                                k + 1 < rows.count ? camera(rows[k + 1].cue.cameraID) : nil))
                }
            }
            let songs = Set(all.map { $0.0.id }).count
            let sub = [cam.operatorName.isEmpty ? "" : "Operator: \(cam.operatorName)",
                       all.count == 1 ? "1 shot" : "\(all.count) shots",
                       songs == 1 ? "in 1 song or segment" : "in \(songs) songs and segments"].filter { !$0.isEmpty }
            w.draw(PDFText.string(sub.joined(separator: "   "), size: 9.5, color: PDFText.grey), x: tx, top: w.y + 44, width: w.contentWidth - badge - 16)
            w.advance(badge + 18)

            func headings() {
                let h: [(String, CGFloat, CGFloat)] = [("Shot", x0, cols.shot), ("Position", x0 + cols.shot, cols.pos),
                                                       ("Section", x0 + cols.shot + cols.pos, cols.section),
                                                       ("Description and note", descX, descW), ("Before / after", aroundX, cols.around)]
                for (t, x, width) in h { w.draw(PDFText.string(t, size: 7.5, bold: true, color: PDFText.grey), x: x, top: w.y, width: width) }
                w.advance(13)
                w.line(fromX: x0, toX: x0 + w.contentWidth, at: w.y, color: PDFText.ink, width: 0.8)
                w.advance(2)
            }

            if all.isEmpty {
                w.draw(PDFText.string("No shots for this camera in the script.", size: 11, color: PDFText.grey), x: x0, top: w.y, width: w.contentWidth)
                continue
            }
            headings()
            var currentItem: UUID?
            for (item, row, before, after) in all {
                if item.id != currentItem {
                    currentItem = item.id
                    w.continuation = {
                        w.draw(PDFText.string("Camera \(cam.number) \(cam.displayName) (continued)", size: 9, bold: true, color: PDFText.grey),
                               x: x0, top: w.y, width: w.contentWidth)
                        w.advance(16)
                        headings()
                    }
                    w.ensure(44)
                    w.advance(8)
                    let title = PDFText.string(item.title, size: 11, bold: true)
                    let h = w.measure(title, width: w.contentWidth - 12) + 8
                    w.fill(CGRect(x: x0, y: w.y, width: w.contentWidth, height: h), color: PDFText.band, radius: 2)
                    w.draw(title, x: x0 + 6, top: w.y + 4, width: w.contentWidth - 12)
                    w.advance(h + 2)
                }
                let desc = PDFText.compose([(row.cue.text.isEmpty ? "No description" : row.cue.text, 10, false, row.cue.text.isEmpty ? PDFText.grey : PDFText.ink),
                                            (row.cue.note, 9, true, PDFText.ink)])
                let around = PDFText.compose([("After " + (before.map { "\($0.number) \($0.displayName)" } ?? "start"), 8.5, false, PDFText.grey),
                                              ("Then " + (after.map { "\($0.number) \($0.displayName)" } ?? "end"), 8.5, false, PDFText.grey)])
                let section = PDFText.string(item.section(at: row.cue.at)?.name ?? "", size: 9, color: PDFText.grey)
                let h = max(w.measure(desc, width: descW - 8), w.measure(around, width: cols.around), w.measure(section, width: cols.section - 6), 16) + 10
                w.ensure(h)
                let top = w.y + 5
                w.draw(PDFText.string("\(row.number)", size: 11, bold: true), x: x0, top: top, width: cols.shot)
                w.draw(PDFText.string(item.format(row.cue.at), size: 9.5, color: PDFText.grey), x: x0 + cols.shot, top: top + 1.5, width: cols.pos)
                w.draw(section, x: x0 + cols.shot + cols.pos, top: top + 1.5, width: cols.section - 6)
                w.draw(desc, x: descX, top: top, width: descW - 8)
                w.draw(around, x: aroundX, top: top + 1, width: cols.around)
                w.advance(h)
                w.line(fromX: x0, toX: x0 + w.contentWidth, at: w.y)
            }
        }
        return w.finish()
    }
}

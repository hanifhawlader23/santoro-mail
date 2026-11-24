import SwiftUI
import CoreText
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Santoro look: El Messiri, cream / black / wine. Everything follows light & dark mode.
enum Brand {
    static let wine = Color(red: 91 / 255, green: 26 / 255, blue: 44 / 255)
    static let bg = Color.dyn((0.969, 0.961, 0.914), (0.039, 0.027, 0.031))
    static let card = Color.dyn((0.988, 0.984, 0.961), (0.078, 0.063, 0.071))
    static let line = Color.dyn((0.357, 0.102, 0.173, 0.13), (0.969, 0.961, 0.914, 0.10))
    static let fg = Color.dyn((0, 0, 0), (0.969, 0.961, 0.914))
    static let fg2 = Color.dyn((0, 0, 0, 0.62), (0.969, 0.961, 0.914, 0.70))
    static let fg3 = Color.dyn((0, 0, 0, 0.42), (0.969, 0.961, 0.914, 0.45))
    /// wine that stays readable in dark mode
    static let at = Color.dyn((0.357, 0.102, 0.173), (0.86, 0.62, 0.68))

    static func f(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        let name = w == .medium ? "ElMessiri-Medium" : (w == .semibold || w == .bold) ? "ElMessiri-SemiBold" : "ElMessiri-Regular"
        return .custom(name, size: size)
    }

    static func registerFonts() {
        for n in ["ElMessiri-Regular", "ElMessiri-Medium", "ElMessiri-SemiBold"] {
            if let u = Bundle.main.url(forResource: n, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
            }
        }
    }

    static let palette: [String] = ["#5B1A2C", "#24476B", "#A0522D", "#56602F", "#2F6A66", "#7A4B78", "#B2475E", "#8C6A43", "#6E6862"]
    static let defaultColor: [String: String] = ["santoro": "#5B1A2C", "contacto": "#24476B", "pedidos": "#A0522D", "club": "#56602F", "hola": "#7A4B78"]
}

extension Color {
    static func dyn(_ l: (Double, Double, Double), _ d: (Double, Double, Double)) -> Color { dyn((l.0, l.1, l.2, 1), (d.0, d.1, d.2, 1)) }
    static func dyn(_ l: (Double, Double, Double, Double), _ d: (Double, Double, Double, Double)) -> Color {
        #if os(iOS)
        return Color(UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: d.0, green: d.1, blue: d.2, alpha: d.3) : UIColor(red: l.0, green: l.1, blue: l.2, alpha: l.3) })
        #else
        return Color(NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: d.0, green: d.1, blue: d.2, alpha: d.3) : NSColor(red: l.0, green: l.1, blue: l.2, alpha: l.3) })
        #endif
    }
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces); if h.hasPrefix("#") { h.removeFirst() }
        let v = UInt64(h, radix: 16) ?? 0x5B1A2C
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// Cap-style label: small, spaced, uppercase
struct Cap: View {
    let text: String
    var color: Color = Brand.fg3
    init(_ t: String, color: Color = Brand.fg3) { text = t; self.color = color }
    var body: some View { Text(text.uppercased()).font(Brand.f(10.5)).tracking(2.4).foregroundStyle(color) }
}

/// Rounded-square initials avatar
struct Initials: View {
    let name: String
    var color: Color = Brand.wine
    var size: CGFloat = 38
    var ring: Bool = false
    var email: String? = nil          // logo de la empresa / Gravatar, como Gmail
    var body: some View {
        ZStack {
            Text(initials(name)).font(Brand.f(size * 0.36, .medium)).tracking(0.5)
                .foregroundStyle(Brand.at)
            if let e = email, let u = URL(string: BASE + "/logo?e=" + (e.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? e)) {
                AsyncImage(url: u) { ph in
                    if let img = ph.image { img.resizable().scaledToFit().padding(size * 0.1).frame(width: size, height: size).background(Color.white) }
                }
            }
        }
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.26).fill(color.opacity(0.13)))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
        .overlay(RoundedRectangle(cornerRadius: size * 0.26).stroke(color, lineWidth: ring ? 2 : 0).padding(-3))
    }
    func initials(_ n: String) -> String {
        let clean = n.components(separatedBy: CharacterSet(charactersIn: "·-")).first ?? n
        let w = clean.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }.joined()
        return w.isEmpty ? "·" : w.uppercased()
    }
}

/// Animated GIF (profile pictures, signatures) — decoded with ImageIO, played with TimelineView
struct GIFView: View {
    let data: Data?
    @State private var frames: [(CGImage, Double)] = []
    @State private var total: Double = 1
    var body: some View {
        TimelineView(.animation) { tl in
            if let img = frame(at: tl.date) {
                Image(decorative: img, scale: 1).resizable().scaledToFill()
            } else { Color.clear }
        }
        .onAppear(perform: decode)
    }
    func frame(at d: Date) -> CGImage? {
        guard !frames.isEmpty else { return nil }
        var t = d.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: total)
        for f in frames { if t < f.1 { return f.0 }; t -= f.1 }
        return frames.last?.0
    }
    func decode() {
        guard frames.isEmpty, let data, let src = CGImageSourceCreateWithData(data as CFData, nil) else { return }
        var out: [(CGImage, Double)] = []
        for i in 0..<CGImageSourceGetCount(src) {
            guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let g = p?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (g?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (g?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            out.append((img, max(delay, 0.02)))
        }
        frames = out; total = max(out.reduce(0) { $0 + $1.1 }, 0.1)
    }
}

/// Santoro profile animation shipped inside the app (works offline)
struct SantoroAvatar: View {
    var size: CGFloat = 44
    var who: String = "santoro"       // "santoro" o "hanif" (monograma animado)
    var body: some View {
        GIFView(data: Bundle.main.url(forResource: "av-" + who, withExtension: "gif").flatMap { try? Data(contentsOf: $0) })
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
    }
}

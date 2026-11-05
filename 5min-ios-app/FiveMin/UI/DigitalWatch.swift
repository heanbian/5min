import SwiftUI

/// 七段电子表数字，几何与 Android `DigitalWatch.kt` / Web `digitalWatchSvg` 对齐。
struct DigitalWatchTime: View {
    let text: String
    let color: Color

    private static let watchW: CGFloat = 144
    private static let watchH: CGFloat = 48

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Self.watchW, size.height / Self.watchH)
            let dx = (size.width - Self.watchW * scale) / 2
            let dy = (size.height - Self.watchH * scale) / 2
            context.concatenate(
                CGAffineTransform.identity
                    .translatedBy(x: dx, y: dy)
                    .scaledBy(x: scale, y: scale)
            )
            drawWatch(context: context, text: text, color: color)
        }
        .aspectRatio(Self.watchW / Self.watchH, contentMode: .fit)
    }

    private func drawWatch(context: GraphicsContext, text: String, color: Color) {
        let digits = text.filter(\.isNumber).map { Int(String($0)) ?? 0 }
        let padded = Array(repeating: 0, count: max(0, 4 - digits.count)) + digits.suffix(4)
        let oy: CGFloat = 6
        let slots: [(kind: String, x: CGFloat)] = [
            ("digit", 4), ("digit", 34), ("colon", 64), ("digit", 80), ("digit", 110),
        ]
        var di = 0
        for slot in slots {
            if slot.kind == "colon" {
                drawColon(context: context, ox: slot.x, oy: oy, color: color)
            } else {
                drawDigit(context: context, d: padded[di], ox: slot.x, oy: oy, color: color)
                di += 1
            }
        }
    }

    private static let digitSegs = [
        "abcdef", "bc", "abged", "abgcd", "fgbc",
        "afgcd", "afgcde", "abc", "abcdefg", "abfgcd",
    ]

    private func drawDigit(context: GraphicsContext, d: Int, ox: CGFloat, oy: CGFloat, color: Color) {
        let on = Self.digitSegs[min(max(d, 0), 9)]
        let segs = digitSegMap(ox: ox, oy: oy)
        for (key, path) in segs {
            let alpha: Double = on.contains(key) ? 1 : 0.05
            context.fill(Path(path), with: .color(color.opacity(alpha)))
        }
    }

    private func drawColon(context: GraphicsContext, ox: CGFloat, oy: CGFloat, color: Color) {
        let cx = ox + 6
        let r: CGFloat = 2.6
        context.fill(Path(ellipseIn: CGRect(x: cx - r, y: oy + 10 - r, width: r * 2, height: r * 2)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: cx - r, y: oy + 26 - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    private func digitSegMap(ox: CGFloat, oy: CGFloat) -> [Character: CGPath] {
        let dw: CGFloat = 22
        let dh: CGFloat = 36
        let t: CGFloat = 4
        let gap: CGFloat = 1
        let mid = dh / 2
        return [
            "a": hBar(ox + 2.5, oy, dw - 5, t),
            "g": hBar(ox + 2.5, oy + mid - t / 2, dw - 5, t),
            "d": hBar(ox + 2.5, oy + dh - t, dw - 5, t),
            "f": vBar(ox, oy + t + gap, mid - t - gap * 2, t),
            "b": vBar(ox + dw - t, oy + t + gap, mid - t - gap * 2, t),
            "e": vBar(ox, oy + mid + gap, mid - t - gap * 2, t),
            "c": vBar(ox + dw - t, oy + mid + gap, mid - t - gap * 2, t),
        ]
    }

    private func hBar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ t: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + t / 2))
        p.addLine(to: CGPoint(x: x + t / 2, y: y))
        p.addLine(to: CGPoint(x: x + w - t / 2, y: y))
        p.addLine(to: CGPoint(x: x + w, y: y + t / 2))
        p.addLine(to: CGPoint(x: x + w - t / 2, y: y + t))
        p.addLine(to: CGPoint(x: x + t / 2, y: y + t))
        p.closeSubpath()
        return p
    }

    private func vBar(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat, _ t: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x + t / 2, y: y))
        p.addLine(to: CGPoint(x: x + t, y: y + t / 2))
        p.addLine(to: CGPoint(x: x + t, y: y + h - t / 2))
        p.addLine(to: CGPoint(x: x + t / 2, y: y + h))
        p.addLine(to: CGPoint(x: x, y: y + h - t / 2))
        p.addLine(to: CGPoint(x: x, y: y + t / 2))
        p.closeSubpath()
        return p
    }
}

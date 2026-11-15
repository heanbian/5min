import SwiftUI

/// 七段电子表：现代细段 + 鼠尾草绿底盘，几何与各端对齐（viewBox 144×48）。
struct DigitalWatchTime: View {
    let text: String
    let color: Color

    private static let watchW: CGFloat = 144
    private static let watchH: CGFloat = 48
    /// 熄灭段底盘：固定鼠尾草灰绿，不随亮段染色
    private static let chassis = Color(red: 0xD0 / 255, green: 0xDE / 255, blue: 0xD6 / 255)

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
        let oy: CGFloat = 5
        let slots: [(kind: String, x: CGFloat)] = [
            ("digit", 2), ("digit", 34), ("colon", 64), ("digit", 78), ("digit", 110),
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
            let fill = on.contains(key) ? color : Self.chassis
            context.fill(Path(path), with: .color(fill))
        }
    }

    private func drawColon(context: GraphicsContext, ox: CGFloat, oy: CGFloat, color: Color) {
        let cx = ox + 6
        let r: CGFloat = 2.15
        context.fill(Path(ellipseIn: CGRect(x: cx - r, y: oy + 11 - r, width: r * 2, height: r * 2)), with: .color(color))
        context.fill(Path(ellipseIn: CGRect(x: cx - r, y: oy + 27 - r, width: r * 2, height: r * 2)), with: .color(color))
    }

    private func digitSegMap(ox: CGFloat, oy: CGFloat) -> [Character: CGPath] {
        let dw: CGFloat = 24
        let dh: CGFloat = 38
        let t: CGFloat = 3
        let gap: CGFloat = 1.25
        let mid = dh / 2
        let inset: CGFloat = 2.2
        return [
            "a": hBar(ox + inset, oy, dw - inset * 2, t),
            "g": hBar(ox + inset, oy + mid - t / 2, dw - inset * 2, t),
            "d": hBar(ox + inset, oy + dh - t, dw - inset * 2, t),
            "f": vBar(ox, oy + t + gap, mid - t - gap * 2, t),
            "b": vBar(ox + dw - t, oy + t + gap, mid - t - gap * 2, t),
            "e": vBar(ox, oy + mid + gap, mid - t - gap * 2, t),
            "c": vBar(ox + dw - t, oy + mid + gap, mid - t - gap * 2, t),
        ]
    }

    private func hBar(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ t: CGFloat) -> CGPath {
        let tip = t * 0.55
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + t / 2))
        p.addLine(to: CGPoint(x: x + tip, y: y))
        p.addLine(to: CGPoint(x: x + w - tip, y: y))
        p.addLine(to: CGPoint(x: x + w, y: y + t / 2))
        p.addLine(to: CGPoint(x: x + w - tip, y: y + t))
        p.addLine(to: CGPoint(x: x + tip, y: y + t))
        p.closeSubpath()
        return p
    }

    private func vBar(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat, _ t: CGFloat) -> CGPath {
        let tip = t * 0.55
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x + t / 2, y: y))
        p.addLine(to: CGPoint(x: x + t, y: y + tip))
        p.addLine(to: CGPoint(x: x + t, y: y + h - tip))
        p.addLine(to: CGPoint(x: x + t / 2, y: y + h))
        p.addLine(to: CGPoint(x: x, y: y + h - tip))
        p.addLine(to: CGPoint(x: x, y: y + tip))
        p.closeSubpath()
        return p
    }
}

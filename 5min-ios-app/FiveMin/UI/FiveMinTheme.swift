import SwiftUI

/// Design tokens mirrored from Android `FiveMinColors` / `FiveMinDimens` (5min-web/css/app.css).
enum FiveMinColor {
    static let brand = Color(red: 0x2F / 255, green: 0x9A / 255, blue: 0x68 / 255)
    static let brandStrong = Color(red: 0x24 / 255, green: 0x85 / 255, blue: 0x56 / 255)
    static let brandSoft = Color(red: 0xE5 / 255, green: 0xF5 / 255, blue: 0xEC / 255)
    static let bg = Color(red: 0xEE / 255, green: 0xF6 / 255, blue: 0xF1 / 255)
    static let bg2 = Color(red: 0xF7 / 255, green: 0xFA / 255, blue: 0xF8 / 255)
    static let bgBottom = Color(red: 0xF4 / 255, green: 0xF8 / 255, blue: 0xF5 / 255)
    static let glow = Color(red: 0xDF / 255, green: 0xF0 / 255, blue: 0xE6 / 255)
    static let surface = Color.white
    static let ink = Color(red: 0x1F / 255, green: 0x2A / 255, blue: 0x24 / 255)
    static let muted = Color(red: 0x5F / 255, green: 0x6F / 255, blue: 0x66 / 255)
    static let line = Color(red: 0xD7 / 255, green: 0xE5 / 255, blue: 0xDC / 255)
    static let ring = Color(red: 0xCF / 255, green: 0xE0 / 255, blue: 0xD6 / 255)
    static let warn = Color(red: 0xC9 / 255, green: 0x86 / 255, blue: 0x2D / 255)
    static let warnSoft = Color(red: 0xFF / 255, green: 0xF6 / 255, blue: 0xE8 / 255)
    static let warnGlow = Color(red: 0xFF / 255, green: 0xE9 / 255, blue: 0xC8 / 255)
    static let warnBottom = Color(red: 0xFF / 255, green: 0xFA / 255, blue: 0xF2 / 255)
    static let danger = Color(red: 0xD2 / 255, green: 0x55 / 255, blue: 0x4A / 255)
    static let dangerSoft = Color(red: 0xFF / 255, green: 0xEF / 255, blue: 0xED / 255)
    static let dangerGlow = Color(red: 0xFF / 255, green: 0xD7 / 255, blue: 0xD2 / 255)
    static let dangerBottom = Color(red: 0xFF / 255, green: 0xF7 / 255, blue: 0xF6 / 255)
}

enum FiveMinDimens {
    static let radiusSm: CGFloat = 12
    static let radius: CGFloat = 14
    static let controlH: CGFloat = 52
    static let rowH: CGFloat = 40
    static let padX: CGFloat = 20
    static let padY: CGFloat = 18
    static let stageGap: CGFloat = 18
    static let sectionGap: CGFloat = 20
    static let dialSize: CGFloat = 260
    static let topbarH: CGFloat = 36
}

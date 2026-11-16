import SwiftUI

/// Design tokens mirrored from Android `FiveMinColors` / `FiveMinDimens` (5min-web/css/app.css).

/// Plus Jakarta Sans — Latin UI；缺字时系统回退到中日韩字体。
enum FiveMinFont {
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(postScriptName(for: weight), size: size)
    }

    private static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            return "PlusJakartaSans-Bold"
        case .semibold:
            return "PlusJakartaSans-SemiBold"
        case .medium:
            return "PlusJakartaSans-Medium"
        default:
            return "PlusJakartaSans-Regular"
        }
    }
}

enum FiveMinColor {
    static let brand = Color(red: 0x2F / 255, green: 0x9A / 255, blue: 0x68 / 255)
    static let brandStrong = Color(red: 0x24 / 255, green: 0x85 / 255, blue: 0x56 / 255)
    static let brandSoft = Color(red: 0xE5 / 255, green: 0xF5 / 255, blue: 0xEC / 255)
    /// Primary gradient top stop — aligned with web `--brand-lift`
    static let brandLift = Color(red: 0x36 / 255, green: 0xA8 / 255, blue: 0x72 / 255)
    static let bg = Color(red: 0xEE / 255, green: 0xF6 / 255, blue: 0xF1 / 255)
    /// Records / Mine list page — aligned with MP `#F2F5F3`
    static let bg2 = Color(red: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF3 / 255)
    static let bgBottom = Color(red: 0xF4 / 255, green: 0xF8 / 255, blue: 0xF5 / 255)
    static let glow = Color(red: 0xDF / 255, green: 0xF0 / 255, blue: 0xE6 / 255)
    static let surface = Color.white
    static let ink = Color(red: 0x1F / 255, green: 0x2A / 255, blue: 0x24 / 255)
    static let muted = Color(red: 0x5F / 255, green: 0x6F / 255, blue: 0x66 / 255)
    static let line = Color(red: 0xD7 / 255, green: 0xE5 / 255, blue: 0xDC / 255)
    /// Reset / secondary — aligned with web `.ghost`
    static let ghostBg = Color(red: 0xE8 / 255, green: 0xEC / 255, blue: 0xEA / 255)
    static let ghostInk = Color(red: 0x6B / 255, green: 0x75 / 255, blue: 0x70 / 255)
    static let ghostLine = Color(red: 0xD5 / 255, green: 0xDB / 255, blue: 0xD7 / 255)
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
    /// 首页操作按钮 / 场景选择 / 芯片统一大圆角
    static let radius: CGFloat = 22
    /// 列表卡片 / 统计卡
    static let radiusCard: CGFloat = 14
    /// 弹层卡片（仪式等）
    static let radiusDialog: CGFloat = 16
    /// 底部 sheet 顶角
    static let radiusSheet: CGFloat = 18
    static let controlH: CGFloat = 52
    static let fieldH: CGFloat = 52
    static let rowH: CGFloat = 40
    /// 筛选胶囊 / 快捷分钟芯片高度
    static let chipH: CGFloat = 40
    static let filterChipH: CGFloat = 40
    /// 首页推荐场景胶囊
    static let suggestedChipH: CGFloat = 32
    static let padX: CGFloat = 20
    static let padY: CGFloat = 18
    static let padBody: CGFloat = 16
    static let stageGap: CGFloat = 18
    static let sectionGap: CGFloat = 20
    static let listSectionGap: CGFloat = 16
    static let controlGap: CGFloat = 10
    static let dialSize: CGFloat = 260
    static let topbarH: CGFloat = 36
}

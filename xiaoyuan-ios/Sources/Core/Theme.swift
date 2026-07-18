import SwiftUI

/// 针脚小园 · 全局视觉契约(所有模块只从这里取色和字体)
enum Theme {
    // 毛毡色板(与 garden/ASSETS.md 一致)
    static let ink        = Color(hex: 0x5A4232)   // 暖棕墨线/正文
    static let inkSoft    = Color(hex: 0x7A6350)
    static let paper      = Color(hex: 0xFFFDF6)   // 纸/卡底
    static let paperWarm  = Color(hex: 0xFFF7E8)
    static let cream      = Color(hex: 0xFFF6E3)
    static let sage       = Color(hex: 0x9CC08A)
    static let leaf       = Color(hex: 0x6FA06B)
    static let terra      = Color(hex: 0xD98A6A)
    static let pink       = Color(hex: 0xEFB6B2)
    static let butter     = Color(hex: 0xFFD98A)
    static let nightHi    = Color(hex: 0x2E3550)
    static let nightLo    = Color(hex: 0x4A4E73)

    /// 手写感(楷体);正文默认系统苹方
    static func kai(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Kaiti SC", size: size).weight(weight)
    }

    static let cornerSheet: CGFloat = 26
    static let cornerCard: CGFloat = 10
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// 昼夜段位:园景与 UI 都跟真实时间走
enum DayPhase: String {
    case dawn, day, dusk, night
    static func current(_ date: Date = .now) -> DayPhase {
        let h = Calendar.current.component(.hour, from: date)
        let m = Calendar.current.component(.minute, from: date)
        let t = Double(h) + Double(m) / 60
        switch t {
        case 5..<7: return .dawn
        case 7..<17.5: return .day
        case 17.5..<19.5: return .dusk
        default: return .night
        }
    }
}

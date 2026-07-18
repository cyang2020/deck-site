import SwiftUI
import Combine

/// 园子的"此刻":昼夜段位 + 节气 + 日期章文本。
/// 每 60 秒对一次表;场景与天空一起观察它。回到前台时由根视图再叫一次 `refresh()`。
final class Ambience: ObservableObject {
    @Published private(set) var phase: DayPhase
    @Published private(set) var termName: String
    @Published private(set) var month: Int
    /// 顶部日期章文本,如 "7月18日 · 小暑"
    @Published private(set) var dateLine: String

    private var ticker: AnyCancellable?

    init(date: Date = .now) {
        phase = DayPhase.current(date)
        termName = SolarTerms.current(date)
        month = Calendar.current.component(.month, from: date)
        dateLine = Ambience.composeDateLine(date)
        ticker = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.refresh(now) }
    }

    /// 萤火虫只在夏天的夜里来(5–9 月)
    var isFireflySeason: Bool { (5...9).contains(month) }

    /// 对表。只有真的变了才发布,免得整幅园景无谓地重画。
    func refresh(_ date: Date = .now) {
        let newPhase = DayPhase.current(date)
        if newPhase != phase { phase = newPhase }
        let newTerm = SolarTerms.current(date)
        if newTerm != termName { termName = newTerm }
        let newMonth = Calendar.current.component(.month, from: date)
        if newMonth != month { month = newMonth }
        let newLine = Ambience.composeDateLine(date)
        if newLine != dateLine { dateLine = newLine }
    }

    private static func composeDateLine(_ date: Date) -> String {
        let m = Calendar.current.component(.month, from: date)
        let d = Calendar.current.component(.day, from: date)
        return "\(m)月\(d)日 · \(SolarTerms.current(date))"
    }
}

// MARK: - 昼夜配色(与 garden/index.html 的 CSS 变量一一对应)

/// 一段昼夜的整套景物配色。天空归 SkyView,山与草归 GardenSceneView。
struct ScenePalette {
    let skyHi: Color
    let skyLo: Color
    let hillFar: Color
    let hillNear: Color
    let grass: Color
    let grassDeep: Color
    let pine: Color

    init(_ phase: DayPhase) {
        switch phase {
        case .dawn:
            skyHi = Color(hex: 0xF3CDB6); skyLo = Color(hex: 0xFDEED2)
            hillFar = Color(hex: 0xCBDDB4); hillNear = Color(hex: 0xAECB99)
            grass = Theme.sage; grassDeep = Theme.leaf
            pine = Color(hex: 0x4F7D5B)
        case .day:
            skyHi = Color(hex: 0xC2E2DD); skyLo = Color(hex: 0xFFF3D9)
            hillFar = Color(hex: 0xCBDDB4); hillNear = Color(hex: 0xAECB99)
            grass = Theme.sage; grassDeep = Theme.leaf
            pine = Color(hex: 0x4F7D5B)
        case .dusk:
            skyHi = Color(hex: 0xE7B8A2); skyLo = Color(hex: 0xFBE3C0)
            hillFar = Color(hex: 0xC4B9A4); hillNear = Color(hex: 0x9DB088)
            grass = Theme.sage; grassDeep = Theme.leaf
            pine = Color(hex: 0x4F7D5B)
        case .night:
            skyHi = Theme.nightHi; skyLo = Theme.nightLo
            hillFar = Color(hex: 0x3E4A55); hillNear = Color(hex: 0x37544C)
            grass = Color(hex: 0x5E7D62); grassDeep = Color(hex: 0x48664F)
            pine = Color(hex: 0x3A5A48)
        }
    }
}

// MARK: - 夜里毛毡素材整体变暗

extension View {
    /// 夜:≈ brightness .62 × saturation .8;黄昏:微微偏暖变柔。
    /// 用乘色(colorMultiply)而不是加减亮度,更接近原型里 CSS 的乘法滤镜。
    func spriteDimming(for phase: DayPhase) -> some View {
        let sat: Double
        let mult: Color
        switch phase {
        case .night:
            sat = 0.8; mult = Color(white: 0.62)
        case .dusk:
            sat = 0.95; mult = Color(hex: 0xF0DFCB)
        case .dawn, .day:
            sat = 1; mult = .white
        }
        return saturation(sat).colorMultiply(mult)
    }
}

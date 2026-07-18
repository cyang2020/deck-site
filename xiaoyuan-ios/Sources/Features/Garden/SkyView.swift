import SwiftUI

/// 全幅天空:随昼夜变化的渐变,太阳或一弯月亮与刺绣样的星星,
/// 两朵慢慢飘的毛毡云;夏夜(5–9 月)有萤火虫。
/// 固定在屏幕上,不随园景滚动;放在场景最底层。
struct SkyView: View {
    @ObservedObject var ambience: Ambience
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let palette = ScenePalette(ambience.phase)
            let size = geo.size
            ZStack {
                LinearGradient(colors: [palette.skyHi, palette.skyLo],
                               startPoint: .top, endPoint: .bottom)
                if ambience.phase == .night {
                    stars(in: size)
                    moon(in: size)
                } else {
                    sun(in: size)
                }
                drifting(in: size)
            }
            .animation(.easeInOut(duration: 2), value: ambience.phase)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 太阳 / 月亮 / 星星

    private func sun(in size: CGSize) -> some View {
        let y = ambience.phase == .day ? size.height * 0.15 : size.height * 0.21
        return ZStack {
            Circle()
                .fill(Theme.butter)
                .opacity(0.25)
                .frame(width: 150, height: 150)
                .blur(radius: 6)
            Image("sun")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
        }
        .position(x: size.width * 0.42, y: y)
        .transition(.opacity)
    }

    private func moon(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0xF6E7B2))
                .opacity(0.22)
                .frame(width: 132, height: 132)
                .blur(radius: 10)
            CrescentMoonView(diameter: 86)
        }
        .position(x: size.width * 0.46, y: size.height * 0.16)
        .transition(.opacity)
    }

    /// (x, y) 为屏幕比例位置,s 为针脚星星的大小
    private static let starSpots: [(x: CGFloat, y: CGFloat, s: CGFloat)] = [
        (0.10, 0.10, 7), (0.20, 0.24, 5), (0.31, 0.12, 8), (0.38, 0.32, 5),
        (0.49, 0.06, 6), (0.56, 0.29, 7), (0.63, 0.19, 5), (0.71, 0.37, 6),
        (0.79, 0.10, 7), (0.88, 0.28, 5), (0.94, 0.16, 6), (0.60, 0.42, 4),
    ]

    private func stars(in size: CGSize) -> some View {
        ForEach(0..<Self.starSpots.count, id: \.self) { i in
            let spot = Self.starSpots[i]
            StitchStarView(size: spot.s)
                .rotationEffect(.degrees(i.isMultiple(of: 2) ? 0 : 45))
                .position(x: size.width * spot.x, y: size.height * spot.y)
        }
        .transition(.opacity)
    }

    // MARK: - 云与萤火虫(用时间线驱动,慢而省;关闭动态效果时静止)

    private func drifting(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let night = ambience.phase == .night
            ZStack {
                cloud("cloud-a", width: 152,
                      x: cloudX(t, duration: 150, offset: 0.32, size: size),
                      y: size.height * 0.10,
                      opacity: night ? 0.5 : 0.9)
                cloud("cloud-b", width: 110,
                      x: size.width - cloudX(t, duration: 210, offset: 0.25, size: size),
                      y: size.height * 0.24,
                      opacity: night ? 0.4 : 0.75)
                if night && ambience.isFireflySeason {
                    fireflies(t: t, in: size)
                }
            }
        }
    }

    private func cloud(_ name: String, width: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .opacity(opacity)
            .position(x: x, y: y)
    }

    /// 从屏幕外缓缓横穿(-0.25W → 1.25W);关闭动态效果时停在 offset 处。
    private func cloudX(_ t: TimeInterval, duration: Double, offset: Double, size: CGSize) -> CGFloat {
        if reduceMotion { return size.width * CGFloat(offset) }
        let u = ((t / duration) + offset).truncatingRemainder(dividingBy: 1)
        return size.width * CGFloat(-0.25 + 1.5 * u)
    }

    /// (x, y) 屏幕比例位置(略高于远山线,天幕在园景后面),r 半径,delay 错开呼吸
    private static let fireflySpots: [(x: CGFloat, y: CGFloat, r: CGFloat, delay: Double)] = [
        (0.16, 0.50, 3.0, 0.0), (0.30, 0.55, 2.6, 1.1), (0.44, 0.48, 2.4, 2.0),
        (0.58, 0.53, 3.2, 0.6), (0.72, 0.46, 2.6, 2.8), (0.86, 0.52, 3.0, 1.7),
    ]

    private func fireflies(t: TimeInterval, in size: CGSize) -> some View {
        ForEach(0..<Self.fireflySpots.count, id: \.self) { i in
            let f = Self.fireflySpots[i]
            let u = ((t + f.delay) / 4.2).truncatingRemainder(dividingBy: 1)
            let alpha = reduceMotion ? 0.55 : Self.blink(u)
            let dy: CGFloat = reduceMotion ? 0 : CGFloat(-12 * sin(.pi * u))
            Circle()
                .fill(Color(hex: 0xFFE9A0))
                .frame(width: f.r * 2, height: f.r * 2)
                .shadow(color: Color(hex: 0xFFE9A0).opacity(0.8), radius: 6)
                .opacity(alpha)
                .position(x: size.width * f.x, y: size.height * f.y + dy)
        }
        .transition(.opacity)
    }

    /// 近似原型的萤火 keyframes:0→0,0.4→0.95,0.6→0.5,0.8→0.9,1→0
    private static func blink(_ u: Double) -> Double {
        switch u {
        case ..<0.4: return u / 0.4 * 0.95
        case ..<0.6: return 0.95 - (u - 0.4) / 0.2 * 0.45
        case ..<0.8: return 0.5 + (u - 0.6) / 0.2 * 0.4
        default: return max(0, 0.9 - (u - 0.8) / 0.2 * 0.9)
        }
    }
}

// MARK: - 一弯月亮(毡子色,两圆相减)

private struct CrescentMoonView: View {
    let diameter: CGFloat
    var body: some View {
        Circle()
            .fill(Color(hex: 0xF6E7B2))
            .frame(width: diameter, height: diameter)
            .overlay(
                Circle()
                    .fill(Color.black)
                    .frame(width: diameter * 0.91, height: diameter * 0.91)
                    .offset(x: -diameter * 0.18, y: -diameter * 0.11)
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
    }
}

// MARK: - 刺绣针脚星星(十字小线迹)

private struct StitchStarView: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Capsule().frame(width: size, height: max(1.6, size * 0.26))
            Capsule().frame(width: max(1.6, size * 0.26), height: size)
        }
        .foregroundStyle(Color(hex: 0xF2E9D8))
        .opacity(0.9)
    }
}

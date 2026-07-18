import SwiftUI
import SwiftData

/// 园景主场景:一整幅可以横向漫步的毛毡园子(镜像 garden/index.html 的布局)。
/// 天空(SkyView)在最底层由根视图铺好;这里画视差远山、草地与园中之物。
/// 坐标系与网页原型一致:场景高 1000、宽 2600,按屏幕高度等比缩放。
struct GardenSceneView: View {
    @ObservedObject var ambience: Ambience
    /// 点到园中某处(邮筒/花坛/花房/小屋)
    var onOpen: (GardenPlace) -> Void
    /// 双指一捏,切到 3D 俯瞰
    var onPinchOverview: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Plant.plantedAt) private var plants: [Plant]

    @State private var scrollX: CGFloat = 0
    @State private var doorOpen = false
    @State private var isSwinging = false
    @State private var hintShown = false
    @State private var hintDismissed = false

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.height / L.unitH
            let palette = ScenePalette(ambience.phase)
            ZStack(alignment: .topLeading) {
                hills(palette: palette, k: k, height: geo.size.height)
                    .offset(x: -scrollX * 0.3)
                ScrollView(.horizontal, showsIndicators: false) {
                    scene(palette: palette, k: k, height: geo.size.height)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(key: ScrollXKey.self,
                                                       value: -g.frame(in: .named("gardenScroll")).minX)
                            }
                        )
                }
                .coordinateSpace(.named("gardenScroll"))
                .onPreferenceChange(ScrollXKey.self) { x in
                    scrollX = x
                    if x > 30 { hintDismissed = true }
                }
            }
            .overlay(alignment: .bottom) { hint }
        }
        .simultaneousGesture(
            MagnifyGesture().onEnded { value in
                if value.magnification > 1.35 || value.magnification < 0.72 { onPinchOverview() }
            }
        )
        .onAppear {
            if reduceMotion {
                doorOpen = true
            } else {
                withAnimation(.easeInOut(duration: 1.4).delay(0.6)) { doorOpen = true }
            }
            withAnimation(.easeInOut(duration: 1.2).delay(1.8)) { hintShown = true }
        }
    }

    // MARK: - 远山(0.3 倍视差)

    private func hills(palette: ScenePalette, k: CGFloat, height: CGFloat) -> some View {
        ZStack {
            QuadFillShape(start: CGPoint(x: 0, y: 760), segments: [
                (CGPoint(x: 640, y: 700), CGPoint(x: 300, y: 600)),
                (CGPoint(x: 1300, y: 690), CGPoint(x: 980, y: 800)),
                (CGPoint(x: 2000, y: 710), CGPoint(x: 1620, y: 580)),
                (CGPoint(x: 2700, y: 680), CGPoint(x: 2380, y: 840)),
                (CGPoint(x: 3400, y: 720), CGPoint(x: 3020, y: 520)),
            ])
            .fill(palette.hillFar)
            QuadFillShape(start: CGPoint(x: 0, y: 820), segments: [
                (CGPoint(x: 800, y: 780), CGPoint(x: 380, y: 700)),
                (CGPoint(x: 1600, y: 790), CGPoint(x: 1220, y: 860)),
                (CGPoint(x: 2400, y: 760), CGPoint(x: 1980, y: 720)),
                (CGPoint(x: 3400, y: 800), CGPoint(x: 2820, y: 800)),
            ])
            .fill(palette.hillNear)
            PinesShape(pines: [
                (520, 712, 32, 38), (560, 716, 26, 30), (1720, 742, 30, 36),
                (2560, 722, 32, 38), (2600, 728, 24, 27),
            ])
            .fill(palette.pine.opacity(0.8))
        }
        .frame(width: 3400 * k, height: height)
        .animation(.easeInOut(duration: 2), value: ambience.phase)
        .allowsHitTesting(false)
    }

    // MARK: - 场景内容(宽 2600 单位)

    private func scene(palette: ScenePalette, k: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ground(palette: palette)
            sprites(k: k, palette: palette)
                .spriteDimming(for: ambience.phase)
            if ambience.phase == .night { nightGlows(k: k) }
        }
        .frame(width: L.unitW * k, height: height)
        .animation(.easeInOut(duration: 2), value: ambience.phase)
    }

    private func ground(palette: ScenePalette) -> some View {
        ZStack {
            QuadFillShape(start: CGPoint(x: 0, y: 772), segments: [
                (CGPoint(x: 900, y: 768), CGPoint(x: 400, y: 752)),
                (CGPoint(x: 1800, y: 764), CGPoint(x: 1400, y: 784)),
                (CGPoint(x: 2600, y: 770), CGPoint(x: 2200, y: 744)),
            ])
            .fill(palette.grass)
            QuadFillShape(start: CGPoint(x: 0, y: 840), segments: [
                (CGPoint(x: 1200, y: 838), CGPoint(x: 500, y: 820)),
                (CGPoint(x: 2600, y: 834), CGPoint(x: 1900, y: 856)),
            ])
            .fill(palette.grassDeep)
            .opacity(0.55)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func sprites(k: CGFloat, palette: ScenePalette) -> some View {
        let night = ambience.phase == .night
        ZStack {
            // 草叶小簇
            TuftShape(bases: [(420, 790), (1350, 800), (2380, 792), (840, 806)])
                .stroke(palette.pine.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2.4 * k, lineCap: .round))

            // 后排篱笆(毛毡木桩 + 横档)
            ForEach(Array(stride(from: 490.0, to: 2440.0, by: 44.0)), id: \.self) { x in
                Image("picket")
                    .resizable()
                    .scaledToFit()
                    .placed(x - 26.2, 684.6, 52.4, 78.7, k: k)
            }
            RoundedRectangle(cornerRadius: 3.5 * k)
                .fill(Color(hex: 0xE9DCC2))
                .overlay(RoundedRectangle(cornerRadius: 3.5 * k)
                    .stroke(Theme.ink, lineWidth: 2 * k))
                .placed(470, 726, 1970, 7, k: k)

            // 篱笆门:门扇(进园时轻轻推开)+ 门框 + 空牌上的字
            Image("gate-door")
                .resizable()
                .scaledToFit()
                .opacity(doorOpen ? 0.85 : 1)
                .scaleEffect(x: doorOpen ? 0.14 : 1, y: 1, anchor: .leading)
                .rotationEffect(.degrees(doorOpen ? -3 : 0), anchor: .bottomLeading)
                .placed(118.6, 573.5, 156.6, 235, k: k)
            Image("gate-frame")
                .resizable()
                .scaledToFit()
                .placed(75, 525, 250, 250, k: k)
            Text("小园")
                .font(Theme.kai(21 * k))
                .tracking(5 * k)
                .foregroundStyle(Color(hex: 0x6B4A2E))
                .position(x: 198 * k, y: 646 * k)

            // 邮筒
            tappableSprite("mailbox", 300, 590, 123, 185, k: k) { onOpen(.mailbox) }

            // 花坛:花床 + 立牌 + 种下的植物;整片区域都能点开抽屉
            Image("flowerbed")
                .resizable()
                .scaledToFit()
                .placed(451, 628, 410, 273, k: k)
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 3 * k, height: 44 * k)
                .position(x: 820 * k, y: 730 * k)
            RoundedRectangle(cornerRadius: 7 * k)
                .fill(Color(hex: 0xFFF3D9))
                .overlay(RoundedRectangle(cornerRadius: 7 * k)
                    .stroke(Theme.ink, lineWidth: 2.6 * k))
                .overlay(Text("花坛")
                    .font(Theme.kai(17 * k))
                    .foregroundStyle(Theme.ink))
                .placed(792, 686, 58, 30, k: k)
            ForEach(plants) { plant in
                let slot = min(max(plant.slot, 0), L.plantSlots.count - 1)
                PlantSpriteView(plant: plant)
                    .frame(width: 64 * k, height: 96 * k, alignment: .bottom)
                    .allowsHitTesting(false)
                    .position(x: L.plantSlots[slot] * k, y: 708 * k)   // 底边落在土上(y 756)
            }
            Color.clear
                .frame(width: 400 * k, height: 156 * k)
                .contentShape(Rectangle())
                .onTapGesture { onOpen(.flowerbed) }
                .position(x: 656 * k, y: 718 * k)

            // 花房(夜里换成亮灯那张)
            nightSwappedSprite(day: "greenhouse", nightName: "greenhouse-night", night: night,
                               865, 495, 420, 280, k: k) { onOpen(.greenhouse) }

            // 大树与秋千(点一下,轻轻荡起来;再点一下停)
            Image("tree")
                .resizable()
                .scaledToFit()
                .placed(1420, 258, 347, 520, k: k)
            Image("swing")
                .resizable()
                .scaledToFit()
                .frame(width: 117.6 * k, height: 176 * k)
                .rotationEffect(.degrees(isSwinging ? -5 : 2), anchor: .top)
                .animation(isSwinging
                           ? .easeInOut(duration: 1.7).repeatForever(autoreverses: true)
                           : .spring(response: 1.2, dampingFraction: 0.6),
                           value: isSwinging)
                .contentShape(Rectangle())
                .onTapGesture { if !reduceMotion { isSwinging.toggle() } }
                .position(x: 1692 * k, y: 631 * k)

            // 小屋(夜里圆窗亮灯)
            nightSwappedSprite(day: "cottage", nightName: "cottage-night", night: night,
                               1885, 508, 400, 267, k: k) { onOpen(.dollhouse) }

            // 野花地
            WildflowerView(k: k).position(x: 2280 * k, y: (760 - 15.5) * k)
            WildflowerView(k: k, scale: 0.85).position(x: 2320 * k, y: (780 - 13.2) * k)
            WildflowerView(k: k, scale: 1.1).position(x: 2362 * k, y: (764 - 17) * k)
            WildflowerView(k: k, scale: 0.8).position(x: 2410 * k, y: (782 - 12.4) * k)

            // 小溪(流向园子东南角)
            Image("stream")
                .resizable()
                .scaledToFit()
                .placed(2402, 708, 210, 315, k: k)
        }
    }

    /// 夜里亮起的暖光(不参与整体压暗)
    private func nightGlows(k: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24 * k)
                .fill(Theme.butter)
                .opacity(0.16)
                .blur(radius: 8 * k)
                .placed(885, 520, 380, 240, k: k)
            Circle()
                .fill(Theme.butter)
                .opacity(0.55)
                .blur(radius: 12 * k)
                .placed(2105, 650, 52, 52, k: k)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    // MARK: - 小件

    private func tappableSprite(_ name: String,
                                _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                                k: CGFloat, action: @escaping () -> Void) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: w * k, height: h * k)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .position(x: (x + w / 2) * k, y: (y + h / 2) * k)
    }

    /// 白天/夜晚两张素材交叉淡入,整体可点
    private func nightSwappedSprite(day: String, nightName: String, night: Bool,
                                    _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                                    k: CGFloat, action: @escaping () -> Void) -> some View {
        ZStack {
            Image(day)
                .resizable()
                .scaledToFit()
                .opacity(night ? 0 : 1)
            Image(nightName)
                .resizable()
                .scaledToFit()
                .opacity(night ? 1 : 0)
        }
        .frame(width: w * k, height: h * k)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .position(x: (x + w / 2) * k, y: (y + h / 2) * k)
    }

    private var hint: some View {
        Text("往右边走走 →")
            .font(Theme.kai(15))
            .tracking(4)
            .foregroundStyle(ambience.phase == .night ? Color(hex: 0xD8D2C2) : Theme.inkSoft)
            .opacity(hintShown && !hintDismissed ? 1 : 0)
            .animation(.easeInOut(duration: 1.2), value: hintDismissed)
            .padding(.bottom, 26)
            .allowsHitTesting(false)
    }
}

// MARK: - 布局常量(原型坐标系:高 1000,宽 2600)

private enum L {
    static let unitW: CGFloat = 2600
    static let unitH: CGFloat = 1000
    /// 花坛六个格位的横坐标(基线 y = 756)
    static let plantSlots: [CGFloat] = [510, 560, 610, 660, 710, 760]
}

// MARK: - 形状

/// 一串二次贝塞尔曲线围成的地形(照抄原型 SVG 路径,底边闭合)
private struct QuadFillShape: Shape {
    var start: CGPoint
    /// (终点, 控制点),单位坐标(高 1000)
    var segments: [(CGPoint, CGPoint)]

    func path(in rect: CGRect) -> Path {
        let k = rect.height / 1000
        var p = Path()
        p.move(to: CGPoint(x: start.x * k, y: start.y * k))
        for (to, control) in segments {
            p.addQuadCurve(to: CGPoint(x: to.x * k, y: to.y * k),
                           control: CGPoint(x: control.x * k, y: control.y * k))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// 远山上的小杉树(基线左端 x, 基线 y, 宽, 高)
private struct PinesShape: Shape {
    var pines: [(CGFloat, CGFloat, CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        let k = rect.height / 1000
        var p = Path()
        for (x, y, w, h) in pines {
            p.move(to: CGPoint(x: x * k, y: y * k))
            p.addLine(to: CGPoint(x: (x + w / 2) * k, y: (y - h) * k))
            p.addLine(to: CGPoint(x: (x + w) * k, y: y * k))
            p.closeSubpath()
        }
        return p
    }
}

/// 三根小草叶一簇
private struct TuftShape: Shape {
    var bases: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        let k = rect.height / 1000
        var p = Path()
        for (x, y) in bases {
            p.move(to: CGPoint(x: x * k, y: y * k))
            p.addLine(to: CGPoint(x: x * k, y: (y - 12) * k))
            p.move(to: CGPoint(x: (x + 8) * k, y: y * k))
            p.addLine(to: CGPoint(x: (x + 13) * k, y: (y - 10) * k))
            p.move(to: CGPoint(x: (x - 8) * k, y: y * k))
            p.addLine(to: CGPoint(x: (x - 13) * k, y: (y - 10) * k))
        }
        return p
    }
}

/// 野花:细茎 + 米色小圆花
private struct WildflowerView: View {
    let k: CGFloat
    var scale: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color(hex: 0xF3E4B2))
                .overlay(Circle().stroke(Theme.ink, lineWidth: 1.8 * k * scale))
                .frame(width: 11 * k * scale, height: 11 * k * scale)
            Rectangle()
                .fill(Theme.ink)
                .frame(width: 2 * k * scale, height: 20 * k * scale)
        }
    }
}

// MARK: - 滚动量(供远山视差)

private struct ScrollXKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - SVG 式定位:x/y 为左上角,单位为原型坐标,k 为缩放

private extension View {
    func placed(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, k: CGFloat) -> some View {
        frame(width: w * k, height: h * k)
            .position(x: (x + w / 2) * k, y: (y + h / 2) * k)
    }
}

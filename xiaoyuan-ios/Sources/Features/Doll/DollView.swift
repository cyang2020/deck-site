import SwiftUI

// MARK: - 布料契约(缝娃娃与画娃娃共用;索引即 DollProfile.fabric)

/// 四块毛毡/棉布小样。索引写进 DollProfile.fabric,永不重排。
public struct DollFabric: Identifiable, Equatable {
    public enum Pattern: Equatable { case plain, dots, gingham, sprigs }

    public let id: Int
    public let name: String
    public let base: Color
    public let accent: Color
    public let pattern: Pattern

    public static let all: [DollFabric] = [
        DollFabric(id: 0, name: "奶油小花", base: Theme.cream, accent: Theme.pink, pattern: .sprigs),
        DollFabric(id: 1, name: "雾青圆点", base: Color(hex: 0xC9D8C5), accent: Theme.paper, pattern: .dots),
        DollFabric(id: 2, name: "陶土格纹", base: Color(hex: 0xE8B49B), accent: Color(hex: 0xC97F5E), pattern: .gingham),
        DollFabric(id: 3, name: "本白素麻", base: Theme.paperWarm, accent: Color(hex: 0xD9C9A8), pattern: .plain),
    ]

    /// 越界索引一律退回第 0 块,不让旧数据崩掉屋子
    public static func at(_ index: Int) -> DollFabric {
        all.indices.contains(index) ? all[index] : all[0]
    }
}

/// 三张缝出来的表情。索引即 DollProfile.expression。
public enum DollExpression: Int, CaseIterable {
    case smiley = 0   // 笑眯眯
    case quiet  = 1   // 静静的
    case dozy   = 2   // 呆呆的

    public var label: String {
        switch self {
        case .smiley: "笑眯眯"
        case .quiet:  "静静的"
        case .dozy:   "呆呆的"
        }
    }

    public static func at(_ index: Int) -> DollExpression {
        DollExpression(rawValue: index) ?? .smiley
    }
}

/// 娃娃此刻在做什么(它只会这几件事)
public enum DollReaction: Equatable {
    case idle        // 坐着,慢慢呼吸
    case listening   // 侧过来一点,在听
    case received    // 点点头,把烦恼叠好收进兜
    case companion   // 陪着,不动
}

// MARK: - 布料纹样(小样片与娃娃身体共用)

/// 一块布:底色 + 纹样。裁成什么形状由外面 clip 决定。
struct FabricSwatch: View {
    let fabric: DollFabric

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(fabric.base))
            switch fabric.pattern {
            case .plain:
                var rng = SeededRandom(seed: 7)
                for _ in 0..<Int(size.width * size.height / 260) {
                    let p = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: 1.6, height: 1.6)),
                             with: .color(fabric.accent.opacity(0.5)))
                }
            case .dots:
                let step: CGFloat = 16
                var row = 0
                for y in stride(from: 6, to: size.height, by: step) {
                    let shift: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
                    for x in stride(from: 6 + shift, to: size.width, by: step) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8)),
                                 with: .color(fabric.accent.opacity(0.85)))
                    }
                    row += 1
                }
            case .gingham:
                let step: CGFloat = 14
                for x in stride(from: 0, to: size.width, by: step) {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: step / 2, height: size.height)),
                             with: .color(fabric.accent.opacity(0.30)))
                }
                for y in stride(from: 0, to: size.height, by: step) {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: step / 2)),
                             with: .color(fabric.accent.opacity(0.30)))
                }
            case .sprigs:
                let step: CGFloat = 24
                var row = 0
                for y in stride(from: 10, to: size.height, by: step) {
                    let shift: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
                    for x in stride(from: 10 + shift, to: size.width, by: step) {
                        for k in 0..<5 {
                            let a = Double(k) / 5 * 2 * .pi
                            let px = x + cos(a) * 3.2, py = y + sin(a) * 3.2
                            ctx.fill(Path(ellipseIn: CGRect(x: px - 1.7, y: py - 1.7, width: 3.4, height: 3.4)),
                                     with: .color(fabric.accent.opacity(0.9)))
                        }
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                                 with: .color(Theme.butter))
                    }
                    row += 1
                }
            }
        }
    }
}

/// 确定性小随机(布纹用,重画不变)
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
}

// MARK: - 娃娃本体(纯 SwiftUI 手绘,无素材)

/// 布娃娃。粗针脚、纽扣眼睛、胸前小布袋。
/// 设计坐标 200×250,`scale` 缩放整体(布局尺寸一并缩放)。
public struct DollView: View {
    public var fabricIndex: Int
    public var expressionIndex: Int
    public var reaction: DollReaction
    public var scale: CGFloat

    public init(fabricIndex: Int, expressionIndex: Int,
                reaction: DollReaction = .idle, scale: CGFloat = 1) {
        self.fabricIndex = fabricIndex
        self.expressionIndex = expressionIndex
        self.reaction = reaction
        self.scale = scale
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var blink = false
    @State private var nod: Double = 0          // 点头角度
    @State private var paperPhase: CGFloat = 0  // 0 没纸 → 1 收进兜

    private var fabric: DollFabric { DollFabric.at(fabricIndex) }
    private var expression: DollExpression { DollExpression.at(expressionIndex) }
    private var stitch: StrokeStyle {
        StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [5, 5])
    }

    public var body: some View {
        ZStack {
            body200
        }
        .frame(width: 200, height: 250)
        .scaleEffect(scale)
        .frame(width: 200 * scale, height: 250 * scale)
        .accessibilityLabel("布娃娃")
    }

    // 设计坐标下的完整娃娃
    private var body200: some View {
        ZStack {
            // 身体(圆滚滚一块毡)
            bodyShape
                .frame(width: 132, height: 118)
                .offset(y: 52)
            // 手:两只小圆手
            hand.offset(x: -66, y: 46)
            hand.offset(x: 66, y: 46)
            // 脚
            foot.offset(x: -30, y: 112)
            foot.offset(x: 30, y: 112)
            // 胸前小布袋(+ 收纸动画)
            pocket.offset(y: 66)
            if paperPhase > 0 { foldedPaper }
            // 头
            head.offset(y: -42)
        }
        .rotationEffect(.degrees(leanAngle + nod), anchor: .bottom)
        .scaleEffect(breathe ? 1.015 : 1.0, anchor: .bottom)
        .task(id: reduceMotion) { await idleLoops() }
        .onChange(of: reaction) { _, new in
            if new == .received { Task { await receivedSequence() } }
        }
    }

    private var leanAngle: Double {
        reaction == .listening ? -4 : 0
    }

    // MARK: 部件

    private var bodyShape: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 54, style: .continuous)
                .fill(.clear)
                .background(FabricSwatch(fabric: fabric))
                .clipShape(RoundedRectangle(cornerRadius: 54, style: .continuous))
            RoundedRectangle(cornerRadius: 54, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.55), style: stitch)
        }
        .shadow(color: Theme.ink.opacity(0.10), radius: 6, y: 4)
    }

    private var head: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .background(FabricSwatch(fabric: fabric))
                .clipShape(Circle())
            Circle().strokeBorder(Theme.ink.opacity(0.55), style: stitch)
            face
        }
        .frame(width: 108, height: 108)
        .shadow(color: Theme.ink.opacity(0.10), radius: 6, y: 3)
    }

    private var face: some View {
        ZStack {
            // 纽扣眼睛(四孔小纽扣;眨眼时压扁)
            buttonEye.offset(x: -20, y: -4)
            buttonEye.offset(x: 20, y: -4)
            // 腮红
            Circle().fill(Theme.pink.opacity(0.55)).frame(width: 13, height: 13).offset(x: -33, y: 12)
            Circle().fill(Theme.pink.opacity(0.55)).frame(width: 13, height: 13).offset(x: 33, y: 12)
            // 缝出来的嘴
            mouth.offset(y: 16)
        }
    }

    private var buttonEye: some View {
        ZStack {
            Circle().fill(Color(hex: 0x6B4F3A))
            Circle().strokeBorder(Theme.ink.opacity(0.8), lineWidth: 1)
            // 四个线孔
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Theme.paper.opacity(0.8))
                    .frame(width: 1.8, height: 1.8)
                    .offset(x: i % 2 == 0 ? -2.4 : 2.4, y: i < 2 ? -2.4 : 2.4)
            }
        }
        .frame(width: 15, height: 15)
        .scaleEffect(y: blink ? 0.12 : 1, anchor: .center)
    }

    @ViewBuilder private var mouth: some View {
        switch expression {
        case .smiley:
            StitchArc(up: true)
                .stroke(Theme.ink.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3.5, 3]))
                .frame(width: 26, height: 12)
        case .quiet:
            Path { $0.move(to: CGPoint(x: 0, y: 1)); $0.addLine(to: CGPoint(x: 18, y: 1)) }
                .stroke(Theme.ink.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3.5, 3]))
                .frame(width: 18, height: 2)
        case .dozy:
            WavyMouth()
                .stroke(Theme.ink.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 24, height: 8)
        }
    }

    private var pocket: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fabric.accent.opacity(0.35))
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.paperWarm.opacity(0.6))
                )
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [4, 4]))
        }
        .frame(width: 52, height: 40)
    }

    /// 一小张被叠好的纸,从胸前落进兜里
    private var foldedPaper: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.paper)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.inkSoft.opacity(0.6), lineWidth: 1))
            .frame(width: 18, height: 13)
            .rotationEffect(.degrees(Double(paperPhase) * -16))
            .offset(y: 30 + paperPhase * 34)          // 从胸口上方落到兜口
            .opacity(paperPhase < 0.92 ? 1 : Double((1 - paperPhase) / 0.08))
            .scaleEffect(1 - paperPhase * 0.35)
    }

    private var hand: some View {
        ZStack {
            Circle().fill(.clear).background(FabricSwatch(fabric: fabric)).clipShape(Circle())
            Circle().strokeBorder(Theme.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [4, 4]))
        }
        .frame(width: 34, height: 34)
    }

    private var foot: some View {
        ZStack {
            Capsule().fill(.clear).background(FabricSwatch(fabric: fabric)).clipShape(Capsule())
            Capsule().strokeBorder(Theme.ink.opacity(0.5), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [4, 4]))
        }
        .frame(width: 40, height: 26)
    }

    // MARK: 动作

    /// 呼吸与眨眼(减少动态效果时全部安静下来)
    private func idleLoops() async {
        guard !reduceMotion else {
            breathe = false; blink = false
            return
        }
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathe = true
        }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64.random(in: 2_400...5_800) * 1_000_000)
            guard !Task.isCancelled else { break }
            withAnimation(.easeIn(duration: 0.07)) { blink = true }
            try? await Task.sleep(nanoseconds: 130_000_000)
            withAnimation(.easeOut(duration: 0.12)) { blink = false }
        }
    }

    /// 收下:认真点两下头,把纸叠进兜里
    private func receivedSequence() async {
        if reduceMotion {
            // 不动画,纸直接进兜
            paperPhase = 1
            try? await Task.sleep(nanoseconds: 400_000_000)
            paperPhase = 0
            return
        }
        for _ in 0..<2 {
            withAnimation(.easeInOut(duration: 0.28)) { nod = 5 }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.28)) { nod = 0 }
            try? await Task.sleep(nanoseconds: 320_000_000)
        }
        paperPhase = 0.01
        withAnimation(.easeInOut(duration: 1.1)) { paperPhase = 1 }
        try? await Task.sleep(nanoseconds: 1_250_000_000)
        paperPhase = 0
    }
}

// MARK: - 小形状

/// 一段缝线弧(嘴)
struct StitchArc: Shape {
    var up: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: up ? rect.minY + 2 : rect.maxY - 2))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: up ? rect.minY + 2 : rect.maxY - 2),
            control: CGPoint(x: rect.midX, y: up ? rect.maxY + 3 : rect.minY - 3))
        return p
    }
}

/// 呆呆的小波浪嘴(像缝歪了一点,但很可爱)
struct WavyMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.midY),
                       control: CGPoint(x: rect.width * 0.25, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                       control: CGPoint(x: rect.width * 0.75, y: rect.maxY))
        return p
    }
}

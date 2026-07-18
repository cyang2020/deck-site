import Foundation
import SwiftUI
import SwiftData

/// 花坛 · 「种一颗种子」纸抽屉。
///
/// 由园景模块以 `.sheet` 呈现:挑一包种子,说说今天心里的天气(可不说),
/// 写一句话(可不写),种进花坛的下一个空格。
/// 铁律:不催促、不评分;心情用天气,雨天没有好坏;一切可跳过。
public struct FlowerbedSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var seedLots: [SeedLot]
    @Query private var plants: [Plant]

    @State private var selectedKind: FlowerKind?
    @State private var selectedMood: MoodWeather?
    @State private var line = ""
    @State private var toastText: String?
    @State private var planted = false
    @State private var toastDismissal: Task<Void, Never>?

    /// 花坛一共六格(与园景场景一致)
    private static let slotCount = 6
    /// 一句话最多 40 字
    private static let lineLimit = 40

    public init() {}

    // MARK: - 视图

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                seedSection
                moodSection
                lineField
                actionRow
            }
            .padding(EdgeInsets(top: 24, leading: 20, bottom: 28, trailing: 20))
        }
        .scrollBounceBehavior(.basedOnSize)
        .tint(Theme.ink)
        .animation(.easeOut(duration: 0.15), value: selectedKind)
        .animation(.easeOut(duration: 0.15), value: selectedMood)
        .overlay(alignment: .top) { toastView }
        .sensoryFeedback(.impact(weight: .light), trigger: planted)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.cornerSheet)
        .presentationBackground(Theme.paper)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("种一颗种子")
                .font(Theme.kai(22, weight: .semibold))
                .kerning(3)
                .foregroundStyle(Theme.ink)
            Text("把今天种进土里。开什么样,随它。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(6)
        }
    }

    // MARK: 种子盒

    private var seedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("种子盒:")
            if packets.isEmpty {
                Text("种子盒空了。去邮筒看看,或者等下一个节气。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(6)
                    .padding(.vertical, 10)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(packets) { packet in
                            SeedPackCard(kind: packet.kind,
                                         count: packet.count,
                                         selected: selectedKind == packet.kind) {
                                selectedKind = packet.kind
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    /// 只列还有剩余的种子包,按 FlowerKind 的固定顺序
    private var packets: [SeedPacket] {
        FlowerKind.allCases.compactMap { kind in
            guard let lot = seedLots.first(where: { $0.kind == kind.rawValue }),
                  lot.count > 0 else { return nil }
            return SeedPacket(kind: kind, count: lot.count)
        }
    }

    // MARK: 心里的天气

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("今天的天气(你心里的):")
            HStack(spacing: 10) {
                ForEach(MoodWeather.allCases, id: \.self) { mood in
                    MoodChip(mood: mood, selected: selectedMood == mood) {
                        // 天气也可以不选;再点一下就收回
                        selectedMood = (selectedMood == mood) ? nil : mood
                    }
                }
            }
        }
    }

    // MARK: 一句话

    private var lineField: some View {
        TextField("一句话,也可以不说", text: $line)
            .font(Theme.kai(17))
            .foregroundStyle(Theme.ink)
            .submitLabel(.done)
            .padding(.vertical, 8)
            .background(alignment: .bottom) {
                DashedBaseline()
                    .stroke(Color(hex: 0xD9C9AE),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .frame(height: 2)
            }
            .onChange(of: line) { _, newValue in
                if newValue.count > Self.lineLimit {
                    line = String(newValue.prefix(Self.lineLimit))
                }
            }
    }

    // MARK: 种下去

    private var actionRow: some View {
        HStack {
            Button(action: plantSeed) {
                Text("种下去")
                    .font(Theme.kai(16))
                    .kerning(2)
                    .foregroundStyle(Color(hex: 0xFFF6E6))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 11)
                    .background(Theme.ink, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedKind == nil || planted)
            .opacity(selectedKind == nil || planted ? 0.35 : 1)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("先出去")
                    .font(Theme.kai(14))
                    .kerning(2)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 8)
                    .background(Theme.paper, in: Capsule())
                    .overlay { Capsule().strokeBorder(Theme.ink, lineWidth: 1.5) }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func plantSeed() {
        guard !planted, let kind = selectedKind else { return }
        guard let lot = seedLots.first(where: { $0.kind == kind.rawValue }),
              lot.count > 0 else { return }

        // 下一个空格;满了就先让它们开一会儿
        let taken = Set(plants.map(\.slot))
        guard let slot = (0..<Self.slotCount).first(where: { !taken.contains($0) }) else {
            showToast("花坛满了——先让它们开一会儿。")
            return
        }

        lot.count -= 1
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(Plant(kind: kind,
                                  mood: selectedMood,
                                  line: String(trimmed.prefix(Self.lineLimit)),
                                  slot: slot))
        try? modelContext.save()

        planted = true
        showToast("种下去了。急不来的,慢慢等。")
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
        }
    }

    // MARK: 小纸条提示

    @ViewBuilder private var toastView: some View {
        if let toastText {
            Text(toastText)
                .font(Theme.kai(14))
                .kerning(2)
                .foregroundStyle(Color(hex: 0xFFF6E6))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Theme.ink, in: Capsule())
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func showToast(_ text: String) {
        toastDismissal?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toastText = text }
        toastDismissal = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.35)) { toastText = nil }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.inkSoft)
    }
}

// MARK: - 种子包卡片

/// 种子盒里的一格
private struct SeedPacket: Identifiable {
    let kind: FlowerKind
    let count: Int
    var id: String { kind.rawValue }
}

private struct SeedPackCard: View {
    let kind: FlowerKind
    let count: Int
    let selected: Bool
    let action: () -> Void

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: .init(topLeading: 10,
                                                  bottomLeading: 14,
                                                  bottomTrailing: 14,
                                                  topTrailing: 10),
                               style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(kind.seedAsset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                Text(kind.label)
                    .font(Theme.kai(14))
                    .kerning(1)
                    .foregroundStyle(Theme.ink)
                Text("还有 \(count) 粒")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(width: 86)
            .background(Theme.paperWarm, in: shape)
            .overlay {
                shape.strokeBorder(selected ? Theme.ink : Color(hex: 0xE2D3B8),
                                   lineWidth: 2)
            }
            .shadow(color: selected ? Theme.ink : .clear, radius: 0, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(kind.label),还有 \(count) 粒")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 心情天气小卡

private struct MoodChip: View {
    let mood: MoodWeather
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                MoodIcon(mood: mood)
                Text(mood.label)
                    .font(Theme.kai(12))
                    .kerning(1)
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(selected ? Color(hex: 0xFFF2D9) : Theme.paperWarm,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.ink : Color(hex: 0xE2D3B8), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("心里的天气:\(mood.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 心情天气的小图标:太阳/云/雨云/雷云,全部用 SwiftUI 画出来(不用 emoji)。
/// 形状与 garden 网页原型的 34×34 图标一致。
private struct MoodIcon: View {
    let mood: MoodWeather
    var side: CGFloat = 34

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 34
            context.scaleBy(x: scale, y: scale)
            switch mood {
            case .sunny: Self.drawSunny(in: &context)
            case .cloudy: Self.drawCloudy(in: &context)
            case .rain: Self.drawRain(in: &context)
            case .storm: Self.drawStorm(in: &context)
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    private static let inkStroke = StrokeStyle(lineWidth: 2, lineCap: .round)

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat,
                                _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private static func drawSunny(in context: inout GraphicsContext) {
        var rays = Path()
        let segments: [[CGFloat]] = [
            [17, 2, 17, 6], [17, 28, 17, 32], [2, 17, 6, 17], [28, 17, 32, 17],
            [6.4, 6.4, 9.2, 9.2], [24.8, 24.8, 27.6, 27.6],
            [6.4, 27.6, 9.2, 24.8], [24.8, 9.2, 27.6, 6.4],
        ]
        for s in segments {
            rays.move(to: CGPoint(x: s[0], y: s[1]))
            rays.addLine(to: CGPoint(x: s[2], y: s[3]))
        }
        context.stroke(rays, with: .color(Theme.ink), style: inkStroke)
        let disc = ellipse(17, 17, 8, 8)
        context.fill(disc, with: .color(Theme.butter))
        context.stroke(disc, with: .color(Theme.ink), style: inkStroke)
    }

    private static func drawCloudy(in context: inout GraphicsContext) {
        let sun = ellipse(12, 13, 6, 6)
        context.fill(sun, with: .color(Theme.butter))
        context.stroke(sun, with: .color(Theme.ink), style: inkStroke)
        for cloud in [ellipse(19, 20, 10, 6.5), ellipse(11, 22, 7, 5)] {
            context.fill(cloud, with: .color(Theme.paper))
            context.stroke(cloud, with: .color(Theme.ink), style: inkStroke)
        }
    }

    private static func drawRain(in context: inout GraphicsContext) {
        let cloud = ellipse(17, 13, 11, 7)
        context.fill(cloud, with: .color(Theme.paper))
        context.stroke(cloud, with: .color(Theme.ink), style: inkStroke)
        var drops = Path()
        let xs: [CGFloat] = [10, 17, 24]
        for x in xs {
            drops.move(to: CGPoint(x: x, y: 24))
            drops.addLine(to: CGPoint(x: x - 2, y: 29))
        }
        context.stroke(drops, with: .color(Color(hex: 0x7FA8C9)),
                       style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private static func drawStorm(in context: inout GraphicsContext) {
        let cloud = ellipse(17, 12, 11, 7)
        context.fill(cloud, with: .color(Color(hex: 0xD8D2C2)))
        context.stroke(cloud, with: .color(Theme.ink), style: inkStroke)
        var bolt = Path()
        bolt.move(to: CGPoint(x: 16, y: 20))
        bolt.addLine(to: CGPoint(x: 12, y: 27))
        bolt.addLine(to: CGPoint(x: 17, y: 27))
        bolt.addLine(to: CGPoint(x: 14, y: 34))
        bolt.addLine(to: CGPoint(x: 22, y: 25))
        bolt.addLine(to: CGPoint(x: 17, y: 25))
        bolt.addLine(to: CGPoint(x: 20, y: 20))
        bolt.closeSubpath()
        context.fill(bolt, with: .color(Color(hex: 0xF3C34E)))
        context.stroke(bolt, with: .color(Theme.ink),
                       style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
    }
}

/// 输入框下面那条虚线
private struct DashedBaseline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

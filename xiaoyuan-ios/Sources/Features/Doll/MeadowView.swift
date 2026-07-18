import SwiftUI
import SwiftData

// MARK: - 屋后的花田

/// 花田:每一朵花,都是一个"后来没事了"的烦恼。
/// 点一朵,只看到放下的日期和一句"后来没事了。"——原话默认不再翻出来。
public struct MeadowView: View {
    public init() {}

    @Query(sort: \Worry.releasedAt) private var allWorries: [Worry]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Worry?

    private var released: [Worry] {
        allWorries.filter { $0.state == WorryState.released.rawValue && $0.releasedAt != nil }
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.cream, Color(hex: 0xEAF2E0)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if released.isEmpty {
                    Spacer()
                    Text("田先空着,不急。")
                        .font(Theme.kai(15))
                        .foregroundStyle(Theme.inkSoft.opacity(0.8))
                    Spacer()
                } else {
                    ScrollView {
                        field
                            .padding(.top, 18)
                            .padding(.bottom, 30)
                    }
                    .scrollIndicators(.hidden)
                }
                footer
            }

            if let worry = selected {
                flowerNote(worry)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selected != nil)
    }

    // MARK: 上与下

    private var header: some View {
        ZStack {
            Text("屋后的花田")
                .font(Theme.kai(19, weight: .medium))
                .foregroundStyle(Theme.ink)
            HStack {
                Spacer()
                Button("回屋") { dismiss() }
                    .font(Theme.kai(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("每一朵,都是一个后来没事了的烦恼。")
                .font(Theme.kai(13))
                .foregroundStyle(Theme.inkSoft.opacity(0.9))
            // 藏在角落的一行小字:不弹窗,不链接,只是放在这里
            Text("如果最近总是雷阵雨,也可以找专业的人聊聊。")
                .font(Theme.kai(11))
                .foregroundStyle(Theme.inkSoft.opacity(0.55))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }

    // MARK: 田

    private var field: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(released.enumerated()), id: \.offset) { index, worry in
                    let spot = flowerSpot(index: index, worry: worry, width: geo.size.width)
                    Button {
                        selected = worry
                    } label: {
                        FeltFlower(color: monthColor(of: worry.createdAt), seed: spot.seed)
                    }
                    .buttonStyle(.plain)
                    .position(spot.point)
                    .accessibilityLabel("一朵花")
                }
            }
        }
        .frame(height: fieldHeight)
    }

    private var fieldHeight: CGFloat {
        let rows = max(1, Int(ceil(Double(released.count) / 3.0)))
        return CGFloat(rows) * 108 + 40
    }

    /// 三朵一行,位置带一点确定性的散落(重开 App 也长在原地)
    private func flowerSpot(index: Int, worry: Worry, width: CGFloat) -> (point: CGPoint, seed: UInt64) {
        let seed = UInt64(bitPattern: Int64(worry.createdAt.timeIntervalSince1970.rounded()))
        var rng = SeededRandom(seed: seed)
        let col = index % 3, row = index / 3
        let cellW = max(1, (width - 48) / 3)
        let x = 24 + cellW * CGFloat(col) + cellW * (0.28 + rng.next() * 0.44)
        let y = 30 + CGFloat(row) * 108 + rng.next() * 34
        return (CGPoint(x: x, y: y), seed)
    }

    /// 花色跟着种下那个月走(毛毡色,四季各有偏向)
    private func monthColor(of date: Date) -> Color {
        let month = Calendar.current.component(.month, from: date)
        let hexes: [UInt32] = [
            0xB9C8E8, // 1 冬·雾蓝
            0xD8C8E4, // 2 冬·浅藤
            0xF2BFD4, // 3 春·桃粉
            0xEFB6B2, // 4 春·豆沙
            0xF6C6A8, // 5 春·杏
            0xFFD98A, // 6 夏·黄油
            0xF2A65E, // 7 夏·橙
            0xE8938C, // 8 夏·石榴
            0xD98A6A, // 9 秋·陶土
            0xC97F5E, // 10 秋·赭
            0xB08968, // 11 秋·栗
            0xA9B8D8, // 12 冬·霜蓝
        ]
        return Color(hex: hexes[(month - 1 + 12) % 12])
    }

    // MARK: 点一朵

    private func flowerNote(_ worry: Worry) -> some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()
                .onTapGesture { selected = nil }
            VStack(spacing: 12) {
                FeltFlower(color: monthColor(of: worry.createdAt),
                           seed: UInt64(bitPattern: Int64(worry.createdAt.timeIntervalSince1970.rounded())))
                    .scaleEffect(1.2)
                    .frame(height: 66)
                if let date = worry.releasedAt {
                    Text(Self.zhDate.string(from: date))
                        .font(Theme.kai(14))
                        .foregroundStyle(Theme.inkSoft)
                }
                Text("后来没事了。")
                    .font(Theme.kai(18))
                    .foregroundStyle(Theme.ink)
                Button("嗯") { selected = nil }
                    .font(Theme.kai(15))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, 2)
            }
            .padding(26)
            .frame(maxWidth: 260)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerSheet, style: .continuous)
                    .fill(Theme.paper)
                    .shadow(color: Theme.ink.opacity(0.15), radius: 16, y: 6)
            )
        }
    }

    private static let zhDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f
    }()
}

// MARK: - 一朵毛毡花

/// 纯 SwiftUI 小毡花:几瓣圆瓣 + 绒芯 + 茎叶。seed 决定瓣数与歪头角度。
struct FeltFlower: View {
    let color: Color
    let seed: UInt64

    private var petalCount: Int { 5 + Int(seed % 2) }        // 5 或 6 瓣
    private var tilt: Double { Double(Int(seed % 17)) - 8 }  // -8°..8° 歪一点

    var body: some View {
        VStack(spacing: -4) {
            ZStack {
                ForEach(0..<petalCount, id: \.self) { i in
                    let angle = Double(i) / Double(petalCount) * 2 * .pi
                    Circle()
                        .fill(color)
                        .overlay(Circle().stroke(Theme.ink.opacity(0.18), lineWidth: 1))
                        .frame(width: 16, height: 16)
                        .offset(x: cos(angle) * 10, y: sin(angle) * 10)
                }
                Circle()
                    .fill(Theme.butter)
                    .overlay(Circle().stroke(Theme.ink.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 2])))
                    .frame(width: 13, height: 13)
            }
            .frame(width: 40, height: 40)
            .rotationEffect(.degrees(tilt))
            // 茎与一片小叶
            ZStack(alignment: .top) {
                Capsule().fill(Theme.leaf).frame(width: 3, height: 26)
                Ellipse()
                    .fill(Theme.sage)
                    .frame(width: 12, height: 7)
                    .rotationEffect(.degrees(-38))
                    .offset(x: 8, y: 12)
            }
        }
        .frame(width: 48, height: 72)
    }
}

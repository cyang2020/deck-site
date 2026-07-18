import SwiftUI
import SwiftData

/// 花房:照片做成小卡,用木夹晾在绳上。整个模块的唯一入口。
public struct GreenhouseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PhotoCard.createdAt, order: .reverse) private var cards: [PhotoCard]

    @State private var showNewPhoto = false
    @State private var selectedCard: PhotoCard?
    @State private var toastText: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                wall
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            bottomBar
        }
        .background(Theme.paper)
        .overlay(alignment: .top) { GreenhouseToast(text: toastText) }
        .sensoryFeedback(.impact(weight: .light), trigger: toastText) { _, new in new != nil }
        .task(id: toastText) { await autoHideToast() }
        .sheet(isPresented: $showNewPhoto) {
            NewPhotoFlow { celebrateHang() }
        }
        .sheet(item: $selectedCard) { card in
            CardDetailView(card: card)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.cornerSheet)
        .presentationBackground(Theme.paper)
    }

    // MARK: - 头

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("花房")
                .font(Theme.kai(22, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Theme.ink)
            Text("照片晾在这里。只有你会看到。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 10)
    }

    // MARK: - 照片墙(每根绳晾三张)

    private var rows: [[PhotoCard]] {
        stride(from: 0, to: cards.count, by: 3).map {
            Array(cards[$0 ..< min($0 + 3, cards.count)])
        }
    }

    private var wall: some View {
        VStack(spacing: 0) {
            if cards.isEmpty {
                emptyWall
            } else {
                ForEach(rows.indices, id: \.self) { r in
                    WireRowView(cards: rows[r], firstIndex: r * 3) { selectedCard = $0 }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 18)
        .background(Theme.paperWarm, in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyWall: some View {
        VStack(spacing: 24) {
            WireView()
                .padding(.top, 32)
                .padding(.horizontal, 4)
            Text("绳子还空着。第一张,晾什么都好。")
                .font(Theme.kai(14))
                .tracking(2)
                .foregroundStyle(GreenhousePalette.hint)
                .padding(.bottom, 14)
        }
    }

    // MARK: - 底部

    private var bottomBar: some View {
        HStack {
            Button("晾一张新照片") { showNewPhoto = true }
                .buttonStyle(GreenhouseButtonStyle(fill: true))
            Spacer()
            Button("先出去") { dismiss() }
                .buttonStyle(GreenhouseButtonStyle(small: true))
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    // MARK: - 夹好之后

    private func celebrateHang() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))   // 等晾照片的抽屉先合上
            toastText = "嗒——夹好了。"
        }
    }

    private func autoHideToast() async {
        guard toastText != nil else { return }
        do {
            try await Task.sleep(for: .seconds(2.2))
            toastText = nil
        } catch {}   // 被新提示打断就不动它
    }
}

// MARK: - 一根绳 + 挂着的卡

private struct WireRowView: View {
    let cards: [PhotoCard]          // 至多三张
    let firstIndex: Int             // 在整面墙里的起始序号(算旋转抖动用)
    let onTap: (PhotoCard) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            WireView()
                .padding(.horizontal, 2)
            HStack(alignment: .top, spacing: 12) {
                ForEach(cards.indices, id: \.self) { i in
                    Button { onTap(cards[i]) } label: {
                        HungCardView(card: cards[i])
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees(Double((firstIndex + i) % 3 - 1) * 2),
                                    anchor: .top)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, 10)     // 卡顶落在绳下,木夹正好咬住绳
        }
        .padding(.top, 26)
    }
}

/// 挂在墙上的小卡:纸样 + 木夹 + 蜡封
private struct HungCardView: View {
    let card: PhotoCard

    var body: some View {
        PaperCardFace(paper: PaperStyle(rawValue: card.paper) ?? .polaroid,
                      caption: card.caption,
                      sealed: card.sealed,
                      side: 88) {
            StoredImageView(path: card.imagePath, maxPixel: 260)
        }
        .overlay(alignment: .top) { WoodClipView().offset(y: -12) }
    }
}

// MARK: - 花房共用的小物件(本目录内几个视图一起用)

/// 花房专用“实物色”:木夹、铁丝、胶片、蜡……
/// Theme 是全局毡布色;这些是道具本身的颜色,集中放在这里,不散落。
enum GreenhousePalette {
    static let wire          = Color(hex: 0xB9A488)   // 铁丝
    static let clipWood      = Color(hex: 0xC68A5B)   // 木夹
    static let polaroidPaper = Color(hex: 0xFFFEFA)   // 拍立得相纸
    static let cardEdge      = Color(hex: 0xE7DCC8)   // 卡纸描边
    static let captionInk    = Color(hex: 0x6B5847)   // 相纸上的小字
    static let filmDark      = Color(hex: 0x3B3630)   // 胶片底
    static let filmHole      = Color(hex: 0xFFF9EA)   // 齿孔
    static let filmInk       = Color(hex: 0xD8CBB5)   // 胶片上的浅字
    static let backPaper     = Color(hex: 0xFBF3E2)   // 背面的暖纸
    static let hint          = Color(hex: 0xB7A489)   // 极轻的提示字
    static let underline     = Color(hex: 0xD9C9AE)   // 虚线书写线
    static let waxHi         = Color(hex: 0xE89A8B)   // 蜡封高光
    static let waxLo         = Color(hex: 0xC05B4D)   // 蜡封深处
    static let waxInk        = Color(hex: 0xFFF0E0)   // 蜡封上的“封”
}

extension View {
    /// 纸园按钮的胶囊外衣(PhotosPicker 的 label 也能直接穿)
    func greenhousePill(fill: Bool = false, small: Bool = false, dashed: Bool = false) -> some View {
        self
            .font(Theme.kai(small ? 14 : 16))
            .tracking(2)
            .foregroundStyle(fill ? Theme.cream : Theme.ink)
            .padding(.horizontal, small ? 16 : 22)
            .padding(.vertical, small ? 7 : 10)
            .background(fill ? Theme.ink : GreenhousePalette.polaroidPaper, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Theme.ink.opacity(fill ? 0 : 1),
                                       style: StrokeStyle(lineWidth: small ? 1.5 : 2,
                                                          dash: dashed ? [5, 4] : []))
            }
    }
}

struct GreenhouseButtonStyle: ButtonStyle {
    var fill: Bool
    var small: Bool
    var dashed: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(fill: Bool = false, small: Bool = false, dashed: Bool = false) {
        self.fill = fill
        self.small = small
        self.dashed = dashed
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .greenhousePill(fill: fill, small: small, dashed: dashed)
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 晾衣绳:两端钉着小圆钉
struct WireView: View {
    var body: some View {
        ZStack {
            Capsule().fill(GreenhousePalette.wire).frame(height: 2)
            HStack {
                Circle().fill(GreenhousePalette.wire).frame(width: 9, height: 9)
                Spacer()
                Circle().fill(GreenhousePalette.wire).frame(width: 9, height: 9)
            }
        }
        .frame(height: 9)
    }
}

/// 小木夹
struct WoodClipView: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 4,
                               bottomLeadingRadius: 2,
                               bottomTrailingRadius: 2,
                               topTrailingRadius: 4)
            .fill(GreenhousePalette.clipWood)
            .frame(width: 12, height: 20)
            .overlay {
                Rectangle()
                    .fill(Theme.ink.opacity(0.18))
                    .frame(width: 8, height: 1)
                    .offset(y: 2)   // 夹缝
            }
            .shadow(color: .black.opacity(0.15), radius: 0.5, y: 1)
    }
}

/// 胶片齿孔一排
struct FilmSprocketsView: View {
    var count = 8
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0 ..< count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(GreenhousePalette.filmHole)
                    .frame(width: 4.5, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 小蜡封:一粒红蜡,按着一个“封”字
struct WaxSealView: View {
    var size: CGFloat = 22
    var body: some View {
        ZStack {
            Circle().fill(
                RadialGradient(colors: [GreenhousePalette.waxHi, GreenhousePalette.waxLo],
                               center: UnitPoint(x: 0.35, y: 0.35),
                               startRadius: size * 0.05,
                               endRadius: size * 0.62)
            )
            Text("封")
                .font(Theme.kai(size * 0.5))
                .foregroundStyle(GreenhousePalette.waxInk)
        }
        .frame(width: size, height: size)
        .shadow(color: Color(hex: 0x782820).opacity(0.4), radius: 2, y: 1)
    }
}

/// 通用小卡正面(墙上的 88pt 小卡、晾照片时的 150pt 预览都用它)
struct PaperCardFace<Photo: View>: View {
    var paper: PaperStyle
    var caption: String = ""
    var sealed = false
    var side: CGFloat
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        card
            .overlay(alignment: .bottomTrailing) {
                if sealed {
                    WaxSealView(size: max(18, side * 0.25))
                        .offset(x: side * 0.07, y: -side * 0.11)
                }
            }
    }

    @ViewBuilder private var card: some View {
        switch paper {
        case .polaroid:
            VStack(spacing: 3) {
                photoBox
                Text(caption.isEmpty ? " " : caption)
                    .font(Theme.kai(max(9, side * 0.115)))
                    .foregroundStyle(GreenhousePalette.captionInk)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .padding(side * 0.07)
            .padding(.bottom, side * 0.09)
            .background(GreenhousePalette.polaroidPaper, in: RoundedRectangle(cornerRadius: 3))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(GreenhousePalette.cardEdge, lineWidth: 1)
            }
            .shadow(color: Theme.ink.opacity(0.18), radius: 4, y: 3)
        case .film:
            VStack(spacing: 3) {
                FilmSprocketsView(count: max(5, Int(side / 11)))
                photoBox
                FilmSprocketsView(count: max(5, Int(side / 11)))
            }
            .padding(.vertical, 4)
            .padding(.horizontal, side * 0.06)
            .background(GreenhousePalette.filmDark, in: RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 3)
        }
    }

    private var photoBox: some View {
        photo()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

/// 顶部一句轻轻的话(“嗒——夹好了。”这类),自己滑进滑出
struct GreenhouseToast: View {
    let text: String?
    var body: some View {
        Group {
            if let text {
                Text(text)
                    .font(Theme.kai(14))
                    .tracking(2)
                    .foregroundStyle(Theme.cream)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Theme.ink, in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: text)
    }
}

#Preview {
    GreenhouseSheet()
        .modelContainer(for: PhotoCard.self, inMemory: true)
}

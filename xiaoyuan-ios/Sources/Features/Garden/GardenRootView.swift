import SwiftUI

/// 园中各处。点到哪里,就从哪里打开一张纸质抽屉。
enum GardenPlace: String, Identifiable {
    case greenhouse   // 花房:照片日记
    case flowerbed    // 花坛:种一颗种子
    case mailbox      // 邮筒:节气的种子与信
    case dollhouse    // 小屋:布娃娃

    var id: String { rawValue }
}

/// App 根视图:天空铺底,园景可横向漫步;
/// 右上「俯瞰」或双指一捏,切到 3D 立体书;各处点开对应的纸质抽屉。
struct GardenRootView: View {
    @StateObject private var ambience = Ambience()
    @Environment(\.scenePhase) private var scenePhase

    @State private var activePlace: GardenPlace?
    @State private var showOverview = false
    @State private var absenceLine: String?

    private static let lastVisitKey = "garden.lastVisitAt"

    var body: some View {
        ZStack {
            SkyView(ambience: ambience)
                .ignoresSafeArea()
            GardenSceneView(ambience: ambience,
                            onOpen: { activePlace = $0 },
                            onPinchOverview: toggleOverview)
                .ignoresSafeArea()
                .opacity(showOverview ? 0 : 1)
                .scaleEffect(showOverview ? 1.05 : 1)
                .allowsHitTesting(!showOverview)
            if showOverview {
                OverviewDioramaView(phase: ambience.phase,
                                    onOpen: { activePlace = $0 })
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
            }
        }
        .overlay(alignment: .topLeading) { dateChip }
        .overlay(alignment: .topTrailing) { overviewChip }
        .overlay(alignment: .bottom) { absenceNote }
        .sheet(item: $activePlace) { place in
            placeSheet(place)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { ambience.refresh() }
        }
        .onAppear(perform: noteVisit)
    }

    // MARK: - 抽屉(纸质、整张)

    @ViewBuilder
    private func placeSheet(_ place: GardenPlace) -> some View {
        Group {
            switch place {
            case .greenhouse: GreenhouseSheet()
            case .flowerbed: FlowerbedSheet()
            case .mailbox: MailboxSheet()
            case .dollhouse: DollHouseSheet()
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.cornerSheet)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.paper)
    }

    // MARK: - 角上的小章

    private var dateChip: some View {
        PaperChip(text: ambience.dateLine, night: ambience.phase == .night)
            .padding(.top, 12)
            .padding(.leading, 14)
            .allowsHitTesting(false)
    }

    private var overviewChip: some View {
        Button(action: toggleOverview) {
            PaperChip(text: showOverview ? "回到园中" : "俯瞰",
                      night: ambience.phase == .night)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 14)
    }

    private func toggleOverview() {
        withAnimation(.easeInOut(duration: 0.5)) { showOverview.toggle() }
    }

    // MARK: - 隔了很久回来,只有一句轻轻的话

    private var absenceNote: some View {
        Group {
            if let line = absenceLine {
                Text(line)
                    .font(Theme.kai(15))
                    .tracking(2)
                    .foregroundStyle(ambience.phase == .night ? Color(hex: 0xD8D2C2) : Theme.inkSoft)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 18)
                    .background(
                        Capsule().fill((ambience.phase == .night ? Theme.nightHi : Theme.paper)
                            .opacity(0.72))
                    )
                    .transition(.opacity)
            }
        }
        .padding(.bottom, 74)
        .allowsHitTesting(false)
    }

    private func noteVisit() {
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: Self.lastVisitKey) as? Date
        defaults.set(Date.now, forKey: Self.lastVisitKey)
        guard let last, Date.now.timeIntervalSince(last) >= 7 * 86_400 else { return }
        withAnimation(.easeInOut(duration: 1.6).delay(1.2)) {
            absenceLine = "你不在的时候,风替你浇了水。"
        }
        Task {
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            withAnimation(.easeInOut(duration: 1.6)) { absenceLine = nil }
        }
    }
}

// MARK: - 纸片小章(左上日期、右上俯瞰共用)

private struct PaperChip: View {
    let text: String
    var night = false

    var body: some View {
        Text(text)
            .font(Theme.kai(15))
            .tracking(2)
            .foregroundStyle(night ? Color(hex: 0xF2E9D8) : Theme.ink)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                chipShape.fill(night ? Theme.nightHi.opacity(0.55) : Theme.paper.opacity(0.85))
            )
            .overlay(
                chipShape.stroke(night ? Color(hex: 0xF2E9D8).opacity(0.4) : Theme.ink.opacity(0.35),
                                 lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 2), value: night)
    }

    private var chipShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 4,
                               bottomLeadingRadius: 14,
                               bottomTrailingRadius: 4,
                               topTrailingRadius: 14)
    }
}

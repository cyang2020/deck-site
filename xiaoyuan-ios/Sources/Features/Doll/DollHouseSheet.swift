import SwiftUI
import SwiftData

// MARK: - 小屋(灯下)

/// 小屋内景:一盏灯、一张小床、坐着的娃娃。
/// 没缝过娃娃 → 先进初见缝制;有了 → 房间。
/// 一次 app-open 至多轻轻问一次(卡片浮在房里,不叠、不跳页)。
/// 点灯 = 晚安:屋子慢慢暗下来,"今天到这儿,交给我了。",然后自己合上。
public struct DollHouseSheet: View {
    public init() {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var profiles: [DollProfile]
    @Query(sort: \Worry.createdAt) private var allWorries: [Worry]

    @State private var showCapture = false
    @State private var showMeadow = false
    @State private var askWorry: Worry?
    @State private var goodnight = false

    private var heldDue: Worry? {
        allWorries
            .filter { $0.dueForGentleAsk() }
            .min { $0.createdAt < $1.createdAt }
    }

    public var body: some View {
        ZStack {
            if let profile = profiles.first {
                room(profile)
            } else {
                SewDollFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: profiles.isEmpty)
        .onChange(of: scenePhase) { _, phase in
            // 退到后台再回来,算新的一次打开
            if phase == .background { GentleAskGate.shownThisOpen = false }
        }
    }

    // MARK: 房间

    private func room(_ profile: DollProfile) -> some View {
        ZStack {
            roomBackground

            VStack(spacing: 0) {
                lamp
                    .padding(.top, 6)
                Spacer(minLength: 6)

                Text(profile.name)
                    .font(Theme.kai(17))
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .padding(.bottom, 2)

                ZStack(alignment: .bottom) {
                    // 小床(它睡这儿,烦恼睡枕头底下)
                    bed.offset(x: -108, y: 6)
                    // 通向花田的小门
                    meadowDoor.offset(x: 128, y: 0)
                    DollView(fabricIndex: profile.fabric,
                             expressionIndex: profile.expression,
                             reaction: goodnight ? .companion : .idle,
                             scale: 0.9)
                    // 地毯
                    Ellipse()
                        .fill(Theme.terra.opacity(0.18))
                        .frame(width: 250, height: 44)
                        .offset(y: 24)
                        .zIndex(-1)
                }
                .frame(height: 270)

                Spacer(minLength: 10)

                if !goodnight {
                    Button {
                        showCapture = true
                    } label: {
                        Text("把烦恼给它")
                            .font(Theme.kai(17, weight: .medium))
                            .foregroundStyle(Theme.paper)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 13)
                            .background(Capsule().fill(Theme.terra))
                            .overlay(Capsule().strokeBorder(Theme.paper.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 34)
                }
            }
            .padding(.horizontal, 20)

            // 熄灯的暗与那句话
            nightOverlay

            // 轻轻问(至多一张,浮在房里)
            if let worry = askWorry {
                gentleAskOverlay(worry, dollName: profile.name)
            }
        }
        .sheet(isPresented: $showCapture) {
            WorryCaptureView(profile: profile)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showMeadow) {
            MeadowView()
        }
        .task { await maybeGentleAsk() }
    }

    private var roomBackground: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF6E3C2), Theme.paperWarm],
                           startPoint: .top, endPoint: .bottom)
            // 灯光晕
            RadialGradient(colors: [Theme.butter.opacity(0.55), .clear],
                           center: .init(x: 0.5, y: 0.16),
                           startRadius: 10, endRadius: 300)
            // 木地板一条
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(hex: 0xE0C39A).opacity(0.6))
                    .frame(height: 120)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: 灯(点它 = 晚安)

    private var lamp: some View {
        Button {
            beginGoodnight()
        } label: {
            VStack(spacing: 0) {
                Rectangle().fill(Theme.ink.opacity(0.5)).frame(width: 2, height: 26)
                ZStack {
                    // 灯罩
                    LampShade()
                        .fill(Theme.pink.opacity(0.85))
                        .overlay(LampShade().stroke(Theme.ink.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.6, dash: [4, 4])))
                        .frame(width: 64, height: 38)
                    // 灯泡的一点亮
                    Circle()
                        .fill(Theme.butter.opacity(goodnight ? 0.15 : 0.95))
                        .frame(width: 12, height: 12)
                        .offset(y: 24)
                        .blur(radius: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(goodnight || askWorry != nil)
        .accessibilityLabel("灯。点一下,今天就到这儿。")
    }

    // MARK: 小床

    private var bed: some View {
        VStack(spacing: -6) {
            // 枕头
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Theme.paper)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.3, dash: [3, 3])))
                .frame(width: 40, height: 18)
                .offset(x: -14)
            // 被子
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.sage.opacity(0.75))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1.6, dash: [5, 4])))
                .frame(width: 92, height: 34)
            // 床板
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: 0xC9A176))
                .frame(width: 104, height: 10)
        }
        .accessibilityHidden(true)
    }

    // MARK: 屋后的门 → 花田

    private var meadowDoor: some View {
        Button {
            showMeadow = true
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottom) {
                    // 门洞
                    UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26)
                        .fill(Color(hex: 0xC9A176).opacity(0.9))
                        .frame(width: 54, height: 84)
                    UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                        .fill(LinearGradient(colors: [Color(hex: 0xEAF2E0), Theme.sage.opacity(0.7)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 44, height: 74)
                    // 门外探进来的一朵小花
                    Circle().fill(Theme.pink).frame(width: 8, height: 8).offset(x: 8, y: -12)
                    Capsule().fill(Theme.leaf).frame(width: 2, height: 10).offset(x: 8, y: -4)
                }
                Text("屋后的花田")
                    .font(Theme.kai(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .disabled(goodnight)
    }

    // MARK: 轻轻问

    private func maybeGentleAsk() async {
        guard !GentleAskGate.shownThisOpen else { return }
        try? await Task.sleep(nanoseconds: 1_400_000_000)
        guard !Task.isCancelled, askWorry == nil,
              !showCapture, !showMeadow, !goodnight else { return }
        guard let due = heldDue else { return }
        GentleAskGate.shownThisOpen = true
        withAnimation(.easeInOut(duration: 0.35)) { askWorry = due }
    }

    private func gentleAskOverlay(_ worry: Worry, dollName: String) -> some View {
        ZStack {
            Color.black.opacity(0.14).ignoresSafeArea()
            GentleAskCard(worry: worry, dollName: dollName) {
                withAnimation(.easeInOut(duration: 0.3)) { askWorry = nil }
            }
            .padding(.horizontal, 30)
        }
        .transition(.opacity)
    }

    // MARK: 晚安

    private var nightOverlay: some View {
        ZStack {
            Theme.nightHi
                .opacity(goodnight ? 0.86 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(goodnight)
            if goodnight {
                Text("今天到这儿,交给我了。")
                    .font(Theme.kai(20))
                    .foregroundStyle(Theme.paper.opacity(0.92))
                    .transition(.opacity)
            }
        }
    }

    private func beginGoodnight() {
        guard !goodnight else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.5) : .easeInOut(duration: 3.0)) {
            goodnight = true
        }
        Task {
            try? await Task.sleep(nanoseconds: reduceMotion ? 2_200_000_000 : 4_600_000_000)
            dismiss()
        }
    }
}

/// 灯罩(上窄下宽的小梯形,边缘圆一点)
struct LampShade: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.30, y: 0))
        p.addLine(to: CGPoint(x: w * 0.70, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: h), control: CGPoint(x: w * 0.92, y: h * 0.5))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.86), control: CGPoint(x: w * 0.75, y: h * 0.98))
        p.addQuadCurve(to: CGPoint(x: 0, y: h), control: CGPoint(x: w * 0.25, y: h * 0.98))
        p.addQuadCurve(to: CGPoint(x: w * 0.30, y: 0), control: CGPoint(x: w * 0.08, y: h * 0.5))
        p.closeSubpath()
        return p
    }
}

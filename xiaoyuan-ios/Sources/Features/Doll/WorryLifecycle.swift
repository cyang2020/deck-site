import SwiftUI
import SwiftData
import AVFoundation

// MARK: - 每次打开 App,至多轻轻问一次

/// 轻问的闸门:一次 app-open 只问一个,永不叠、永不追。
/// 退到后台再回来算新的一次(由小屋在 scenePhase 里重置)。
@MainActor
enum GentleAskGate {
    static var shownThisOpen = false
}

// MARK: - 语音回放(封着的那段话)

@MainActor
final class VoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    func toggle(relativePath: String) {
        if isPlaying { stop(); return }
        let url = WorryAudioStore.url(forRelativePath: relativePath)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.play()
            player = p
            isPlaying = true
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}

// MARK: - 纸船

/// 折好的小纸船(船身 + 小帆)
struct PaperBoatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // 船身:上宽下窄
        p.move(to: CGPoint(x: 0, y: h * 0.55))
        p.addLine(to: CGPoint(x: w, y: h * 0.55))
        p.addLine(to: CGPoint(x: w * 0.78, y: h))
        p.addLine(to: CGPoint(x: w * 0.22, y: h))
        p.closeSubpath()
        // 帆:中间一只小三角
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.28, y: h * 0.5))
        p.closeSubpath()
        return p
    }
}

/// 会漂的纸船(放下时用)
struct PaperBoatView: View {
    var body: some View {
        PaperBoatShape()
            .fill(Theme.paper)
            .overlay(
                PaperBoatShape().stroke(Theme.inkSoft.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            )
            .frame(width: 46, height: 30)
            .shadow(color: Theme.ink.opacity(0.10), radius: 3, y: 2)
    }
}

// MARK: - 轻轻问一次

/// 娃娃隔了些日子,轻轻问一次:"上次你给我的那个,还沉吗?"
/// 还沉 → "那我继续拿着。"(记下 lastAskedAt,永不追问)
/// 不沉了 → 折成纸船漂走,花田会多一朵花(state → released)。
struct GentleAskCard: View {
    let worry: Worry
    let dollName: String
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var voice = VoicePlayer()

    private enum Phase { case asking, keeping, releasing }
    @State private var phase: Phase = .asking
    @State private var boatDrift: CGFloat = 0     // 0 在原地 → 1 漂出画面
    @State private var cardFolded = false

    /// 卡片随时间褪色:第 7 天起从 0.95 淡到 30 天后的 0.4
    private var fadedOpacity: Double {
        let days = Date.now.timeIntervalSince(worry.createdAt) / 86_400
        return min(0.95, max(0.4, 0.95 - (days - 7) * 0.024))
    }

    var body: some View {
        VStack(spacing: 18) {
            switch phase {
            case .asking:    askingContent
            case .keeping:   line("那我继续拿着。")
            case .releasing: releasingContent
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerSheet, style: .continuous)
                .fill(Theme.paper)
                .shadow(color: Theme.ink.opacity(0.16), radius: 18, y: 8)
        )
        .onDisappear { voice.stop() }
    }

    // MARK: 问

    private var askingContent: some View {
        VStack(spacing: 18) {
            worryToken
            Text("上次你给我的那个,还沉吗?")
                .font(Theme.kai(18))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 14) {
                choiceButton("还沉", fill: Theme.paperWarm, textColor: Theme.ink) { keep() }
                choiceButton("不沉了", fill: Theme.sage, textColor: Theme.paper) { release() }
            }
        }
    }

    /// 那个烦恼:文字(已褪色)或一段封着的话(可以听,不转文字)
    @ViewBuilder private var worryToken: some View {
        Group {
            if let text = worry.text, !text.isEmpty {
                Text(text)
                    .font(Theme.kai(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let path = worry.audioPath {
                Button {
                    voice.toggle(relativePath: path)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: voice.isPlaying ? "pause.circle" : "play.circle")
                            .font(.system(size: 20))
                        Text("一段你说过的话")
                            .font(Theme.kai(15))
                    }
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                Text("那天的一小件事")
                    .font(Theme.kai(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous)
                .fill(Theme.paperWarm.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.12), style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
        )
        .opacity(fadedOpacity)
        .rotation3DEffect(.degrees(cardFolded ? 88 : 0), axis: (x: 1, y: 0, z: 0), anchor: .top)
    }

    // MARK: 还沉

    private func keep() {
        worry.lastAskedAt = .now
        withAnimation(.easeInOut(duration: 0.3)) { phase = .keeping }
        Task {
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            onClose()
        }
    }

    // MARK: 不沉了 → 纸船

    private var releasingContent: some View {
        VStack(spacing: 16) {
            ZStack {
                // 一道浅浅的水
                Capsule()
                    .fill(Color(hex: 0xBFD8E8).opacity(0.5))
                    .frame(height: 10)
                    .offset(y: 20)
                PaperBoatView()
                    .offset(x: boatDrift * 190, y: sin(boatDrift * .pi * 3) * 3)
                    .opacity(1 - Double(boatDrift) * 0.9)
            }
            .frame(height: 56)
            .clipped()
            line("它漂走了。花田里会多一朵花。")
        }
    }

    private func release() {
        voice.stop()
        worry.state = WorryState.released.rawValue
        worry.releasedAt = .now
        worry.lastAskedAt = .now
        if reduceMotion {
            phase = .releasing
            boatDrift = 0.0
            Task {
                try? await Task.sleep(nanoseconds: 2_300_000_000)
                onClose()
            }
            return
        }
        // 先把卡片折起来,再换成船漂走
        withAnimation(.easeIn(duration: 0.45)) { cardFolded = true }
        Task {
            try? await Task.sleep(nanoseconds: 480_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { phase = .releasing }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(.easeInOut(duration: 2.4)) { boatDrift = 1 }
            try? await Task.sleep(nanoseconds: 3_100_000_000)
            onClose()
        }
    }

    // MARK: 小件

    private func line(_ s: String) -> some View {
        Text(s)
            .font(Theme.kai(18))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.vertical, 8)
    }

    private func choiceButton(_ label: String, fill: Color, textColor: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.kai(16, weight: .medium))
                .foregroundStyle(textColor)
                .padding(.horizontal, 26)
                .padding(.vertical, 10)
                .background(Capsule().fill(fill))
                .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1.4, dash: [4, 4])))
        }
        .buttonStyle(.plain)
    }
}

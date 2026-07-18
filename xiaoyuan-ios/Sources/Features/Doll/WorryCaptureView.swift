import SwiftUI
import SwiftData
import AVFoundation

// MARK: - 固定反应池(它不会说漂亮话,但永远不会说错话)

enum DollReplies {
    /// 收下烦恼时,随机一句。只收,不劝,不问。
    static let onReceive: [String] = [
        "这个给我吧,你拿着太重了。",
        "我拿着了。",
        "嗯。都放我这儿。",
        "收好了,在我兜里。",
        "交给我了。",
    ]
}

// MARK: - 语音文件柜(Documents/worries/,只存不转)

enum WorryAudioStore {
    static let folderName = "worries"

    static var folderURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    /// 新一段话的落脚点;返回 (绝对 URL, 存进 Worry.audioPath 的相对路径)
    static func newFile() throws -> (url: URL, relativePath: String) {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".m4a"
        return (folderURL.appendingPathComponent(name), folderName + "/" + name)
    }

    /// Worry.audioPath(相对 Documents)→ 绝对 URL
    static func url(forRelativePath path: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
    }
}

// MARK: - 按住它的手,说话(AVAudioRecorder 包一层)

@MainActor
final class HandRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var fileRelativePath: String?
    private var startedAt: Date?

    /// 按下:要权限、开录。权限被拒 → permissionDenied,由界面温柔退回打字。
    func beginHold() async {
        guard !isRecording else { return }
        let granted: Bool
        switch AVAudioApplication.shared.recordPermission {
        case .granted:      granted = true
        case .denied:       granted = false
        case .undetermined: granted = await AVAudioApplication.requestRecordPermission()
        @unknown default:   granted = false
        }
        guard granted else {
            permissionDenied = true
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let file = try WorryAudioStore.newFile()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let r = try AVAudioRecorder(url: file.url, settings: settings)
            r.record()
            recorder = r
            fileRelativePath = file.relativePath
            startedAt = .now
            isRecording = true
        } catch {
            cleanupSession()
        }
    }

    /// 松手:停下。太短的一下就当没说,悄悄扔掉,不评价。
    /// 返回可入库的相对路径(nil = 这次没有留下东西)。
    func endHold() -> String? {
        guard isRecording, let r = recorder else { return nil }
        let duration = Date.now.timeIntervalSince(startedAt ?? .now)
        r.stop()
        recorder = nil
        isRecording = false
        cleanupSession()
        defer { fileRelativePath = nil; startedAt = nil }
        if duration < 0.6 {
            if let p = fileRelativePath {
                try? FileManager.default.removeItem(at: WorryAudioStore.url(forRelativePath: p))
            }
            return nil
        }
        return fileRelativePath
    }

    private func cleanupSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - 说给它

/// 打字,或按住它的手说语音(语音不转文字,只是被收着)。
/// 存下时:娃娃点头收纸 + 固定反应一句,然后自己轻轻关上。
struct WorryCaptureView: View {
    let profile: DollProfile

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = HandRecorder()

    private enum Mode { case text, voice }
    @State private var mode: Mode = .text
    @State private var draft = ""
    @State private var pendingAudioPath: String?
    @State private var reply: String?          // 非 nil = 已收下,展示反应
    @State private var reaction: DollReaction = .listening
    @FocusState private var editorFocused: Bool

    private var hasSomething: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pendingAudioPath != nil
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                if reply == nil {
                    Button("先不说了") { dismiss() }
                        .font(Theme.kai(15))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .frame(height: 24)

            DollView(fabricIndex: profile.fabric, expressionIndex: profile.expression,
                     reaction: reaction, scale: 0.62)

            if let reply {
                Text(reply)
                    .font(Theme.kai(19))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                Spacer()
            } else {
                composeArea
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .background(Theme.paperWarm.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: reply)
        .animation(.easeInOut(duration: 0.25), value: mode)
        .interactiveDismissDisabled(recorder.isRecording)
        .onChange(of: recorder.permissionDenied) { _, denied in
            if denied { mode = .text }   // 录音没开成,退回打字,不多说一个字的责备
        }
    }

    // MARK: 说的两种方式

    @ViewBuilder private var composeArea: some View {
        VStack(spacing: 14) {
            if mode == .text { textArea } else { voiceArea }
            modeSwitch
            saveButton
        }
    }

    private var textArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $draft)
                .font(Theme.kai(17))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .padding(10)
                .focused($editorFocused)
            if draft.isEmpty {
                Text("怎么说都行,说多久都行。")
                    .font(Theme.kai(17))
                    .foregroundStyle(Theme.inkSoft.opacity(0.55))
                    .padding(.top, 18)
                    .padding(.leading, 15)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 150, maxHeight: 220)
        .background(RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous).fill(Theme.paper))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
        )
        .onAppear { reaction = .listening }
    }

    private var voiceArea: some View {
        VStack(spacing: 12) {
            Text(pendingAudioPath == nil
                 ? (recorder.isRecording ? "它在听。" : "按住它的手,说就行。")
                 : "一段话被收着了。")
                .font(Theme.kai(15))
                .foregroundStyle(Theme.inkSoft)

            // 它的手:按住说,松开就停
            ZStack {
                Circle()
                    .fill(.clear)
                    .background(FabricSwatch(fabric: DollFabric.at(profile.fabric)))
                    .clipShape(Circle())
                Circle().strokeBorder(Theme.ink.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))
                Image(systemName: recorder.isRecording ? "waveform" : "hand.wave.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.ink.opacity(0.65))
                    .symbolEffect(.variableColor, isActive: recorder.isRecording)
            }
            .frame(width: 96, height: 96)
            .scaleEffect(recorder.isRecording ? 1.08 : 1)
            .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 60) {
            } onPressingChanged: { pressing in
                if pressing {
                    reaction = .listening
                    Task { await recorder.beginHold() }
                } else if recorder.isRecording {
                    if let path = recorder.endHold() {
                        // 新的一段替掉刚才那段(只留最后一次松手的)
                        if let old = pendingAudioPath {
                            try? FileManager.default.removeItem(at: WorryAudioStore.url(forRelativePath: old))
                        }
                        pendingAudioPath = path
                    }
                }
            }
            .accessibilityLabel("按住说话")

            Text("语音不转文字,只是被收着。")
                .font(Theme.kai(12))
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
        }
        .frame(minHeight: 150)
    }

    private var modeSwitch: some View {
        Button {
            editorFocused = false
            mode = (mode == .text) ? .voice : .text
        } label: {
            Text(mode == .text ? "想用说的:按住它的手" : "还是打字吧")
                .font(Theme.kai(14))
                .foregroundStyle(Theme.inkSoft)
                .underline(true, color: Theme.inkSoft.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(recorder.isRecording)

    }

    private var saveButton: some View {
        Button {
            give()
        } label: {
            Text("给它")
                .font(Theme.kai(17, weight: .medium))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 44)
                .padding(.vertical, 12)
                .background(Capsule().fill(hasSomething ? Theme.terra : Theme.terra.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .disabled(!hasSomething || recorder.isRecording)
        .padding(.bottom, 12)
    }

    // MARK: 收下

    private func give() {
        guard hasSomething, reply == nil else { return }
        editorFocused = false
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let worry = Worry(text: text.isEmpty ? nil : text, audioPath: pendingAudioPath)
        context.insert(worry)
        pendingAudioPath = nil

        reaction = .received
        withAnimation { reply = DollReplies.onReceive.randomElement() }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            dismiss()
        }
    }
}

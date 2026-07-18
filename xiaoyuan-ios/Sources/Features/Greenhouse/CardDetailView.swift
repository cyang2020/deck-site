import SwiftUI
import SwiftData

/// 一张卡的大样:正面给回忆,背面给情绪。
/// 背面默认蒙着毛玻璃,只有手指按住的那一会儿才显形——写在背面,即被承载。
struct CardDetailView: View {
    @Bindable var card: PhotoCard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingBack = false
    @State private var holding = false        // 手指按着背面
    @State private var editing = false        // 正在写背面的话
    @State private var draft = ""
    @State private var unpinArmed = false     // 取下的第二步确认
    @State private var toastText: String?
    @FocusState private var noteFocused: Bool

    private var paperStyle: PaperStyle { PaperStyle(rawValue: card.paper) ?? .polaroid }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                flipCard
                    .padding(.top, 26)
                controlRow
                bottomRow
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .overlay(alignment: .top) { GreenhouseToast(text: toastText) }
        .sensoryFeedback(.impact(weight: .light), trigger: card.sealed)
        .task(id: toastText) { await autoHideToast() }
        .task(id: unpinArmed) { await disarmLater() }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.cornerSheet)
        .presentationBackground(Theme.paper)
    }

    // MARK: - 翻面的卡
    // 背面预先转好 180°,整体再转:正反两面共用一次 rotation3DEffect;
    // 面的显隐在翻转中点(0.26s)瞬间交接,像真的翻过来。

    private var flipCard: some View {
        frontFace
            .opacity(showingBack ? 0 : 1)
            .allowsHitTesting(!showingBack)
            .overlay {
                backFace
                    .opacity(showingBack ? 1 : 0)
                    .allowsHitTesting(showingBack)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .animation(.linear(duration: 0.001).delay(0.26), value: showingBack)
            .rotation3DEffect(.degrees(showingBack ? 180 : 0),
                              axis: (x: 0, y: 1, z: 0),
                              perspective: 0.35)
            .animation(.easeInOut(duration: 0.52), value: showingBack)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity)
    }

    private func flip() {
        if editing { commitBackNote() }   // 写到一半翻面,先替她收好
        showingBack.toggle()
    }

    // MARK: - 正面

    @ViewBuilder private var frontFace: some View {
        switch paperStyle {
        case .polaroid: polaroidFront
        case .film: filmFront
        }
    }

    private var polaroidFront: some View {
        VStack(spacing: 12) {
            photo
            stampRow(color: GreenhousePalette.captionInk)
        }
        .padding(12)
        .padding(.bottom, 16)
        .background(RoundedRectangle(cornerRadius: 4).fill(GreenhousePalette.polaroidPaper))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .strokeBorder(GreenhousePalette.cardEdge, lineWidth: 1))
        .overlay(alignment: .bottomTrailing) {
            sealOverlay.padding(.trailing, 8).padding(.bottom, 44)
        }
        .shadow(color: Theme.ink.opacity(0.2), radius: 9, y: 6)
        .contentShape(Rectangle())
        .onTapGesture { flip() }
    }

    private var filmFront: some View {
        VStack(spacing: 8) {
            FilmSprocketsView(count: 18)
            photo
            FilmSprocketsView(count: 18)
            stampRow(color: GreenhousePalette.filmInk)
                .padding(.horizontal, 4)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 4).fill(GreenhousePalette.filmDark))
        .overlay(alignment: .bottomTrailing) {
            sealOverlay.padding(.trailing, 8).padding(.bottom, 52)
        }
        .shadow(color: .black.opacity(0.35), radius: 9, y: 6)
        .contentShape(Rectangle())
        .onTapGesture { flip() }
    }

    private var photo: some View {
        StoredImageView(path: card.imagePath)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    private func stampRow(color: Color) -> some View {
        HStack {
            Text(card.caption)
                .lineLimit(1)
            Spacer(minLength: 10)
            Text(dateStamp)
        }
        .font(Theme.kai(14))
        .foregroundStyle(color)
    }

    @ViewBuilder private var sealOverlay: some View {
        if card.sealed {
            WaxSealView(size: 30)
                .transition(.scale.combined(with: .opacity))
        }
    }

    /// 手写体日期戳,如 “7月18日”
    private var dateStamp: String {
        let c = Calendar.current.dateComponents([.month, .day], from: card.createdAt)
        return "\(c.month ?? 1)月\(c.day ?? 1)日"
    }

    // MARK: - 背面

    private var backFace: some View {
        VStack(spacing: 12) {
            if editing {
                TextEditor(text: $draft)
                    .font(Theme.kai(16))
                    .lineSpacing(6)
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .tint(Theme.terra)
                    .focused($noteFocused)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { noteFocused = true }
                    .onChange(of: draft) { _, new in
                        if new.count > 200 { draft = String(new.prefix(200)) }
                    }
            } else {
                noteBody
            }

            Text(editing ? "写吧,只有你看得到" : "按住,才看得见")
                .font(Theme.kai(12))
                .tracking(2)
                .foregroundStyle(GreenhousePalette.hint)

            if editing {
                Button("写好了") { commitBackNote() }
                    .buttonStyle(GreenhouseButtonStyle(small: true))
            } else {
                Button("在背面写字") { startEditing() }
                    .buttonStyle(GreenhouseButtonStyle(small: true))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 4).fill(GreenhousePalette.backPaper))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .strokeBorder(GreenhousePalette.cardEdge, lineWidth: 1))
    }

    /// 背面的话:默认蒙 6pt 毛玻璃,按住才显形
    private var noteBody: some View {
        Group {
            if card.backNote.isEmpty {
                Text("背面还没有写字。").opacity(0.5)
            } else {
                Text(card.backNote)
            }
        }
        .font(Theme.kai(16))
        .lineSpacing(8)
        .foregroundStyle(Theme.ink)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .blur(radius: holding ? 0 : 6)
        .animation(.easeOut(duration: 0.3), value: holding)
        .contentShape(Rectangle())
        .gesture(holdGesture)
    }

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in holding = true }
            .onEnded { _ in holding = false }
    }

    private func startEditing() {
        draft = card.backNote
        withAnimation(.easeInOut(duration: 0.2)) { editing = true }
    }

    private func commitBackNote() {
        card.backNote = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        noteFocused = false
        withAnimation(.easeInOut(duration: 0.2)) { editing = false }
    }

    // MARK: - 翻面 / 蜡封

    private var controlRow: some View {
        HStack(spacing: 14) {
            Button(showingBack ? "翻回正面" : "翻到背面") { flip() }
                .buttonStyle(GreenhouseButtonStyle(small: true))
            Button(card.sealed ? "揭掉蜡封" : "按一枚蜡封") { toggleSeal() }
                .buttonStyle(GreenhouseButtonStyle(small: true))
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleSeal() {
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { card.sealed.toggle() }
        try? modelContext.save()
        if card.sealed { toastText = "这一张,封起来了。" }
    }

    // MARK: - 取下(安静的两步,不弹窗)

    private var bottomRow: some View {
        HStack {
            Button(unpinArmed ? "取下就找不回来了——真的取下?" : "取下这张") { unpinTapped() }
                .buttonStyle(GreenhouseButtonStyle(small: true, dashed: true))
                .opacity(0.75)
            if !unpinArmed {
                Spacer()
                Button("好了") { dismiss() }
                    .buttonStyle(GreenhouseButtonStyle(small: true))
            }
        }
        .animation(.easeOut(duration: 0.2), value: unpinArmed)
    }

    private func unpinTapped() {
        if unpinArmed {
            unpin()
        } else {
            unpinArmed = true
        }
    }

    /// 第二步确认只停留 3.5 秒,之后自己退回去
    private func disarmLater() async {
        guard unpinArmed else { return }
        do {
            try await Task.sleep(for: .seconds(3.5))
            unpinArmed = false
        } catch {}   // 真的取下了/提前收起,就不用退了
    }

    private func unpin() {
        let path = card.imagePath
        let doomed = card
        let context = modelContext
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))   // 等卡片先合上,再安静地取下
            ImageStore.delete(path)
            context.delete(doomed)
            try? context.save()
        }
    }

    // MARK: - 顶部小话

    private func autoHideToast() async {
        guard toastText != nil else { return }
        do {
            try await Task.sleep(for: .seconds(2.2))
            toastText = nil
        } catch {}
    }
}

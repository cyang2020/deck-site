import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// 晾一张新照片:选图/拍一张 → 选纸 → 写一行字(可不写)→ 夹上绳。
/// 全程可以随时“算了”。
struct NewPhotoFlow: View {
    /// 夹好(插入成功)后通知外面,花房那边好说一声“嗒——夹好了。”
    var onHung: () -> Void

    init(onHung: @escaping () -> Void = {}) {
        self.onHung = onHung
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var pickedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var paper: PaperStyle = .polaroid
    @State private var caption = ""
    @State private var showCamera = false
    @State private var loadingPick = false
    @State private var quietHint: String?

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("晾一张")
                    .font(Theme.kai(22, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(Theme.ink)

                preview
                pickRow

                Text("选一种纸:")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                paperRow

                captionField
                    .padding(.top, 4)

                if let quietHint {
                    Text(quietHint)
                        .font(Theme.kai(13))
                        .foregroundStyle(GreenhousePalette.hint)
                }

                actionRow
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(Theme.paper)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.cornerSheet)
        .presentationBackground(Theme.paper)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { taken in
                if let taken { image = ImageStore.squareCropped(taken) }
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickedItem) { _, item in loadPicked(item) }
        .onChange(of: caption) { _, new in
            if new.count > 30 { caption = String(new.prefix(30)) }   // 一行字,30 个字够了
        }
    }

    // MARK: - 预览:照片放在选中的纸上

    private var preview: some View {
        HStack {
            Spacer()
            PaperCardFace(paper: paper, caption: caption, side: 150) {
                ZStack {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle().fill(Theme.paperWarm)
                        if loadingPick {
                            ProgressView().tint(Theme.inkSoft)
                        } else {
                            Text("照片会晾在这里")
                                .font(Theme.kai(13))
                                .tracking(1)
                                .foregroundStyle(GreenhousePalette.hint)
                        }
                    }
                }
            }
            .rotationEffect(.degrees(-1.5))
            Spacer()
        }
        .animation(.easeOut(duration: 0.2), value: paper)
    }

    // MARK: - 取照片

    private var pickRow: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Text(image == nil ? "从相册选" : "换一张")
                    .greenhousePill(small: true)
            }
            if cameraAvailable {
                Button("拍一张") { showCamera = true }
                    .buttonStyle(GreenhouseButtonStyle(small: true))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        loadingPick = true
        Task { @MainActor in
            defer {
                loadingPick = false
                pickedItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let picked = UIImage(data: data) else {
                quietHint = "这张没取出来,再选一次就好。"
                return
            }
            image = ImageStore.squareCropped(picked)
            quietHint = nil
        }
    }

    // MARK: - 选纸

    private var paperRow: some View {
        HStack(spacing: 10) {
            ForEach(PaperStyle.allCases, id: \.rawValue) { style in
                Button(style.label) {
                    withAnimation(.easeOut(duration: 0.18)) { paper = style }
                }
                .buttonStyle(GreenhouseButtonStyle(fill: paper == style, small: true))
            }
        }
    }

    // MARK: - 一行字

    private var captionField: some View {
        TextField("写一行字,也可以不写", text: $caption)
            .font(Theme.kai(17))
            .foregroundStyle(Theme.ink)
            .tint(Theme.terra)
            .padding(.vertical, 8)
            .background(alignment: .bottom) {
                DashedLine()
                    .stroke(GreenhousePalette.underline,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .frame(height: 2)
            }
    }

    // MARK: - 夹上绳 / 算了

    private var actionRow: some View {
        HStack {
            Button("夹上绳") { hang() }
                .buttonStyle(GreenhouseButtonStyle(fill: true))
                .disabled(image == nil)
            Spacer()
            Button("算了") { dismiss() }
                .buttonStyle(GreenhouseButtonStyle(small: true))
        }
    }

    private func hang() {
        guard let image else { return }
        do {
            let path = try ImageStore.save(image)
            let card = PhotoCard(imagePath: path,
                                 paper: paper,
                                 caption: caption.trimmingCharacters(in: .whitespacesAndNewlines))
            modelContext.insert(card)
            try modelContext.save()
            onHung()
            dismiss()
        } catch {
            quietHint = "没夹住,再来一次就好。"
        }
    }
}

// MARK: - 虚线书写线

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - 相机(系统取景器,拍完直接回来)

private struct CameraCaptureView: UIViewControllerRepresentable {
    /// 拍到了给图,取消给 nil;由外面负责收起 cover
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

#Preview {
    NewPhotoFlow()
        .modelContainer(for: PhotoCard.self, inMemory: true)
}

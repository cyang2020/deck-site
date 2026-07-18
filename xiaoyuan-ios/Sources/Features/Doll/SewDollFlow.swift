import SwiftUI
import SwiftData

/// 初见:亲手缝它。一步一屏,哪一步都可以直接"先这样"。
/// 缝完(最后一屏点"进屋")才写入 DollProfile;中途关掉 = 什么都没发生。
struct SewDollFlow: View {
    @Environment(\.modelContext) private var context

    private enum Step: Int { case fabric, expression, name, done }
    @State private var step: Step = .fabric
    @State private var fabricIndex = 0
    @State private var expressionIndex = 0
    @State private var name = ""

    @FocusState private var nameFocused: Bool

    private var finalName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "豆豆" : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 8)
            Group {
                switch step {
                case .fabric:     fabricStep
                case .expression: expressionStep
                case .name:       nameStep
                case .done:       doneStep
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .background(Theme.paperWarm.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: 顶栏(可回退;随时"先这样"跳到最后,用现在的样子)

    private var topBar: some View {
        HStack {
            if step != .fabric && step != .done {
                Button("上一步") { step = Step(rawValue: step.rawValue - 1) ?? .fabric }
                    .font(Theme.kai(15))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            if step != .done {
                Button("先这样") { step = .done }
                    .font(Theme.kai(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(height: 28)
    }

    // MARK: 第一针:挑布料

    private var fabricStep: some View {
        VStack(spacing: 26) {
            stepTitle("给它挑一块布", sub: "哪块都好。")
            DollView(fabricIndex: fabricIndex, expressionIndex: expressionIndex, scale: 0.82)
            HStack(spacing: 18) {
                ForEach(DollFabric.all) { fabric in
                    swatchButton(fabric)
                }
            }
            nextButton("缝好了")
        }
    }

    private func swatchButton(_ fabric: DollFabric) -> some View {
        Button {
            fabricIndex = fabric.id
        } label: {
            VStack(spacing: 8) {
                FabricSwatch(fabric: fabric)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                fabricIndex == fabric.id ? Theme.ink.opacity(0.7) : Theme.ink.opacity(0.18),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                    )
                Text(fabric.name)
                    .font(Theme.kai(12))
                    .foregroundStyle(fabricIndex == fabric.id ? Theme.ink : Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("布料:\(fabric.name)")
    }

    // MARK: 第二针:缝表情

    private var expressionStep: some View {
        VStack(spacing: 26) {
            stepTitle("缝个表情", sub: "它反正都乐意。")
            DollView(fabricIndex: fabricIndex, expressionIndex: expressionIndex, scale: 0.82)
            HStack(spacing: 16) {
                ForEach(DollExpression.allCases, id: \.rawValue) { exp in
                    Button {
                        expressionIndex = exp.rawValue
                    } label: {
                        Text(exp.label)
                            .font(Theme.kai(15))
                            .foregroundStyle(expressionIndex == exp.rawValue ? Theme.paper : Theme.ink)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(expressionIndex == exp.rawValue ? Theme.terra : Theme.paper)
                            )
                            .overlay(
                                Capsule().strokeBorder(Theme.ink.opacity(0.2),
                                    style: StrokeStyle(lineWidth: 1.6, dash: [4, 4]))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            nextButton("就这个脸")
        }
    }

    // MARK: 最后一针:取名字

    private var nameStep: some View {
        VStack(spacing: 26) {
            stepTitle("给它取个名字", sub: "不取也行,它就叫豆豆。")
            DollView(fabricIndex: fabricIndex, expressionIndex: expressionIndex, scale: 0.72)
            TextField("豆豆", text: $name)
                .font(Theme.kai(22))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { step = .done }
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous)
                        .fill(Theme.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerCard, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                )
                .frame(maxWidth: 220)
            nextButton("好了")
        }
    }

    // MARK: 缝好了

    private var doneStep: some View {
        VStack(spacing: 30) {
            Text(finalName)
                .font(Theme.kai(24, weight: .medium))
                .foregroundStyle(Theme.ink)
            DollView(fabricIndex: fabricIndex, expressionIndex: expressionIndex, scale: 0.95)
            Text("以后,麻烦是我的工作。")
                .font(Theme.kai(19))
                .foregroundStyle(Theme.ink)
            Button {
                nameFocused = false
                context.insert(DollProfile(name: finalName, fabric: fabricIndex, expression: expressionIndex))
                // 写入后,小屋那边的 @Query 自己会换成房间
            } label: {
                Text("进屋")
                    .font(Theme.kai(17, weight: .medium))
                    .foregroundStyle(Theme.paper)
                    .padding(.horizontal, 42)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Theme.leaf))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 小件

    private func stepTitle(_ title: String, sub: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(Theme.kai(21, weight: .medium)).foregroundStyle(Theme.ink)
            Text(sub).font(Theme.kai(14)).foregroundStyle(Theme.inkSoft)
        }
    }

    private func nextButton(_ label: String) -> some View {
        Button {
            nameFocused = false
            step = Step(rawValue: step.rawValue + 1) ?? .done
        } label: {
            Text(label)
                .font(Theme.kai(16, weight: .medium))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 34)
                .padding(.vertical, 11)
                .background(Capsule().fill(Theme.terra))
        }
        .buttonStyle(.plain)
    }
}

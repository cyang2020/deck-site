import Foundation
import SwiftUI
import SwiftData

/// 邮筒 · 节气寄来的种子包与小园的信。
///
/// 只在被打开的时候回应——永远不发推送、不亮红点、不催她来看。
/// 逻辑(以 `MailRecord` + `SolarTerms.termKey()` 判定):
/// 1. 头一次打开(一条记录都没有):欢迎信 + 头一批种子,并记下当前节气;
/// 2. 到了没记过的新节气:节气便签(没有便签的节气用一句安静的默认话)+ 一小包应季种子;
/// 3. 这个节气已经收过:暂时没有新的信。
public struct MailboxSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var delivery: Delivery?

    public init() {}

    // MARK: - 视图

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("邮筒")
                    .font(Theme.kai(22, weight: .semibold))
                    .kerning(3)
                    .foregroundStyle(Theme.ink)

                if let delivery {
                    letter(for: delivery)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("收好了")
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
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(EdgeInsets(top: 24, leading: 20, bottom: 28, trailing: 20))
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.cornerSheet)
        .presentationBackground(Theme.paper)
        .task { deliverIfNeeded() }
    }

    // MARK: - 投递逻辑

    private enum Delivery {
        case welcome(term: String, grants: [SeedGrant])
        case seasonal(term: String, note: String, grants: [SeedGrant])
        case nothingNew
    }

    @MainActor
    private func deliverIfNeeded() {
        guard delivery == nil else { return }

        let key = SolarTerms.termKey()
        let term = SolarTerms.current()
        let records = (try? modelContext.fetch(FetchDescriptor<MailRecord>())) ?? []

        let result: Delivery
        if records.isEmpty {
            // 头一次打开:欢迎信 + 头一批种子
            let grants = SeedGrants.welcome
            SeedGrants.apply(grants, in: modelContext)
            modelContext.insert(MailRecord(termKey: key))
            try? modelContext.save()
            result = .welcome(term: term, grants: grants)
        } else if !records.contains(where: { $0.termKey == key }) {
            // 新节气:便签 + 应季小包
            let grants = SeedGrants.termGrant(forTermKey: key)
            SeedGrants.apply(grants, in: modelContext)
            modelContext.insert(MailRecord(termKey: key))
            try? modelContext.save()
            let note = SolarTerms.letters[term] ?? "又是一个节气。园子都记得。"
            result = .seasonal(term: term, note: note, grants: grants)
        } else {
            result = .nothingNew
        }

        withAnimation(.easeOut(duration: 0.5)) { delivery = result }
    }

    // MARK: - 信

    @ViewBuilder
    private func letter(for delivery: Delivery) -> some View {
        switch delivery {
        case .welcome(let term, let grants):
            LetterPaper(
                text: "这里是你的园子。\n花往哪儿种,都对。\n\n随信附上头一批种子:\(Self.grantList(grants))。",
                from: "—— 小园 · \(term)",
                grants: grants
            )
        case .seasonal(let term, let note, let grants):
            LetterPaper(
                text: "\(note)\n\n随信附上应季的种子:\(Self.grantList(grants))。",
                from: "—— 小园 · \(term)",
                grants: grants
            )
        case .nothingNew:
            LetterPaper(
                text: "暂时没有新的信。\n下一个节气,会有种子寄到。",
                from: "—— 小园"
            )
        }
    }

    /// "波斯菊三粒、向日葵两粒、牵牛花两粒"
    private static func grantList(_ grants: [SeedGrant]) -> String {
        grants.map(\.described).joined(separator: "、")
    }
}

// MARK: - 信纸

/// 楷体、宽行距的信纸;信里附了种子时,下方摆出小种子包。
private struct LetterPaper: View {
    let text: String
    let from: String
    var grants: [SeedGrant] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(Theme.kai(17))
                .kerning(1)
                .lineSpacing(16)
                .foregroundStyle(Color(hex: 0x54432F))
                .frame(maxWidth: .infinity, alignment: .leading)

            if !grants.isEmpty {
                HStack(spacing: 16) {
                    ForEach(grants, id: \.kind) { grant in
                        VStack(spacing: 3) {
                            Image(grant.kind.seedAsset)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text(grant.kind.label)
                                .font(Theme.kai(12))
                                .foregroundStyle(Color(hex: 0x9A8568))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(grant.described)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 18)
            }

            Text(from)
                .font(Theme.kai(14))
                .foregroundStyle(Color(hex: 0x9A8568))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 14)
        }
        .padding(EdgeInsets(top: 26, leading: 22, bottom: 20, trailing: 22))
        .background(Color(hex: 0xFFFAF0),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color(hex: 0xE7D9BE), lineWidth: 1)
        }
        .shadow(color: Theme.ink.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

import Foundation
import SwiftUI

/// 花坛里的一株植物。由园景模块摆进花坛的格位里。
///
/// 素材:阶段 0 → "sprout",1 → "bud",2 → `FlowerKind.bloomAsset`;
/// 只随真实时间生长(见 `Plant.stage(at:)`),永不枯萎。
/// 点一下,弹出一张小纸片「展签」:是什么、哪天种的、心里的天气、那句话。
public struct PlantSpriteView: View {

    let plant: Plant
    /// 成花的目标高度(园景的标尺);芽和苞按比例更矮
    private let height: CGFloat

    @State private var showTag = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(plant: Plant, height: CGFloat = 72) {
        self.plant = plant
        self.height = height
    }

    public var body: some View {
        Button {
            showTag = true
        } label: {
            sprite
        }
        .buttonStyle(.plain)
        .accessibilityLabel(stageTitle)
        .popover(isPresented: $showTag, arrowEdge: .bottom) {
            tagCard
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color(hex: 0xFFFAF0))
        }
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                // 轻轻地冒出来,不惊动谁
                withAnimation(.spring(response: 0.7, dampingFraction: 0.66)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: 精灵

    private var sprite: some View {
        Image(assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: height * stageScale, alignment: .bottom)
            .frame(width: max(44, height * 0.75), height: height, alignment: .bottom)
            .contentShape(Rectangle())
            .scaleEffect(appeared ? 1 : 0.55, anchor: .bottom)
            .opacity(appeared ? 1 : 0)
    }

    private var stage: Int { plant.stage() }

    private var kind: FlowerKind { FlowerKind(rawValue: plant.kind) ?? .cosmos }

    private var assetName: String {
        switch stage {
        case 0: "sprout"
        case 1: "bud"
        default: kind.bloomAsset
        }
    }

    private var stageScale: CGFloat {
        switch stage {
        case 0: 0.45
        case 1: 0.66
        default: 1
        }
    }

    private var stageTitle: String {
        switch stage {
        case 0: "一株小芽"
        case 1: "一个花苞"
        default: kind.label
        }
    }

    // MARK: 展签

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stageTitle)
                .font(Theme.kai(18, weight: .semibold))
                .kerning(2)
                .foregroundStyle(Color(hex: 0x54432F))
            Text(dateAndMood)
                .font(Theme.kai(13))
                .foregroundStyle(Color(hex: 0x9A8568))
            if !trimmedLine.isEmpty {
                Text("「\(trimmedLine)」")
                    .font(Theme.kai(15))
                    .lineSpacing(9)
                    .foregroundStyle(Color(hex: 0x54432F))
                    .padding(.top, 2)
            }
            if stage < 2 {
                Text("还在长。花开的日子,由它自己定。")
                    .font(Theme.kai(13))
                    .lineSpacing(7)
                    .foregroundStyle(Color(hex: 0x9A8568))
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(width: 236, alignment: .leading)
    }

    private var trimmedLine: String {
        plant.line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "7月18日 · 晴" —— 手排的中文日期,不跟系统区域走
    private var dateAndMood: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: plant.plantedAt)
        let day = calendar.component(.day, from: plant.plantedAt)
        var text = "\(month)月\(day)日"
        if let mood = plant.mood.flatMap(MoodWeather.init(rawValue:)) {
            text += " · " + mood.label
        }
        return text
    }
}

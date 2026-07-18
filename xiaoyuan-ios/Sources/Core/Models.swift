import Foundation
import SwiftData

// MARK: - 枚举契约(字符串存储,便于 SwiftData 与素材文件名对齐)

enum PaperStyle: String, Codable, CaseIterable {
    case polaroid, film
    var label: String { self == .polaroid ? "拍立得" : "胶片" }
}

enum MoodWeather: String, Codable, CaseIterable {
    case sunny, cloudy, rain, storm
    var label: String {
        switch self {
        case .sunny: "晴"; case .cloudy: "多云"; case .rain: "小雨"; case .storm: "雷阵雨"
        }
    }
}

enum FlowerKind: String, Codable, CaseIterable {
    case cosmos, sunflower, glory
    var label: String {
        switch self {
        case .cosmos: "波斯菊"; case .sunflower: "向日葵"; case .glory: "牵牛花"
        }
    }
    /// garden/assets 里的成花素材名
    var bloomAsset: String {
        switch self {
        case .cosmos: "flw-cosmos"; case .sunflower: "flw-sunflower"; case .glory: "flw-glory"
        }
    }
    var seedAsset: String {
        switch self {
        case .cosmos: "seed-cosmos"; case .sunflower: "seed-sunflower"; case .glory: "seed-glory"
        }
    }
}

enum WorryState: String, Codable { case held, released }

// MARK: - SwiftData 模型

@Model
final class PhotoCard {
    var imagePath: String      // Documents 下相对路径,方形已裁剪
    var paper: String          // PaperStyle.rawValue
    var caption: String
    var backNote: String       // 背面的话(只在长按时显形)
    var sealed: Bool           // 蜡封
    var createdAt: Date

    init(imagePath: String, paper: PaperStyle, caption: String = "", createdAt: Date = .now) {
        self.imagePath = imagePath
        self.paper = paper.rawValue
        self.caption = caption
        self.backNote = ""
        self.sealed = false
        self.createdAt = createdAt
    }
}

@Model
final class Plant {
    var kind: String           // FlowerKind.rawValue
    var mood: String?          // MoodWeather.rawValue
    var line: String           // 一句话,可空
    var plantedAt: Date
    var slot: Int              // 花坛格位 0..<6

    init(kind: FlowerKind, mood: MoodWeather?, line: String, slot: Int, plantedAt: Date = .now) {
        self.kind = kind.rawValue
        self.mood = mood?.rawValue
        self.line = line
        self.slot = slot
        self.plantedAt = plantedAt
    }

    /// 0 芽 / 1 苞 / 2 开花 —— 只随真实时间,永不枯萎
    func stage(at date: Date = .now) -> Int {
        let days = date.timeIntervalSince(plantedAt) / 86_400
        if days >= 2 { return 2 }
        if days >= 1 { return 1 }
        return 0
    }
}

@Model
final class Worry {
    var text: String?
    var audioPath: String?     // 语音不转文字,只是被收着
    var createdAt: Date
    var state: String          // WorryState.rawValue
    var lastAskedAt: Date?     // 娃娃上次轻轻问的时间
    var releasedAt: Date?      // 折成纸船漂走、花田开花的时间

    init(text: String? = nil, audioPath: String? = nil, createdAt: Date = .now) {
        self.text = text
        self.audioPath = audioPath
        self.createdAt = createdAt
        self.state = WorryState.held.rawValue
    }

    /// 收下 ≥7 天且 ≥14 天未问过,娃娃才轻轻问一次("还沉吗?")
    func dueForGentleAsk(at date: Date = .now) -> Bool {
        guard state == WorryState.held.rawValue else { return false }
        guard date.timeIntervalSince(createdAt) >= 7 * 86_400 else { return false }
        if let last = lastAskedAt, date.timeIntervalSince(last) < 14 * 86_400 { return false }
        return true
    }
}

@Model
final class SeedLot {
    @Attribute(.unique) var kind: String   // FlowerKind.rawValue
    var count: Int
    init(kind: FlowerKind, count: Int) { self.kind = kind.rawValue; self.count = count }
}

@Model
final class DollProfile {
    var name: String
    var fabric: Int            // 布料样式索引
    var expression: Int        // 表情索引
    var createdAt: Date
    init(name: String, fabric: Int, expression: Int) {
        self.name = name; self.fabric = fabric; self.expression = expression; self.createdAt = .now
    }
}

/// 邮筒投递记录(哪个节气的信/种子已收过)
@Model
final class MailRecord {
    @Attribute(.unique) var termKey: String   // 如 "2026-小暑"
    var openedAt: Date
    init(termKey: String) { self.termKey = termKey; self.openedAt = .now }
}

enum AllModels {
    static let schema: [any PersistentModel.Type] =
        [PhotoCard.self, Plant.self, Worry.self, SeedLot.self, DollProfile.self, MailRecord.self]
}

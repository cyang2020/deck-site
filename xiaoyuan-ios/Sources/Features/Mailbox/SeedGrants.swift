import Foundation
import SwiftData

/// 一小包随信附上的种子
struct SeedGrant: Equatable {
    let kind: FlowerKind
    let count: Int

    /// 信里的写法:"波斯菊三粒"
    var described: String { kind.label + Self.chineseCount(count) + "粒" }

    private static func chineseCount(_ n: Int) -> String {
        switch n {
        case 1: "一"
        case 2: "两"
        case 3: "三"
        case 4: "四"
        case 5: "五"
        default: "\(n)"
        }
    }
}

/// 邮筒寄种子的纯逻辑:头一封信的种子、每个节气的种子(确定性的)、并进种子盒。
/// 不弹任何通知——种子只在她自己打开邮筒时到手。
enum SeedGrants {

    /// 第一次打开邮筒:波斯菊×3、向日葵×2、牵牛花×2
    static let welcome: [SeedGrant] = [
        SeedGrant(kind: .cosmos, count: 3),
        SeedGrant(kind: .sunflower, count: 2),
        SeedGrant(kind: .glory, count: 2),
    ]

    /// 某个节气的应季小包:共 2–3 粒,由 termKey(如 "2026-小暑")确定性地决定,
    /// 同一节气无论何时打开、打开几次(只发一次),内容都一样。
    static func termGrant(forTermKey key: String) -> [SeedGrant] {
        let hash = fnv1a(key)
        let kinds = FlowerKind.allCases
        let total = 2 + Int(hash % 2)                                // 2 或 3 粒
        let first = kinds[Int((hash >> 8) % UInt64(kinds.count))]
        let second = kinds[Int((hash >> 16) % UInt64(kinds.count))]
        if first == second {
            return [SeedGrant(kind: first, count: total)]
        }
        return [
            SeedGrant(kind: first, count: total - 1),
            SeedGrant(kind: second, count: 1),
        ]
    }

    /// 把一整包并进种子盒
    static func apply(_ grants: [SeedGrant], in modelContext: ModelContext) {
        for grant in grants {
            upsert(kind: grant.kind, add: grant.count, in: modelContext)
        }
    }

    /// SeedLot.kind 唯一:已有这一格就累加,没有就新开一格
    static func upsert(kind: FlowerKind, add: Int, in modelContext: ModelContext) {
        let raw = kind.rawValue
        var descriptor = FetchDescriptor<SeedLot>(
            predicate: #Predicate<SeedLot> { $0.kind == raw }
        )
        descriptor.fetchLimit = 1
        if let lot = (try? modelContext.fetch(descriptor))?.first {
            lot.count += add
        } else {
            modelContext.insert(SeedLot(kind: kind, count: add))
        }
    }

    /// 稳定哈希(FNV-1a 64)。不用 String.hashValue——它每次启动都会变。
    private static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}

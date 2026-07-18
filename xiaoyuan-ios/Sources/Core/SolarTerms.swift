import Foundation

/// 二十四节气(近似日期表,±1 天误差对氛围无影响;正式版可换天文表)
enum SolarTerms {
    static let table: [(month: Int, day: Int, name: String)] = [
        (1, 5, "小寒"), (1, 20, "大寒"), (2, 4, "立春"), (2, 19, "雨水"),
        (3, 5, "惊蛰"), (3, 20, "春分"), (4, 5, "清明"), (4, 20, "谷雨"),
        (5, 5, "立夏"), (5, 21, "小满"), (6, 6, "芒种"), (6, 21, "夏至"),
        (7, 7, "小暑"), (7, 23, "大暑"), (8, 7, "立秋"), (8, 23, "处暑"),
        (9, 7, "白露"), (9, 23, "秋分"), (10, 8, "寒露"), (10, 23, "霜降"),
        (11, 7, "立冬"), (11, 22, "小雪"), (12, 7, "大雪"), (12, 22, "冬至"),
    ]

    static func current(_ date: Date = .now) -> String {
        let m = Calendar.current.component(.month, from: date)
        let d = Calendar.current.component(.day, from: date)
        var name = "冬至"
        for t in table where m > t.month || (m == t.month && d >= t.day) { name = t.name }
        return name
    }

    /// 邮筒用:唯一键 "2026-小暑"
    static func termKey(_ date: Date = .now) -> String {
        let y = Calendar.current.component(.year, from: date)
        return "\(y)-\(current(date))"
    }

    /// 节气便签:不是知识,是自然的活法(低频,宁缺毋滥)
    static let letters: [String: String] = [
        "立春": "泥土还冻着,种子已经知道春天的事了。",
        "谷雨": "雨是给所有草木的,不挑长得快的。",
        "小暑": "蝉不着急,夏天还长。",
        "霜降": "冬天的树没有为落叶道歉。",
        "小雪": "苔藓不羡慕乔木,它们不在同一场比赛里。",
        "冬至": "夜最长的一天,灯也最亮。",
    ]
}

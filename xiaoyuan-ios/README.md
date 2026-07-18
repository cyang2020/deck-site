# 小园 · iOS

毛毡质感的口袋小园子。完全离线、零服务器、数据只在设备上。

## 跑起来(Mac)

```bash
brew install xcodegen
cd xiaoyuan-ios
xcodegen            # 生成 Xiaoyuan.xcodeproj(素材直接引用 ../garden/assets)
open Xiaoyuan.xcodeproj
```

## 模块地图

| 目录 | 内容 |
|---|---|
| Sources/App | 入口、根视图、ModelContainer |
| Sources/Core | 共享契约:Models(SwiftData)/ Theme / SolarTerms |
| Sources/Features/Garden | 园景主场景(横向漫步、昼夜、节气氛围)+ 3D 立体书俯瞰 |
| Sources/Features/Greenhouse | 花房:照片卡(纸样、背面的话、蜡封)与照片墙 |
| Sources/Features/Flowerbed | 花坛:种子盒、心情天气、真实时间生长 |
| Sources/Features/Mailbox | 邮筒:节气种子包与小园来信 |
| Sources/Features/Doll | 小屋:缝娃娃、收烦恼、烦恼生命周期、晚安 |

## 铁律(写任何 UI 文案前先读)

1. 无观众、无期待:没有打卡、连签、统计、进度、红点;App 永不表达期待。
2. 疗愈藏在可爱里:界面上只有园中日常之物,不出现任何心理学词汇。
3. 文案不评价、不祈使、不煽情:✅"都还在。" ❌"坚持记录,你真棒!"
4. 心情用天气,不用分数;雨天没有好坏。
5. 一切可跳过;30 秒也算来过;没有东西会枯萎。
6. 零服务器;娃娃不接大模型,只有固定的笨拙可爱反应。

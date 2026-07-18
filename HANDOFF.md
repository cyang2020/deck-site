# 小园 · 项目交接(给本地 Claude Code / 任何接手的 agent)

> 第一次接手,读完本文件即可开工。更完整的产品思考在 `docs/app-design.md`。

## 0. 这是什么

「小园」:一个装在口袋里的**毛毡手缝小园子**,给一位温柔可爱、热爱记录生活、
但活在他人期待与比较里、怕让人失望、怕麻烦别人的人,做**长期、安静、无负担的陪伴**。

- 完全独立的产品:与本仓库根目录的「深水区」官网(index/support/privacy.html)**无任何关系**,
  未来迁到独立仓库;暂放这里只因开发会话绑定此 repo。
- 核心功能:园景漫步(昼夜/节气)、花房照片日记(背面的话/蜡封)、花坛种心情(真实时间生长)、
  邮筒节气来信与种子、解忧布娃娃(只收不劝、烦恼回访、花田)、3D 立体书俯瞰(在做)。

## 1. 铁律(动手前必读,做任何 UI/文案都要过这几关)

1. **无观众、无期待**:没有打卡/连签/统计/进度/红点;App 永不表达期待;没有东西会枯萎。
2. **疗愈藏在可爱里**:界面上只有园中日常之物,零心理学词汇。
3. **文案不评价、不祈使、不煽情**:✅"都还在。" ❌"坚持记录,你真棒!"
4. 心情用天气(晴/多云/小雨/雷阵雨),不用分数;雨天没有好坏。
5. 零服务器、完全离线、数据可导出;**娃娃不接大模型**,只有固定的笨拙可爱反应。
6. 不把"她"的任何个人信息写进这个(可能公开的)仓库。

## 2. 代码地图

| 路径 | 内容 |
|---|---|
| `docs/app-design.md` | 产品设计全文(v4:garden 世界观) |
| `garden/index.html` | **可玩的网页原型**(单文件,localStorage,零依赖) |
| `garden/assets/*.png` | 26 张毛毡素材(codex 生成→绿幕抠图→≤900px) |
| `garden/designs/` | 整景设计图(6 张,生成中/已生成) |
| `garden/ASSETS.md` | 素材风格圣经 + 逐张 prompt + 一致性做法 |
| `garden/tools/gen-assets.mjs` | 批量生图脚本(OpenAI Images API,备选路线) |
| `garden/tools/chromakey.mjs` | 绿幕→透明 + 降采样(playwright-core + 无头 Chromium) |
| `garden/tools/build-artifact.mjs` | 打包单文件原型(素材内联为 ≤700px WebP) |
| `xiaoyuan-ios/` | iOS 原生工程(SwiftUI+SwiftData,XcodeGen) |

iOS 模块状态(由并行 agent 产出,**尚未编译验证**——第一件事就是拉起来修编译错):
Core 契约与四功能模块代码已在 `xiaoyuan-ios/Sources/`,
园景主入口(GardenRootView)与 3D 俯瞰(OverviewDiorama)、娃娃的部分文件可能仍在补齐,
以 git log 最新为准。

## 3. 本地环境拉起

```bash
# 代码
git clone https://github.com/cyang2020/deck-site.git
cd deck-site && git checkout claude/ex-girlfriend-app-design-mb2mct

# 网页原型:直接用浏览器打开 garden/index.html 即可(或起个静态服务)

# iOS
brew install xcodegen
cd xiaoyuan-ios && xcodegen && open Xiaoyuan.xcodeproj
# 真机运行在 Xcode 里选自己的 Team 签名

# 素材工具链(需要时)
npm i playwright-core            # chromakey / build-artifact 依赖,任意目录
node garden/tools/chromakey.mjs  # 新生成的绿幕图 → 透明
node garden/tools/build-artifact.mjs --out /tmp/garden-artifact.html
```

素材再生成(两条路,选一):
- **codex(推荐,用订阅)**:`codex login`(浏览器点 Google)→
  `codex exec "读 garden/ASSETS.md,用图像工具生成 XXX,绿幕 #00FF00,存 garden/assets/"`
  → 跑 chromakey。整景设计图同理,见 `garden/designs/` 的命名。
- **API key**:`export OPENAI_API_KEY=... && node garden/tools/gen-assets.mjs`(另计费)。

## 4. 当前方向(按最新决策,勿回退)

1. **视觉路线已定为"整景设计"**:不再由代码拼贴单件素材。
   codex 正在/已经产出 6 张整景(`garden/designs/scene-*.png`:园子全景昼/夜、
   花房内部、小屋内部、花坛特写、3D 立体书俯瞰概念)。
   由用户挑定后:选中的整景做真背景,交互物件(会生长的花、照片卡、娃娃、门)作为
   动态层叠在热区上。单件素材库仍有用(动态层用)。
2. **3D 俯瞰**:立体书/桌面毛毡模型 diorama 方向(iOS 用 SceneKit,billboard 贴片即可),
   不做全 3D 建模管线。
3. **iOS**:先 xcodegen 拉起、修编译错、把四模块接进 GardenRootView 跑通;
   然后按整景设计重构园景层。
4. **v0.2**:娃娃素材(布娃娃本体、小布袋、纸船)见 `garden/ASSETS.md` 第二批清单。

## 5. 别做的事

- 别加打卡/成就/分享/排行/推送轰炸;别给娃娃接 AI;别起服务器。
- 别在公开材料里出现她的身份信息或"前女友"字样。
- 别把本项目与「深水区」在代码、文案、视觉上产生任何关联。

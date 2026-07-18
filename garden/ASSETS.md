# 针脚小园 · 素材风格圣经与生成清单

> 目标:把 `garden/index.html` 里的程序绘制素材,替换成 AI 生成的**布艺羊毛毡立体绘本**风格 PNG。
> 本文档是完整的交接说明:风格定义、每张图的文件名/尺寸/prompt、一致性做法、本地执行方式。
>
> 给本地 Claude Code 或 codex 的一句话指令:
> **"读 garden/ASSETS.md,生成全部第一批素材到 garden/assets/,提交并推到当前分支。"**

---

## 0. 本地怎么跑(三选一)

- **A. 本地 Claude Code CLI**(推荐):在仓库目录里 `claude`,说上面那句话。
  它可以先跑 `codex login`(浏览器里你自己点 Google 登录),用 codex 生图;
  codex 生不了图就走 C 的脚本。
- **B. codex CLI**:`codex login` 后,让 codex 读本文件自行生成。
- **C. 纯脚本**(只要 API key,不用登录):
  `export OPENAI_API_KEY=sk-... && node garden/tools/gen-assets.mjs --quality medium`
  脚本零依赖(Node 18+),逐张调 OpenAI 图像接口存到 `garden/assets/`。

完成后:`git add garden/assets && git commit -m "add felt assets" && git push`,
然后回网页会话说一声"图好了",由云端会话接入原型。

费用参考:第一批 22 张,medium 档约 1–2 美元,high 档约 4–6 美元。先用 medium 试风格,满意再重生成关键大图。

## 1. 风格定义(所有 prompt 共用前缀)

**中文含义**:一切都是手缝出来的——羊毛毡的山与草地、棉布的屋、粗针脚缝边、木纽扣点缀;
圆润、微微歪扭的手作感;绘本摊平页的正视角;柔和均匀的光;能看清毡子纤维。

**共用 prompt 前缀(英文,直接拼在每条 prompt 前)**:

```
Hand-crafted wool felt diorama, children's picture-book craft style.
Everything sewn from wool felt and cotton fabric with visible hand stitches
in contrasting warm-brown thread, rounded chubby shapes, slightly imperfect
handmade charm, tiny wooden buttons as accents. Soft even front lighting,
photographed straight-on like a flat storybook page, macro felt fiber
texture clearly visible. Isolated single subject on fully transparent
background, no cast shadow, no ground plane, no text, no letters, no logos.
Palette: cream #FFF6E3, sage green #9CC08A, deep leaf green #6FA06B,
terracotta #D98A6A, dusty pink #EFB6B2, butter yellow #FFD98A, warm brown #5A4232.
```

**三条铁规**:
1. **图里不许出现任何文字**(中文英文都会画坏)。所有牌子、标签留空白,文字由代码用楷体叠上去。
2. **全部按白天中性光生成**。夜晚效果由代码调色,只有花房和小屋各生成一张"夜晚亮灯"变体。
3. **主体占满画面、背景透明**(风格定调图除外)。展示尺寸由代码控制,生成尺寸只按下表。

## 2. 一致性做法(先定调,再批量)

1. 先只生成 `style-key.png`(§3 第一条,不透明背景的小合集)。
2. 人眼确认风格对了(不对就改词重来,别继续)。
3. 其余每张都用**图像编辑接口 + style-key 作参考图**生成
   (脚本 `--ref garden/assets/style-key.png` 即此模式),或在 codex/ChatGPT 里把
   style-key 作为参考图附上。这样 22 张才像一套。

## 3. 第一批素材清单

尺寸只能取 1024x1024 / 1536x1024 / 1024x1536(接口限制)。
`※夜` = 需要额外夜晚变体。共 22 张。

| 文件 | 尺寸 | 内容 prompt(接在共用前缀后) |
|---|---|---|
| style-key.png | 1536x1024 | Style reference sheet on a plain cream backdrop: a small felt garden gate with an arched top, a round red felt mailbox on a stick with a yellow flag, one pink felt cosmos flower, one puffy white felt cloud, arranged loosely with space between them. |
| gate-frame.png | 1024x1024 | A garden gate frame: two chubby felt posts and an arched top rail, with a small blank wooden sign hanging from the arch. No door leaf. |
| gate-door.png | 1024x1536 | A single small picket gate door leaf made of felt over a wooden frame, hinge side on the left, slightly crooked pickets. |
| picket.png | 1024x1536 | One single fence picket, a chubby rounded felt-wrapped stick, cream colored with brown stitch edging. |
| mailbox.png | 1024x1536 | A round terracotta felt mailbox on a wooden stick post, small cream door on its front, its yellow felt flag folded DOWN. |
| mailbox-flag.png | 1024x1024 | A small yellow felt pennant flag on a short stick, stitched edge. |
| flowerbed.png | 1536x1024 | A long low raised flower bed: brown felt soil inside a border of stitched fabric logs, empty, no plants. |
| greenhouse.png | 1536x1024 | A small greenhouse with a gabled roof: cream felt frame, translucent white organza fabric as glass panels, stitched seams, closed fabric door. Daylight, unlit. |
| greenhouse-night.png | 1536x1024 | The same greenhouse at night: warm butter-yellow light glowing through its organza panels, everything else unchanged. |
| tree.png | 1024x1536 | A big friendly tree: brown felt trunk, three overlapping puffy deep-green felt canopy balls with visible stitches, one thick side branch extending right. |
| swing.png | 1024x1536 | A simple swing only: two twisted jute ropes and a small wooden-look felt seat plank, hanging straight down. |
| cottage.png | 1536x1024 | A small cottage: cream cotton walls, terracotta felt roof tiles in stitched rows, brown felt door, one round window with a cross of thread, a tiny chimney. Daylight, window dark. |
| cottage-night.png | 1536x1024 | The same cottage at night: the round window glowing warm butter yellow, everything else unchanged. |
| stream.png | 1024x1536 | A winding stream segment: layered blue felt water with white running-stitch wave lines, a few grey felt pebbles along the edges. |
| cloud-a.png | 1024x1024 | One puffy white felt cloud, three lobes, visible stitches. |
| cloud-b.png | 1024x1024 | A different smaller puffy white felt cloud, two lobes. |
| sun.png | 1024x1024 | A round butter-yellow felt sun with short stitched rays around it. |
| moon.png | 1024x1024 | A crescent moon in ivory felt with tiny embroidered stars stitched beside it. |
| sprout.png | 1024x1024 | A tiny seedling sprout: green felt stem and two round felt leaves. |
| bud.png | 1024x1024 | A young flower bud: green felt stem, one leaf, a closed pale-green felt bud. |
| flw-cosmos.png | 1024x1024 | A blooming cosmos flower: dusty pink felt petals around a butter-yellow button center, green felt stem and leaf. |
| flw-sunflower.png | 1024x1024 | A blooming sunflower: butter-yellow felt petals around a brown button center, sturdy green felt stem. |
| flw-glory.png | 1024x1024 | A blooming morning glory: soft blue felt trumpet flower with a cream throat, curling green felt vine stem. |

另有 3 张种子袋(kraft 纸小袋、空白标签):
`seed-cosmos.png / seed-sunflower.png / seed-glory.png`,1024x1024,
prompt:`A small kraft paper seed packet with a blank label patch, a few felt
[pink cosmos / yellow sunflower / blue morning glory] petals peeking out of the top.`
(算上这 3 张,第一批共 25 张。)

## 4. 第二批(v0.2 娃娃,先不生成)

- doll.png:the worry doll,手缝布娃娃,粗针脚、纽扣眼睛、胸前小布袋
- doll-pocket.png:摊开的小布袋
- boat.png:一只叠好的纸船(烦恼放下后漂走用)
- 缝娃娃界面用的布料样片 swatch-*.png ×4

## 5. 生成后交回

1. 全部 PNG 放 `garden/assets/`(文件名严格按上表)。
2. `git add garden/assets && git commit && git push` 到当前分支。
3. 回网页会话说"图好了"——由云端会话把 PNG 接进 `garden/index.html`
   (替换对应 SVG 元素、加夜晚调色、保留现有交互与降级逻辑)。

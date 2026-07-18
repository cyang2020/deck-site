#!/usr/bin/env node
/**
 * 针脚小园 · 素材批量生成脚本(零依赖,Node 18+)
 *
 *   export OPENAI_API_KEY=sk-...
 *   node garden/tools/gen-assets.mjs                 # 只生成 style-key.png(定调)
 *   node garden/tools/gen-assets.mjs --all           # 定调图确认满意后,生成其余全部
 *   node garden/tools/gen-assets.mjs --only cottage  # 只生成文件名含 cottage 的
 *   可选:--quality low|medium|high(默认 medium) --force(覆盖已存在) --dry(只打印)
 *
 * 已存在的文件默认跳过,可随时断点续跑。
 * 除 style-key 外,若 assets/style-key.png 存在,自动用它作参考图(edits 接口)保持整套一致;
 * 夜晚变体优先用对应白天图作参考。
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "assets");
const KEY = process.env.OPENAI_API_KEY;

const STYLE = `Hand-crafted wool felt diorama, children's picture-book craft style.
Everything sewn from wool felt and cotton fabric with visible hand stitches
in contrasting warm-brown thread, rounded chubby shapes, slightly imperfect
handmade charm, tiny wooden buttons as accents. Soft even front lighting,
photographed straight-on like a flat storybook page, macro felt fiber
texture clearly visible. Isolated single subject on fully transparent
background, no cast shadow, no ground plane, no text, no letters, no logos.
Palette: cream #FFF6E3, sage green #9CC08A, deep leaf green #6FA06B,
terracotta #D98A6A, dusty pink #EFB6B2, butter yellow #FFD98A, warm brown #5A4232.`;

const ITEMS = [
  { file: "style-key.png", size: "1536x1024", transparent: false, key: true,
    prompt: "Style reference sheet on a plain cream backdrop: a small felt garden gate with an arched top, a round red felt mailbox on a stick with a yellow flag, one pink felt cosmos flower, one puffy white felt cloud, arranged loosely with space between them." },
  { file: "gate-frame.png", size: "1024x1024",
    prompt: "A garden gate frame: two chubby felt posts and an arched top rail, with a small blank wooden sign hanging from the arch. No door leaf." },
  { file: "gate-door.png", size: "1024x1536",
    prompt: "A single small picket gate door leaf made of felt over a wooden frame, hinge side on the left, slightly crooked pickets." },
  { file: "picket.png", size: "1024x1536",
    prompt: "One single fence picket, a chubby rounded felt-wrapped stick, cream colored with brown stitch edging." },
  { file: "mailbox.png", size: "1024x1536",
    prompt: "A round terracotta felt mailbox on a wooden stick post, small cream door on its front, its yellow felt flag folded DOWN." },
  { file: "mailbox-flag.png", size: "1024x1024",
    prompt: "A small yellow felt pennant flag on a short stick, stitched edge." },
  { file: "flowerbed.png", size: "1536x1024",
    prompt: "A long low raised flower bed: brown felt soil inside a border of stitched fabric logs, empty, no plants." },
  { file: "greenhouse.png", size: "1536x1024",
    prompt: "A small greenhouse with a gabled roof: cream felt frame, translucent white organza fabric as glass panels, stitched seams, closed fabric door. Daylight, unlit." },
  { file: "greenhouse-night.png", size: "1536x1024", refSelf: "greenhouse.png",
    prompt: "The same greenhouse at night: warm butter-yellow light glowing through its organza panels, everything else unchanged." },
  { file: "tree.png", size: "1024x1536",
    prompt: "A big friendly tree: brown felt trunk, three overlapping puffy deep-green felt canopy balls with visible stitches, one thick side branch extending right." },
  { file: "swing.png", size: "1024x1536",
    prompt: "A simple swing only: two twisted jute ropes and a small wooden-look felt seat plank, hanging straight down." },
  { file: "cottage.png", size: "1536x1024",
    prompt: "A small cottage: cream cotton walls, terracotta felt roof tiles in stitched rows, brown felt door, one round window with a cross of thread, a tiny chimney. Daylight, window dark." },
  { file: "cottage-night.png", size: "1536x1024", refSelf: "cottage.png",
    prompt: "The same cottage at night: the round window glowing warm butter yellow, everything else unchanged." },
  { file: "stream.png", size: "1024x1536",
    prompt: "A winding stream segment: layered blue felt water with white running-stitch wave lines, a few grey felt pebbles along the edges." },
  { file: "cloud-a.png", size: "1024x1024",
    prompt: "One puffy white felt cloud, three lobes, visible stitches." },
  { file: "cloud-b.png", size: "1024x1024",
    prompt: "A different smaller puffy white felt cloud, two lobes." },
  { file: "sun.png", size: "1024x1024",
    prompt: "A round butter-yellow felt sun with short stitched rays around it." },
  { file: "moon.png", size: "1024x1024",
    prompt: "A crescent moon in ivory felt with tiny embroidered stars stitched beside it." },
  { file: "sprout.png", size: "1024x1024",
    prompt: "A tiny seedling sprout: green felt stem and two round felt leaves." },
  { file: "bud.png", size: "1024x1024",
    prompt: "A young flower bud: green felt stem, one leaf, a closed pale-green felt bud." },
  { file: "flw-cosmos.png", size: "1024x1024",
    prompt: "A blooming cosmos flower: dusty pink felt petals around a butter-yellow button center, green felt stem and leaf." },
  { file: "flw-sunflower.png", size: "1024x1024",
    prompt: "A blooming sunflower: butter-yellow felt petals around a brown button center, sturdy green felt stem." },
  { file: "flw-glory.png", size: "1024x1024",
    prompt: "A blooming morning glory: soft blue felt trumpet flower with a cream throat, curling green felt vine stem." },
  { file: "seed-cosmos.png", size: "1024x1024",
    prompt: "A small kraft paper seed packet with a blank label patch, a few pink felt cosmos petals peeking out of the top." },
  { file: "seed-sunflower.png", size: "1024x1024",
    prompt: "A small kraft paper seed packet with a blank label patch, a few yellow felt sunflower petals peeking out of the top." },
  { file: "seed-glory.png", size: "1024x1024",
    prompt: "A small kraft paper seed packet with a blank label patch, a few blue felt morning glory petals peeking out of the top." },
];

const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const QUALITY = opt("--quality", "medium");
const ONLY = opt("--only", null);
const DRY = flag("--dry");
const FORCE = flag("--force");
const ALL = flag("--all");

if (!KEY && !DRY) { console.error("缺 OPENAI_API_KEY(export OPENAI_API_KEY=sk-...)"); process.exit(1); }
mkdirSync(OUT, { recursive: true });

const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function callOpenAI(item, refPath) {
  const prompt = STYLE + "\n\n" + item.prompt;
  let res;
  for (let attempt = 1; attempt <= 3; attempt++) {
    if (refPath) {
      const fd = new FormData();
      fd.append("model", "gpt-image-1");
      fd.append("prompt", "Match exactly the craft style, materials, stitching and palette of the reference image. " + prompt);
      fd.append("size", item.size);
      fd.append("quality", QUALITY);
      fd.append("background", item.transparent === false ? "opaque" : "transparent");
      fd.append("image[]", new Blob([readFileSync(refPath)], { type: "image/png" }), "ref.png");
      res = await fetch("https://api.openai.com/v1/images/edits", {
        method: "POST", headers: { Authorization: `Bearer ${KEY}` }, body: fd,
      });
    } else {
      res = await fetch("https://api.openai.com/v1/images/generations", {
        method: "POST",
        headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "gpt-image-1", prompt, size: item.size, quality: QUALITY,
          background: item.transparent === false ? "opaque" : "transparent",
          output_format: "png",
        }),
      });
    }
    if (res.ok) break;
    const body = await res.text();
    if ((res.status === 429 || res.status >= 500) && attempt < 3) {
      console.log(`  ${res.status},${attempt * 15}s 后重试…`);
      await wait(attempt * 15000);
      continue;
    }
    throw new Error(`${item.file}: HTTP ${res.status} ${body.slice(0, 300)}`);
  }
  const json = await res.json();
  return Buffer.from(json.data[0].b64_json, "base64");
}

(async () => {
  let todo = ITEMS.filter((it) => (ONLY ? it.file.includes(ONLY) : ALL ? true : it.key));
  if (!todo.length) { console.log("没有匹配的条目。"); return; }
  const styleKey = join(OUT, "style-key.png");
  let done = 0, skipped = 0;
  for (const it of todo) {
    const out = join(OUT, it.file);
    if (existsSync(out) && !FORCE) { console.log(`跳过(已存在) ${it.file}`); skipped++; continue; }
    let ref = null;
    if (!it.key) {
      if (it.refSelf && existsSync(join(OUT, it.refSelf))) ref = join(OUT, it.refSelf);
      else if (existsSync(styleKey)) ref = styleKey;
    }
    console.log(`生成 ${it.file}(${it.size}, ${QUALITY}${ref ? ", 带参考图" : ""})…`);
    if (DRY) continue;
    const png = await callOpenAI(it, ref);
    writeFileSync(out, png);
    console.log(`  ✓ ${it.file} ${(png.length / 1024).toFixed(0)}KB`);
    done++;
  }
  console.log(`\n完成 ${done} 张,跳过 ${skipped} 张。`);
  if (!ALL && !ONLY) console.log("style-key 满意后,跑:node garden/tools/gen-assets.mjs --all");
})().catch((e) => { console.error("失败:", e.message); process.exit(1); });

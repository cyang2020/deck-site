#!/usr/bin/env node
/**
 * 从 garden/index.html 构建 Artifact 版单文件:
 * 取 <body>…</body> 内容,把静态与运行时用到的素材全部内联。
 * 有 playwright-core 时(推荐,在装了它的目录里跑),每张图缩到 ≤700px 并转 WebP(约 1/10 体积);
 * 否则原样内联 PNG。
 *
 *   node garden/tools/build-artifact.mjs --out /path/garden-artifact.html [--max 700] [--q 0.8]
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const OUT = opt("--out", join(ROOT, "artifact-build.html"));
const MAX = parseInt(opt("--max", "700"), 10);
const Q = parseFloat(opt("--q", "0.8"));

/* 运行时动态拼接路径的素材(种子袋、花的阶段、昼夜建筑) */
const DYN = ["sprout","bud","flw-cosmos","flw-sunflower","flw-glory",
             "seed-cosmos","seed-sunflower","seed-glory",
             "greenhouse","greenhouse-night","cottage","cottage-night"];

function loadPlaywright() {
  for (const base of [join(process.cwd(), "noop.js"), import.meta.url]) {
    try { return createRequire(base)("playwright-core"); } catch { /* next */ }
  }
  return null;
}

const html = readFileSync(join(ROOT, "index.html"), "utf8");
const m = html.match(/<body>\n([\s\S]*)\n<\/body>/);
if (!m) { console.error("找不到 <body> 段"); process.exit(1); }
let content = m[1];

const files = new Set(DYN.map(f => f + ".png"));
for (const mm of content.matchAll(/(?:href|src)="assets\/([\w.-]+\.png)"/g)) files.add(mm[1]);

(async () => {
  const uris = new Map();
  const pw = loadPlaywright();
  let page = null, browser = null;
  if (pw) {
    browser = await pw.chromium.launch({ executablePath: "/opt/pw-browsers/chromium", args: ["--no-sandbox"] });
    page = await browser.newPage();
  }
  let total = 0;
  for (const f of files) {
    const buf = readFileSync(join(ROOT, "assets", f));
    if (!page) { uris.set(f, "data:image/png;base64," + buf.toString("base64")); total += buf.length; continue; }
    await page.setContent('<img id="src" src="data:image/png;base64,' + buf.toString("base64") + '">');
    await page.waitForFunction(() => { const i = document.getElementById("src"); return i && i.complete && i.naturalWidth > 0; }, { timeout: 30000 });
    const uri = await page.evaluate(([MAX, Q]) => {
      const img = document.getElementById("src");
      const s = Math.min(1, MAX / Math.max(img.naturalWidth, img.naturalHeight));
      const c = document.createElement("canvas");
      c.width = Math.round(img.naturalWidth * s); c.height = Math.round(img.naturalHeight * s);
      const ctx = c.getContext("2d");
      ctx.imageSmoothingQuality = "high";
      ctx.drawImage(img, 0, 0, c.width, c.height);
      return c.toDataURL("image/webp", Q);
    }, [MAX, Q]);
    uris.set(f, uri);
    total += uri.length * 0.75;
  }
  if (browser) await browser.close();

  content = content.replace(/(href|src)="assets\/([\w.-]+\.png)"/g, (_, attr, f) => attr + '="' + uris.get(f) + '"');
  let dynMap = "window.__ASSETS={";
  for (const f of DYN) dynMap += JSON.stringify(f) + ":" + JSON.stringify(uris.get(f + ".png")) + ",";
  dynMap += "};";
  content = '<meta charset="utf-8">\n<script>' + dynMap + "<\/script>\n" + content;

  writeFileSync(OUT, content);
  console.log(`写出 ${OUT}(素材 ${(total / 1048576).toFixed(1)}MB,总大小 ${(content.length / 1048576).toFixed(1)}MB,${page ? "webp压缩" : "png原样"})`);
})().catch(e => { console.error("build 失败:", e); process.exit(1); });

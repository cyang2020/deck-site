#!/usr/bin/env node
/**
 * 绿幕抠图:把 PNG 的纯绿背景(#00FF00 附近)变成真透明。
 * 用 playwright-core + 无头 Chromium 的 canvas 处理,不需要图像库。
 *
 *   node garden/tools/chromakey.mjs [--dir garden/assets] [--only cottage]
 *
 * 在能 require 到 playwright-core 的目录跑(或先 npm i playwright-core)。
 * 默认原地覆盖并保留 .orig.png 备份;style-key.png 自动跳过。
 */
import { readdirSync, existsSync, copyFileSync, writeFileSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const DIR = opt("--dir", join(dirname(fileURLToPath(import.meta.url)), "..", "assets"));
const ONLY = opt("--only", null);
const MAX = parseInt(opt("--max", "900"), 10);

function loadPlaywright() {
  for (const base of [join(process.cwd(), "noop.js"), import.meta.url]) {
    try { return createRequire(base)("playwright-core"); } catch { /* next */ }
  }
  return null;
}
const pw = loadPlaywright();
if (!pw) { console.error("找不到 playwright-core:先在当前目录 npm i playwright-core"); process.exit(1); }

const files = readdirSync(DIR).filter(f =>
  f.endsWith(".png") && !f.endsWith(".orig.png") && f !== "style-key.png" && (!ONLY || f.includes(ONLY)));
if (!files.length) { console.log("没有要处理的 PNG。"); process.exit(0); }

(async () => {
  const browser = await pw.chromium.launch({ executablePath: "/opt/pw-browsers/chromium", args: ["--no-sandbox"] });
  const page = await browser.newPage();
  for (const f of files) {
    const full = join(DIR, f);
    const b64 = readFileSync(full).toString("base64");
    await page.setContent('<img id="src" src="data:image/png;base64,' + b64 + '">');
    await page.waitForFunction(() => {
      const i = document.getElementById("src");
      return i && i.complete && i.naturalWidth > 0;
    }, { timeout: 30000 });
    const r = await page.evaluate((MAX) => {
      const img = document.getElementById("src");
      const c = document.createElement("canvas");
      c.width = img.naturalWidth; c.height = img.naturalHeight;
      const ctx = c.getContext("2d");
      ctx.drawImage(img, 0, 0);
      const d = ctx.getImageData(0, 0, c.width, c.height);
      const p = d.data;
      let greenish = 0;
      for (let i = 0; i < p.length; i += 4) {
        const r0 = p[i], g = p[i + 1], b = p[i + 2];
        const dom = g - Math.max(r0, b);
        if (g > 160 && dom > 90) { p[i + 3] = 0; greenish++; }
        else if (g > 120 && dom > 40) {
          const t = Math.min(1, (dom - 40) / 60);
          p[i + 3] = Math.round(p[i + 3] * (1 - t));
          p[i + 1] = Math.max(0, g - Math.round(dom * 0.6));
          greenish++;
        }
      }
      ctx.putImageData(d, 0, 0);
      let outCanvas = c;
      if (Math.max(c.width, c.height) > MAX) {
        const s = MAX / Math.max(c.width, c.height);
        const c2 = document.createElement("canvas");
        c2.width = Math.round(c.width * s); c2.height = Math.round(c.height * s);
        const ctx2 = c2.getContext("2d");
        ctx2.imageSmoothingQuality = "high";
        ctx2.drawImage(c, 0, 0, c2.width, c2.height);
        outCanvas = c2;
      }
      return { out: greenish > 100 ? outCanvas.toDataURL("image/png") : null,
               greenish, w: outCanvas.width, h: outCanvas.height };
    }, MAX);
    if (!r.out) { console.log(`跳过 ${f}(未检测到绿幕,greenish=${r.greenish})`); continue; }
    const orig = full.replace(/\.png$/, ".orig.png");
    if (!existsSync(orig)) copyFileSync(full, orig);
    writeFileSync(full, Buffer.from(r.out.split(",")[1], "base64"));
    console.log(`✓ ${f} ${r.w}x${r.h} 处理了 ${r.greenish} 个绿像素`);
  }
  await browser.close();
  console.log("完成。");
})().catch((e) => { console.error("chromakey 失败:", e); process.exit(1); });

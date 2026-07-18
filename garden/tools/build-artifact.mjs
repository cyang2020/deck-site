#!/usr/bin/env node
/**
 * 从 garden/index.html 构建 Artifact 版单文件:
 * 取 <body>…</body> 内容,把 href="assets/*.png" 内联成 data URI。
 *
 *   node garden/tools/build-artifact.mjs --out /path/garden-artifact.html
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const OUT = opt("--out", join(ROOT, "artifact-build.html"));

const html = readFileSync(join(ROOT, "index.html"), "utf8");
const m = html.match(/<body>\n([\s\S]*)\n<\/body>/);
if (!m) { console.error("找不到 <body> 段"); process.exit(1); }
let content = m[1];

let total = 0;
content = content.replace(/href="assets\/([\w.-]+\.png)"/g, (_, f) => {
  const buf = readFileSync(join(ROOT, "assets", f));
  total += buf.length;
  return 'href="data:image/png;base64,' + buf.toString("base64") + '"';
});

writeFileSync(OUT, content);
console.log(`写出 ${OUT}(内联素材 ${(total / 1048576).toFixed(1)}MB,总大小 ${(content.length / 1048576).toFixed(1)}MB)`);

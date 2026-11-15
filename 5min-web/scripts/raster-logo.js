/**
 * Copyright 2026 学记宝 / heanbian
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
'use strict';

/**
 * 从 Android 同款 App 图标生成 Web favicon / apple-touch / logo.png。
 * 依赖本机 `sips`（macOS）。运行：node scripts/raster-logo.js
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const root = path.join(__dirname, '..');
const repoRoot = path.join(root, '..');
const srcCandidates = [
  path.join(repoRoot, '5min-android-app/store/artwork/ic_launcher_512.png'),
  path.join(repoRoot, '5min-ios-app/store/artwork/ic_launcher_512.png'),
  path.join(repoRoot, '5min-ios-app/FiveMin/Assets.xcassets/AppIcon.appiconset/AppIcon.png'),
];
const src = srcCandidates.find((p) => fs.existsSync(p));
if (!src) {
  console.error('未找到 App 图标源文件');
  process.exit(1);
}

const imgDir = path.join(root, 'public', 'img');
fs.mkdirSync(imgDir, { recursive: true });

function sipsResize(size, outPath) {
  const r = spawnSync('sips', ['-z', String(size), String(size), src, '--out', outPath], {
    encoding: 'utf8',
  });
  if (r.status !== 0) {
    console.error(r.stderr || r.stdout || 'sips failed');
    process.exit(1);
  }
}

function ico(images) {
  const count = images.length;
  let offset = 6 + count * 16;
  const entries = images.map((image) => {
    const entry = Buffer.alloc(16);
    entry.writeUInt8(image.size >= 256 ? 0 : image.size, 0);
    entry.writeUInt8(image.size >= 256 ? 0 : image.size, 1);
    entry.writeUInt16LE(0, 2);
    entry.writeUInt16LE(1, 4);
    entry.writeUInt16LE(32, 6);
    entry.writeUInt32LE(image.png.length, 8);
    entry.writeUInt32LE(offset, 12);
    offset += image.png.length;
    return entry;
  });
  const head = Buffer.alloc(6);
  head.writeUInt16LE(0, 0);
  head.writeUInt16LE(1, 2);
  head.writeUInt16LE(count, 4);
  return Buffer.concat([head, ...entries, ...images.map((image) => image.png)]);
}

const out16 = path.join(imgDir, 'favicon-16.png');
const out32 = path.join(imgDir, 'favicon-32.png');
const out180 = path.join(imgDir, 'apple-touch-icon.png');
const out512 = path.join(imgDir, 'logo.png');

sipsResize(16, out16);
sipsResize(32, out32);
sipsResize(180, out180);
sipsResize(512, out512);

fs.writeFileSync(
  path.join(root, 'public', 'favicon.ico'),
  ico([
    { size: 16, png: fs.readFileSync(out16) },
    { size: 32, png: fs.readFileSync(out32) },
  ])
);

console.log('已从 App 图标生成: favicon.ico / favicon-32.png / apple-touch-icon.png / logo.png');
console.log('源:', src);

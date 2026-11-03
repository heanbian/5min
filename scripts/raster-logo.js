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

const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const root = path.join(__dirname, '..');
const svg = fs.readFileSync(path.join(root, 'img/logo.svg'));

function png(size) {
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: size }
  });
  return resvg.render().asPng();
}

function ico(images) {
  const count = images.length;
  const header = 6 + count * 16;
  let offset = header;
  const entries = images.map((image) => {
    const entry = Buffer.alloc(16);
    entry.writeUInt8(image.size >= 256 ? 0 : image.size, 0);
    entry.writeUInt8(image.size >= 256 ? 0 : image.size, 1);
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

const img = path.join(root, 'img');
fs.writeFileSync(path.join(img, 'apple-touch-icon.png'), png(180));
fs.writeFileSync(path.join(img, 'logo.png'), png(512));
fs.writeFileSync(
  path.join(root, 'favicon.ico'),
  ico([
    { size: 16, png: png(16) },
    { size: 32, png: png(32) }
  ])
);
console.log('logo.png / apple-touch-icon.png / favicon.ico 已写出');

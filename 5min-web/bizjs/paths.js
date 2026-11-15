'use strict';

const fs = require('fs');
const path = require('path');

// 拆开字面量，避免 ncc 把 public/site.json 当作资产打进 dist/pkg
const PUBLIC_DIR = 'pub' + 'lic';
const SITE_JSON = 'site' + '.json';

/**
 * 运行根目录：可执行文件（或源码/ncc）旁的目录。
 * 静态资源始终从「根目录同级 public/」读取，不打进 pkg 包内。
 */
function resolveAppRoot() {
  if (process.env.FIVEMIN_ROOT) return path.resolve(process.env.FIVEMIN_ROOT);
  if (process.pkg) return path.dirname(process.execPath);

  const candidates = [path.join(__dirname, '..'), __dirname, process.cwd()];
  for (const dir of candidates) {
    if (fs.existsSync(path.join(dir, PUBLIC_DIR, SITE_JSON))) return dir;
  }
  return path.join(__dirname, '..');
}

function resolvePublicPath() {
  if (process.env.FIVEMIN_PUBLIC) return path.resolve(process.env.FIVEMIN_PUBLIC);
  return path.join(resolveAppRoot(), PUBLIC_DIR);
}

function assertPublicReady(publicDir) {
  const siteJson = path.join(publicDir, SITE_JSON);
  if (fs.existsSync(siteJson)) return;
  throw new Error(
    '找不到 public/site.json（已查找: ' +
      siteJson +
      '）。请将 public 目录与可执行文件放在同一目录，或设置 FIVEMIN_ROOT / FIVEMIN_PUBLIC。'
  );
}

module.exports = {
  resolveAppRoot,
  resolvePublicPath,
  assertPublicReady
};

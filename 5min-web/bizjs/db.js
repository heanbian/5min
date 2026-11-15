'use strict';

const path = require('path');
const fs = require('fs');
const dotenv = require('dotenv');
const { Pool } = require('pg');

function findConfigPath() {
  if (process.env.DOTENV_CONFIG_PATH) return process.env.DOTENV_CONFIG_PATH;
  const { resolveAppRoot } = require('./paths');
  const cwdPath = path.join(process.cwd(), 'server.conf');
  if (fs.existsSync(cwdPath)) return cwdPath;
  const rootPath = path.join(resolveAppRoot(), 'server.conf');
  if (fs.existsSync(rootPath)) return rootPath;
  return cwdPath;
}

const configPath = findConfigPath();
dotenv.config({
  path: configPath,
  override: true
});

const requiredEnv = ['DB_HOST', 'DB_PORT', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
const missing = requiredEnv.filter((name) => !process.env[name]);
if (missing.length > 0) {
  throw new Error('缺少数据库配置: ' + missing.join(', '));
}

const pool = new Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT, 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  max: Math.min(50, Math.max(2, Number(process.env.DB_POOL_MAX) || 10)),
  idleTimeoutMillis: 20000,
  connectionTimeoutMillis: 5000,
  statement_timeout: 15000,
  ssl:
    process.env.DB_SSL === '1' || String(process.env.DB_SSL || '').toLowerCase() === 'true'
      ? { rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false' }
      : undefined
});

pool.on('error', (err) => {
  console.error('数据库连接异常: ' + (err && err.message ? err.message : err));
});

module.exports = pool;

'use strict';

const express = require('express');
const cloud = require('../bizjs/cloud-storage');

function sendOk(res, data) {
  res.json({ success: true, data });
}

function sendErr(res, status, message) {
  res.status(status).json({ success: false, message: String(message || '错误') });
}

/** 简易全局限流：每 IP 每分钟最多 N 次写操作；注册单独更严，抑制刷库。 */
const writeHits = new Map();
const registerHits = new Map();
const WRITE_LIMIT = 60;
const REGISTER_LIMIT = 10;
const WRITE_WINDOW_MS = 60 * 1000;

function clientIp(req) {
  return String((req && req.ip) || req.socket?.remoteAddress || '')
    .replace(/^::ffff:/i, '')
    .slice(0, 64);
}

function allowLimited(map, ip, limit) {
  const now = Date.now();
  const row = map.get(ip);
  if (!row || now - row.start >= WRITE_WINDOW_MS) {
    map.set(ip, { start: now, count: 1 });
    if (map.size > 5000) {
      for (const [k, v] of map) {
        if (now - v.start >= WRITE_WINDOW_MS) map.delete(k);
      }
    }
    return true;
  }
  if (row.count >= limit) return false;
  row.count += 1;
  return true;
}

function allowWrite(req) {
  return allowLimited(writeHits, clientIp(req) || 'unknown', WRITE_LIMIT);
}

function allowRegister(req) {
  return allowLimited(registerHits, clientIp(req) || 'unknown', REGISTER_LIMIT);
}

function registerStorageRoutes(app) {
  const router = express.Router();
  router.use(express.json({ limit: '256kb' }));

  router.post('/register', async (req, res) => {
    try {
      if (!allowRegister(req) || !allowWrite(req)) return sendErr(res, 429, '请求过于频繁');
      const deviceId = String(req.body?.deviceId || '');
      const deviceSecret = String(req.body?.deviceSecret || '');
      const result = await cloud.registerDevice(deviceId, deviceSecret);
      if (!result.ok) return sendErr(res, result.status, result.message);
      return sendOk(res, result.data);
    } catch (err) {
      console.error('storage register', err && err.message ? err.message : err);
      return sendErr(res, 500, '注册失败');
    }
  });

  router.get('/snapshot', async (req, res) => {
    try {
      const auth = await cloud.authenticate(req);
      if (!auth.ok) return sendErr(res, auth.status, auth.message);
      const data = await cloud.getSnapshot(auth.deviceId);
      return sendOk(res, data);
    } catch (err) {
      console.error('storage snapshot get', err && err.message ? err.message : err);
      return sendErr(res, 500, '读取失败');
    }
  });

  router.put('/prefs', async (req, res) => {
    try {
      if (!allowWrite(req)) return sendErr(res, 429, '请求过于频繁');
      const auth = await cloud.authenticate(req);
      if (!auth.ok) return sendErr(res, auth.status, auth.message);
      const prefs = await cloud.putPrefs(auth.deviceId, req.body?.prefs || req.body || {});
      return sendOk(res, { prefs });
    } catch (err) {
      console.error('storage prefs put', err && err.message ? err.message : err);
      return sendErr(res, 500, '保存失败');
    }
  });

  router.put('/sessions', async (req, res) => {
    try {
      if (!allowWrite(req)) return sendErr(res, 429, '请求过于频繁');
      const auth = await cloud.authenticate(req);
      if (!auth.ok) return sendErr(res, auth.status, auth.message);
      const result = await cloud.upsertSessions(auth.deviceId, req.body?.sessions || []);
      return sendOk(res, result);
    } catch (err) {
      console.error('storage sessions put', err && err.message ? err.message : err);
      return sendErr(res, 500, '同步失败');
    }
  });

  router.put('/snapshot', async (req, res) => {
    try {
      if (!allowWrite(req)) return sendErr(res, 429, '请求过于频繁');
      const auth = await cloud.authenticate(req);
      if (!auth.ok) return sendErr(res, auth.status, auth.message);
      let prefs = null;
      if (req.body?.prefs != null) {
        prefs = await cloud.putPrefs(auth.deviceId, req.body.prefs);
      }
      let sessions = null;
      if (Array.isArray(req.body?.sessions)) {
        sessions = await cloud.upsertSessions(auth.deviceId, req.body.sessions);
      }
      const snap = await cloud.getSnapshot(auth.deviceId);
      return sendOk(res, { ...snap, written: { prefs: !!prefs, sessions } });
    } catch (err) {
      console.error('storage snapshot put', err && err.message ? err.message : err);
      return sendErr(res, 500, '同步失败');
    }
  });

  router.delete('/sessions/:clientId', async (req, res) => {
    try {
      if (!allowWrite(req)) return sendErr(res, 429, '请求过于频繁');
      const auth = await cloud.authenticate(req);
      if (!auth.ok) return sendErr(res, auth.status, auth.message);
      const result = await cloud.deleteSession(auth.deviceId, req.params.clientId);
      if (!result.ok) return sendErr(res, result.status, result.message);
      return sendOk(res, { deleted: true });
    } catch (err) {
      console.error('storage session delete', err && err.message ? err.message : err);
      return sendErr(res, 500, '删除失败');
    }
  });

  router.post('/sessions/clear', async (req, res) => {
    try {
      if (!allowWrite(req)) return sendErr(res, 429, '请求过于频繁');
      const auth = await cloud.authenticate(req);
      if (!auth.ok) return sendErr(res, auth.status, auth.message);
      await cloud.clearSessions(auth.deviceId);
      return sendOk(res, { cleared: true });
    } catch (err) {
      console.error('storage sessions clear', err && err.message ? err.message : err);
      return sendErr(res, 500, '清空失败');
    }
  });

  app.use('/api/v1/storage', router);
}

module.exports = registerStorageRoutes;

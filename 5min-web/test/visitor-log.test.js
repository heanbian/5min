'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isPrivateIp,
  isLiteralIp,
  sanitizeQuery,
  sanitizeReferer,
  shouldRecord
} = require('../bizjs/visitor-log');

test('isPrivateIp 识别内网与回环', () => {
  assert.equal(isPrivateIp('127.0.0.1'), true);
  assert.equal(isPrivateIp('127.0.0.2'), true);
  assert.equal(isPrivateIp('::1'), true);
  assert.equal(isPrivateIp('10.0.0.2'), true);
  assert.equal(isPrivateIp('192.168.1.1'), true);
  assert.equal(isPrivateIp('172.16.0.1'), true);
  assert.equal(isPrivateIp('100.64.1.1'), true);
  assert.equal(isPrivateIp('8.8.8.8'), false);
});

test('isLiteralIp 拒绝主机名以防 SSRF', () => {
  assert.equal(isLiteralIp('8.8.8.8'), true);
  assert.equal(isLiteralIp('2001:db8::1'), true);
  assert.equal(isLiteralIp('evil.example.com'), false);
  assert.equal(isLiteralIp('8.8.8.8.nip.io'), false);
  assert.equal(isLiteralIp('999.1.1.1'), false);
  assert.equal(isLiteralIp('01.2.3.4'), false);
});

test('sanitizeQuery 剥离敏感参数', () => {
  assert.equal(sanitizeQuery('lang=zh-CN&token=secret&state=abc'), 'lang=zh-CN');
  assert.equal(sanitizeQuery(''), '');
});

test('sanitizeReferer 清理查询串中的令牌', () => {
  const cleaned = sanitizeReferer('https://example.com/cb?code=xyz&lang=en');
  assert.match(cleaned, /^https:\/\/example\.com\/cb/);
  assert.equal(/code=/.test(cleaned), false);
  assert.match(cleaned, /lang=en/);
});

test('shouldRecord 仅记录页面 GET', () => {
  assert.equal(shouldRecord({ method: 'GET', path: '/', url: '/' }), true);
  assert.equal(shouldRecord({ method: 'GET', path: '/about.html', url: '/about.html' }), true);
  assert.equal(shouldRecord({ method: 'POST', path: '/', url: '/' }), false);
  assert.equal(shouldRecord({ method: 'GET', path: '/api/status', url: '/api/status' }), false);
  assert.equal(shouldRecord({ method: 'GET', path: '/js/app.js', url: '/js/app.js' }), false);
});

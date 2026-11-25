/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * Pure timer helpers used by the home page controller.
 */

function pad2(n) {
  return String(n).padStart(2, '0');
}

function formatTime(ms) {
  const totalSec = Math.max(0, Math.ceil(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${pad2(s)}`;
}

function formatOvertime(ms) {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  if (m > 0) return `${m}:${pad2(s)}`;
  return `0:${pad2(s)}`;
}

function visualPhase(remainMs, running, finished, warnMs) {
  if (finished || remainMs <= 0) return 'done';
  if (remainMs <= warnMs) return 'warn';
  if (running) return 'running';
  return 'idle';
}

function phaseColor(phase, kind) {
  if (phase === 'warn') return '#c9862d';
  if (phase === 'done') return '#d2554a';
  if (kind === 'ring') return '#2f9a68';
  return '#000000';
}

module.exports = {
  pad2,
  formatTime,
  formatOvertime,
  visualPhase,
  phaseColor,
};

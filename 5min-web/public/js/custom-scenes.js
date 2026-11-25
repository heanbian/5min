/**
 * Copyright 2026 学记宝 / xuejibao.com
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

/**
 * Custom scene CRUD (localStorage) — parity with MP prefs custom scenes.
 * Names are plain text only (callers must use textContent, never innerHTML).
 */

export const STORAGE_KEY = '5min.custom_scenes';
export const GROUP_ID = 'custom';
export const ID_PREFIX = 'custom_';
export const MAX_COUNT = 30;
export const MAX_NAME = 24;
export const MIN_MINUTES = 1;
export const MAX_MINUTES = 90;

const makeId = () => {
  const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
  return ID_PREFIX + uuid;
};

/** Strip control chars / HTML-ish markup; trim; length-cap. */
export const sanitizeName = (raw) => {
  let s = String(raw == null ? '' : raw)
    .replace(/[\u0000-\u001F\u007F]/g, '')
    .replace(/[<>]/g, '')
    .trim();
  if (s.length > MAX_NAME) s = s.slice(0, MAX_NAME);
  return s;
};

export const clampMinutes = (value) => {
  const n = Math.floor(Number(value) || 0);
  return Math.max(MIN_MINUTES, Math.min(MAX_MINUTES, n));
};

const sanitizeScene = (raw) => {
  if (!raw || typeof raw !== 'object') return null;
  const name = sanitizeName(raw.name);
  if (!name) return null;
  const id = String(raw.id || '').trim() || makeId();
  // Reject ids that look like built-in scenes without prefix when empty name already handled
  return {
    id,
    name,
    min: clampMinutes(raw.min),
  };
};

const readAll = () => {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.map(sanitizeScene).filter(Boolean).slice(0, MAX_COUNT);
  } catch {
    return [];
  }
};

const writeAll = (list) => {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list.slice(0, MAX_COUNT)));
  } catch {
    /* private mode / quota */
  }
};

/** @returns {{id:string,name:string,min:number}[]} */
export const listCustomScenes = () => readAll();

/** @param {string} id */
export const getCustomScene = (id) => {
  const sid = String(id || '');
  if (!sid) return null;
  return readAll().find((s) => s.id === sid) || null;
};

/**
 * @param {string} name
 * @param {number} min
 * @returns {{id:string,name:string,min:number}|null}
 */
export const addCustomScene = (name, min) => {
  const list = readAll();
  if (list.length >= MAX_COUNT) return null;
  const cleaned = sanitizeName(name);
  if (!cleaned) return null;
  const scene = { id: makeId(), name: cleaned, min: clampMinutes(min) };
  list.push(scene);
  writeAll(list);
  return scene;
};

/**
 * @param {string} id
 * @param {string} name
 * @param {number} min
 * @returns {{id:string,name:string,min:number}|null}
 */
export const updateCustomScene = (id, name, min) => {
  const list = readAll();
  const idx = list.findIndex((s) => s.id === id);
  if (idx < 0) return null;
  const cleaned = sanitizeName(name);
  if (!cleaned) return null;
  list[idx] = { id: list[idx].id, name: cleaned, min: clampMinutes(min) };
  writeAll(list);
  return list[idx];
};

/** @param {string} id */
export const deleteCustomScene = (id) => {
  const sid = String(id || '');
  if (!sid) return;
  writeAll(readAll().filter((s) => s.id !== sid));
};


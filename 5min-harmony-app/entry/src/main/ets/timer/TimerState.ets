export type TimerPhase = 'idle' | 'running' | 'paused' | 'warn' | 'done';

export class TimerState {
  locale: string = 'zh-CN';
  totalMs: number = 5 * 60 * 1000;
  remainMs: number = 5 * 60 * 1000;
  running: boolean = false;
  finished: boolean = false;
  activeSceneId: string = '';
  ambient: string = 'off';
  statsCount: number = 0;
  statsMs: number = 0;
  phase: TimerPhase = 'idle';
  endAt: number = 0;

  progress(): number {
    if (this.totalMs <= 0) {
      return 0;
    }
    const p = this.remainMs / this.totalMs;
    if (p < 0) {
      return 0;
    }
    if (p > 1) {
      return 1;
    }
    return p;
  }
}

export function formatMs(ms: number): string {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  const ss = s < 10 ? `0${s}` : `${s}`;
  return `${m}:${ss}`;
}

export function phaseOf(state: TimerState): TimerPhase {
  if (state.finished || (state.remainMs <= 0 && !state.running)) {
    return 'done';
  }
  if (state.running && state.remainMs > 0 && state.remainMs <= 60000) {
    return 'warn';
  }
  if (state.running) {
    return 'running';
  }
  if (state.remainMs < state.totalMs) {
    return 'paused';
  }
  return 'idle';
}

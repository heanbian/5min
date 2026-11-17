import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '5minAmbient';
const SAMPLE_RATE = 44100;
const CHUNK_FRAMES = 1024;

/**
 * Procedural ambient loops (rain / waves / clock) via AudioRenderer — no media assets.
 * Mirrors 5min-web ambient.js behaviour; start from a user gesture when possible.
 */
export class AmbientPlayer {
  private static mode: string = 'off';
  private static renderer: audio.AudioRenderer | null = null;
  private static writing: boolean = false;
  private static phase: number = 0;
  private static tickRemain: number = 0;
  private static swellGain: number = 0.35;
  private static swellTarget: number = 0.35;
  private static swellFramesLeft: number = 0;
  private static noiseState: number = 0;

  static getMode(): string {
    return AmbientPlayer.mode;
  }

  static async setMode(mode: string): Promise<void> {
    const next = (mode === 'rain' || mode === 'waves' || mode === 'clock') ? mode : 'off';
    if (next === AmbientPlayer.mode && (next === 'off' || AmbientPlayer.renderer !== null)) {
      return;
    }
    await AmbientPlayer.stopInternal(false);
    AmbientPlayer.mode = next;
    if (next === 'off') {
      return;
    }
    await AmbientPlayer.start(next);
  }

  static async stop(): Promise<void> {
    await AmbientPlayer.stopInternal(true);
  }

  private static async stopInternal(resetMode: boolean): Promise<void> {
    AmbientPlayer.writing = false;
    if (resetMode) {
      AmbientPlayer.mode = 'off';
    }
    const r = AmbientPlayer.renderer;
    AmbientPlayer.renderer = null;
    if (!r) {
      return;
    }
    try {
      await r.stop();
    } catch (_) {
    }
    try {
      await r.release();
    } catch (_) {
    }
  }

  private static async start(mode: string): Promise<void> {
    try {
      const opts: audio.AudioRendererOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_44100,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        rendererInfo: {
          usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
          rendererFlags: 0
        }
      };
      const renderer = await audio.createAudioRenderer(opts);
      AmbientPlayer.renderer = renderer;
      AmbientPlayer.writing = true;
      AmbientPlayer.phase = 0;
      AmbientPlayer.tickRemain = 0;
      AmbientPlayer.swellGain = 0.35;
      AmbientPlayer.swellTarget = 0.35;
      AmbientPlayer.swellFramesLeft = 0;
      AmbientPlayer.noiseState = 1;
      await renderer.start();
      AmbientPlayer.writeLoop(mode);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, `start: ${err.code} ${err.message}`);
      AmbientPlayer.mode = 'off';
      AmbientPlayer.writing = false;
      AmbientPlayer.renderer = null;
    }
  }

  private static async writeLoop(mode: string): Promise<void> {
    while (AmbientPlayer.writing && AmbientPlayer.mode === mode && AmbientPlayer.renderer) {
      const buf = AmbientPlayer.genChunk(mode, CHUNK_FRAMES);
      try {
        await AmbientPlayer.renderer.write(buf);
      } catch (e) {
        const err = e as BusinessError;
        hilog.warn(0x0000, TAG, `write: ${err.code} ${err.message}`);
        break;
      }
    }
  }

  private static genChunk(mode: string, frames: number): ArrayBuffer {
    const buf = new ArrayBuffer(frames * 2);
    const view = new DataView(buf);
    for (let i = 0; i < frames; i++) {
      let sample = 0;
      if (mode === 'rain') {
        sample = AmbientPlayer.nextNoise() * 0.22;
        // Cheap high-shelf emphasis via one-pole difference
        AmbientPlayer.phase = AmbientPlayer.phase * 0.92 + sample;
        sample = sample - AmbientPlayer.phase * 0.35;
      } else if (mode === 'waves') {
        if (AmbientPlayer.swellFramesLeft <= 0) {
          AmbientPlayer.swellTarget = 0.12 + Math.random() * 0.28;
          AmbientPlayer.swellFramesLeft = Math.floor(SAMPLE_RATE * (1.8 + Math.random() * 1.4));
        }
        const step = (AmbientPlayer.swellTarget - AmbientPlayer.swellGain) /
          Math.max(1, AmbientPlayer.swellFramesLeft);
        AmbientPlayer.swellGain += step;
        AmbientPlayer.swellFramesLeft -= 1;
        // Low-passed noise swell
        AmbientPlayer.phase = AmbientPlayer.phase * 0.97 + AmbientPlayer.nextNoise() * 0.03;
        sample = AmbientPlayer.phase * AmbientPlayer.swellGain;
      } else {
        // clock tick once per second
        if (AmbientPlayer.tickRemain <= 0) {
          AmbientPlayer.tickRemain = SAMPLE_RATE;
          AmbientPlayer.phase = 0;
        }
        const tickAge = SAMPLE_RATE - AmbientPlayer.tickRemain;
        if (tickAge < Math.floor(SAMPLE_RATE * 0.06)) {
          const env = Math.exp(-tickAge / (SAMPLE_RATE * 0.012));
          sample = Math.sin(2 * Math.PI * 1180 * tickAge / SAMPLE_RATE) * 0.18 * env;
        } else {
          sample = 0;
        }
        AmbientPlayer.tickRemain -= 1;
      }
      const clamped = Math.max(-1, Math.min(1, sample));
      view.setInt16(i * 2, Math.floor(clamped * 32767), true);
    }
    return buf;
  }

  /** xorshift-ish white noise in [-1, 1] */
  private static nextNoise(): number {
    let x = AmbientPlayer.noiseState | 0;
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    AmbientPlayer.noiseState = x || 1;
    return (x & 0xffff) / 0x8000 - 1;
  }
}

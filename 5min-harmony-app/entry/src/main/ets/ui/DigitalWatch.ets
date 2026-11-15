/** 七段电子表：现代细段 + 鼠尾草绿底盘，几何对齐各端（viewBox 144×48） */

const DIGIT_SEGS: string[] = [
  'abcdef', 'bc', 'abged', 'abgcd', 'fgbc',
  'afgcd', 'afgcde', 'abc', 'abcdefg', 'abfgcd'
];
const ALL_SEGS = 'abcdefg';
/** 熄灭段底盘：固定鼠尾草灰绿，不随亮段染色 */
const CHASSIS = '#D0DED6';
const WATCH_W = 144;
const WATCH_H = 48;

@Component
export struct DigitalWatchTime {
  @Watch('onStyleChange') @Prop text: string = '00:00';
  @Watch('onStyleChange') @Prop color: string = '#2F9A68';
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private areaW: number = 0;
  private areaH: number = 0;

  onStyleChange(): void {
    this.redraw();
  }

  redraw(): void {
    const canvasW = this.areaW > 0 ? this.areaW : this.ctx.width;
    const canvasH = this.areaH > 0 ? this.areaH : this.ctx.height;
    if (canvasW <= 0 || canvasH <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, canvasW, canvasH);
    const scale = Math.min(canvasW / WATCH_W, canvasH / WATCH_H);
    const dx = (canvasW - WATCH_W * scale) / 2;
    const dy = (canvasH - WATCH_H * scale) / 2;
    this.ctx.save();
    this.ctx.translate(dx, dy);
    this.ctx.scale(scale, scale);
    this.drawWatch(this.text, this.color);
    this.ctx.restore();
  }

  drawWatch(text: string, color: string): void {
    const digitsOnly = text.replace(/\D/g, '');
    let raw = digitsOnly;
    while (raw.length < 4) {
      raw = `0${raw}`;
    }
    raw = raw.substring(raw.length - 4);
    const digits: number[] = [
      Number.parseInt(raw.charAt(0), 10),
      Number.parseInt(raw.charAt(1), 10),
      Number.parseInt(raw.charAt(2), 10),
      Number.parseInt(raw.charAt(3), 10)
    ];
    const oy = 5;
    const slotKinds: string[] = ['digit', 'digit', 'colon', 'digit', 'digit'];
    const slotXs: number[] = [2, 34, 64, 78, 110];
    let di = 0;
    for (let i = 0; i < slotKinds.length; i++) {
      if (slotKinds[i] === 'colon') {
        this.drawColon(slotXs[i], oy, color);
      } else {
        this.drawDigit(digits[di++], slotXs[i], oy, color);
      }
    }
  }

  drawDigit(d: number, ox: number, oy: number, color: string): void {
    const segs = this.digitSegMap(ox, oy);
    const on = DIGIT_SEGS[d] ?? '';
    for (let i = 0; i < ALL_SEGS.length; i++) {
      const k = ALL_SEGS.charAt(i);
      const path = segs.get(k);
      if (!path) {
        continue;
      }
      this.ctx.globalAlpha = 1;
      this.ctx.fillStyle = on.indexOf(k) >= 0 ? color : CHASSIS;
      this.ctx.fill(path);
    }
  }

  drawColon(ox: number, oy: number, color: string): void {
    const cx = ox + 6;
    this.ctx.fillStyle = color;
    this.ctx.beginPath();
    this.ctx.arc(cx, oy + 11, 2.15, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.beginPath();
    this.ctx.arc(cx, oy + 27, 2.15, 0, Math.PI * 2);
    this.ctx.fill();
  }

  digitSegMap(ox: number, oy: number): Map<string, Path2D> {
    const dw = 24;
    const dh = 38;
    const t = 3;
    const gap = 1.25;
    const mid = dh / 2;
    const inset = 2.2;
    const map = new Map<string, Path2D>();
    map.set('a', this.hBar(ox + inset, oy, dw - inset * 2, t));
    map.set('g', this.hBar(ox + inset, oy + mid - t / 2, dw - inset * 2, t));
    map.set('d', this.hBar(ox + inset, oy + dh - t, dw - inset * 2, t));
    map.set('f', this.vBar(ox, oy + t + gap, mid - t - gap * 2, t));
    map.set('b', this.vBar(ox + dw - t, oy + t + gap, mid - t - gap * 2, t));
    map.set('e', this.vBar(ox, oy + mid + gap, mid - t - gap * 2, t));
    map.set('c', this.vBar(ox + dw - t, oy + mid + gap, mid - t - gap * 2, t));
    return map;
  }

  hBar(x: number, y: number, w: number, t: number): Path2D {
    const tip = t * 0.55;
    const p = new Path2D();
    p.moveTo(x, y + t / 2);
    p.lineTo(x + tip, y);
    p.lineTo(x + w - tip, y);
    p.lineTo(x + w, y + t / 2);
    p.lineTo(x + w - tip, y + t);
    p.lineTo(x + tip, y + t);
    p.closePath();
    return p;
  }

  vBar(x: number, y: number, h: number, t: number): Path2D {
    const tip = t * 0.55;
    const p = new Path2D();
    p.moveTo(x + t / 2, y);
    p.lineTo(x + t, y + tip);
    p.lineTo(x + t, y + h - tip);
    p.lineTo(x + t / 2, y + h);
    p.lineTo(x, y + h - tip);
    p.lineTo(x, y + tip);
    p.closePath();
    return p;
  }

  build() {
    // 尺寸由父级给定（拨盘的 ~64% 宽），此处 100% 填满，避免二次缩放导致偏小/偏左
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.redraw();
      })
      .onAreaChange((_old: Area, area: Area) => {
        this.areaW = Number(area.width);
        this.areaH = Number(area.height);
        this.redraw();
      })
  }
}

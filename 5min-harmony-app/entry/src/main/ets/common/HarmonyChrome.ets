/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * HarmonyOS NEXT–style shared chrome (sheet drag handle + surface tokens).
 * Brand colors remain FiveMin; shapes follow system sheet language.
 */

/** Shared sheet / card chrome constants aligned with HarmonyOS NEXT. */
export class HarmonyChrome {
  /** Drag-handle pill (system sheet). */
  static readonly handleW: number = 36;
  static readonly handleH: number = 4;
  static readonly handleRadius: number = 2;
  static readonly handleTop: number = 10;
  /** Soft surface for list cards (near-opaque). */
  static readonly cardSurface: string = 'rgba(255, 255, 255, 0.96)';
  /** Outlined trigger height (scene / filter). */
  static readonly triggerH: number = 48;
}

/**
 * System-style bottom-sheet drag handle.
 */
@Builder
export function HarmonySheetHandle() {
  Row()
    .width(HarmonyChrome.handleW)
    .height(HarmonyChrome.handleH)
    .borderRadius(HarmonyChrome.handleRadius)
    .backgroundColor($r('app.color.line'))
    .opacity(0.95)
    .margin({ top: HarmonyChrome.handleTop, bottom: 2 })
    .alignSelf(ItemAlign.Center)
}

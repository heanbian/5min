/**
 * Spacing / radius / control sizes — aligned with Android FiveMinDimens & MP tokens.
 * Font family registered in EntryAbility (Plus Jakarta Sans).
 */
export class FiveMinFont {
  static readonly family: string = 'PlusJakartaSans';
  static readonly regular: string = 'PlusJakartaSans-Regular';
  static readonly medium: string = 'PlusJakartaSans-Medium';
  static readonly semiBold: string = 'PlusJakartaSans-SemiBold';
  static readonly bold: string = 'PlusJakartaSans-Bold';
}

export class FiveMinDimens {
  static readonly radiusSm: number = 12;
  /** 首页操作按钮 / 场景选择 / 芯片 */
  static readonly radius: number = 22;
  /** 列表卡片 / 统计卡 */
  static readonly radiusCard: number = 14;
  /** 弹层卡片（仪式等） */
  static readonly radiusDialog: number = 16;
  /** 底部 sheet 顶角 */
  static readonly radiusSheet: number = 18;
  static readonly controlH: number = 52;
  static readonly fieldH: number = 52;
  static readonly rowH: number = 40;
  static readonly chipH: number = 40;
  static readonly filterChipH: number = 40;
  static readonly suggestedChipH: number = 32;
  static readonly padX: number = 20;
  static readonly padY: number = 18;
  static readonly padBody: number = 16;
  static readonly stageGap: number = 18;
  static readonly sectionGap: number = 20;
  static readonly listSectionGap: number = 16;
  static readonly controlGap: number = 10;
  static readonly dialSize: number = 260;
  static readonly titleSize: number = 20;
  static readonly labelSize: number = 13;
  static readonly bodySize: number = 14;
  static readonly prefTitleSize: number = 15;
  static readonly buttonTextSize: number = 16;
  static readonly chipTextSize: number = 13;
  static readonly insightTitleSize: number = 15;
  static readonly hintSize: number = 12;
}

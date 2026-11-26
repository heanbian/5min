/**
 * Design tokens for 5min Harmony UI.
 * Brand palette mirrors Android / web; radii follow HarmonyOS NEXT sheet / dialog language.
 */
export class FiveMinDimens {
  /** Small controls / inner chips */
  static readonly radiusSm: number = 12;
  /** Home actions / scene trigger / suggested chips */
  static readonly radius: number = 20;
  /** List cards / stats cards */
  static readonly radiusCard: number = 16;
  /** Centered dialogs (ritual) — Harmony dialog ≈ 24–28 */
  static readonly radiusDialog: number = 28;
  /** Bottom sheets — HarmonyOS NEXT sheet top corners */
  static readonly radiusSheet: number = 28;

  static readonly controlH: number = 52;
  static readonly fieldH: number = 52;
  static readonly rowH: number = 40;
  static readonly chipH: number = 40;
  static readonly suggestedChipH: number = 32;
  static readonly tabBarH: number = 58;
  static readonly headerH: number = 52;
  static readonly iconTap: number = 36;
  static readonly iconSm: number = 22;
  static readonly checkHit: number = 44;
  static readonly checkBox: number = 22;

  static readonly padX: number = 20;
  static readonly padY: number = 18;
  static readonly padBody: number = 16;
  static readonly stageGap: number = 18;
  static readonly sectionGap: number = 20;
  static readonly listSectionGap: number = 16;
  static readonly controlGap: number = 10;
  static readonly chipGap: number = 8;

  static readonly dialSize: number = 260;
  static readonly dialTimeW: number = 166;
  static readonly dialTimeH: number = 55;

  static readonly sheetMaxH: number = 360;
  static readonly customScenesMaxH: number = 420;
  static readonly overlayMaxPct: string = '78%';
  static readonly overlayWPct: string = '88%';
  static readonly ritualWPct: string = '86%';

  /** Soft card border used on Records / Mine list cards */
  static readonly cardBorder: string = 'rgba(215, 229, 220, 0.9)';
  static readonly cardSurface: string = 'rgba(255, 255, 255, 0.96)';
  static readonly brandSoftRail: string = 'rgba(229, 245, 236, 0.72)';
  static readonly brandSoftStat: string = 'rgba(229, 245, 236, 0.55)';
  static readonly brandBorderSoft: string = 'rgba(47, 154, 104, 0.12)';
  static readonly brandBorderOpen: string = 'rgba(47, 154, 104, 0.45)';
  static readonly chipIdleBorder: string = 'rgba(47, 154, 104, 0.18)';
  static readonly chipIdleFill: string = 'rgba(255, 255, 255, 0.55)';
  static readonly headerBg: string = 'rgba(255, 255, 255, 0.92)';
  static readonly headerLine: string = 'rgba(215, 229, 220, 0.85)';
  static readonly overlayDim: string = '#00000066';
  static readonly warnCardBg: string = 'rgba(255, 246, 232, 0.72)';
  static readonly warnCardBorder: string = 'rgba(201, 134, 45, 0.16)';
}

/**
 * Font families registered in EntryAbility (Plus Jakarta Sans).
 * Only Medium / SemiBold are used in UI today.
 */
export class FiveMinFont {
  static readonly medium: string = 'PlusJakartaSans-Medium';
  static readonly semiBold: string = 'PlusJakartaSans-SemiBold';
}

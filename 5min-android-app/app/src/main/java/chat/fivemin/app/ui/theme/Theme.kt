package chat.fivemin.app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.R

/** Design tokens mirrored from 5min-web/css/app.css */

/** Plus Jakarta Sans — Latin UI；缺字时系统回退到中日韩字体 */
val FiveMinFontFamily = FontFamily(
    Font(R.font.plus_jakarta_sans_regular, FontWeight.Normal),
    Font(R.font.plus_jakarta_sans_medium, FontWeight.Medium),
    Font(R.font.plus_jakarta_sans_semibold, FontWeight.SemiBold),
    Font(R.font.plus_jakarta_sans_bold, FontWeight.Bold),
)

object FiveMinColors {
    val brand = Color(0xFF2F9A68)
    val brandStrong = Color(0xFF248556)
    val brandSoft = Color(0xFFE5F5EC)
    val bg = Color(0xFFEEF6F1)
    /** Records / Mine list page background — aligned with MP/iOS `#F2F5F3` */
    val bg2 = Color(0xFFF2F5F3)
    val bgBottom = Color(0xFFF4F8F5)
    val glow = Color(0xFFDFF0E6)
    val surface = Color(0xFFFFFFFF)
    val ink = Color(0xFF1F2A24)
    val muted = Color(0xFF5F6F66)
    val line = Color(0xFFD7E5DC)
    /** Reset / secondary button — aligned with web `.ghost` */
    val ghostBg = Color(0xFFE8ECEA)
    val ghostInk = Color(0xFF6B7570)
    val ghostLine = Color(0xFFD5DBD7)
    val ring = Color(0xFFCFE0D6)
    val warn = Color(0xFFC9862D)
    val warnSoft = Color(0xFFFFF6E8)
    val warnGlow = Color(0xFFFFE9C8)
    val warnBottom = Color(0xFFFFFAF2)
    val danger = Color(0xFFD2554A)
    val dangerSoft = Color(0xFFFFEFED)
    val dangerGlow = Color(0xFFFFD7D2)
    val dangerBottom = Color(0xFFFFF7F6)
}

object FiveMinDimens {
    val radiusSm = 12.dp
    /** 首页操作按钮 / 场景选择 / 芯片统一大圆角 */
    val radius = 22.dp
    /** 列表卡片 / 统计卡 */
    val radiusCard = 14.dp
    /** 弹层卡片（仪式等） */
    val radiusDialog = 16.dp
    /** 底部 sheet 顶角 */
    val radiusSheet = 18.dp
    val controlH = 52.dp
    val fieldH = 52.dp
    val rowH = 40.dp
    /** 筛选胶囊 / 快捷分钟芯片高度 */
    val chipH = 40.dp
    val filterChipH = 40.dp
    /** 首页推荐场景胶囊 */
    val suggestedChipH = 32.dp
    val padX = 20.dp
    val padY = 18.dp
    val padBody = 16.dp
    val stageGap = 18.dp
    val sectionGap = 20.dp
    val listSectionGap = 16.dp
    val controlGap = 10.dp
    val dialSize = 260.dp
}

private val LightColors = lightColorScheme(
    primary = FiveMinColors.brand,
    onPrimary = Color.White,
    primaryContainer = FiveMinColors.brandSoft,
    onPrimaryContainer = FiveMinColors.brandStrong,
    secondary = FiveMinColors.brandStrong,
    background = FiveMinColors.bg,
    onBackground = FiveMinColors.ink,
    surface = FiveMinColors.surface,
    onSurface = FiveMinColors.ink,
    onSurfaceVariant = FiveMinColors.muted,
    outline = FiveMinColors.line,
    error = FiveMinColors.danger,
    tertiary = FiveMinColors.warn,
)

private fun TextStyle.withAppFont(): TextStyle = copy(fontFamily = FiveMinFontFamily)

private val BaseTypography = Typography()

private val AppTypography = Typography(
    displayLarge = BaseTypography.displayLarge.withAppFont(),
    displayMedium = BaseTypography.displayMedium.withAppFont(),
    displaySmall = BaseTypography.displaySmall.withAppFont(),
    headlineLarge = BaseTypography.headlineLarge.withAppFont(),
    headlineMedium = BaseTypography.headlineMedium.withAppFont(),
    headlineSmall = BaseTypography.headlineSmall.withAppFont(),
    titleLarge = TextStyle(
        fontFamily = FiveMinFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 19.sp,
        letterSpacing = 0.01.sp,
        color = FiveMinColors.ink,
        lineHeight = 24.sp,
    ),
    titleMedium = BaseTypography.titleMedium.withAppFont(),
    titleSmall = BaseTypography.titleSmall.withAppFont(),
    bodyLarge = TextStyle(
        fontFamily = FiveMinFontFamily,
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        lineHeight = 24.sp,
        color = FiveMinColors.ink,
    ),
    bodyMedium = TextStyle(
        fontFamily = FiveMinFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 21.sp,
        color = FiveMinColors.muted,
    ),
    bodySmall = TextStyle(
        fontFamily = FiveMinFontFamily,
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        lineHeight = 20.sp,
        color = FiveMinColors.muted,
    ),
    labelLarge = TextStyle(
        fontFamily = FiveMinFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 16.sp,
        color = FiveMinColors.ink,
    ),
    labelMedium = TextStyle(
        fontFamily = FiveMinFontFamily,
        fontWeight = FontWeight.SemiBold,
        fontSize = 14.sp,
        color = FiveMinColors.muted,
    ),
    labelSmall = BaseTypography.labelSmall.withAppFont(),
)

val FiveMinShapes = androidx.compose.material3.Shapes(
    small = RoundedCornerShape(FiveMinDimens.radiusSm),
    medium = RoundedCornerShape(FiveMinDimens.radius),
    large = RoundedCornerShape(FiveMinDimens.radius),
)

@Composable
fun FiveMinTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        typography = AppTypography,
        shapes = FiveMinShapes,
        content = content,
    )
}

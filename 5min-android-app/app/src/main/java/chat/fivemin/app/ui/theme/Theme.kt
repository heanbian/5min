package chat.fivemin.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val Brand = Color(0xFF2F9A68)
private val BrandStrong = Color(0xFF248556)
private val BrandSoft = Color(0xFFE5F5EC)
private val Ink = Color(0xFF1F2A24)
private val Muted = Color(0xFF5F6F66)
private val Bg = Color(0xFFEEF6F1)
private val Warn = Color(0xFFC9862D)
private val Danger = Color(0xFFD2554A)

private val LightColors = lightColorScheme(
    primary = Brand,
    onPrimary = Color.White,
    primaryContainer = BrandSoft,
    onPrimaryContainer = BrandStrong,
    secondary = BrandStrong,
    background = Bg,
    onBackground = Ink,
    surface = Color.White,
    onSurface = Ink,
    onSurfaceVariant = Muted,
    error = Danger,
    tertiary = Warn,
)

@Composable
fun FiveMinTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        content = content,
    )
}

object FiveMinColors {
    val brand = Brand
    val brandStrong = BrandStrong
    val brandSoft = BrandSoft
    val warn = Warn
    val danger = Danger
    val muted = Muted
}

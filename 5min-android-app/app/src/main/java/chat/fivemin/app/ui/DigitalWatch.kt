package chat.fivemin.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate

/**
 * 七段电子表数字，几何与 5min-web/js/app.js digitalWatchSvg 对齐：
 * viewBox 144×48，固定 MM:SS 五槽布局。
 */
private val DigitSegs = arrayOf(
    "abcdef", "bc", "abged", "abgcd", "fgbc",
    "afgcd", "afgcde", "abc", "abcdefg", "abfgcd",
)
private const val AllSegs = "abcdefg"
private const val WatchW = 144f
private const val WatchH = 48f
private val WatchSlots = listOf(
    Slot("digit", 4f),
    Slot("digit", 34f),
    Slot("colon", 64f),
    Slot("digit", 80f),
    Slot("digit", 110f),
)

private data class Slot(val kind: String, val x: Float)

@Composable
fun DigitalWatchTime(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Canvas(
        modifier = modifier
            .fillMaxWidth(0.64f)
            .aspectRatio(WatchW / WatchH),
    ) {
        val scale = minOf(size.width / WatchW, size.height / WatchH)
        val dx = (size.width - WatchW * scale) / 2f
        val dy = (size.height - WatchH * scale) / 2f
        translate(dx, dy) {
            scale(scale, scale, pivot = Offset.Zero) {
                drawDigitalWatch(text, color)
            }
        }
    }
}

private fun DrawScope.drawDigitalWatch(text: String, color: Color) {
    val raw = text.filter { it.isDigit() }.padStart(4, '0').takeLast(4)
    val digits = raw.map { it.digitToInt() }
    val oy = 6f
    var di = 0
    for (slot in WatchSlots) {
        if (slot.kind == "colon") {
            drawColon(slot.x, oy, color)
        } else {
            drawDigit(digits[di++], slot.x, oy, color)
        }
    }
}

private fun DrawScope.drawDigit(d: Int, ox: Float, oy: Float, color: Color) {
    val segs = digitSegMap(ox, oy)
    val on = DigitSegs.getOrElse(d) { "" }
    for (k in AllSegs) {
        val path = segs[k] ?: continue
        val alpha = if (on.contains(k)) 1f else 0.05f
        drawPath(path, color.copy(alpha = alpha))
    }
}

private fun DrawScope.drawColon(ox: Float, oy: Float, color: Color) {
    val cx = ox + 6f
    drawCircle(color = color, radius = 2.6f, center = Offset(cx, oy + 10f))
    drawCircle(color = color, radius = 2.6f, center = Offset(cx, oy + 26f))
}

private fun digitSegMap(ox: Float, oy: Float): Map<Char, Path> {
    val dw = 22f
    val dh = 36f
    val t = 4f
    val gap = 1f
    val mid = dh / 2f
    return mapOf(
        'a' to hBar(ox + 2.5f, oy, dw - 5f, t),
        'g' to hBar(ox + 2.5f, oy + mid - t / 2f, dw - 5f, t),
        'd' to hBar(ox + 2.5f, oy + dh - t, dw - 5f, t),
        'f' to vBar(ox, oy + t + gap, mid - t - gap * 2f, t),
        'b' to vBar(ox + dw - t, oy + t + gap, mid - t - gap * 2f, t),
        'e' to vBar(ox, oy + mid + gap, mid - t - gap * 2f, t),
        'c' to vBar(ox + dw - t, oy + mid + gap, mid - t - gap * 2f, t),
    )
}

private fun hBar(x: Float, y: Float, w: Float, t: Float): Path = Path().apply {
    moveTo(x, y + t / 2f)
    lineTo(x + t / 2f, y)
    lineTo(x + w - t / 2f, y)
    lineTo(x + w, y + t / 2f)
    lineTo(x + w - t / 2f, y + t)
    lineTo(x + t / 2f, y + t)
    close()
}

private fun vBar(x: Float, y: Float, h: Float, t: Float): Path = Path().apply {
    moveTo(x + t / 2f, y)
    lineTo(x + t, y + t / 2f)
    lineTo(x + t, y + h - t / 2f)
    lineTo(x + t / 2f, y + h)
    lineTo(x, y + h - t / 2f)
    lineTo(x, y + t / 2f)
    close()
}

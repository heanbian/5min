package chat.fivemin.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

enum class DialogBtnStyle {
    Primary,
    Ghost,
    Danger,
}

/** Solid / ghost / danger action used in AlertDialog footers and sheet bodies. */
@Composable
fun DialogActionButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    style: DialogBtnStyle = DialogBtnStyle.Primary,
    enabled: Boolean = true,
    fillMaxWidth: Boolean = false,
) {
    val bg = when {
        !enabled -> FiveMinColors.ghostBg
        style == DialogBtnStyle.Primary -> FiveMinColors.brand
        style == DialogBtnStyle.Danger -> FiveMinColors.danger
        else -> FiveMinColors.ghostBg
    }
    val fg = when {
        !enabled -> FiveMinColors.muted
        style == DialogBtnStyle.Ghost -> FiveMinColors.ink
        else -> Color.White
    }
    val borderColor = when {
        style == DialogBtnStyle.Ghost && enabled -> FiveMinColors.line
        else -> Color.Transparent
    }
    Row(
        modifier = modifier
            .then(if (fillMaxWidth) Modifier.fillMaxWidth() else Modifier.widthIn(min = 88.dp))
            .height(44.dp)
            .clip(RoundedCornerShape(FiveMinDimens.radiusSm))
            .background(bg)
            .border(1.dp, borderColor, RoundedCornerShape(FiveMinDimens.radiusSm))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Text(
            text = text,
            color = fg,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
        )
    }
}

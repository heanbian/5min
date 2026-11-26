/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Shared Material 3 buttons used across Home / Mine / Privacy.
 */
package chat.fivemin.app.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

private val BtnShape = RoundedCornerShape(FiveMinDimens.radius)
private val TriggerShape = RoundedCornerShape(FiveMinDimens.radiusSm)

@Composable
fun MaterialPrimaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(FiveMinDimens.controlH),
        shape = BtnShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = FiveMinColors.brand,
            contentColor = androidx.compose.ui.graphics.Color.White,
            disabledContainerColor = FiveMinColors.brandSoft,
            disabledContentColor = FiveMinColors.muted,
        ),
        elevation = ButtonDefaults.buttonElevation(
            defaultElevation = 2.dp,
            pressedElevation = 4.dp,
            disabledElevation = 0.dp,
        ),
        contentPadding = PaddingValues(horizontal = 16.dp),
    ) {
        Text(text = text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun MaterialSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(FiveMinDimens.controlH),
        shape = BtnShape,
        border = BorderStroke(1.dp, if (enabled) FiveMinColors.line else FiveMinColors.line.copy(alpha = 0.5f)),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = FiveMinColors.muted,
            disabledContentColor = FiveMinColors.muted.copy(alpha = 0.38f),
            containerColor = FiveMinColors.surface,
        ),
        contentPadding = PaddingValues(horizontal = 16.dp),
    ) {
        Text(text = text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun MaterialDangerOutlinedButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(FiveMinDimens.controlH),
        shape = BtnShape,
        border = BorderStroke(1.dp, FiveMinColors.danger.copy(alpha = 0.4f)),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = FiveMinColors.danger,
            containerColor = FiveMinColors.surface.copy(alpha = 0.9f),
        ),
        contentPadding = PaddingValues(horizontal = 16.dp),
    ) {
        Text(text = text, fontSize = 15.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun MaterialFilledWideButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp),
        shape = RoundedCornerShape(FiveMinDimens.radiusSm),
        colors = ButtonDefaults.buttonColors(
            containerColor = FiveMinColors.brand,
            contentColor = androidx.compose.ui.graphics.Color.White,
            disabledContainerColor = FiveMinColors.brandSoft,
            disabledContentColor = FiveMinColors.muted,
        ),
        elevation = ButtonDefaults.buttonElevation(defaultElevation = 1.dp),
    ) {
        Text(text = text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** Outlined dropdown-style trigger (scene / filter pickers). */
@Composable
fun MaterialOutlinedTrigger(
    value: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    expanded: Boolean = false,
    placeholder: Boolean = false,
    leadingLabel: String? = null,
    height: androidx.compose.ui.unit.Dp = 48.dp,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier
            .fillMaxWidth()
            .height(height),
        shape = TriggerShape,
        border = BorderStroke(
            1.dp,
            when {
                !enabled -> FiveMinColors.line.copy(alpha = 0.5f)
                expanded -> FiveMinColors.brand.copy(alpha = 0.45f)
                else -> FiveMinColors.line
            },
        ),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = FiveMinColors.surface,
            contentColor = FiveMinColors.ink,
            disabledContainerColor = FiveMinColors.surface,
            disabledContentColor = FiveMinColors.muted.copy(alpha = 0.4f),
        ),
        contentPadding = PaddingValues(horizontal = 14.dp),
    ) {
        if (leadingLabel != null) {
            Text(
                text = leadingLabel,
                color = if (enabled) FiveMinColors.muted else FiveMinColors.muted.copy(alpha = 0.4f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
            )
            Spacer(modifier = Modifier.width(8.dp))
        }
        Text(
            text = value,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Start,
            color = when {
                !enabled -> FiveMinColors.muted.copy(alpha = 0.4f)
                placeholder -> FiveMinColors.muted
                else -> FiveMinColors.ink
            },
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
        )
        Icon(
            imageVector = Icons.Default.KeyboardArrowDown,
            contentDescription = null,
            tint = when {
                !enabled -> FiveMinColors.muted.copy(alpha = 0.4f)
                expanded -> FiveMinColors.brandStrong
                else -> FiveMinColors.muted
            },
            modifier = Modifier.size(18.dp),
        )
    }
}

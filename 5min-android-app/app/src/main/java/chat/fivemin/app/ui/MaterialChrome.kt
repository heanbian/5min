/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Material 3 / Google-style dialog & bottom-sheet primitives for Mine (and similar) flows.
 */
package chat.fivemin.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.SheetValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

/** M3 dialog corner (Google default ≈ 28.dp). */
private val MaterialDialogShape = RoundedCornerShape(28.dp)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MaterialPickSheet(
    title: String,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val sheetState = rememberBottomSheetState(
        initialValue = SheetValue.Hidden,
        enabledValues = setOf(SheetValue.Hidden, SheetValue.Expanded),
    )
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(
            topStart = FiveMinDimens.radiusSheet,
            topEnd = FiveMinDimens.radiusSheet,
        ),
        containerColor = FiveMinColors.surface,
        tonalElevation = 2.dp,
        dragHandle = { BottomSheetDefaults.DragHandle(color = FiveMinColors.line) },
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp),
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = FiveMinDimens.sheetMaxH + 80.dp)
                .verticalScroll(rememberScrollState())
                .navigationBarsPadding()
                .padding(bottom = 16.dp),
            content = content,
        )
    }
}

@Composable
fun MaterialPickRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    ListItem(
        selected = selected,
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        leadingContent = {
            RadioButton(
                selected = selected,
                onClick = onClick,
                colors = RadioButtonDefaults.colors(
                    selectedColor = FiveMinColors.brand,
                    unselectedColor = FiveMinColors.muted,
                ),
            )
        },
        colors = ListItemDefaults.colors(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            selectedContainerColor = FiveMinColors.brandSoft.copy(alpha = 0.65f),
        ),
    ) {
        Text(
            text = label,
            color = if (selected) FiveMinColors.brandStrong else FiveMinColors.ink,
            fontSize = 16.sp,
            fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MaterialFormSheet(
    title: String,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val sheetState = rememberBottomSheetState(
        initialValue = SheetValue.Hidden,
        enabledValues = setOf(SheetValue.Hidden, SheetValue.Expanded),
    )
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(
            topStart = FiveMinDimens.radiusSheet,
            topEnd = FiveMinDimens.radiusSheet,
        ),
        containerColor = FiveMinColors.surface,
        tonalElevation = 2.dp,
        dragHandle = { BottomSheetDefaults.DragHandle(color = FiveMinColors.line) },
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp),
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 24.dp, vertical = 12.dp)
                .padding(bottom = 20.dp),
            content = content,
        )
    }
}

@Composable
fun MaterialAlert(
    onDismissRequest: () -> Unit,
    title: String,
    text: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    dismissLabel: String? = null,
    onDismiss: (() -> Unit)? = null,
    destructive: Boolean = false,
) {
    MaterialAlertContent(
        onDismissRequest = onDismissRequest,
        title = title,
        confirmLabel = confirmLabel,
        onConfirm = onConfirm,
        dismissLabel = dismissLabel,
        onDismiss = onDismiss,
        destructive = destructive,
    ) {
        Text(
            text = text,
            color = FiveMinColors.muted,
            style = MaterialTheme.typography.bodyMedium,
            lineHeight = 22.sp,
        )
    }
}

@Composable
fun MaterialAlertContent(
    onDismissRequest: () -> Unit,
    title: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    dismissLabel: String? = null,
    onDismiss: (() -> Unit)? = null,
    destructive: Boolean = false,
    content: @Composable () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismissRequest,
        shape = MaterialDialogShape,
        containerColor = FiveMinColors.surface,
        title = {
            Text(
                text = title,
                color = FiveMinColors.ink,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
        },
        text = content,
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    text = confirmLabel,
                    color = if (destructive) FiveMinColors.danger else FiveMinColors.brandStrong,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        },
        dismissButton = if (dismissLabel != null && onDismiss != null) {
            {
                TextButton(onClick = onDismiss) {
                    Text(
                        text = dismissLabel,
                        color = FiveMinColors.muted,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        } else {
            null
        },
    )
}

@Composable
fun MaterialTextAction(
    text: String,
    onClick: () -> Unit,
    emphatic: Boolean = false,
    enabled: Boolean = true,
) {
    TextButton(onClick = onClick, enabled = enabled) {
        Text(
            text = text,
            color = when {
                !enabled -> FiveMinColors.muted.copy(alpha = 0.45f)
                emphatic -> FiveMinColors.brandStrong
                else -> FiveMinColors.muted
            },
            fontWeight = if (emphatic) FontWeight.SemiBold else FontWeight.Medium,
        )
    }
}

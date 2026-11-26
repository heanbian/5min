package chat.fivemin.app.ui.records

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.data.HistoryItem
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.DialogActionButton
import chat.fivemin.app.ui.DialogBtnStyle
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private enum class RecordsDialog { None, ClearAll, DeleteOne }

@Composable
fun RecordsScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsStateWithLifecycle()
    var rows by remember { mutableStateOf<List<HistoryItem>>(emptyList()) }
    var periodCount by remember { mutableIntStateOf(0) }
    var periodMins by remember { mutableIntStateOf(0) }
    var streakDays by remember { mutableIntStateOf(0) }
    var filterSceneId by remember { mutableStateOf<String?>(null) }
    var showFilter by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf(RecordsDialog.None) }
    var pendingDeleteId by remember { mutableStateOf<Long?>(null) }
    val context = LocalContext.current

    fun reload() {
        val history = FiveMinApp.instance.history
        rows = history.getHistory(filterSceneId)
        val (count, mins, streak) = history.shareSummaryValues()
        periodCount = count
        periodMins = mins
        streakDays = streak
    }

    fun shareSummary() {
        val history = FiveMinApp.instance.history
        val (count, mins, streak) = history.shareSummaryValues()
        val text = vm.t(
            "shareText",
            mapOf(
                "count" to count.toString(),
                "mins" to mins.toString(),
                "streak" to streak.toString(),
            ),
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        context.startActivity(Intent.createChooser(intent, vm.t("shareLabel")))
    }

    fun exportCsv() {
        val history = FiveMinApp.instance.history
        val csv = history.exportHistoryCsv(vm.t("exportCsvHeader")) { row ->
            vm.sceneTitle(row.sceneId.takeIf { it.isNotBlank() })
                ?: vm.t("historySceneDefault")
        }
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/csv"
                putExtra(Intent.EXTRA_SUBJECT, "5min-history.csv")
                putExtra(Intent.EXTRA_TEXT, csv)
                putExtra(Intent.EXTRA_TITLE, "5min-history.csv")
            }
            context.startActivity(Intent.createChooser(intent, vm.t("exportLabel")))
            Toast.makeText(context, vm.t("exportDone"), Toast.LENGTH_SHORT).show()
        } catch (_: Exception) {
            Toast.makeText(context, vm.t("exportFailed"), Toast.LENGTH_SHORT).show()
        }
    }

    val filterOptions = remember(state.recordsEpoch, state.locale, state.customScenes) {
        val all = FiveMinApp.instance.history.getHistory()
        all.map { it.sceneId }.filter { it.isNotBlank() }.distinct()
    }

    LaunchedEffect(state.recordsEpoch, state.locale, filterSceneId) { reload() }

    val selectedFilterLabel = filterSceneId
        ?.let { id -> vm.sceneTitle(id) ?: id }
        ?: vm.t("historyFilterAll")
    val filterRadius = RoundedCornerShape(FiveMinDimens.radius)
    val listRadius = RoundedCornerShape(FiveMinDimens.radiusCard)
    val sheetRadius = RoundedCornerShape(
        topStart = FiveMinDimens.radiusSheet,
        topEnd = FiveMinDimens.radiusSheet,
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(FiveMinColors.bg, FiveMinColors.bg2, FiveMinColors.bgBottom),
                ),
            ),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Sticky header — title + share + export (Clear lives under historyLabel, like Harmony/iOS)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .statusBarsPadding()
                    .height(FiveMinDimens.headerH)
                    .background(FiveMinColors.surface.copy(alpha = 0.72f))
                    .padding(horizontal = FiveMinDimens.padX),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = vm.t("tabRecords"),
                    color = FiveMinColors.ink,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = vm.t("shareLabel"),
                    color = FiveMinColors.brandStrong,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .padding(start = 8.dp, end = 4.dp, top = 10.dp, bottom = 10.dp)
                        .clickable { shareSummary() },
                )
                Text(
                    text = vm.t("exportLabel"),
                    color = FiveMinColors.brandStrong,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .padding(start = 4.dp, end = 4.dp, top = 10.dp, bottom = 10.dp)
                        .clickable { exportCsv() },
                )
            }
            HorizontalDivider(color = FiveMinColors.line.copy(alpha = 0.85f), thickness = 1.dp)

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(
                        start = FiveMinDimens.padBody,
                        end = FiveMinDimens.padBody,
                        top = FiveMinDimens.padBody,
                        bottom = 24.dp,
                    ),
                verticalArrangement = Arrangement.spacedBy(FiveMinDimens.listSectionGap),
            ) {
                Text(
                    text = vm.t("weekStatsLabel"),
                    color = FiveMinColors.muted,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(start = 4.dp),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    StatCard(
                        title = vm.t("weekStatsCountLabel"),
                        value = "$periodCount",
                        unit = null,
                        modifier = Modifier.weight(1f),
                    )
                    StatCard(
                        title = vm.t("weekStatsMinsLabel"),
                        value = "$periodMins",
                        unit = vm.t("customUnit"),
                        modifier = Modifier.weight(1f),
                    )
                }
                Text(
                    text = if (streakDays > 0) {
                        vm.t("streakDays", mapOf("n" to streakDays.toString()))
                    } else {
                        vm.t("streakNone")
                    },
                    color = FiveMinColors.muted,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(start = 4.dp),
                )

                val p0 = FiveMinApp.instance.prefs.p0
                val overtimeStats = remember(state.recordsEpoch) { p0.readOvertimeStats() }
                if (p0.showOvertimeInsight) {
                    val insightLine = if (overtimeStats.count > 0) {
                        vm.t(
                            "overtimeInsightLine",
                            mapOf(
                                "count" to overtimeStats.count.toString(),
                                "mins" to p0.insightMinutes(overtimeStats.ms).toString(),
                            ),
                        )
                    } else {
                        vm.t("overtimeInsightEmpty")
                    }
                    // Harmony/MP: one note — tip when overtime exists, else hint
                    val insightNote = if (overtimeStats.count > 0) {
                        vm.t("overtimeInsightTip")
                    } else {
                        vm.t("overtimeInsightHint")
                    }
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                FiveMinColors.warnSoft.copy(alpha = 0.72f),
                                RoundedCornerShape(FiveMinDimens.radiusCard),
                            )
                            .border(
                                1.dp,
                                FiveMinColors.warn.copy(alpha = 0.16f),
                                RoundedCornerShape(FiveMinDimens.radiusCard),
                            )
                            .padding(FiveMinDimens.padBody),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = vm.t("overtimeInsightTitle"),
                            color = FiveMinColors.ink,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            text = insightLine,
                            color = FiveMinColors.ink,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        Text(
                            text = insightNote,
                            color = FiveMinColors.muted,
                            fontSize = 13.sp,
                            lineHeight = 19.sp,
                        )
                    }
                }

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(start = 4.dp, end = 4.dp, top = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = vm.t("historyLabel"),
                        color = FiveMinColors.muted,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = vm.t("historyClear"),
                        color = FiveMinColors.danger,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier
                            .padding(start = 10.dp, end = 4.dp, top = 8.dp, bottom = 8.dp)
                            .clickable { dialog = RecordsDialog.ClearAll },
                    )
                }

                // Labeled filter trigger → bottom sheet (matches Harmony RecordsTab)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(FiveMinDimens.rowH)
                        .clip(filterRadius)
                        .border(
                            1.dp,
                            if (showFilter) {
                                FiveMinColors.brand.copy(alpha = 0.45f)
                            } else {
                                FiveMinColors.line
                            },
                            filterRadius,
                        )
                        .background(FiveMinColors.surface)
                        .clickable { showFilter = true }
                        .padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = vm.t("historyFilterLabel"),
                        color = FiveMinColors.muted,
                        fontSize = 13.sp,
                        modifier = Modifier.padding(end = 8.dp),
                    )
                    Text(
                        text = selectedFilterLabel,
                        color = FiveMinColors.ink,
                        fontSize = 14.sp,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "▾",
                        color = if (showFilter) FiveMinColors.brandStrong else FiveMinColors.muted,
                        fontSize = 12.sp,
                        modifier = Modifier.rotate(if (showFilter) 180f else 0f),
                    )
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .shadow(
                            elevation = 2.dp,
                            shape = listRadius,
                            ambientColor = Color(0x0A1F2A24),
                            spotColor = Color(0x0A1F2A24),
                        )
                        .clip(listRadius)
                        .background(FiveMinColors.surface.copy(alpha = 0.88f))
                        .border(1.dp, FiveMinColors.line.copy(alpha = 0.9f), listRadius),
                ) {
                    if (rows.isEmpty()) {
                        Text(
                            text = vm.t("historyEmpty"),
                            color = FiveMinColors.muted,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(20.dp),
                        )
                    } else {
                        rows.forEachIndexed { index, item ->
                            HistoryRow(
                                vm = vm,
                                item = item,
                                onDelete = {
                                    pendingDeleteId = item.id
                                    dialog = RecordsDialog.DeleteOne
                                },
                            )
                            if (index < rows.lastIndex) {
                                HorizontalDivider(
                                    color = FiveMinColors.line,
                                    modifier = Modifier.padding(start = FiveMinDimens.padBody),
                                )
                            }
                        }
                    }
                }
            }
        }

        if (showFilter) {
            Column(modifier = Modifier.fillMaxSize()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .background(Color(0x66000000))
                        .clickable { showFilter = false },
                )
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(sheetRadius)
                        .background(FiveMinColors.surface),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(
                                start = FiveMinDimens.padX,
                                end = 12.dp,
                                top = FiveMinDimens.padBody,
                                bottom = 8.dp,
                            ),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = vm.t("historyFilterLabel"),
                            color = FiveMinColors.ink,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            text = "✕",
                            color = FiveMinColors.muted,
                            fontSize = 18.sp,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .height(FiveMinDimens.rowH)
                                .padding(horizontal = 12.dp)
                                .clickable { showFilter = false },
                        )
                    }
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = FiveMinDimens.sheetMaxH)
                            .verticalScroll(rememberScrollState())
                            .padding(bottom = 28.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        FilterOptionRow(
                            label = vm.t("historyFilterAll"),
                            selected = filterSceneId == null,
                            onClick = {
                                filterSceneId = null
                                showFilter = false
                            },
                        )
                        filterOptions.forEach { sceneId ->
                            val label = vm.sceneTitle(sceneId) ?: sceneId
                            FilterOptionRow(
                                label = label,
                                selected = filterSceneId == sceneId,
                                onClick = {
                                    filterSceneId = sceneId
                                    showFilter = false
                                },
                            )
                        }
                    }
                }
            }
        }
    }

    when (dialog) {
        RecordsDialog.ClearAll -> AlertDialog(
            onDismissRequest = { dialog = RecordsDialog.None },
            dismissButton = {
                DialogActionButton(
                    text = vm.t("cancelLabel"),
                    onClick = { dialog = RecordsDialog.None },
                    style = DialogBtnStyle.Ghost,
                )
            },
            confirmButton = {
                DialogActionButton(
                    text = vm.t("confirmLabel"),
                    onClick = {
                        vm.clearHistory()
                        filterSceneId = null
                        dialog = RecordsDialog.None
                    },
                    style = DialogBtnStyle.Danger,
                )
            },
            title = { Text(vm.t("historyClear"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = { Text(vm.t("historyClearConfirm"), color = FiveMinColors.ink) },
        )
        RecordsDialog.DeleteOne -> AlertDialog(
            onDismissRequest = {
                dialog = RecordsDialog.None
                pendingDeleteId = null
            },
            dismissButton = {
                DialogActionButton(
                    text = vm.t("cancelLabel"),
                    onClick = {
                        dialog = RecordsDialog.None
                        pendingDeleteId = null
                    },
                    style = DialogBtnStyle.Ghost,
                )
            },
            confirmButton = {
                DialogActionButton(
                    text = vm.t("historyDelete"),
                    onClick = {
                        pendingDeleteId?.let { vm.deleteHistorySession(it) }
                        dialog = RecordsDialog.None
                        pendingDeleteId = null
                    },
                    style = DialogBtnStyle.Danger,
                )
            },
            title = { Text(vm.t("historyDelete"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = { Text(vm.t("historyDeleteConfirm"), color = FiveMinColors.ink) },
        )
        RecordsDialog.None -> Unit
    }
}

@Composable
private fun FilterOptionRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(FiveMinDimens.controlH)
            .clickable(onClick = onClick)
            .padding(horizontal = FiveMinDimens.padBody),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            color = if (selected) FiveMinColors.brandStrong else FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (selected) {
            Text(
                text = "✓",
                color = FiveMinColors.brandStrong,
                fontSize = 16.sp,
            )
        }
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    unit: String?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .background(
                FiveMinColors.brandSoft.copy(alpha = 0.55f),
                RoundedCornerShape(FiveMinDimens.radiusCard),
            )
            .border(
                1.dp,
                FiveMinColors.brand.copy(alpha = 0.12f),
                RoundedCornerShape(FiveMinDimens.radiusCard),
            )
            .padding(FiveMinDimens.padBody),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(title, color = FiveMinColors.muted, fontSize = 12.sp, fontWeight = FontWeight.Medium)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                value,
                color = FiveMinColors.brandStrong,
                fontSize = 28.sp,
                fontWeight = FontWeight.SemiBold,
            )
            if (unit != null) {
                Text(
                    unit,
                    color = FiveMinColors.muted,
                    fontSize = 13.sp,
                    modifier = Modifier.padding(start = 4.dp, bottom = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun HistoryRow(vm: TimerViewModel, item: HistoryItem, onDelete: () -> Unit) {
    val scene = vm.sceneTitle(item.sceneId.takeIf { it.isNotBlank() })
        ?: vm.t("historySceneDefault")
    val time = formatDateTime(item.at)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(
                start = FiveMinDimens.padBody,
                end = FiveMinDimens.padBody,
                top = 14.dp,
                bottom = 14.dp,
            ),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = vm.t("historySceneLine", mapOf("scene" to scene)),
                color = FiveMinColors.ink,
                fontSize = 14.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = vm.t("historyDurationLine", mapOf("n" to item.minutes.toString())),
                color = FiveMinColors.ink,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = vm.t("historyTimeLine", mapOf("time" to time)),
                color = FiveMinColors.ink,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            text = vm.t("historyDelete"),
            color = FiveMinColors.danger,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier
                .padding(start = 12.dp, end = 8.dp, top = 12.dp, bottom = 12.dp)
                .clickable(onClick = onDelete),
        )
    }
}

private fun formatDateTime(at: Long): String {
    val fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss", Locale.US)
    return Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).format(fmt)
}

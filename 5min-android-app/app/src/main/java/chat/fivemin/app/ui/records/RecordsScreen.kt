package chat.fivemin.app.ui.records

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
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
import chat.fivemin.app.ui.MaterialAlert
import chat.fivemin.app.ui.MaterialOutlinedTrigger
import chat.fivemin.app.ui.MaterialPickRow
import chat.fivemin.app.ui.MaterialPickSheet
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private enum class RecordsDialog { None, ClearAll, DeleteOne }

@OptIn(ExperimentalMaterial3Api::class)
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
            TopAppBar(
                title = {
                    Text(
                        text = vm.t("tabRecords"),
                        color = FiveMinColors.ink,
                        fontWeight = FontWeight.SemiBold,
                    )
                },
                actions = {
                    TextButton(
                        onClick = { shareSummary() },
                        colors = ButtonDefaults.textButtonColors(contentColor = FiveMinColors.brandStrong),
                    ) {
                        Text(vm.t("shareLabel"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                    TextButton(
                        onClick = { exportCsv() },
                        colors = ButtonDefaults.textButtonColors(contentColor = FiveMinColors.brandStrong),
                    ) {
                        Text(vm.t("exportLabel"), fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FiveMinColors.surface.copy(alpha = 0.92f),
                    titleContentColor = FiveMinColors.ink,
                ),
                modifier = Modifier.statusBarsPadding(),
            )
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
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(FiveMinDimens.radiusCard),
                        colors = CardDefaults.cardColors(
                            containerColor = FiveMinColors.warnSoft.copy(alpha = 0.72f),
                        ),
                        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
                        border = androidx.compose.foundation.BorderStroke(
                            1.dp,
                            FiveMinColors.warn.copy(alpha = 0.16f),
                        ),
                    ) {
                        Column(
                            modifier = Modifier.padding(FiveMinDimens.padBody),
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
                    TextButton(
                        onClick = { dialog = RecordsDialog.ClearAll },
                        colors = ButtonDefaults.textButtonColors(contentColor = FiveMinColors.danger),
                    ) {
                        Text(vm.t("historyClear"), fontSize = 13.sp, fontWeight = FontWeight.Medium)
                    }
                }

                MaterialOutlinedTrigger(
                    value = selectedFilterLabel,
                    onClick = { showFilter = true },
                    expanded = showFilter,
                    leadingLabel = vm.t("historyFilterLabel"),
                    height = FiveMinDimens.rowH,
                )

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(FiveMinDimens.radiusCard),
                    colors = CardDefaults.cardColors(
                        containerColor = FiveMinColors.surface.copy(alpha = 0.96f),
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                    border = androidx.compose.foundation.BorderStroke(
                        1.dp,
                        FiveMinColors.line.copy(alpha = 0.9f),
                    ),
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
            MaterialPickSheet(
                title = vm.t("historyFilterLabel"),
                onDismiss = { showFilter = false },
            ) {
                MaterialPickRow(
                    label = vm.t("historyFilterAll"),
                    selected = filterSceneId == null,
                    onClick = {
                        filterSceneId = null
                        showFilter = false
                    },
                )
                filterOptions.forEach { sceneId ->
                    val label = vm.sceneTitle(sceneId) ?: sceneId
                    MaterialPickRow(
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

    when (dialog) {
        RecordsDialog.ClearAll -> MaterialAlert(
            onDismissRequest = { dialog = RecordsDialog.None },
            title = vm.t("historyClear"),
            text = vm.t("historyClearConfirm"),
            confirmLabel = vm.t("confirmLabel"),
            onConfirm = {
                vm.clearHistory()
                filterSceneId = null
                dialog = RecordsDialog.None
            },
            dismissLabel = vm.t("cancelLabel"),
            onDismiss = { dialog = RecordsDialog.None },
            destructive = true,
        )
        RecordsDialog.DeleteOne -> MaterialAlert(
            onDismissRequest = {
                dialog = RecordsDialog.None
                pendingDeleteId = null
            },
            title = vm.t("historyDelete"),
            text = vm.t("historyDeleteConfirm"),
            confirmLabel = vm.t("historyDelete"),
            onConfirm = {
                pendingDeleteId?.let { vm.deleteHistorySession(it) }
                dialog = RecordsDialog.None
                pendingDeleteId = null
            },
            dismissLabel = vm.t("cancelLabel"),
            onDismiss = {
                dialog = RecordsDialog.None
                pendingDeleteId = null
            },
            destructive = true,
        )
        RecordsDialog.None -> Unit
    }
}

@Composable
private fun StatCard(
    title: String,
    value: String,
    unit: String?,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(FiveMinDimens.radiusCard),
        colors = CardDefaults.cardColors(
            containerColor = FiveMinColors.brandSoft.copy(alpha = 0.55f),
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        border = androidx.compose.foundation.BorderStroke(
            1.dp,
            FiveMinColors.brand.copy(alpha = 0.12f),
        ),
    ) {
        Column(
            modifier = Modifier.padding(FiveMinDimens.padBody),
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
}

@Composable
private fun HistoryRow(vm: TimerViewModel, item: HistoryItem, onDelete: () -> Unit) {
    val scene = vm.sceneTitle(item.sceneId.takeIf { it.isNotBlank() })
        ?: vm.t("historySceneDefault")
    val time = formatDateTime(item.at)
    ListItem(
        modifier = Modifier.fillMaxWidth(),
        supportingContent = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = vm.t("historyDurationLine", mapOf("n" to item.minutes.toString())),
                    color = FiveMinColors.ink,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = vm.t("historyTimeLine", mapOf("time" to time)),
                    color = FiveMinColors.muted,
                    fontSize = 13.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        },
        trailingContent = {
            TextButton(
                onClick = onDelete,
                colors = ButtonDefaults.textButtonColors(contentColor = FiveMinColors.danger),
            ) {
                Text(vm.t("historyDelete"), fontSize = 13.sp, fontWeight = FontWeight.Medium)
            }
        },
        colors = ListItemDefaults.colors(containerColor = androidx.compose.ui.graphics.Color.Transparent),
    ) {
        Text(
            text = vm.t("historySceneLine", mapOf("scene" to scene)),
            color = FiveMinColors.ink,
            fontSize = 14.sp,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

private fun formatDateTime(at: Long): String {
    val fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss", Locale.US)
    return Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).format(fmt)
}

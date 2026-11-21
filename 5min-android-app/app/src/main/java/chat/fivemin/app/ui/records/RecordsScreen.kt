package chat.fivemin.app.ui.records

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.data.HistoryItem
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private enum class RecordsDialog { None, ClearAll, DeleteOne }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordsScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsState()
    var rows by remember { mutableStateOf<List<HistoryItem>>(emptyList()) }
    var periodCount by remember { mutableIntStateOf(0) }
    var periodMins by remember { mutableIntStateOf(0) }
    var filterSceneId by remember { mutableStateOf<String?>(null) }
    var filterExpanded by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf(RecordsDialog.None) }
    var pendingDeleteId by remember { mutableStateOf<Long?>(null) }

    fun reload() {
        val history = FiveMinApp.instance.history
        rows = history.getHistory(filterSceneId)
        val period = history.periodStats()
        periodCount = period.first
        periodMins = period.second
    }

    val filterOptions = remember(state.recordsEpoch, state.locale, state.customScenes) {
        val all = FiveMinApp.instance.history.getHistory()
        all.map { it.sceneId }.filter { it.isNotBlank() }.distinct()
    }

    LaunchedEffect(state.recordsEpoch, state.locale, filterSceneId) { reload() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(FiveMinColors.bg, FiveMinColors.bg2, FiveMinColors.bgBottom),
                ),
            ),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .background(FiveMinColors.surface.copy(alpha = 0.72f))
                .padding(horizontal = 20.dp)
                .padding(vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = vm.t("tabRecords"),
                color = FiveMinColors.ink,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f),
            )
            if (rows.isNotEmpty() || filterOptions.isNotEmpty()) {
                Text(
                    text = vm.t("historyClear"),
                    color = FiveMinColors.danger,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.clickable { dialog = RecordsDialog.ClearAll },
                )
            }
        }
        HorizontalDivider(color = FiveMinColors.line, thickness = 1.dp)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(FiveMinDimens.padBody),
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
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
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
                    )
                    Text(
                        text = vm.t("overtimeInsightHint"),
                        color = FiveMinColors.muted,
                        fontSize = 12.sp,
                    )
                    Text(
                        text = vm.t("overtimeInsightTip"),
                        color = FiveMinColors.muted,
                        fontSize = 12.sp,
                    )
                }
            }
            Text(
                text = vm.t("historyLabel"),
                color = FiveMinColors.muted,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp),
            )
            if (filterOptions.isNotEmpty()) {
                val selectedLabel = filterSceneId
                    ?.let { id -> vm.sceneTitle(id) ?: id }
                    ?: vm.t("historyFilterAll")
                // 与主页场景选择触发器同尺寸：rowH 40 / radius 22
                val filterRadius = RoundedCornerShape(FiveMinDimens.radius)
                ExposedDropdownMenuBox(
                    expanded = filterExpanded,
                    onExpandedChange = { filterExpanded = it },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        modifier = Modifier
                            .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                            .fillMaxWidth()
                            .height(FiveMinDimens.rowH)
                            .shadow(elevation = 2.dp, shape = filterRadius, clip = false)
                            .clip(filterRadius)
                            .border(
                                1.dp,
                                if (filterExpanded) {
                                    FiveMinColors.brand.copy(alpha = 0.45f)
                                } else {
                                    FiveMinColors.line
                                },
                                filterRadius,
                            )
                            .background(FiveMinColors.surface)
                            .padding(horizontal = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = selectedLabel,
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = if (filterSceneId == null) {
                                FiveMinColors.muted
                            } else {
                                FiveMinColors.ink
                            },
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                        Icon(
                            imageVector = Icons.Default.KeyboardArrowDown,
                            contentDescription = vm.t("historyFilterLabel"),
                            tint = if (filterExpanded) {
                                FiveMinColors.brandStrong
                            } else {
                                FiveMinColors.muted
                            },
                            modifier = Modifier.size(18.dp),
                        )
                    }
                    ExposedDropdownMenu(
                        expanded = filterExpanded,
                        onDismissRequest = { filterExpanded = false },
                        containerColor = FiveMinColors.surface,
                    ) {
                        DropdownMenuItem(
                            text = {
                                Text(
                                    text = vm.t("historyFilterAll"),
                                    color = if (filterSceneId == null) {
                                        FiveMinColors.brandStrong
                                    } else {
                                        FiveMinColors.ink
                                    },
                                    fontWeight = if (filterSceneId == null) {
                                        FontWeight.SemiBold
                                    } else {
                                        FontWeight.Normal
                                    },
                                    fontSize = 14.sp,
                                )
                            },
                            onClick = {
                                filterSceneId = null
                                filterExpanded = false
                            },
                        )
                        filterOptions.forEach { sceneId ->
                            val label = vm.sceneTitle(sceneId) ?: sceneId
                            val active = filterSceneId == sceneId
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        text = label,
                                        color = if (active) {
                                            FiveMinColors.brandStrong
                                        } else {
                                            FiveMinColors.ink
                                        },
                                        fontWeight = if (active) {
                                            FontWeight.SemiBold
                                        } else {
                                            FontWeight.Normal
                                        },
                                        fontSize = 14.sp,
                                    )
                                },
                                onClick = {
                                    filterSceneId = sceneId
                                    filterExpanded = false
                                },
                            )
                        }
                    }
                }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        FiveMinColors.surface.copy(alpha = 0.88f),
                        RoundedCornerShape(FiveMinDimens.radiusCard),
                    )
                    .border(
                        1.dp,
                        FiveMinColors.line.copy(alpha = 0.9f),
                        RoundedCornerShape(FiveMinDimens.radiusCard),
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
                            .padding(vertical = 28.dp, horizontal = 20.dp),
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
                                modifier = Modifier.padding(start = 16.dp),
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
                TextButton(onClick = { dialog = RecordsDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.clearHistory()
                    filterSceneId = null
                    dialog = RecordsDialog.None
                }) {
                    Text(vm.t("confirmLabel"), color = FiveMinColors.danger, fontWeight = FontWeight.SemiBold)
                }
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
                TextButton(onClick = {
                    dialog = RecordsDialog.None
                    pendingDeleteId = null
                }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    pendingDeleteId?.let { vm.deleteHistorySession(it) }
                    dialog = RecordsDialog.None
                    pendingDeleteId = null
                }) {
                    Text(vm.t("historyDelete"), color = FiveMinColors.danger, fontWeight = FontWeight.SemiBold)
                }
            },
            title = { Text(vm.t("historyDelete"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = { Text(vm.t("historyDeleteConfirm"), color = FiveMinColors.ink) },
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
            .padding(16.dp),
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
            .padding(start = 16.dp, end = 8.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(vm.t("historySceneLine", mapOf("scene" to scene)), color = FiveMinColors.ink, fontSize = 14.sp)
            Text(vm.t("historyDurationLine", mapOf("n" to item.minutes.toString())), color = FiveMinColors.ink, fontSize = 14.sp)
            Text(vm.t("historyTimeLine", mapOf("time" to time)), color = FiveMinColors.ink, fontSize = 14.sp)
        }
        Icon(
            imageVector = Icons.Default.Delete,
            contentDescription = vm.t("historyDelete"),
            tint = FiveMinColors.danger,
            modifier = Modifier
                .size(22.dp)
                .clickable(onClick = onDelete)
                .padding(4.dp),
        )
    }
}

private fun formatDateTime(at: Long): String {
    val fmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
    return fmt.format(Date(at))
}
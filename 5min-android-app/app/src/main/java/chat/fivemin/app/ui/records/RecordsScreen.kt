package chat.fivemin.app.ui.records

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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

@Composable
fun RecordsScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsState()
    var rows by remember { mutableStateOf<List<HistoryItem>>(emptyList()) }
    var periodCount by remember { mutableIntStateOf(0) }
    var periodMins by remember { mutableIntStateOf(0) }
    var filterSceneId by remember { mutableStateOf<String?>(null) }
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
            .background(FiveMinColors.bg2),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .background(FiveMinColors.surface)
                .padding(horizontal = 20.dp)
                .padding(vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = vm.t("tabRecords"),
                color = FiveMinColors.ink,
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium,
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
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
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
                text = vm.t("historyLabel"),
                color = FiveMinColors.muted,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(start = 4.dp, top = 4.dp),
            )
            if (filterOptions.isNotEmpty()) {
                Text(
                    text = vm.t("historyFilterLabel"),
                    color = FiveMinColors.muted,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier.padding(start = 4.dp),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilterChip(
                        label = vm.t("historyFilterAll"),
                        active = filterSceneId == null,
                        onClick = { filterSceneId = null },
                    )
                    filterOptions.forEach { sceneId ->
                        val label = vm.sceneTitle(sceneId) ?: sceneId
                        FilterChip(
                            label = label,
                            active = filterSceneId == sceneId,
                            onClick = { filterSceneId = sceneId },
                        )
                    }
                }
            }
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(FiveMinColors.surface, RoundedCornerShape(14.dp)),
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
private fun FilterChip(label: String, active: Boolean, onClick: () -> Unit) {
    val radius = RoundedCornerShape(FiveMinDimens.radius)
    Text(
        text = label,
        modifier = Modifier
            .height(FiveMinDimens.chipH)
            .clip(radius)
            .border(
                1.dp,
                if (active) FiveMinColors.brand.copy(alpha = 0.35f) else FiveMinColors.line,
                radius,
            )
            .background(if (active) FiveMinColors.brandSoft else FiveMinColors.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp)
            .wrapContentHeight(Alignment.CenterVertically),
        color = if (active) FiveMinColors.brandStrong else FiveMinColors.muted,
        fontWeight = FontWeight.SemiBold,
        fontSize = 13.sp,
        maxLines = 1,
    )
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
            .background(FiveMinColors.surface, RoundedCornerShape(14.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(title, color = FiveMinColors.muted, fontSize = 12.sp)
        Row(verticalAlignment = Alignment.Bottom) {
            Text(value, color = FiveMinColors.ink, fontSize = 28.sp, fontWeight = FontWeight.Medium)
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
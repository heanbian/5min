package chat.fivemin.app.ui.records

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.data.HistoryItem
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun RecordsScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsState()
    var rows by remember { mutableStateOf<List<HistoryItem>>(emptyList()) }
    var periodCount by remember { mutableIntStateOf(0) }
    var periodMins by remember { mutableIntStateOf(0) }

    fun reload() {
        val history = FiveMinApp.instance.history
        rows = history.getHistory()
        val period = history.periodStats()
        periodCount = period.first
        periodMins = period.second
    }

    LaunchedEffect(state.recordsEpoch, state.locale) { reload() }

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
            )
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
                        HistoryRow(vm, item)
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
private fun HistoryRow(vm: TimerViewModel, item: HistoryItem) {
    val catalog = FiveMinApp.instance.catalog
    val scene = item.sceneId.takeIf { it.isNotBlank() }
        ?.let { id -> catalog.scenes.find { it.id == id }?.let { vm.t(it.titleKey) } }
        ?: vm.t("historySceneDefault")
    val time = formatDateTime(item.at)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(vm.t("historySceneLine", mapOf("scene" to scene)), color = FiveMinColors.ink, fontSize = 14.sp)
        Text(vm.t("historyDurationLine", mapOf("n" to item.minutes.toString())), color = FiveMinColors.ink, fontSize = 14.sp)
        Text(vm.t("historyTimeLine", mapOf("time" to time)), color = FiveMinColors.ink, fontSize = 14.sp)
    }
}

private fun formatDateTime(at: Long): String {
    val fmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)
    return fmt.format(Date(at))
}

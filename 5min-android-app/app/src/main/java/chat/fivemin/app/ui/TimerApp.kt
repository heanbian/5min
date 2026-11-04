package chat.fivemin.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.timer.TimerPhase
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TimerApp(vm: TimerViewModel = viewModel()) {
    val state by vm.state.collectAsState()
    val catalog = FiveMinApp.instance.catalog
    var langOpen by remember { mutableStateOf(false) }
    var ambientOpen by remember { mutableStateOf(false) }
    var sceneOpen by remember { mutableStateOf(false) }

    val ringColor = when (state.phase) {
        TimerPhase.Warn -> FiveMinColors.warn
        TimerPhase.Done -> FiveMinColors.danger
        else -> FiveMinColors.brand
    }
    val title = state.activeSceneId?.let { id ->
        catalog.scenes.find { it.id == id }?.let { vm.t(it.titleKey) }
    } ?: vm.t("brandTitle")
    val status = when (state.phase) {
        TimerPhase.Done -> vm.t("statusDone")
        TimerPhase.Warn -> vm.t("statusWarn")
        TimerPhase.Running -> vm.t("statusRunning")
        TimerPhase.Paused -> vm.t("statusPaused")
        TimerPhase.Idle -> vm.t("statusIdle")
    }
    val startLabel = when {
        state.finished && !state.running -> vm.t("again")
        state.running -> vm.t("pause")
        state.remainMs < state.totalMs && state.remainMs > 0 -> vm.t("resume")
        else -> vm.t("start")
    }
    val statsText = if (state.statsCount <= 0) {
        "${vm.t("dailyStatsLabel")} · ${vm.t("dailyStatsEmpty")}"
    } else {
        "${vm.t("dailyStatsLabel")} · ${state.statsCount}${vm.t("dailyStatsCountUnit")} · ${vm.statsMinutes()}${vm.t("dailyStatsMinutesUnit")}"
    }
    val sceneLabel = state.activeSceneId?.let { id ->
        catalog.scenes.find { it.id == id }?.let { vm.t(it.labelKey) }
    } ?: vm.t("scenePlaceholder")

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(padding)
                .padding(horizontal = 20.dp, vertical = 16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Box {
                    IconButton(onClick = { ambientOpen = true }) {
                        Icon(Icons.Default.VolumeUp, contentDescription = vm.t("ambientLabel"))
                    }
                    DropdownMenu(expanded = ambientOpen, onDismissRequest = { ambientOpen = false }) {
                        listOf("off" to "ambientOff", "rain" to "ambientRain", "waves" to "ambientWaves", "clock" to "ambientClock").forEach { (id, key) ->
                            DropdownMenuItem(
                                text = { Text(vm.t(key)) },
                                onClick = {
                                    vm.setAmbient(id)
                                    ambientOpen = false
                                },
                            )
                        }
                    }
                }
                Box {
                    IconButton(onClick = { langOpen = true }) {
                        Icon(Icons.Default.Language, contentDescription = vm.t("langLabel"))
                    }
                    DropdownMenu(expanded = langOpen, onDismissRequest = { langOpen = false }) {
                        catalog.localeCodes.forEach { code ->
                            DropdownMenuItem(
                                text = { Text(catalog.t(code, "nativeName")) },
                                onClick = {
                                    vm.setLocale(code)
                                    langOpen = false
                                },
                            )
                        }
                    }
                }
            }

            Text(
                text = statsText,
                color = FiveMinColors.muted,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                val progress = state.progress
                Canvas(modifier = Modifier.size(240.dp)) {
                    val stroke = 14.dp.toPx()
                    drawArc(
                        color = Color(0xFFD7E5DC),
                        startAngle = -90f,
                        sweepAngle = 360f,
                        useCenter = false,
                        style = Stroke(width = stroke, cap = StrokeCap.Round),
                        size = Size(size.minDimension, size.minDimension),
                        topLeft = Offset.Zero,
                    )
                    drawArc(
                        color = ringColor,
                        startAngle = -90f,
                        sweepAngle = 360f * progress,
                        useCenter = false,
                        style = Stroke(width = stroke, cap = StrokeCap.Round),
                        size = Size(size.minDimension, size.minDimension),
                        topLeft = Offset.Zero,
                    )
                }
                Text(
                    text = vm.format(state.remainMs),
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Bold,
                    color = ringColor,
                )
            }

            Text(
                text = status,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onBackground,
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Button(
                    onClick = { vm.toggleStart() },
                    modifier = Modifier.weight(1f).height(52.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = FiveMinColors.brand),
                ) { Text(startLabel) }
                OutlinedButton(
                    onClick = { vm.reset() },
                    enabled = state.running || state.remainMs < state.totalMs || state.finished,
                    modifier = Modifier.weight(1f).height(52.dp),
                ) { Text(vm.t("reset")) }
            }

            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                catalog.presetsMin.forEach { min ->
                    val active = state.activeSceneId == null && state.totalMs == min * 60_000L
                    FilterChip(
                        selected = active,
                        onClick = { if (!state.running) vm.setPresetMinutes(min, null) },
                        enabled = !state.running,
                        label = { Text(vm.t("minutes", mapOf("n" to min.toString()))) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = FiveMinColors.brandSoft,
                            selectedLabelColor = FiveMinColors.brandStrong,
                        ),
                    )
                }
            }

            OutlinedButton(
                onClick = { if (!state.running) sceneOpen = true },
                enabled = !state.running,
                modifier = Modifier.fillMaxWidth().height(48.dp),
            ) {
                Text(
                    text = sceneLabel,
                    modifier = Modifier.weight(1f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Icon(Icons.Default.ExpandMore, contentDescription = null)
            }

            Text(
                text = vm.t("footnote"),
                style = MaterialTheme.typography.bodySmall,
                color = FiveMinColors.muted,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 24.dp),
            )
        }
    }

    if (sceneOpen) {
        AlertDialog(
            onDismissRequest = { sceneOpen = false },
            confirmButton = {
                TextButton(onClick = { sceneOpen = false }) { Text(vm.t("reset").let { "OK" }) }
            },
            title = { Text(vm.t("scenesLabel")) },
            text = {
                LazyColumn(modifier = Modifier.height(420.dp)) {
                    catalog.groups.forEach { group ->
                        val itemsInGroup = catalog.scenes.filter { it.group == group.id }
                        if (itemsInGroup.isEmpty()) return@forEach
                        item {
                            Text(
                                text = vm.t(group.labelKey),
                                color = FiveMinColors.brandStrong,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(FiveMinColors.brandSoft, RoundedCornerShape(8.dp))
                                    .padding(horizontal = 10.dp, vertical = 8.dp),
                            )
                            Spacer(Modifier = Modifier.height(4.dp))
                        }
                        items(itemsInGroup, key = { it.id }) { scene ->
                            Text(
                                text = vm.t(scene.labelKey),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        vm.selectScene(scene.id)
                                        sceneOpen = false
                                    }
                                    .padding(horizontal = 12.dp, vertical = 12.dp),
                                color = if (scene.id == state.activeSceneId) FiveMinColors.brandStrong else FiveMinColors.muted,
                                fontWeight = if (scene.id == state.activeSceneId) FontWeight.Bold else FontWeight.SemiBold,
                            )
                        }
                    }
                }
            },
        )
    }
}

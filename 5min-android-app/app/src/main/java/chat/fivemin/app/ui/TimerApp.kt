package chat.fivemin.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.R
import chat.fivemin.app.timer.TimerPhase
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

@Composable
fun TimerApp(
    vm: TimerViewModel = viewModel(),
    ensureStartPermissions: (onReady: () -> Unit) -> Unit = { it() },
) {
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
    val timeColor = when (state.phase) {
        TimerPhase.Warn -> FiveMinColors.warn
        TimerPhase.Done -> FiveMinColors.danger
        else -> FiveMinColors.ink
    }
    val statusColor = when (state.phase) {
        TimerPhase.Warn -> FiveMinColors.warn
        TimerPhase.Done -> FiveMinColors.danger
        else -> FiveMinColors.muted
    }
    val bgBrush = when (state.phase) {
        TimerPhase.Warn -> Brush.verticalGradient(
            listOf(FiveMinColors.warnSoft, FiveMinColors.warnBottom),
        )
        TimerPhase.Done -> Brush.verticalGradient(
            listOf(FiveMinColors.dangerSoft, FiveMinColors.dangerBottom),
        )
        else -> Brush.verticalGradient(
            listOf(FiveMinColors.bg, FiveMinColors.bg2, FiveMinColors.bgBottom),
        )
    }
    val glowColor = when (state.phase) {
        TimerPhase.Warn -> FiveMinColors.warnGlow
        TimerPhase.Done -> FiveMinColors.dangerGlow
        else -> FiveMinColors.glow
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
    val sceneLabel = state.activeSceneId?.let { id ->
        catalog.scenes.find { it.id == id }?.let { vm.t(it.labelKey) }
    } ?: vm.t("scenePlaceholder")
    val scenePlaceholder = state.activeSceneId == null
    val resetEnabled = state.running || state.remainMs < state.totalMs || state.finished
    val setupEnabled = !state.running
    val radius = RoundedCornerShape(FiveMinDimens.radius)
    val localeLabel = catalog.t(state.locale, "nativeName")

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(bgBrush),
    ) {
        // Soft radial glow (matches web body background)
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(glowColor.copy(alpha = 0.95f), Color.Transparent),
                    center = Offset(size.width / 2f, size.height * -0.02f),
                    radius = size.minDimension * 0.95f,
                ),
                radius = size.minDimension * 0.95f,
                center = Offset(size.width / 2f, size.height * -0.02f),
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = FiveMinDimens.padX, vertical = FiveMinDimens.padY)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(FiveMinDimens.sectionGap),
        ) {
            // —— topbar（与 web .topbar 等高 36dp、纵向居中）——
            val topbarH = 36.dp
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(topbarH),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Image(
                        painter = painterResource(R.drawable.logo),
                        contentDescription = "5min",
                        modifier = Modifier
                            .height(22.dp)
                            .width(22.dp * 108f / 32f),
                        contentScale = ContentScale.Fit,
                    )
                    Text(
                        text = title,
                        color = FiveMinColors.ink,
                        fontSize = 19.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        letterSpacing = 0.1.sp,
                        lineHeight = 36.sp,
                        modifier = Modifier
                            .weight(1f, fill = false)
                            .fillMaxHeight()
                            .wrapContentHeight(Alignment.CenterVertically),
                    )
                }

                Row(
                    modifier = Modifier.fillMaxHeight(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Box {
                        Box(
                            modifier = Modifier
                                .size(topbarH)
                                .clickable { ambientOpen = true },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                Icons.AutoMirrored.Filled.VolumeUp,
                                contentDescription = vm.t("ambientLabel"),
                                tint = if (ambientOpen) FiveMinColors.brandStrong else FiveMinColors.muted,
                                modifier = Modifier.size(20.dp),
                            )
                        }
                        DropdownMenu(
                            expanded = ambientOpen,
                            onDismissRequest = { ambientOpen = false },
                            shape = RoundedCornerShape(FiveMinDimens.radiusSm),
                            containerColor = FiveMinColors.surface,
                        ) {
                            listOf(
                                "off" to "ambientOff",
                                "rain" to "ambientRain",
                                "waves" to "ambientWaves",
                                "clock" to "ambientClock",
                            ).forEach { (id, key) ->
                                val active = state.ambient == id
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            vm.t(key),
                                            color = if (active) FiveMinColors.brandStrong else FiveMinColors.muted,
                                            fontWeight = FontWeight.SemiBold,
                                            fontSize = 14.sp,
                                        )
                                    },
                                    onClick = {
                                        vm.setAmbient(id)
                                        ambientOpen = false
                                    },
                                    modifier = if (active) {
                                        Modifier.background(FiveMinColors.brandSoft, RoundedCornerShape(8.dp))
                                    } else Modifier,
                                )
                            }
                        }
                    }

                    Box {
                        Row(
                            modifier = Modifier
                                .height(topbarH)
                                .clickable { langOpen = true }
                                .padding(start = 6.dp, end = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Text(
                                text = localeLabel,
                                color = if (langOpen) FiveMinColors.brandStrong else FiveMinColors.muted,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp,
                                maxLines = 1,
                                lineHeight = 14.sp,
                            )
                            Icon(
                                Icons.Default.KeyboardArrowDown,
                                contentDescription = null,
                                tint = if (langOpen) FiveMinColors.brandStrong else FiveMinColors.muted,
                                modifier = Modifier.size(12.dp),
                            )
                        }
                        DropdownMenu(
                            expanded = langOpen,
                            onDismissRequest = { langOpen = false },
                            shape = RoundedCornerShape(FiveMinDimens.radiusSm),
                            containerColor = FiveMinColors.surface,
                        ) {
                            catalog.localeCodes.forEach { code ->
                                val active = state.locale == code
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            catalog.t(code, "nativeName"),
                                            color = if (active) FiveMinColors.brandStrong else FiveMinColors.muted,
                                            fontWeight = FontWeight.SemiBold,
                                            fontSize = 14.sp,
                                        )
                                    },
                                    onClick = {
                                        vm.setLocale(code)
                                        langOpen = false
                                    },
                                    modifier = if (active) {
                                        Modifier.background(FiveMinColors.brandSoft, RoundedCornerShape(8.dp))
                                    } else Modifier,
                                )
                            }
                        }
                    }
                }
            }

            // —— stage: dial + cue ——
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(FiveMinDimens.stageGap),
            ) {
                Box(
                    modifier = Modifier.size(FiveMinDimens.dialSize),
                    contentAlignment = Alignment.Center,
                ) {
                    val progress = state.progress
                    Canvas(modifier = Modifier.fillMaxSize()) {
                        // Match web stroke-width 8.5 on viewBox 120
                        val stroke = size.minDimension * (8.5f / 120f)
                        drawArc(
                            color = FiveMinColors.ring,
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
                    DigitalWatchTime(
                        text = vm.format(state.remainMs),
                        color = timeColor,
                    )
                }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.padding(horizontal = 12.dp),
                ) {
                    Text(
                        text = status,
                        color = statusColor,
                        fontSize = 14.sp,
                        fontWeight = if (state.phase == TimerPhase.Done) FontWeight.SemiBold else FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        lineHeight = 21.sp,
                        modifier = Modifier.fillMaxWidth(0.9f),
                    )
                    if (state.statsCount <= 0) {
                        Text(
                            text = "${vm.t("dailyStatsLabel")} · ${vm.t("dailyStatsEmpty")}",
                            color = FiveMinColors.muted,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            textAlign = TextAlign.Center,
                        )
                    } else {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                text = vm.t("dailyStatsLabel"),
                                color = FiveMinColors.muted,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                            )
                            Text(
                                text = "·",
                                color = FiveMinColors.muted,
                                fontSize = 12.sp,
                            )
                            Text(
                                text = buildString {
                                    append(state.statsCount)
                                    append(vm.t("dailyStatsCountUnit"))
                                    append(" · ")
                                    append(vm.statsMinutes())
                                    append(vm.t("dailyStatsMinutesUnit"))
                                },
                                color = FiveMinColors.ink,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }

            // —— actions ——
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(FiveMinDimens.controlH)
                            .clip(radius)
                            .background(FiveMinColors.brand)
                            .clickable {
                                if (state.running) {
                                    vm.toggleStart()
                                } else {
                                    ensureStartPermissions { vm.toggleStart() }
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = startLabel,
                            color = Color.White,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 16.sp,
                        )
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(FiveMinDimens.controlH)
                            .clip(radius)
                            .border(1.dp, FiveMinColors.ghostLine, radius)
                            .background(FiveMinColors.ghostBg)
                            .then(
                                if (resetEnabled) {
                                    Modifier.clickable { vm.reset() }
                                } else {
                                    Modifier
                                },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = vm.t("reset"),
                            color = FiveMinColors.ghostInk.copy(alpha = if (resetEnabled) 1f else 0.4f),
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 16.sp,
                        )
                    }
                }

                // presets: segmented control
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(FiveMinDimens.rowH)
                        .clip(radius)
                        .border(1.dp, FiveMinColors.line, radius)
                        .background(FiveMinColors.surface),
                ) {
                    catalog.presetsMin.forEachIndexed { index, min ->
                        val active = state.activeSceneId == null && state.totalMs == min * 60_000L
                        if (index > 0) {
                            Box(
                                modifier = Modifier
                                    .width(1.dp)
                                    .fillMaxHeight()
                                    .background(FiveMinColors.line),
                            )
                        }
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .background(if (active) FiveMinColors.brandSoft else FiveMinColors.surface)
                                .then(
                                    if (setupEnabled) {
                                        Modifier.clickable {
                                            vm.setPresetMinutes(min, null)
                                        }
                                    } else Modifier,
                                ),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = vm.t("minutes", mapOf("n" to min.toString())),
                                color = when {
                                    !setupEnabled -> FiveMinColors.muted.copy(alpha = 0.4f)
                                    active -> FiveMinColors.brandStrong
                                    else -> FiveMinColors.muted
                                },
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp,
                            )
                        }
                    }
                }

                // scene trigger
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(FiveMinDimens.rowH)
                        .clip(radius)
                        .border(
                            1.dp,
                            if (sceneOpen) FiveMinColors.brand.copy(alpha = 0.45f) else FiveMinColors.line,
                            radius,
                        )
                        .background(FiveMinColors.surface)
                        .then(
                            if (setupEnabled) {
                                Modifier.clickable { sceneOpen = true }
                            } else Modifier,
                        )
                        .padding(horizontal = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = sceneLabel,
                        modifier = Modifier.weight(1f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        color = when {
                            !setupEnabled -> FiveMinColors.muted.copy(alpha = 0.4f)
                            scenePlaceholder -> FiveMinColors.muted
                            else -> FiveMinColors.ink
                        },
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp,
                    )
                    Icon(
                        Icons.Default.KeyboardArrowDown,
                        contentDescription = null,
                        tint = if (sceneOpen) FiveMinColors.brandStrong else FiveMinColors.muted,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            Text(
                text = vm.t("footnote"),
                color = FiveMinColors.muted,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                textAlign = TextAlign.Center,
                lineHeight = 20.sp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 4.dp, bottom = 8.dp),
            )
        }
    }

    if (sceneOpen) {
        AlertDialog(
            onDismissRequest = { sceneOpen = false },
            confirmButton = {
                TextButton(onClick = { sceneOpen = false }) {
                    Text("OK", color = FiveMinColors.brandStrong, fontWeight = FontWeight.SemiBold)
                }
            },
            containerColor = FiveMinColors.surface,
            shape = RoundedCornerShape(FiveMinDimens.radius),
            title = {
                Text(
                    vm.t("scenesLabel"),
                    color = FiveMinColors.ink,
                    fontWeight = FontWeight.SemiBold,
                )
            },
            text = {
                LazyColumn(modifier = Modifier.height(420.dp)) {
                    catalog.groups.forEach { group ->
                        val itemsInGroup = catalog.scenes.filter { it.group == group.id }
                        if (itemsInGroup.isEmpty()) return@forEach
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(bottom = 2.dp)
                                    .background(
                                        FiveMinColors.brandSoft.copy(alpha = 0.72f),
                                        RoundedCornerShape(8.dp),
                                    )
                                    .border(
                                        1.dp,
                                        FiveMinColors.brand.copy(alpha = 0.14f),
                                        RoundedCornerShape(8.dp),
                                    )
                                    .padding(horizontal = 10.dp, vertical = 7.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Box(
                                    modifier = Modifier
                                        .width(3.dp)
                                        .height(12.dp)
                                        .background(FiveMinColors.brand, RoundedCornerShape(2.dp)),
                                )
                                Text(
                                    text = vm.t(group.labelKey),
                                    color = FiveMinColors.brandStrong,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 11.sp,
                                    letterSpacing = 0.8.sp,
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                        }
                        items(itemsInGroup, key = { it.id }) { scene ->
                            val active = scene.id == state.activeSceneId
                            Text(
                                text = vm.t(scene.labelKey),
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(11.dp))
                                    .background(if (active) FiveMinColors.brandSoft else Color.Transparent)
                                    .clickable {
                                        vm.selectScene(scene.id)
                                        sceneOpen = false
                                    }
                                    .padding(horizontal = 12.dp, vertical = 10.dp),
                                color = if (active) FiveMinColors.brandStrong else FiveMinColors.muted,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 14.sp,
                            )
                        }
                    }
                }
            },
        )
    }
}

package chat.fivemin.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import android.app.Activity
import android.view.WindowManager
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.R
import chat.fivemin.app.timer.TimerPhase
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

@Composable
fun TimerHome(
    vm: TimerViewModel,
    ensureStartPermissions: (onReady: () -> Unit) -> Unit = { it() },
    onOpenMine: () -> Unit = {},
) {
    val state by vm.state.collectAsState()
    var sceneOpen by remember { mutableStateOf(false) }
    var ritualUp by remember { mutableStateOf(false) }
    var ritualStretch by remember { mutableStateOf(false) }
    var ritualLeave by remember { mutableStateOf(false) }
    LaunchedEffect(state.showStandRitual) {
        if (state.showStandRitual) {
            ritualUp = false
            ritualStretch = false
            ritualLeave = false
        }
    }
    val view = LocalView.current
    DisposableEffect(state.running) {
        val window = (view.context as? Activity)?.window
        if (state.running) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    val ringColor = when (state.phase) {
        TimerPhase.Warn -> FiveMinColors.warn
        TimerPhase.Done -> FiveMinColors.danger
        else -> FiveMinColors.brand
    }
    val timeColor = when (state.phase) {
        TimerPhase.Warn -> FiveMinColors.warn
        TimerPhase.Done -> FiveMinColors.danger
        else -> Color.Black
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

    val title = vm.sceneTitle(state.activeSceneId) ?: vm.t("brandTitle")
    val dialMs = if (state.finished && !state.running) state.overtimeMs else state.remainMs
    val status = when (state.phase) {
        TimerPhase.Done -> if (state.finished) {
            vm.t("statusOvertime", mapOf("n" to vm.format(state.overtimeMs)))
        } else {
            vm.statusDoneText()
        }
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
    val sceneLabel = vm.sceneLabel(state.activeSceneId) ?: vm.t("scenePlaceholder")
    val scenePlaceholder = state.activeSceneId == null
    val resetEnabled = state.running || state.remainMs < state.totalMs || state.finished
    val setupEnabled = !state.running
    val radius = RoundedCornerShape(FiveMinDimens.radius)

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
                            .height(24.dp)
                            .width(24.dp * 108f / 32f),
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

                Box(
                    modifier = Modifier
                        .size(topbarH)
                        .clickable(onClick = onOpenMine),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = if (state.ambient == "off") {
                            Icons.AutoMirrored.Filled.VolumeOff
                        } else {
                            Icons.AutoMirrored.Filled.VolumeUp
                        },
                        contentDescription = vm.t("ambientLabel"),
                        tint = if (state.ambient == "off") {
                            FiveMinColors.muted.copy(alpha = 0.85f)
                        } else {
                            FiveMinColors.muted.copy(alpha = 0.55f)
                        },
                        modifier = Modifier.size(20.dp),
                    )
                }
            }

            // —— stage: dial + cue ——
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(FiveMinDimens.stageGap),
            ) {
                val pulsePhase = state.phase == TimerPhase.Warn || state.phase == TimerPhase.Done
                val pulseTransition = rememberInfiniteTransition(label = "dialPulse")
                val dialScale by pulseTransition.animateFloat(
                    initialValue = 1f,
                    targetValue = if (pulsePhase) 1.018f else 1f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(if (state.phase == TimerPhase.Done) 625 else 900),
                        repeatMode = RepeatMode.Reverse,
                    ),
                    label = "dialScale",
                )
                Box(
                    modifier = Modifier
                        .size(FiveMinDimens.dialSize)
                        .scale(if (pulsePhase) dialScale else 1f)
                        .clickable(enabled = state.finished) { vm.realert() },
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
                        text = vm.format(dialMs),
                        color = timeColor,
                        blinking = state.running,
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
                            StatsSepDot()
                            Text(
                                text = "${state.statsCount}${vm.t("dailyStatsCountUnit")}",
                                color = FiveMinColors.ink,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                            StatsSepDot()
                            Text(
                                text = "${vm.statsMinutes()}${vm.t("dailyStatsMinutesUnit")}",
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
                verticalArrangement = Arrangement.spacedBy(FiveMinDimens.controlGap),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(FiveMinDimens.controlGap),
                ) {
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(FiveMinDimens.controlH)
                            .shadow(
                                elevation = 8.dp,
                                shape = radius,
                                ambientColor = FiveMinColors.brand.copy(alpha = 0.28f),
                                spotColor = FiveMinColors.brand.copy(alpha = 0.35f),
                            )
                            .clip(radius)
                            .background(
                                Brush.verticalGradient(
                                    listOf(
                                        FiveMinColors.brandLift,
                                        FiveMinColors.brand,
                                        FiveMinColors.brandStrong,
                                    ),
                                ),
                            )
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
                            .shadow(elevation = 2.dp, shape = radius, clip = false)
                            .clip(radius)
                            .border(1.5.dp, FiveMinColors.line, radius)
                            .background(FiveMinColors.surface)
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
                            color = FiveMinColors.muted.copy(alpha = if (resetEnabled) 1f else 0.38f),
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 16.sp,
                        )
                    }
                }

                if (state.sessionLogged && state.finished && !state.running) {
                    val ignoreInteraction = remember { MutableInteractionSource() }
                    val ignorePressed by ignoreInteraction.collectIsPressedAsState()
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(FiveMinDimens.controlH)
                            .clip(radius)
                            .border(
                                1.dp,
                                FiveMinColors.danger.copy(alpha = if (ignorePressed) 0.55f else 0.35f),
                                radius,
                            )
                            .background(
                                if (ignorePressed) FiveMinColors.dangerSoft
                                else FiveMinColors.surface.copy(alpha = 0.82f),
                            )
                            .clickable(
                                interactionSource = ignoreInteraction,
                                indication = null,
                                onClick = { vm.ignoreFinish() },
                            ),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = vm.t("finishIgnore"),
                            color = FiveMinColors.danger,
                            fontWeight = FontWeight.Medium,
                            fontSize = 15.sp,
                        )
                    }
                }

                // scene trigger — 与操作按钮统一大圆角
                val sceneRadius = RoundedCornerShape(FiveMinDimens.radius)
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(FiveMinDimens.rowH)
                        .shadow(elevation = 2.dp, shape = sceneRadius, clip = false)
                        .clip(sceneRadius)
                        .border(
                            1.dp,
                            if (sceneOpen) FiveMinColors.brand.copy(alpha = 0.45f) else FiveMinColors.line,
                            sceneRadius,
                        )
                        .background(FiveMinColors.surface)
                        .then(
                            if (setupEnabled) {
                                Modifier.clickable {
                                    vm.refreshSuggested()
                                    sceneOpen = true
                                }
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

                val chipIds = vm.chipSceneIds()
                if (chipIds.isNotEmpty()) {
                    val chipRadius = RoundedCornerShape(FiveMinDimens.radius)
                    val railShape = RoundedCornerShape(FiveMinDimens.radius)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(railShape)
                            .background(FiveMinColors.brandSoft.copy(alpha = 0.72f))
                            .border(1.dp, FiveMinColors.brand.copy(alpha = 0.12f), railShape)
                            .padding(6.dp)
                            .horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        chipIds.forEach { id ->
                            val active = id == state.activeSceneId
                            Text(
                                text = vm.sceneTitle(id) ?: id,
                                modifier = Modifier
                                    .height(FiveMinDimens.suggestedChipH)
                                    .then(
                                        if (active) {
                                            Modifier
                                                .shadow(
                                                    elevation = 4.dp,
                                                    shape = chipRadius,
                                                    ambientColor = FiveMinColors.brand.copy(alpha = 0.28f),
                                                    spotColor = FiveMinColors.brand.copy(alpha = 0.3f),
                                                )
                                                .clip(chipRadius)
                                                .background(
                                                    Brush.verticalGradient(
                                                        listOf(FiveMinColors.brandLift, FiveMinColors.brand),
                                                    ),
                                                )
                                        } else {
                                            Modifier
                                                .clip(chipRadius)
                                                .border(
                                                    1.dp,
                                                    FiveMinColors.brand.copy(alpha = 0.18f),
                                                    chipRadius,
                                                )
                                                .background(FiveMinColors.surface.copy(alpha = 0.55f))
                                        },
                                    )
                                    .then(
                                        if (setupEnabled) {
                                            Modifier.clickable { vm.selectScene(id) }
                                        } else Modifier,
                                    )
                                    .padding(horizontal = 14.dp)
                                    .wrapContentHeight(Alignment.CenterVertically),
                                color = when {
                                    !setupEnabled -> FiveMinColors.muted.copy(alpha = 0.4f)
                                    active -> Color.White
                                    else -> FiveMinColors.brandStrong
                                },
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 13.sp,
                                maxLines = 1,
                            )
                        }
                    }
                }
            }
        }
    }

    if (sceneOpen) {
        AlertDialog(
            onDismissRequest = { sceneOpen = false },
            confirmButton = {
                TextButton(onClick = { sceneOpen = false }) {
                    Text(vm.t("confirmLabel"), color = FiveMinColors.brandStrong, fontWeight = FontWeight.SemiBold)
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
                    vm.pickerGroups().forEach { group ->
                        val itemsInGroup = vm.scenesInGroup(group.id)
                        if (itemsInGroup.isEmpty()) return@forEach
                        item(key = "hdr:${group.id}") {
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
                        // 推荐分组与目录/自定义会复用同一 scene id，key 必须带 group 前缀
                        items(itemsInGroup, key = { "${group.id}:${it.id}" }) { scene ->
                            val active = scene.id == state.activeSceneId
                            Text(
                                text = vm.sceneLabel(scene.id) ?: scene.id,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(FiveMinDimens.rowH)
                                    .clip(RoundedCornerShape(FiveMinDimens.radiusSm))
                                    .background(if (active) FiveMinColors.brandSoft else Color.Transparent)
                                    .clickable {
                                        vm.selectScene(scene.id)
                                        sceneOpen = false
                                    }
                                    .padding(horizontal = 12.dp)
                                    .wrapContentHeight(Alignment.CenterVertically),
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

    if (state.showStandRitual) {
        AlertDialog(
            onDismissRequest = { vm.dismissStandRitual() },
            dismissButton = {
                TextButton(onClick = { vm.dismissStandRitual() }) {
                    Text(vm.t("standRitualSkip"), color = FiveMinColors.muted)
                }
            },
            confirmButton = {
                TextButton(onClick = { vm.dismissStandRitual() }) {
                    Text(vm.t("standRitualDone"), color = FiveMinColors.brandStrong, fontWeight = FontWeight.SemiBold)
                }
            },
            containerColor = FiveMinColors.surface,
            shape = RoundedCornerShape(FiveMinDimens.radiusDialog),
            title = {
                Text(
                    vm.t("standRitualTitle"),
                    color = FiveMinColors.ink,
                    fontWeight = FontWeight.SemiBold,
                )
            },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    RitualCheckRow(
                        label = vm.t("standRitualStepUp"),
                        checked = ritualUp,
                        onCheckedChange = { ritualUp = it },
                    )
                    RitualCheckRow(
                        label = vm.t("standRitualStepStretch"),
                        checked = ritualStretch,
                        onCheckedChange = { ritualStretch = it },
                    )
                    RitualCheckRow(
                        label = vm.t("standRitualStepLeave"),
                        checked = ritualLeave,
                        onCheckedChange = { ritualLeave = it },
                    )
                }
            },
        )
    }
}

@Composable
private fun RitualCheckRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCheckedChange(!checked) }
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Checkbox(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = CheckboxDefaults.colors(
                checkedColor = FiveMinColors.brand,
                uncheckedColor = FiveMinColors.muted,
            ),
        )
        Text(
            text = label,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f),
        )
    }
}

/** 统计行分隔点：实心圆，品牌色更醒目 */
@Composable
private fun StatsSepDot() {
    Box(
        modifier = Modifier
            .size(4.5.dp)
            .clip(RoundedCornerShape(50))
            .background(FiveMinColors.brandStrong),
    )
}

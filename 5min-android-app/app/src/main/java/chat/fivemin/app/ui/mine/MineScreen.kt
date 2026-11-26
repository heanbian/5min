package chat.fivemin.app.ui.mine

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import chat.fivemin.app.ui.MaterialAlert
import chat.fivemin.app.ui.MaterialFilledWideButton
import chat.fivemin.app.ui.MaterialFormSheet
import chat.fivemin.app.ui.MaterialPickRow
import chat.fivemin.app.ui.MaterialPickSheet
import chat.fivemin.app.ui.MaterialTextAction
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.data.AndroidLatest
import chat.fivemin.app.data.AppUpdate
import chat.fivemin.app.data.CustomScene
import chat.fivemin.app.data.P0Features
import chat.fivemin.app.data.UpdateCheckResult
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class MineDialog {
    None, Lang, Sound, CustomScenes, SceneEditor, Feedback, Beian, Storage, StandRitual, AlertProfile, UpdateAvailable,
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MineScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val catalog = FiveMinApp.instance.catalog
    val scope = rememberCoroutineScope()
    var dialog by remember { mutableStateOf(MineDialog.None) }
    var confirmCloud by remember { mutableStateOf(false) }
    var editingSceneId by remember { mutableStateOf<String?>(null) }
    var editorName by remember { mutableStateOf("") }
    var editorMinutes by remember { mutableStateOf(state.customMin.toString()) }
    var checkingUpdate by remember { mutableStateOf(false) }
    var pendingUpdate by remember { mutableStateOf<AndroidLatest?>(null) }
    var backupRevealed by remember { mutableStateOf(false) }
    var restoreRevealed by remember { mutableStateOf(false) }
    var restoreCode by remember { mutableStateOf("") }
    var promptRecoveryOnce by remember { mutableStateOf(false) }
    var overtimeInsight by remember {
        mutableStateOf(FiveMinApp.instance.prefs.p0.showOvertimeInsight)
    }
    val appVersion = remember(context) { AppUpdate.localVersionName(context) }
    val soundIds = listOf("off", "rain", "waves", "clock")
    val quickMins = listOf(3, 5, 10, 15, 25)
    val recoveryCode = remember(state.storageMode, state.storageSyncStatus) {
        if (state.storageMode == "cloud") vm.recoveryCode() else ""
    }

    fun openUrl(url: String) {
        AppUpdate.openUrl(context, url)
    }

    fun checkSoftwareUpdate() {
        if (checkingUpdate) return
        checkingUpdate = true
        Toast.makeText(context, vm.t("softwareUpdateChecking"), Toast.LENGTH_SHORT).show()
        scope.launch {
            val result = withContext(Dispatchers.IO) { AppUpdate.check(context) }
            checkingUpdate = false
            when (result) {
                is UpdateCheckResult.Latest -> {
                    Toast.makeText(context, vm.t("softwareUpdateLatest"), Toast.LENGTH_SHORT).show()
                }
                is UpdateCheckResult.Available -> {
                    pendingUpdate = result.latest
                    dialog = MineDialog.UpdateAvailable
                }
                is UpdateCheckResult.Failed -> {
                    Toast.makeText(context, vm.t("softwareUpdateFailed"), Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    fun ambientLabel(id: String): String = when (id) {
        "rain" -> vm.t("ambientRain")
        "waves" -> vm.t("ambientWaves")
        "clock" -> vm.t("ambientClock")
        else -> vm.t("ambientOff")
    }

    fun ritualLabel(mode: String): String =
        if (mode == P0Features.RITUAL_BASIC) vm.t("standRitualBasic") else vm.t("standRitualOff")

    fun alertProfileLabel(mode: String): String = when (mode) {
        P0Features.PROFILE_QUIET -> vm.t("alertProfileQuiet")
        P0Features.PROFILE_SILENT -> vm.t("alertProfileSilent")
        else -> vm.t("alertProfileNormal")
    }

    fun customScenesValue(): String {
        val n = state.customScenes.size
        if (n <= 0) return vm.t("customScenesEmpty")
        return vm.t("customScenesCount", mapOf("n" to "$n"))
    }

    fun openSceneEditor(scene: CustomScene?) {
        if (scene == null) {
            editingSceneId = null
            editorName = ""
            editorMinutes = state.customMin.toString()
        } else {
            editingSceneId = scene.id
            editorName = scene.name
            editorMinutes = scene.min.toString()
        }
        dialog = MineDialog.SceneEditor
    }

    fun nudgeEditor(delta: Int) {
        val cur = editorMinutes.toIntOrNull() ?: state.customMin
        editorMinutes = CustomScene.clampMinutes(cur + delta).toString()
    }

    fun saveSceneEditor() {
        val minutes = CustomScene.clampMinutes(editorMinutes.toIntOrNull() ?: state.customMin)
        if (vm.upsertCustomScene(editingSceneId, editorName, minutes) == null) return
        dialog = MineDialog.CustomScenes
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(FiveMinColors.bg, FiveMinColors.bg2, FiveMinColors.bgBottom),
                ),
            ),
    ) {
        TopAppBar(
            title = {
                Text(
                    text = vm.t("tabMine"),
                    color = FiveMinColors.ink,
                    fontWeight = FontWeight.SemiBold,
                )
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = FiveMinColors.surface.copy(alpha = 0.92f),
                titleContentColor = FiveMinColors.ink,
            ),
            modifier = Modifier.statusBarsPadding(),
        )
        HorizontalDivider(color = FiveMinColors.line.copy(alpha = 0.85f))

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(FiveMinDimens.padBody),
            verticalArrangement = Arrangement.spacedBy(FiveMinDimens.listSectionGap),
        ) {
            SectionTitle(vm.t("mineSectionPrefs"))
            CardBlock {
                PrefRow(vm.t("langLabel"), catalog.t(state.locale, "nativeName")) {
                    dialog = MineDialog.Lang
                }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefRow(vm.t("ambientLabel"), ambientLabel(state.ambient)) {
                    dialog = MineDialog.Sound
                }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefRow(vm.t("customScenesLabel"), customScenesValue()) {
                    dialog = MineDialog.CustomScenes
                }
            }

            SectionTitle(vm.t("prefAlertsSection"))
            CardBlock {
                PrefSwitchRow(
                    title = vm.t("prefFinishTone"),
                    checked = state.finishTone,
                    onCheckedChange = { vm.setFinishTone(it) },
                )
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefSwitchRow(
                    title = vm.t("prefFinishVibrate"),
                    checked = state.finishVibrate,
                    onCheckedChange = { vm.setFinishVibrate(it) },
                )
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefSwitchRow(
                    title = vm.t("prefFinishNotify"),
                    checked = state.finishNotify,
                    onCheckedChange = { vm.setFinishNotify(it) },
                )
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefSwitchRow(
                    title = vm.t("prefOvertimeInsight"),
                    checked = overtimeInsight,
                    onCheckedChange = {
                        overtimeInsight = it
                        vm.setShowOvertimeInsight(it)
                    },
                )
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefRow(vm.t("alertProfileLabel"), alertProfileLabel(state.alertProfile)) {
                    dialog = MineDialog.AlertProfile
                }
            }
            Text(
                text = vm.t("alertProfileHint"),
                color = FiveMinColors.muted,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 4.dp),
            )

            SectionTitle(vm.t("standRitualSection"))
            CardBlock {
                PrefRow(vm.t("standRitualLabel"), ritualLabel(state.standRitual)) {
                    dialog = MineDialog.StandRitual
                }
            }

            SectionTitle(vm.t("storageSection"))
            CardBlock {
                PrefRow(
                    vm.t("storageModeLabel"),
                    if (state.storageMode == "cloud") vm.t("storageModeCloud") else vm.t("storageModeLocal"),
                ) {
                    dialog = MineDialog.Storage
                }
            }
            Text(
                text = vm.t("storageModeHint"),
                color = FiveMinColors.muted,
                fontSize = 12.sp,
                modifier = Modifier.padding(horizontal = 4.dp),
            )
            if (state.storageSyncStatus.isNotBlank()) {
                Text(
                    text = state.storageSyncStatus,
                    color = FiveMinColors.muted,
                    fontSize = 12.sp,
                    modifier = Modifier.padding(horizontal = 4.dp),
                )
            }
            if (state.storageMode == "cloud" && recoveryCode.isNotBlank()) {
                CardBlock {
                    ListItem(
                        onClick = { backupRevealed = !backupRevealed },
                        modifier = Modifier.fillMaxWidth(),
                        trailingContent = {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                contentDescription = null,
                                tint = FiveMinColors.muted,
                                modifier = Modifier.graphicsLayer {
                                    rotationZ = if (backupRevealed) 90f else 0f
                                },
                            )
                        },
                        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                    ) {
                        Text(
                            text = vm.t("storageBackupShow"),
                            color = FiveMinColors.ink,
                            fontSize = 15.sp,
                        )
                    }
                    if (backupRevealed) {
                        HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Text(
                                text = recoveryCode,
                                color = FiveMinColors.ink,
                                fontSize = 12.sp,
                                fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
                                lineHeight = 18.sp,
                            )
                            Text(
                                text = vm.t("storageBackupHint"),
                                color = FiveMinColors.muted,
                                fontSize = 12.sp,
                                lineHeight = 18.sp,
                            )
                            MaterialFilledWideButton(
                                text = vm.t("storageBackupCopy"),
                                onClick = {
                                    val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                    cm.setPrimaryClip(ClipData.newPlainText("recovery", recoveryCode))
                                    Toast.makeText(
                                        context,
                                        vm.t("storageBackupCopied"),
                                        Toast.LENGTH_SHORT,
                                    ).show()
                                },
                            )
                        }
                    }
                }
            }
            CardBlock {
                ListItem(
                    onClick = { restoreRevealed = !restoreRevealed },
                    modifier = Modifier.fillMaxWidth(),
                    trailingContent = {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = FiveMinColors.muted,
                            modifier = Modifier.graphicsLayer {
                                rotationZ = if (restoreRevealed) 90f else 0f
                            },
                        )
                    },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                ) {
                    Text(
                        text = vm.t("storageRestoreLabel"),
                        color = FiveMinColors.ink,
                        fontSize = 15.sp,
                    )
                }
                if (restoreRevealed) {
                    HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        OutlinedTextField(
                            value = restoreCode,
                            onValueChange = { restoreCode = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text(vm.t("storageRestorePlaceholder")) },
                            singleLine = true,
                            textStyle = TextStyle(fontSize = 13.sp),
                            shape = RoundedCornerShape(FiveMinDimens.radiusSm),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = FiveMinColors.brand,
                                unfocusedBorderColor = FiveMinColors.line,
                                cursorColor = FiveMinColors.brand,
                                focusedLabelColor = FiveMinColors.brandStrong,
                            ),
                        )
                        Text(
                            text = vm.t("storageRestoreHint"),
                            color = FiveMinColors.muted,
                            fontSize = 12.sp,
                            lineHeight = 18.sp,
                        )
                        MaterialFilledWideButton(
                            text = vm.t("storageRestoreAction"),
                            onClick = {
                                vm.restoreWithCode(restoreCode) { ok, _ ->
                                    if (ok) {
                                        restoreCode = ""
                                        backupRevealed = false
                                        restoreRevealed = false
                                    }
                                }
                            },
                        )
                    }
                }
            }

            SectionTitle(vm.t("mineSectionSupport"))
            CardBlock {
                LinkRow(vm.t("privacyLink")) { openUrl("https://5min.chat/privacy.html") }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                LinkRow(vm.t("termsLink")) { openUrl("https://5min.chat/terms.html") }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                LinkRow(vm.t("aboutLabel")) { openUrl("https://5min.chat/about.html") }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                LinkRow(vm.t("feedbackLabel")) { dialog = MineDialog.Feedback }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                LinkRow(vm.t("beianEntry")) { dialog = MineDialog.Beian }
                HorizontalDivider(color = FiveMinColors.line, modifier = Modifier.padding(start = 16.dp))
                PrefRow(
                    title = vm.t("softwareUpdateLabel"),
                    value = if (checkingUpdate) "…" else appVersion,
                    onClick = { checkSoftwareUpdate() },
                )
            }
        }
    }

    when (dialog) {
        MineDialog.Lang -> MaterialPickSheet(
            title = vm.t("langLabel"),
            onDismiss = { dialog = MineDialog.None },
        ) {
            vm.appLocaleCodes().forEach { code ->
                MaterialPickRow(
                    label = catalog.t(code, "nativeName"),
                    selected = code == state.locale,
                    onClick = {
                        vm.setLocale(code)
                        dialog = MineDialog.None
                    },
                )
            }
        }
        MineDialog.Sound -> MaterialPickSheet(
            title = vm.t("ambientLabel"),
            onDismiss = { dialog = MineDialog.None },
        ) {
            soundIds.forEach { id ->
                MaterialPickRow(
                    label = ambientLabel(id),
                    selected = id == state.ambient,
                    onClick = {
                        vm.setAmbient(id)
                        dialog = MineDialog.None
                    },
                )
            }
        }
        MineDialog.Storage -> MaterialPickSheet(
            title = vm.t("storageModeLabel"),
            onDismiss = { dialog = MineDialog.None },
        ) {
            listOf("local" to vm.t("storageModeLocal"), "cloud" to vm.t("storageModeCloud")).forEach { (id, label) ->
                MaterialPickRow(
                    label = label,
                    selected = id == state.storageMode,
                    onClick = {
                        if (id == "local") {
                            vm.setStorageMode("local")
                            dialog = MineDialog.None
                        } else {
                            dialog = MineDialog.None
                            confirmCloud = true
                        }
                    },
                )
            }
        }
        MineDialog.StandRitual -> MaterialPickSheet(
            title = vm.t("standRitualLabel"),
            onDismiss = { dialog = MineDialog.None },
        ) {
            listOf(
                P0Features.RITUAL_OFF to vm.t("standRitualOff"),
                P0Features.RITUAL_BASIC to vm.t("standRitualBasic"),
            ).forEach { (id, label) ->
                MaterialPickRow(
                    label = label,
                    selected = id == state.standRitual,
                    onClick = {
                        vm.setStandRitual(id)
                        dialog = MineDialog.None
                    },
                )
            }
        }
        MineDialog.AlertProfile -> MaterialPickSheet(
            title = vm.t("alertProfileLabel"),
            onDismiss = { dialog = MineDialog.None },
        ) {
            listOf(
                P0Features.PROFILE_NORMAL to vm.t("alertProfileNormal"),
                P0Features.PROFILE_QUIET to vm.t("alertProfileQuiet"),
                P0Features.PROFILE_SILENT to vm.t("alertProfileSilent"),
            ).forEach { (id, label) ->
                MaterialPickRow(
                    label = label,
                    selected = id == state.alertProfile,
                    onClick = {
                        vm.setAlertProfile(id)
                        dialog = MineDialog.None
                    },
                )
            }
        }
        else -> Unit
    }

    if (confirmCloud) {
        MaterialAlert(
            onDismissRequest = { confirmCloud = false },
            title = vm.t("storageModeCloud"),
            text = vm.t("storageCloudConfirm"),
            confirmLabel = vm.t("confirmLabel"),
            onConfirm = {
                confirmCloud = false
                promptRecoveryOnce = true
                vm.setStorageMode("cloud")
            },
            dismissLabel = vm.t("cancelLabel"),
            onDismiss = { confirmCloud = false },
        )
    }

    LaunchedEffect(state.storageMode, state.storageSyncStatus, promptRecoveryOnce) {
        if (!promptRecoveryOnce) return@LaunchedEffect
        if (state.storageMode != "cloud") return@LaunchedEffect
        if (state.storageSyncStatus != vm.t("storageSyncOk")) return@LaunchedEffect
        promptRecoveryOnce = false
        if (vm.recoveryCode().isNotBlank()) {
            backupRevealed = true
            Toast.makeText(context, vm.t("storageBackupHint"), Toast.LENGTH_LONG).show()
        }
    }

    when (dialog) {
        MineDialog.None, MineDialog.Lang, MineDialog.Sound, MineDialog.Storage,
        MineDialog.StandRitual, MineDialog.AlertProfile,
        -> Unit
        MineDialog.CustomScenes -> {
            val canAdd = state.customScenes.size < CustomScene.MAX_COUNT
            MaterialFormSheet(
                title = vm.t("customScenesLabel"),
                onDismiss = { dialog = MineDialog.None },
            ) {
                if (state.customScenes.isEmpty()) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Text(
                            text = vm.t("customScenesEmptyHint"),
                            color = FiveMinColors.muted,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center,
                            lineHeight = 20.sp,
                        )
                        FilledTonalButton(
                            onClick = { openSceneEditor(null) },
                            enabled = canAdd,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(vm.t("customSceneAdd"), fontWeight = FontWeight.SemiBold)
                        }
                    }
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                    ) {
                        MaterialTextAction(
                            text = vm.t("customSceneAdd"),
                            onClick = { openSceneEditor(null) },
                            emphatic = true,
                            enabled = canAdd,
                        )
                    }
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(max = 360.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        items(state.customScenes, key = { it.id }) { scene ->
                            ListItem(
                                onClick = { openSceneEditor(scene) },
                                modifier = Modifier.fillMaxWidth(),
                                supportingContent = {
                                    Text(
                                        text = "${scene.min} ${vm.t("customUnit")}",
                                        color = FiveMinColors.muted,
                                        fontSize = 13.sp,
                                    )
                                },
                                trailingContent = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        MaterialTextAction(
                                            text = vm.t("customSceneUse"),
                                            onClick = {
                                                vm.queueCustomScene(scene.id)
                                                dialog = MineDialog.None
                                                vm.setSelectedTab(1)
                                            },
                                            emphatic = true,
                                        )
                                        IconButton(onClick = { vm.deleteCustomScene(scene.id) }) {
                                            Icon(
                                                imageVector = Icons.Default.Delete,
                                                contentDescription = vm.t("historyDelete"),
                                                tint = FiveMinColors.muted,
                                            )
                                        }
                                    }
                                },
                                colors = ListItemDefaults.colors(containerColor = Color.Transparent),
                            ) {
                                Text(
                                    text = scene.name,
                                    color = FiveMinColors.ink,
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Medium,
                                )
                            }
                            HorizontalDivider(color = FiveMinColors.line.copy(alpha = 0.7f))
                        }
                    }
                }
            }
        }
        MineDialog.SceneEditor -> {
            val canSave = CustomScene.normalizedName(editorName).isNotEmpty()
            MaterialFormSheet(
                title = if (editingSceneId == null) vm.t("customSceneAdd") else vm.t("customSceneEdit"),
                onDismiss = { dialog = MineDialog.CustomScenes },
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(FiveMinDimens.sectionGap)) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = vm.t("customSceneNameLabel"),
                            color = FiveMinColors.muted,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        OutlinedTextField(
                            value = editorName,
                            onValueChange = {
                                editorName = it.take(CustomScene.MAX_NAME_LENGTH)
                            },
                            placeholder = { Text(vm.t("customSceneNamePlaceholder")) },
                            singleLine = true,
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(FiveMinDimens.fieldH),
                            shape = RoundedCornerShape(FiveMinDimens.radiusSm),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = FiveMinColors.brand,
                                unfocusedBorderColor = FiveMinColors.line,
                                cursorColor = FiveMinColors.brand,
                            ),
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = vm.t("customMinutesLabel"),
                            color = FiveMinColors.muted,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(FiveMinDimens.controlGap),
                        ) {
                            FilledTonalIconButton(onClick = { nudgeEditor(-1) }) {
                                Icon(Icons.Default.Remove, contentDescription = null)
                            }
                            OutlinedTextField(
                                value = editorMinutes,
                                onValueChange = {
                                    editorMinutes = it.filter { ch -> ch.isDigit() }.take(3)
                                },
                                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                singleLine = true,
                                modifier = Modifier
                                    .weight(1f)
                                    .height(FiveMinDimens.fieldH),
                                shape = RoundedCornerShape(FiveMinDimens.radiusSm),
                                textStyle = TextStyle(
                                    fontSize = 22.sp,
                                    fontWeight = FontWeight.Medium,
                                    textAlign = TextAlign.Center,
                                ),
                                colors = OutlinedTextFieldDefaults.colors(
                                    focusedBorderColor = FiveMinColors.brand,
                                    unfocusedBorderColor = FiveMinColors.line,
                                    cursorColor = FiveMinColors.brand,
                                ),
                            )
                            FilledTonalIconButton(onClick = { nudgeEditor(1) }) {
                                Icon(Icons.Default.Add, contentDescription = null)
                            }
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        quickMins.forEach { m ->
                            AssistChip(
                                onClick = { editorMinutes = m.toString() },
                                label = {
                                    Text(
                                        text = "$m",
                                        fontWeight = FontWeight.SemiBold,
                                        color = FiveMinColors.brandStrong,
                                    )
                                },
                                shape = RoundedCornerShape(FiveMinDimens.radiusSm),
                                colors = AssistChipDefaults.assistChipColors(
                                    containerColor = FiveMinColors.brandSoft,
                                ),
                                border = AssistChipDefaults.assistChipBorder(
                                    enabled = true,
                                    borderColor = FiveMinColors.brand.copy(alpha = 0.18f),
                                ),
                            )
                        }
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                    ) {
                        MaterialTextAction(
                            text = vm.t("cancelLabel"),
                            onClick = { dialog = MineDialog.CustomScenes },
                        )
                        MaterialTextAction(
                            text = vm.t("confirmLabel"),
                            onClick = { saveSceneEditor() },
                            emphatic = true,
                            enabled = canSave,
                        )
                    }
                }
            }
        }
        MineDialog.Feedback -> {
            val email = vm.t("feedbackEmail")
            MaterialAlert(
                onDismissRequest = { dialog = MineDialog.None },
                title = vm.t("feedbackLabel"),
                text = "${vm.t("feedbackBody")}\n\n$email",
                confirmLabel = vm.t("copyEmailLabel"),
                onConfirm = {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val clip = ClipData.newPlainText("email", email)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                        clip.description?.extras = android.os.PersistableBundle().apply {
                            putBoolean(android.content.ClipDescription.EXTRA_IS_SENSITIVE, true)
                        }
                    }
                    clipboard.setPrimaryClip(clip)
                    dialog = MineDialog.None
                    Toast.makeText(context, vm.t("emailCopied"), Toast.LENGTH_SHORT).show()
                },
                dismissLabel = vm.t("cancelLabel"),
                onDismiss = { dialog = MineDialog.None },
            )
        }
        MineDialog.Beian -> MaterialAlert(
            onDismissRequest = { dialog = MineDialog.None },
            title = vm.t("beianTitle"),
            text = vm.t("beianIcp"),
            confirmLabel = vm.t("confirmLabel"),
            onConfirm = { dialog = MineDialog.None },
        )
        MineDialog.UpdateAvailable -> {
            val latest = pendingUpdate
            MaterialAlert(
                onDismissRequest = {
                    dialog = MineDialog.None
                    pendingUpdate = null
                },
                title = vm.t("softwareUpdateLabel"),
                text = vm.t(
                    "softwareUpdateAvailable",
                    mapOf("n" to (latest?.versionName ?: "")),
                ),
                confirmLabel = vm.t("softwareUpdateAction"),
                onConfirm = {
                    val url = latest?.apkUrl?.takeIf { it.isNotBlank() }
                        ?: latest?.pageUrl
                        ?: "https://5min.chat/download.html"
                    openUrl(url)
                    dialog = MineDialog.None
                    pendingUpdate = null
                },
                dismissLabel = vm.t("cancelLabel"),
                onDismiss = {
                    dialog = MineDialog.None
                    pendingUpdate = null
                },
            )
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        color = FiveMinColors.muted,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.padding(start = 4.dp),
    )
}

@Composable
private fun CardBlock(content: @Composable () -> Unit) {
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
        Column { content() }
    }
}

@Composable
private fun PrefRow(title: String, value: String, onClick: () -> Unit) {
    ListItem(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        trailingContent = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(
                    text = value,
                    color = FiveMinColors.muted,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.End,
                    modifier = Modifier.widthIn(max = 160.dp),
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = FiveMinColors.muted,
                )
            }
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun PrefSwitchRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    ListItem(
        modifier = Modifier.fillMaxWidth(),
        trailingContent = {
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
                colors = SwitchDefaults.colors(
                    checkedThumbColor = FiveMinColors.surface,
                    checkedTrackColor = FiveMinColors.brand,
                    uncheckedThumbColor = FiveMinColors.surface,
                    uncheckedTrackColor = FiveMinColors.line,
                    uncheckedBorderColor = FiveMinColors.line,
                ),
            )
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun LinkRow(title: String, onClick: () -> Unit) {
    ListItem(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        trailingContent = {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = FiveMinColors.muted,
            )
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

package chat.fivemin.app.ui.mine

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .background(FiveMinColors.surface.copy(alpha = 0.72f))
                .padding(horizontal = 20.dp, vertical = 14.dp),
        ) {
            Text(vm.t("tabMine"), color = FiveMinColors.ink, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
        }
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
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { backupRevealed = !backupRevealed }
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = vm.t("storageBackupShow"),
                            color = FiveMinColors.ink,
                            fontSize = 15.sp,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            text = "›",
                            color = FiveMinColors.muted,
                            fontSize = 18.sp,
                            modifier = Modifier.graphicsLayer {
                                rotationZ = if (backupRevealed) 90f else 0f
                            },
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
                            Text(
                                text = vm.t("storageBackupCopy"),
                                color = Color.White,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                textAlign = TextAlign.Center,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(FiveMinColors.brand)
                                    .clickable {
                                        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                        cm.setPrimaryClip(ClipData.newPlainText("recovery", recoveryCode))
                                        Toast.makeText(
                                            context,
                                            vm.t("storageBackupCopied"),
                                            Toast.LENGTH_SHORT,
                                        ).show()
                                    }
                                    .padding(vertical = 12.dp),
                            )
                        }
                    }
                }
            }
            CardBlock {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { restoreRevealed = !restoreRevealed }
                        .padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = vm.t("storageRestoreLabel"),
                        color = FiveMinColors.ink,
                        fontSize = 15.sp,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = "›",
                        color = FiveMinColors.muted,
                        fontSize = 18.sp,
                        modifier = Modifier.graphicsLayer {
                            rotationZ = if (restoreRevealed) 90f else 0f
                        },
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
                        )
                        Text(
                            text = vm.t("storageRestoreHint"),
                            color = FiveMinColors.muted,
                            fontSize = 12.sp,
                            lineHeight = 18.sp,
                        )
                        Text(
                            text = vm.t("storageRestoreAction"),
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            textAlign = TextAlign.Center,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(12.dp))
                                .background(FiveMinColors.brand)
                                .clickable {
                                    vm.restoreWithCode(restoreCode) { ok, _ ->
                                        if (ok) {
                                            restoreCode = ""
                                            backupRevealed = false
                                            restoreRevealed = false
                                        }
                                    }
                                }
                                .padding(vertical = 12.dp),
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
        MineDialog.Lang -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            confirmButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.brandStrong)
                }
            },
            title = { Text(vm.t("langLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Column {
                    vm.appLocaleCodes().forEach { code ->
                        Text(
                            text = catalog.t(code, "nativeName"),
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    vm.setLocale(code)
                                    dialog = MineDialog.None
                                }
                                .padding(vertical = 12.dp),
                            color = if (code == state.locale) FiveMinColors.brandStrong else FiveMinColors.ink,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            },
        )
        MineDialog.Sound -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            confirmButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.brandStrong)
                }
            },
            title = { Text(vm.t("ambientLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Column {
                    soundIds.forEach { id ->
                        Text(
                            text = ambientLabel(id),
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    vm.setAmbient(id)
                                    dialog = MineDialog.None
                                }
                                .padding(vertical = 12.dp),
                            color = if (id == state.ambient) FiveMinColors.brandStrong else FiveMinColors.ink,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            },
        )
        MineDialog.Storage -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            confirmButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.brandStrong)
                }
            },
            title = { Text(vm.t("storageModeLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Column {
                    listOf("local" to vm.t("storageModeLocal"), "cloud" to vm.t("storageModeCloud")).forEach { (id, label) ->
                        Text(
                            text = label,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    if (id == "local") {
                                        vm.setStorageMode("local")
                                        dialog = MineDialog.None
                                    } else {
                                        dialog = MineDialog.None
                                        confirmCloud = true
                                    }
                                }
                                .padding(vertical = 12.dp),
                            color = if (id == state.storageMode) FiveMinColors.brandStrong else FiveMinColors.ink,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            },
        )
        MineDialog.StandRitual -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            confirmButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.brandStrong)
                }
            },
            title = { Text(vm.t("standRitualLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Column {
                    listOf(
                        P0Features.RITUAL_OFF to vm.t("standRitualOff"),
                        P0Features.RITUAL_BASIC to vm.t("standRitualBasic"),
                    ).forEach { (id, label) ->
                        Text(
                            text = label,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    vm.setStandRitual(id)
                                    dialog = MineDialog.None
                                }
                                .padding(vertical = 12.dp),
                            color = if (id == state.standRitual) FiveMinColors.brandStrong else FiveMinColors.ink,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            },
        )
        MineDialog.AlertProfile -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            confirmButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.brandStrong)
                }
            },
            title = { Text(vm.t("alertProfileLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Column {
                    listOf(
                        P0Features.PROFILE_NORMAL to vm.t("alertProfileNormal"),
                        P0Features.PROFILE_QUIET to vm.t("alertProfileQuiet"),
                        P0Features.PROFILE_SILENT to vm.t("alertProfileSilent"),
                    ).forEach { (id, label) ->
                        Text(
                            text = label,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    vm.setAlertProfile(id)
                                    dialog = MineDialog.None
                                }
                                .padding(vertical = 12.dp),
                            color = if (id == state.alertProfile) FiveMinColors.brandStrong else FiveMinColors.ink,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            },
        )
        else -> Unit
    }

    if (confirmCloud) {
        AlertDialog(
            onDismissRequest = { confirmCloud = false },
            confirmButton = {
                TextButton(onClick = {
                    confirmCloud = false
                    promptRecoveryOnce = true
                    vm.setStorageMode("cloud")
                }) {
                    Text(vm.t("confirmLabel"), color = FiveMinColors.brandStrong)
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmCloud = false }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                }
            },
            title = { Text(vm.t("storageModeCloud"), fontWeight = FontWeight.SemiBold) },
            text = { Text(vm.t("storageCloudConfirm")) },
            containerColor = FiveMinColors.surface,
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

    // Keep dialog when-block closed: remaining cases continue below
    when (dialog) {
        MineDialog.None, MineDialog.Lang, MineDialog.Sound, MineDialog.Storage,
        MineDialog.StandRitual, MineDialog.AlertProfile,
        -> Unit
        MineDialog.CustomScenes -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            dismissButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                }
            },
            confirmButton = {
                TextButton(
                    onClick = { openSceneEditor(null) },
                    enabled = state.customScenes.size < CustomScene.MAX_COUNT,
                ) {
                    Text(
                        vm.t("customSceneAdd"),
                        color = if (state.customScenes.size < CustomScene.MAX_COUNT) {
                            FiveMinColors.brandStrong
                        } else {
                            FiveMinColors.muted
                        },
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            },
            title = { Text(vm.t("customScenesLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                if (state.customScenes.isEmpty()) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(
                            text = vm.t("customScenesEmptyHint"),
                            color = FiveMinColors.muted,
                            fontSize = 14.sp,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = vm.t("customSceneAdd"),
                            modifier = Modifier
                                .background(FiveMinColors.brand, RoundedCornerShape(12.dp))
                                .clickable { openSceneEditor(null) }
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                            color = FiveMinColors.surface,
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 14.sp,
                        )
                    }
                } else {
                    LazyColumn(modifier = Modifier.height(360.dp)) {
                        items(state.customScenes, key = { it.id }) { scene ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Column(
                                    modifier = Modifier
                                        .weight(1f)
                                        .clickable { openSceneEditor(scene) },
                                    verticalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    Text(
                                        text = scene.name,
                                        color = FiveMinColors.ink,
                                        fontSize = 15.sp,
                                        fontWeight = FontWeight.Medium,
                                    )
                                    Text(
                                        text = "${scene.min} ${vm.t("customUnit")}",
                                        color = FiveMinColors.muted,
                                        fontSize = 13.sp,
                                    )
                                }
                                Text(
                                    text = vm.t("customSceneUse"),
                                    modifier = Modifier
                                        .background(FiveMinColors.brandSoft, RoundedCornerShape(8.dp))
                                        .clickable {
                                            vm.queueCustomScene(scene.id)
                                            dialog = MineDialog.None
                                            vm.setSelectedTab(1)
                                        }
                                        .padding(horizontal = 10.dp, vertical = 6.dp),
                                    color = FiveMinColors.brandStrong,
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 13.sp,
                                )
                                Icon(
                                    imageVector = Icons.Default.Delete,
                                    contentDescription = vm.t("historyDelete"),
                                    tint = FiveMinColors.muted,
                                    modifier = Modifier
                                        .size(22.dp)
                                        .clickable { vm.deleteCustomScene(scene.id) },
                                )
                            }
                        }
                    }
                }
            },
        )
        MineDialog.SceneEditor -> {
            val canSave = CustomScene.normalizedName(editorName).isNotEmpty()
            AlertDialog(
                onDismissRequest = { dialog = MineDialog.CustomScenes },
                dismissButton = {
                    TextButton(onClick = { dialog = MineDialog.CustomScenes }) {
                        Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                    }
                },
                confirmButton = {
                    TextButton(
                        onClick = { saveSceneEditor() },
                        enabled = canSave,
                    ) {
                        Text(
                            vm.t("confirmLabel"),
                            color = if (canSave) FiveMinColors.brandStrong else FiveMinColors.muted,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                },
                title = {
                    Text(
                        if (editingSceneId == null) vm.t("customSceneAdd") else vm.t("customSceneEdit"),
                        fontWeight = FontWeight.SemiBold,
                    )
                },
                containerColor = FiveMinColors.surface,
                text = {
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
                                shape = RoundedCornerShape(FiveMinDimens.radius),
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
                                Text(
                                    text = "−",
                                    modifier = Modifier
                                        .size(FiveMinDimens.controlH)
                                        .clip(RoundedCornerShape(FiveMinDimens.radius))
                                        .background(FiveMinColors.ghostBg)
                                        .border(1.dp, FiveMinColors.line, RoundedCornerShape(FiveMinDimens.radius))
                                        .clickable { nudgeEditor(-1) }
                                        .wrapContentHeight(Alignment.CenterVertically),
                                    color = FiveMinColors.ink,
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 18.sp,
                                    textAlign = TextAlign.Center,
                                )
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
                                    shape = RoundedCornerShape(FiveMinDimens.radius),
                                    textStyle = TextStyle(
                                        fontSize = 24.sp,
                                        fontWeight = FontWeight.Medium,
                                        textAlign = TextAlign.Center,
                                    ),
                                )
                                Text(
                                    text = "+",
                                    modifier = Modifier
                                        .size(FiveMinDimens.controlH)
                                        .clip(RoundedCornerShape(FiveMinDimens.radius))
                                        .background(FiveMinColors.ghostBg)
                                        .border(1.dp, FiveMinColors.line, RoundedCornerShape(FiveMinDimens.radius))
                                        .clickable { nudgeEditor(1) }
                                        .wrapContentHeight(Alignment.CenterVertically),
                                    color = FiveMinColors.ink,
                                    fontWeight = FontWeight.SemiBold,
                                    fontSize = 18.sp,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            quickMins.forEach { m ->
                                Text(
                                    text = "$m",
                                    modifier = Modifier
                                        .height(FiveMinDimens.chipH)
                                        .background(FiveMinColors.brandSoft, RoundedCornerShape(FiveMinDimens.radiusSm))
                                        .clickable { editorMinutes = m.toString() }
                                        .padding(horizontal = 12.dp)
                                        .wrapContentHeight(Alignment.CenterVertically),
                                    color = FiveMinColors.brandStrong,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        }
                    }
                },
            )
        }
        MineDialog.Feedback -> {
            val email = vm.t("feedbackEmail")
            AlertDialog(
                onDismissRequest = { dialog = MineDialog.None },
                confirmButton = {
                    TextButton(onClick = {
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
                    }) {
                        Text(vm.t("copyEmailLabel"), color = FiveMinColors.brandStrong, fontWeight = FontWeight.SemiBold)
                    }
                },
                title = { Text(vm.t("feedbackLabel"), fontWeight = FontWeight.SemiBold) },
                containerColor = FiveMinColors.surface,
                text = {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = vm.t("feedbackBody"),
                            color = FiveMinColors.ink,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            text = email,
                            color = FiveMinColors.ink,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            textAlign = TextAlign.Center,
                        )
                    }
                },
            )
        }
        MineDialog.Beian -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            confirmButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("confirmLabel"), color = FiveMinColors.brandStrong, fontWeight = FontWeight.SemiBold)
                }
            },
            title = { Text(vm.t("beianTitle"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Text(
                    text = vm.t("beianIcp"),
                    color = FiveMinColors.ink,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
        )
        MineDialog.UpdateAvailable -> {
            val latest = pendingUpdate
            AlertDialog(
                onDismissRequest = {
                    dialog = MineDialog.None
                    pendingUpdate = null
                },
                confirmButton = {
                    TextButton(
                        onClick = {
                            val url = latest?.apkUrl?.takeIf { it.isNotBlank() }
                                ?: latest?.pageUrl
                                ?: "https://5min.chat/download.html"
                            openUrl(url)
                            dialog = MineDialog.None
                            pendingUpdate = null
                        },
                    ) {
                        Text(
                            vm.t("softwareUpdateAction"),
                            color = FiveMinColors.brandStrong,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                },
                dismissButton = {
                    TextButton(
                        onClick = {
                            dialog = MineDialog.None
                            pendingUpdate = null
                        },
                    ) {
                        Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                    }
                },
                title = { Text(vm.t("softwareUpdateLabel"), fontWeight = FontWeight.SemiBold) },
                containerColor = FiveMinColors.surface,
                text = {
                    Text(
                        text = vm.t(
                            "softwareUpdateAvailable",
                            mapOf("n" to (latest?.versionName ?: "")),
                        ),
                        color = FiveMinColors.ink,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                },
            )
        }
        MineDialog.None -> Unit
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
    ) { content() }
}

@Composable
private fun PrefRow(title: String, value: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(FiveMinDimens.controlH)
            .clickable(onClick = onClick)
            .padding(horizontal = FiveMinDimens.padBody),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .wrapContentHeight(Alignment.CenterVertically),
        )
        Text(
            text = value,
            color = FiveMinColors.muted,
            fontSize = 14.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.End,
            modifier = Modifier
                .padding(start = 8.dp, end = 6.dp)
                .widthIn(max = 160.dp)
                .wrapContentHeight(Alignment.CenterVertically),
        )
        Text(
            text = "›",
            color = FiveMinColors.muted,
            fontSize = 18.sp,
            modifier = Modifier.wrapContentHeight(Alignment.CenterVertically),
        )
    }
}

@Composable
private fun PrefSwitchRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(FiveMinDimens.controlH)
            .padding(horizontal = FiveMinDimens.padBody),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .wrapContentHeight(Alignment.CenterVertically),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            modifier = Modifier.wrapContentHeight(Alignment.CenterVertically),
            colors = SwitchDefaults.colors(
                checkedThumbColor = FiveMinColors.surface,
                checkedTrackColor = FiveMinColors.brand,
                uncheckedThumbColor = FiveMinColors.surface,
                uncheckedTrackColor = FiveMinColors.line,
            ),
        )
    }
}

@Composable
private fun LinkRow(title: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(FiveMinDimens.controlH)
            .clickable(onClick = onClick)
            .padding(horizontal = FiveMinDimens.padBody),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = title,
            color = FiveMinColors.ink,
            fontSize = 15.sp,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .weight(1f)
                .wrapContentHeight(Alignment.CenterVertically),
        )
        Text(
            text = "›",
            color = FiveMinColors.muted,
            fontSize = 18.sp,
            modifier = Modifier.wrapContentHeight(Alignment.CenterVertically),
        )
    }
}

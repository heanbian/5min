package chat.fivemin.app.ui.mine

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.data.CustomScene
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

private enum class MineDialog { None, Lang, Sound, CustomScenes, SceneEditor, Feedback, Beian }

@Composable
fun MineScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsState()
    val context = LocalContext.current
    val catalog = FiveMinApp.instance.catalog
    var dialog by remember { mutableStateOf(MineDialog.None) }
    var editingSceneId by remember { mutableStateOf<String?>(null) }
    var editorName by remember { mutableStateOf("") }
    var editorMinutes by remember { mutableStateOf(state.customMin.toString()) }
    val soundIds = listOf("off", "rain", "waves", "clock")
    val quickMins = listOf(3, 5, 10, 15, 25)

    fun openUrl(url: String) {
        if (!url.startsWith("https://", ignoreCase = true)) return
        runCatching {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        }
    }

    fun ambientLabel(id: String): String = when (id) {
        "rain" -> vm.t("ambientRain")
        "waves" -> vm.t("ambientWaves")
        "clock" -> vm.t("ambientClock")
        else -> vm.t("ambientOff")
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
            .background(FiveMinColors.bg2),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .statusBarsPadding()
                .background(FiveMinColors.surface)
                .padding(horizontal = 20.dp, vertical = 14.dp),
        ) {
            Text(vm.t("tabMine"), color = FiveMinColors.ink, fontSize = 20.sp, fontWeight = FontWeight.Medium)
        }
        HorizontalDivider(color = FiveMinColors.line)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
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
                                    contentDescription = null,
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
                        clipboard.setPrimaryClip(ClipData.newPlainText("email", email))
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
            .background(FiveMinColors.surface, RoundedCornerShape(14.dp)),
    ) { content() }
}

@Composable
private fun PrefRow(title: String, value: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = FiveMinColors.ink, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Text(value, color = FiveMinColors.muted, fontSize = 14.sp, modifier = Modifier.padding(end = 6.dp))
        Text("›", color = FiveMinColors.muted, fontSize = 18.sp)
    }
}

@Composable
private fun LinkRow(title: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = FiveMinColors.ink, fontSize = 15.sp, modifier = Modifier.weight(1f))
        Text("›", color = FiveMinColors.muted, fontSize = 18.sp)
    }
}

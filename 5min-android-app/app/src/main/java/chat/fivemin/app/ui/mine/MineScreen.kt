package chat.fivemin.app.ui.mine

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import chat.fivemin.app.FiveMinApp
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.theme.FiveMinColors

private enum class MineDialog { None, Lang, Sound, Duration, Feedback, Beian }

@Composable
fun MineScreen(vm: TimerViewModel) {
    val state by vm.state.collectAsState()
    val context = LocalContext.current
    val catalog = FiveMinApp.instance.catalog
    var dialog by remember { mutableStateOf(MineDialog.None) }
    var customText by remember { mutableStateOf(state.customMin.toString()) }
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
                PrefRow(vm.t("durationSettingsLabel"), "${state.customMin} ${vm.t("customUnit")}") {
                    customText = state.customMin.toString()
                    dialog = MineDialog.Duration
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
        MineDialog.Duration -> AlertDialog(
            onDismissRequest = { dialog = MineDialog.None },
            dismissButton = {
                TextButton(onClick = { dialog = MineDialog.None }) {
                    Text(vm.t("cancelLabel"), color = FiveMinColors.muted)
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.applyCustomMinutes(customText.toIntOrNull() ?: state.customMin)
                    dialog = MineDialog.None
                }) {
                    Text(vm.t("confirmLabel"), color = FiveMinColors.brandStrong, fontWeight = FontWeight.SemiBold)
                }
            },
            title = { Text(vm.t("durationSettingsLabel"), fontWeight = FontWeight.SemiBold) },
            containerColor = FiveMinColors.surface,
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = customText,
                        onValueChange = { customText = it.filter { ch -> ch.isDigit() }.take(3) },
                        label = { Text(vm.t("customMinutesHint")) },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        quickMins.forEach { m ->
                            Text(
                                text = "$m",
                                modifier = Modifier
                                    .background(FiveMinColors.brandSoft, RoundedCornerShape(10.dp))
                                    .clickable {
                                        customText = m.toString()
                                        vm.applyCustomMinutes(m)
                                        dialog = MineDialog.None
                                    }
                                    .padding(horizontal = 12.dp, vertical = 8.dp),
                                color = FiveMinColors.brandStrong,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            },
        )
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

package chat.fivemin.app.ui

import android.app.Activity
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import chat.fivemin.app.R
import chat.fivemin.app.ShortcutPending
import chat.fivemin.app.data.AppUpdate
import chat.fivemin.app.timer.TimerViewModel
import chat.fivemin.app.ui.mine.MineScreen
import chat.fivemin.app.ui.records.RecordsScreen
import chat.fivemin.app.ui.theme.FiveMinColors
import chat.fivemin.app.ui.theme.FiveMinDimens

@Composable
fun RootApp(
    vm: TimerViewModel = viewModel(),
    ensureStartPermissions: (onReady: () -> Unit) -> Unit = { it() },
) {
    val state by vm.state.collectAsStateWithLifecycle()
    var privacyChecked by remember { mutableStateOf(false) }
    var pendingShortcutScene by remember { mutableStateOf<String?>(null) }
    val context = LocalContext.current
    val layoutDirection =
        if (state.locale.startsWith("ar")) LayoutDirection.Rtl else LayoutDirection.Ltr

    LaunchedEffect(Unit) {
        val intent = (context as? Activity)?.intent
        val scene = intent?.getStringExtra("FIVEMIN_SCREENSHOT")
        if (!scene.isNullOrBlank()) {
            vm.applyStoreScreenshot(scene)
        }
        val shortcutScene = ShortcutPending.take()
        if (!shortcutScene.isNullOrBlank()) {
            if (state.privacyAccepted) {
                vm.startFromShortcut(shortcutScene, ensureStartPermissions)
            } else {
                pendingShortcutScene = shortcutScene
            }
        }
    }

    LaunchedEffect(state.privacyAccepted, pendingShortcutScene) {
        val scene = pendingShortcutScene ?: return@LaunchedEffect
        if (!state.privacyAccepted) return@LaunchedEffect
        pendingShortcutScene = null
        vm.startFromShortcut(scene, ensureStartPermissions)
    }

    CompositionLocalProvider(LocalLayoutDirection provides layoutDirection) {
        if (!state.privacyAccepted) {
            // Full-page consent — aligned with Harmony / iOS / MP (no tabs behind).
            PrivacyConsentPane(
                vm = vm,
                checked = privacyChecked,
                onCheckedChange = { privacyChecked = it },
                onAgree = { vm.acceptPrivacy() },
                onOpenPrivacy = { openHttps(context, "https://5min.chat/privacy.html") },
                onOpenTerms = { openHttps(context, "https://5min.chat/terms.html") },
            )
        } else {
            Scaffold(
                containerColor = FiveMinColors.bg,
                bottomBar = {
                    NavigationBar(
                        containerColor = FiveMinColors.surface,
                        tonalElevation = 3.dp,
                    ) {
                        NavigationBarItem(
                            selected = state.selectedTab == 0,
                            onClick = { vm.setSelectedTab(0) },
                            icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = null) },
                            label = { Text(vm.t("tabRecords")) },
                            colors = navColors(),
                        )
                        NavigationBarItem(
                            selected = state.selectedTab == 1,
                            onClick = { vm.setSelectedTab(1) },
                            icon = { Icon(Icons.Filled.Home, contentDescription = null) },
                            label = { Text(vm.t("tabHome")) },
                            colors = navColors(),
                        )
                        NavigationBarItem(
                            selected = state.selectedTab == 2,
                            onClick = { vm.setSelectedTab(2) },
                            icon = { Icon(Icons.Filled.Person, contentDescription = null) },
                            label = { Text(vm.t("tabMine")) },
                            colors = navColors(),
                        )
                    }
                },
            ) { padding ->
                Box(modifier = Modifier.padding(padding).fillMaxSize()) {
                    when (state.selectedTab) {
                        0 -> RecordsScreen(vm)
                        2 -> MineScreen(vm)
                        else -> TimerHome(
                            vm = vm,
                            ensureStartPermissions = ensureStartPermissions,
                            onOpenMine = { vm.setSelectedTab(2) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PrivacyConsentPane(
    vm: TimerViewModel,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    onAgree: () -> Unit,
    onOpenPrivacy: () -> Unit,
    onOpenTerms: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(FiveMinColors.bg, FiveMinColors.bg2, FiveMinColors.bgBottom),
                ),
            )
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp, vertical = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Image(
                painter = painterResource(R.drawable.logo),
                contentDescription = null,
                modifier = Modifier.size(width = 28.dp * 108f / 32f, height = 28.dp),
                contentScale = ContentScale.Fit,
            )
            Text(
                text = vm.t("brandTitle"),
                color = FiveMinColors.ink,
                style = MaterialTheme.typography.titleLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }

        Card(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 360.dp),
            shape = MaterialTheme.shapes.extraLarge,
            colors = CardDefaults.cardColors(containerColor = FiveMinColors.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 3.dp),
        ) {
            Column(
                modifier = Modifier.padding(
                    horizontal = FiveMinDimens.padY,
                    vertical = FiveMinDimens.padBody,
                ),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    text = vm.t("privacyTitle"),
                    color = FiveMinColors.ink,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = vm.t("privacyMessage"),
                    color = FiveMinColors.muted,
                    style = MaterialTheme.typography.bodyMedium,
                    lineHeight = 22.sp,
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onCheckedChange(!checked) },
                ) {
                    Checkbox(
                        checked = checked,
                        onCheckedChange = onCheckedChange,
                        colors = CheckboxDefaults.colors(
                            checkedColor = FiveMinColors.brand,
                            uncheckedColor = FiveMinColors.muted,
                            checkmarkColor = androidx.compose.ui.graphics.Color.White,
                        ),
                    )
                    Text(
                        text = vm.t("privacyCheckLabel"),
                        color = FiveMinColors.ink,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f),
                    )
                }

                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    TextButton(onClick = onOpenPrivacy) {
                        Text(
                            text = vm.t("privacyLink"),
                            color = FiveMinColors.brandStrong,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                    TextButton(onClick = onOpenTerms) {
                        Text(
                            text = vm.t("termsLink"),
                            color = FiveMinColors.brandStrong,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }

                MaterialFilledWideButton(
                    text = vm.t("privacyAgree"),
                    onClick = onAgree,
                    enabled = checked,
                    modifier = Modifier.height(FiveMinDimens.controlH),
                )

                Text(
                    text = vm.t("privacyFooter"),
                    color = FiveMinColors.muted,
                    style = MaterialTheme.typography.bodySmall,
                    lineHeight = 18.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun navColors() = NavigationBarItemDefaults.colors(
    selectedIconColor = FiveMinColors.brandStrong,
    selectedTextColor = FiveMinColors.brandStrong,
    indicatorColor = FiveMinColors.brandSoft,
    unselectedIconColor = FiveMinColors.muted,
    unselectedTextColor = FiveMinColors.muted,
)

private fun openHttps(context: android.content.Context, url: String) {
    AppUpdate.openUrl(context, url)
}

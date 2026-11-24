package chat.fivemin.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.app.Activity
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
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
        // Only ShortcutActivity (non-exported) can offer a pending scene.
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
    Box(modifier = Modifier.fillMaxSize()) {
        Scaffold(
            containerColor = FiveMinColors.bg,
            bottomBar = {
                NavigationBar(containerColor = FiveMinColors.surface) {
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

        if (!state.privacyAccepted) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.45f)),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    modifier = Modifier
                        .padding(24.dp)
                        .background(FiveMinColors.surface, RoundedCornerShape(16.dp))
                        .padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Text(vm.t("privacyTitle"), color = FiveMinColors.ink, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                    Text(vm.t("privacyMessage"), color = FiveMinColors.muted, fontSize = 14.sp)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clickable { privacyChecked = !privacyChecked },
                    ) {
                        Checkbox(
                            checked = privacyChecked,
                            onCheckedChange = { privacyChecked = it },
                            colors = CheckboxDefaults.colors(checkedColor = FiveMinColors.brand),
                        )
                        Text(vm.t("privacyCheckLabel"), color = FiveMinColors.ink, fontSize = 14.sp)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        TextButton(onClick = { openHttps(context, "https://5min.chat/privacy.html") }) {
                            Text(vm.t("privacyLink"), color = FiveMinColors.brandStrong)
                        }
                        TextButton(onClick = { openHttps(context, "https://5min.chat/terms.html") }) {
                            Text(vm.t("termsLink"), color = FiveMinColors.brandStrong)
                        }
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                if (privacyChecked) FiveMinColors.brand else FiveMinColors.brand.copy(alpha = 0.45f),
                                RoundedCornerShape(FiveMinDimens.radiusCard),
                            )
                            .clickable(enabled = privacyChecked) { vm.acceptPrivacy() }
                            .padding(vertical = 14.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(vm.t("privacyAgree"), color = Color.White, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                    }
                }
            }
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

import SwiftUI
import UIKit

struct MineView: View {
    @Environment(TimerViewModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var sheet: MineSheet?
    @State private var sceneEditor: SceneEditor?
    @State private var editorName = ""
    @State private var editorMinutes = "5"
    @State private var showBeianAlert = false
    @State private var showCloudConfirm = false
    @State private var backupRevealed = false
    @State private var restoreRevealed = false
    @State private var restoreCode = ""
    @State private var promptRecoveryOnce = false
    @State private var overtimeInsight = P0Features.getShowOvertimeInsight()

    private enum MineSheet: String, Identifiable {
        case lang, sound, storage, customScenes, feedback, standRitual, alertProfile
        var id: String { rawValue }
    }

    private enum SceneEditor: Identifiable {
        case add
        case edit(CustomScene)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let scene): return scene.id
            }
        }
    }

    private let soundIds = ["off", "rain", "waves", "clock"]
    private let quickMins = [3, 5, 10, 15, 25]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    prefRow(model.t("langLabel"), value: model.catalog.t(model.locale, "nativeName")) {
                        sheet = .lang
                    }
                    prefRow(model.t("ambientLabel"), value: ambientLabel(model.ambient)) {
                        sheet = .sound
                    }
                    prefRow(model.t("customScenesLabel"), value: customScenesValue) {
                        sheet = .customScenes
                    }
                } header: {
                    Text(model.t("mineSectionPrefs"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .textCase(nil)
                }

                Section {
                    // Order aligned with Harmony / Android / MP:
                    // tone → vibrate → notify → overtime insight → alert profile
                    alertToggleRow(model.t("prefFinishTone"), isOn: alertBinding(
                        get: { model.finishTone },
                        set: { model.setFinishTone($0) }
                    ))
                    alertToggleRow(model.t("prefFinishVibrate"), isOn: alertBinding(
                        get: { model.finishVibrate },
                        set: { model.setFinishVibrate($0) }
                    ))
                    alertToggleRow(model.t("prefFinishNotify"), isOn: alertBinding(
                        get: { model.finishNotify },
                        set: { model.setFinishNotify($0) }
                    ))
                    alertToggleRow(model.t("prefOvertimeInsight"), isOn: $overtimeInsight)
                    prefRow(model.t("alertProfileLabel"), value: alertProfileValue) {
                        sheet = .alertProfile
                    }
                } header: {
                    Text(model.t("prefAlertsSection"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .textCase(nil)
                } footer: {
                    Text(model.t("alertProfileHint"))
                        .font(FiveMinFont.ui(12))
                        .foregroundStyle(FiveMinColor.muted)
                }

                Section {
                    prefRow(model.t("standRitualLabel"), value: standRitualValue) {
                        sheet = .standRitual
                    }
                } header: {
                    Text(model.t("standRitualSection"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .textCase(nil)
                }

                Section {
                    prefRow(
                        model.t("storageModeLabel"),
                        value: model.storageMode == PrefsStore.modeCloud
                            ? model.t("storageModeCloud")
                            : model.t("storageModeLocal")
                    ) {
                        sheet = .storage
                    }

                    if model.storageMode == PrefsStore.modeCloud, !model.recoveryCode().isEmpty {
                        DisclosureGroup(isExpanded: $backupRevealed) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(model.recoveryCode())
                                    .font(FiveMinFont.ui(12))
                                    .monospaced()
                                    .foregroundStyle(FiveMinColor.ink)
                                    .textSelection(.enabled)
                                    .lineSpacing(4)
                                Text(model.t("storageBackupHint"))
                                    .font(FiveMinFont.ui(12))
                                    .foregroundStyle(FiveMinColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button {
                                    UIPasteboard.general.string = model.recoveryCode()
                                } label: {
                                    Text(model.t("storageBackupCopy"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .tint(FiveMinColor.brand)
                            }
                            .padding(.vertical, 4)
                        } label: {
                            Text(model.t("storageBackupShow"))
                                .font(FiveMinFont.ui(15))
                                .foregroundStyle(FiveMinColor.ink)
                        }
                    }

                    DisclosureGroup(isExpanded: $restoreRevealed) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField(model.t("storageRestorePlaceholder"), text: $restoreCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(FiveMinFont.ui(13))
                            Text(model.t("storageRestoreHint"))
                                .font(FiveMinFont.ui(12))
                                .foregroundStyle(FiveMinColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                Task {
                                    let (ok, _) = await model.restoreWithCode(restoreCode)
                                    if ok {
                                        restoreCode = ""
                                        backupRevealed = false
                                        restoreRevealed = false
                                    }
                                }
                            } label: {
                                Text(model.t("storageRestoreAction"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(FiveMinColor.brand)
                        }
                        .padding(.vertical, 4)
                    } label: {
                        Text(model.t("storageRestoreLabel"))
                            .font(FiveMinFont.ui(15))
                            .foregroundStyle(FiveMinColor.ink)
                    }
                } header: {
                    Text(model.t("storageSection"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .textCase(nil)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.t("storageModeHint"))
                        if !model.storageSyncStatus.isEmpty {
                            Text(model.storageSyncStatus)
                        }
                    }
                    .font(FiveMinFont.ui(12))
                    .foregroundStyle(FiveMinColor.muted)
                }

                Section {
                    linkRow(model.t("privacyLink")) {
                        openTrusted("https://5min.chat/privacy.html")
                    }
                    linkRow(model.t("termsLink")) {
                        openTrusted("https://5min.chat/terms.html")
                    }
                    linkRow(model.t("aboutLabel")) {
                        openTrusted("https://5min.chat/about.html")
                    }
                    linkRow(model.t("feedbackLabel")) {
                        sheet = .feedback
                    }
                    linkRow(model.t("beianEntry")) {
                        showBeianAlert = true
                    }
                    versionRow
                } header: {
                    Text(model.t("mineSectionSupport"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [FiveMinColor.bg, FiveMinColor.bg2, FiveMinColor.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(model.t("tabMine"))
            .navigationBarTitleDisplayMode(.large)
        }
        .onChange(of: overtimeInsight) { _, on in
            model.setShowOvertimeInsight(on)
        }
        .sheet(item: $sheet, onDismiss: { sceneEditor = nil }) { kind in
            sheetContent(kind)
                .presentationDetents(kind == .customScenes ? [.medium, .large] : [.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(FiveMinDimens.radiusSheet)
        }
        .alert(model.t("beianTitle"), isPresented: $showBeianAlert) {
            Button(model.t("confirmLabel"), role: .cancel) {}
        } message: {
            Text(model.t("beianIcp"))
        }
        .alert(model.t("storageModeCloud"), isPresented: $showCloudConfirm) {
            Button(model.t("cancelLabel"), role: .cancel) {}
            Button(model.t("confirmLabel")) {
                promptRecoveryOnce = true
                model.setStorageMode(PrefsStore.modeCloud)
            }
        } message: {
            Text(model.t("storageCloudConfirm"))
        }
        .onChange(of: model.storageSyncStatus) { _, status in
            guard promptRecoveryOnce else { return }
            guard model.storageMode == PrefsStore.modeCloud else { return }
            guard status == model.t("storageSyncOk") else { return }
            promptRecoveryOnce = false
            if !model.recoveryCode().isEmpty {
                backupRevealed = true
            }
        }
    }

    private var customScenesValue: String {
        let n = model.customScenes.count
        if n <= 0 { return model.t("customScenesEmpty") }
        return model.t("customScenesCount", ["n": "\(n)"])
    }

    private var standRitualValue: String {
        model.standRitual == P0Features.ritualBasic
            ? model.t("standRitualBasic")
            : model.t("standRitualOff")
    }

    private var alertProfileValue: String {
        switch model.alertProfile {
        case P0Features.profileQuiet: return model.t("alertProfileQuiet")
        case P0Features.profileSilent: return model.t("alertProfileSilent")
        default: return model.t("alertProfileNormal")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Display-only version row (no update check).
    private var versionRow: some View {
        HStack {
            Text(versionTitle)
                .font(FiveMinFont.ui(15))
                .foregroundStyle(FiveMinColor.ink)
            Spacer(minLength: 8)
            Text(appVersion)
                .font(FiveMinFont.ui(14))
                .foregroundStyle(FiveMinColor.muted)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.t("aboutVersion", ["n": appVersion]))
    }

    /// `aboutVersion` is "Version {n}" — strip the placeholder for the left label.
    private var versionTitle: String {
        model.t("aboutVersion", ["n": ""])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "·•-:："))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func alertBinding(get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: set)
    }

    private func alertToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(FiveMinFont.ui(15))
                .foregroundStyle(FiveMinColor.ink)
        }
        .tint(FiveMinColor.brand)
    }

    private func prefRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(value)
                    .font(FiveMinFont.ui(14))
                    .foregroundStyle(FiveMinColor.muted)
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FiveMinColor.muted.opacity(0.55))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FiveMinColor.muted.opacity(0.55))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sheetContent(_ kind: MineSheet) -> some View {
        NavigationStack {
            switch kind {
            case .lang:
                List {
                    ForEach(AppLocales.filter(model.catalog.localeCodes), id: \.self) { code in
                        Button {
                            model.setLocale(code)
                            sheet = nil
                        } label: {
                            HStack {
                                Text(model.catalog.t(code, "nativeName"))
                                Spacer()
                                if code == model.locale {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FiveMinColor.brandStrong)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(model.t("langLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("cancelLabel")) { sheet = nil }
                    }
                }
            case .sound:
                List {
                    ForEach(soundIds, id: \.self) { id in
                        Button {
                            model.setAmbient(id)
                            sheet = nil
                        } label: {
                            HStack {
                                Text(ambientLabel(id))
                                Spacer()
                                if id == model.ambient {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FiveMinColor.brandStrong)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(model.t("ambientLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("cancelLabel")) { sheet = nil }
                    }
                }
            case .storage:
                List {
                    Button {
                        model.setStorageMode(PrefsStore.modeLocal)
                        sheet = nil
                    } label: {
                        HStack {
                            Text(model.t("storageModeLocal"))
                            Spacer()
                            if model.storageMode == PrefsStore.modeLocal {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FiveMinColor.brandStrong)
                            }
                        }
                    }
                    Button {
                        sheet = nil
                        showCloudConfirm = true
                    } label: {
                        HStack {
                            Text(model.t("storageModeCloud"))
                            Spacer()
                            if model.storageMode == PrefsStore.modeCloud {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FiveMinColor.brandStrong)
                            }
                        }
                    }
                }
                .navigationTitle(model.t("storageModeLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("cancelLabel")) { sheet = nil }
                    }
                }
            case .standRitual:
                List {
                    Button {
                        model.setStandRitual(P0Features.ritualOff)
                        sheet = nil
                    } label: {
                        HStack {
                            Text(model.t("standRitualOff"))
                            Spacer()
                            if model.standRitual == P0Features.ritualOff {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FiveMinColor.brandStrong)
                            }
                        }
                    }
                    Button {
                        model.setStandRitual(P0Features.ritualBasic)
                        sheet = nil
                    } label: {
                        HStack {
                            Text(model.t("standRitualBasic"))
                            Spacer()
                            if model.standRitual == P0Features.ritualBasic {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(FiveMinColor.brandStrong)
                            }
                        }
                    }
                }
                .navigationTitle(model.t("standRitualLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("cancelLabel")) { sheet = nil }
                    }
                }
            case .alertProfile:
                List {
                    ForEach(
                        [
                            (P0Features.profileNormal, "alertProfileNormal"),
                            (P0Features.profileQuiet, "alertProfileQuiet"),
                            (P0Features.profileSilent, "alertProfileSilent"),
                        ],
                        id: \.0
                    ) { id, key in
                        Button {
                            model.setAlertProfile(id)
                            sheet = nil
                        } label: {
                            HStack {
                                Text(model.t(key))
                                Spacer()
                                if model.alertProfile == id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(FiveMinColor.brandStrong)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(model.t("alertProfileLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("cancelLabel")) { sheet = nil }
                    }
                }
            case .customScenes:
                customScenesList
            case .feedback:
                List {
                    Section {
                        Text(model.t("feedbackBody"))
                            .font(FiveMinFont.ui(15))
                            .foregroundStyle(FiveMinColor.ink)
                        Text(model.t("feedbackEmail"))
                            .font(FiveMinFont.ui(15, weight: .medium))
                            .foregroundStyle(FiveMinColor.ink)
                            .textSelection(.enabled)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(model.t("feedbackLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("cancelLabel")) { sheet = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(model.t("copyEmailLabel")) { copyFeedbackEmail() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var customScenesList: some View {
        Group {
            if model.customScenes.isEmpty {
                ContentUnavailableView {
                    Label(model.t("customScenesEmpty"), systemImage: "square.stack.3d.up")
                } description: {
                    Text(model.t("customScenesEmptyHint"))
                } actions: {
                    Button(model.t("customSceneAdd")) { openSceneEditor(.add) }
                        .buttonStyle(.borderedProminent)
                        .tint(FiveMinColor.brand)
                }
            } else {
                List {
                    ForEach(model.customScenes) { scene in
                        HStack(spacing: 12) {
                            Button {
                                openSceneEditor(.edit(scene))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(scene.name)
                                        .font(FiveMinFont.ui(15, weight: .medium))
                                        .foregroundStyle(FiveMinColor.ink)
                                    Text("\(scene.min) \(model.t("customUnit"))")
                                        .font(FiveMinFont.ui(13))
                                        .foregroundStyle(FiveMinColor.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button {
                                model.queueCustomScene(scene.id)
                                sheet = nil
                                model.selectedTab = 1
                            } label: {
                                Text(model.t("customSceneUse"))
                                    .font(FiveMinFont.ui(13, weight: .semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(FiveMinColor.brand)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { model.customScenes[$0].id }
                        for id in ids {
                            model.deleteCustomScene(id: id)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(model.t("customScenesLabel"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(model.t("cancelLabel")) { sheet = nil }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openSceneEditor(.add)
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(model.customScenes.count >= CustomScene.maxCount)
                .accessibilityLabel(model.t("customSceneAdd"))
            }
        }
        .sheet(item: $sceneEditor) { editor in
            sceneEditorSheet(editor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(FiveMinDimens.radiusSheet)
        }
    }

    private func sceneEditorSheet(_ editor: SceneEditor) -> some View {
        NavigationStack {
            Form {
                Section {
                    TextField(model.t("customSceneNamePlaceholder"), text: $editorName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } header: {
                    Text(model.t("customSceneNameLabel"))
                        .textCase(nil)
                }

                Section {
                    HStack(spacing: FiveMinDimens.controlGap) {
                        Button {
                            nudgeEditor(-1)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(FiveMinColor.brand)
                        .accessibilityLabel("-")

                        TextField("", text: $editorMinutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(FiveMinFont.ui(24, weight: .medium))
                            .frame(maxWidth: .infinity)

                        Button {
                            nudgeEditor(1)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(FiveMinColor.brand)
                        .accessibilityLabel("+")
                    }

                    HStack(spacing: 8) {
                        ForEach(quickMins, id: \.self) { m in
                            let selected = (Int(editorMinutes) ?? -1) == m
                            Button("\(m)") {
                                editorMinutes = "\(m)"
                            }
                            .font(FiveMinFont.ui(14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                            .tint(selected ? FiveMinColor.brand : FiveMinColor.muted)
                        }
                    }
                } header: {
                    Text(model.t("customMinutesLabel"))
                        .textCase(nil)
                }
            }
            .navigationTitle(editorTitle(editor))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t("cancelLabel")) { sceneEditor = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t("confirmLabel")) { saveSceneEditor(editor) }
                        .fontWeight(.semibold)
                        .foregroundStyle(FiveMinColor.brandStrong)
                        .disabled(CustomScene.normalizedName(editorName).isEmpty)
                }
            }
        }
    }

    private func editorTitle(_ editor: SceneEditor) -> String {
        switch editor {
        case .add: return model.t("customSceneAdd")
        case .edit: return model.t("customSceneEdit")
        }
    }

    private func openSceneEditor(_ editor: SceneEditor) {
        switch editor {
        case .add:
            editorName = ""
            editorMinutes = "\(model.customMin)"
        case .edit(let scene):
            editorName = scene.name
            editorMinutes = "\(scene.min)"
        }
        sceneEditor = editor
    }

    private func nudgeEditor(_ delta: Int) {
        let cur = Int(editorMinutes) ?? model.customMin
        editorMinutes = "\(CustomScene.clampMinutes(cur + delta))"
    }

    private func saveSceneEditor(_ editor: SceneEditor) {
        let minutes = CustomScene.clampMinutes(Int(editorMinutes) ?? model.customMin)
        let id: String?
        switch editor {
        case .add: id = nil
        case .edit(let scene): id = scene.id
        }
        guard model.upsertCustomScene(id: id, name: editorName, minutes: minutes) != nil else { return }
        sceneEditor = nil
    }

    private func ambientLabel(_ id: String) -> String {
        switch id {
        case "rain": return model.t("ambientRain")
        case "waves": return model.t("ambientWaves")
        case "clock": return model.t("ambientClock")
        default: return model.t("ambientOff")
        }
    }

    private func copyFeedbackEmail() {
        UIPasteboard.general.string = model.t("feedbackEmail")
        sheet = nil
    }

    private func openTrusted(_ string: String) {
        guard let url = TrustedURL.parse(string) else { return }
        openURL(url)
    }
}

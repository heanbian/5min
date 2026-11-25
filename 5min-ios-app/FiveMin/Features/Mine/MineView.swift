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
    @State private var restoreCode = ""
    @State private var promptRecoveryOnce = false

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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: FiveMinDimens.listSectionGap) {
                    sectionTitle(model.t("mineSectionPrefs"))
                    card {
                        prefRow(model.t("langLabel"), value: model.catalog.t(model.locale, "nativeName")) {
                            sheet = .lang
                        }
                        Divider().padding(.leading, 16)
                        prefRow(model.t("ambientLabel"), value: ambientLabel(model.ambient)) {
                            sheet = .sound
                        }
                        Divider().padding(.leading, 16)
                        prefRow(model.t("customScenesLabel"), value: customScenesValue) {
                            sheet = .customScenes
                        }
                    }

                    sectionTitle(model.t("prefAlertsSection"))
                    card {
                        prefRow(model.t("alertProfileLabel"), value: alertProfileValue) {
                            sheet = .alertProfile
                        }
                        Divider().padding(.leading, 16)
                        alertToggleRow(model.t("prefFinishTone"), isOn: alertBinding(
                            get: { model.finishTone },
                            set: { model.setFinishTone($0) }
                        ))
                        Divider().padding(.leading, 16)
                        alertToggleRow(model.t("prefFinishVibrate"), isOn: alertBinding(
                            get: { model.finishVibrate },
                            set: { model.setFinishVibrate($0) }
                        ))
                        Divider().padding(.leading, 16)
                        alertToggleRow(model.t("prefFinishNotify"), isOn: alertBinding(
                            get: { model.finishNotify },
                            set: { model.setFinishNotify($0) }
                        ))
                    }
                    Text(model.t("alertProfileHint"))
                        .font(FiveMinFont.ui(12))
                        .foregroundStyle(FiveMinColor.muted)
                        .padding(.horizontal, 4)

                    sectionTitle(model.t("standRitualSection"))
                    card {
                        prefRow(model.t("standRitualLabel"), value: standRitualValue) {
                            sheet = .standRitual
                        }
                    }

                    sectionTitle(model.t("storageSection"))
                    card {
                        prefRow(
                            model.t("storageModeLabel"),
                            value: model.storageMode == PrefsStore.modeCloud
                                ? model.t("storageModeCloud")
                                : model.t("storageModeLocal")
                        ) {
                            sheet = .storage
                        }
                    }
                    Text(model.t("storageModeHint"))
                        .font(FiveMinFont.ui(12))
                        .foregroundStyle(FiveMinColor.muted)
                        .padding(.horizontal, 4)
                    if !model.storageSyncStatus.isEmpty {
                        Text(model.storageSyncStatus)
                            .font(FiveMinFont.ui(12))
                            .foregroundStyle(FiveMinColor.muted)
                            .padding(.horizontal, 4)
                    }
                    if model.storageMode == PrefsStore.modeCloud, !model.recoveryCode().isEmpty {
                        card {
                            Button {
                                backupRevealed = true
                            } label: {
                                Text(model.t("storageBackupShow"))
                                    .font(FiveMinFont.ui(15))
                                    .foregroundStyle(FiveMinColor.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 48)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if backupRevealed {
                                Divider().padding(.leading, 16)
                                Text(model.recoveryCode())
                                    .font(FiveMinFont.ui(12))
                                    .monospaced()
                                    .foregroundStyle(FiveMinColor.ink)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                Text(model.t("storageBackupHint"))
                                    .font(FiveMinFont.ui(12))
                                    .foregroundStyle(FiveMinColor.muted)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 4)
                                Button {
                                    UIPasteboard.general.string = model.recoveryCode()
                                } label: {
                                    Text(model.t("storageBackupCopy"))
                                        .font(FiveMinFont.ui(14, weight: .semibold))
                                        .foregroundStyle(FiveMinColor.brandStrong)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    card {
                        Text(model.t("storageRestoreLabel"))
                            .font(FiveMinFont.ui(15))
                            .foregroundStyle(FiveMinColor.ink)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        TextField(model.t("storageRestorePlaceholder"), text: $restoreCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(FiveMinFont.ui(13))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Text(model.t("storageRestoreHint"))
                            .font(FiveMinFont.ui(12))
                            .foregroundStyle(FiveMinColor.muted)
                            .padding(.horizontal, 16)
                        Button {
                            Task {
                                let (ok, _) = await model.restoreWithCode(restoreCode)
                                if ok {
                                    restoreCode = ""
                                    backupRevealed = false
                                }
                            }
                        } label: {
                            Text(model.t("storageRestoreAction"))
                                .font(FiveMinFont.ui(14, weight: .semibold))
                                .foregroundStyle(FiveMinColor.brandStrong)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }

                    sectionTitle(model.t("mineSectionSupport"))
                    card {
                        linkRow(model.t("privacyLink")) {
                            openTrusted("https://5min.chat/privacy.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("termsLink")) {
                            openTrusted("https://5min.chat/terms.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("aboutLabel")) {
                            openTrusted("https://5min.chat/about.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("feedbackLabel")) {
                            sheet = .feedback
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("beianEntry")) {
                            showBeianAlert = true
                        }
                        Divider().padding(.leading, 16)
                        versionRow
                    }

                }
                .padding(.horizontal, FiveMinDimens.padBody)
                .padding(.vertical, FiveMinDimens.padBody)
            }
            .background(
                LinearGradient(
                    colors: [FiveMinColor.bg, FiveMinColor.bg2, FiveMinColor.bgBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(item: $sheet, onDismiss: { sceneEditor = nil }) { kind in
            sheetContent(kind)
                .presentationDetents(kind == .customScenes ? [.medium, .large] : [.medium])
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
        .padding(.horizontal, 16)
        .frame(height: 52)
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

    private var header: some View {
        HStack {
            Text(model.t("tabMine"))
                .font(FiveMinFont.ui(20, weight: .semibold))
                .foregroundStyle(FiveMinColor.ink)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(FiveMinColor.surface.opacity(0.72))
        .overlay(alignment: .bottom) {
            Rectangle().fill(FiveMinColor.line.opacity(0.85)).frame(height: 1)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(FiveMinFont.ui(13, weight: .medium))
            .foregroundStyle(FiveMinColor.muted)
            .padding(.leading, 4)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(FiveMinColor.surface.opacity(0.88))
            .overlay(
                RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous)
                    .strokeBorder(FiveMinColor.line.opacity(0.9), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous))
            .shadow(color: FiveMinColor.ink.opacity(0.04), radius: 8, y: 2)
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
        .tint(FiveMinColor.brandStrong)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
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
                    .frame(width: 160, alignment: .trailing)
                Text("›")
                    .font(FiveMinFont.ui(18))
                    .foregroundStyle(FiveMinColor.muted)
                    .frame(width: 16, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
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
                Text("›")
                    .font(FiveMinFont.ui(18))
                    .foregroundStyle(FiveMinColor.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
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
                VStack(alignment: .leading, spacing: FiveMinDimens.listSectionGap) {
                    Text(model.t("feedbackBody"))
                        .font(FiveMinFont.ui(15))
                        .foregroundStyle(FiveMinColor.ink)
                    Text(model.t("feedbackEmail"))
                        .font(FiveMinFont.ui(15, weight: .medium))
                        .foregroundStyle(FiveMinColor.ink)
                        .textSelection(.enabled)
                    Button(model.t("copyEmailLabel")) { copyFeedbackEmail() }
                        .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(model.t("feedbackLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { sheet = nil } label: {
                            Image(systemName: "xmark")
                                .font(FiveMinFont.ui(14, weight: .semibold))
                        }
                        .accessibilityLabel(model.t("cancelLabel"))
                    }
                }
            }
        }
    }

    private var customScenesList: some View {
        Group {
            if model.customScenes.isEmpty {
                VStack(spacing: 12) {
                    Text(model.t("customScenesEmptyHint"))
                        .font(FiveMinFont.ui(14))
                        .foregroundStyle(FiveMinColor.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button(model.t("customSceneAdd")) { openSceneEditor(.add) }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 28)
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
                                    .foregroundStyle(FiveMinColor.brandStrong)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(FiveMinColor.brandSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { model.customScenes[$0].id }
                        for id in ids {
                            model.deleteCustomScene(id: id)
                        }
                    }
                }
                .listStyle(.plain)
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
        }
    }

    private func sceneEditorSheet(_ editor: SceneEditor) -> some View {
        NavigationStack {
            VStack(spacing: FiveMinDimens.sectionGap) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("customSceneNameLabel"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                    TextField(model.t("customSceneNamePlaceholder"), text: $editorName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 14)
                        .frame(height: FiveMinDimens.fieldH)
                        .background(FiveMinColor.ghostBg)
                        .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                                .stroke(FiveMinColor.line, lineWidth: 1)
                        )
                }
                .padding(.horizontal, FiveMinDimens.padX)

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("customMinutesLabel"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                    HStack(spacing: FiveMinDimens.controlGap) {
                        Button("-") { nudgeEditor(-1) }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: FiveMinDimens.controlH)
                            .accessibilityLabel("-")
                        TextField("", text: $editorMinutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(FiveMinFont.ui(24, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: FiveMinDimens.fieldH)
                            .background(FiveMinColor.ghostBg)
                            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                                    .stroke(FiveMinColor.line, lineWidth: 1)
                            )
                        Button("+") { nudgeEditor(1) }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: FiveMinDimens.controlH)
                            .accessibilityLabel("+")
                    }
                }
                .padding(.horizontal, FiveMinDimens.padX)

                HStack(spacing: 8) {
                    ForEach(quickMins, id: \.self) { m in
                        Button("\(m)") {
                            editorMinutes = "\(m)"
                        }
                        .font(FiveMinFont.ui(14, weight: .semibold))
                        .foregroundStyle(FiveMinColor.brandStrong)
                        .frame(height: FiveMinDimens.chipH)
                        .padding(.horizontal, 12)
                        .background(FiveMinColor.brandSoft)
                        .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusSm, style: .continuous))
                    }
                }
                .padding(.horizontal, FiveMinDimens.padX)

                Button(model.t("confirmLabel")) { saveSceneEditor(editor) }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, FiveMinDimens.padX)
                    .disabled(CustomScene.normalizedName(editorName).isEmpty)
                    .opacity(CustomScene.normalizedName(editorName).isEmpty ? 0.55 : 1)

                Spacer()
            }
            .padding(.top, FiveMinDimens.padY)
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

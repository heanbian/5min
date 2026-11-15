import SwiftUI
import UIKit

struct MineView: View {
    @EnvironmentObject private var model: TimerViewModel
    @State private var sheet: MineSheet?
    @State private var sceneEditor: SceneEditor?
    @State private var editorName = ""
    @State private var editorMinutes = "5"
    @State private var showBeianAlert = false
    @State private var showCloudConfirm = false

    private enum MineSheet: String, Identifiable {
        case lang, sound, storage, customScenes, feedback
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
                VStack(alignment: .leading, spacing: 18) {
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

                    sectionTitle(model.t("mineSectionSupport"))
                    card {
                        linkRow(model.t("privacyLink")) {
                            openURL("https://5min.chat/privacy.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("termsLink")) {
                            openURL("https://5min.chat/terms.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("aboutLabel")) {
                            openURL("https://5min.chat/about.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("feedbackLabel")) {
                            sheet = .feedback
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("beianEntry")) {
                            showBeianAlert = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(red: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF3 / 255))
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
                model.setStorageMode(PrefsStore.modeCloud)
            }
        } message: {
            Text(model.t("storageCloudConfirm"))
        }
    }

    private var customScenesValue: String {
        let n = model.customScenes.count
        if n <= 0 { return model.t("customScenesEmpty") }
        return model.t("customScenesCount", ["n": "\(n)"])
    }

    private var header: some View {
        HStack {
            Text(model.t("tabMine"))
                .font(FiveMinFont.ui(20, weight: .medium))
                .foregroundStyle(FiveMinColor.ink)
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(FiveMinColor.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FiveMinColor.line).frame(height: 1)
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
            .background(FiveMinColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            HStack {
                Text(title)
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
                Spacer()
                Text(value)
                    .font(FiveMinFont.ui(14))
                    .foregroundStyle(FiveMinColor.muted)
                    .lineLimit(1)
                Text("›")
                    .font(FiveMinFont.ui(18))
                    .foregroundStyle(FiveMinColor.muted)
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
            case .customScenes:
                customScenesList
            case .feedback:
                VStack(alignment: .leading, spacing: 16) {
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

    private func openURL(_ string: String) {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https" else { return }
        UIApplication.shared.open(url)
    }
}

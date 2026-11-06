import SwiftUI
import UIKit

struct MineView: View {
    @EnvironmentObject private var model: TimerViewModel
    @State private var sheet: MineSheet?
    @State private var customText = "5"
    @State private var showAbout = false

    private enum MineSheet: String, Identifiable {
        case lang, sound, duration
        var id: String { rawValue }
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
                        prefRow(model.t("durationSettingsLabel"), value: "\(model.customMin) \(model.t("customUnit"))") {
                            customText = "\(model.customMin)"
                            sheet = .duration
                        }
                    }

                    sectionTitle(model.t("mineSectionSupport"))
                    card {
                        linkRow(model.t("feedbackLabel")) {
                            openURL("https://5min.chat/about.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("privacyLink")) {
                            openURL("https://5min.chat/privacy.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("termsLink")) {
                            openURL("https://5min.chat/terms.html")
                        }
                        Divider().padding(.leading, 16)
                        linkRow(model.t("aboutLabel")) {
                            showAbout = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(red: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF3 / 255))
        }
        .sheet(item: $sheet) { kind in
            sheetContent(kind)
                .presentationDetents(kind == .duration ? [.medium, .large] : [.medium])
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
                .environmentObject(model)
        }
    }

    private var header: some View {
        HStack {
            Text(model.t("tabMine"))
                .font(.system(size: 20, weight: .medium))
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
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(FiveMinColor.muted)
            .padding(.leading, 4)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(FiveMinColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func prefRow(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(FiveMinColor.ink)
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(FiveMinColor.muted)
                    .lineLimit(1)
                Text("›")
                    .font(.system(size: 18))
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
                    .font(.system(size: 15))
                    .foregroundStyle(FiveMinColor.ink)
                Spacer()
                Text("›")
                    .font(.system(size: 18))
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
                        Button(model.t("backLabel")) { sheet = nil }
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
                        Button(model.t("backLabel")) { sheet = nil }
                    }
                }
            case .duration:
                VStack(spacing: 16) {
                    Text(model.t("customMinutesLabel"))
                        .font(.system(size: 15, weight: .medium))
                    HStack(spacing: 16) {
                        Button("-") { nudge(-1) }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: 64)
                        TextField("", text: $customText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 28, weight: .medium))
                            .frame(maxWidth: .infinity)
                        Button("+") { nudge(1) }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: 64)
                    }
                    .padding(.horizontal, 20)

                    HStack(spacing: 8) {
                        ForEach(quickMins, id: \.self) { m in
                            Button("\(m)") {
                                customText = "\(m)"
                                applyCustom()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FiveMinColor.brandStrong)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(FiveMinColor.brandSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    Button(model.t("customApply")) { applyCustom() }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .padding(.top, 20)
                .navigationTitle(model.t("durationSettingsLabel"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(model.t("backLabel")) { sheet = nil }
                    }
                }
            }
        }
    }

    private func ambientLabel(_ id: String) -> String {
        switch id {
        case "rain": return model.t("ambientRain")
        case "waves": return model.t("ambientWaves")
        case "clock": return model.t("ambientClock")
        default: return model.t("ambientOff")
        }
    }

    private func nudge(_ delta: Int) {
        let cur = Int(customText) ?? model.customMin
        customText = "\(Swift.max(1, Swift.min(120, cur + delta)))"
    }

    private func applyCustom() {
        let n = Swift.max(1, Swift.min(120, Int(customText) ?? model.customMin))
        model.applyCustomMinutes(n)
        sheet = nil
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https" else { return }
        UIApplication.shared.open(url)
    }
}

struct AboutView: View {
    @EnvironmentObject private var model: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(model.t("aboutTitle"))
                        .font(.system(size: 20, weight: .semibold))
                    Text(model.t("aboutBody"))
                        .font(.system(size: 14))
                        .foregroundStyle(FiveMinColor.muted)
                    Text(model.t("aboutVersion", ["n": appVersion]))
                        .font(.system(size: 13))
                        .foregroundStyle(FiveMinColor.muted)
                    Button(model.t("aboutWebsite")) {
                        if let url = URL(string: "https://5min.chat") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundStyle(FiveMinColor.brandStrong)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.t("backLabel")) { dismiss() }
                }
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

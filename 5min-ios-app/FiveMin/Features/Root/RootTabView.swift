import SwiftUI

struct RootTabView: View {
    @Environment(TimerViewModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var privacyChecked = false

    var body: some View {
        @Bindable var model = model
        let isRTL = model.locale.hasPrefix("ar")
        Group {
            if !model.privacyAccepted {
                // Dedicated consent surface (no timer UI behind) — aligned with Harmony / MP.
                privacyGate
            } else {
                TabView(selection: $model.selectedTab) {
                    Tab(model.t("tabRecords"), systemImage: "list.bullet", value: 0) {
                        RecordsView()
                    }
                    Tab(model.t("tabHome"), systemImage: "house.fill", value: 1) {
                        TimerView()
                    }
                    Tab(model.t("tabMine"), systemImage: "person.fill", value: 2) {
                        MineView()
                    }
                }
                .tint(FiveMinColor.brand)
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .onChange(of: model.selectedTab) { _, newValue in
            if newValue == 0 {
                model.recordsEpoch += 1
            } else if newValue == 1 {
                model.consumePendingScene()
                model.refreshTodayStats()
                model.refreshSuggested()
            }
        }
    }

    private var privacyGate: some View {
        ZStack {
            LinearGradient(
                colors: [FiveMinColor.bg, FiveMinColor.bg2, FiveMinColor.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        Image("Logo")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 28 * 108 / 32, height: 28)
                        Text(model.t("brandTitle"))
                            .font(FiveMinFont.ui(20, weight: .semibold))
                            .foregroundStyle(FiveMinColor.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(model.t("privacyTitle"))
                            .font(FiveMinFont.ui(18, weight: .semibold))
                            .foregroundStyle(FiveMinColor.ink)

                        Text(model.t("privacyMessage"))
                            .font(FiveMinFont.ui(14))
                            .foregroundStyle(FiveMinColor.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            privacyChecked.toggle()
                        } label: {
                            Label {
                                Text(model.t("privacyCheckLabel"))
                                    .font(FiveMinFont.ui(14))
                                    .foregroundStyle(FiveMinColor.ink)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } icon: {
                                Image(systemName: privacyChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(privacyChecked ? FiveMinColor.brand : FiveMinColor.muted)
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityValue(privacyChecked ? Text("1") : Text("0"))

                        HStack(spacing: 8) {
                            Button(model.t("privacyLink")) {
                                openTrusted("https://5min.chat/privacy.html")
                            }
                            .buttonStyle(.borderless)
                            .font(FiveMinFont.ui(14, weight: .medium))
                            .foregroundStyle(FiveMinColor.brandStrong)

                            Button(model.t("termsLink")) {
                                openTrusted("https://5min.chat/terms.html")
                            }
                            .buttonStyle(.borderless)
                            .font(FiveMinFont.ui(14, weight: .medium))
                            .foregroundStyle(FiveMinColor.brandStrong)
                        }
                        .padding(.top, 2)

                        Button {
                            guard privacyChecked else { return }
                            model.acceptPrivacy()
                        } label: {
                            Text(model.t("privacyAgree"))
                                .font(FiveMinFont.ui(16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: FiveMinDimens.controlH)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FiveMinColor.brand)
                        .disabled(!privacyChecked)
                        .opacity(privacyChecked ? 1 : 0.55)
                        .padding(.top, 4)
                        .accessibilityHint(privacyChecked ? "" : model.t("privacyCheckLabel"))

                        Text(model.t("privacyFooter"))
                            .font(FiveMinFont.ui(12))
                            .foregroundStyle(FiveMinColor.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, FiveMinDimens.padY)
                    .padding(.vertical, FiveMinDimens.padBody)
                    .frame(maxWidth: 360)
                    .background(FiveMinColor.surface)
                    .clipShape(
                        RoundedRectangle(cornerRadius: FiveMinDimens.radiusDialog, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FiveMinDimens.radiusDialog, style: .continuous)
                            .stroke(FiveMinColor.line.opacity(0.9), lineWidth: 1)
                    )
                    .shadow(color: FiveMinColor.ink.opacity(0.12), radius: 24, y: 10)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func openTrusted(_ string: String) {
        guard let url = TrustedURL.parse(string) else { return }
        openURL(url)
    }
}

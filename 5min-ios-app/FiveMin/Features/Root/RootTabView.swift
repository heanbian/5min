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
                            HStack(alignment: .center, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(
                                            privacyChecked ? FiveMinColor.brand : FiveMinColor.muted,
                                            lineWidth: 1.5
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(privacyChecked ? FiveMinColor.brand : Color.clear)
                                        )
                                        .frame(width: 22, height: 22)
                                    if privacyChecked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 44, height: 44)

                                Text(model.t("privacyCheckLabel"))
                                    .font(FiveMinFont.ui(14))
                                    .foregroundStyle(FiveMinColor.ink)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(.isButton)

                        HStack(spacing: 16) {
                            Button(model.t("privacyLink")) {
                                openTrusted("https://5min.chat/privacy.html")
                            }
                            .font(FiveMinFont.ui(14, weight: .medium))
                            .foregroundStyle(FiveMinColor.brandStrong)

                            Button(model.t("termsLink")) {
                                openTrusted("https://5min.chat/terms.html")
                            }
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
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: FiveMinDimens.controlH,
                                    maxHeight: FiveMinDimens.controlH
                                )
                                .foregroundStyle(privacyChecked ? Color.white : FiveMinColor.muted)
                                .background(
                                    Group {
                                        if privacyChecked {
                                            LinearGradient(
                                                colors: [
                                                    FiveMinColor.brandLift,
                                                    FiveMinColor.brand,
                                                    FiveMinColor.brandStrong,
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        } else {
                                            FiveMinColor.brandSoft
                                        }
                                    }
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                                )
                                .shadow(
                                    color: privacyChecked
                                        ? FiveMinColor.brand.opacity(0.28)
                                        : .clear,
                                    radius: privacyChecked ? 10 : 0,
                                    y: privacyChecked ? 5 : 0
                                )
                        }
                        .buttonStyle(.plain)
                        .opacity(privacyChecked ? 1 : 0.55)
                        .disabled(!privacyChecked)
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
                    .background(
                        LinearGradient(
                            colors: [
                                FiveMinColor.brandSoft.opacity(0.55),
                                FiveMinColor.surface,
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: FiveMinDimens.radiusDialog, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: FiveMinDimens.radiusDialog, style: .continuous)
                            .stroke(FiveMinColor.line.opacity(0.9), lineWidth: 1)
                    )
                    .shadow(color: FiveMinColor.ink.opacity(0.14), radius: 20, y: 8)
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

import SwiftUI

struct RootTabView: View {
    @Environment(TimerViewModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var privacyChecked = false

    var body: some View {
        @Bindable var model = model
        let isRTL = model.locale.hasPrefix("ar")
        ZStack {
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

            if !model.privacyAccepted {
                privacyGate
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
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
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
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: privacyChecked ? "checkmark.square.fill" : "square")
                            .font(FiveMinFont.ui(18))
                            .foregroundStyle(privacyChecked ? FiveMinColor.brand : FiveMinColor.muted)
                            .frame(width: 28, height: 28)
                        Text(model.t("privacyCheckLabel"))
                            .font(FiveMinFont.ui(14))
                            .foregroundStyle(FiveMinColor.ink)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 16) {
                    Button(model.t("privacyLink")) {
                        openTrusted("https://5min.chat/privacy.html")
                    }
                    .font(FiveMinFont.ui(13, weight: .medium))
                    .foregroundStyle(FiveMinColor.brandStrong)

                    Button(model.t("termsLink")) {
                        openTrusted("https://5min.chat/terms.html")
                    }
                    .font(FiveMinFont.ui(13, weight: .medium))
                    .foregroundStyle(FiveMinColor.brandStrong)
                }

                Button(model.t("privacyAgree")) {
                    model.acceptPrivacy()
                }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(privacyChecked ? 1 : 0.55)
                .disabled(!privacyChecked)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(
                LinearGradient(
                    colors: [FiveMinColor.brandSoft.opacity(0.5), FiveMinColor.surface],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusDialog, style: .continuous))
            .shadow(color: FiveMinColor.ink.opacity(0.14), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
    }

    private func openTrusted(_ string: String) {
        guard let url = TrustedURL.parse(string) else { return }
        openURL(url)
    }
}

import SwiftUI
import UIKit

struct RootTabView: View {
    @EnvironmentObject private var model: TimerViewModel
    @State private var privacyChecked = false

    var body: some View {
        ZStack {
            TabView(selection: $model.selectedTab) {
                RecordsView()
                    .tabItem {
                        Label(model.t("tabRecords"), systemImage: "list.bullet")
                    }
                    .tag(0)

                TimerView()
                    .tabItem {
                        Label(model.t("tabHome"), systemImage: "house.fill")
                    }
                    .tag(1)

                MineView()
                    .tabItem {
                        Label(model.t("tabMine"), systemImage: "person.fill")
                    }
                    .tag(2)
            }
            .tint(FiveMinColor.brand)

            if !model.privacyAccepted {
                privacyGate
            }
        }
        .onChange(of: model.selectedTab) { _, newValue in
            if newValue == 0 {
                model.recordsEpoch += 1
            } else if newValue == 1 {
                model.consumePendingCustomMin()
                model.refreshTodayStats()
            }
        }
    }

    private var privacyGate: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("privacyTitle"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FiveMinColor.ink)

                Text(model.t("privacyMessage"))
                    .font(.system(size: 14))
                    .foregroundStyle(FiveMinColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    privacyChecked.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: privacyChecked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(privacyChecked ? FiveMinColor.brand : FiveMinColor.muted)
                        Text(model.t("privacyCheckLabel"))
                            .font(.system(size: 14))
                            .foregroundStyle(FiveMinColor.ink)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 16) {
                    Button(model.t("privacyLink")) {
                        openURL("https://5min.chat/privacy.html")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FiveMinColor.brandStrong)

                    Button(model.t("termsLink")) {
                        openURL("https://5min.chat/terms.html")
                    }
                    .font(.system(size: 13, weight: .medium))
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
            .background(FiveMinColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https" else { return }
        UIApplication.shared.open(url)
    }
}

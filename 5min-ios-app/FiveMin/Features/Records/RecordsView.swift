import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var model: TimerViewModel
    @State private var rows: [HistoryItem] = []
    @State private var periodCount = 0
    @State private var periodMins = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.t("weekStatsLabel"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .padding(.leading, 4)

                    HStack(spacing: 10) {
                        statCard(title: model.t("weekStatsCountLabel"), value: "\(periodCount)", unit: nil)
                        statCard(title: model.t("weekStatsMinsLabel"), value: "\(periodMins)", unit: model.t("customUnit"))
                    }

                    Text(model.t("historyLabel"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .padding(.leading, 4)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        if rows.isEmpty {
                            Text(model.t("historyEmpty"))
                                .font(.system(size: 14))
                                .foregroundStyle(FiveMinColor.muted)
                                .frame(maxWidth: .infinity)
                                .padding(20)
                        } else {
                            ForEach(rows) { item in
                                historyRow(item)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(FiveMinColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(red: 0xF2 / 255, green: 0xF5 / 255, blue: 0xF3 / 255))
        }
        .onAppear(perform: reload)
        .onChange(of: model.recordsEpoch) { _, _ in reload() }
        .onChange(of: model.locale) { _, _ in reload() }
    }

    private var header: some View {
        HStack {
            Text(model.t("tabRecords"))
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

    private func statCard(title: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(FiveMinColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(FiveMinColor.ink)
                if let unit {
                    Text(unit)
                        .font(.system(size: 13))
                        .foregroundStyle(FiveMinColor.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FiveMinColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        let scene = sceneName(item.sceneId)
        return VStack(alignment: .leading, spacing: 6) {
            Text(model.t("historySceneLine", ["scene": scene]))
                .font(.system(size: 15))
                .foregroundStyle(FiveMinColor.ink)
            Text(model.t("historyDurationLine", ["n": "\(item.minutes)"]))
                .font(.system(size: 15))
                .foregroundStyle(FiveMinColor.ink)
            Text(model.t("historyTimeLine", ["time": formatDateTime(item.at)]))
                .font(.system(size: 15))
                .foregroundStyle(FiveMinColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sceneName(_ sceneId: String) -> String {
        guard !sceneId.isEmpty,
              let scene = model.catalog.scenes.first(where: { $0.id == sceneId }) else {
            return model.t("historySceneDefault")
        }
        return model.t(scene.titleKey)
    }

    private func formatDateTime(_ at: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(at) / 1000.0)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func reload() {
        rows = HistoryStore.shared.getHistory()
        let period = HistoryStore.shared.periodStats()
        periodCount = period.count
        periodMins = period.minutes
    }
}

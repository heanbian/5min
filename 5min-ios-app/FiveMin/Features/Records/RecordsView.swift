import SwiftUI

private let historyFilterAll = "__all__"

struct RecordsView: View {
    @EnvironmentObject private var model: TimerViewModel
    @State private var rows: [HistoryItem] = []
    @State private var periodCount = 0
    @State private var periodMins = 0
    @State private var filterSceneId = historyFilterAll
    @State private var sceneFilterOptions: [(id: String, label: String)] = []
    @State private var pendingDeleteId: Int64?
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: FiveMinDimens.listSectionGap) {
                    Text(model.t("weekStatsLabel"))
                        .font(FiveMinFont.ui(13, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                        .padding(.leading, 4)

                    HStack(spacing: 10) {
                        statCard(title: model.t("weekStatsCountLabel"), value: "\(periodCount)", unit: nil)
                        statCard(title: model.t("weekStatsMinsLabel"), value: "\(periodMins)", unit: model.t("customUnit"))
                    }

                    if P0Features.getShowOvertimeInsight() {
                        overtimeInsightCard
                    }

                    HStack {
                        Text(model.t("historyLabel"))
                            .font(FiveMinFont.ui(13, weight: .medium))
                            .foregroundStyle(FiveMinColor.muted)
                        Spacer()
                        if !rows.isEmpty {
                            Button(model.t("historyClear")) {
                                showClearConfirm = true
                            }
                            .font(FiveMinFont.ui(13, weight: .semibold))
                            .foregroundStyle(FiveMinColor.danger)
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.top, 4)

                    if sceneFilterOptions.count > 1 {
                        sceneFilterPicker
                    }

                    VStack(spacing: 0) {
                        if rows.isEmpty {
                            Text(model.t("historyEmpty"))
                                .font(FiveMinFont.ui(14))
                                .foregroundStyle(FiveMinColor.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                                .padding(.horizontal, 20)
                        } else {
                            ForEach(rows) { item in
                                historyRow(item)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(FiveMinColor.surface.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous)
                            .strokeBorder(FiveMinColor.line.opacity(0.9), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous))
                    .shadow(color: FiveMinColor.ink.opacity(0.04), radius: 8, y: 2)
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
        .onAppear(perform: reload)
        .onChange(of: model.recordsEpoch) { _, _ in reload() }
        .onChange(of: model.locale) { _, _ in reload() }
        .onChange(of: filterSceneId) { _, _ in reloadRows() }
        .alert(model.t("historyDeleteConfirm"), isPresented: deleteConfirmBinding) {
            Button(model.t("cancelLabel"), role: .cancel) {
                pendingDeleteId = nil
            }
            Button(model.t("historyDelete"), role: .destructive) {
                if let id = pendingDeleteId {
                    model.deleteHistorySession(id: id)
                }
                pendingDeleteId = nil
                reload()
            }
        }
        .alert(model.t("historyClearConfirm"), isPresented: $showClearConfirm) {
            Button(model.t("cancelLabel"), role: .cancel) {}
            Button(model.t("historyClear"), role: .destructive) {
                model.clearAllHistory()
                filterSceneId = historyFilterAll
                reload()
            }
        }
    }

    private var deleteConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteId != nil },
            set: { if !$0 { pendingDeleteId = nil } }
        )
    }

    private var sceneFilterPicker: some View {
        HStack(spacing: 8) {
            Text(model.t("historyFilterLabel"))
                .font(FiveMinFont.ui(13, weight: .medium))
                .foregroundStyle(FiveMinColor.muted)
            Picker("", selection: $filterSceneId) {
                Text(model.t("historyFilterAll")).tag(historyFilterAll)
                ForEach(sceneFilterOptions, id: \.id) { opt in
                    Text(opt.label).tag(opt.id)
                }
            }
            .pickerStyle(.menu)
            .tint(FiveMinColor.brandStrong)
        }
        .padding(.leading, 4)
    }

    private var header: some View {
        HStack {
            Text(model.t("tabRecords"))
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

    private func statCard(title: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FiveMinFont.ui(12, weight: .medium))
                .foregroundStyle(FiveMinColor.muted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(FiveMinFont.ui(28, weight: .semibold))
                    .foregroundStyle(FiveMinColor.brandStrong)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(FiveMinFont.ui(13))
                        .foregroundStyle(FiveMinColor.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FiveMinColor.brandSoft.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous)
                .strokeBorder(FiveMinColor.brand.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous))
    }

    private var overtimeInsightCard: some View {
        let stats = P0Features.readOvertimeStats()
        let line: String
        if stats.count > 0 {
            line = model.t("overtimeInsightLine", [
                "count": "\(stats.count)",
                "mins": "\(P0Features.insightMinutes(stats.ms))",
            ])
        } else {
            line = model.t("overtimeInsightEmpty")
        }
        return VStack(alignment: .leading, spacing: 8) {
            Text(model.t("overtimeInsightTitle"))
                .font(FiveMinFont.ui(15, weight: .semibold))
                .foregroundStyle(FiveMinColor.ink)
            Text(line)
                .font(FiveMinFont.ui(14))
                .foregroundStyle(FiveMinColor.ink)
            Text(model.t("overtimeInsightHint"))
                .font(FiveMinFont.ui(12))
                .foregroundStyle(FiveMinColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(FiveMinColor.warnSoft.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous)
                .strokeBorder(FiveMinColor.warn.opacity(0.16), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusCard, style: .continuous))
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        let scene = sceneName(item.sceneId)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.t("historySceneLine", ["scene": scene]))
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
                Text(model.t("historyDurationLine", ["n": "\(item.minutes)"]))
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
                Text(model.t("historyTimeLine", ["time": formatDateTime(item.at)]))
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                pendingDeleteId = item.id
            } label: {
                Text(model.t("historyDelete"))
                    .font(FiveMinFont.ui(13, weight: .semibold))
                    .foregroundStyle(FiveMinColor.danger)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func sceneName(_ sceneId: String) -> String {
        model.sceneTitle(for: sceneId) ?? model.t("historySceneDefault")
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
        let all = HistoryStore.shared.getHistory()
        var seen = Set<String>()
        var options: [(id: String, label: String)] = []
        for item in all {
            let sid = item.sceneId
            guard !sid.isEmpty, !seen.contains(sid) else { continue }
            seen.insert(sid)
            let label = sceneName(sid)
            options.append((id: sid, label: label))
        }
        options.sort { $0.label.localizedCompare($1.label) == .orderedAscending }
        sceneFilterOptions = options
        if filterSceneId != historyFilterAll, !options.contains(where: { $0.id == filterSceneId }) {
            filterSceneId = historyFilterAll
        }
        let period = HistoryStore.shared.periodStats()
        periodCount = period.count
        periodMins = period.minutes
        reloadRows()
    }

    private func reloadRows() {
        if filterSceneId == historyFilterAll {
            rows = HistoryStore.shared.getHistory()
        } else {
            rows = HistoryStore.shared.getHistory(sceneId: filterSceneId)
        }
    }
}
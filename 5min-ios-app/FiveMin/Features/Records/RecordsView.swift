import SwiftUI

private let historyFilterAll = "__all__"

struct RecordsView: View {
    @Environment(TimerViewModel.self) private var model
    @State private var rows: [HistoryItem] = []
    @State private var periodCount = 0
    @State private var periodMins = 0
    @State private var streakDays = 0
    @State private var filterSceneId = historyFilterAll
    @State private var sceneFilterOptions: [(id: String, label: String)] = []
    @State private var pendingDeleteId: Int64?
    @State private var showClearConfirm = false

    private var shareText: String {
        let values = HistoryStore.shared.shareSummaryValues()
        return model.t("shareText", [
            "count": "\(values.count)",
            "mins": "\(values.minutes)",
            "streak": "\(values.streak)",
        ])
    }

    private var exportCsvURL: URL {
        let csv = HistoryStore.shared.exportHistoryCsv(headerLine: model.t("exportCsvHeader")) { row in
            model.sceneTitle(for: row.sceneId.isEmpty ? nil : row.sceneId) ?? model.t("historySceneDefault")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("5min-history.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        statMetric(title: model.t("weekStatsCountLabel"), value: "\(periodCount)", unit: nil)
                        Divider()
                            .padding(.vertical, 12)
                        statMetric(title: model.t("weekStatsMinsLabel"), value: "\(periodMins)", unit: model.t("customUnit"))
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(FiveMinColor.brandSoft.opacity(0.55))
                    .listRowSeparator(.hidden)
                } header: {
                    sectionHeader(model.t("weekStatsLabel"))
                } footer: {
                    Text(
                        streakDays > 0
                            ? model.t("streakDays", ["n": "\(streakDays)"])
                            : model.t("streakNone")
                    )
                    .font(FiveMinFont.ui(13, weight: .medium))
                    .foregroundStyle(FiveMinColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if P0Features.getShowOvertimeInsight() {
                    Section {
                        overtimeInsightContent
                    } header: {
                        sectionHeader(model.t("overtimeInsightTitle"))
                    }
                }

                Section {
                    Picker(model.t("historyFilterLabel"), selection: $filterSceneId) {
                        Text(model.t("historyFilterAll")).tag(historyFilterAll)
                        ForEach(sceneFilterOptions, id: \.id) { opt in
                            Text(opt.label).tag(opt.id)
                        }
                    }
                    .tint(FiveMinColor.brandStrong)

                    if rows.isEmpty {
                        Text(model.t("historyEmpty"))
                            .font(FiveMinFont.ui(15))
                            .foregroundStyle(FiveMinColor.muted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(rows) { item in
                            historyRow(item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        pendingDeleteId = item.id
                                    } label: {
                                        Label(model.t("historyDelete"), systemImage: "trash")
                                    }
                                    .tint(FiveMinColor.danger)
                                }
                        }

                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Text(model.t("historyClear"))
                                .font(FiveMinFont.ui(16, weight: .medium))
                                .foregroundStyle(FiveMinColor.danger)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(FiveMinColor.danger)
                    }
                } header: {
                    sectionHeader(model.t("historyLabel"))
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
            .navigationTitle(model.t("tabRecords"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Label(model.t("shareLabel"), systemImage: "square.and.arrow.up")
                    }
                    .tint(FiveMinColor.brandStrong)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportCsvURL) {
                        Label(model.t("exportLabel"), systemImage: "square.and.arrow.down")
                    }
                    .tint(FiveMinColor.brandStrong)
                }
            }
        }
        .task(id: model.recordsEpoch) { reload() }
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

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(FiveMinFont.ui(13, weight: .medium))
            .foregroundStyle(FiveMinColor.muted)
            .textCase(nil)
    }

    private var deleteConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteId != nil },
            set: { if !$0 { pendingDeleteId = nil } }
        )
    }

    private func statMetric(title: String, value: String, unit: String?) -> some View {
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
        .padding(.horizontal, 4)
    }

    private var overtimeInsightContent: some View {
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
            Text(line)
                .font(FiveMinFont.ui(15))
                .foregroundStyle(FiveMinColor.ink)
            Text(model.t("overtimeInsightHint"))
                .font(FiveMinFont.ui(13))
                .foregroundStyle(FiveMinColor.muted)
            Text(model.t("overtimeInsightTip"))
                .font(FiveMinFont.ui(13))
                .foregroundStyle(FiveMinColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        let scene = sceneName(item.sceneId)
        return VStack(alignment: .leading, spacing: 4) {
            Text(scene)
                .font(FiveMinFont.ui(16, weight: .medium))
                .foregroundStyle(FiveMinColor.ink)
            Text("\(model.t("historyDurationLine", ["n": "\(item.minutes)"])) · \(formatDateTime(item.at))")
                .font(FiveMinFont.ui(13, weight: .medium))
                .foregroundStyle(FiveMinColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(model.t("historySceneLine", ["scene": scene])), \(model.t("historyDurationLine", ["n": "\(item.minutes)"])), \(model.t("historyTimeLine", ["time": formatDateTime(item.at)]))"
        )
        .contextMenu {
            Button(role: .destructive) {
                pendingDeleteId = item.id
            } label: {
                Label(model.t("historyDelete"), systemImage: "trash")
            }
        }
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
        periodCount = all.count
        periodMins = all.reduce(0) { $0 + $1.minutes }
        streakDays = HistoryStore.shared.streakDays(from: all)
        if filterSceneId == historyFilterAll {
            rows = all
        } else {
            rows = all.filter { $0.sceneId == filterSceneId }
        }
    }

    private func reloadRows() {
        if filterSceneId == historyFilterAll {
            rows = HistoryStore.shared.getHistory()
        } else {
            rows = HistoryStore.shared.getHistory(sceneId: filterSceneId)
        }
    }
}

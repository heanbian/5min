import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var model: TimerViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showScenes = false

    private var ringColor: Color {
        switch model.phase {
        case .warn: return FiveMinColor.warn
        case .done: return FiveMinColor.danger
        default: return FiveMinColor.brand
        }
    }

    private var timeColor: Color {
        switch model.phase {
        case .warn: return FiveMinColor.warn
        case .done: return FiveMinColor.danger
        default: return .black
        }
    }

    private var statusColor: Color {
        switch model.phase {
        case .warn: return FiveMinColor.warn
        case .done: return FiveMinColor.danger
        default: return FiveMinColor.muted
        }
    }

    private var bgColors: [Color] {
        switch model.phase {
        case .warn: return [FiveMinColor.warnSoft, FiveMinColor.warnBottom]
        case .done: return [FiveMinColor.dangerSoft, FiveMinColor.dangerBottom]
        default: return [FiveMinColor.bg, FiveMinColor.bg2, FiveMinColor.bgBottom]
        }
    }

    private var glowColor: Color {
        switch model.phase {
        case .warn: return FiveMinColor.warnGlow
        case .done: return FiveMinColor.dangerGlow
        default: return FiveMinColor.glow
        }
    }

    private var setupEnabled: Bool { !model.running }
    private var resetEnabled: Bool {
        model.running || model.remainMs < model.totalMs || model.finished
    }
    private var scenePlaceholder: Bool { model.activeSceneId == nil }

    var body: some View {
        let isRTL = model.locale.hasPrefix("ar")
        GeometryReader { geo in
            let wide = shouldUseWideLayout(size: geo.size)
            let dial = dialSize(for: geo.size, wide: wide)

            ZStack {
                LinearGradient(colors: bgColors, startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [glowColor.opacity(0.95), .clear],
                    center: UnitPoint(x: 0.5, y: -0.02),
                    startRadius: 0,
                    endRadius: min(geo.size.width, geo.size.height) * 0.95
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                Group {
                    if wide {
                        wideContent(dial: dial, size: geo.size)
                    } else {
                        compactContent(dial: dial)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.showRitual {
                    ritualOverlay
                }
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showScenes) {
            ScenePickerView()
                .environmentObject(model)
                .presentationDetents([.medium, .large])
        }
    }

    private var ritualOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .allowsHitTesting(true)

            VStack(alignment: .leading, spacing: 16) {
                let pack = model.ritualPackForActiveScene()
                let steps = pack.stepKeys
                Text(model.t(pack.titleKey))
                    .font(FiveMinFont.ui(18, weight: .semibold))
                    .foregroundStyle(FiveMinColor.ink)

                ritualStep(
                    label: model.t(steps.count > 0 ? steps[0] : "standRitualStepUp"),
                    isOn: model.ritualUp
                ) {
                    model.ritualUp.toggle()
                }
                ritualStep(
                    label: model.t(steps.count > 1 ? steps[1] : "standRitualStepStretch"),
                    isOn: model.ritualStretch
                ) {
                    model.ritualStretch.toggle()
                }
                ritualStep(
                    label: model.t(steps.count > 2 ? steps[2] : "standRitualStepLeave"),
                    isOn: model.ritualLeave
                ) {
                    model.ritualLeave.toggle()
                }

                HStack(spacing: 10) {
                    Button(model.t("standRitualSkip")) {
                        model.dismissRitual()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button(model.t("standRitualDone")) {
                        model.dismissRitual()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(
                LinearGradient(
                    colors: [FiveMinColor.brandSoft.opacity(0.45), FiveMinColor.surface],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radiusDialog, style: .continuous))
            .shadow(color: FiveMinColor.ink.opacity(0.16), radius: 20, y: 8)
            .padding(.horizontal, 28)
        }
    }

    private func ritualStep(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isOn ? FiveMinColor.brandStrong : FiveMinColor.line, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isOn ? FiveMinColor.brandSoft : Color.clear)
                        )
                        .frame(width: 24, height: 24)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(FiveMinFont.ui(12, weight: .bold))
                            .foregroundStyle(FiveMinColor.brandStrong)
                    }
                }
                Text(label)
                    .font(FiveMinFont.ui(15))
                    .foregroundStyle(FiveMinColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Prefer scene / window bounds over device idiom — required for iPhone Duo resize.
    private func shouldUseWideLayout(size: CGSize) -> Bool {
        if horizontalSizeClass == .regular { return true }
        // Unfolded / landscape / Split View: wider than tall with enough room for two columns.
        return size.width > size.height && size.width >= 560
    }

    private func dialSize(for size: CGSize, wide: Bool) -> CGFloat {
        if wide {
            let side = min(size.height * 0.62, size.width * 0.42, 320)
            return max(180, side)
        }
        let side = min(size.width - FiveMinDimens.padX * 2, size.height * 0.38, FiveMinDimens.dialSize)
        return max(160, side)
    }

    // MARK: - Compact (outer display / portrait phone)

    private func compactContent(dial: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: FiveMinDimens.sectionGap) {
                topBar
                stage(dial: dial)
                actions
            }
            .padding(.horizontal, FiveMinDimens.padX)
            .padding(.vertical, FiveMinDimens.padY)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Wide (iPhone Duo inner / landscape / Split View)

    private func wideContent(dial: CGFloat, size: CGSize) -> some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, FiveMinDimens.padX)
                .padding(.top, FiveMinDimens.padY)
                .padding(.bottom, 12)

            HStack(alignment: .center, spacing: 28) {
                stage(dial: dial)
                    .frame(maxWidth: .infinity)

                VStack(spacing: FiveMinDimens.sectionGap) {
                    actions
                }
                .frame(maxWidth: min(420, size.width * 0.46))
            }
            .padding(.horizontal, FiveMinDimens.padX)
            .padding(.bottom, FiveMinDimens.padY)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(width: 24 * 108 / 32, height: 24)
                    .accessibilityLabel("5min")
                Text(model.brandTitle)
                    .font(FiveMinFont.ui(19, weight: .semibold))
                    .foregroundStyle(FiveMinColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FiveMinDimens.topbarH)

            Button {
                model.selectedTab = 2
            } label: {
                Image(systemName: model.ambient == "off" ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(FiveMinFont.ui(17, weight: .medium))
                    .foregroundStyle(model.ambient == "off" ? FiveMinColor.muted.opacity(0.85) : FiveMinColor.muted.opacity(0.55))
                    .frame(width: FiveMinDimens.topbarH, height: FiveMinDimens.topbarH)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.t("ambientLabel"))
            .accessibilityValue(model.ambient == "off" ? model.t("soundMutedHint") : model.t("ambientLabel"))
        }
    }

    // MARK: - Stage

    private func stage(dial: CGFloat) -> some View {
        let stroke = dial * (8.5 / 120)
        return VStack(spacing: FiveMinDimens.stageGap) {
            ZStack {
                Circle()
                    .stroke(FiveMinColor.ring, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                Circle()
                    .trim(from: 0, to: model.progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: model.progress)
                DigitalWatchTime(
                    text: model.dialTimeText,
                    color: timeColor,
                    blinking: model.running
                )
                    .frame(width: dial * 0.64)
            }
            .frame(width: dial, height: dial)
            .scaleEffect(model.phase == .warn || model.phase == .done ? 1.018 : 1)
            .animation(
                (model.phase == .warn || model.phase == .done)
                    ? .easeInOut(duration: model.phase == .done ? 0.625 : 0.9).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.2),
                value: model.phase
            )
            .onTapGesture {
                if model.phase == .done { model.realert() }
            }

            VStack(spacing: 6) {
                Text(model.statusText)
                    .font(FiveMinFont.ui(14, weight: model.phase == .done ? .semibold : .medium))
                    .foregroundStyle(statusColor)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)

                statsRow
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 统计行分隔点：加粗、品牌色更醒目（· 字重几乎无效，用实心圆点）
    private var statsSepDot: some View {
        Circle()
            .fill(FiveMinColor.brandStrong)
            .frame(width: 4.5, height: 4.5)
    }

    private var statsRow: some View {
        Group {
            if model.statsCount <= 0 {
                Text("\(model.t("dailyStatsLabel")) · \(model.t("dailyStatsEmpty"))")
                    .font(FiveMinFont.ui(12, weight: .medium))
                    .foregroundStyle(FiveMinColor.muted)
            } else {
                HStack(spacing: 6) {
                    Text(model.t("dailyStatsLabel"))
                        .font(FiveMinFont.ui(12, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                    statsSepDot
                    Text("\(model.statsCount)\(model.t("dailyStatsCountUnit"))")
                        .font(FiveMinFont.ui(12, weight: .semibold))
                        .foregroundStyle(FiveMinColor.ink)
                    statsSepDot
                    Text("\(model.statsMinutes())\(model.t("dailyStatsMinutesUnit"))")
                        .font(FiveMinFont.ui(12, weight: .semibold))
                        .foregroundStyle(FiveMinColor.ink)
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: FiveMinDimens.controlGap) {
            HStack(spacing: FiveMinDimens.controlGap) {
                Button(model.startLabel) { model.toggleStart() }
                    .buttonStyle(PrimaryButtonStyle())
                Button(model.t("reset")) { model.reset() }
                    .buttonStyle(SecondaryButtonStyle(enabled: resetEnabled))
                    .disabled(!resetEnabled)
            }

            if model.canIgnoreFinish {
                Button(model.t("finishIgnore")) { model.ignoreLastSession() }
                    .buttonStyle(IgnoreButtonStyle())
                    .frame(maxWidth: .infinity)
            }

            Button {
                showScenes = true
            } label: {
                HStack {
                    Text(sceneLabel)
                        .font(FiveMinFont.ui(14, weight: .semibold))
                        .foregroundStyle(
                            !setupEnabled
                            ? FiveMinColor.muted.opacity(0.4)
                            : (scenePlaceholder ? FiveMinColor.muted : FiveMinColor.ink)
                        )
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(FiveMinFont.ui(12, weight: .semibold))
                        .foregroundStyle(FiveMinColor.muted)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: FiveMinDimens.rowH)
                .background(FiveMinColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                        .stroke(FiveMinColor.line, lineWidth: 1)
                )
            }
            .disabled(!setupEnabled)
            .opacity(setupEnabled ? 1 : 0.55)

            if !model.chipSceneIds.isEmpty {
                suggestedChips
            }
        }
    }

    private var suggestedChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.chipSceneIds, id: \.self) { id in
                    let active = id == model.activeSceneId
                    Button {
                        guard setupEnabled else { return }
                        model.selectScene(id)
                    } label: {
                        Text(model.sceneTitle(for: id) ?? id)
                            .font(FiveMinFont.ui(13, weight: .semibold))
                            .foregroundStyle(active ? Color.white : FiveMinColor.brandStrong)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(height: FiveMinDimens.suggestedChipH)
                            .background(
                                Group {
                                    if active {
                                        LinearGradient(
                                            colors: [
                                                FiveMinColor.brandLift,
                                                FiveMinColor.brand,
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    } else {
                                        FiveMinColor.surface.opacity(0.55)
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                                    .stroke(
                                        active ? Color.clear : FiveMinColor.brand.opacity(0.18),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: active ? FiveMinColor.brand.opacity(0.28) : .clear,
                                radius: active ? 6 : 0,
                                y: active ? 3 : 0
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!setupEnabled)
                    .opacity(setupEnabled ? 1 : 0.55)
                }
            }
            .padding(6)
        }
        .background(FiveMinColor.brandSoft.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                .stroke(FiveMinColor.brand.opacity(0.12), lineWidth: 1)
        )
        .accessibilityLabel(model.t(SceneRanker.labelKey))
    }

    private var sceneLabel: String {
        model.sceneLabel(for: model.activeSceneId) ?? model.t("scenePlaceholder")
    }
}

// MARK: - Scene picker

/// Suggested + catalog reuse the same scene.id; LazyVStack needs a group-scoped identity.
private struct ScenePickerRow: Identifiable {
    let id: String
    let scene: SceneDTO

    init(groupId: String, scene: SceneDTO) {
        self.id = "\(groupId):\(scene.id)"
        self.scene = scene
    }
}

struct ScenePickerView: View {
    @EnvironmentObject private var model: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FiveMinDimens.controlGap, pinnedViews: []) {
                    ForEach(model.pickerGroups) { group in
                        let items = model.scenes(inGroup: group.id)
                        if !items.isEmpty {
                            groupHeader(model.t(group.labelKey))
                                .id("hdr:\(group.id)")
                            ForEach(items.map { ScenePickerRow(groupId: group.id, scene: $0) }) { row in
                                let scene = row.scene
                                let active = scene.id == model.activeSceneId
                                Button {
                                    model.selectScene(scene.id)
                                    dismiss()
                                } label: {
                                    Text(model.sceneLabel(for: scene.id) ?? scene.id)
                                        .font(FiveMinFont.ui(14, weight: .semibold))
                                        .foregroundStyle(active ? FiveMinColor.brandStrong : FiveMinColor.muted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: FiveMinDimens.rowH)
                                        .background(
                                            RoundedRectangle(cornerRadius: FiveMinDimens.radiusSm, style: .continuous)
                                                .fill(active ? FiveMinColor.brandSoft : .clear)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(FiveMinDimens.padX)
                .onAppear { model.refreshSuggested() }
            }
            .background(FiveMinColor.surface)
            .navigationTitle(model.t("scenesLabel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.t("confirmLabel")) { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(FiveMinColor.brandStrong)
                }
            }
        }
    }

    private func groupHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(FiveMinColor.brand)
                .frame(width: 3, height: 12)
            Text(title)
                .font(FiveMinFont.ui(11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(FiveMinColor.brandStrong)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(FiveMinColor.brandSoft.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(FiveMinColor.brand.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FiveMinFont.ui(16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: FiveMinDimens.controlH, maxHeight: FiveMinDimens.controlH)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        FiveMinColor.brandLift,
                        FiveMinColor.brand,
                        FiveMinColor.brandStrong,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
            .shadow(
                color: FiveMinColor.brand.opacity(configuration.isPressed ? 0.18 : 0.32),
                radius: configuration.isPressed ? 4 : 10,
                y: configuration.isPressed ? 2 : 6
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FiveMinFont.ui(16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: FiveMinDimens.controlH, maxHeight: FiveMinDimens.controlH)
            .foregroundStyle(FiveMinColor.muted.opacity(enabled ? 1 : 0.38))
            .background(configuration.isPressed ? FiveMinColor.brandSoft : FiveMinColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                    .stroke(
                        configuration.isPressed
                            ? FiveMinColor.brand.opacity(0.35)
                            : FiveMinColor.line,
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}

/// Tertiary undo — quieter than primary/secondary, solid danger border (aligned with Android/MP).
struct IgnoreButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FiveMinFont.ui(15, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: FiveMinDimens.controlH, maxHeight: FiveMinDimens.controlH)
            .foregroundStyle(FiveMinColor.danger)
            .background(
                configuration.isPressed
                    ? FiveMinColor.dangerSoft
                    : FiveMinColor.surface.opacity(0.82)
            )
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                    .stroke(
                        FiveMinColor.danger.opacity(configuration.isPressed ? 0.55 : 0.35),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

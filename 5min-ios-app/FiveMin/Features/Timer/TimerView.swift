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
        default: return FiveMinColor.ink
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
            }
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showScenes) {
            ScenePickerView()
                .environmentObject(model)
                .presentationDetents([.medium, .large])
        }
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
                footnote
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
                    footnote
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
                    .frame(width: 22 * 108 / 32, height: 22)
                    .accessibilityLabel("5min")
                Text(model.brandTitle)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(FiveMinColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: FiveMinDimens.topbarH)

            HStack(spacing: 4) {
                Menu {
                    ambientButton("off", key: "ambientOff")
                    ambientButton("rain", key: "ambientRain")
                    ambientButton("waves", key: "ambientWaves")
                    ambientButton("clock", key: "ambientClock")
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(FiveMinColor.muted)
                        .frame(width: FiveMinDimens.topbarH, height: FiveMinDimens.topbarH)
                }
                .accessibilityLabel(model.t("ambientLabel"))

                Menu {
                    ForEach(model.catalog.localeCodes, id: \.self) { code in
                        Button {
                            model.setLocale(code)
                        } label: {
                            if code == model.locale {
                                Label(model.catalog.t(code, "nativeName"), systemImage: "checkmark")
                            } else {
                                Text(model.catalog.t(code, "nativeName"))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(model.catalog.t(model.locale, "nativeName"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(FiveMinColor.muted)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(FiveMinColor.muted)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(height: FiveMinDimens.topbarH)
                }
            }
        }
    }

    private func ambientButton(_ id: String, key: String) -> some View {
        Button {
            model.setAmbient(id)
        } label: {
            if model.ambient == id {
                Label(model.t(key), systemImage: "checkmark")
            } else {
                Text(model.t(key))
            }
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
                DigitalWatchTime(text: model.format(model.remainMs), color: timeColor)
                    .frame(width: dial * 0.64)
            }
            .frame(width: dial, height: dial)
            .onTapGesture {
                if model.finished { model.realert() }
            }

            VStack(spacing: 6) {
                Text(model.statusText)
                    .font(.system(size: 14, weight: model.phase == .done ? .semibold : .medium))
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

    private var statsRow: some View {
        Group {
            if model.statsCount <= 0 {
                Text("\(model.t("dailyStatsLabel")) · \(model.t("dailyStatsEmpty"))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FiveMinColor.muted)
            } else {
                HStack(spacing: 6) {
                    Text(model.t("dailyStatsLabel"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FiveMinColor.muted)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(FiveMinColor.muted)
                    Text("\(model.statsCount)\(model.t("dailyStatsCountUnit")) · \(model.statsMinutes())\(model.t("dailyStatsMinutesUnit"))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(FiveMinColor.ink)
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(model.startLabel) { model.toggleStart() }
                    .buttonStyle(PrimaryButtonStyle())
                Button(model.t("reset")) { model.reset() }
                    .buttonStyle(SecondaryButtonStyle(enabled: resetEnabled))
                    .disabled(!resetEnabled)
            }

            presetSegment

            Button {
                showScenes = true
            } label: {
                HStack {
                    Text(sceneLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            !setupEnabled
                            ? FiveMinColor.muted.opacity(0.4)
                            : (scenePlaceholder ? FiveMinColor.muted : FiveMinColor.ink)
                        )
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
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
        }
    }

    private var presetSegment: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.catalog.presetsMin.enumerated()), id: \.element) { index, min in
                let active = model.activeSceneId == nil && model.totalMs == Int64(min) * 60_000
                if index > 0 {
                    Rectangle()
                        .fill(FiveMinColor.line)
                        .frame(width: 1)
                }
                Button {
                    model.setPreset(minutes: min, sceneId: nil)
                } label: {
                    Text(model.t("minutes", ["n": "\(min)"]))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            !setupEnabled
                            ? FiveMinColor.muted.opacity(0.4)
                            : (active ? FiveMinColor.brandStrong : FiveMinColor.muted)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(active ? FiveMinColor.brandSoft : FiveMinColor.surface)
                }
                .disabled(!setupEnabled)
            }
        }
        .frame(height: FiveMinDimens.rowH)
        .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                .stroke(FiveMinColor.line, lineWidth: 1)
        )
    }

    private var footnote: some View {
        Text(model.t("footnote"))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(FiveMinColor.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private var sceneLabel: String {
        if let id = model.activeSceneId,
           let scene = model.catalog.scenes.first(where: { $0.id == id }) {
            return model.t(scene.labelKey)
        }
        return model.t("scenePlaceholder")
    }
}

// MARK: - Scene picker

struct ScenePickerView: View {
    @EnvironmentObject private var model: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                    ForEach(model.catalog.groups) { group in
                        let items = model.catalog.scenes.filter { $0.group == group.id }
                        if !items.isEmpty {
                            groupHeader(model.t(group.labelKey))
                            ForEach(items) { scene in
                                let active = scene.id == model.activeSceneId
                                Button {
                                    model.selectScene(scene.id)
                                    dismiss()
                                } label: {
                                    Text(model.t(scene.labelKey))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(active ? FiveMinColor.brandStrong : FiveMinColor.muted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(active ? FiveMinColor.brandSoft : .clear)
                                        )
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(FiveMinColor.surface)
            .navigationTitle(model.t("scenesLabel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
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
                .font(.system(size: 11, weight: .bold))
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
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: FiveMinDimens.controlH)
            .background(FiveMinColor.brand)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: FiveMinDimens.controlH)
            .background(configuration.isPressed ? Color(red: 0xDD / 255, green: 0xE3 / 255, blue: 0xE0 / 255) : FiveMinColor.ghostBg)
            .foregroundStyle(FiveMinColor.ghostInk.opacity(enabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FiveMinDimens.radius, style: .continuous)
                    .stroke(FiveMinColor.ghostLine, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

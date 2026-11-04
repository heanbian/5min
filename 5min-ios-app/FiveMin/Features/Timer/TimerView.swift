import SwiftUI

struct TimerView: View {
    @EnvironmentObject private var model: TimerViewModel
    @State private var showScenes = false

    private var ringColor: Color {
        switch model.phase {
        case .warn: return Color(red: 0.788, green: 0.525, blue: 0.176)
        case .done: return Color(red: 0.824, green: 0.333, blue: 0.290)
        default: return Color(red: 0.184, green: 0.604, blue: 0.408)
        }
    }

    var body: some View {
        let isRTL = model.locale.hasPrefix("ar")
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text(model.brandTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Menu {
                        Button(model.t("ambientOff")) { model.setAmbient("off") }
                        Button(model.t("ambientRain")) { model.setAmbient("rain") }
                        Button(model.t("ambientWaves")) { model.setAmbient("waves") }
                        Button(model.t("ambientClock")) { model.setAmbient("clock") }
                    } label: {
                        Image(systemName: "speaker.wave.2")
                    }
                    Menu {
                        ForEach(model.catalog.localeCodes, id: \.self) { code in
                            Button(model.catalog.t(code, "nativeName")) {
                                model.setLocale(code)
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                    }
                }

                Text(statsText)
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.373, green: 0.435, blue: 0.400))

                ZStack {
                    Circle()
                        .stroke(Color(red: 0.843, green: 0.898, blue: 0.863), lineWidth: 14)
                        .frame(width: 240, height: 240)
                    Circle()
                        .trim(from: 0, to: model.progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 240, height: 240)
                        .animation(.linear(duration: 0.2), value: model.progress)
                    Text(model.format(model.remainMs))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(ringColor)
                }
                .padding(.vertical, 8)
                .onTapGesture {
                    if model.finished { model.realert() }
                }

                Text(model.statusText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                HStack(spacing: 12) {
                    Button(model.startLabel) { model.toggleStart() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button(model.t("reset")) { model.reset() }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(!(model.running || model.remainMs < model.totalMs || model.finished))
                }

                FlowPresets(model: model)

                Button {
                    showScenes = true
                } label: {
                    HStack {
                        Text(sceneLabel)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(model.running)

                Text(model.t("footnote"))
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.373, green: 0.435, blue: 0.400))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(Color(red: 0.933, green: 0.965, blue: 0.945).ignoresSafeArea())
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .sheet(isPresented: $showScenes) {
            ScenePickerView()
                .environmentObject(model)
        }
    }

    private var statsText: String {
        if model.statsCount <= 0 {
            return "\(model.t("dailyStatsLabel")) · \(model.t("dailyStatsEmpty"))"
        }
        return "\(model.t("dailyStatsLabel")) · \(model.statsCount)\(model.t("dailyStatsCountUnit")) · \(model.statsMinutes())\(model.t("dailyStatsMinutesUnit"))"
    }

    private var sceneLabel: String {
        if let id = model.activeSceneId,
           let scene = model.catalog.scenes.first(where: { $0.id == id }) {
            return model.t(scene.labelKey)
        }
        return model.t("scenePlaceholder")
    }
}

struct FlowPresets: View {
    @ObservedObject var model: TimerViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(model.catalog.presetsMin, id: \.self) { min in
                let active = model.activeSceneId == nil && model.totalMs == Int64(min) * 60_000
                Button(model.t("minutes", ["n": "\(min)"])) {
                    model.setPreset(minutes: min, sceneId: nil)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(active ? Color(red: 0.898, green: 0.961, blue: 0.925) : Color.white)
                .foregroundStyle(Color(red: 0.141, green: 0.522, blue: 0.337))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .disabled(model.running)
            }
            Spacer()
        }
    }
}

struct ScenePickerView: View {
    @EnvironmentObject private var model: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.catalog.groups) { group in
                    let items = model.catalog.scenes.filter { $0.group == group.id }
                    if !items.isEmpty {
                        Section(model.t(group.labelKey)) {
                            ForEach(items) { scene in
                                Button {
                                    model.selectScene(scene.id)
                                    dismiss()
                                } label: {
                                    Text(model.t(scene.labelKey))
                                        .foregroundStyle(
                                            scene.id == model.activeSceneId
                                            ? Color(red: 0.141, green: 0.522, blue: 0.337)
                                            : Color(red: 0.373, green: 0.435, blue: 0.400)
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(model.t("scenesLabel"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color(red: 0.184, green: 0.604, blue: 0.408))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.white)
            .foregroundStyle(Color(red: 0.122, green: 0.165, blue: 0.141))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 0.843, green: 0.898, blue: 0.863), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

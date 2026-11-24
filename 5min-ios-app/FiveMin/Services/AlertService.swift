import AVFoundation
import UIKit

/// Finish cue: optional tone pulses + haptic pulses.
@MainActor
final class AlertService {
    static let shared = AlertService()

    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var toneTask: Task<Void, Never>?
    private var hapticTask: Task<Void, Never>?

    func play(durationMs: Int = 5000, withSound: Bool = true, withVibrate: Bool = true) {
        stop()
        if withSound {
            configureSession()
            startToneLoop(durationMs: durationMs)
        }
        if withVibrate {
            startHaptics(durationMs: durationMs)
        }
    }

    func stop() {
        toneTask?.cancel()
        toneTask = nil
        hapticTask?.cancel()
        hapticTask = nil
        stopEngine()
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func startToneLoop(durationMs: Int) {
        stopEngine()
        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
        engine.connect(node, to: engine.mainMixerNode, format: format)
        try? engine.start()
        audioEngine = engine
        player = node
        node.play()

        let end = Date().addingTimeInterval(Double(durationMs) / 1000.0)
        toneTask = Task { [weak self] in
            var high = true
            while !Task.isCancelled, Date() < end {
                self?.enqueueBeep(high: high)
                high.toggle()
                try? await Task.sleep(for: .milliseconds(620))
            }
            self?.stopEngine()
        }
    }

    private func enqueueBeep(high: Bool) {
        guard let player, let engine = audioEngine else { return }
        let sampleRate = 22_050.0
        let duration = 0.22
        let n = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: n)
        let freq: Float = high ? 783.99 : 523.25
        for i in 0..<n {
            let t = Float(i) / Float(sampleRate)
            let env = sin(Float.pi * Float(i) / Float(max(1, n)))
            samples[i] = sin(2 * Float.pi * freq * t) * 0.35 * env
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)) else { return }
        buffer.frameLength = AVAudioFrameCount(n)
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<n { channel[i] = samples[i] }
        }
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { player.play() }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func startHaptics(durationMs: Int) {
        let end = Date().addingTimeInterval(Double(durationMs) / 1000.0)
        hapticTask = Task {
            while !Task.isCancelled, Date() < end {
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.warning)
                try? await Task.sleep(for: .milliseconds(650))
            }
        }
    }

    private func stopEngine() {
        player?.stop()
        audioEngine?.stop()
        player = nil
        audioEngine = nil
    }
}

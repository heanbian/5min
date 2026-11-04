import AVFoundation
import UIKit

/// ~5s finish cue: playback session + tone pulses + haptic pulses.
final class AlertService {
    static let shared = AlertService()

    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var workItem: DispatchWorkItem?

    func play(durationMs: Int = 5000) {
        workItem?.cancel()
        configureSession()
        startToneLoop(durationMs: durationMs)
        startHaptics(durationMs: durationMs)
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
        scheduleBeep(at: Date(), until: end, high: true)
    }

    private func scheduleBeep(at date: Date, until end: Date, high: Bool) {
        guard date < end else {
            stopEngine()
            return
        }
        let item = DispatchWorkItem { [weak self] in
            self?.enqueueBeep(high: high)
            let next = Date().addingTimeInterval(0.62)
            self?.scheduleBeep(at: next, until: end, high: !high)
        }
        workItem = item
        let delay = max(0, date.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
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
        func pulse() {
            guard Date() < end else { return }
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { pulse() }
        }
        pulse()
    }

    private func stopEngine() {
        player?.stop()
        audioEngine?.stop()
        player = nil
        audioEngine = nil
    }
}

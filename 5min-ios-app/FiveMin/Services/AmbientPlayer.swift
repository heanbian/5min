import AVFoundation
import Foundation

/// Procedural ambient loops (rain / waves / clock) via AVAudioEngine — no media assets.
/// Mirrors 5min-web ambient.js / Harmony AmbientPlayer.
final class AmbientPlayer {
    static let shared = AmbientPlayer()

    static let modes = ["off", "rain", "waves", "clock"]

    private(set) var mode: String = "off"

    private let sampleRate: Double = 44_100
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    private var phase: Float = 0
    private var tickRemain: Int = 0
    private var swellGain: Float = 0.35
    private var swellTarget: Float = 0.35
    private var swellFramesLeft: Int = 0
    private var noiseState: UInt32 = 1
    private var activeRenderMode: String = "off"

    private init() {}

    func setMode(_ next: String) {
        let mode = Self.modes.contains(next) ? next : "off"
        if mode == self.mode, mode == "off" || engine != nil { return }
        stopEngine(resetMode: false)
        self.mode = mode
        guard mode != "off" else { return }
        start(mode: mode)
    }

    func stop() {
        stopEngine(resetMode: true)
    }

    /// Pause audio without clearing the selected mode (e.g. during finish alert).
    func suspend() {
        stopEngine(resetMode: false)
    }

    func resumeIfNeeded() {
        guard mode != "off" else { return }
        if engine == nil {
            start(mode: mode)
        }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func start(mode: String) {
        configureSession()
        phase = 0
        tickRemain = 0
        swellGain = 0.35
        swellTarget = 0.35
        swellFramesLeft = 0
        noiseState = 1
        activeRenderMode = mode

        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buf = abl.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            let n = Int(frameCount)
            self.render(into: buf, frames: n)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.22
        do {
            try engine.start()
            self.engine = engine
            self.sourceNode = node
        } catch {
            self.mode = "off"
            self.engine = nil
            self.sourceNode = nil
        }
    }

    private func stopEngine(resetMode: Bool) {
        activeRenderMode = "off"
        sourceNode.map { engine?.detach($0) }
        engine?.stop()
        sourceNode = nil
        engine = nil
        if resetMode { mode = "off" }
    }

    private func render(into out: UnsafeMutablePointer<Float>, frames: Int) {
        let mode = activeRenderMode
        for i in 0..<frames {
            var sample: Float = 0
            switch mode {
            case "rain":
                sample = nextNoise() * 0.22
                phase = phase * 0.92 + sample
                sample = sample - phase * 0.35
            case "waves":
                if swellFramesLeft <= 0 {
                    swellTarget = 0.12 + Float.random(in: 0...0.28)
                    swellFramesLeft = Int(sampleRate * Double(1.8 + Float.random(in: 0...1.4)))
                }
                let step = (swellTarget - swellGain) / Float(max(1, swellFramesLeft))
                swellGain += step
                swellFramesLeft -= 1
                phase = phase * 0.97 + nextNoise() * 0.03
                sample = phase * swellGain
            case "clock":
                if tickRemain <= 0 {
                    tickRemain = Int(sampleRate)
                    phase = 0
                }
                let tickAge = Int(sampleRate) - tickRemain
                let tickLen = Int(sampleRate * 0.06)
                if tickAge < tickLen {
                    let env = exp(-Float(tickAge) / Float(sampleRate * 0.012))
                    sample = sin(2 * Float.pi * 1180 * Float(tickAge) / Float(sampleRate)) * 0.18 * env
                } else {
                    sample = 0
                }
                tickRemain -= 1
            default:
                sample = 0
            }
            out[i] = max(-1, min(1, sample))
        }
    }

    /// xorshift-ish white noise in [-1, 1]
    private func nextNoise() -> Float {
        var x = noiseState
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        noiseState = x == 0 ? 1 : x
        return Float(Int32(bitPattern: noiseState & 0xffff)) / 0x8000 - 1
    }
}

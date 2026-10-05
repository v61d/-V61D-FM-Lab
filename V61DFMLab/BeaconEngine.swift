import AVFoundation
import Foundation

@MainActor
final class BeaconEngine: ObservableObject {
    enum Pattern: String, CaseIterable, Identifiable {
        case locator = "Locator"
        case dualTone = "Dual Tone"
        case chirp = "Chirp"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .locator: return "V61D Locator"
            case .dualTone: return "1000 / 500 Hz"
            case .chirp: return "200 Hz → 8 kHz"
            }
        }
    }

    @Published private(set) var isRunning = false
    @Published var pattern: Pattern = .locator
    @Published var level: Float = 0.78
    @Published private(set) var status = "جاهز"

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    func start() {
        guard !isRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let sampleRate = 48_000.0
            let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
            var phase = 0.0
            var sampleIndex: Int64 = 0
            let selectedPattern = pattern
            let selectedLevel = max(0.05, min(level, 1.0))

            let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

                for frame in 0..<Int(frameCount) {
                    let t = Double(sampleIndex) / sampleRate
                    let frequency: Double
                    let amplitude: Float

                    switch selectedPattern {
                    case .locator:
                        let cycle = t.truncatingRemainder(dividingBy: 3.0)
                        if cycle < 0.22 || (cycle >= 0.38 && cycle < 0.60) || (cycle >= 0.76 && cycle < 0.98) {
                            frequency = 1_000
                            amplitude = selectedLevel
                        } else if cycle >= 1.15 && cycle < 1.85 {
                            frequency = 520
                            amplitude = selectedLevel
                        } else {
                            frequency = 1_000
                            amplitude = 0
                        }
                    case .dualTone:
                        let cycle = t.truncatingRemainder(dividingBy: 2.5)
                        if cycle < 1.0 {
                            frequency = 1_000
                            amplitude = selectedLevel
                        } else if cycle < 2.0 {
                            frequency = 500
                            amplitude = selectedLevel
                        } else {
                            frequency = 500
                            amplitude = 0
                        }
                    case .chirp:
                        let cycle = t.truncatingRemainder(dividingBy: 2.2)
                        if cycle < 2.0 {
                            let fraction = cycle / 2.0
                            frequency = 200.0 * pow(40.0, fraction)
                            amplitude = selectedLevel * 0.72
                        } else {
                            frequency = 200
                            amplitude = 0
                        }
                    }

                    phase += (2.0 * .pi * frequency) / sampleRate
                    if phase > 2.0 * .pi { phase -= 2.0 * .pi }

                    let sine = sin(phase)
                    let shaped = tanh(2.2 * sine)
                    let value = Float(shaped) * amplitude

                    for buffer in abl {
                        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        data[frame] = value
                    }
                    sampleIndex += 1
                }
                return noErr
            }

            sourceNode = node
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.prepare()
            try engine.start()

            isRunning = true
            status = "البصمة الصوتية شغالة"
        } catch {
            stop()
            status = "تعذر تشغيل الصوت: \(error.localizedDescription)"
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        if let node = sourceNode {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
        sourceNode = nil
        isRunning = false
        status = "متوقف"
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

import SwiftUI

struct ContentView: View {
    private enum PulsePreset: String, CaseIterable, Identifiable {
        case slow = "2s / 2s"
        case medium = "1s / 1s"
        case fast = "0.5s / 0.5s"

        var id: String { rawValue }

        var on: Double {
            switch self {
            case .slow: return 2.0
            case .medium: return 1.0
            case .fast: return 0.5
            }
        }

        var off: Double { on }

        var count: Int {
            switch self {
            case .slow: return 6
            case .medium: return 8
            case .fast: return 10
            }
        }
    }

    @StateObject private var nfc = NFCLabEngine()
    @StateObject private var beacon = BeaconEngine()
    @State private var receiverMHz: Double = 13.560
    @State private var pulsePreset: PulsePreset = .slow

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.10, green: 0.02, blue: 0.16), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    pulseCard
                    nfcCard
                    shortwaveCard
                    audioCard
                    procedureCard
                    disclaimer
                }
                .padding(18)
            }
        }
        .onDisappear {
            beacon.stop()
            nfc.stop()
        }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Text("V61D SW / NFC LAB")
                .font(.system(size: 27, weight: .black, design: .rounded))
            Text("13.56 MHz pulse-channel experiment")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var pulseCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("NFC ON / OFF PULSE TRAIN", systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline)

                Picker("Timing", selection: $pulsePreset) {
                    ForEach(PulsePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(nfc.isPulseMode || nfc.isScanning)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PHASE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(nfc.pulsePhase)
                            .font(.title3.bold().monospaced())
                            .foregroundStyle(nfc.pulsePhase == "ON" ? .green : .orange)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("PULSES")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(nfc.pulseProgress)
                            .font(.title3.bold().monospaced())
                    }
                }

                Button {
                    nfc.startPulseTrain(
                        on: pulsePreset.on,
                        off: pulsePreset.off,
                        count: pulsePreset.count
                    )
                } label: {
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text("START \(pulsePreset.rawValue) PATTERN")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!nfc.isAvailable || nfc.isScanning || nfc.isPulseMode)

                if nfc.isPulseMode {
                    Button(role: .destructive) {
                        nfc.stop()
                    } label: {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("STOP PATTERN")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Text("المفروض تسمع: طقطقة أثناء ON → سكون أثناء OFF → طقطقة → سكون. إذا اتبع المسجل الإيقاع نفسه، فلدينا قناة تحكم برمجية فعلية.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nfcCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("اختبار NFC اليدوي", systemImage: "wave.3.right.circle.fill")
                    .font(.headline)

                HStack {
                    Text("Core NFC")
                    Spacer()
                    Text(nfc.isAvailable ? "AVAILABLE" : "UNAVAILABLE")
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(nfc.isAvailable ? .green : .red)
                }

                Button {
                    nfc.startBurst(seconds: 6)
                } label: {
                    HStack {
                        Image(systemName: "bolt.horizontal.circle.fill")
                        Text("NFC BURST — 6 SEC")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!nfc.isAvailable || nfc.isScanning || nfc.isPulseMode)

                Button {
                    nfc.startContinuous()
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("START CONTINUOUS READER")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!nfc.isAvailable || nfc.isScanning || nfc.isPulseMode)

                Text(nfc.status)
                    .font(.caption)
                    .foregroundStyle((nfc.isScanning || nfc.isPulseMode) ? .green : .secondary)

                Text("آخر حدث: \(nfc.lastEvent)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortwaveCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("مساعد ضبط SW", systemImage: "radio")
                    .font(.headline)

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.3f", receiverMHz))
                        .font(.system(size: 39, weight: .bold, design: .monospaced))
                    Text("MHz")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $receiverMHz, in: 9.500...18.135, step: 0.005)

                HStack {
                    Button("− 5 kHz") {
                        receiverMHz = max(9.500, receiverMHz - 0.005)
                    }
                    Spacer()
                    Button("13.560") {
                        receiverMHz = 13.560
                    }
                    Spacer()
                    Button("+ 5 kHz") {
                        receiverMHz = min(18.135, receiverMHz + 0.005)
                    }
                }
                .buttonStyle(.bordered)

                Text("خلّه على 13.560 MHz أولاً. إذا كان الالتقاط أقوى بجانبها، جرّب ±5 kHz.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audioCard: some View {
        card {
            VStack(alignment: .leading, spacing: 13) {
                Label("اختبار صوتي ثانوي", systemImage: "waveform")
                    .font(.headline)

                Picker("Pattern", selection: $beacon.pattern) {
                    ForEach(BeaconEngine.Pattern.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(beacon.isRunning)

                Button {
                    beacon.isRunning ? beacon.stop() : beacon.start()
                } label: {
                    HStack {
                        Image(systemName: beacon.isRunning ? "stop.fill" : "play.fill")
                        Text(beacon.isRunning ? "STOP AUDIO" : "START AUDIO BEACON")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(nfc.isScanning || nfc.isPulseMode)

                Text("هذا الصوت ليس مُضمّنًا على NFC؛ للاختبار المقارن فقط.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var procedureCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("الاختبار الحاسم", systemImage: "checklist")
                    .font(.headline)

                Text("1. اضبط المسجل على SW2 / 13.560 MHz.")
                Text("2. قرّب أعلى الآيفون للمسجل مثل التجربة التي نجحت معك.")
                Text("3. ابدأ بنمط 2s / 2s.")
                Text("4. المفروض تسمع طقطقة قرابة ثانيتين ثم سكون قرابة ثانيتين، وتتكرر.")
                Text("5. إذا نجح، جرّب 1s / 1s ثم 0.5s / 0.5s.")

                Text("إذا 2/2 ينجح و0.5/0.5 يفشل، فالحد غالبًا من زمن فتح/إغلاق جلسة Core NFC في iOS، وليس من مستقبل SW نفسه.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .font(.subheadline)
        }
    }

    private var disclaimer: some View {
        Text("هذه النسخة تتحكم بتشغيل وإيقاف جلسات NFC، وليست تحكمًا خامًا بموجة 13.56 MHz. iOS قد يفرض تأخيرًا بين الجلسات، لذلك الزمن الفعلي قد يختلف قليلًا عن الرقم المختار.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.bottom, 24)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.purple.opacity(0.28), lineWidth: 1)
            )
    }
}

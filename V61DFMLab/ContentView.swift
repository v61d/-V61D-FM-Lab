import SwiftUI

struct ContentView: View {
    private enum TonePreset: Double, CaseIterable, Identifiable {
        case hz25 = 25
        case hz50 = 50
        case hz100 = 100
        case hz200 = 200

        var id: Double { rawValue }
        var label: String { "\(Int(rawValue)) Hz" }
    }

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
    @State private var tonePreset: TonePreset = .hz50

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
                    toneCard
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
            Text("13.56 MHz tone experiment")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var toneCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("RF TONE — بدل الطقطقة", systemImage: "speaker.wave.3.fill")
                    .font(.headline)

                Text("هذه التجربة تُبقي جلسة NFC مفتوحة وتستدعي restartPolling بسرعة ثابتة. إذا كل restart يولّد تغيرًا يلتقطه المسجل، المفروض الطقات تندمج إلى أزيز/نغمة لها Pitch واضح.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Tone", selection: $tonePreset) {
                    ForEach(TonePreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(nfc.isScanning || nfc.isPulseMode || nfc.isToneMode)

                Button {
                    nfc.startRestartTone(rateHz: tonePreset.rawValue, duration: 8)
                } label: {
                    HStack {
                        Image(systemName: "waveform")
                        Text("START \(tonePreset.label) RF TONE")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!nfc.isAvailable || nfc.isScanning || nfc.isPulseMode || nfc.isToneMode)

                if nfc.isToneMode {
                    HStack {
                        Text("RATE")
                            .foregroundStyle(.secondary)
                        Text("\(Int(nfc.toneRateHz)) Hz")
                            .font(.headline.monospaced())
                        Spacer()
                        Text("× \(nfc.toneTicks)")
                            .font(.caption.monospaced())
                    }

                    Button(role: .destructive) {
                        nfc.stop()
                    } label: {
                        Text("STOP RF TONE")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Text("ابدأ بـ50 Hz، ثم 100 Hz، ثم 200 Hz. إذا تغير ارتفاع الأزيز مع الرقم فهذه أول خطوة نحو صوت RF فعلي، مو مجرد ON/OFF بطيء.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
                .disabled(nfc.isPulseMode || nfc.isScanning || nfc.isToneMode)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PHASE")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(nfc.pulsePhase)
                            .font(.title3.bold().monospaced())
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
                    Text("START \(pulsePreset.rawValue) PATTERN")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!nfc.isAvailable || nfc.isScanning || nfc.isPulseMode || nfc.isToneMode)
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
                    Text("NFC BURST — 6 SEC")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!nfc.isAvailable || nfc.isScanning || nfc.isPulseMode || nfc.isToneMode)

                Text(nfc.status)
                    .font(.caption)
                    .foregroundStyle((nfc.isScanning || nfc.isPulseMode || nfc.isToneMode) ? .green : .secondary)

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
                    Button("− 5 kHz") { receiverMHz = max(9.500, receiverMHz - 0.005) }
                    Spacer()
                    Button("13.560") { receiverMHz = 13.560 }
                    Spacer()
                    Button("+ 5 kHz") { receiverMHz = min(18.135, receiverMHz + 0.005) }
                }
                .buttonStyle(.bordered)

                Text("ابدأ على 13.560 MHz، ونفس مكان الآيفون الذي أعطاك الطقطقة المستمرة.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var audioCard: some View {
        card {
            VStack(alignment: .leading, spacing: 13) {
                Label("صوت سماعة الآيفون للمقارنة", systemImage: "waveform")
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
                    Text(beacon.isRunning ? "STOP AUDIO" : "START AUDIO BEACON")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(nfc.isScanning || nfc.isPulseMode || nfc.isToneMode)
            }
        }
    }

    private var procedureCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("وش نبي نسمع؟", systemImage: "ear")
                    .font(.headline)

                Text("1. SW2 = 13.560 MHz.")
                Text("2. نفس موضع الجوال اللي نجحت فيه التجربة السابقة.")
                Text("3. شغّل 50 Hz لمدة 8 ثوانٍ.")
                Text("4. بعدها 100 Hz ثم 200 Hz.")
                Text("5. النجاح = الأزيز/النغمة ترتفع بوضوح كلما رفعت Hz.")

                Text("إذا كلها تطلع نفس الطقطقة بدون اختلاف في Pitch، فـ Core NFC لا يعطينا سرعة/تحكم كافيين لتحويلها لصوت. إذا تغير الـPitch، ننتقل بعدها مباشرة لتجربة Melody ثم low-fi audio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .font(.subheadline)
        }
    }

    private var disclaimer: some View {
        Text("هذا لا يرسل ملف صوت بعد. هو اختبار لمعرفة هل restartPolling داخل جلسة NFC واحدة يقدر يصنع ترددًا صوتيًا قابلًا للسماع على مستقبل SW. iOS ما يزال يتحكم بالموجة RF نفسها.")
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

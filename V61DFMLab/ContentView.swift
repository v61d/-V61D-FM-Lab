import SwiftUI

struct ContentView: View {
    @StateObject private var beacon = BeaconEngine()
    @State private var receiverMHz: Double = 87.5
    @State private var showPulse = false

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
                    beaconCard
                    scanCard
                    experimentCard
                    disclaimer
                }
                .padding(18)
            }
        }
        .onDisappear { beacon.stop() }
    }

    private var header: some View {
        VStack(spacing: 7) {
            Text("V61D FM LAB")
                .font(.system(size: 28, weight: .black, design: .rounded))
            Text("Experimental iPhone RF / audio beacon")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var beaconCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("البصمة الصوتية", systemImage: "waveform")
                    .font(.headline)

                Picker("Pattern", selection: $beacon.pattern) {
                    ForEach(BeaconEngine.Pattern.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(beacon.isRunning)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("القوة")
                        Spacer()
                        Text("\(Int(beacon.level * 100))%")
                            .monospacedDigit()
                    }
                    Slider(value: $beacon.level, in: 0.15...1.0)
                        .disabled(beacon.isRunning)
                }

                Button {
                    beacon.isRunning ? beacon.stop() : beacon.start()
                } label: {
                    HStack {
                        Image(systemName: beacon.isRunning ? "stop.fill" : "play.fill")
                        Text(beacon.isRunning ? "STOP BEACON" : "START BEACON")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(beacon.isRunning ? .red : .purple)

                Text(beacon.status)
                    .font(.caption)
                    .foregroundStyle(beacon.isRunning ? .green : .secondary)
            }
        }
    }

    private var scanCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("مساعد مسح الراديو", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)

                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.1f", receiverMHz))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                    Text("MHz")
                        .foregroundStyle(.secondary)
                }

                Slider(value: $receiverMHz, in: 87.5...108.0, step: 0.1)

                HStack {
                    Button("− 0.1") { receiverMHz = max(87.5, receiverMHz - 0.1) }
                    Spacer()
                    Button("+ 0.1") { receiverMHz = min(108.0, receiverMHz + 0.1) }
                }
                .buttonStyle(.bordered)

                Text("هذا الرقم لتسجيل التردد الذي تفحصه في مسجل السيارة فقط؛ التطبيق لا يضبط تردد إرسال FM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var experimentCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Screen activity test", systemImage: "display")
                    .font(.headline)

                Toggle("نبض الشاشة أثناء الاختبار", isOn: $showPulse)

                if showPulse {
                    TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
                        let tick = Int(timeline.date.timeIntervalSinceReferenceDate * 120)
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tick.isMultiple(of: 2) ? Color.white : Color.black)
                            .frame(height: 85)
                            .overlay(
                                Text("DISPLAY PULSE")
                                    .font(.caption.bold())
                                    .foregroundStyle(tick.isMultiple(of: 2) ? .black : .white)
                            )
                    }
                }

                Text("اختبار إضافي فقط لزيادة النشاط الكهربائي داخل الهاتف. لا يعني أن الشاشة مرسل FM.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disclaimer: some View {
        Text("تنبيه: iPhone لا يوفر API رسميًا لإرسال FM. هذا تطبيق مختبر لاختبار أي انبعاثات جانبية قابلة للالتقاط، وقد لا يظهر أي شيء على راديو السيارة. أوقف الاختبار إذا ارتفعت حرارة الجهاز بشكل ملحوظ.")
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

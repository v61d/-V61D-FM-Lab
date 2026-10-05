import SwiftUI

struct ContentView: View {
    @StateObject private var nfc = NFCLabEngine()
    @StateObject private var beacon = BeaconEngine()
    @State private var receiverMHz: Double = 13.560

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
            Text("13.56 MHz near-field experiment")
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var nfcCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("اختبار مجال NFC — 13.56 MHz", systemImage: "wave.3.right.circle.fill")
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
                    .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!nfc.isAvailable || nfc.isScanning)

                Button {
                    nfc.startContinuous()
                } label: {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("START NFC READER")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!nfc.isAvailable || nfc.isScanning)

                Text(nfc.status)
                    .font(.caption)
                    .foregroundStyle(nfc.isScanning ? .green : .secondary)

                Text("آخر حدث: \(nfc.lastEvent)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)

                Text("iOS هو الذي يتحكم بالمجال والتوقيت فعليًا. هذا الزر يطلب NFC Reader Mode؛ التطبيق لا يملك تحكمًا خامًا بالحامل أو التضمين.")
                    .font(.caption)
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

                Text("ابدأ من 13.560 MHz. الرقم هنا دفتر ضبط فقط؛ التطبيق لا يغيّر تردد NFC نفسه.")
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
                .disabled(nfc.isScanning)

                Text("هذا الصوت ليس مُضمّنًا على NFC. أبقيناه فقط للمقارنة مع أي تداخل كهربائي آخر.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var procedureCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("طريقة الاختبار", systemImage: "checklist")
                    .font(.headline)

                Text("1. اضبط المسجل على SW2 ثم 13.560 MHz.")
                Text("2. ارفع الصوت إلى مستوى متوسط وابحث حول 13.555–13.565 إذا لزم.")
                Text("3. قرّب أعلى الآيفون جدًا من واجهة المسجل أو مسار هوائي الراديو.")
                Text("4. اضغط NFC BURST وانتظر حتى تصبح الجلسة Active.")
                Text("5. كررها 3 مرات. النجاح الأولي = طقطقة/أزيز يظهر عند التشغيل ويختفي بعد انتهاء النبضة.")

                Text("لو ظهر نفس الأثر كل مرة، نكون أثبتنا مسار التقاط حقيقي من نشاط NFC إلى مستقبل SW. الخطوة التالية وقتها تكون دراسة ترميز نبضات، وليس افتراض نقل أغنية مباشرة.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .font(.subheadline)
        }
    }

    private var disclaimer: some View {
        Text("هذه تجربة استقبال قريب المدى. NFC يعمل عند 13.56 MHz كمجال قريب وiOS لا يوفّر API لتضمين صوت AM/FM خام عليه. قد لا يسمع المسجل أي شيء حتى والجلسة نشطة. لا تختبر أثناء القيادة.")
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

import Combine
import CoreNFC
import Foundation

final class NFCLabEngine: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published private(set) var isScanning = false
    @Published private(set) var status = "جاهز لاختبار NFC"
    @Published private(set) var lastEvent = "—"

    private var session: NFCNDEFReaderSession?
    private var autoStopWorkItem: DispatchWorkItem?

    var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func startContinuous() {
        start(autoStopAfter: nil)
    }

    func startBurst(seconds: TimeInterval = 6.0) {
        start(autoStopAfter: seconds)
    }

    func stop() {
        autoStopWorkItem?.cancel()
        autoStopWorkItem = nil

        guard let currentSession = session else {
            isScanning = false
            status = "متوقف"
            return
        }

        status = "إيقاف جلسة NFC…"
        currentSession.invalidate()
        session = nil
        isScanning = false
    }

    private func start(autoStopAfter seconds: TimeInterval?) {
        guard NFCNDEFReaderSession.readingAvailable else {
            status = "NFC Reader غير متاح على هذا الجهاز"
            return
        }

        guard session == nil else {
            status = "جلسة NFC شغالة بالفعل"
            return
        }

        autoStopWorkItem?.cancel()

        let newSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        newSession.alertMessage = "V61D SW/NFC Lab — قرّب أعلى الآيفون من المسجل واضبط SW على 13.560 MHz."
        session = newSession
        isScanning = true
        status = "بدء NFC Reader Mode…"
        lastEvent = "طلب تشغيل المجال"
        newSession.begin()

        if let seconds = seconds {
            let work = DispatchWorkItem { [weak self, weak newSession] in
                guard let self = self, let activeSession = newSession else { return }
                DispatchQueue.main.async {
                    guard self.session === activeSession else { return }
                    self.status = "انتهت نبضة NFC بعد \(Int(seconds)) ثوانٍ"
                    activeSession.invalidate()
                    self.session = nil
                    self.isScanning = false
                }
            }
            autoStopWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.session === session else { return }
            self.isScanning = true
            self.status = "NFC Reader نشط — راقب 13.560 MHz"
            self.lastEvent = "الجلسة أصبحت نشطة"
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastEvent = "تم رصد NDEF (\(messages.count))"
            self.status = "تم رصد Tag — الاختبار مستمر"
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.autoStopWorkItem?.cancel()
            self.autoStopWorkItem = nil
            if self.session === session {
                self.session = nil
            }
            self.isScanning = false

            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    self.status = "تم إيقاف/إلغاء جلسة NFC"
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.status = "انتهت مهلة جلسة NFC — أعد التشغيل"
                default:
                    self.status = "انتهت جلسة NFC: \(nfcError.localizedDescription)"
                }
            } else {
                self.status = "انتهت جلسة NFC: \(error.localizedDescription)"
            }
        }
    }
}

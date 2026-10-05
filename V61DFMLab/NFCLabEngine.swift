import Combine
import CoreNFC
import Foundation

final class NFCLabEngine: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published private(set) var isScanning = false
    @Published private(set) var isPulseMode = false
    @Published private(set) var status = "جاهز لاختبار NFC"
    @Published private(set) var lastEvent = "—"
    @Published private(set) var pulsePhase = "IDLE"
    @Published private(set) var pulseProgress = "—"

    private var session: NFCNDEFReaderSession?
    private var autoStopWorkItem: DispatchWorkItem?
    private var nextPulseWorkItem: DispatchWorkItem?

    private var pulseOn: TimeInterval = 2.0
    private var pulseOff: TimeInterval = 2.0
    private var pulseCount = 0
    private var currentPulse = 0
    private var plannedPulseInvalidation = false

    var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    func startContinuous() {
        guard !isPulseMode else { return }
        startStandaloneSession(autoStopAfter: nil)
    }

    func startBurst(seconds: TimeInterval = 6.0) {
        guard !isPulseMode else { return }
        startStandaloneSession(autoStopAfter: seconds)
    }

    func startPulseTrain(on: TimeInterval, off: TimeInterval, count: Int) {
        guard NFCNDEFReaderSession.readingAvailable else {
            status = "NFC Reader غير متاح على هذا الجهاز"
            return
        }
        guard session == nil, !isPulseMode else {
            status = "أوقف جلسة NFC الحالية أولاً"
            return
        }

        autoStopWorkItem?.cancel()
        nextPulseWorkItem?.cancel()

        pulseOn = max(0.35, on)
        pulseOff = max(0.35, off)
        pulseCount = max(1, count)
        currentPulse = 0
        plannedPulseInvalidation = false
        isPulseMode = true
        pulsePhase = "READY"
        pulseProgress = "0 / \(pulseCount)"
        status = "تجهيز نمط ON/OFF…"

        beginNextPulse()
    }

    func stop() {
        autoStopWorkItem?.cancel()
        autoStopWorkItem = nil
        nextPulseWorkItem?.cancel()
        nextPulseWorkItem = nil

        isPulseMode = false
        plannedPulseInvalidation = false
        pulsePhase = "STOPPED"

        if let currentSession = session {
            status = "إيقاف جلسة NFC…"
            currentSession.invalidate()
            session = nil
        } else {
            status = "متوقف"
        }
        isScanning = false
    }

    private func makeSession() -> NFCNDEFReaderSession {
        let newSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        newSession.alertMessage = "V61D SW/NFC Lab — اضبط المسجل على 13.560 MHz وقرّب أعلى الآيفون من المسجل."
        return newSession
    }

    private func startStandaloneSession(autoStopAfter seconds: TimeInterval?) {
        guard NFCNDEFReaderSession.readingAvailable else {
            status = "NFC Reader غير متاح على هذا الجهاز"
            return
        }
        guard session == nil else {
            status = "جلسة NFC شغالة بالفعل"
            return
        }

        autoStopWorkItem?.cancel()

        let newSession = makeSession()
        session = newSession
        isScanning = true
        pulsePhase = "MANUAL"
        status = "بدء NFC Reader Mode…"
        lastEvent = "طلب تشغيل المجال"
        newSession.begin()

        if let seconds = seconds {
            let work = DispatchWorkItem { [weak self, weak newSession] in
                guard let self = self, let activeSession = newSession else { return }
                DispatchQueue.main.async {
                    guard self.session === activeSession else { return }
                    self.status = "انتهت نبضة NFC بعد \(String(format: "%.1f", seconds)) ثانية"
                    activeSession.invalidate()
                    self.session = nil
                    self.isScanning = false
                }
            }
            autoStopWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
    }

    private func beginNextPulse() {
        guard isPulseMode else { return }

        if currentPulse >= pulseCount {
            finishPulseTrain()
            return
        }

        currentPulse += 1
        plannedPulseInvalidation = false
        pulsePhase = "STARTING"
        pulseProgress = "\(currentPulse) / \(pulseCount)"
        status = "تشغيل نبضة NFC رقم \(currentPulse)…"

        let newSession = makeSession()
        session = newSession
        isScanning = true
        newSession.begin()
    }

    private func schedulePulseEnd(for activeSession: NFCNDEFReaderSession) {
        autoStopWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self, weak activeSession] in
            guard let self = self, let activeSession = activeSession else { return }
            DispatchQueue.main.async {
                guard self.isPulseMode, self.session === activeSession else { return }

                self.plannedPulseInvalidation = true
                self.pulsePhase = "OFF"
                self.status = "OFF — سكون \(String(format: "%.2f", self.pulseOff)) ثانية"
                self.lastEvent = "Pulse \(self.currentPulse): OFF"
                activeSession.invalidate()
            }
        }

        autoStopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pulseOn, execute: work)
    }

    private func scheduleNextPulseOrFinish() {
        nextPulseWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.isPulseMode else { return }
                if self.currentPulse >= self.pulseCount {
                    self.finishPulseTrain()
                } else {
                    self.beginNextPulse()
                }
            }
        }

        nextPulseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + pulseOff, execute: work)
    }

    private func finishPulseTrain() {
        autoStopWorkItem?.cancel()
        nextPulseWorkItem?.cancel()
        autoStopWorkItem = nil
        nextPulseWorkItem = nil

        isPulseMode = false
        isScanning = false
        plannedPulseInvalidation = false
        pulsePhase = "DONE"
        pulseProgress = "\(currentPulse) / \(pulseCount)"
        status = "اكتمل نمط ON/OFF"
        lastEvent = "Pulse train completed"
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.session === session else { return }

            self.isScanning = true

            if self.isPulseMode {
                self.pulsePhase = "ON"
                self.status = "ON — نبضة \(self.currentPulse)/\(self.pulseCount) لمدة \(String(format: "%.2f", self.pulseOn)) ثانية"
                self.lastEvent = "Pulse \(self.currentPulse): ON"
                self.schedulePulseEnd(for: session)
            } else {
                self.status = "NFC Reader نشط — راقب 13.560 MHz"
                self.lastEvent = "الجلسة أصبحت نشطة"
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastEvent = "تم رصد NDEF (\(messages.count))"
            if !self.isPulseMode {
                self.status = "تم رصد Tag — الاختبار مستمر"
            }
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

            if self.isPulseMode && self.plannedPulseInvalidation {
                self.plannedPulseInvalidation = false
                self.pulsePhase = "OFF"
                self.scheduleNextPulseOrFinish()
                return
            }

            if self.isPulseMode {
                self.isPulseMode = false
                self.nextPulseWorkItem?.cancel()
                self.nextPulseWorkItem = nil
                self.pulsePhase = "ERROR"
            }

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

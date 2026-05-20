import AVFoundation
import Foundation
import OSLog
import UIKit

// MARK: - HandPoseCameraSession
//
// Лёгкая обёртка над `AVCaptureSession` для front-camera. Возвращает
// CVPixelBuffer'ы во внешний callback, который вызывает `HandPoseWorker`.
//
// Отделено от FingerPlayInteractor, чтобы можно было модульно мокать в тестах.

@MainActor
final class HandPoseCameraSession: NSObject {

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "ru.happyspeech.fingerplay.camera")
    private let logger = Logger(subsystem: "ru.happyspeech", category: "FingerPlay.Camera")

    /// Callback вызывается из background-очереди.
    var onPixelBuffer: (@Sendable (CVPixelBuffer) -> Void)?

    var captureSession: AVCaptureSession { session }

    // MARK: - Public

    /// Запускает захват. Возвращает успех — false, если фронтальной камеры нет
    /// или нет разрешения.
    func start() -> Bool {
        guard configureIfNeeded() else { return false }
        if !session.isRunning {
            // Apple допускает старт из main, но рекомендует background.
            let captureSession = session
            sampleQueue.async {
                captureSession.startRunning()
            }
        }
        return true
    }

    func stop() {
        let captureSession = session
        sampleQueue.async {
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }

    // MARK: - Private

    private var didConfigure = false

    private func configureIfNeeded() -> Bool {
        guard !didConfigure else { return true }
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            didConfigure = true
        }
        session.sessionPreset = .vga640x480
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            logger.error("Front camera not available.")
            return false
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return false }
            session.addInput(input)

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self, queue: sampleQueue)
            guard session.canAddOutput(videoOutput) else { return false }
            session.addOutput(videoOutput)
            return true
        } catch {
            logger.error("Camera input failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension HandPoseCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // CVPixelBuffer — CF-тип, не Sendable; обёртка через nonisolated(unsafe).
        nonisolated(unsafe) let buffer = pixelBuffer
        Task { @MainActor [weak self] in
            self?.onPixelBuffer?(buffer)
        }
    }
}

// MARK: - Sendable

// AVCaptureSession и AVCaptureVideoDataOutput — Apple-types, не Sendable
// по умолчанию. Mark as @unchecked Sendable безопасно, потому что вся работа
// делегирована на sampleQueue и main-actor (доступ к session.start / stop).
extension HandPoseCameraSession: @unchecked Sendable {}

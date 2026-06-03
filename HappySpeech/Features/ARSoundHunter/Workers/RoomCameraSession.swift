@preconcurrency import AVFoundation
import Foundation
import OSLog
import UIKit

// MARK: - RoomCameraSession
//
// Лёгкая обёртка над `AVCaptureSession` для ЗАДНЕЙ (wide-angle) камеры — ребёнок
// «охотится» за предметами в комнате. Кадры (CVPixelBuffer) отдаются во внешний
// callback с прореживанием до ~3 fps (Vision-классификация дорогая, чаще не нужно).
//
// COPPA: кадры обрабатываются строго on-device (Apple Vision), никуда не
// передаются и не сохраняются.

@MainActor
final class RoomCameraSession: NSObject {

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "ru.happyspeech.soundhunter.camera")
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ARSoundHunter.Camera")

    /// Прореживание: классифицируем каждый N-й кадр.
    private let frameStride = 10
    private var frameCounter = 0

    /// Callback вызывается из background-очереди (CVPixelBuffer не Sendable —
    /// оборачивается через nonisolated(unsafe) и сразу прокидывается на main).
    var onPixelBuffer: (@Sendable (CVPixelBuffer) -> Void)?

    var captureSession: AVCaptureSession { session }

    private var didConfigure = false

    // MARK: - Public

    /// Запускает захват. Возвращает `false`, если задней камеры нет или нет
    /// доступа — вызывающая сторона уходит в фоллбэк-режим фото-карточек.
    func start() -> Bool {
        guard configureIfNeeded() else { return false }
        if !session.isRunning {
            let captureSession = session
            sampleQueue.async { captureSession.startRunning() }
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
                                                   position: .back) else {
            logger.error("Back camera not available.")
            return false
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return false }
            session.addInput(input)

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
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

extension RoomCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        nonisolated(unsafe) let buffer = pixelBuffer
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.frameCounter &+= 1
            guard self.frameCounter % self.frameStride == 0 else { return }
            self.onPixelBuffer?(buffer)
        }
    }
}

// MARK: - Sendable
//
// AVCaptureSession / AVCaptureVideoDataOutput — Apple-типы, не Sendable. Доступ к
// session делегирован на sampleQueue + main-actor — @unchecked Sendable безопасно.
extension RoomCameraSession: @unchecked Sendable {}

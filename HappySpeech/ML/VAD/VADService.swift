import Foundation
import AVFoundation
import OSLog
import Accelerate

// MARK: - VADService Protocol

public protocol VADService: Sendable {
    var isActive: Bool { get }
    func isSpeech(buffer: AVAudioPCMBuffer) -> Bool
    func detectFatigue(amplitudeHistory: [Float]) -> FatigueLevel
}

// MARK: - LiveVADService

/// Energy-threshold VAD with adaptive baseline.
/// Uses Accelerate for RMS calculation on audio PCM buffers.
public final class LiveVADService: VADService, @unchecked Sendable {

    nonisolated(unsafe) private var _isActive: Bool = false
    nonisolated(unsafe) private var energyBaseline: Float = 0.01
    private let speechThreshold: Float = 0.02
    private let silenceFrames: Int = 30
    nonisolated(unsafe) private var consecutiveSilenceCount: Int = 0

    public var isActive: Bool { _isActive }

    public init() {}

    public func isSpeech(buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }
        let frameCount = Int(buffer.frameLength)
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
        let energy = rms
        // Update adaptive baseline slowly
        energyBaseline = 0.95 * energyBaseline + 0.05 * min(energy, speechThreshold)
        let threshold = energyBaseline * 2.5 + speechThreshold
        let speech = energy > threshold
        if speech {
            consecutiveSilenceCount = 0
            _isActive = true
        } else {
            consecutiveSilenceCount += 1
            if consecutiveSilenceCount > silenceFrames {
                _isActive = false
            }
        }
        return speech
    }

    /// Detect fatigue from amplitude variance over recent history.
    /// Low variance + low amplitude = tired child.
    public func detectFatigue(amplitudeHistory: [Float]) -> FatigueLevel {
        guard amplitudeHistory.count >= 10 else { return .normal }
        let mean = amplitudeHistory.reduce(0, +) / Float(amplitudeHistory.count)
        let variance = amplitudeHistory.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(amplitudeHistory.count)
        switch (mean, variance) {
        case (0..<0.05, _):       return .tired
        case (_, 0..<0.002):      return .tired
        case (0.05..<0.15, _):    return .normal
        default:                  return .fresh
        }
    }
}

// MARK: - MockVADService

public final class MockVADService: VADService, @unchecked Sendable {
    public var isActive: Bool = false
    public init() {}
    public func isSpeech(buffer: AVAudioPCMBuffer) -> Bool { true }
    public func detectFatigue(amplitudeHistory: [Float]) -> FatigueLevel { .normal }
}

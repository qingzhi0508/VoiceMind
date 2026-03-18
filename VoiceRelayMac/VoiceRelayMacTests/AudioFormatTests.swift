import XCTest
import AVFoundation
@testable import VoiceRelayMac

final class AudioFormatTests: XCTestCase {

    func testInt16ToFloat32Conversion() {
        // Given - Create sample Int16 PCM data
        let samples: [Int16] = [0, Int16.max, Int16.min, Int16.max / 2]
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size)

        // When - Convert to Float32
        let floatSamples = convertInt16ToFloat32(data)

        // Then - Verify conversion
        XCTAssertEqual(floatSamples.count, samples.count)
        XCTAssertEqual(floatSamples[0], 0.0, accuracy: 0.001)
        XCTAssertEqual(floatSamples[1], 1.0, accuracy: 0.001)
        XCTAssertEqual(floatSamples[2], -1.0, accuracy: 0.001)
        XCTAssertEqual(floatSamples[3], 0.5, accuracy: 0.001)
    }

    func testAudioBufferCreation() {
        // Given
        let sampleRate: Double = 16000
        let channels: AVAudioChannelCount = 1
        let frameCount: AVAudioFrameCount = 1024

        // When
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: false
        ) else {
            XCTFail("Failed to create audio format")
            return
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            XCTFail("Failed to create audio buffer")
            return
        }

        // Then
        XCTAssertEqual(buffer.format.sampleRate, sampleRate)
        XCTAssertEqual(buffer.format.channelCount, channels)
        XCTAssertEqual(buffer.frameCapacity, frameCount)
    }

    func testEmptyDataConversion() {
        // Given
        let emptyData = Data()

        // When
        let floatSamples = convertInt16ToFloat32(emptyData)

        // Then
        XCTAssertTrue(floatSamples.isEmpty)
    }

    // Helper function
    private func convertInt16ToFloat32(_ data: Data) -> [Float] {
        let int16Array = data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Int16>(
                start: $0.baseAddress?.assumingMemoryBound(to: Int16.self),
                count: data.count / 2
            ))
        }

        return int16Array.map { Float($0) / Float(Int16.max) }
    }
}

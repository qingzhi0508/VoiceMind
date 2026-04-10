import XCTest
@testable import VoiceMind

@MainActor
final class SherpaOnnxRuntimeSupportTests: XCTestCase {
    func testResolveRuntimeModelPrefersStreamingParaformerLayout() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let modelDirectory = root.appendingPathComponent("paraformer-zh", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data().write(to: modelDirectory.appendingPathComponent("encoder.int8.onnx"))
        try Data().write(to: modelDirectory.appendingPathComponent("decoder.int8.onnx"))
        try Data().write(to: modelDirectory.appendingPathComponent("tokens.txt"))

        let runtimeModel = try XCTUnwrap(SherpaOnnxRuntimeModelResolver.resolveModel(in: modelDirectory.path))

        guard case .streamingParaformer(let encoder, let decoder, let tokens) = runtimeModel else {
            return XCTFail("Expected streaming paraformer model")
        }

        XCTAssertEqual(canonicalPath(encoder), canonicalPath(modelDirectory.appendingPathComponent("encoder.int8.onnx").path))
        XCTAssertEqual(canonicalPath(decoder), canonicalPath(modelDirectory.appendingPathComponent("decoder.int8.onnx").path))
        XCTAssertEqual(canonicalPath(tokens), canonicalPath(modelDirectory.appendingPathComponent("tokens.txt").path))
    }

    func testResolveRuntimeModelSupportsStreamingTransducerLayout() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let modelDirectory = root.appendingPathComponent("zipformer-en", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data().write(to: modelDirectory.appendingPathComponent("encoder-epoch-99-avg-1.onnx"))
        try Data().write(to: modelDirectory.appendingPathComponent("decoder-epoch-99-avg-1.onnx"))
        try Data().write(to: modelDirectory.appendingPathComponent("joiner-epoch-99-avg-1.onnx"))
        try Data().write(to: modelDirectory.appendingPathComponent("tokens.txt"))

        let runtimeModel = try XCTUnwrap(SherpaOnnxRuntimeModelResolver.resolveModel(in: modelDirectory.path))

        guard case .streamingTransducer(let encoder, let decoder, let joiner, let tokens) = runtimeModel else {
            return XCTFail("Expected streaming transducer model")
        }

        XCTAssertEqual(canonicalPath(encoder), canonicalPath(modelDirectory.appendingPathComponent("encoder-epoch-99-avg-1.onnx").path))
        XCTAssertEqual(canonicalPath(decoder), canonicalPath(modelDirectory.appendingPathComponent("decoder-epoch-99-avg-1.onnx").path))
        XCTAssertEqual(canonicalPath(joiner), canonicalPath(modelDirectory.appendingPathComponent("joiner-epoch-99-avg-1.onnx").path))
        XCTAssertEqual(canonicalPath(tokens), canonicalPath(modelDirectory.appendingPathComponent("tokens.txt").path))
    }

    func testResolveRuntimeModelRejectsIncompleteStreamingLayout() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let modelDirectory = root.appendingPathComponent("broken-model", isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data().write(to: modelDirectory.appendingPathComponent("encoder.int8.onnx"))
        try Data().write(to: modelDirectory.appendingPathComponent("tokens.txt"))

        XCTAssertNil(SherpaOnnxRuntimeModelResolver.resolveModel(in: modelDirectory.path))
    }

    func testResolveLibraryPathFindsVersionedBundledOnnxRuntimeDylib() throws {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let frameworksDirectory = root.appendingPathComponent("Frameworks", isDirectory: true)
        try FileManager.default.createDirectory(at: frameworksDirectory, withIntermediateDirectories: true)
        let dylibPath = frameworksDirectory.appendingPathComponent("libonnxruntime.1.23.0.dylib")
        try Data().write(to: dylibPath)

        let resolvedPath = SherpaOnnxRuntimeLibraryResolver.resolveLibraryPath(
            bundlePrivateFrameworksPath: frameworksDirectory.path,
            fallbackPaths: []
        )

        XCTAssertEqual(canonicalPath(resolvedPath ?? ""), canonicalPath(dylibPath.path))
    }

    func testPCM16ConverterNormalizesSamplesToFloatRange() {
        let pcmSamples: [Int16] = [Int16.min, 0, Int16.max]
        let data = pcmSamples.withUnsafeBufferPointer { Data(buffer: $0) }

        let normalized = SherpaOnnxPCM16Converter.floatSamples(from: data)

        XCTAssertEqual(normalized.count, 3)
        XCTAssertEqual(normalized[0], -1, accuracy: 0.0001)
        XCTAssertEqual(normalized[1], 0, accuracy: 0.0001)
        XCTAssertEqual(normalized[2], 1, accuracy: 0.0001)
    }

    func testOnlineModelTypeResolvesParaformerAndTransducer() {
        let paraformer = SherpaOnnxOnlineConfigPolicy.modelType(
            for: .streamingParaformer(encoder: "/tmp/e.onnx", decoder: "/tmp/d.onnx", tokens: "/tmp/tokens.txt")
        )
        XCTAssertEqual(paraformer, "paraformer")

        let transducer = SherpaOnnxOnlineConfigPolicy.modelType(
            for: .streamingTransducer(
                encoder: "/tmp/e.onnx",
                decoder: "/tmp/d.onnx",
                joiner: "/tmp/j.onnx",
                tokens: "/tmp/tokens.txt"
            )
        )
        XCTAssertEqual(transducer, "zipformer")
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func canonicalPath(_ path: String) -> String {
        if path.hasPrefix("/private/var/") {
            return String(path.dropFirst("/private".count))
        }
        return path
    }
}

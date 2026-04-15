import Foundation
import Compression

/// 火山引擎 ASR 二进制协议辅助
/// 移植自 Windows 端 VoiceMindWindows/src-tauri/src/asr.rs
enum VolcengineBinaryProtocol {

    // MARK: - Protocol Constants

    private static let protocolVersion: UInt8 = 0b0001
    private static let headerSize: UInt8 = 0b0001 // 1 × 4 = 4 bytes

    // Message types (high nibble of byte 1)
    private static let msgFullClientRequest: UInt8 = 0b0001
    private static let msgAudioOnlyRequest: UInt8 = 0b0010
    private static let msgFullServerResponse: UInt8 = 0b1001
    private static let msgErrorResponse: UInt8 = 0b1111

    // Message-type specific flags (low nibble of byte 1)
    private static let flagNoSequence: UInt8 = 0b0000
    private static let flagPositiveSequence: UInt8 = 0b0001
    private static let flagLastNoSequence: UInt8 = 0b0010
    private static let flagNegativeSequence: UInt8 = 0b0011

    // Serialization (high nibble of byte 2)
    private static let serialNone: UInt8 = 0b0000
    private static let serialJSON: UInt8 = 0b0001

    // Compression (low nibble of byte 2)
    private static let compressNone: UInt8 = 0b0000
    private static let compressGzip: UInt8 = 0b0001

    // MARK: - Frame Building

    /// 构建 WebSocket URL
    static let websocketURL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"

    /// 构建 WebSocket 请求头
    static func buildRequestHeaders(appId: String, accessKey: String, resourceId: String, connectId: String) -> [String: String] {
        return [
            "X-Api-App-Key": appId,
            "X-Api-Access-Key": accessKey,
            "X-Api-Resource-Id": resourceId,
            "X-Api-Connect-Id": connectId,
        ]
    }

    /// 构建配置帧 (FULL_CLIENT_REQUEST)
    /// - Parameter language: 语言代码
    /// - Returns: 完整的二进制帧数据
    static func buildConfigFrame(language: String = "zh-CN") -> Data {
        let payloadJSON: [String: Any] = [
            "user": ["uid": "voicemind-mac"],
            "audio": [
                "format": "pcm",
                "rate": 16000,
                "bits": 16,
                "channel": 1,
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,
                "enable_punc": true,
                "enable_ddc": true,
                "result_type": "single",
            ],
        ]

        guard let jsonBytes = try? JSONSerialization.data(withJSONObject: payloadJSON) else {
            return Data()
        }

        let payload = GzipHelper.compress(jsonBytes)
        let header = buildHeader(
            msgType: msgFullClientRequest,
            flags: flagNoSequence,
            serial: serialJSON,
            compress: compressGzip
        )

        var frame = Data(capacity: 4 + 4 + payload.count)
        frame.append(header)
        frame.append(UInt32(payload.count).bigEndianData)
        frame.append(payload)

        return frame
    }

    /// 构建音频帧 (AUDIO_ONLY_REQUEST with positive sequence)
    /// - Parameters:
    ///   - audioData: PCM 音频数据
    ///   - sequence: 序列号
    /// - Returns: 完整的二进制帧数据
    static func buildAudioFrame(audioData: Data, sequence: Int32) -> Data {
        let payload = GzipHelper.compress(audioData)
        let header = buildHeader(
            msgType: msgAudioOnlyRequest,
            flags: flagPositiveSequence,
            serial: serialNone,
            compress: compressGzip
        )

        var frame = Data(capacity: 4 + 4 + 4 + payload.count)
        frame.append(header)
        frame.append(sequence.bigEndianData)
        frame.append(UInt32(payload.count).bigEndianData)
        frame.append(payload)

        return frame
    }

    /// 构建结束帧 (AUDIO_ONLY_REQUEST with LAST_NO_SEQUENCE flag)
    static func buildFinishFrame() -> Data {
        let header = buildHeader(
            msgType: msgAudioOnlyRequest,
            flags: flagLastNoSequence,
            serial: serialNone,
            compress: compressNone
        )

        var frame = Data(capacity: 4 + 4)
        frame.append(header)
        frame.append(UInt32(0).bigEndianData) // payload size = 0

        return frame
    }

    // MARK: - Response Parsing

    /// 服务端响应解析结果
    struct ServerResponse {
        let text: String
        let isFinal: Bool
    }

    /// 解析服务端二进制响应
    /// - Parameter data: WebSocket 收到的二进制数据
    /// - Returns: 解析出的响应数组
    static func parseServerResponse(_ data: Data) -> [ServerResponse] {
        guard data.count >= 4 else { return [] }

        let msgType = (data[1] >> 4) & 0x0F
        let flags = data[1] & 0x0F
        let compression = data[2] & 0x0F

        switch msgType {
        case msgFullServerResponse:
            return parseFullServerResponse(data, flags: flags, compression: compression)
        case msgErrorResponse:
            parseErrorResponse(data)
            return []
        default:
            return []
        }
    }

    // MARK: - Private Helpers

    private static func buildHeader(msgType: UInt8, flags: UInt8, serial: UInt8, compress: UInt8) -> Data {
        return Data([
            (protocolVersion << 4) | headerSize,
            (msgType << 4) | flags,
            (serial << 4) | compress,
            0x00,
        ])
    }

    private static func parseFullServerResponse(_ data: Data, flags: UInt8, compression: UInt8) -> [ServerResponse] {
        // Layout: header(4) + sequence(4) + payload_size(4) + payload
        guard data.count >= 12 else { return [] }

        let payloadSize = UInt32(bigEndian: [data[8], data[9], data[10], data[11]])
        let payloadEnd = 12 + Int(payloadSize)
        guard data.count >= payloadEnd else { return [] }

        let rawPayload = data[12..<payloadEnd]

        let jsonBytes: Data
        if compression == compressGzip {
            guard let decompressed = GzipHelper.decompressOrNil(Data(rawPayload)) else {
                print("⚠️ Volcengine: gzip 解压响应失败")
                return []
            }
            jsonBytes = decompressed
        } else {
            jsonBytes = Data(rawPayload)
        }

        let isFinal = (flags == flagNegativeSequence || flags == flagLastNoSequence)

        var results: [ServerResponse] = []

        // 解析 JSON（可能是多个连续 JSON）
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonBytes) {
            if let jsonArray = jsonObject as? [[String: Any]] {
                for json in jsonArray {
                    if let response = parseSingleResponse(json, isFinal: isFinal) {
                        results.append(response)
                    }
                }
            } else if let json = jsonObject as? [String: Any] {
                if let response = parseSingleResponse(json, isFinal: isFinal) {
                    results.append(response)
                }
            }
        }

        return results
    }

    private static func parseSingleResponse(_ json: [String: Any], isFinal: Bool) -> ServerResponse? {
        // Check for error code
        if let code = json["result_code"] as? Int, code != 0 {
            let msg = json["message"] as? String ?? "unknown"
            print("⚠️ Volcengine ASR error code \(code): \(msg)")
            return nil
        }

        guard let result = json["result"] as? [String: Any],
              let text = result["text"] as? String,
              !text.isEmpty else {
            return nil
        }

        return ServerResponse(text: text, isFinal: isFinal)
    }

    private static func parseErrorResponse(_ data: Data) {
        // Layout: header(4) + error_code(4) + msg_size(4) + msg
        guard data.count >= 12 else { return }
        let code = UInt32(bigEndian: [data[4], data[5], data[6], data[7]])
        let msgSize = UInt32(bigEndian: [data[8], data[9], data[10], data[11]])
        let msg: String
        if data.count >= 12 + Int(msgSize) {
            msg = String(data: data[12..<12 + Int(msgSize)], encoding: .utf8) ?? "unknown"
        } else {
            msg = "unknown"
        }
        print("⚠️ Volcengine ASR protocol error \(code): \(msg)")
    }
}

// MARK: - Data Extension for Big Endian

private extension Int32 {
    var bigEndianData: Data {
        withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}

private extension UInt32 {
    init(bigEndian bytes: [UInt8]) {
        self = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
    }

    var bigEndianData: Data {
        withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}

// MARK: - Gzip Helper

/// Gzip 压缩/解压工具
/// 使用 zlib (通过 Bridging Header 导入)
enum GzipHelper {

    /// gzip 压缩
    static func compress(_ data: Data) -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        stream.avail_in = uInt(data.count)
        stream.total_in = uLong(data.count)

        data.withUnsafeBytes { rawBuffer in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress)
        }

        // Window bits: 15 + 16 for gzip format
        let windowBits = 15 + 16
        let memLevel = 8
        let result = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, Int32(windowBits), Int32(memLevel), Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard result == Z_OK else {
            print("⚠️ Gzip compress init failed: \(result)")
            return data
        }

        defer { deflateEnd(&stream) }

        let bufferSize = max(data.count, 4096)
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        buffer.withUnsafeMutableBufferPointer { bufPtr in
            stream.avail_out = uInt(bufferSize)
            stream.next_out = bufPtr.baseAddress
        }

        let deflateResult = deflate(&stream, Z_FINISH)
        guard deflateResult == Z_STREAM_END else {
            print("⚠️ Gzip compress failed: \(deflateResult)")
            return data
        }

        let compressedSize = stream.total_out
        return Data(buffer.prefix(Int(compressedSize)))
    }

    /// gzip 解压
    static func decompressOrNil(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }

        var stream = z_stream()
        stream.avail_in = uInt(data.count)

        data.withUnsafeBytes { rawBuffer in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress)
        }

        // Window bits: 15 + 32 for auto-detect gzip/zlib
        let result = inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard result == Z_OK else { return nil }

        defer { inflateEnd(&stream) }

        var output = Data()
        let bufferSize = 16384
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while true {
            buffer.withUnsafeMutableBufferPointer { bufPtr in
                stream.avail_out = uInt(bufferSize)
                stream.next_out = bufPtr.baseAddress
            }

            let inflateResult = inflate(&stream, Z_NO_FLUSH)
            let have = bufferSize - Int(stream.avail_out)
            output.append(buffer, count: have)

            if inflateResult == Z_STREAM_END {
                break
            }
            if inflateResult != Z_OK {
                return nil
            }
            if stream.avail_out != 0 {
                break
            }
        }

        return output
    }
}

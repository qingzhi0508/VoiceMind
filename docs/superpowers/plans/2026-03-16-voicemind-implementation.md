# VoiceMind (语灵) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build macOS + iOS voice input system with push-to-talk hotkey triggering iPhone speech recognition

**Architecture:** Three-target Xcode workspace with SharedCore Swift package for protocol/security, VoiceMindMac for menu bar app with CGEventTap hotkey monitoring and text injection, VoiceMindiOS for SwiftUI app with SFSpeechRecognizer. WebSocket transport with Bonjour discovery, HMAC authentication after pairing.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Starscream WebSocket, CryptoKit, Network.framework, SFSpeechRecognizer, CGEventTap

---

## Chunk 1: Project Setup & SharedCore Protocol

### Task 1: Create Xcode Workspace Structure

**Files:**
- Create: `VoiceMind.xcworkspace/contents.xcworkspacedata`
- Create: `VoiceMindMac/VoiceMindMac.xcodeproj/project.pbxproj`
- Create: `VoiceMindiOS/VoiceMindiOS.xcodeproj/project.pbxproj`
- Create: `SharedCore/Package.swift`

- [ ] **Step 1: Create workspace directory structure**

```bash
mkdir -p VoiceMind.xcworkspace
mkdir -p VoiceMindMac
mkdir -p VoiceMindiOS
mkdir -p SharedCore/Sources/SharedCore/{Protocol,Security,Models}
mkdir -p SharedCore/Tests/SharedCoreTests
```

- [ ] **Step 2: Create macOS app project**

Open Xcode, create new macOS App:
- Product Name: VoiceMindMac
- Interface: AppKit
- Language: Swift
- Deployment Target: macOS 13.0
- Save to: `VoiceMindMac/`

- [ ] **Step 3: Create iOS app project**

Open Xcode, create new iOS App:
- Product Name: VoiceMindiOS
- Interface: SwiftUI
- Language: Swift
- Deployment Target: iOS 18.0
- Save to: `VoiceMindiOS/`

- [ ] **Step 4: Create Swift Package for SharedCore**

```bash
cd SharedCore
swift package init --type library --name SharedCore
```

- [ ] **Step 5: Create Xcode workspace**

In Xcode:
- File → New → Workspace
- Save as: VoiceMind.xcworkspace
- Add VoiceMindMac.xcodeproj
- Add VoiceMindiOS.xcodeproj
- Add SharedCore package

- [ ] **Step 6: Configure SharedCore Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SharedCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "SharedCore",
            targets: ["SharedCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "SharedCore",
            dependencies: ["Starscream"]),
        .testTarget(
            name: "SharedCoreTests",
            dependencies: ["SharedCore"]),
    ]
)
```

- [ ] **Step 7: Add SharedCore dependency to both apps**

In Xcode, for both VoiceMindMac and VoiceMindiOS:
- Target → General → Frameworks, Libraries, and Embedded Content
- Add SharedCore library

- [ ] **Step 8: Commit project structure**

```bash
git add .
git commit -m "feat: create Xcode workspace with macOS, iOS, and SharedCore targets

- VoiceMindMac: macOS 13.0+ menu bar app
- VoiceMindiOS: iOS 18.0+ SwiftUI app
- SharedCore: Swift package for shared protocol and security

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 2: SharedCore - Message Protocol Types

**Files:**
- Create: `SharedCore/Sources/SharedCore/Protocol/MessageType.swift`
- Create: `SharedCore/Sources/SharedCore/Protocol/MessageEnvelope.swift`
- Create: `SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift`
- Test: `SharedCore/Tests/SharedCoreTests/MessageEnvelopeTests.swift`

- [ ] **Step 1: Write test for MessageType enum**

```swift
// SharedCore/Tests/SharedCoreTests/MessageEnvelopeTests.swift
import XCTest
@testable import SharedCore

final class MessageEnvelopeTests: XCTestCase {
    func testMessageTypeRawValues() {
        XCTAssertEqual(MessageType.pairRequest.rawValue, "pairRequest")
        XCTAssertEqual(MessageType.pairConfirm.rawValue, "pairConfirm")
        XCTAssertEqual(MessageType.pairSuccess.rawValue, "pairSuccess")
        XCTAssertEqual(MessageType.startListen.rawValue, "startListen")
        XCTAssertEqual(MessageType.stopListen.rawValue, "stopListen")
        XCTAssertEqual(MessageType.result.rawValue, "result")
        XCTAssertEqual(MessageType.ping.rawValue, "ping")
        XCTAssertEqual(MessageType.pong.rawValue, "pong")
        XCTAssertEqual(MessageType.error.rawValue, "error")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path SharedCore`
Expected: FAIL with "Type 'MessageType' not found"

- [ ] **Step 3: Implement MessageType enum**

```swift
// SharedCore/Sources/SharedCore/Protocol/MessageType.swift
import Foundation

public enum MessageType: String, Codable {
    case pairRequest
    case pairConfirm
    case pairSuccess
    case startListen
    case stopListen
    case result
    case ping
    case pong
    case error
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path SharedCore`
Expected: PASS

- [ ] **Step 5: Write test for MessageEnvelope encoding/decoding**

```swift
// Add to SharedCore/Tests/SharedCoreTests/MessageEnvelopeTests.swift
func testMessageEnvelopeEncodingDecoding() throws {
    let payload = try JSONEncoder().encode(["test": "data"])
    let envelope = MessageEnvelope(
        type: .ping,
        payload: payload,
        timestamp: Date(),
        deviceId: "test-device-123",
        hmac: "test-hmac"
    )

    let encoded = try JSONEncoder().encode(envelope)
    let decoded = try JSONDecoder().decode(MessageEnvelope.self, from: encoded)

    XCTAssertEqual(decoded.type, .ping)
    XCTAssertEqual(decoded.deviceId, "test-device-123")
    XCTAssertEqual(decoded.hmac, "test-hmac")
}

func testMessageEnvelopeWithoutHMAC() throws {
    let payload = try JSONEncoder().encode(["test": "data"])
    let envelope = MessageEnvelope(
        type: .pairRequest,
        payload: payload,
        timestamp: Date(),
        deviceId: "test-device-123",
        hmac: nil
    )

    let encoded = try JSONEncoder().encode(envelope)
    let decoded = try JSONDecoder().decode(MessageEnvelope.self, from: encoded)

    XCTAssertEqual(decoded.type, .pairRequest)
    XCTAssertNil(decoded.hmac)
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `swift test --package-path SharedCore`
Expected: FAIL with "Type 'MessageEnvelope' not found"

- [ ] **Step 7: Implement MessageEnvelope struct**

```swift
// SharedCore/Sources/SharedCore/Protocol/MessageEnvelope.swift
import Foundation

public struct MessageEnvelope: Codable {
    public let type: MessageType
    public let payload: Data
    public let timestamp: Date
    public let deviceId: String
    public let hmac: String?

    public init(
        type: MessageType,
        payload: Data,
        timestamp: Date,
        deviceId: String,
        hmac: String?
    ) {
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
        self.deviceId = deviceId
        self.hmac = hmac
    }
}
```

- [ ] **Step 8: Run test to verify it passes**

Run: `swift test --package-path SharedCore`
Expected: PASS

- [ ] **Step 9: Write test for message payload types**

```swift
// SharedCore/Tests/SharedCoreTests/MessagePayloadsTests.swift
import XCTest
@testable import SharedCore

final class MessagePayloadsTests: XCTestCase {
    func testPairRequestPayload() throws {
        let payload = PairRequestPayload(
            shortCode: "123456",
            macName: "Test Mac",
            macId: "mac-uuid-123"
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PairRequestPayload.self, from: encoded)

        XCTAssertEqual(decoded.shortCode, "123456")
        XCTAssertEqual(decoded.macName, "Test Mac")
        XCTAssertEqual(decoded.macId, "mac-uuid-123")
    }

    func testStartListenPayload() throws {
        let payload = StartListenPayload(sessionId: "session-uuid-456")

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(StartListenPayload.self, from: encoded)

        XCTAssertEqual(decoded.sessionId, "session-uuid-456")
    }

    func testResultPayload() throws {
        let payload = ResultPayload(
            sessionId: "session-uuid-789",
            text: "Hello world",
            language: "en-US"
        )

        let encoded = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ResultPayload.self, from: encoded)

        XCTAssertEqual(decoded.sessionId, "session-uuid-789")
        XCTAssertEqual(decoded.text, "Hello world")
        XCTAssertEqual(decoded.language, "en-US")
    }
}
```

- [ ] **Step 10: Run test to verify it fails**

Run: `swift test --package-path SharedCore`
Expected: FAIL with payload types not found

- [ ] **Step 11: Implement message payload structs**

```swift
// SharedCore/Sources/SharedCore/Protocol/MessagePayloads.swift
import Foundation

public struct PairRequestPayload: Codable {
    public let shortCode: String
    public let macName: String
    public let macId: String

    public init(shortCode: String, macName: String, macId: String) {
        self.shortCode = shortCode
        self.macName = macName
        self.macId = macId
    }
}

public struct PairConfirmPayload: Codable {
    public let shortCode: String
    public let iosName: String
    public let iosId: String

    public init(shortCode: String, iosName: String, iosId: String) {
        self.shortCode = shortCode
        self.iosName = iosName
        self.iosId = iosId
    }
}

public struct PairSuccessPayload: Codable {
    public let sharedSecret: String

    public init(sharedSecret: String) {
        self.sharedSecret = sharedSecret
    }
}

public struct StartListenPayload: Codable {
    public let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

public struct StopListenPayload: Codable {
    public let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

public struct ResultPayload: Codable {
    public let sessionId: String
    public let text: String
    public let language: String

    public init(sessionId: String, text: String, language: String) {
        self.sessionId = sessionId
        self.text = text
        self.language = language
    }
}

public struct PingPayload: Codable {
    public let nonce: String

    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct PongPayload: Codable {
    public let nonce: String

    public init(nonce: String) {
        self.nonce = nonce
    }
}

public struct ErrorPayload: Codable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}
```

- [ ] **Step 12: Run test to verify it passes**

Run: `swift test --package-path SharedCore`
Expected: PASS

- [ ] **Step 13: Commit protocol types**

```bash
git add SharedCore/
git commit -m "feat(SharedCore): add message protocol types and payloads

- MessageType enum with all message types
- MessageEnvelope for wrapping messages with HMAC
- Payload structs for all message types
- Unit tests for encoding/decoding

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 3: SharedCore - HMAC Security

**Files:**
- Create: `SharedCore/Sources/SharedCore/Security/HMACValidator.swift`
- Create: `SharedCore/Sources/SharedCore/Security/KeychainManager.swift`
- Test: `SharedCore/Tests/SharedCoreTests/HMACValidatorTests.swift`

- [ ] **Step 1: Write test for HMAC generation**

```swift
// SharedCore/Tests/SharedCoreTests/HMACValidatorTests.swift
import XCTest
import CryptoKit
@testable import SharedCore

final class HMACValidatorTests: XCTestCase {
    func testHMACGeneration() throws {
        let key = SymmetricKey(size: .bits256)
        let validator = HMACValidator(key: key)

        let message = "test message"
        let hmac = validator.generateHMAC(for: message)

        XCTAssertFalse(hmac.isEmpty)
        XCTAssertEqual(hmac.count, 64) // SHA256 hex string length
    }

    func testHMACValidation() throws {
        let key = SymmetricKey(size: .bits256)
        let validator = HMACValidator(key: key)

        let message = "test message"
        let hmac = validator.generateHMAC(for: message)

        XCTAssertTrue(validator.validateHMAC(hmac, for: message))
    }

    func testHMACValidationFailsWithWrongMessage() throws {
        let key = SymmetricKey(size: .bits256)
        let validator = HMACValidator(key: key)

        let message = "test message"
        let hmac = validator.generateHMAC(for: message)

        XCTAssertFalse(validator.validateHMAC(hmac, for: "different message"))
    }

    func testHMACValidationFailsWithWrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)

        let validator1 = HMACValidator(key: key1)
        let validator2 = HMACValidator(key: key2)

        let message = "test message"
        let hmac = validator1.generateHMAC(for: message)

        XCTAssertFalse(validator2.validateHMAC(hmac, for: message))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --package-path SharedCore`
Expected: FAIL with "Type 'HMACValidator' not found"

- [ ] **Step 3: Implement HMACValidator**

```swift
// SharedCore/Sources/SharedCore/Security/HMACValidator.swift
import Foundation
import CryptoKit

public class HMACValidator {
    private let key: SymmetricKey

    public init(key: SymmetricKey) {
        self.key = key
    }

    public convenience init(sharedSecret: String) {
        let data = Data(sharedSecret.utf8)
        let key = SymmetricKey(data: data)
        self.init(key: key)
    }

    public func generateHMAC(for message: String) -> String {
        let data = Data(message.utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return hmac.map { String(format: "%02x", $0) }.joined()
    }

    public func validateHMAC(_ hmac: String, for message: String) -> Bool {
        let expectedHMAC = generateHMAC(for: message)
        return hmac == expectedHMAC
    }

    public func generateHMACForEnvelope(
        type: MessageType,
        payload: Data,
        timestamp: Date,
        deviceId: String
    ) -> String {
        let message = "\(type.rawValue)\(payload.base64EncodedString())\(timestamp.timeIntervalSince1970)\(deviceId)"
        return generateHMAC(for: message)
    }

    public func validateEnvelopeHMAC(_ envelope: MessageEnvelope) -> Bool {
        guard let hmac = envelope.hmac else { return false }
        let expectedHMAC = generateHMACForEnvelope(
            type: envelope.type,
            payload: envelope.payload,
            timestamp: envelope.timestamp,
            deviceId: envelope.deviceId
        )
        return hmac == expectedHMAC
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --package-path SharedCore`
Expected: PASS

- [ ] **Step 5: Write test for KeychainManager**

```swift
// SharedCore/Tests/SharedCoreTests/KeychainManagerTests.swift
import XCTest
@testable import SharedCore

final class KeychainManagerTests: XCTestCase {
    let testService = "com.voicerelay.test"
    let testAccount = "test-pairing"

    override func tearDown() {
        super.tearDown()
        // Clean up test keychain items
        try? KeychainManager.delete(service: testService, account: testAccount)
    }

    func testSaveAndRetrievePairing() throws {
        let pairing = PairingData(
            deviceId: "test-device-123",
            deviceName: "Test Device",
            sharedSecret: "test-secret-key"
        )

        try KeychainManager.savePairing(pairing, service: testService, account: testAccount)
        let retrieved = try KeychainManager.retrievePairing(service: testService, account: testAccount)

        XCTAssertEqual(retrieved.deviceId, "test-device-123")
        XCTAssertEqual(retrieved.deviceName, "Test Device")
        XCTAssertEqual(retrieved.sharedSecret, "test-secret-key")
    }

    func testDeletePairing() throws {
        let pairing = PairingData(
            deviceId: "test-device-456",
            deviceName: "Test Device 2",
            sharedSecret: "test-secret-key-2"
        )

        try KeychainManager.savePairing(pairing, service: testService, account: testAccount)
        try KeychainManager.delete(service: testService, account: testAccount)

        XCTAssertThrowsError(try KeychainManager.retrievePairing(service: testService, account: testAccount))
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `swift test --package-path SharedCore`
Expected: FAIL with "Type 'KeychainManager' not found"

- [ ] **Step 7: Implement PairingData model**

```swift
// SharedCore/Sources/SharedCore/Models/PairingData.swift
import Foundation

public struct PairingData: Codable {
    public let deviceId: String
    public let deviceName: String
    public let sharedSecret: String

    public init(deviceId: String, deviceName: String, sharedSecret: String) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.sharedSecret = sharedSecret
    }
}
```

- [ ] **Step 8: Implement KeychainManager**

```swift
// SharedCore/Sources/SharedCore/Security/KeychainManager.swift
import Foundation
import Security

public enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(status: OSStatus)
}

public class KeychainManager {
    public static func savePairing(
        _ pairing: PairingData,
        service: String,
        account: String
    ) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(pairing)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        // Delete existing item if present
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    public static func retrievePairing(
        service: String,
        account: String
    ) throws -> PairingData {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        let decoder = JSONDecoder()
        return try decoder.decode(PairingData.self, from: data)
    }

    public static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `swift test --package-path SharedCore`
Expected: PASS

- [ ] **Step 10: Commit security implementation**

```bash
git add SharedCore/
git commit -m "feat(SharedCore): add HMAC validation and Keychain management

- HMACValidator for message authentication
- KeychainManager for secure pairing storage
- PairingData model
- Unit tests for HMAC and Keychain operations

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 2: macOS Network Layer & Bonjour

### Task 4: macOS WebSocket Server

**Files:**
- Create: `VoiceMindMac/Network/WebSocketServer.swift`
- Create: `VoiceMindMac/Network/ConnectionState.swift`

- [ ] **Step 1: Add Starscream to macOS project**

In Xcode, VoiceMindMac target:
- File → Add Package Dependencies
- Add: https://github.com/daltoniam/Starscream.git
- Version: 4.0.0+

- [ ] **Step 2: Create ConnectionState enum**

```swift
// VoiceMindMac/Network/ConnectionState.swift
import Foundation

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(Error)
}
```

- [ ] **Step 3: Implement WebSocketServer**

```swift
// VoiceMindMac/Network/WebSocketServer.swift
import Foundation
import Starscream
import SharedCore

protocol WebSocketServerDelegate: AnyObject {
    func server(_ server: WebSocketServer, didReceiveMessage message: MessageEnvelope)
    func server(_ server: WebSocketServer, didChangeState state: ConnectionState)
}

class WebSocketServer: NSObject {
    weak var delegate: WebSocketServerDelegate?
    private var server: Server?
    private var connectedSocket: WebSocket?
    private(set) var port: UInt16 = 0
    private(set) var state: ConnectionState = .disconnected {
        didSet {
            delegate?.server(self, didChangeState: state)
        }
    }

    func start(portRange: ClosedRange<UInt16> = 8000...9000) throws {
        for port in portRange {
            do {
                let server = Server(port: port)
                server.onConnect = { [weak self] socket in
                    self?.handleConnection(socket)
                }
                try server.start()
                self.server = server
                self.port = port
                self.state = .connecting
                print("WebSocket server started on port \(port)")
                return
            } catch {
                continue
            }
        }
        throw NSError(domain: "WebSocketServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No available port in range"])
    }

    func stop() {
        connectedSocket?.disconnect()
        connectedSocket = nil
        server?.stop()
        server = nil
        state = .disconnected
    }

    func send(_ envelope: MessageEnvelope) {
        guard let socket = connectedSocket, socket.isConnected else {
            print("Cannot send message: not connected")
            return
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            socket.write(data: data)
        } catch {
            print("Failed to encode message: \(error)")
        }
    }

    private func handleConnection(_ socket: WebSocket) {
        // Reject if already connected
        if connectedSocket != nil {
            socket.disconnect()
            return
        }

        connectedSocket = socket
        state = .connected

        socket.onText = { [weak self] text in
            self?.handleMessage(text)
        }

        socket.onData = { [weak self] data in
            self?.handleMessage(data)
        }

        socket.onDisconnect = { [weak self] error in
            self?.handleDisconnection(error)
        }
    }

    private func handleMessage(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            delegate?.server(self, didReceiveMessage: envelope)
        } catch {
            print("Failed to decode message: \(error)")
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        handleMessage(data)
    }

    private func handleDisconnection(_ error: Error?) {
        connectedSocket = nil
        state = .disconnected
        if let error = error {
            print("WebSocket disconnected with error: \(error)")
        }
    }
}
```

- [ ] **Step 4: Commit WebSocket server**

```bash
git add VoiceMindMac/Network/
git commit -m "feat(macOS): add WebSocket server with Starscream

- WebSocketServer class for single-client connections
- ConnectionState enum for tracking connection status
- Delegate pattern for message handling

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 5: macOS Bonjour Publisher

**Files:**
- Create: `VoiceMindMac/Network/BonjourPublisher.swift`

- [ ] **Step 1: Implement BonjourPublisher**

```swift
// VoiceMindMac/Network/BonjourPublisher.swift
import Foundation
import Network

class BonjourPublisher {
    private var listener: NWListener?
    private let serviceType = "_voicerelay._tcp"
    private var port: UInt16

    init(port: UInt16) {
        self.port = port
    }

    func start() throws {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener.service = NWListener.Service(
            name: Host.current().localizedName ?? "VoiceMind Mac",
            type: serviceType
        )

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Bonjour service published on port \(self.port)")
            case .failed(let error):
                print("Bonjour service failed: \(error)")
            case .cancelled:
                print("Bonjour service cancelled")
            default:
                break
            }
        }

        listener.start(queue: .main)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}
```

- [ ] **Step 2: Commit Bonjour publisher**

```bash
git add VoiceMindMac/Network/BonjourPublisher.swift
git commit -m "feat(macOS): add Bonjour service publisher

- BonjourPublisher for advertising WebSocket server
- Uses Network.framework for mDNS
- Publishes _voicerelay._tcp service

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 6: macOS Connection Manager

**Files:**
- Create: `VoiceMindMac/Network/ConnectionManager.swift`
- Create: `VoiceMindMac/Network/PairingState.swift`

- [ ] **Step 1: Create PairingState enum**

```swift
// VoiceMindMac/Network/PairingState.swift
import Foundation

enum PairingState {
    case unpaired
    case pairing(code: String, expiresAt: Date)
    case paired(deviceId: String, deviceName: String)
}
```

- [ ] **Step 2: Implement ConnectionManager**

```swift
// VoiceMindMac/Network/ConnectionManager.swift
import Foundation
import SharedCore
import CryptoKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState)
    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope)
}

class ConnectionManager: NSObject {
    weak var delegate: ConnectionManagerDelegate?

    private let server = WebSocketServer()
    private var bonjourPublisher: BonjourPublisher?
    private var hmacValidator: HMACValidator?

    private let keychainService = "com.voicerelay.mac"
    private let keychainAccount = "pairing"
    private let deviceId = UUID().uuidString

    private(set) var pairingState: PairingState = .unpaired {
        didSet {
            delegate?.connectionManager(self, didChangePairingState: pairingState)
        }
    }

    private var pairingTimer: Timer?

    override init() {
        super.init()
        server.delegate = self
        loadPairing()
    }

    func start() throws {
        try server.start()
        let publisher = BonjourPublisher(port: server.port)
        try publisher.start()
        bonjourPublisher = publisher
    }

    func stop() {
        server.stop()
        bonjourPublisher?.stop()
    }

    func startPairing() -> String {
        // Generate 6-digit code
        let code = String(format: "%06d", Int.random(in: 0...999999))

        // Set pairing state with 2-minute expiration
        let expiresAt = Date().addingTimeInterval(120)
        pairingState = .pairing(code: code, expiresAt: expiresAt)

        // Start expiration timer
        pairingTimer?.invalidate()
        pairingTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            self?.cancelPairing()
        }

        return code
    }

    func cancelPairing() {
        pairingTimer?.invalidate()
        pairingTimer = nil

        if case .pairing = pairingState {
            pairingState = .unpaired
        }
    }

    func unpair() {
        try? KeychainManager.delete(service: keychainService, account: keychainAccount)
        hmacValidator = nil
        pairingState = .unpaired
    }

    func send(_ envelope: MessageEnvelope) {
        server.send(envelope)
    }

    private func loadPairing() {
        do {
            let pairing = try KeychainManager.retrievePairing(service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: pairing.sharedSecret)
            pairingState = .paired(deviceId: pairing.deviceId, deviceName: pairing.deviceName)
        } catch {
            pairingState = .unpaired
        }
    }

    private func handlePairConfirm(_ payload: PairConfirmPayload) {
        guard case .pairing(let code, _) = pairingState else {
            sendError(code: "not_pairing", message: "Not in pairing mode")
            return
        }

        guard payload.shortCode == code else {
            sendError(code: "invalid_code", message: "Invalid pairing code")
            return
        }

        // Generate shared secret
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let sharedSecret = Data(bytes).base64EncodedString()

        // Save pairing
        let pairing = PairingData(
            deviceId: payload.iosId,
            deviceName: payload.iosName,
            sharedSecret: sharedSecret
        )

        do {
            try KeychainManager.savePairing(pairing, service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: sharedSecret)
            pairingState = .paired(deviceId: payload.iosId, deviceName: payload.iosName)

            // Send success
            let successPayload = PairSuccessPayload(sharedSecret: sharedSecret)
            let payloadData = try JSONEncoder().encode(successPayload)
            let envelope = MessageEnvelope(
                type: .pairSuccess,
                payload: payloadData,
                timestamp: Date(),
                deviceId: deviceId,
                hmac: nil
            )
            server.send(envelope)

            pairingTimer?.invalidate()
            pairingTimer = nil
        } catch {
            sendError(code: "pairing_failed", message: "Failed to save pairing: \(error)")
        }
    }

    private func sendError(code: String, message: String) {
        let payload = ErrorPayload(code: code, message: message)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: nil
        )
        server.send(envelope)
    }
}

extension ConnectionManager: WebSocketServerDelegate {
    func server(_ server: WebSocketServer, didReceiveMessage message: MessageEnvelope) {
        // Handle pairing messages without HMAC
        if message.type == .pairConfirm {
            guard let payload = try? JSONDecoder().decode(PairConfirmPayload.self, from: message.payload) else {
                sendError(code: "invalid_payload", message: "Invalid pairConfirm payload")
                return
            }
            handlePairConfirm(payload)
            return
        }

        // Validate HMAC for all other messages
        guard let validator = hmacValidator else {
            sendError(code: "not_paired", message: "Device not paired")
            return
        }

        guard validator.validateEnvelopeHMAC(message) else {
            sendError(code: "invalid_hmac", message: "HMAC validation failed")
            return
        }

        // Forward validated message to delegate
        delegate?.connectionManager(self, didReceiveMessage: message)
    }

    func server(_ server: WebSocketServer, didChangeState state: ConnectionState) {
        delegate?.connectionManager(self, didChangeConnectionState: state)
    }
}
```

- [ ] **Step 3: Commit connection manager**

```bash
git add VoiceMindMac/Network/
git commit -m "feat(macOS): add connection manager with pairing logic

- ConnectionManager orchestrates WebSocket and Bonjour
- Handles pairing flow with 6-digit code and 2-minute timeout
- HMAC validation for post-pairing messages
- Keychain persistence for pairing data

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 3: macOS Hotkey & Text Injection

### Task 7: macOS Hotkey Monitor

**Files:**
- Create: `VoiceMindMac/Hotkey/HotkeyMonitor.swift`
- Create: `VoiceMindMac/Hotkey/HotkeyConfiguration.swift`

- [ ] **Step 1: Create HotkeyConfiguration struct**

```swift
// VoiceMindMac/Hotkey/HotkeyConfiguration.swift
import Foundation
import Carbon

struct HotkeyConfiguration: Codable {
    let keyCode: UInt16
    let modifierFlags: UInt32

    static let defaultHotkey = HotkeyConfiguration(
        keyCode: UInt16(kVK_Space),
        modifierFlags: UInt32(optionKey)
    )

    var displayString: String {
        var parts: [String] = []

        if modifierFlags & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifierFlags & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifierFlags & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if modifierFlags & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_ANSI_A...kVK_ANSI_Z:
            let char = Character(UnicodeScalar(Int(keyCode) - kVK_ANSI_A + 65)!)
            return String(char)
        default: return "Key\(keyCode)"
        }
    }
}
```

- [ ] **Step 2: Implement HotkeyMonitor**

```swift
// VoiceMindMac/Hotkey/HotkeyMonitor.swift
import Foundation
import Carbon
import Cocoa

protocol HotkeyMonitorDelegate: AnyObject {
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didPressHotkey sessionId: String)
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didReleaseHotkey sessionId: String)
}

class HotkeyMonitor {
    weak var delegate: HotkeyMonitorDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var configuration: HotkeyConfiguration
    private var isHotkeyPressed = false
    private var currentSessionId: String?
    private var pressTime: Date?

    private let debounceInterval: TimeInterval = 0.1 // 100ms

    init(configuration: HotkeyConfiguration = .defaultHotkey) {
        self.configuration = configuration
    }

    func start() -> Bool {
        guard checkAccessibilityPermission() else {
            print("Accessibility permission not granted")
            return false
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        print("Hotkey monitor started")
        return true
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        print("Hotkey monitor stopped")
    }

    func updateConfiguration(_ configuration: HotkeyConfiguration) {
        self.configuration = configuration
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .keyDown || type == .keyUp {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags

            let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
            let currentModifiers = flags.intersection(modifierMask).rawValue

            // Check if this matches our hotkey
            if keyCode == configuration.keyCode && currentModifiers == UInt64(configuration.modifierFlags) {
                if type == .keyDown && !isHotkeyPressed {
                    handleHotkeyPress()
                    return nil // Consume event
                } else if type == .keyUp && isHotkeyPressed {
                    handleHotkeyRelease()
                    return nil // Consume event
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func handleHotkeyPress() {
        let now = Date()

        // Debounce: ignore if pressed too quickly after last release
        if let lastPress = pressTime, now.timeIntervalSince(lastPress) < debounceInterval {
            return
        }

        pressTime = now
        isHotkeyPressed = true

        let sessionId = UUID().uuidString
        currentSessionId = sessionId

        delegate?.hotkeyMonitor(self, didPressHotkey: sessionId)
    }

    private func handleHotkeyRelease() {
        guard let sessionId = currentSessionId else { return }

        let now = Date()

        // Debounce: ignore if released too quickly after press
        if let pressTime = pressTime, now.timeIntervalSince(pressTime) < debounceInterval {
            return
        }

        isHotkeyPressed = false
        delegate?.hotkeyMonitor(self, didReleaseHotkey: sessionId)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
```

- [ ] **Step 3: Commit hotkey monitor**

```bash
git add VoiceMindMac/Hotkey/
git commit -m "feat(macOS): add hotkey monitor with CGEventTap

- HotkeyMonitor for global hotkey detection
- HotkeyConfiguration for customizable hotkeys
- Press/release detection with debouncing
- Accessibility permission checking

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 8: macOS Text Injector

**Files:**
- Create: `VoiceMindMac/TextInjection/TextInjector.swift`

- [ ] **Step 1: Implement TextInjector**

```swift
// VoiceMindMac/TextInjection/TextInjector.swift
import Foundation
import Carbon
import Cocoa

enum TextInjectionError: Error {
    case accessibilityPermissionDenied
    case injectionFailed(String)
}

class TextInjector {
    private let chunkSize = 500
    private let chunkDelay: TimeInterval = 0.01 // 10ms

    func inject(_ text: String) throws {
        guard checkAccessibilityPermission() else {
            throw TextInjectionError.accessibilityPermissionDenied
        }

        // Split into chunks for long text
        let chunks = text.chunked(into: chunkSize)

        for (index, chunk) in chunks.enumerated() {
            try injectChunk(chunk)

            // Add delay between chunks (except for last chunk)
            if index < chunks.count - 1 {
                Thread.sleep(forTimeInterval: chunkDelay)
            }
        }
    }

    private func injectChunk(_ text: String) throws {
        for char in text {
            try injectCharacter(char)
        }
    }

    private func injectCharacter(_ char: Character) throws {
        let string = String(char)
        guard let unicodeScalar = string.unicodeScalars.first else { return }

        let keyCode = CGKeyCode(0) // Virtual key code for Unicode input

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw TextInjectionError.injectionFailed("Failed to create key down event")
        }

        // Set Unicode string
        keyDownEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw TextInjectionError.injectionFailed("Failed to create key up event")
        }

        keyUpEvent.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var currentIndex = startIndex

        while currentIndex < endIndex {
            let nextIndex = index(currentIndex, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(String(self[currentIndex..<nextIndex]))
            currentIndex = nextIndex
        }

        return chunks
    }
}
```

- [ ] **Step 2: Commit text injector**

```bash
git add VoiceMindMac/TextInjection/
git commit -m "feat(macOS): add text injector with CGEvent

- TextInjector for keyboard simulation
- Unicode character posting via CGEvent
- Chunking for long text with delays
- Accessibility permission checking

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 4: macOS UI & Permissions

### Task 9: macOS Permissions Manager

**Files:**
- Create: `VoiceMindMac/Permissions/PermissionsManager.swift`
- Create: `VoiceMindMac/Permissions/PermissionsWindow.swift`

- [ ] **Step 1: Implement PermissionsManager**

```swift
// VoiceMindMac/Permissions/PermissionsManager.swift
import Foundation
import Cocoa

enum PermissionType {
    case accessibility
    case inputMonitoring
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
}

class PermissionsManager {
    static func checkAccessibility() -> PermissionStatus {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options)
        return trusted ? .granted : .denied
    }

    static func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemPreferences(for permission: PermissionType) {
        switch permission {
        case .accessibility:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        case .inputMonitoring:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
            NSWorkspace.shared.open(url)
        }
    }

    static func showPermissionAlert(for permission: PermissionType) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"

        switch permission {
        case .accessibility:
            alert.informativeText = "VoiceMind needs Accessibility permission to monitor hotkeys and inject text. Please grant permission in System Settings."
        case .inputMonitoring:
            alert.informativeText = "VoiceMind needs Input Monitoring permission to detect keyboard events. Please grant permission in System Settings."
        }

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            openSystemPreferences(for: permission)
        }
    }
}
```

- [ ] **Step 2: Create PermissionsWindow SwiftUI view**

```swift
// VoiceMindMac/Permissions/PermissionsWindow.swift
import SwiftUI

struct PermissionsWindow: View {
    @State private var accessibilityGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.title)

            VStack(alignment: .leading, spacing: 15) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required for hotkey monitoring and text injection",
                    isGranted: accessibilityGranted,
                    onRequest: {
                        PermissionsManager.requestAccessibility()
                        checkPermissions()
                    }
                )
            }
            .padding()

            Button("Refresh") {
                checkPermissions()
            }
        }
        .frame(width: 500, height: 300)
        .padding()
        .onAppear {
            checkPermissions()
        }
    }

    private func checkPermissions() {
        accessibilityGranted = PermissionsManager.checkAccessibility() == .granted
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onRequest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button("Grant Permission") {
                    onRequest()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
```

- [ ] **Step 3: Commit permissions manager**

```bash
git add VoiceMindMac/Permissions/
git commit -m "feat(macOS): add permissions manager and UI

- PermissionsManager for checking and requesting permissions
- PermissionsWindow SwiftUI view for permission status
- System Settings deep links for permission grants

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 10: macOS Menu Bar UI

**Files:**
- Create: `VoiceMindMac/MenuBar/MenuBarController.swift`
- Create: `VoiceMindMac/MenuBar/PairingWindow.swift`
- Create: `VoiceMindMac/MenuBar/HotkeySettingsWindow.swift`

- [ ] **Step 1: Implement MenuBarController**

```swift
// VoiceMindMac/MenuBar/MenuBarController.swift
import Cocoa
import SwiftUI
import SharedCore

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let connectionManager = ConnectionManager()
    private let hotkeyMonitor: HotkeyMonitor
    private let textInjector = TextInjector()

    private var currentSessionId: String?
    private var sessionTimer: Timer?

    private var pairingWindow: NSWindow?
    private var permissionsWindow: NSWindow?
    private var hotkeySettingsWindow: NSWindow?

    override init() {
        self.hotkeyMonitor = HotkeyMonitor()
        super.init()

        setupStatusItem()
        setupConnectionManager()
        setupHotkeyMonitor()
        startServices()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "VoiceMind")
            updateStatusIcon()
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let statusItem = NSMenuItem(title: "Unpaired", action: nil, keyEquivalent: "")
        statusItem.tag = 100 // For updating later
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Start Pairing...", action: #selector(startPairing), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Hotkey Settings...", action: #selector(openHotkeySettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Permissions...", action: #selector(openPermissions), keyEquivalent: ""))

        let unpairItem = NSMenuItem(title: "Unpair Device", action: #selector(unpairDevice), keyEquivalent: "")
        unpairItem.tag = 101 // For showing/hiding
        menu.addItem(unpairItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        self.statusItem.menu = menu
        updateMenu()
    }

    private func setupConnectionManager() {
        connectionManager.delegate = self
    }

    private func setupHotkeyMonitor() {
        hotkeyMonitor.delegate = self

        if PermissionsManager.checkAccessibility() == .granted {
            _ = hotkeyMonitor.start()
        }
    }

    private func startServices() {
        do {
            try connectionManager.start()
        } catch {
            print("Failed to start connection manager: \(error)")
            showError("Failed to start services: \(error.localizedDescription)")
        }
    }

    @objc private func startPairing() {
        let code = connectionManager.startPairing()
        showPairingWindow(code: code)
    }

    @objc private func openHotkeySettings() {
        if hotkeySettingsWindow == nil {
            let contentView = HotkeySettingsWindow(
                onSave: { [weak self] config in
                    self?.hotkeyMonitor.updateConfiguration(config)
                    self?.hotkeySettingsWindow?.close()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Hotkey Settings"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            hotkeySettingsWindow = window
        }

        hotkeySettingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openPermissions() {
        if permissionsWindow == nil {
            let contentView = PermissionsWindow()

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Permissions"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            permissionsWindow = window
        }

        permissionsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func unpairDevice() {
        let alert = NSAlert()
        alert.messageText = "Unpair Device?"
        alert.informativeText = "This will remove the pairing with your iPhone. You'll need to pair again to use VoiceMind."
        alert.addButton(withTitle: "Unpair")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            connectionManager.unpair()
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func showPairingWindow(code: String) {
        let contentView = PairingWindow(
            code: code,
            onCancel: { [weak self] in
                self?.connectionManager.cancelPairing()
                self?.pairingWindow?.close()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pair with iPhone"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()

        pairingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        switch connectionManager.pairingState {
        case .unpaired:
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Unpaired")
        case .pairing:
            button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Pairing")
        case .paired:
            if case .connected = connectionManager.server.state {
                button.image = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "Connected")
                button.image?.isTemplate = false
                // Set tint to green
            } else {
                button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "Disconnected")
            }
        }
    }

    private func updateMenu() {
        guard let menu = statusItem.menu else { return }

        // Update status text
        if let statusItem = menu.item(withTag: 100) {
            switch connectionManager.pairingState {
            case .unpaired:
                statusItem.title = "Unpaired"
            case .pairing:
                statusItem.title = "Pairing..."
            case .paired(_, let deviceName):
                if case .connected = connectionManager.server.state {
                    statusItem.title = "Connected to \(deviceName)"
                } else {
                    statusItem.title = "Disconnected"
                }
            }
        }

        // Show/hide unpair button
        if let unpairItem = menu.item(withTag: 101) {
            unpairItem.isHidden = {
                if case .paired = connectionManager.pairingState {
                    return false
                }
                return true
            }()
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func showTextCopyAlert(_ text: String, error: String) {
        let alert = NSAlert()
        alert.messageText = "Text Injection Failed"
        alert.informativeText = "Failed to inject text: \(error)\n\nYou can copy the text manually."
        alert.addButton(withTitle: "Copy Text")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}

extension MenuBarController: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        updateStatusIcon()
        updateMenu()

        if case .paired = state {
            pairingWindow?.close()
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        updateStatusIcon()
        updateMenu()
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope) {
        switch envelope.type {
        case .result:
            handleResultMessage(envelope)
        case .ping:
            handlePingMessage(envelope)
        default:
            break
        }
    }

    private func handleResultMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(ResultPayload.self, from: envelope.payload) else {
            return
        }

        // Validate session ID
        guard payload.sessionId == currentSessionId else {
            print("Ignoring result with mismatched session ID")
            return
        }

        // Clear session
        currentSessionId = nil
        sessionTimer?.invalidate()
        sessionTimer = nil

        // Inject text
        do {
            try textInjector.inject(payload.text)
        } catch TextInjectionError.accessibilityPermissionDenied {
            showTextCopyAlert(payload.text, error: "Accessibility permission denied")
        } catch {
            showTextCopyAlert(payload.text, error: error.localizedDescription)
        }
    }

    private func handlePingMessage(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(PingPayload.self, from: envelope.payload) else {
            return
        }

        // Send pong
        let pongPayload = PongPayload(nonce: payload.nonce)
        guard let payloadData = try? JSONEncoder().encode(pongPayload) else { return }

        let pongEnvelope = MessageEnvelope(
            type: .pong,
            payload: payloadData,
            timestamp: Date(),
            deviceId: connectionManager.deviceId,
            hmac: connectionManager.hmacValidator?.generateHMACForEnvelope(
                type: .pong,
                payload: payloadData,
                timestamp: Date(),
                deviceId: connectionManager.deviceId
            )
        )

        connectionManager.send(pongEnvelope)
    }
}

extension MenuBarController: HotkeyMonitorDelegate {
    func hotkeyMonitor(_ monitor: HotkeyMonitor, didPressHotkey sessionId: String) {
        guard case .paired = connectionManager.pairingState else {
            return
        }

        currentSessionId = sessionId

        // Start 30-second timeout
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.handleSessionTimeout()
        }

        // Send startListen message
        let payload = StartListenPayload(sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .startListen,
            payload: payloadData,
            timestamp: Date(),
            deviceId: connectionManager.deviceId,
            hmac: connectionManager.hmacValidator?.generateHMACForEnvelope(
                type: .startListen,
                payload: payloadData,
                timestamp: Date(),
                deviceId: connectionManager.deviceId
            )
        )

        connectionManager.send(envelope)
    }

    func hotkeyMonitor(_ monitor: HotkeyMonitor, didReleaseHotkey sessionId: String) {
        guard sessionId == currentSessionId else { return }

        // Send stopListen message
        let payload = StopListenPayload(sessionId: sessionId)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .stopListen,
            payload: payloadData,
            timestamp: Date(),
            deviceId: connectionManager.deviceId,
            hmac: connectionManager.hmacValidator?.generateHMACForEnvelope(
                type: .stopListen,
                payload: payloadData,
                timestamp: Date(),
                deviceId: connectionManager.deviceId
            )
        )

        connectionManager.send(envelope)
    }

    private func handleSessionTimeout() {
        currentSessionId = nil
        showError("No response from iPhone within 30 seconds")
    }
}
```

- [ ] **Step 2: Create PairingWindow SwiftUI view**

```swift
// VoiceMindMac/MenuBar/PairingWindow.swift
import SwiftUI

struct PairingWindow: View {
    let code: String
    let onCancel: () -> Void

    @State private var timeRemaining = 120

    var body: some View {
        VStack(spacing: 20) {
            Text("Pair with iPhone")
                .font(.title)

            Text("Enter this code on your iPhone:")
                .font(.headline)

            Text(code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)

            Text("Waiting for iPhone...")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Time remaining: \(timeRemaining)s")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Cancel") {
                onCancel()
            }
        }
        .frame(width: 400, height: 300)
        .padding()
        .onAppear {
            startTimer()
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                onCancel()
            }
        }
    }
}
```

- [ ] **Step 3: Create HotkeySettingsWindow SwiftUI view**

```swift
// VoiceMindMac/MenuBar/HotkeySettingsWindow.swift
import SwiftUI

struct HotkeySettingsWindow: View {
    let onSave: (HotkeyConfiguration) -> Void

    @State private var selectedModifiers: Set<String> = ["Option"]
    @State private var selectedKey = "Space"

    let modifierOptions = ["Control", "Option", "Shift", "Command"]
    let keyOptions = ["Space", "Return", "Tab", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Hotkey Settings")
                .font(.title)

            VStack(alignment: .leading, spacing: 10) {
                Text("Modifiers:")
                    .font(.headline)

                ForEach(modifierOptions, id: \.self) { modifier in
                    Toggle(modifier, isOn: Binding(
                        get: { selectedModifiers.contains(modifier) },
                        set: { isOn in
                            if isOn {
                                selectedModifiers.insert(modifier)
                            } else {
                                selectedModifiers.remove(modifier)
                            }
                        }
                    ))
                }

                Text("Key:")
                    .font(.headline)
                    .padding(.top)

                Picker("Key", selection: $selectedKey) {
                    ForEach(keyOptions, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding()

            Text("Current: \(hotkeyDisplayString)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Cancel") {
                    // Close window
                }

                Button("Save") {
                    saveHotkey()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 400, height: 300)
        .padding()
    }

    private var hotkeyDisplayString: String {
        var parts: [String] = []

        if selectedModifiers.contains("Control") {
            parts.append("⌃")
        }
        if selectedModifiers.contains("Option") {
            parts.append("⌥")
        }
        if selectedModifiers.contains("Shift") {
            parts.append("⇧")
        }
        if selectedModifiers.contains("Command") {
            parts.append("⌘")
        }

        parts.append(selectedKey)
        return parts.joined()
    }

    private func saveHotkey() {
        var modifierFlags: UInt32 = 0

        if selectedModifiers.contains("Control") {
            modifierFlags |= UInt32(controlKey)
        }
        if selectedModifiers.contains("Option") {
            modifierFlags |= UInt32(optionKey)
        }
        if selectedModifiers.contains("Shift") {
            modifierFlags |= UInt32(shiftKey)
        }
        if selectedModifiers.contains("Command") {
            modifierFlags |= UInt32(cmdKey)
        }

        let keyCode = keyToKeyCode(selectedKey)
        let config = HotkeyConfiguration(keyCode: keyCode, modifierFlags: modifierFlags)

        onSave(config)
    }

    private func keyToKeyCode(_ key: String) -> UInt16 {
        switch key {
        case "Space": return UInt16(kVK_Space)
        case "Return": return UInt16(kVK_Return)
        case "Tab": return UInt16(kVK_Tab)
        case "A": return UInt16(kVK_ANSI_A)
        case "B": return UInt16(kVK_ANSI_B)
        case "C": return UInt16(kVK_ANSI_C)
        // ... add all other keys
        default: return UInt16(kVK_Space)
        }
    }
}
```

- [ ] **Step 4: Update AppDelegate to use MenuBarController**

```swift
// VoiceMindMac/App/AppDelegate.swift
import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuBarController = MenuBarController()

        // Check permissions on launch
        if PermissionsManager.checkAccessibility() != .granted {
            PermissionsManager.showPermissionAlert(for: .accessibility)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Cleanup
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
```

- [ ] **Step 5: Commit macOS UI**

```bash
git add VoiceMindMac/
git commit -m "feat(macOS): add menu bar UI and pairing windows

- MenuBarController orchestrates all macOS components
- PairingWindow for displaying pairing code
- HotkeySettingsWindow for configuring hotkey
- AppDelegate integration
- Complete macOS app flow

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```


---

## Chunk 5: iOS Network Layer

### Task 11: iOS Bonjour Browser

**Files:**
- Create: `VoiceMindiOS/Network/BonjourBrowser.swift`
- Create: `VoiceMindiOS/Network/DiscoveredService.swift`

- [ ] **Step 1: Create DiscoveredService model**

```swift
// VoiceMindiOS/Network/DiscoveredService.swift
import Foundation

struct DiscoveredService: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: UInt16
}
```

- [ ] **Step 2: Implement BonjourBrowser**

```swift
// VoiceMindiOS/Network/BonjourBrowser.swift
import Foundation
import Network

protocol BonjourBrowserDelegate: AnyObject {
    func browser(_ browser: BonjourBrowser, didFindService service: DiscoveredService)
    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService)
}

class BonjourBrowser {
    weak var delegate: BonjourBrowserDelegate?

    private var browser: NWBrowser?
    private let serviceType = "_voicerelay._tcp"
    private var discoveredServices: [NWBrowser.Result.Endpoint: DiscoveredService] = [:]

    func start() {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Bonjour browser ready")
            case .failed(let error):
                print("Bonjour browser failed: \(error)")
            case .cancelled:
                print("Bonjour browser cancelled")
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleBrowseResults(results, changes: changes)
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        discoveredServices.removeAll()
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                resolveService(result)
            case .removed(let result):
                if let service = discoveredServices.removeValue(forKey: result.endpoint) {
                    delegate?.browser(self, didRemoveService: service)
                }
            default:
                break
            }
        }
    }

    private func resolveService(_ result: NWBrowser.Result) {
        guard case .service(let name, let type, let domain, _) = result.endpoint else {
            return
        }

        // Create connection to resolve endpoint
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let service = DiscoveredService(
                        name: name,
                        host: "\(host)",
                        port: port.rawValue
                    )
                    self?.discoveredServices[result.endpoint] = service
                    self?.delegate?.browser(self!, didFindService: service)
                }
                connection.cancel()
            }
        }

        connection.start(queue: .main)
    }
}
```

- [ ] **Step 3: Commit Bonjour browser**

```bash
git add VoiceMindiOS/Network/
git commit -m "feat(iOS): add Bonjour browser for service discovery

- BonjourBrowser for discovering Mac services
- DiscoveredService model
- Network.framework integration

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 12: iOS WebSocket Client

**Files:**
- Create: `VoiceMindiOS/Network/WebSocketClient.swift`
- Create: `VoiceMindiOS/Network/ReconnectionManager.swift`

- [ ] **Step 1: Add Starscream to iOS project**

In Xcode, VoiceMindiOS target:
- File → Add Package Dependencies
- Add: https://github.com/daltoniam/Starscream.git
- Version: 4.0.0+

- [ ] **Step 2: Implement ReconnectionManager**

```swift
// VoiceMindiOS/Network/ReconnectionManager.swift
import Foundation

class ReconnectionManager {
    private var currentDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 10.0
    private let backoffMultiplier: TimeInterval = 2.0

    private var reconnectTimer: Timer?
    private var onReconnect: (() -> Void)?

    func scheduleReconnect(onReconnect: @escaping () -> Void) {
        self.onReconnect = onReconnect

        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: currentDelay, repeats: false) { [weak self] _ in
            self?.onReconnect?()
            self?.increaseDelay()
        }

        print("Reconnecting in \(currentDelay)s")
    }

    func reset() {
        currentDelay = 1.0
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func increaseDelay() {
        currentDelay = min(currentDelay * backoffMultiplier, maxDelay)
    }
}
```

- [ ] **Step 3: Implement WebSocketClient**

```swift
// VoiceMindiOS/Network/WebSocketClient.swift
import Foundation
import Starscream
import SharedCore

protocol WebSocketClientDelegate: AnyObject {
    func client(_ client: WebSocketClient, didReceiveMessage message: MessageEnvelope)
    func client(_ client: WebSocketClient, didChangeState state: ConnectionState)
}

class WebSocketClient: NSObject {
    weak var delegate: WebSocketClientDelegate?

    private var socket: WebSocket?
    private let reconnectionManager = ReconnectionManager()

    private(set) var state: ConnectionState = .disconnected {
        didSet {
            delegate?.client(self, didChangeState: state)
        }
    }

    private var host: String?
    private var port: UInt16?

    func connect(to host: String, port: UInt16) {
        self.host = host
        self.port = port

        var request = URLRequest(url: URL(string: "ws://\(host):\(port)")!)
        request.timeoutInterval = 5

        let socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()

        self.socket = socket
        state = .connecting
    }

    func disconnect() {
        reconnectionManager.reset()
        socket?.disconnect()
        socket = nil
        state = .disconnected
    }

    func send(_ envelope: MessageEnvelope) {
        guard let socket = socket, socket.isConnected else {
            print("Cannot send message: not connected")
            return
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            socket.write(data: data)
        } catch {
            print("Failed to encode message: \(error)")
        }
    }

    private func attemptReconnect() {
        guard let host = host, let port = port else { return }

        reconnectionManager.scheduleReconnect { [weak self] in
            self?.connect(to: host, port: port)
        }
    }
}

extension WebSocketClient: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected:
            state = .connected
            reconnectionManager.reset()
            print("WebSocket connected")

        case .disconnected(let reason, let code):
            state = .disconnected
            print("WebSocket disconnected: \(reason) (code: \(code))")
            attemptReconnect()

        case .text(let text):
            if let data = text.data(using: .utf8) {
                handleMessage(data)
            }

        case .binary(let data):
            handleMessage(data)

        case .error(let error):
            state = .error(error ?? NSError(domain: "WebSocketClient", code: -1))
            print("WebSocket error: \(String(describing: error))")
            attemptReconnect()

        default:
            break
        }
    }

    private func handleMessage(_ data: Data) {
        do {
            let envelope = try JSONDecoder().decode(MessageEnvelope.self, from: data)
            delegate?.client(self, didReceiveMessage: envelope)
        } catch {
            print("Failed to decode message: \(error)")
        }
    }
}
```

- [ ] **Step 4: Commit WebSocket client**

```bash
git add VoiceMindiOS/Network/
git commit -m "feat(iOS): add WebSocket client with reconnection

- WebSocketClient with Starscream
- ReconnectionManager with exponential backoff
- Automatic reconnection on disconnect

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 13: iOS Connection Manager

**Files:**
- Create: `VoiceMindiOS/Network/ConnectionManager.swift`

- [ ] **Step 1: Implement iOS ConnectionManager**

```swift
// VoiceMindiOS/Network/ConnectionManager.swift
import Foundation
import SharedCore
import CryptoKit

protocol ConnectionManagerDelegate: AnyObject {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState)
    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState)
    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope)
}

class ConnectionManager: NSObject {
    weak var delegate: ConnectionManagerDelegate?

    private let client = WebSocketClient()
    private var hmacValidator: HMACValidator?

    private let keychainService = "com.voicerelay.ios"
    private let keychainAccount = "pairing"
    private let deviceId = UUID().uuidString

    private(set) var pairingState: PairingState = .unpaired {
        didSet {
            delegate?.connectionManager(self, didChangePairingState: pairingState)
        }
    }

    private var heartbeatTimer: Timer?
    private var pongTimer: Timer?
    private var currentPingNonce: String?

    override init() {
        super.init()
        client.delegate = self
        loadPairing()
    }

    func connect(to service: DiscoveredService) {
        client.connect(to: service.host, port: service.port)
    }

    func disconnect() {
        stopHeartbeat()
        client.disconnect()
    }

    func pair(with service: DiscoveredService, code: String) {
        connect(to: service)

        // Send pair confirm
        let payload = PairConfirmPayload(
            shortCode: code,
            iosName: UIDevice.current.name,
            iosId: deviceId
        )

        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .pairConfirm,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: nil
        )

        client.send(envelope)
    }

    func unpair() {
        try? KeychainManager.delete(service: keychainService, account: keychainAccount)
        hmacValidator = nil
        pairingState = .unpaired
        disconnect()
    }

    func send(_ envelope: MessageEnvelope) {
        client.send(envelope)
    }

    private func loadPairing() {
        do {
            let pairing = try KeychainManager.retrievePairing(service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: pairing.sharedSecret)
            pairingState = .paired(deviceId: pairing.deviceId, deviceName: pairing.deviceName)
        } catch {
            pairingState = .unpaired
        }
    }

    private func handlePairSuccess(_ payload: PairSuccessPayload, macId: String, macName: String) {
        // Save pairing
        let pairing = PairingData(
            deviceId: macId,
            deviceName: macName,
            sharedSecret: payload.sharedSecret
        )

        do {
            try KeychainManager.savePairing(pairing, service: keychainService, account: keychainAccount)
            hmacValidator = HMACValidator(sharedSecret: payload.sharedSecret)
            pairingState = .paired(deviceId: macId, deviceName: macName)

            startHeartbeat()
        } catch {
            print("Failed to save pairing: \(error)")
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        pongTimer?.invalidate()
        pongTimer = nil
    }

    private func sendPing() {
        let nonce = UUID().uuidString
        currentPingNonce = nonce

        let payload = PingPayload(nonce: nonce)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .ping,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: hmacValidator?.generateHMACForEnvelope(
                type: .ping,
                payload: payloadData,
                timestamp: Date(),
                deviceId: deviceId
            )
        )

        client.send(envelope)

        // Start pong timeout
        pongTimer?.invalidate()
        pongTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.handlePongTimeout()
        }
    }

    private func handlePongTimeout() {
        print("Pong timeout, reconnecting...")
        client.disconnect()
    }

    private func sendError(code: String, message: String) {
        let payload = ErrorPayload(code: code, message: message)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .error,
            payload: payloadData,
            timestamp: Date(),
            deviceId: deviceId,
            hmac: hmacValidator?.generateHMACForEnvelope(
                type: .error,
                payload: payloadData,
                timestamp: Date(),
                deviceId: deviceId
            )
        )

        client.send(envelope)
    }
}

extension ConnectionManager: WebSocketClientDelegate {
    func client(_ client: WebSocketClient, didReceiveMessage message: MessageEnvelope) {
        // Handle pairing messages without HMAC
        if message.type == .pairSuccess {
            guard let payload = try? JSONDecoder().decode(PairSuccessPayload.self, from: message.payload) else {
                return
            }
            // Extract Mac name from previous context (would need to store from discovery)
            handlePairSuccess(payload, macId: message.deviceId, macName: "Mac")
            return
        }

        // Validate HMAC for all other messages
        guard let validator = hmacValidator else {
            print("Received message but not paired")
            return
        }

        guard validator.validateEnvelopeHMAC(message) else {
            print("HMAC validation failed")
            return
        }

        // Handle pong
        if message.type == .pong {
            guard let payload = try? JSONDecoder().decode(PongPayload.self, from: message.payload) else {
                return
            }

            if payload.nonce == currentPingNonce {
                pongTimer?.invalidate()
                pongTimer = nil
            }
            return
        }

        // Forward validated message to delegate
        delegate?.connectionManager(self, didReceiveMessage: message)
    }

    func client(_ client: WebSocketClient, didChangeState state: ConnectionState) {
        delegate?.connectionManager(self, didChangeConnectionState: state)

        if case .connected = state, case .paired = pairingState {
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }
}
```

- [ ] **Step 2: Commit iOS connection manager**

```bash
git add VoiceMindiOS/Network/
git commit -m "feat(iOS): add connection manager with pairing and heartbeat

- ConnectionManager for iOS
- Pairing flow with code submission
- Heartbeat with ping/pong
- HMAC validation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 6: iOS Speech Recognition

### Task 14: iOS Speech Controller

**Files:**
- Create: `VoiceMindiOS/Speech/SpeechController.swift`
- Create: `VoiceMindiOS/Speech/RecognitionState.swift`

- [ ] **Step 1: Create RecognitionState enum**

```swift
// VoiceMindiOS/Speech/RecognitionState.swift
import Foundation

enum RecognitionState {
    case idle
    case listening
    case processing
    case sending
}
```

- [ ] **Step 2: Implement SpeechController**

```swift
// VoiceMindiOS/Speech/SpeechController.swift
import Foundation
import Speech
import AVFoundation

protocol SpeechControllerDelegate: AnyObject {
    func speechController(_ controller: SpeechController, didChangeState state: RecognitionState)
    func speechController(_ controller: SpeechController, didRecognizeText text: String, language: String)
    func speechController(_ controller: SpeechController, didFailWithError error: Error)
}

class SpeechController: NSObject {
    weak var delegate: SpeechControllerDelegate?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    private var currentSessionId: String?
    private var finalResultTimer: Timer?

    private(set) var state: RecognitionState = .idle {
        didSet {
            delegate?.speechController(self, didChangeState: state)
        }
    }

    var selectedLanguage: String = "zh-CN" {
        didSet {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
        }
    }

    override init() {
        super.init()
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage))
    }

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
            guard micGranted else {
                completion(false)
                return
            }

            // Request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        }
    }

    func checkPermissions() -> Bool {
        let micGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        let speechGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        return micGranted && speechGranted
    }

    func startListening(sessionId: String) {
        guard checkPermissions() else {
            delegate?.speechController(self, didFailWithError: NSError(domain: "SpeechController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Permissions not granted"]))
            return
        }

        currentSessionId = sessionId

        do {
            try startRecognition()
            state = .listening
        } catch {
            delegate?.speechController(self, didFailWithError: error)
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        state = .processing

        // Wait up to 2 seconds for final result
        finalResultTimer?.invalidate()
        finalResultTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.finishRecognition()
        }
    }

    private func startRecognition() throws {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "SpeechController", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Create recognition task
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                // Store latest result
                if result.isFinal {
                    self.handleFinalResult(result.bestTranscription.formattedString)
                }
            }

            if let error = error {
                self.delegate?.speechController(self, didFailWithError: error)
                self.cleanup()
            }
        }

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func handleFinalResult(_ text: String) {
        finalResultTimer?.invalidate()
        finishRecognition(with: text)
    }

    private func finishRecognition(with text: String? = nil) {
        guard let sessionId = currentSessionId else { return }

        state = .sending

        let finalText = text ?? recognitionTask?.result?.bestTranscription.formattedString ?? ""

        delegate?.speechController(self, didRecognizeText: finalText, language: selectedLanguage)

        cleanup()
        currentSessionId = nil
        state = .idle
    }

    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask = nil
        finalResultTimer?.invalidate()
        finalResultTimer = nil
    }
}
```

- [ ] **Step 3: Commit speech controller**

```bash
git add VoiceMindiOS/Speech/
git commit -m "feat(iOS): add speech recognition controller

- SpeechController with SFSpeechRecognizer
- Support for Chinese and English
- Permission handling
- Final result extraction with timeout

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```


---

## Chunk 7: iOS UI & Integration

### Task 15: iOS Main View

**Files:**
- Create: `VoiceMindiOS/Views/ContentView.swift`
- Create: `VoiceMindiOS/Views/PairingView.swift`
- Create: `VoiceMindiOS/Views/SettingsView.swift`

- [ ] **Step 1: Implement ContentView**

```swift
// VoiceMindiOS/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Connection Status Card
                ConnectionStatusCard(
                    pairingState: viewModel.pairingState,
                    connectionState: viewModel.connectionState
                )

                // Recognition Status
                RecognitionStatusView(state: viewModel.recognitionState)

                Spacer()

                // Actions
                if case .unpaired = viewModel.pairingState {
                    Button("Pair with Mac") {
                        viewModel.showPairingView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                // Settings
                NavigationLink("Settings") {
                    SettingsView(viewModel: viewModel)
                }
            }
            .padding()
            .navigationTitle("VoiceMind")
            .sheet(isPresented: $viewModel.showPairingView) {
                PairingView(viewModel: viewModel)
            }
        }
    }
}

struct ConnectionStatusCard: View {
    let pairingState: PairingState
    let connectionState: ConnectionState

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.headline)

                Spacer()
            }

            if case .paired(_, let deviceName) = pairingState {
                HStack {
                    Text("Paired with: \(deviceName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return .gray
        case (.paired, .connected):
            return .green
        case (.paired, _):
            return .yellow
        default:
            return .gray
        }
    }

    private var statusText: String {
        switch (pairingState, connectionState) {
        case (.unpaired, _):
            return "Unpaired"
        case (.paired, .connected):
            return "Connected"
        case (.paired, .connecting):
            return "Connecting..."
        case (.paired, .disconnected):
            return "Disconnected"
        default:
            return "Unknown"
        }
    }
}

struct RecognitionStatusView: View {
    let state: RecognitionState

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(iconColor)

            Text(statusText)
                .font(.title2)
                .fontWeight(.medium)

            if state == .listening {
                WaveformView()
                    .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var iconName: String {
        switch state {
        case .idle:
            return "mic.circle"
        case .listening:
            return "mic.circle.fill"
        case .processing:
            return "waveform.circle"
        case .sending:
            return "arrow.up.circle.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .idle:
            return .gray
        case .listening:
            return .red
        case .processing:
            return .blue
        case .sending:
            return .green
        }
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "Ready to listen"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .sending:
            return "Sending result..."
        }
    }
}

struct WaveformView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2

                path.move(to: CGPoint(x: 0, y: midHeight))

                for x in stride(from: 0, through: width, by: 1) {
                    let relativeX = x / width
                    let sine = sin((relativeX + phase) * .pi * 4)
                    let y = midHeight + sine * (height / 4)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.red, lineWidth: 2)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
```

- [ ] **Step 2: Implement PairingView**

```swift
// VoiceMindiOS/Views/PairingView.swift
import SwiftUI

struct PairingView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var enteredCode = ""
    @State private var selectedService: DiscoveredService?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if viewModel.discoveredServices.isEmpty {
                    ProgressView("Searching for Macs...")
                        .padding()
                } else {
                    List(viewModel.discoveredServices) { service in
                        Button(action: {
                            selectedService = service
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(service.name)
                                        .font(.headline)
                                    Text("\(service.host):\(service.port)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedService?.id == service.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                if selectedService != nil {
                    VStack(spacing: 15) {
                        Text("Enter pairing code from Mac:")
                            .font(.headline)

                        TextField("000000", text: $enteredCode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 200)

                        Button("Pair") {
                            if let service = selectedService, enteredCode.count == 6 {
                                viewModel.pair(with: service, code: enteredCode)
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(enteredCode.count != 6)
                    }
                    .padding()
                }
            }
            .navigationTitle("Pair with Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.startDiscovery()
            }
            .onDisappear {
                viewModel.stopDiscovery()
            }
        }
    }
}
```

- [ ] **Step 3: Implement SettingsView**

```swift
// VoiceMindiOS/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        Form {
            Section("Language") {
                Picker("Recognition Language", selection: $viewModel.selectedLanguage) {
                    Text("Chinese (Mandarin)").tag("zh-CN")
                    Text("English").tag("en-US")
                }
            }

            Section("Pairing") {
                if case .paired(_, let deviceName) = viewModel.pairingState {
                    HStack {
                        Text("Paired Mac")
                        Spacer()
                        Text(deviceName)
                            .foregroundColor(.secondary)
                    }

                    Button("Unpair", role: .destructive) {
                        viewModel.unpair()
                    }
                }
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Microphone",
                    isGranted: viewModel.microphoneGranted
                )

                PermissionRow(
                    title: "Speech Recognition",
                    isGranted: viewModel.speechRecognitionGranted
                )

                PermissionRow(
                    title: "Local Network",
                    isGranted: true // Auto-prompted by system
                )

                if !viewModel.microphoneGranted || !viewModel.speechRecognitionGranted {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                Text("Keep this app in the foreground for voice recognition to work.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}

struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
    }
}
```

- [ ] **Step 4: Implement ContentViewModel**

```swift
// VoiceMindiOS/Views/ContentViewModel.swift
import Foundation
import Combine
import SharedCore

class ContentViewModel: ObservableObject {
    @Published var pairingState: PairingState = .unpaired
    @Published var connectionState: ConnectionState = .disconnected
    @Published var recognitionState: RecognitionState = .idle
    @Published var discoveredServices: [DiscoveredService] = []
    @Published var showPairingView = false
    @Published var selectedLanguage = "zh-CN" {
        didSet {
            speechController.selectedLanguage = selectedLanguage
            UserDefaults.standard.set(selectedLanguage, forKey: "selectedLanguage")
        }
    }
    @Published var microphoneGranted = false
    @Published var speechRecognitionGranted = false

    private let connectionManager = ConnectionManager()
    private let speechController = SpeechController()
    private let bonjourBrowser = BonjourBrowser()

    private var currentSessionId: String?

    init() {
        setupManagers()
        loadSettings()
        checkPermissions()
    }

    private func setupManagers() {
        connectionManager.delegate = self
        speechController.delegate = self
        bonjourBrowser.delegate = self
    }

    private func loadSettings() {
        if let language = UserDefaults.standard.string(forKey: "selectedLanguage") {
            selectedLanguage = language
        }
    }

    private func checkPermissions() {
        speechController.requestPermissions { [weak self] granted in
            self?.microphoneGranted = granted
            self?.speechRecognitionGranted = granted
        }
    }

    func startDiscovery() {
        bonjourBrowser.start()
    }

    func stopDiscovery() {
        bonjourBrowser.stop()
    }

    func pair(with service: DiscoveredService, code: String) {
        connectionManager.pair(with: service, code: code)
    }

    func unpair() {
        connectionManager.unpair()
    }
}

extension ContentViewModel: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangePairingState state: PairingState) {
        DispatchQueue.main.async {
            self.pairingState = state
        }
    }

    func connectionManager(_ manager: ConnectionManager, didChangeConnectionState state: ConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
        }
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveMessage envelope: MessageEnvelope) {
        switch envelope.type {
        case .startListen:
            handleStartListen(envelope)
        case .stopListen:
            handleStopListen(envelope)
        default:
            break
        }
    }

    private func handleStartListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StartListenPayload.self, from: envelope.payload) else {
            return
        }

        currentSessionId = payload.sessionId
        speechController.startListening(sessionId: payload.sessionId)
    }

    private func handleStopListen(_ envelope: MessageEnvelope) {
        guard let payload = try? JSONDecoder().decode(StopListenPayload.self, from: envelope.payload) else {
            return
        }

        guard payload.sessionId == currentSessionId else {
            return
        }

        speechController.stopListening()
    }
}

extension ContentViewModel: SpeechControllerDelegate {
    func speechController(_ controller: SpeechController, didChangeState state: RecognitionState) {
        DispatchQueue.main.async {
            self.recognitionState = state
        }
    }

    func speechController(_ controller: SpeechController, didRecognizeText text: String, language: String) {
        guard let sessionId = currentSessionId else { return }

        let payload = ResultPayload(sessionId: sessionId, text: text, language: language)
        guard let payloadData = try? JSONEncoder().encode(payload) else { return }

        let envelope = MessageEnvelope(
            type: .result,
            payload: payloadData,
            timestamp: Date(),
            deviceId: connectionManager.deviceId,
            hmac: connectionManager.hmacValidator?.generateHMACForEnvelope(
                type: .result,
                payload: payloadData,
                timestamp: Date(),
                deviceId: connectionManager.deviceId
            )
        )

        connectionManager.send(envelope)
        currentSessionId = nil
    }

    func speechController(_ controller: SpeechController, didFailWithError error: Error) {
        print("Speech recognition error: \(error)")

        if let sessionId = currentSessionId {
            let payload = ErrorPayload(code: "recognition_failed", message: error.localizedDescription)
            guard let payloadData = try? JSONEncoder().encode(payload) else { return }

            let envelope = MessageEnvelope(
                type: .error,
                payload: payloadData,
                timestamp: Date(),
                deviceId: connectionManager.deviceId,
                hmac: connectionManager.hmacValidator?.generateHMACForEnvelope(
                    type: .error,
                    payload: payloadData,
                    timestamp: Date(),
                    deviceId: connectionManager.deviceId
                )
            )

            connectionManager.send(envelope)
            currentSessionId = nil
        }
    }
}

extension ContentViewModel: BonjourBrowserDelegate {
    func browser(_ browser: BonjourBrowser, didFindService service: DiscoveredService) {
        DispatchQueue.main.async {
            if !self.discoveredServices.contains(where: { $0.id == service.id }) {
                self.discoveredServices.append(service)
            }
        }
    }

    func browser(_ browser: BonjourBrowser, didRemoveService service: DiscoveredService) {
        DispatchQueue.main.async {
            self.discoveredServices.removeAll { $0.id == service.id }
        }
    }
}
```

- [ ] **Step 5: Update iOS App entry point**

```swift
// VoiceMindiOS/App/VoiceMindiOSApp.swift
import SwiftUI

@main
struct VoiceMindiOSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 6: Add required Info.plist entries**

Add to VoiceMindiOS/Info.plist:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>VoiceMind needs microphone access for voice recognition.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>VoiceMind needs speech recognition to convert your voice to text.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>VoiceMind needs local network access to connect to your Mac.</string>
<key>NSBonjourServices</key>
<array>
    <string>_voicerelay._tcp</string>
</array>
```

- [ ] **Step 7: Commit iOS UI**

```bash
git add VoiceMindiOS/
git commit -m "feat(iOS): add complete UI and integration

- ContentView with connection and recognition status
- PairingView for Mac discovery and code entry
- SettingsView for language and permissions
- ContentViewModel orchestrating all components
- Info.plist permissions

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Chunk 8: Documentation & Final Integration

### Task 16: README and Documentation

**Files:**
- Create: `README.md`
- Create: `docs/MANUAL_TESTING.md`

- [ ] **Step 1: Create README**

```markdown
# VoiceMind (语灵)

Voice-to-text input system for macOS using iPhone speech recognition.

## Features

- **Push-to-talk**: Press and hold hotkey on Mac to start recognition
- **Instant text injection**: Recognized text appears in focused input field
- **Secure pairing**: One Mac paired with one iPhone
- **Local network**: No internet required, works on same WiFi/LAN
- **Bilingual**: Supports Chinese (Mandarin) and English

## Requirements

- **macOS**: 13.0 or later
- **iOS**: 18.0 or later
- **Network**: Both devices on same WiFi/LAN

## Setup

### macOS App

1. Open `VoiceMind.xcworkspace` in Xcode
2. Select `VoiceMindMac` scheme
3. Build and run
4. Grant Accessibility permission when prompted:
   - System Settings → Privacy & Security → Accessibility
   - Enable VoiceMindMac

### iOS App

1. Select `VoiceMindiOS` scheme
2. Build and run on your iPhone
3. Grant permissions when prompted:
   - Microphone
   - Speech Recognition
   - Local Network (auto-prompted)

## Pairing

1. On Mac: Click menu bar icon → "Start Pairing..."
2. Mac displays 6-digit code
3. On iPhone: Tap "Pair with Mac"
4. Select your Mac from discovered devices
5. Enter the 6-digit code
6. Wait for "Connected" status

## Usage

1. Ensure iPhone app is in foreground
2. Press and hold hotkey on Mac (default: Option+Space)
3. Speak into iPhone
4. Release hotkey when done
5. Text appears in focused input field on Mac

## Hotkey Configuration

1. Click menu bar icon → "Hotkey Settings..."
2. Select modifiers (Control, Option, Shift, Command)
3. Select key
4. Click "Save"

## Language Selection

1. On iPhone: Settings tab
2. Select "Chinese (Mandarin)" or "English"
3. Language applies to next recognition session

## Troubleshooting

### Text not injecting on Mac

- Check Accessibility permission is granted
- Try in different apps (TextEdit, Notes, Safari)
- If injection fails, use "Copy Text" button in alert

### iPhone not discovering Mac

- Ensure both devices on same WiFi network
- Check firewall settings on Mac
- Restart both apps

### Recognition not starting

- Keep iPhone app in foreground
- Check microphone permission on iPhone
- Check speech recognition permission on iPhone

### Stale results appearing

- This shouldn't happen due to session ID validation
- If it does, unpair and re-pair devices

## Architecture

- **SharedCore**: Swift package with protocol, security, models
- **VoiceMindMac**: macOS menu bar app with hotkey monitoring and text injection
- **VoiceMindiOS**: iOS app with speech recognition

### Network Protocol

- **Transport**: WebSocket over TCP
- **Discovery**: Bonjour/mDNS (`_voicerelay._tcp`)
- **Security**: HMAC-SHA256 message authentication after pairing

### Message Types

- `pairRequest`, `pairConfirm`, `pairSuccess`: Pairing flow
- `startListen`, `stopListen`: Recognition control
- `result`: Final recognized text
- `ping`, `pong`: Heartbeat
- `error`: Error notifications

## Development

### Building

```bash
# Open workspace
open VoiceMind.xcworkspace

# Build all targets
xcodebuild -workspace VoiceMind.xcworkspace -scheme VoiceMindMac
xcodebuild -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS
```

### Testing

```bash
# Run SharedCore tests
swift test --package-path SharedCore
```

See `docs/MANUAL_TESTING.md` for manual testing checklist.

## License

MIT License - see LICENSE file

## Credits

Built with:
- [Starscream](https://github.com/daltoniam/Starscream) - WebSocket library
- Apple CryptoKit - HMAC authentication
- Apple Speech Framework - Speech recognition
```

- [ ] **Step 2: Create manual testing guide**

```markdown
# Manual Testing Guide

## Prerequisites

- Mac running macOS 13.0+
- iPhone running iOS 18.0+
- Both devices on same WiFi network
- VoiceMindMac and VoiceMindiOS apps built and installed

## Test 1: Pairing Flow

**Steps:**
1. Launch VoiceMindMac
2. Click menu bar icon → "Start Pairing..."
3. Note the 6-digit code displayed
4. Launch VoiceMindiOS on iPhone
5. Tap "Pair with Mac"
6. Select Mac from discovered devices list
7. Enter 6-digit code
8. Tap "Pair"

**Expected:**
- Mac appears in discovered devices list within 5 seconds
- After entering code, both devices show "Paired" status
- Mac menu bar shows "Connected to [iPhone name]"
- iPhone shows "Connected" with Mac name

**Pass/Fail:** ___

## Test 2: Basic Hotkey Recognition

**Steps:**
1. Ensure devices are paired and connected
2. Open TextEdit on Mac
3. Create new document
4. Press and hold Option+Space
5. Speak "Hello world" into iPhone
6. Release Option+Space
7. Wait 2 seconds

**Expected:**
- iPhone shows "Listening..." when hotkey pressed
- iPhone shows "Processing..." when hotkey released
- Text "Hello world" appears in TextEdit
- iPhone returns to "Ready to listen"

**Pass/Fail:** ___

## Test 3: Session Isolation

**Steps:**
1. Open TextEdit on Mac
2. Press and hold Option+Space
3. Speak "First test"
4. Release Option+Space
5. Immediately press and hold Option+Space again
6. Speak "Second test"
7. Release Option+Space

**Expected:**
- Only "Second test" appears in TextEdit
- "First test" is discarded (session invalidated)

**Pass/Fail:** ___

## Test 4: Reconnection

**Steps:**
1. Ensure devices are paired and connected
2. On iPhone: Disable WiFi
3. Wait 5 seconds
4. On iPhone: Enable WiFi
5. Wait 10 seconds

**Expected:**
- Mac shows "Disconnected" when WiFi disabled
- iPhone shows "Reconnecting..."
- Both devices show "Connected" within 10 seconds after WiFi enabled
- No re-pairing required

**Pass/Fail:** ___

## Test 5: Permission Denied

**Steps:**
1. On Mac: System Settings → Privacy & Security → Accessibility
2. Disable VoiceMindMac
3. Press Option+Space hotkey
4. Speak into iPhone

**Expected:**
- Hotkey does not trigger recognition (no "Listening..." on iPhone)
- Mac shows warning about missing Accessibility permission
- No crash

**Pass/Fail:** ___

## Test 6: Text Injection in Multiple Apps

**Steps:**
1. Test in each app:
   - TextEdit
   - Notes
   - Safari address bar
   - VS Code (if installed)
2. For each app:
   - Focus input field
   - Press Option+Space
   - Speak "Test in [app name]"
   - Release Option+Space

**Expected:**
- Text appears correctly in all apps
- Special characters and spaces preserved

**Pass/Fail:** ___

## Test 7: Long Text

**Steps:**
1. Open TextEdit
2. Press Option+Space
3. Speak continuously for 10 seconds (100+ characters)
4. Release Option+Space

**Expected:**
- All spoken text appears in TextEdit
- No truncation
- Text injection completes within 5 seconds

**Pass/Fail:** ___

## Test 8: Language Switching

**Steps:**
1. On iPhone: Settings → Language → Select "English"
2. Press Option+Space on Mac
3. Speak "Hello world" in English
4. Release Option+Space
5. On iPhone: Settings → Language → Select "Chinese (Mandarin)"
6. Press Option+Space on Mac
7. Speak "你好世界" in Chinese
8. Release Option+Space

**Expected:**
- English text recognized correctly
- Chinese text recognized correctly
- Language setting persists across app restarts

**Pass/Fail:** ___

## Test 9: Unpair

**Steps:**
1. Ensure devices are paired
2. On Mac: Menu bar → "Unpair Device"
3. Confirm unpair
4. Check iPhone status

**Expected:**
- Mac shows "Unpaired"
- iPhone shows "Unpaired"
- Pressing hotkey does not trigger recognition
- iPhone can pair again with same Mac

**Pass/Fail:** ___

## Test 10: Security - Unpaired Device

**Steps:**
1. Ensure Mac is unpaired
2. On iPhone: Attempt to connect to Mac
3. Try sending commands without pairing

**Expected:**
- Commands rejected by Mac
- Mac shows error or ignores messages
- No text injection occurs

**Pass/Fail:** ___

## Summary

Total tests: 10
Passed: ___
Failed: ___

## Notes

[Add any observations, issues, or additional testing notes here]
```

- [ ] **Step 3: Commit documentation**

```bash
git add README.md docs/MANUAL_TESTING.md
git commit -m "docs: add README and manual testing guide

- Complete setup and usage instructions
- Architecture overview
- Troubleshooting guide
- Manual testing checklist

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Task 17: Final Integration and Build Verification

**Files:**
- Verify: All project files compile
- Verify: All dependencies resolved

- [ ] **Step 1: Clean build macOS app**

```bash
xcodebuild clean -workspace VoiceMind.xcworkspace -scheme VoiceMindMac
xcodebuild build -workspace VoiceMind.xcworkspace -scheme VoiceMindMac
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Clean build iOS app**

```bash
xcodebuild clean -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS
xcodebuild build -workspace VoiceMind.xcworkspace -scheme VoiceMindiOS -destination 'platform=iOS Simulator,name=iPhone 15'
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run SharedCore tests**

```bash
swift test --package-path SharedCore
```

Expected: All tests pass

- [ ] **Step 4: Verify project structure**

```bash
tree -L 3 -I 'build|DerivedData'
```

Expected: Matches design spec directory structure

- [ ] **Step 5: Create final commit**

```bash
git add .
git commit -m "chore: final integration and build verification

- All targets build successfully
- All tests pass
- Project structure verified
- Ready for manual testing

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Implementation Complete

The plan is now complete. To execute:

1. **Use superpowers:subagent-driven-development** (if subagents available)
2. **Or use superpowers:executing-plans** (if no subagents)

Each task should be executed in order, with all steps completed and verified before moving to the next task.

After implementation, follow the manual testing guide in `docs/MANUAL_TESTING.md` to verify all acceptance criteria.

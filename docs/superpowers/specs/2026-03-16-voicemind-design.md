# VoiceMind (语灵) Design Specification

**Date:** 2026-03-16
**Version:** 1.0
**Status:** Draft

## Overview

VoiceMind is a macOS + iOS companion system that enables voice-to-text input on Mac using iPhone's speech recognition. The user presses a configurable hotkey on Mac, speaks into their iPhone, releases the hotkey, and the recognized text is injected into the currently focused input field on Mac.

**Key Characteristics:**
- Push-to-talk: Hotkey press starts recognition, release stops and sends result
- Single device pairing: One Mac paired with one iPhone
- Local network only: Same WiFi/LAN required
- Foreground iOS app: iPhone app must be active (no background/lock screen support in MVP)
- Keyboard simulation: Text injected via CGEvent, not clipboard paste

## Project Structure

### Xcode Workspace: VoiceRelay.xcworkspace

Three targets:

1. **VoiceRelayMac** - macOS menu bar application
   - Platform: macOS 13.0+
   - UI: AppKit (menu bar) + SwiftUI (settings/pairing windows)
   - Capabilities: Network, Keychain

2. **VoiceRelayiOS** - iOS application
   - Platform: iOS 18.0+
   - UI: SwiftUI
   - Capabilities: Microphone, Speech Recognition, Local Network, Keychain

3. **SharedCore** - Swift Package
   - Shared protocol definitions
   - Security utilities (HMAC, key derivation)
   - Common models and state machine

### Dependencies

- **Starscream** (~4.0): WebSocket client/server for both platforms
- **CryptoKit**: Built-in framework for HMAC authentication
- **Network.framework**: Built-in framework for Bonjour discovery

### Directory Structure

```
VoiceRelay/
├── VoiceRelay.xcworkspace
├── VoiceRelayMac/
│   ├── App/                    # AppDelegate, main entry
│   ├── MenuBar/                # NSStatusItem, menu management
│   ├── Hotkey/                 # CGEventTap hotkey monitoring
│   ├── TextInjection/          # CGEvent text injection
│   ├── Network/                # WebSocket server, Bonjour publisher
│   ├── Pairing/                # Pairing UI and logic
│   └── Permissions/            # Accessibility permission checks
├── VoiceRelayiOS/
│   ├── App/                    # App entry, lifecycle
│   ├── Views/                  # SwiftUI views
│   ├── Speech/                 # SFSpeechRecognizer integration
│   ├── Network/                # WebSocket client, Bonjour browser
│   └── Pairing/                # Pairing UI and logic
├── SharedCore/
│   ├── Sources/SharedCore/
│   │   ├── Protocol/           # Message types, envelope
│   │   ├── Security/           # HMAC, key management
│   │   └── Models/             # Shared data models
└── docs/
    └── superpowers/specs/      # Design documents
```

## Protocol & Security

### Network Architecture

- **Discovery**: Bonjour/mDNS (`_voicerelay._tcp` service)
- **Transport**: WebSocket over TCP
- **Authentication**: HMAC-SHA256 message authentication after pairing

### Message Protocol

All messages wrapped in `MessageEnvelope`:

```swift
struct MessageEnvelope: Codable {
    let type: MessageType
    let payload: Data           // JSON-encoded specific message
    let timestamp: Date
    let deviceId: String        // Sender's device ID
    let hmac: String?           // HMAC-SHA256, present after pairing
}
```

### Message Types

| Type | Direction | Payload | Purpose |
|------|-----------|---------|---------|
| `pairRequest` | Mac → iPhone | `{ shortCode: String, macName: String, macId: String }` | Initiate pairing |
| `pairConfirm` | iPhone → Mac | `{ shortCode: String, iosName: String, iosId: String }` | Confirm pairing code |
| `pairSuccess` | Mac → iPhone | `{ sharedSecret: String }` | Complete pairing, share key |
| `startListen` | Mac → iPhone | `{ sessionId: String }` | Begin speech recognition |
| `stopListen` | Mac → iPhone | `{ sessionId: String }` | Stop recognition, send result |
| `result` | iPhone → Mac | `{ sessionId: String, text: String, language: String }` | Final recognized text |
| `ping` | Either | `{ nonce: String }` | Heartbeat |
| `pong` | Either | `{ nonce: String }` | Heartbeat response |
| `error` | Either | `{ code: String, message: String }` | Error notification |

### Security Model

**Pairing Phase (unencrypted, time-limited):**

1. Mac generates 6-digit numeric code + UUID deviceId
2. Mac shows code in pairing window (2-minute timeout)
3. iPhone discovers Mac via Bonjour, connects to WebSocket
4. iPhone sends `pairConfirm` with code + its deviceId
5. Mac validates code, generates 32-byte shared secret (CryptoKit random)
6. Mac sends `pairSuccess` with shared secret
7. Both sides derive HMAC key from shared secret
8. Both persist to Keychain: `{ pairedDeviceId, hmacKey }`

**Post-Pairing (authenticated):**

- Every message includes HMAC-SHA256 of `(type + payload + timestamp + deviceId)` using shared key
- Receiver validates HMAC before processing message
- Messages without valid HMAC are rejected and logged
- Invalid HMAC may trigger unpair after threshold (e.g., 3 failures)

**State Machine:**

```
Unpaired → Pairing (2min timeout) → Paired
Paired → Connected (WebSocket active) / Disconnected
```

**Single Device Constraint:**

- Mac stores only one pairing at a time
- New pairing request while paired: Reject with error, require unpair first
- Unpair: Clear Keychain entry on both sides

## macOS Application Design

### Menu Bar UI

**NSStatusItem** with icon indicating state:
- Gray: Unpaired
- Yellow: Paired but disconnected
- Green: Connected

**Menu Items:**
- Status text (non-clickable): "Connected to iPhone" / "Disconnected" / "Unpaired"
- "Start Pairing..." → Opens pairing window
- "Hotkey Settings..." → Opens SwiftUI settings sheet
- "Permissions..." → Opens permissions check window
- "Unpair Device" (only visible when paired)
- "Quit"

### Pairing Window

- Large 6-digit code display
- Optional QR code: `voicerelay://pair?code=123456&ip=192.168.1.x&port=8080`
- Status text: "Waiting for iPhone..."
- Auto-closes on successful pairing or 2-minute timeout
- Cancel button to abort pairing

### Hotkey System

**Implementation: CGEventTap**

- `HotkeyMonitor` class manages CGEventTap lifecycle
- Default hotkey: Option+Space (configurable in settings)
- Requires Accessibility permission

**Behavior:**

1. **keyDown**:
   - Generate UUID sessionId
   - Send `startListen` message with sessionId
   - Show "Listening..." indicator (optional floating window or menu bar icon change)
   - Store sessionId as current active session

2. **keyUp**:
   - Send `stopListen` with same sessionId
   - Keep sessionId active, waiting for result
   - Start 30-second timeout

3. **Debouncing**:
   - Ignore press/release cycles shorter than 100ms
   - Prevents accidental triggers

**Session Tracking:**

- Only accept `result` messages matching current sessionId
- Ignore results with mismatched or nil sessionId (stale from previous sessions)
- Clear sessionId after successful injection or timeout

### Text Injection

**Implementation: CGEvent Unicode posting**

- `TextInjector` class handles text-to-CGEvent conversion
- Posts Unicode characters to system event stream
- Targets currently focused input field (no specific app targeting)

**Chunking for Long Text:**

- Split text into 500-character chunks
- 10ms delay between chunks to prevent UI blocking
- Progress indicator for long injections (optional)

**Failure Handling:**

- Validate Accessibility permission before injection
- On failure (secure input, permission denied, etc.):
  - Show NSAlert with error message
  - Provide "Copy Text" button (does not auto-copy to clipboard)
  - Log failure reason for debugging

### Network Layer

**WebSocketServer:**

- Wraps Starscream server
- Listens on random available port (range 8000-9000)
- Single client connection (reject additional connections when paired)

**BonjourPublisher:**

- Publishes `_voicerelay._tcp` service with:
  - Port number
  - TXT record: `{ version: "1.0", name: "<Mac Name>" }`

**ConnectionManager:**

- Handles WebSocket lifecycle (connect, disconnect, error)
- Routes incoming messages to appropriate handlers
- Validates HMAC on all post-pairing messages
- Manages pairing state persistence

### Permissions Manager

**Required Permissions:**

1. **Accessibility** (critical):
   - Required for CGEventTap hotkey monitoring
   - Required for CGEvent text injection
   - Check on app launch
   - Show alert with "Open System Settings" button if denied

2. **Input Monitoring** (if needed):
   - May be required depending on CGEventTap implementation
   - Check and prompt if necessary

**Graceful Degradation:**

- App runs without permissions but shows warnings
- Hotkey monitoring disabled without Accessibility
- Text injection shows error alert without Accessibility
- Connection and pairing still functional

## iOS Application Design

### Main UI (SwiftUI)

**Connection Status Card:**
- Shows paired Mac name when paired
- Connection state: Connected / Disconnected / Unpaired
- Green/yellow/gray indicator

**Status Indicator:**
- Large central display showing current state:
  - Idle: "Ready to listen"
  - Listening: "Listening..." with waveform animation
  - Processing: "Processing..."
  - Sending: "Sending result..."

**Language Selector:**
- Toggle between Chinese (Mandarin) and English
- Persisted to UserDefaults
- Applied to next recognition session

**Settings Section:**
- Paired Mac name + "Unpair" button
- Permissions status indicators:
  - Microphone: ✓ / ✗
  - Speech Recognition: ✓ / ✗
  - Local Network: ✓ / ✗
- "Open Settings" buttons for denied permissions
- Reminder: "Keep app in foreground for recognition"

### Speech Recognition

**SpeechController:**

- Manages `SFSpeechRecognizer` + `AVAudioEngine`
- Supports Chinese (Mandarin) and English locales
- Requests microphone and speech recognition permissions on first use

**Recognition Flow:**

1. **On `startListen` message**:
   - Check microphone permission (request if needed)
   - Configure audio session for recording
   - Start AVAudioEngine
   - Begin SFSpeechRecognizer with selected language
   - Update UI to "Listening"

2. **On `stopListen` message**:
   - Stop AVAudioEngine
   - Wait for final recognition result (up to 2 seconds)
   - Extract final transcription text
   - Send `result` message with sessionId + text + language
   - Update UI to "Sending" → "Idle"

3. **Error Handling**:
   - Recognition failure: Send `error` message to Mac
   - Permission denied: Show alert, update permissions UI
   - Timeout: Send partial result or error after 2 seconds

### Network Layer

**BonjourBrowser:**

- Discovers `_voicerelay._tcp` services on local network
- Resolves service to IP address and port
- Presents discovered Macs in pairing UI

**WebSocketClient:**

- Wraps Starscream client
- Connects to discovered Mac's WebSocket server
- Handles reconnection with exponential backoff

**ConnectionManager:**

- Manages WebSocket lifecycle
- Routes incoming messages to appropriate handlers
- Validates HMAC on all post-pairing messages
- Implements reconnection strategy

**Reconnection Strategy:**

- Exponential backoff: 1s, 2s, 4s, 8s, max 10s
- Reset backoff on successful connection
- Maintain pairing across reconnections (no re-pairing needed)

**Heartbeat:**

- Send `ping` every 30 seconds when connected
- Expect `pong` within 5 seconds
- Trigger reconnection if pong timeout

### Pairing Flow

1. User taps "Pair with Mac" button
2. App discovers Macs via Bonjour
3. User selects Mac from list
4. App shows 6-digit code entry sheet (numeric keyboard)
5. User enters code from Mac's pairing window
6. App sends `pairConfirm` message
7. App waits for `pairSuccess` response
8. On success: Store pairing to Keychain, update UI to "Paired"
9. On failure: Show error, allow retry

### Permissions

**Required Permissions:**

1. **Microphone**: Required for audio recording
2. **Speech Recognition**: Required for SFSpeechRecognizer
3. **Local Network**: Required for Bonjour discovery (auto-prompted by system)

**Permission Flow:**

- Check all permissions on app launch
- Show status in settings UI
- Request microphone on first recognition attempt
- Request speech recognition on first recognition attempt
- Show alerts with "Open Settings" button for denied permissions

## Data Flow & Error Handling

### Happy Path Flow

1. User presses hotkey (Option+Space) on Mac
2. Mac generates sessionId (UUID)
3. Mac sends `startListen` message via WebSocket
4. iPhone receives message, validates HMAC
5. iPhone starts audio recording and speech recognition
6. User speaks into iPhone
7. User releases hotkey on Mac
8. Mac sends `stopListen` with same sessionId
9. iPhone stops recording, waits for final recognition result
10. iPhone sends `result` with sessionId + text + language
11. Mac validates sessionId matches current session
12. Mac validates HMAC on result message
13. Mac injects text into focused input field via CGEvent
14. Mac shows brief success indicator
15. Mac clears sessionId

### Error Scenarios

| Error | Detection | Handling |
|-------|-----------|----------|
| WebSocket disconnected during session | Connection loss event | Mac shows "Disconnected", iPhone attempts reconnect, abandon current session |
| HMAC validation fails | Receiver checks HMAC | Reject message, log security warning, increment failure counter |
| Wrong sessionId in result | Mac checks sessionId != current | Ignore result (stale from previous session) |
| Speech recognition fails | SFSpeechRecognizer error | iPhone sends `error` message, shows alert |
| Text injection fails | CGEvent returns error | Mac shows alert with "Copy Text" button |
| Accessibility permission denied | Mac checks permission | Show warning, disable hotkey monitoring |
| Pairing timeout | Mac timer expires (2 min) | Close pairing window, discard code |
| Duplicate pairing attempt | Mac already paired | Reject with error, require unpair first |
| Heartbeat timeout | No pong within 5s | Trigger reconnection |
| Session timeout | No result within 30s | Mac clears sessionId, shows "No response" warning |

### Session Management

**Mac Side:**

- Track current sessionId (nil when idle)
- On keyDown: Set sessionId, start 30-second timeout
- On keyUp: Keep sessionId, waiting for result
- On result: Validate sessionId matches, then clear
- On timeout: Clear sessionId, show warning

**iPhone Side:**

- Track current sessionId (nil when idle)
- On `startListen`: Store sessionId, start recognition
- On `stopListen`: Validate sessionId matches, stop recognition
- On final result: Send with stored sessionId, clear

### Reconnection Strategy

**iPhone (active reconnection):**

- Exponential backoff: 1s, 2s, 4s, 8s, max 10s
- Reset backoff on successful connection
- Maintain pairing data across reconnections
- Show "Reconnecting..." in UI

**Mac (passive):**

- Wait for iPhone to reconnect
- Maintain pairing data
- Show "Disconnected" status in menu bar

**Heartbeat:**

- Send `ping` every 30 seconds when connected
- Expect `pong` within 5 seconds
- Detect silent disconnections (network issues without explicit close)

## Testing Strategy

### Unit Testing

**SharedCore:**
- Message encoding/decoding (Codable conformance)
- HMAC generation and validation
- Key derivation from shared secret

**macOS:**
- Hotkey combination parsing
- SessionId tracking and validation
- Text chunking logic for long strings

**iOS:**
- Speech recognition state machine
- Reconnection backoff calculation
- Language locale selection

### Integration Testing

**Pairing Flow:**
- Mac generates code → iPhone submits → Both store keys
- Verify Keychain persistence
- Verify HMAC validation works after pairing

**Message Flow:**
- Send each message type, verify HMAC validation
- Test with invalid HMAC, verify rejection
- Test with wrong deviceId, verify rejection

**Session Tracking:**
- Rapid press/release, verify only latest result accepted
- Send stale result, verify ignored
- Timeout scenario, verify session cleared

**Reconnection:**
- Kill WebSocket connection, verify iPhone reconnects
- Verify pairing persists across reconnection
- Verify no re-pairing required

### Manual Testing Checklist

1. ✓ **Pairing**: Mac shows code, iPhone enters code, both show "Paired"
2. ✓ **Hotkey**: Press Option+Space in TextEdit, speak, release, text appears
3. ✓ **Session isolation**: Press hotkey twice quickly, verify only latest result injects
4. ✓ **Reconnection**: Disable/enable WiFi on iPhone, verify reconnects without re-pairing
5. ✓ **Permission denied**: Disable Accessibility, verify warning shown, no crash
6. ✓ **Text injection**: Test in Safari address bar, Notes, TextEdit, VS Code
7. ✓ **Long text**: Speak 100+ characters, verify all text injects without truncation
8. ✓ **Language switching**: Toggle Chinese/English on iPhone, verify recognition language changes
9. ✓ **Unpair**: Unpair on Mac, verify iPhone shows "Unpaired", commands rejected
10. ✓ **Security**: Try sending commands from unpaired device, verify rejection

### Acceptance Criteria

From original requirements:

- ✓ Mac menu bar can configure hotkey (default Option+Space)
- ✓ Press and hold hotkey → iPhone starts recognition
- ✓ Release hotkey → iPhone stops and sends final text
- ✓ Text appears in focused input field (TextEdit, Notes, Safari, etc.)
- ✓ Rapid press/release doesn't inject stale results (sessionId validation)
- ✓ Missing Accessibility permission shows clear prompt, no crash
- ✓ Unpaired devices cannot control Mac (HMAC validation)
- ✓ Single device pairing enforced (Mac stores one pairing at a time)

### Performance Targets

- **Pairing**: Complete within 10 seconds
- **Hotkey to recognition start**: <500ms latency
- **Recognition stop to text injection**: <2 seconds end-to-end
- **Reconnection after network recovery**: <5 seconds

## Implementation Notes

### Critical Path Items

1. **CGEventTap reliability**: Ensure keyDown/keyUp detection works across macOS versions (13+)
2. **Accessibility permission flow**: Clear UI guidance, no crashes when denied
3. **HMAC validation**: Prevent unauthorized devices from sending commands
4. **SessionId tracking**: Prevent stale results from injecting
5. **Text injection**: Handle long text, special characters, emoji correctly

### Known Limitations (MVP)

- iPhone app must be in foreground (no background/lock screen support)
- Single device pairing only (no multi-device support)
- No partial result streaming (final text only)
- No voice profile/speaker recognition
- Local network only (no internet relay)

### Future Enhancements (Out of Scope)

- Background recognition on iPhone
- Multi-device pairing
- Partial result streaming with live preview
- Voice profile for speaker identification
- Cloud relay for different networks
- Dictation commands (punctuation, formatting)
- Custom vocabulary/corrections

## Deliverables

1. **Xcode Workspace**: VoiceRelay.xcworkspace with all three targets
2. **Source Code**: Organized by module as per directory structure
3. **README.md**: Setup instructions, pairing guide, permissions requirements
4. **Manual Testing Guide**: Step-by-step verification of acceptance criteria

## Success Criteria

The implementation is complete when:

1. All acceptance criteria pass manual testing
2. Pairing flow works reliably on same network
3. Push-to-talk (press/release) triggers recognition correctly
4. Text injection works in common macOS apps
5. Permission checks guide user through setup
6. Unpaired devices cannot control Mac
7. No crashes when permissions denied
8. Reconnection works after network interruption

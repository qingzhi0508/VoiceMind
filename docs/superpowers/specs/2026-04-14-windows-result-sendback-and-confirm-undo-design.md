# Windows: Recognition Result Send-Back and Confirm/Undo

**Date:** 2026-04-14
**Status:** Approved
**Scope:** VoiceMindWindows (Tauri/Rust backend)

## Problem

The Mac app sends ASR recognition results back to the iPhone and handles confirm/undo keyword messages. The Windows app lacks both features:

1. After Windows completes ASR, the result is only injected locally — the iPhone never sees it.
2. The iPhone sends `keyword` messages (confirm/undo) that Windows ignores.

## Goal

Match Mac behavior: after Windows ASR completes, send the result back to iPhone so it displays with confirm/undo buttons; handle those confirm/undo messages to simulate the corresponding keyboard actions.

## Design

### 1. Send Recognition Results Back to iPhone

**Trigger:** `handle_audio_end` in `network.rs`, after ASR produces a final result.

**Action:** Send a `result` message to the connected iPhone via the same TCP connection using `send_envelope_to_connection` (handles base64 payload encoding, HMAC signing, and 4-byte length-prefix framing).

**Payload struct** (already exists): `ResultPayload { session_id, text, language }`

**Flow:**
```
iPhone sends: audioStart → audioData... → audioEnd
Windows performs ASR (cloud or local)
  → On final result:
      1. Inject text into foreground window (existing)
      2. Send "result" envelope back to iPhone via send_envelope_to_connection with HMAC (new)
```

**Key details:**
- Must extract `secret_key` and `device_id` from the Connection to sign the outbound message (required by iOS HMAC validation).
- Use `windows_device_id()` as the sender device_id.
- `send_envelope_to_connection` handles base64 payload encoding, HMAC, and framing — reuse directly.
- No `partialResult` for now: current ASR (Volcengine/SAPI) is batch-mode, no streaming partial results available.

**Implementation in `network.rs`:**
- In `handle_audio_end`, after the existing injection/history/emitter block (lines 1188-1204), add a call to `send_envelope_to_connection` with `MessageType::Result` and a `ResultPayload`.
- Extract `secret_key` from the Connection (read lock) before sending.

### 2. Handle Confirm/Undo (Keyword Messages)

**Add `Keyword` variant to `MessageType` enum** in `network.rs` with:
- Enum: `Keyword`
- `as_str()`: `"keyword"`
- `from_str()`: `"keyword" => Some(Self::Keyword)`

**Add payload structs:**
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KeywordPayload {
    pub action: KeywordAction,
    pub session_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum KeywordAction {
    confirm,
    undo,
}
```

**Add match arm in `process_message`:**
```rust
MessageType::Keyword => handle_keyword(conn_id, envelope).await,
```

**New handler: `handle_keyword`**

| Action | iOS sends | Windows does |
|--------|-----------|-------------|
| `confirm` | `KeywordPayload { action: confirm, sessionId }` | `injection::simulate_return_key()` |
| `undo` | `KeywordPayload { action: undo, sessionId }` | `injection::simulate_undo()` |

**Implementation in `injection.rs`:**
- Add public functions `simulate_return_key()` and `simulate_undo()`.
- Both use `SendInput` with appropriate virtual key codes (same pattern as existing `send_ctrl_v`).
- `simulate_return_key`: single VK_RETURN key down + key up.
- `simulate_undo`: VK_CONTROL down + VK_Z down + VK_Z up + VK_CONTROL up (Ctrl+Z, Windows equivalent of Mac's Cmd+Z).

### 3. Files Changed

| File | Change |
|------|--------|
| `src-tauri/src/network.rs` | Add `Keyword` to `MessageType` enum + `as_str`/`from_str`; add `KeywordPayload`/`KeywordAction` structs; add `handle_keyword`; add `Keyword` match arm in `process_message`; in `handle_audio_end` send `result` back to iPhone |
| `src-tauri/src/injection.rs` | Add `simulate_return_key()` and `simulate_undo()` public functions |

### 4. Error Handling

- Sending `result` to iPhone: log failure, do not block local injection or event emission.
- Receiving unknown `keyword` action: log warning, ignore.
- No iPhone connected / connection not found: skip sending, only inject locally (current behavior).
- `simulate_return_key` / `simulate_undo` failure: log error (matches Mac behavior of silently attempting key simulation).

### 5. Message Protocol Consistency

All messages use the existing `Envelope` struct with:
- `type` field as string matching `MessageType::as_str()`
- `payload` field as base64-encoded JSON bytes (via `payload_base64` serde module)
- `hmac` field signed with the connection's `secret_key` (required for iOS validation)
- 4-byte big-endian length prefix framing

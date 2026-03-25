# VoiceMind Windows UI Redesign Specification

**Date:** 2026-03-24
**Status:** Draft

## 1. Overview

Replicate the VoiceMind Mac UI on Windows using Tauri. The Windows app is a Tauri 2.0 desktop application (Rust backend + HTML/JS frontend). The Mac version uses SwiftUI with a sidebar + content area layout. The Windows version will use HTML/CSS/JS with an identical layout and visual style.

**Scope:**
- Full frontend redesign with sidebar navigation (7 sections)
- New Rust backend Tauri commands for service control, inbound data records, and accessibility status
- i18n support for English and Chinese
- First-run guide modal

**Out of scope:**
- Local recording feature (Mac-only, requires macOS-specific audio APIs)
- Mac's native menu bar integration

---

## 2. Window & Layout

### Window Dimensions
- **Width:** 800px (fixed minimum)
- **Height:** ~700px (fixed minimum, resizable)
- **Decorations:** Standard window frame with native controls

### Layout Structure
```
┌──────────────────────────────────────────────────┐
│ ┌──────────────┐ ┌────────────────────────────┐│
│ │   SIDEBAR    │ │      CONTENT AREA          ││
│ │   (200px)    │ │      (~580px)               ││
│ │              │ │                            ││
│ │  [Brand]     │ │  [Page content based on    ││
│ │  VoiceMind   │ │   selected sidebar item]   ││
│ │              │ │                            ││
│ │  ─────────   │ │                            ││
│ │  Home        │ │                            ││
│ │  Records     │ │                            ││
│ │  Data        │ │                            ││
│ │  Speech      │ │                            ││
│ │  Permissions │ │                            ││
│ │              │ │                            ││
│ │  ─────────   │ │                            ││
│ │  Settings    │ │                            ││
│ │  About       │ │                            ││
│ └──────────────┘ └────────────────────────────┘│
└──────────────────────────────────────────────────┘
```

### Sidebar Sections (7 total)

| Order | Section     | Icon                        | Description                          |
|-------|-------------|-----------------------------|--------------------------------------|
| 1     | Home        | `dot.radiowaves.left.and.right` | Collaboration dashboard             |
| 2     | Records     | `clock.arrow.circlepath`     | Voice recognition history            |
| 3     | Data        | `tray.full`                 | Inbound data records log             |
| 4     | Speech      | `waveform.circle`           | Speech recognition engine selection  |
| 5     | Permissions | `lock.shield`               | Accessibility permission status      |
| 6     | Settings    | `gearshape`                 | App configuration                    |
| 7     | About       | `questionmark.circle`        | Version info and usage guide         |

Primary items (1-5) are in the top group. Secondary items (6-7) are at the bottom, separated by a flex spacer.

---

## 3. Visual Design System

### Color Palette

| Token                  | Dark Mode Value | Light Mode Value | Usage                           |
|------------------------|-----------------|-----------------|----------------------------------|
| `$pageBackground`      | `#1a1a2e` → `#141828` gradient | `#F2F4FA` → `#E8ECF5` gradient | Page background |
| `$sidebarBgTop`        | `#19222E`       | `#F6F7FC`       | Sidebar top gradient             |
| `$sidebarBgBottom`      | `#141C28`       | `#ECEEF7`       | Sidebar bottom gradient          |
| `$sidebarSelectedFill`  | `#2E3D56`       | `#DDE4F2`       | Selected sidebar item background |
| `$sidebarSelectedBorder`| `#619FAF`       | `#5B9AB5`       | Selected sidebar item border     |
| `$sidebarText`         | `#9EB2C8`       | `#4D5C78`       | Sidebar default text             |
| `$sidebarTextSelected`  | `#EEEEFF`       | `#17203A`       | Sidebar selected text            |
| `$canvasBackground`    | `#1C2130`       | `#FFFFFF`       | Content area background          |
| `$canvasBorder`        | `#2A3448`       | `rgba(0,0,0,0.08)` | Content area border           |
| `$cardSurface`         | `#212840`       | `#FFFFFF`       | Card backgrounds                 |
| `$cardBorder`          | `#3A4860`       | `rgba(0,0,0,0.10)` | Card borders                 |
| `$softSurface`         | `#1E2636`       | `#F5F6FA`       | Inner surface elements           |
| `$title`               | `#EEEEFF`       | `#17203A`       | Section/card titles              |
| `$primaryText`         | `#D0D8EE`       | `#2E3A52`       | Body text                        |
| `$secondaryText`       | `#9EB2C8`       | `#6B7A96`       | Secondary/caption text           |
| `$accent`              | `#00D4FF`       | `#00B4DD`       | Brand accent (keep existing)     |
| `$accentOrange`        | `#FF8C42`       | `#E07830`       | Dashboard stat accent            |
| `$accentGreen`         | `#4ADE80`       | `#22C55E`       | Success/connected states        |
| `$accentRed`           | `#F87171`       | `#EF4444`       | Error/disconnected states       |#EEEEFF`       | Primary text                     |
| `$primaryText`         | `#D4DAE8`       | Body text                        |
| `$secondaryText`       | `#9EB2C8`       | Secondary/muted text             |
| `$accent`              | `#00D4FF`       | Brand accent (keep existing)     |
| `$accentOrange`        | `#FF8C42`       | Dashboard stat accent            |
| `$accentGreen`         | `#4ADE80`       | Success/connected states        |
| `$accentRed`           | `#F87171`       | Error/disconnected states       |

### Typography

| Element          | Font                       | Size   | Weight |
|------------------|----------------------------|--------|--------|
| Brand title      | System (Segoe UI)         | 22px   | Bold   |
| Section title    | System                     | 28px   | Bold   |
| Sidebar label    | System                     | 14px   | Medium |
| Card title       | System                     | 16px   | Medium |
| Body             | System                     | 14px   | Normal |
| Caption          | System                     | 12px   | Normal |

### Component Styles

**Sidebar Item:**
- Padding: 14px vertical, 18px horizontal
- Border radius: 12px
- Selected: `$sidebarSelectedFill` background + 2px `$sidebarSelectedBorder` border
- Default: transparent background
- Transition: background 0.15s ease

**Cards:**
- Background: `$cardSurface` (`#212840`)
- Border: 1px solid `$cardBorder` (`#3A4860`)
- Border radius: 16px
- Padding: 20px
- Shadow: `0 2px 8px rgba(0,0,0,0.15)`

**Primary Button:**
- Background: `#00D4FF`
- Text: `#1a1a2e`
- Border radius: 12px
- Padding: 10px 20px

**Secondary Button:**
- Background: `#2A3448`
- Text: `$title`
- Border: 1px solid `$cardBorder`
- Border radius: 12px

**Status Badges:**
- Pill shape (border-radius: 20px)
- Small text + colored background
- Colors based on status (green=connected, orange=connecting, gray=disconnected, red=error)

**Input Fields:**
- Background: `#1a1a2e`
- Border: 1px solid `#3A4860`
- Border radius: 8px
- Focus: border-color `#00D4FF`

---

## 4. Section Specifications

### 4.1 Home / Collaboration Dashboard

**Purpose:** Main hub showing connection status, service controls, and recent activity.

**Layout:**
```
┌─ Stats Row ──────────────────────────────────────────────┐
│ [🔴 Connected] [🟢 Service Running] [📝 Notes: 0]       │
└──────────────────────────────────────────────────────────┘
┌─ Connection Card ────────────────────────────────────────┐
│ 📱 Connection Status                                      │
│ ┌─────────────────┐ ┌─────────────────┐                   │
│ │ Status: ✓ Ready │ │ Service: Running│                   │
│ │ Paired: iPhone  │ │ IP: 192.168.x.x│                   │
│ └─────────────────┘ └─────────────────┘                   │
│ [Stop Service] [Start Pairing] [Unpair]                  │
└──────────────────────────────────────────────────────────┘
┌─ Recent Activity ────────────────────────────────────────┐
│ 10:32 Voice "Hello world"                                │
│ 10:30 Connection paired successfully                      │
│ ...                                                      │
└──────────────────────────────────────────────────────────┘
```

**Stats Row:** 3 badges showing:
1. Connection state (icon + text, color by state)
2. Service running/stopped (icon + text, green when running)
3. History record count (icon + text, from total voice history entries)

**Connection Card:**
- Title: "Connection Status" or localized equivalent
- 2x2 grid of status items:
  - Status: connection state text + colored dot
  - Service: running/stopped
  - Paired device: device name (if paired, else "—")
  - IP address: local LAN IP
- Action buttons:
  - Start/Stop Service (toggles based on `isServiceRunning`)
  - Start Pairing (shown when service running + unpaired)
  - Unpair (shown when paired)

**Recent Activity Card:**
- Title: "Recent Activity"
- Shows last 6 inbound data records
- Each record: timestamp + category icon + detail text
- Scrollable if > 6

### 4.2 Records (Voice Recognition History)

**Purpose:** Display all speech recognition history with search and management.

**Layout:**
```
┌─ Header ─────────────────────────────────────────────────┐
│ 📋 12 records                          [Edit]  [🔍 ____] │
│ [Select All] [Delete Selected]              [Clear All]  │
└──────────────────────────────────────────────────────────┘
┌─ Today ───────────────────────────────────────────────────┐
│ 10:32 iOS  "Hello world"                                  │
│ 10:30 Local "测试识别"                                    │
├─ Yesterday ──────────────────────────────────────────────┤
│ 14:20 iOS  "Another phrase"                              │
└──────────────────────────────────────────────────────────┘
```

**Features:**
- Search input filters records by text content
- Edit mode toggle: enables selection checkboxes on each record
- Select All: selects all visible records
- Delete Selected: deletes selected records (with confirmation)
- Clear All: clears all history (with confirmation)
- Records grouped by date (Today, Yesterday, or date string)
- Each record shows: time, source badge (iOS/Local), text
- Empty state when no records

### 4.3 Data (Inbound Data Records)

**Purpose:** Debug/development log showing all inbound data events.

**Layout:**
```
┌─ Filter Bar ──────────────────────────────────────────────┐
│ Filter: [All] [Voice] [Pairing]        [🔍 ____] [📑 Group]│
│ Total: 12  Voice: 8  Pairing: 4  Errors: 1              │
└──────────────────────────────────────────────────────────┘
┌─ Session: abc123 ────────────────────────────────────────┐
│ 🔴 [Error] 10:32  Pairing failed: timeout                │
│ 🟢 [Info]  10:30  Device connected                       │
├─ Session: xyz789 ────────────────────────────────────────┤
│ 🔵 [Voice] 10:28  "Hello world" (confidence: 0.95)      │
└──────────────────────────────────────────────────────────┘
```

**Features:**
- Segmented filter: All / Voice / Pairing
- Search field
- Group by session toggle
- Summary badges: Total, Voice, Pairing, Errors counts
- Records grouped by session key
- Each record: severity badge (color-coded), title, timestamp, detail
- Auto-scroll to newest record when new data arrives
- Clear all button

### 4.4 Speech (Speech Recognition Engine)

**Purpose:** Allow user to select which speech recognition engine to use.

**Layout:**
```
┌─ Engine Selection ───────────────────────────────────────┐
│ 🎯 Speech Recognition Engine                               │
│                                                         │
│ ○ Volcengine ASR          ✓ Available                   │
│   Supported: zh-CN, en-US                               │
└──────────────────────────────────────────────────────────┘
```

**Features:**
- List available speech recognition engines
- Radio button selection
- Each engine shows: name, availability status (green check / red x), supported languages
- For initial implementation: show Volcengine ASR as the only available engine
- Engine selection persisted to settings

### 4.5 Permissions

**Purpose:** Show and manage Windows accessibility permissions required for text injection.

**Layout:**
```
┌─ Permissions ────────────────────────────────────────────┐
│ 🔓 Accessibility Permission                               │
│                                                         │
│ Status: ✓ Granted                                       │
│                                                         │
│ OR (if not granted):                                    │
│ Status: ✗ Not Granted                                   │
│ Text explaining why accessibility is needed              │
│                                                         │
│ [Check Status] [Request Permission] [Open Settings]     │
└──────────────────────────────────────────────────────────┘
```

**Features:**
- Display current accessibility permission status
- Check Status: re-checks permission state
- Request Permission: triggers Windows UAC dialog for accessibility
- Open Settings: opens Windows Ease of Access settings page
- Status shown with colored icon (green checkmark / red x)

### 4.6 Settings

**Purpose:** Configure app behavior.

**Layout:**
```
┌─ Text Injection ─────────────────────────────────────────┐
│ ○ Keyboard Simulation  (recommended)                     │
│ ○ Clipboard                                                 │
└──────────────────────────────────────────────────────────┘
┌─ Language ──────────────────────────────────────────────┐
│ [简体中文] [English]                                      │
└──────────────────────────────────────────────────────────┘
┌─ Theme ──────────────────────────────────────────────────┐
│ [System] [Light] [Dark]                                  │
└──────────────────────────────────────────────────────────┘
┌─ Server Port ────────────────────────────────────────────┐
│ [8765          ]                                          │
└──────────────────────────────────────────────────────────┘
┌─ ASR Configuration ──────────────────────────────────────┐
│ App ID:         [____________]                             │
│ Access Key ID:  [____________]                            │
│ Access Key Sec: [____________]                            │
│ Cluster:        [________________]                        │
│ Language:       [中文 ▼]                                  │
│ [Save ASR Config]                                         │
└──────────────────────────────────────────────────────────┘
```

**Fields:**
- Text Injection: radio (Keyboard Simulation / Clipboard)
- Language: segmented (zh-CN / en-US)
- Theme: segmented (System / Light / Dark) — Windows-only addition
- Server Port: number input
- ASR: App ID, Access Key ID, Access Key Secret, Cluster, Language
- Save button for each section

### 4.7 About

**Purpose:** App information and quick access to usage guide.

**Layout:**
```
┌─ About VoiceMind ────────────────────────────────────────┐
│                                                         │
│                    🎤                                   │
│                                                         │
│                 VoiceMind                               │
│                  Version 1.0.0                          │
│                                                         │
│         ──────────────────────────                       │
│                                                         │
│    iPhone as Wireless Microphone                        │
│                                                         │
│    [📖 Usage Guide]                                      │
│                                                         │
└──────────────────────────────────────────────────────────┘
```

**Features:**
- App icon (🎤 emoji or SVG)
- App name and version
- Description text
- Usage Guide button (opens first-run guide modal)
- Double-click version to reveal debug info (optional)

---

## 5. Backend Changes

### 5.1 New Tauri Commands (Rust)

```rust
// Service control
// start_service: binds TcpListener on configured port, spawns accept loop task,
// stores JoinHandle in state.server_handle. If server already running, returns Ok(()) silently.
#[tauri::command]
async fn start_service(state: State<'_, AppState>) -> Result<(), String>;

// stop_service: aborts the stored JoinHandle (handle.abort()), sets server_handle to None.
// Tauri's app_handle is needed to emit 'service-state-changed' event.
#[tauri::command]
async fn stop_service(state: State<'_, AppState>, app: tauri::AppHandle) -> Result<(), String>;

// Returns true if server_handle is Some (task not yet finished or aborted)
#[tauri::command]
async fn get_service_status(state: State<'_, AppState>) -> Result<bool, String>;

// Inbound data records
#[tauri::command]
async fn get_inbound_data_records(state: State<'_, AppState>) -> Result<Vec<InboundDataRecord>, String>;

#[tauri::command]
async fn clear_inbound_data_records(state: State<'_, AppState>) -> Result<(), String>;

// Accessibility: on Windows, keyboard injection via SendInput always works without special permissions.
// Returns "granted" always. Opens Ease of Access settings page via shell command.
#[tauri::command]
fn get_accessibility_status() -> Result<String, String>;  // always returns "granted" on Windows

// Opens Windows Ease of Access settings: ms-settings:easeofaccess-keyboard
#[tauri::command]
fn open_accessibility_settings() -> Result<(), String>;
```

### 5.2 Event Emission (Rust → Frontend)

The Rust backend emits events via Tauri's event system for real-time UI updates:

| Event Name              | Payload                                    | Trigger                          |
|-------------------------|--------------------------------------------|----------------------------------|
| `connection-state-changed` | `{ connected: bool, name: string\|null, device_id: string\|null }` | Device connects/disconnects |
| `pairing-state-changed`   | `{ is_pairing_mode: bool, current_code: string\|null }` | Pairing starts/completes/fails |
| `service-state-changed`   | `{ running: bool }`                      | Service starts/stops             |
| `new-history-record`      | `{ id: string, text: string, source: string, timestamp: string, session_id: string\|null }` | New ASR result received |
| `new-inbound-data`        | `InboundDataRecord` JSON                 | Any inbound data event          |

Events are emitted using `app_handle.emit(event_name, payload)` from within network.rs handlers.
The `app_handle` is passed into `start_server()` and stored for event emission.

### 5.3 AppState Changes

Add to existing `AppState` in `main.rs`:
- `server_handle: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>` — task handle for the running WebSocket accept loop; `abort()` to stop
- `inbound_data_records: Arc<Mutex<VecDeque<InboundDataRecord>>>` — use `VecDeque` capped at 200 entries (pop_front when full)

---

## 6. Data Structures

### InboundDataRecord

**Rust struct** (add to `commands.rs` or a new `src/inbound.rs`):
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InboundDataRecord {
    pub id: String,
    pub timestamp: String,  // format: "%Y-%m-%d %H:%M:%S" (matching HistoryRecord)
    pub title: String,
    pub detail: String,
    pub category: String,  // "voice" | "pairing"
    pub severity: String,  // "info" | "warning" | "error"
}
```

**TypeScript interface** (frontend):
```typescript
interface InboundDataRecord {
  id: string;
  timestamp: string;  // "%Y-%m-%d %H:%M:%S" format
  title: string;
  detail: string;
  category: 'voice' | 'pairing';
  severity: 'info' | 'warning' | 'error';
}
```

### VoiceRecognitionRecord (for `new-history-record` event payload)

Matches the existing `HistoryItem` struct from `speech.rs`:
```typescript
interface VoiceRecognitionRecord {
  id: string;
  text: string;
  source: string;        // e.g. "asr" or device name
  timestamp: string;     // "%Y-%m-%d %H:%M:%S"
  session_id: string | null;
}
```

### Connection State
```typescript
type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'error';
```

### Pairing State
```typescript
type PairingState = 'unpaired' | 'pairing' | 'paired';
```

---

## 7. First-Run Guide Modal

Shown on first launch when `localStorage.getItem('voicemind_guide_dismissed')` is not set.

**Content (same as existing):**
1. Download VoiceMind iOS app
2. Open iOS app and scan QR code
3. Ensure same Wi-Fi network
4. Start speaking

**Dismissal:** "Start Using VoiceMind" button sets the localStorage flag and hides the modal.

---

## 8. i18n

All user-facing strings stored in a JavaScript object:

```javascript
const i18n = {
  'en-US': { /* all strings */ },
  'zh-CN': { /* all strings */ }
};
```

Key string categories:
- Navigation labels
- Section titles and descriptions
- Button labels
- Status messages
- Error messages
- Placeholder texts
- Empty state messages

Language preference persisted in `localStorage` and reflected in settings.

---

## 9. Implementation Order

1. Rust: add missing Tauri commands (service control, inbound data, accessibility) + wire events
2. Rewrite HTML: sidebar + content area skeleton
3. CSS: apply full visual design system
4. JS: sidebar navigation with active state
5. Home Dashboard: service controls, connection status, stats, recent activity
6. Records tab: history list with search, edit, delete, date grouping
7. Data tab: inbound records with filter, group, search, summary badges
8. Speech tab: engine list with radio selection
9. Permissions tab: accessibility status + action buttons
10. Settings tab: all config fields
11. About tab: version + guide button
12. JS: wire up event listeners for real-time updates
13. i18n: ensure all strings are translated
14. First-run guide modal

---

## 10. Files to Modify

### Frontend (`VoiceMindWindows/src/`)
- `index.html` — Complete rewrite: new HTML structure, CSS, JS

### Backend (`VoiceMindWindows/src-tauri/src/`)
- `main.rs` — Add `server_handle` + `inbound_data_records` to `AppState`, new command registrations, event emission on connection/pairing state change
- `commands.rs` — Add new Tauri commands: `start_service`, `stop_service`, `get_service_status`, `get_inbound_data_records`, `clear_inbound_data_records`, `get_accessibility_status`, `open_accessibility_settings`
- `network.rs` — Emit Tauri events on connection/pairing state changes, append to inbound data records on each significant event
- `settings.rs` — Add `theme` field to `Settings` struct (default: `"system"`)

### Notes
- No new `service.rs` file needed: service start/stop will be handled by starting/stopping the WebSocket server task in `network.rs`
- `hotkey` field already exists in `Settings` — no change needed, it can remain unused in UI for now
- Accessibility on Windows is always effectively "granted" for keyboard injection, but the UI should show the status based on whether the injection method actually works

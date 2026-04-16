# Qwen3-ASR ONNX Rust Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth ASR engine (`qwen3_onnx`) that uses Rust-native ONNX Runtime to run Qwen3-ASR inference with true streaming recognition.

**Architecture:** New `qwen3_onnx/` Rust module with whisper-rs-style `Qwen3AsrEngine` wrapper. Streaming uses rolling window: timer re-infers on all buffered audio every 500ms, no VAD. ONNX models downloaded from `Daumee/Qwen3-ASR-0.6B-ONNX-CPU` on HuggingFace.

**Tech Stack:** Rust, `ort` crate (ONNX Runtime), `rustfft` (mel spectrogram), `tokenizers` (HuggingFace BPE), `ndarray`, `tokio_util` (CancellationToken). Tauri v2 for commands/events.

**Spec:** `docs/superpowers/specs/2026-04-16-qwen3-onnx-rust-engine-design.md`

---

## File Structure

### New files
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/mod.rs` — module exports
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/audio.rs` — mel spectrogram (FFT → mel bank → log → normalize → chunk)
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/tokenizer.rs` — BPE tokenizer wrapper
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/encoder.rs` — ONNX encoder inference (conv + transformer)
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/decoder.rs` — ONNX decoder inference (init + step loop)
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/engine.rs` — `Qwen3AsrEngine` high-level API
- `VoiceMindWindows/src-tauri/src/qwen3_onnx/model.rs` — model download, check, management

### Modified files
- `VoiceMindWindows/src-tauri/Cargo.toml` — add `ort`, `rustfft`, `ndarray`, `tokenizers`, `tokio_util`
- `VoiceMindWindows/src-tauri/src/main.rs` — add `qwen3_onnx` module, `AppState` field, command registration
- `VoiceMindWindows/src-tauri/src/network.rs` — add `Qwen3OnnxState`, `Connection` field, engine dispatch
- `VoiceMindWindows/src-tauri/src/commands.rs` — add 5 new Tauri commands
- `VoiceMindWindows/src-tauri/src/events.rs` — add `Qwen3OnnxDownloadProgress` event
- `VoiceMindWindows/src/index.html` — add `qwen3_onnx` engine row + config modal
- `VoiceMindWindows/src/app/app.js` — add engine selection + download UI logic

---

## Task 1: Add Cargo Dependencies

**Files:**
- Modify: `VoiceMindWindows/src-tauri/Cargo.toml`

- [ ] **Step 1: Add new dependencies to Cargo.toml**

Add after the existing dependencies block (after line 37):

```toml
ort = { version = "2.0.0-rc.12", features = ["load-dynamic"] }
ndarray = "0.16"
rustfft = "6"
tokenizers = "0.21"
tokio-util = "0.7"
```

- [ ] **Step 2: Verify compilation**

Run: `cd D:/data/voice-mind/VoiceMindWindows/src-tauri && cargo check`
Expected: Compiles with warnings about unused imports (acceptable). May need to fix version conflicts.

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/Cargo.toml VoiceMindWindows/src-tauri/Cargo.lock
git commit -m "chore(win): add ort, rustfft, ndarray, tokenizers, tokio-util dependencies"
```

---

## Task 2: Create Module Skeleton

**Files:**
- Create: `VoiceMindWindows/src-tauri/src/qwen3_onnx/mod.rs`
- Modify: `VoiceMindWindows/src-tauri/src/main.rs` (add module declaration)

- [ ] **Step 1: Create mod.rs with all submodule declarations**

```rust
// qwen3_onnx/mod.rs
pub mod audio;
pub mod tokenizer;
pub mod encoder;
pub mod decoder;
pub mod engine;
pub mod model;
```

Create placeholder files for each submodule with empty `pub struct` / `pub fn` stubs so the project compiles:

```rust
// qwen3_onnx/audio.rs
pub struct MelSpectrogram;

impl MelSpectrogram {
    pub fn new() -> Self { Self }
    pub fn compute(&self, _pcm: &[f32], _sample_rate: u32) -> Vec<f32> {
        todo!()
    }
}
```

```rust
// qwen3_onnx/tokenizer.rs
pub struct Qwen3Tokenizer;

impl Qwen3Tokenizer {
    pub fn from_file(_path: &std::path::Path) -> Result<Self, String> { todo!() }
    pub fn encode(&self, _text: &str) -> Vec<u32> { todo!() }
    pub fn decode(&self, _ids: &[u32]) -> Result<String, String> { todo!() }
    pub fn get_audio_pad_token_id(&self) -> u32 { 151676 }
}
```

```rust
// qwen3_onnx/encoder.rs
pub struct Encoder;

impl Encoder {
    pub fn new(_model_dir: &std::path::Path) -> Result<Self, String> { todo!() }
    pub fn encode(&self, _mel: &[f32], _mel_dims: (usize, usize, usize)) -> ndarray::Array2<f32> { todo!() }
}
```

```rust
// qwen3_onnx/decoder.rs
pub struct Decoder;

impl Decoder {
    pub fn new(_model_dir: &std::path::Path) -> Result<Self, String> { todo!() }
    pub fn decode(&self, _audio_tokens: &ndarray::Array2<f32>, _embed_tokens: &ndarray::Array2<f32>, _tokenizer: &crate::qwen3_onnx::tokenizer::Qwen3Tokenizer) -> Result<String, String> { todo!() }
}
```

```rust
// qwen3_onnx/engine.rs
pub struct Qwen3AsrEngine;

impl Qwen3AsrEngine {
    pub fn new(_model_dir: &std::path::Path) -> Result<Self, String> { todo!() }
    pub fn transcribe(&self, _pcm: &[f32], _sample_rate: u32) -> Result<String, String> { todo!() }
    pub fn unload(&mut self) {}
}
```

```rust
// qwen3_onnx/model.rs
pub fn get_onnx_model_dir(size: &str) -> std::path::PathBuf { todo!() }
pub fn is_onnx_model_downloaded(size: &str) -> bool { false }
pub async fn download_onnx_model(size: &str, _app_handle: &tauri::AppHandle) -> Result<(), String> { todo!() }
```

- [ ] **Step 2: Add module declaration to main.rs**

Add after line 11 (`mod qwen_asr;`):

```rust
pub mod qwen3_onnx;
```

- [ ] **Step 3: Verify compilation**

Run: `cd D:/data/voice-mind/VoiceMindWindows/src-tauri && cargo check`
Expected: Compiles (todo!() macros won't be called, just need type-check).

- [ ] **Step 4: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/ VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(win): add qwen3_onnx module skeleton with stubs"
```

---

## Task 3: Implement Mel Spectrogram (audio.rs)

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/qwen3_onnx/audio.rs`

**Reference:** Spec section "Mel Spectrogram Implementation Details". Whisper-style mel spectrogram matching Python `librosa.filters.mel()` with Slaney normalization.

- [ ] **Step 1: Implement MelSpectrogram struct and compute method**

Key implementation:
- STFT with `rustfft`: n_fft=400, hop_length=160, center=True, pad_mode=reflect, Hann window
- Power spectrum: `|STFT|^2`, take first 201 bins
- Mel filter bank: 128 bins, Slaney normalization, fmin=0, fmax=8000
  - Hz → mel: `2595 * log10(1 + f/700)`
  - Triangle filters with area normalization per Slaney paper
- Log compression: `log10(max(mel_power, 1e-10))`
- Dynamic range clamp: `clamp(x, max - 8.0, max)`
- Normalize: `(x + 4.0) / 4.0`
- Output shape: `[1, 128, T]` as flat Vec<f32>
- Chunking helper: split into 100-frame chunks, pad last chunk with zeros

```rust
pub struct MelSpectrogram {
    mel_filterbank: ndarray::Array2<f64>,  // [128, 201]
    hann_window: Vec<f64>,
    n_fft: usize,      // 400
    hop_length: usize,  // 160
    n_mels: usize,      // 128
    chunk_size: usize,  // 100
}

impl MelSpectrogram {
    pub fn new(sample_rate: u32) -> Self { /* build mel bank + hann window */ }
    pub fn compute(&self, pcm: &[f32]) -> MelOutput { /* full pipeline */ }
    pub fn chunk_mel(&self, mel: &MelOutput) -> Vec<ndarray::Array3<f32>> { /* 100-frame chunks */ }
}

pub struct MelOutput {
    pub data: ndarray::Array3<f32>,  // [1, 128, T]
    pub num_frames: usize,           // T
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/audio.rs
git commit -m "feat(win): implement mel spectrogram with Slaney mel scale and chunking"
```

---

## Task 4: Implement Tokenizer (tokenizer.rs)

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/qwen3_onnx/tokenizer.rs`

- [ ] **Step 1: Implement Qwen3Tokenizer using `tokenizers` crate**

```rust
use tokenizers::Tokenizer as HfTokenizer;

pub struct Qwen3Tokenizer {
    inner: HfTokenizer,
    audio_pad_token_id: u32,  // 151676
}

impl Qwen3Tokenizer {
    pub fn from_file(path: &std::path::Path) -> Result<Self, String> {
        let inner = HfTokenizer::from_file(path).map_err(|e| e.to_string())?;
        Ok(Self { inner, audio_pad_token_id: 151676 })
    }

    pub fn encode(&self, text: &str) -> Vec<u32> {
        let encoding = self.inner.encode(text, false).unwrap();
        encoding.get_ids().to_vec()
    }

    pub fn decode(&self, ids: &[u32]) -> Result<String, String> {
        self.inner.decode(ids, true).map_err(|e| e.to_string())
    }

    pub fn get_audio_pad_token_id(&self) -> u32 { self.audio_pad_token_id }

    pub fn vocab_size(&self) -> u32 { 151936 }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/tokenizer.rs
git commit -m "feat(win): implement BPE tokenizer wrapper using tokenizers crate"
```

---

## Task 5: Implement ONNX Encoder (encoder.rs)

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/qwen3_onnx/encoder.rs`

**Reference:** Spec section "ONNX Tensor Names". Two-stage encoder: `encoder_conv.onnx` + `encoder_transformer.onnx`.

- [ ] **Step 1: Implement Encoder with two ONNX sessions**

```rust
use ort::session::Session;
use ndarray::Array3;

pub struct Encoder {
    session_conv: Session,
    session_transformer: Session,
    hidden_dim: usize,   // 896 for 0.6B
    d_model: usize,      // 1024 for 0.6B
    tokens_per_chunk: usize, // 13
}

impl Encoder {
    pub fn new(model_dir: &std::path::Path) -> Result<Self, String> {
        let session_conv = Session::builder()
            .and_then(|b| b.commit_from_file(model_dir.join("encoder_conv.onnx")))
            .map_err(|e| format!("Failed to load encoder_conv: {}", e))?;
        let session_transformer = Session::builder()
            .and_then(|b| b.commit_from_file(model_dir.join("encoder_transformer.onnx")))
            .map_err(|e| format!("Failed to load encoder_transformer: {}", e))?;
        Ok(Self { session_conv, session_transformer, hidden_dim: 896, d_model: 1024, tokens_per_chunk: 13 })
    }

    /// Takes chunked mel: [num_chunks, 128, 100]
    /// Returns audio tokens: [total_tokens, d_model] e.g. [N, 1024]
    pub fn encode(&self, mel_chunks: &Array3<f32>) -> ndarray::Array2<f32> {
        // 1. Run encoder_conv.onnx with input "padded_mel_chunks"
        // 2. Collect conv outputs, remove padding from last chunk
        // 3. Reshape to [total_tokens, hidden_dim]
        // 4. Run encoder_transformer.onnx with "hidden_states" + "attention_mask"
        // 5. Return [total_tokens, d_model]
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/encoder.rs
git commit -m "feat(win): implement two-stage ONNX encoder (conv + transformer)"
```

---

## Task 6: Implement ONNX Decoder (decoder.rs)

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/qwen3_onnx/decoder.rs`

**Reference:** Spec section "ONNX Tensor Names". Autoregressive decoder: `decoder_init.int8.onnx` + `decoder_step.int8.onnx`.

- [ ] **Step 1: Implement Decoder with init + step sessions**

```rust
use ort::session::Session;
use ndarray::{Array1, Array2, Array3};

pub struct Decoder {
    session_init: Session,
    session_step: Session,
    num_layers: usize,     // 28 for 0.6B
    num_kv_heads: usize,   // 8 for 0.6B
    head_dim: usize,       // 128 for 0.6B
}

impl Decoder {
    pub fn new(model_dir: &std::path::Path) -> Result<Self, String> {
        let session_init = Session::builder()
            .and_then(|b| b.commit_from_file(model_dir.join("decoder_init.int8.onnx")))
            .map_err(|e| format!("Failed to load decoder_init: {}", e))?;
        let session_step = Session::builder()
            .and_then(|b| b.commit_from_file(model_dir.join("decoder_step.int8.onnx")))
            .map_err(|e| format!("Failed to load decoder_step: {}", e))?;
        Ok(Self { session_init, session_step, num_layers: 28, num_kv_heads: 8, head_dim: 128 })
    }

    /// Run autoregressive decoding
    /// audio_tokens: [num_audio_tokens, d_model]
    /// embed_tokens: [vocab_size, d_model]
    /// Returns decoded text via tokenizer
    pub fn decode(
        &self,
        audio_tokens: &ndarray::Array2<f32>,
        embed_tokens: &ndarray::Array2<f32>,
        tokenizer: &super::tokenizer::Qwen3Tokenizer,
    ) -> Result<String, String> {
        // 1. Build prompt: system_prompt tokens + <|audio_pad|> tokens
        // 2. Replace <|audio_pad|> embeddings with audio_tokens
        // 3. Build position_ids (MRoPE style)
        // 4. Run decoder_init.onnx: input_embeds + position_ids → logits + KV cache
        // 5. Pick first token (argmax)
        // 6. Loop: run decoder_step.onnx with new token embed + past KV cache
        // 7. Stop on EOS token (151645) or max length
        // 8. Collect all token IDs, decode via tokenizer
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/decoder.rs
git commit -m "feat(win): implement autoregressive ONNX decoder (init + step loop)"
```

---

## Task 7: Implement Qwen3AsrEngine (engine.rs)

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/qwen3_onnx/engine.rs`

- [ ] **Step 1: Implement full pipeline**

```rust
use std::path::Path;
use std::sync::Arc;

pub struct Qwen3AsrEngine {
    mel: super::audio::MelSpectrogram,
    encoder: super::encoder::Encoder,
    decoder: super::decoder::Decoder,
    tokenizer: super::tokenizer::Qwen3Tokenizer,
    embed_tokens: ndarray::Array2<f32>,  // [151936, 1024] loaded from embed_tokens.bin
}

impl Qwen3AsrEngine {
    pub fn new(model_dir: &Path) -> Result<Self, String> {
        // 1. Load tokenizer from tokenizer.json
        // 2. Load embed_tokens.bin (FP32, 151936 * 1024 * 4 bytes)
        // 3. Create MelSpectrogram::new(16000)
        // 4. Create Encoder::new(model_dir)
        // 5. Create Decoder::new(model_dir)
        Ok(Self { mel, encoder, decoder, tokenizer, embed_tokens })
    }

    pub fn transcribe(&self, pcm: &[f32], sample_rate: u32) -> Result<String, String> {
        // 1. Resample if needed (assume 16kHz)
        // 2. self.mel.compute(pcm) → MelOutput
        // 3. self.mel.chunk_mel(&mel_output) → chunks [num_chunks, 128, 100]
        // 4. self.encoder.encode(&chunks) → audio_tokens [N, 1024]
        // 5. self.decoder.decode(&audio_tokens, &self.embed_tokens, &self.tokenizer)
    }

    pub fn unload(&mut self) {
        // Drop all sessions by replacing with default
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/engine.rs
git commit -m "feat(win): implement Qwen3AsrEngine full inference pipeline"
```

---

## Task 8: Implement Model Management (model.rs)

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/qwen3_onnx/model.rs`

**Reference:** Pattern from `qwen_asr.rs:466-607` (download_model) and `qwen_asr.rs:246-272` (is_model_downloaded).

- [ ] **Step 1: Implement model check, download, and delete functions**

```rust
use std::path::{Path, PathBuf};

const HF_ONNX_REPO: &str = "Daumee/Qwen3-ASR-0.6B-ONNX-CPU";
const ONNX_SUBDIR: &str = "onnx_models";

const REQUIRED_FILES: &[&str] = &[
    "encoder_conv.onnx",
    "encoder_conv.onnx.data",
    "encoder_transformer.onnx",
    "encoder_transformer.onnx.data",
    "decoder_init.int8.onnx",
    "decoder_step.int8.onnx",
    "embed_tokens.bin",
    "tokenizer.json",
];

pub fn get_onnx_model_dir(size: &str) -> PathBuf {
    let base = dirs_decode_from_env(); // same pattern as qwen_asr::get_models_dir()
    base.join(format!("qwen3-asr-onnx-{}", size))
}

pub fn is_onnx_model_downloaded(size: &str) -> bool {
    let dir = get_onnx_model_dir(size);
    REQUIRED_FILES.iter().all(|f| dir.join(f).exists())
}

pub async fn download_onnx_model(
    size: &str,
    app_handle: &tauri::AppHandle,
) -> Result<(), String> {
    // 1. Create model dir
    // 2. For each file in REQUIRED_FILES:
    //    - GET from https://huggingface.co/{HF_ONNX_REPO}/resolve/main/{ONNX_SUBDIR}/{filename}
    //    - Stream download with progress via emit("qwen3-onnx-download-progress")
    // 3. Verify all files present
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/qwen3_onnx/model.rs
git commit -m "feat(win): implement ONNX model download from HuggingFace with progress"
```

---

## Task 9: Add AppState Field and Engine Loading

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/main.rs`

**Reference:** AppState struct at lines 33-41, init at lines 176-184.

- [ ] **Step 1: Add qwen3_onnx_engine field to AppState**

After `pub inbound_data_records` (line 41), add:

```rust
pub qwen3_onnx_engine: Arc<tokio::sync::Mutex<Option<qwen3_onnx::engine::Qwen3AsrEngine>>>,
```

- [ ] **Step 2: Initialize the field in setup closure**

After line 184 (the `inbound_data_records` init), add:

```rust
qwen3_onnx_engine: Arc::new(tokio::sync::Mutex::new(None)),
```

- [ ] **Step 3: Verify compilation**

Run: `cargo check`

- [ ] **Step 4: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(win): add qwen3_onnx_engine to AppState"
```

---

## Task 10: Add Tauri Commands

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/commands.rs`
- Modify: `VoiceMindWindows/src-tauri/src/main.rs` (register commands)

**Reference:** Pattern from `commands.rs:938-997` (existing qwen3 commands).

- [ ] **Step 1: Add 5 new commands to commands.rs**

Add after the existing qwen3 commands (after line 997):

```rust
// === Qwen3 ONNX Engine Commands ===

#[derive(serde::Serialize)]
pub struct Qwen3OnnxStatus {
    pub loaded: bool,
    pub model_size: Option<String>,
}

#[tauri::command]
pub async fn check_qwen3_onnx_model(model_size: String) -> Result<bool, String> {
    if model_size != "0.6b" {
        return Err("Only 0.6b model size supported for ONNX engine".into());
    }
    Ok(qwen3_onnx::model::is_onnx_model_downloaded(&model_size))
}

#[tauri::command]
pub async fn download_qwen3_onnx_model(
    model_size: String,
    app_handle: tauri::AppHandle,
) -> Result<(), String> {
    if model_size != "0.6b" {
        return Err("Only 0.6b model size supported for ONNX engine".into());
    }
    qwen3_onnx::model::download_onnx_model(&model_size, &app_handle).await
}

#[tauri::command]
pub async fn load_qwen3_onnx_engine(
    model_size: String,
    state: tauri::State<'_, crate::AppState>,
) -> Result<(), String> {
    let model_dir = qwen3_onnx::model::get_onnx_model_dir(&model_size);
    let engine = tokio::task::spawn_blocking(move || {
        qwen3_onnx::engine::Qwen3AsrEngine::new(&model_dir)
    }).await.map_err(|e| e.to_string())??;
    let mut guard = state.qwen3_onnx_engine.lock().await;
    *guard = Some(engine);
    Ok(())
}

#[tauri::command]
pub async fn unload_qwen3_onnx_engine(
    state: tauri::State<'_, crate::AppState>,
) -> Result<(), String> {
    let mut guard = state.qwen3_onnx_engine.lock().await;
    *guard = None;
    Ok(())
}

#[tauri::command]
pub async fn get_qwen3_onnx_status(
    state: tauri::State<'_, crate::AppState>,
) -> Result<Qwen3OnnxStatus, String> {
    let guard = state.qwen3_onnx_engine.lock().await;
    match guard.as_ref() {
        Some(_) => Ok(Qwen3OnnxStatus { loaded: true, model_size: Some("0.6b".into()) }),
        None => Ok(Qwen3OnnxStatus { loaded: false, model_size: None }),
    }
}
```

- [ ] **Step 2: Register commands in main.rs**

Add to `tauri::generate_handler![]` after line 418:

```rust
check_qwen3_onnx_model,
download_qwen3_onnx_model,
load_qwen3_onnx_engine,
unload_qwen3_onnx_engine,
get_qwen3_onnx_status,
```

- [ ] **Step 3: Verify compilation**

Run: `cargo check`

- [ ] **Step 4: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/commands.rs VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(win): add Tauri commands for ONNX engine lifecycle"
```

---

## Task 11: Add Download Progress Event

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/events.rs`

**Reference:** Pattern from `events.rs:260` (emit_qwen3_download_progress).

- [ ] **Step 1: Add Qwen3OnnxDownloadProgress event struct and emit method**

Add after the existing event structs:

```rust
#[derive(Clone, serde::Serialize)]
pub struct Qwen3OnnxDownloadProgress {
    pub model_size: String,
    pub status: String,
    pub progress: f64,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub current_file: String,
}
```

Add emit method to `EventEmitter`:

```rust
pub fn emit_qwen3_onnx_download_progress(&self, progress: Qwen3OnnxDownloadProgress) {
    let _ = self.handle.emit("qwen3-onnx-download-progress", progress);
}
```

- [ ] **Step 2: Verify compilation**

Run: `cargo check`

- [ ] **Step 3: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/events.rs
git commit -m "feat(win): add Qwen3 ONNX download progress event"
```

---

## Task 12: Add Streaming State and Engine Dispatch

**Files:**
- Modify: `VoiceMindWindows/src-tauri/src/network.rs`

**Reference:** Connection struct (lines 257-274), Qwen3VadState (lines 35-49), handle_audio_start (lines 1224-1347), handle_audio_data (lines 1349-1477), handle_audio_end (lines 1479-1686).

- [ ] **Step 1: Add Qwen3OnnxState struct**

Add after the `Qwen3VadState` struct (after line 49):

```rust
struct Qwen3OnnxState {
    engine: Arc<crate::qwen3_onnx::engine::Qwen3AsrEngine>,
    audio_buffer: Arc<tokio::sync::Mutex<Vec<f32>>>,
    interval_handle: Option<tokio::task::JoinHandle<()>>,
    last_partial: Arc<std::sync::Mutex<String>>,
    cancel_token: tokio_util::sync::CancellationToken,
    emitter: crate::events::EventEmitter,
}
```

- [ ] **Step 2: Add field to Connection struct**

Add after `qwen3_vad_poll_task` (line 273):

```rust
qwen3_onnx_state: Option<Qwen3OnnxState>,
```

Update Connection::new to initialize it as `None`.

- [ ] **Step 3: Add "qwen3_onnx" branch to handle_audio_start**

After the `"qwen3_local"` block (after line 1327), add:

```rust
} else if asr_engine == "qwen3_onnx" {
    // Get engine from AppState
    let engine_guard = app_state.qwen3_onnx_engine.lock().await;
    let engine = match engine_guard.as_ref() {
        Some(e) => e.clone(),  // needs Arc wrapper - adjust engine.rs to wrap in Arc
        None => {
            let _ = emitter.emit_error("ONNX engine not loaded".into());
            return Ok(());
        }
    };
    drop(engine_guard);

    let state = Qwen3OnnxState {
        engine,
        audio_buffer: Arc::new(tokio::sync::Mutex::new(Vec::new())),
        interval_handle: None,
        last_partial: Arc::new(std::sync::Mutex::new(String::new())),
        cancel_token: tokio_util::sync::CancellationToken::new(),
        emitter: emitter.clone(),
    };

    // Start streaming loop
    let audio_buf = state.audio_buffer.clone();
    let last_p = state.last_partial.clone();
    let engine_ref = state.engine.clone();
    let cancel = state.cancel_token.clone();
    let em = emitter.clone();

    let handle = tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_millis(500));
        loop {
            tokio::select! {
                _ = cancel.cancelled() => break,
                _ = interval.tick() => {
                    let buf = audio_buf.lock().await;
                    let len = buf.len();
                    if len < 4800 { continue; } // < 0.3s at 16kHz
                    let pcm = buf.clone();
                    drop(buf);

                    match engine_ref.transcribe(&pcm, 16000) {
                        Ok(text) if !text.is_empty() => {
                            let mut last = last_p.lock().unwrap();
                            if *last != text {
                                *last = text.clone();
                                drop(last);
                                let _ = em.emit_partial_result(text, "qwen3_onnx".into(), conn_id);
                            }
                        }
                        Ok(_) => {}  // empty result, skip
                        Err(e) => { eprintln!("ONNX inference error: {}", e); }
                    }
                }
            }
        }
    });

    // Store handle in state and set on connection
    let mut state = state;
    state.interval_handle = Some(handle);
    conn.qwen3_onnx_state = Some(state);
```

**Note:** This code needs to be adapted for the actual function signature. The `conn_id` and `emitter` need to be accessible in the spawned task. Use channel or move what's needed. Also `Qwen3AsrEngine` needs to be wrapped in `Arc` for sharing — update `engine.rs` accordingly and change `AppState` field to `Arc<...Arc<Qwen3AsrEngine>...>`.

- [ ] **Step 4: Add "qwen3_onnx" branch to handle_audio_data**

After the qwen3_vad block in handle_audio_data, add:

```rust
if let Some(ref onnx_state) = conn.qwen3_onnx_state {
    let f32_samples: Vec<f32> = audio_data.chunks(2)
        .map(|c| i16::from_le_bytes([c[0], c[1]]) as f32 / 32768.0)
        .collect();
    onnx_state.audio_buffer.lock().await.extend(f32_samples);
}
```

- [ ] **Step 5: Add "qwen3_onnx" branch to handle_audio_end**

After the qwen3_vad block in handle_audio_end (after line 1629), add:

```rust
if let Some(onnx_state) = conn.qwen3_onnx_state.take() {
    onnx_state.cancel_token.cancel();
    if let Some(h) = onnx_state.interval_handle {
        let _ = h.await;
    }
    let buf = onnx_state.audio_buffer.lock().await;
    if !buf.is_empty() {
        let pcm = buf.clone();
        drop(buf);
        match onnx_state.engine.transcribe(&pcm, 16000) {
            Ok(text) if !text.is_empty() => {
                text_result = text;
            }
            Ok(_) => {}
            Err(e) => {
                let _ = emitter.emit_error(format!("ONNX final inference error: {}", e));
            }
        }
    }
}
```

- [ ] **Step 6: Verify compilation**

Run: `cargo check`

- [ ] **Step 7: Commit**

```bash
git add VoiceMindWindows/src-tauri/src/network.rs VoiceMindWindows/src-tauri/src/qwen3_onnx/engine.rs VoiceMindWindows/src-tauri/src/main.rs
git commit -m "feat(win): add Qwen3OnnxState with streaming timer loop and engine dispatch"
```

---

## Task 13: Add Frontend Engine Row and Config Modal

**Files:**
- Modify: `VoiceMindWindows/src/index.html`
- Modify: `VoiceMindWindows/src/app/app.js`

**Reference:** Existing engine row pattern at `index.html:150-158`, Qwen3 config modal at `index.html:189-239`, engine selection logic in `app.js:131-279`.

- [ ] **Step 1: Add qwen3_onnx engine row in index.html**

After the `qwen3_local` engine row (after line 158), add:

```html
<div class="engine-row" data-engine="qwen3_onnx">
  <div class="engine-radio"></div>
  <div class="engine-info">
    <div class="engine-name">Qwen3 ONNX (本地流式)</div>
    <div class="engine-langs">离线识别 · 高精度 · 实时流式 · 30+ 语言</div>
  </div>
  <button class="engine-status" id="engine-status-qwen3-onnx" type="button">检测中</button>
</div>
```

- [ ] **Step 2: Add qwen3_onnx config modal in index.html**

After the existing qwen3-config-modal (after line 239), add a similar modal for ONNX:

```html
<div id="qwen3-onnx-config-modal" class="card" hidden style="border-color:var(--accent)">
  <h3>Qwen3 ONNX 模型管理</h3>
  <p style="margin:0 0 12px;color:var(--secondaryText);font-size:13px;line-height:1.5">
    下载 ONNX 模型到本地，享受纯 Rust 推理引擎的实时流式语音识别。需要约 2.5 GB 内存。
  </p>
  <div id="qwen3-onnx-model-cards" class="qwen3-model-cards">
    <div class="qwen3-model-card" data-model="0.6b">
      <div class="qwen3-model-header">
        <div class="qwen3-model-name">Qwen3-ASR 0.6B ONNX</div>
        <span class="qwen3-model-size">约 2.5 GB</span>
      </div>
      <div class="qwen3-model-status" id="qwen3-onnx-status-0.6b">未下载</div>
      <div class="qwen3-progress-bar" id="qwen3-onnx-progress-0.6b" hidden>
        <div class="qwen3-progress-fill"></div>
      </div>
      <div class="qwen3-progress-text" id="qwen3-onnx-progress-text-0.6b" hidden></div>
      <button class="btn primary qwen3-action-btn" id="qwen3-onnx-btn-0.6b" type="button">下载</button>
    </div>
  </div>
  <div class="toolbar">
    <button id="save-qwen3-onnx-config" class="btn primary" type="button">保存配置</button>
    <button id="qwen3-onnx-config-cancel" class="btn secondary" type="button">取消</button>
  </div>
</div>
```

- [ ] **Step 3: Add JS logic in app.js for ONNX engine**

Add functions following the pattern of existing `loadQwen3Status`, `downloadQwen3Model`, etc.:

```js
async function loadQwen3OnnxStatus() {
    const downloaded = await invoke("check_qwen3_onnx_model", { modelSize: "0.6b" });
    const statusEl = document.getElementById("qwen3-onnx-status-0.6b");
    const btnEl = document.getElementById("qwen3-onnx-btn-0.6b");
    if (downloaded) {
        statusEl.textContent = "已下载";
        btnEl.textContent = "删除";
        btnEl.className = "btn secondary qwen3-action-btn";
    } else {
        statusEl.textContent = "未下载";
        btnEl.textContent = "下载";
        btnEl.className = "btn primary qwen3-action-btn";
    }
}

async function downloadQwen3OnnxModel() {
    await invoke("download_qwen3_onnx_model", { modelSize: "0.6b" });
}
```

Update `isEngineSelectable` to handle `"qwen3_onnx"`:
```js
if (engine === "qwen3_onnx") {
    const downloaded = await invoke("check_qwen3_onnx_model", { modelSize: "0.6b" });
    return downloaded;
}
```

Update `renderEngineSelection` and `updateSpeechEngineActions` to include the new engine.

Add event listener for `"qwen3-onnx-download-progress"` following the existing `"qwen3-download-progress"` pattern.

Add click handlers for save/cancel buttons in the ONNX config modal.

- [ ] **Step 4: Verify the app builds and renders**

Run: `cd D:/data/voice-mind/VoiceMindWindows && npm run build`

- [ ] **Step 5: Commit**

```bash
git add VoiceMindWindows/src/index.html VoiceMindWindows/src/app/app.js
git commit -m "feat(win): add qwen3_onnx engine row, config modal, and JS logic"
```

---

## Task 14: Integration Test — Full Pipeline

**Files:**
- No new files (manual test)

- [ ] **Step 1: Build the full app**

```bash
cd D:/data/voice-mind/VoiceMindWindows
taskkill /F /IM voice-mind-windows.exe 2>/dev/null
npm run tauri build
```

- [ ] **Step 2: Test model download**

1. Launch the app
2. Go to settings → recognition engine
3. Select "Qwen3 ONNX (本地流式)"
4. Click download for 0.6B ONNX model
5. Verify progress bar updates
6. Verify model files appear in `%LOCALAPPDATA%/com.voicemind.voiceinput/models/qwen3-asr-onnx-0.6b/`

- [ ] **Step 3: Test engine loading**

1. After download, click "保存配置"
2. Verify engine loads (check logs for "ONNX engine loaded")
3. Verify engine status shows "loaded"

- [ ] **Step 4: Test streaming recognition**

1. Connect iPhone via the mobile app
2. Start recording
3. Verify partial results appear in overlay in real-time
4. Stop recording
5. Verify final text is injected at cursor position

- [ ] **Step 5: Fix any issues found during testing**

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix(win): integration fixes from testing"
```

---

## Task 15: Final Cleanup and Compile Verification

- [ ] **Step 1: Run cargo check with all warnings**

```bash
cd D:/data/voice-mind/VoiceMindWindows/src-tauri && cargo check 2>&1
```

Fix any warnings in the new code.

- [ ] **Step 2: Run cargo clippy**

```bash
cargo clippy 2>&1
```

Fix any clippy warnings in the new code.

- [ ] **Step 3: Final commit**

```bash
git add -A
git commit -m "chore(win): cleanup and clippy fixes for qwen3_onnx engine"
```

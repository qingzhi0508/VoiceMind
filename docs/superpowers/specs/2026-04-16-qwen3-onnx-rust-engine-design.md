# Qwen3-ASR Rust ONNX Engine Design

**Date**: 2026-04-16
**Status**: Approved
**Branch**: feature/win-4

## Overview

Add a fourth ASR engine option (`qwen3_onnx`) to VoiceMind Windows that uses Rust-native ONNX Runtime (via `ort` crate) to run Qwen3-ASR inference directly in-process. Uses a whisper-rs-style high-level wrapper that provides true streaming recognition (rolling window, no VAD segmentation).

## Goals

- Pure Rust implementation, no Python or external process dependency
- True streaming recognition: partial results appear in real-time as user speaks
- CPU-only inference via ONNX Runtime, compatible with all Windows devices
- Support 0.6B model size initially (1.7B when ONNX export becomes available)
- Clean `Qwen3AsrEngine` API that hides ONNX internals from callers

## Architecture

```
Frontend (JS)
  settings.asr_engine = "qwen3_onnx"
        │ Tauri Command/Event
        ▼
network.rs (engine dispatch)
  new branch: "qwen3_onnx" → Qwen3OnnxState
        │
        ▼
qwen3_onnx/ (new Rust module)
  ┌─────────────────────────────────┐
  │  Qwen3AsrEngine (high-level API)│
  │  new() / transcribe() / unload()│
  └──────────────┬──────────────────┘
                 │
  ┌──────────────▼──────────────────┐
  │  Internal pipeline components   │
  │  audio.rs    - Mel spectrogram  │
  │  encoder.rs  - ONNX encoder     │
  │  decoder.rs  - ONNX decoder     │
  │  tokenizer.rs - BPE tokenize    │
  │  model.rs    - Model download   │
  └─────────────────────────────────┘
```

## Model Management

### ONNX Model Files (matching actual HuggingFace repo)

Models are stored at:
```
%LOCALAPPDATA%/com.voicemind.voiceinput/models/qwen3-asr-onnx-{size}/
├── encoder_conv.onnx              # Conv2D stem (~small)
├── encoder_conv.onnx.data         # Conv2D weights (~50 MB)
├── encoder_transformer.onnx       # Transformer encoder (~small)
├── encoder_transformer.onnx.data  # Transformer weights (~701 MB)
├── decoder_init.int8.onnx         # Decoder prefill, INT8 quantized (~598 MB)
├── decoder_step.int8.onnx         # Decoder step, INT8 quantized (~598 MB)
├── embed_tokens.bin               # Embedding weights, FP32 (~622 MB)
└── tokenizer.json                 # GPT-2 BPE tokenizer
```

**Total disk: ~2.5 GB for 0.6B model. Total RAM at runtime: ~2.5+ GB.**

### Model Source

- **Primary**: Download pre-exported ONNX models from `Daumee/Qwen3-ASR-0.6B-ONNX-CPU` on HuggingFace
- **Fallback**: Provide Python conversion script (referencing `andrewleech/qwen3-asr-onnx`) for users to convert SafeTensors to ONNX
- **1.7B support**: Deferred until ONNX export becomes available on HuggingFace
- Download progress reported via new `qwen3-onnx-download-progress` event (separate from existing `qwen3-download-progress` which tracks SafeTensors)

### ONNX Tensor Names (critical for implementation)

**encoder_conv.onnx:**
- Input: `"padded_mel_chunks"` → shape `[num_chunks, 128, 100]`
- Output: `"conv_output"` → shape `[num_chunks, hidden, chunk_tokens]`

**encoder_transformer.onnx:**
- Input: `"hidden_states"` → encoder features, `"attention_mask"` → padding mask
- Output: audio token embeddings

**decoder_init.onnx:**
- Input: `"input_embeds"`, `"position_ids"`
- Output: `"logits"`, `"present_keys"`, `"present_values"` (KV cache)

**decoder_step.onnx:**
- Input: `"input_embeds"`, `"position_ids"`, `"past_keys"`, `"past_values"`
- Output: `"logits"`, `"present_keys"`, `"present_values"`

### Model Lifecycle

```
First use → detect ONNX model dir → not found → trigger download → load engine
Reuse     → detect ONNX model dir → found     → load engine directly
Switch    → unload old engine → load new size
```

### Model Check Function

`is_onnx_model_downloaded(size)` checks for all required files:
- `encoder_conv.onnx` + `encoder_conv.onnx.data`
- `encoder_transformer.onnx` + `encoder_transformer.onnx.data`
- `decoder_init.int8.onnx`
- `decoder_step.int8.onnx`
- `embed_tokens.bin`
- `tokenizer.json`

## Streaming Recognition Pipeline

### Approach: Rolling Window (No VAD)

No VAD segmentation. Audio accumulates continuously; a timer triggers full re-inference on all buffered audio every ~500ms.

```
Timeline:  |--0.5s--|--1.0s--|--1.5s--|--2.0s--|--2.5s--|
                      │         │         │         │
Inference:          encode    encode    encode    encode
                    +decode   +decode   +decode   +decode
                      │         │         │         │
Results:          "今天"    "今天天气"  "今天天气很好" "今天天气很好" (final)
```

### Flow

```
iPhone audio stream (continuous PCM s16le)
        │
        ▼
Convert s16le → f32 (divide by 32768.0)
        │
        ▼
Audio buffer (Arc<Mutex<Vec<f32>>>, accumulates)
        │ Every ~500ms tick (tokio interval)
        ▼
Lock buffer, clone all audio [0..current_len], release lock
        │
        ▼
Mel Spectrogram (128 bins, 25ms window, 10ms hop)
  - STFT: n_fft=400, hop=160, center=True, pad_mode="reflect", Hann window
  - Mel filter bank: Slaney norm, 128 bins, 0-8kHz
  - Log: log10(clamp(mel, 1e-10)), dynamic range clamp (max - 8.0), normalize: (x + 4.0) / 4.0
  - Chunk into 100-frame blocks, pad last chunk
        │ mel: [1, 128, T]
        ▼
encoder_conv.onnx → encoder_transformer.onnx
        │ audio_tokens: [1, num_tokens, 1024]
        ▼
Build input sequence: system_prompt + <|audio_pad|> placeholders (token 151676)
Replace <|audio_pad|> embeddings with audio_tokens
        │
        ▼
decoder_init.int8.onnx (prefill → first token + initial KV cache)
        │
        ▼
decoder_step.int8.onnx (autoregressive loop until EOS or max length)
        │
        ▼
BPE detokenize → Chinese text string
        │
        ├── Partial → emit("partial-result") → overlay real-time display
        │
        │ (recording ends)
        ▼
Final inference on full audio
        │
        └── Final → emit("recognition-result") → text injection
```

### Qwen3OnnxState (per-session, thread-safe)

```rust
pub struct Qwen3OnnxState {
    engine: Arc<Qwen3AsrEngine>,
    audio_buffer: Arc<Mutex<Vec<f32>>>,       // shared between audio feed and timer
    interval_handle: Option<tokio::task::JoinHandle<()>>,
    last_partial: Arc<Mutex<String>>,          // dedup partial results
    cancel_token: CancellationToken,           // graceful shutdown of timer loop
}
```

**Concurrency design:**
- `audio_buffer` wrapped in `Arc<Mutex<...>>` — audio data callback appends, timer task clones and releases lock quickly
- Timer task clones the full buffer on each tick, then releases the lock before starting inference (which is slow)
- `CancellationToken` from `tokio_util` to gracefully stop the timer loop on finalize
- `finalize()` cancels the timer first, then does one final inference

### Performance Optimizations

- Skip inference if audio < 0.3s (too short for meaningful result)
- For long audio (>30s), reduce inference frequency to ~1s interval
- Deduplicate partial results: only emit if text changed
- Buffer lock held only during clone, not during inference

## Struct Changes

### AppState addition (main.rs)

```rust
// Add to AppState:
pub qwen3_onnx_engine: Arc<Mutex<Option<qwen3_onnx::Qwen3AsrEngine>>>,
```

### Connection addition (network.rs)

```rust
// Add to Connection struct:
pub qwen3_onnx_state: Option<Qwen3OnnxState>,
```

### Engine loading

- On app startup: if `settings.asr_engine == "qwen3_onnx"` and model exists, load engine into `AppState`
- On engine switch: Tauri command `load_qwen3_onnx_engine` loads/unloads engine
- Engine load is synchronous and blocking (~3-5 seconds), run in `tokio::task::spawn_blocking`

## Engine Integration

### network.rs Dispatch

```rust
// handle_audio_start
"qwen3_onnx" => {
    let engine = app_state.qwen3_onnx_engine.lock().await.clone();
    let state = Qwen3OnnxState::new(engine.unwrap());
    state.start_streaming_loop(event_emitter); // 500ms interval
    conn.qwen3_onnx_state = Some(state);
}

// handle_audio_data
"qwen3_onnx" => {
    // Convert s16le bytes to f32 and append to buffer
    let f32_samples: Vec<f32> = pcm_bytes.chunks(2)
        .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]) as f32 / 32768.0)
        .collect();
    state.audio_buffer.lock().await.extend(f32_samples);
}

// handle_audio_end
"qwen3_onnx" => {
    let final_text = state.finalize().await; // cancel timer, final inference
    // inject text + emit result
}
```

### Qwen3AsrEngine API

```rust
pub struct Qwen3AsrEngine {
    session_encoder_conv: Session,         // ort::Session
    session_encoder_transformer: Session,  // ort::Session
    session_decoder_init: Session,         // ort::Session
    session_decoder_step: Session,         // ort::Session
    embed_tokens: ndarray::Array2<f32>,    // pre-loaded embeddings
    tokenizer: tokenizers::Tokenizer,      // BPE tokenizer
    config: ModelConfig,                   // model size-specific config
}

impl Qwen3AsrEngine {
    /// Load all ONNX sessions + embeddings + tokenizer
    /// ~3-5 seconds, ~2.5 GB RAM for 0.6B
    pub fn new(model_dir: &Path) -> Result<Self>;

    /// Full pipeline: PCM f32 → mel → encode → decode → text
    pub fn transcribe(&self, pcm: &[f32], sample_rate: u32) -> Result<String>;

    /// Release all sessions and tensors
    pub fn unload(&mut self);
}
```

## New Tauri Commands (commands.rs)

```rust
#[tauri::command]
async fn load_qwen3_onnx_engine(model_size: String, state: State<'_, AppState>) -> Result<(), String>;

#[tauri::command]
async fn unload_qwen3_onnx_engine(state: State<'_, AppState>) -> Result<(), String>;

#[tauri::command]
async fn get_qwen3_onnx_status(state: State<'_, AppState>) -> Result<Qwen3OnnxStatus, String>;

#[tauri::command]
async fn check_qwen3_onnx_model(model_size: String) -> Result<bool, String>;

#[tauri::command]
async fn download_qwen3_onnx_model(model_size: String, state: State<'_, AppState>) -> Result<(), String>;
```

## Error Handling

| Error Type | Handling |
|---|---|
| Model files missing | Auto-trigger download, show progress bar |
| Model load failure | Emit error event, prompt user to retry |
| Inference timeout (>10s) | Skip this round, wait for next timer tick |
| Audio too short (<0.3s) | Skip inference |
| ONNX Runtime error | Log error, continue timer loop, don't crash |
| Out of memory | Unload engine, suggest smaller model or different engine |
| Timer task panic | Catch via `JoinHandle`, log, create new state on next audio_start |

## Frontend Changes

### Settings Page

Add fourth option to engine selector:
```js
{ value: "qwen3_onnx", label: "Qwen3 ONNX (本地流式)" }
```

### First-use Flow

1. User selects `qwen3_onnx`
2. Call `check_qwen3_onnx_model` to verify files exist
3. Not found → show download dialog, call `download_qwen3_onnx_model`
4. Download complete → call `load_qwen3_onnx_engine`
5. Engine ready → status shown in settings

### Streaming Display

- `partial-result` event → overlay window shows text in real-time
- `recognition-result` event → inject final text at cursor position
- Reuses existing overlay and main window event listeners, no additional frontend work needed

## Mel Spectrogram Implementation Details

### Dependencies needed

```toml
rustfft = "6"    # FFT for STFT computation
```

### Implementation steps

1. **STFT**: n_fft=400, hop_length=160, center=True (pad with reflect), Hann window
2. **Power spectrum**: `|STFT|^2`, take first n_fft/2+1 = 201 bins
3. **Mel filter bank**: 128 bins, Slaney normalization, fmin=0, fmax=8000, sample_rate=16000
   - Slaney formula: `M(f) = 2595 * log10(1 + f/700)`
   - Filter weights: triangle filters with area normalization
4. **Log compression**: `log10(max(mel_power, 1e-10))`
5. **Dynamic range compression**: clamp each mel vector to `[max - 8.0, max]`
6. **Normalization**: `(log_spec + 4.0) / 4.0` to map to roughly [0, 1]
7. **Chunking**: Split mel into 100-frame chunks, pad last chunk with zeros

### Encoder chunking pipeline

```
mel spectrogram: [1, 128, T]
       │
       ▼ split into chunks of 100 frames
chunks: [num_chunks, 128, 100]  (last chunk zero-padded)
       │
       ▼ encoder_conv.onnx
conv_output: [num_chunks, 480, 13]
       │
       ▼ remove padding, reshape to [total_tokens, hidden]
       │
       ▼ encoder_transformer.onnx (with attention_mask)
audio_tokens: [1, total_tokens, 1024]
```

## Model Architecture Reference

### Audio Encoder (0.6B)
- Conv2D stem: 3 layers (1→480→480→480, 3x3 kernel, stride 2), 8x downsampling
- Chunks of 100 mel frames → 13 tokens each
- Sinusoidal position embeddings per-chunk
- Windowed self-attention within 104-token windows
- 18 Transformer layers: d_model=896, 14 heads, FFN=3584, GELU, LayerNorm
- Projection: Linear(896→1024) + GELU + Linear(1024→1024)

### LLM Decoder (0.6B)
- 28 layers, hidden=1024, 16 attn heads, 8 KV heads (GQA), head_dim=128
- RMSNorm, causal attention, Q/K per-head RMSNorm, MRoPE (theta=1e6)
- SwiGLU MLP, no biases
- Tied embeddings (separated in ONNX export)

### Audio Preprocessing
- 16kHz sample rate, 128 mel bins, 25ms window (400 samples), 10ms hop (160 samples), Hann window
- Slaney mel scale, 0-8kHz range
- Normalization: `log10(clamp(mel, min=1e-10))`, dynamic range clamp (max - 8.0), then `(log_spec + 4.0) / 4.0`

### Tokenizer
- GPT-2 style byte-level BPE, vocab size 151,936
- Special tokens: `<|audio_pad|>` (151676) for embedding replacement

## Memory Requirements

| Component | 0.6B Model |
|---|---|
| encoder_conv.onnx.data | ~50 MB |
| encoder_transformer.onnx.data | ~701 MB |
| decoder_init.int8.onnx | ~598 MB |
| decoder_step.int8.onnx | ~598 MB |
| embed_tokens.bin | ~622 MB |
| KV cache + runtime | ~200+ MB |
| **Total RAM** | **~2.5+ GB** |

Recommendation: display memory requirement in settings UI. Warn if system has < 4 GB free.

## File Structure (New Files)

```
VoiceMindWindows/src-tauri/src/
├── qwen3_onnx/
│   ├── mod.rs          # Module exports
│   ├── engine.rs       # Qwen3AsrEngine (high-level API)
│   ├── audio.rs        # Mel spectrogram preprocessing (FFT, mel bank, chunking)
│   ├── encoder.rs      # ONNX encoder inference (conv + transformer)
│   ├── decoder.rs      # ONNX decoder inference (init + step loop)
│   ├── tokenizer.rs    # BPE tokenizer wrapper (encode/decode)
│   └── model.rs        # Model download, check, management
├── qwen_asr.rs         # Existing engine (unchanged)
├── network.rs          # Add "qwen3_onnx" dispatch branch + Connection field
├── commands.rs         # Add 5 new Tauri commands for ONNX engine
└── main.rs             # Add qwen3_onnx_engine to AppState
```

## Dependencies (Cargo.toml additions)

```toml
[dependencies]
ort = { version = "2.0.0-rc.12", features = ["load-dynamic"] }
ndarray = "0.16"         # Tensor operations for mel spectrogram
rustfft = "6"            # FFT for STFT computation
tokenizers = "0.21"      # HuggingFace tokenizer (BPE)
tokio-util = "0.7"       # CancellationToken for timer loop
```

## Key Reference Projects

- `andrewleech/qwen3-asr-onnx` — ONNX export pipeline, tensor names reference
- `Daumee/Qwen3-ASR-0.6B-ONNX-CPU` — Pre-exported ONNX model on HuggingFace
- `antirez/qwen-asr` — Complete Python reference implementation with architecture docs (`MODEL.md`, `python_simple_implementation.py`)
- `whisper-rs` — API design pattern reference

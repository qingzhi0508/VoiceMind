# Qwen3-ASR Rust ONNX Engine Design

**Date**: 2026-04-16
**Status**: Approved
**Branch**: feature/win-4

## Overview

Add a fourth ASR engine option (`qwen3_onnx`) to VoiceMind Windows that uses Rust-native ONNX Runtime (via `ort` crate) to run Qwen3-ASR inference directly in-process. This replaces the current external `qwen_asr.exe` subprocess approach with a whisper-rs-style high-level wrapper that provides true streaming recognition (rolling window, no VAD segmentation).

## Goals

- Pure Rust implementation, no Python or external process dependency
- True streaming recognition: partial results appear in real-time as user speaks
- CPU-only inference via ONNX Runtime, compatible with all Windows devices
- Support both 0.6B and 1.7B model sizes
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

### ONNX Model Files

Models are stored at:
```
%LOCALAPPDATA%/com.voicemind.voiceinput/models/qwen3-asr-onnx-{0.6b|1.7b}/
├── encoder.onnx          # Audio encoder (single forward pass)
├── decoder_init.onnx     # Decoder prefill (first token generation)
├── decoder_step.onnx     # Decoder autoregressive step
├── decoder_weights.data  # Shared decoder weights
├── embed_tokens.bin      # Embedding weights (FP16)
└── tokenizer.json        # GPT-2 BPE tokenizer
```

### Model Source

- **Primary**: Download pre-exported ONNX models from HuggingFace (`Daumee/Qwen3-ASR-0.6B-ONNX-CPU` and equivalent 1.7B)
- **Fallback**: Provide Python conversion script (referencing `andrewleech/qwen3-asr-onnx`) for users to convert SafeTensors to ONNX
- Download progress reported via existing `qwen3-download-progress` event

### Model Lifecycle

```
First use → detect ONNX model dir → not found → trigger download → load engine
Reuse     → detect ONNX model dir → found     → load engine directly
Switch    → unload old engine → load new size
```

Engine loading is expensive (loads ONNX into memory). Done at `AppState` init or when user switches engine/size. Frontend shows loading state.

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
iPhone audio stream (continuous PCM)
        │
        ▼
Audio buffer (Vec<f32>, accumulates)
        │ Every ~500ms tick
        ▼
Take all buffered audio [0..current_len]
        │
        ▼
Mel Spectrogram (128 bins, 25ms window, 10ms hop)
        │ mel: [1, 128, T]
        ▼
encoder.onnx (Conv2D stem + 18-layer Transformer)
        │ audio_tokens: [1, num_tokens, 1024]
        ▼
Build input sequence: system_prompt + <|audio_pad|> placeholders
Replace <|audio_pad|> embeddings with audio_tokens
        │
        ▼
decoder_init.onnx (prefill → first token + initial KV cache)
        │
        ▼
decoder_step.onnx (autoregressive loop until EOS or max length)
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

### Qwen3OnnxState (per-session)

```rust
pub struct Qwen3OnnxState {
    engine: Arc<Qwen3AsrEngine>,
    audio_buffer: Vec<f32>,
    interval_handle: JoinHandle<()>,
    last_partial: String,
}
```

### Performance Optimizations

- Skip inference if audio < 0.3s (too short for meaningful result)
- For long audio (>30s), reduce inference frequency to ~1s interval
- Deduplicate partial results: only emit if text changed
- `ort::Session` is thread-safe; timer and final inference can overlap safely

## Engine Integration

### network.rs Dispatch

```rust
// handle_audio_start
"qwen3_onnx" => {
    let state = Qwen3OnnxState::new(engine.clone());
    state.start_streaming_loop(event_emitter); // 500ms interval
}

// handle_audio_data
"qwen3_onnx" => {
    state.push_audio(&pcm_data); // append to buffer
}

// handle_audio_end
"qwen3_onnx" => {
    let final_text = state.finalize().await; // stop timer, final inference
    // inject text + emit result
}
```

### Qwen3AsrEngine API

```rust
pub struct Qwen3AsrEngine {
    session_encoder: Session,
    session_decoder_init: Session,
    session_decoder_step: Session,
    embed_tokens: Tensor,
    tokenizer: Tokenizer,
    config: ModelConfig,
}

impl Qwen3AsrEngine {
    pub fn new(model_dir: &Path) -> Result<Self>;
    pub fn transcribe(&self, pcm: &[f32], sample_rate: u32) -> Result<String>;
    pub fn unload(&mut self);
}
```

## Error Handling

| Error Type | Handling |
|---|---|
| Model files missing | Auto-trigger download, show progress bar |
| Model load failure | Emit error event, prompt user to retry |
| Inference timeout (>10s) | Skip this round, wait for next timer tick |
| Audio too short (<0.3s) | Skip inference |
| ONNX Runtime error | Emit error event, log, don't crash |
| Out of memory | Unload engine, suggest smaller model |

## Frontend Changes

### Settings Page

Add fourth option to engine selector:
```js
{ value: "qwen3_onnx", label: "Qwen3 ONNX (本地流式)" }
```

### First-use Flow

1. User selects `qwen3_onnx`
2. Check ONNX model existence
3. Not found → show download dialog (reuse `qwen3-binary-download-progress` event)
4. Download complete → auto-load engine
5. Engine ready

### Streaming Display

- `partial-result` event → overlay window shows text in real-time
- `recognition-result` event → inject final text at cursor position
- Reuses existing overlay and main window event listeners, no additional frontend work needed

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
- 16kHz sample rate, 128 mel bins, 25ms window, 10ms hop, Hann window
- Slaney mel scale, 0-8kHz range
- Normalization: `log10(clamp(mel, min=1e-10))`, dynamic range clamp (max - 8.0), then `(log_spec + 4.0) / 4.0`

### Tokenizer
- GPT-2 style byte-level BPE, vocab size 151,936
- Special tokens: `<|audio_pad|>` (151676) for embedding replacement

## File Structure (New Files)

```
VoiceMindWindows/src-tauri/src/
├── qwen3_onnx/
│   ├── mod.rs          # Module exports
│   ├── engine.rs       # Qwen3AsrEngine (high-level API)
│   ├── audio.rs        # Mel spectrogram preprocessing
│   ├── encoder.rs      # ONNX encoder inference
│   ├── decoder.rs      # ONNX decoder inference (init + step)
│   ├── tokenizer.rs    # BPE tokenizer (encode/decode)
│   └── model.rs        # Model download and management
├── qwen_asr.rs         # Existing engine (unchanged)
├── network.rs          # Add "qwen3_onnx" dispatch branch
├── commands.rs         # Add engine load/check Tauri commands
└── main.rs             # Add engine to AppState
```

## Dependencies (Cargo.toml additions)

```toml
[dependencies]
ort = { version = "2", features = ["load-dynamic"] }
ndarray = "0.16"        # Tensor operations for mel spectrogram
tokenizers = "0.21"     # HuggingFace tokenizer (BPE)
```

## Key Reference Projects

- `andrewleech/qwen3-asr-onnx` — ONNX export pipeline
- `Daumee/Qwen3-ASR-0.6B-ONNX-CPU` — Pre-exported ONNX model on HuggingFace
- `antirez/qwen-asr` — Complete Python reference implementation with architecture docs
- `whisper-rs` — API design pattern reference

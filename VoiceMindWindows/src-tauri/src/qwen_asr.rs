use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::mpsc;
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QwenAsrConfig {
    pub model_size: String,
    pub model_dir: PathBuf,
    pub language: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QwenModelInfo {
    pub size: String,
    pub downloaded: bool,
    pub total_size_bytes: u64,
    pub model_dir: PathBuf,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Qwen3CheckResult {
    pub binary_available: bool,
    pub models: Vec<QwenModelInfo>,
}

#[derive(Debug, Clone, Serialize)]
pub struct Qwen3DownloadProgress {
    pub model_size: String,
    pub status: String,
    pub progress: f64,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub current_file: String,
}

/// Returns the models directory: %LOCALAPPDATA%/com.voicemind.voiceinput/models/
pub fn get_models_dir() -> PathBuf {
    let local_app_data = std::env::var("LOCALAPPDATA")
        .unwrap_or_else(|_| ".".to_string());
    PathBuf::from(local_app_data)
        .join("com.voicemind.voiceinput")
        .join("models")
}

/// Returns the model directory for a given size
pub fn get_model_dir(size: &str) -> PathBuf {
    get_models_dir().join(format!("qwen3-asr-{}", size))
}

/// Find the qwen_asr.exe binary
pub fn get_binary_path() -> Option<PathBuf> {
    // 1. Check next to the running executable
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let bin_path = dir.join("bin").join("qwen_asr.exe");
            if bin_path.exists() {
                return Some(bin_path);
            }
        }
    }

    // 2. Check in current working directory
    let cwd_bin = PathBuf::from("bin").join("qwen_asr.exe");
    if cwd_bin.exists() {
        return Some(cwd_bin);
    }

    // 3. Check in models dir
    let models_bin = get_models_dir().join("qwen_asr.exe");
    if models_bin.exists() {
        return Some(models_bin);
    }

    None
}

/// Check if the qwen_asr binary is available
pub fn check_binary_available() -> Result<PathBuf, String> {
    get_binary_path().ok_or_else(|| "qwen_asr.exe not found. Place it in bin/ directory.".to_string())
}

/// Prepare a command with DLL search paths set for Windows
pub fn prepare_command(binary_path: &PathBuf) -> tokio::process::Command {
    let mut cmd = tokio::process::Command::new(binary_path);
    if let Some(bin_dir) = binary_path.parent() {
        // Set working directory to bin dir (Windows searches DLLs in cwd first)
        cmd.current_dir(bin_dir);
        // Also prepend to PATH as fallback
        let bin_dir_str = bin_dir.to_string_lossy().to_string();
        let current_path = std::env::var("PATH").unwrap_or_default();
        let new_path = format!("{};{}", bin_dir_str, current_path);
        cmd.env("PATH", new_path);
    }
    #[cfg(windows)]
    {
        #[allow(unused_imports)]
        use std::os::windows::process::CommandExt;
        cmd.creation_flags(0x08000000); // CREATE_NO_WINDOW
    }
    cmd
}

/// Get model info for a specific size
pub fn get_model_info(size: &str) -> QwenModelInfo {
    let model_dir = get_model_dir(size);
    let total_size = estimate_model_size(size);

    // Check if essential model files exist
    let downloaded = is_model_downloaded(&model_dir, size);

    QwenModelInfo {
        size: size.to_string(),
        downloaded,
        total_size_bytes: total_size,
        model_dir,
    }
}

fn estimate_model_size(size: &str) -> u64 {
    match size {
        "0.6b" => 1_300_000_000,  // ~1.3 GB
        "1.7b" => 3_500_000_000,  // ~3.5 GB
        _ => 0,
    }
}

fn is_model_downloaded(model_dir: &PathBuf, size: &str) -> bool {
    if !model_dir.exists() {
        return false;
    }

    // Check for essential model files
    let model_file = model_dir.join("model.safetensors");
    let index_file = model_dir.join("model.safetensors.index.json");
    let tokenizer_file = model_dir.join("tokenizer.json");
    let vocab_file = model_dir.join("vocab.json");

    let has_model = model_file.exists() || index_file.exists();
    let has_tokenizer = tokenizer_file.exists() || vocab_file.exists();

    if !has_model || !has_tokenizer {
        info!(
            "Qwen3 model {} missing files: model={}, tokenizer={}",
            size,
            has_model,
            has_tokenizer
        );
        return false;
    }

    info!("Qwen3 model {} appears complete at {:?}", size, model_dir);
    true
}

/// Write WAV file from raw PCM data
pub fn write_wav_file(path: &std::path::Path, pcm_data: &[u8], sample_rate: u32, channels: u32) -> Result<(), String> {
    use std::io::Write;
    let data_len = pcm_data.len() as u32;
    let file = std::fs::File::create(path).map_err(|e| e.to_string())?;
    let mut writer = std::io::BufWriter::new(file);
    let bits_per_sample: u16 = 16;
    let byte_rate = sample_rate * channels * (bits_per_sample as u32 / 8);
    let block_align = (channels * (bits_per_sample as u32 / 8)) as u16;

    writer.write_all(b"RIFF").map_err(|e| e.to_string())?;
    writer.write_all(&(36 + data_len).to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(b"WAVE").map_err(|e| e.to_string())?;
    writer.write_all(b"fmt ").map_err(|e| e.to_string())?;
    writer.write_all(&16u32.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&1u16.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&(channels as u16).to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&sample_rate.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&byte_rate.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&block_align.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(&bits_per_sample.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(b"data").map_err(|e| e.to_string())?;
    writer.write_all(&data_len.to_le_bytes()).map_err(|e| e.to_string())?;
    writer.write_all(pcm_data).map_err(|e| e.to_string())?;
    Ok(())
}

/// Offline recognition using qwen_asr.exe
#[allow(dead_code)]
pub async fn recognize_offline(
    audio_data: &[u8],
    sample_rate: u32,
    channels: u32,
    config: &QwenAsrConfig,
) -> Result<String, String> {
    let binary_path = check_binary_available()?;
    let model_dir = get_model_dir(&config.model_size);

    if !is_model_downloaded(&model_dir, &config.model_size) {
        return Err(format!("Qwen3 model {} not downloaded", config.model_size));
    }

    // Write temp WAV file
    let wav_path = std::env::temp_dir().join(format!("qwen3_asr_{}.wav", uuid::Uuid::new_v4()));
    write_wav_file(&wav_path, audio_data, sample_rate, channels)?;

    let result = run_qwen_asr_binary(&binary_path, &model_dir, &wav_path, false).await;

    let _ = std::fs::remove_file(&wav_path);
    result
}

/// Streaming recognition - runs qwen_asr with --stream flag
pub async fn recognize_streaming(
    audio_data: &[u8],
    sample_rate: u32,
    channels: u32,
    config: &QwenAsrConfig,
    event_emitter: &crate::events::EventEmitter,
    session_id: &str,
) -> Result<String, String> {
    let binary_path = check_binary_available()?;
    let model_dir = get_model_dir(&config.model_size);

    if !is_model_downloaded(&model_dir, &config.model_size) {
        return Err(format!("Qwen3 model {} not downloaded", config.model_size));
    }

    // Write temp WAV file
    let wav_path = std::env::temp_dir().join(format!("qwen3_asr_stream_{}.wav", uuid::Uuid::new_v4()));
    write_wav_file(&wav_path, audio_data, sample_rate, channels)?;

    let model_dir_str = model_dir.to_string_lossy().to_string();
    let wav_str = wav_path.to_string_lossy().to_string();

    let mut cmd = prepare_command(&binary_path);
    cmd.arg("-d").arg(&model_dir_str)
       .arg("-i").arg(&wav_str)
       .arg("--stream")
       .arg("--silent")
       .stdout(std::process::Stdio::piped())
       .stderr(std::process::Stdio::piped());

    let mut child = cmd.spawn()
        .map_err(|e| format!("Failed to spawn qwen_asr: {}", e))?;

    let stdout = child.stdout.take().ok_or("Failed to capture stdout")?;
    let reader = BufReader::new(stdout);
    let mut lines = reader.lines();

    let mut final_text = String::new();

    while let Some(line) = lines.next_line().await.map_err(|e| format!("Read error: {}", e))? {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        // Try to parse as JSON (streaming output)
        if let Ok(json) = serde_json::from_str::<serde_json::Value>(trimmed) {
            if let Some(text) = json.get("text").and_then(|t| t.as_str()) {
                let is_final = json.get("is_final").and_then(|f| f.as_bool()).unwrap_or(false);
                if !text.is_empty() {
                    event_emitter.emit_partial_result(
                        text.to_string(),
                        config.language.clone(),
                        session_id.to_string(),
                    );
                }
                if is_final {
                    final_text = text.to_string();
                } else {
                    final_text = text.to_string();
                }
            }
        } else {
            // Plain text output - treat each line as a partial result
            if !trimmed.is_empty() {
                final_text = trimmed.to_string();
                event_emitter.emit_partial_result(
                    trimmed.to_string(),
                    config.language.clone(),
                    session_id.to_string(),
                );
            }
        }
    }

    let status = child.wait().await.map_err(|e| format!("Wait error: {}", e))?;
    let _ = std::fs::remove_file(&wav_path);

    if !status.success() && final_text.is_empty() {
        return Err(format!("qwen_asr exited with code {:?}", status.code()));
    }

    if final_text.trim().is_empty() {
        return Err("No recognition result from Qwen3-ASR".to_string());
    }

    Ok(final_text)
}

/// Run qwen_asr binary for offline recognition
#[allow(dead_code)]
async fn run_qwen_asr_binary(
    binary_path: &PathBuf,
    model_dir: &PathBuf,
    wav_path: &PathBuf,
    stream: bool,
) -> Result<String, String> {
    let model_dir_str = model_dir.to_string_lossy().to_string();
    let wav_str = wav_path.to_string_lossy().to_string();

    let mut cmd = prepare_command(binary_path);
    cmd.arg("-d").arg(&model_dir_str)
       .arg("-i").arg(&wav_str)
       .arg("--silent");

    if stream {
        cmd.arg("--stream");
    }

    cmd.stdout(std::process::Stdio::piped())
       .stderr(std::process::Stdio::piped());

    let output = cmd.output().await.map_err(|e| format!("Failed to run qwen_asr: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    info!("qwen_asr stdout: {:?}, stderr: {:?}", stdout, stderr);

    if !output.status.success() {
        return Err(format!("qwen_asr failed: {}", stderr));
    }

    // Try to parse JSON output
    if let Ok(json) = serde_json::from_str::<serde_json::Value>(&stdout) {
        if let Some(text) = json.get("text").and_then(|t| t.as_str()) {
            return Ok(text.to_string());
        }
    }

    // Return raw stdout as text
    if stdout.is_empty() {
        return Err("No recognition result".to_string());
    }

    Ok(stdout)
}

/// Download a Qwen3 model from HuggingFace
pub async fn download_model(
    size: &str,
    app_handle: AppHandle,
) -> Result<(), String> {
    let model_dir = get_model_dir(size);
    std::fs::create_dir_all(&model_dir)
        .map_err(|e| format!("Failed to create model directory: {}", e))?;

    let model_id = format!("Qwen/Qwen3-ASR-{}", size);
    let api_url = format!("https://huggingface.co/api/models/{}", model_id);

    info!("Fetching model file list from {}", api_url);

    let client = reqwest::Client::new();
    let response = client.get(&api_url)
        .send().await
        .map_err(|e| format!("Failed to fetch model info: {}", e))?;

    if !response.status().is_success() {
        return Err(format!("HuggingFace API returned status {}", response.status()));
    }

    let model_info: serde_json::Value = response.json::<serde_json::Value>().await
        .map_err(|e| format!("Failed to parse model info: {}", e))?;

    // Extract file list from siblings
    let siblings: Vec<serde_json::Value> = model_info.get("siblings")
        .and_then(|s: &serde_json::Value| s.as_array())
        .cloned()
        .unwrap_or_default();

    // Filter to relevant files (safetensors, tokenizer, config)
    let mut relevant_files: Vec<String> = Vec::new();
    for sib in &siblings {
        if let Some(fname) = sib.get("rfilename").and_then(|r: &serde_json::Value| r.as_str()) {
            let f: &str = fname;
            if f.ends_with(".safetensors") ||
                f.ends_with(".safetensors.index.json") ||
                f == "tokenizer.json" ||
                f == "tokenizer_config.json" ||
                f == "config.json" ||
                f == "generation_config.json" ||
                f == "special_tokens_map.json" ||
                f == "vocab.json" ||
                f.ends_with(".model")
            {
                relevant_files.push(f.to_string());
            }
        }
    }

    if relevant_files.is_empty() {
        return Err("No model files found on HuggingFace".to_string());
    }

    info!("Files to download for {}: {:?}", size, relevant_files);

    let total_files = relevant_files.len();
    for (idx, filename) in relevant_files.iter().enumerate() {
        let file_url = format!(
            "https://huggingface.co/{}/resolve/main/{}",
            model_id, filename
        );

        let dest_path = model_dir.join(filename.as_str());

        // Skip already downloaded files
        if dest_path.exists() {
            info!("Skipping already downloaded: {}", filename);
            continue;
        }

        info!("Downloading {} ({}/{})...", filename, idx + 1, total_files);

        // Emit progress: starting
        let _ = app_handle.emit("qwen3-download-progress", Qwen3DownloadProgress {
            model_size: size.to_string(),
            status: "downloading".to_string(),
            progress: (idx as f64) / (total_files as f64),
            downloaded_bytes: 0,
            total_bytes: 0,
            current_file: filename.clone(),
        });

        let response = client.get(&file_url)
            .send().await
            .map_err(|e| format!("Failed to download {}: {}", filename, e))?;

        let total_size = response.content_length().unwrap_or(0);
        let mut downloaded: u64 = 0;

        // Create parent dirs if needed
        if let Some(parent) = dest_path.parent() {
            std::fs::create_dir_all(parent).ok();
        }

        let mut file = tokio::fs::File::create(&dest_path).await
            .map_err(|e| format!("Failed to create file {}: {}", filename, e))?;

        let mut stream = response.bytes_stream();
        use tokio::io::AsyncWriteExt;

        while let Some(chunk) = stream.next().await {
            let chunk = chunk.map_err(|e| format!("Download error: {}", e))?;
            file.write_all(&chunk).await.map_err(|e| e.to_string())?;
            downloaded += chunk.len() as u64;

            // Emit progress
            let file_progress = if total_size > 0 {
                downloaded as f64 / total_size as f64
            } else {
                0.0
            };
            let overall_progress = (idx as f64 + file_progress) / (total_files as f64);

            let _ = app_handle.emit("qwen3-download-progress", Qwen3DownloadProgress {
                model_size: size.to_string(),
                status: "downloading".to_string(),
                progress: overall_progress,
                downloaded_bytes: downloaded,
                total_bytes: total_size,
                current_file: filename.clone(),
            });
        }

        file.flush().await.map_err(|e| e.to_string())?;
        info!("Downloaded {} ({} bytes)", filename, downloaded);
    }

    // Emit completed
    let _ = app_handle.emit("qwen3-download-progress", Qwen3DownloadProgress {
        model_size: size.to_string(),
        status: "completed".to_string(),
        progress: 1.0,
        downloaded_bytes: 0,
        total_bytes: 0,
        current_file: String::new(),
    });

    info!("Qwen3-ASR model {} download completed", size);
    Ok(())
}

/// Delete a downloaded model
pub fn delete_model(size: &str) -> Result<(), String> {
    let model_dir = get_model_dir(size);

    if !model_dir.exists() {
        return Err(format!("Model {} not found", size));
    }

    std::fs::remove_dir_all(&model_dir)
        .map_err(|e| format!("Failed to delete model: {}", e))?;

    info!("Deleted Qwen3-ASR model {}", size);
    Ok(())
}

/// Live session for preloaded Qwen3-ASR model.
/// The model is loaded when the session is created, eliminating the 3-5s cold start delay.
#[allow(dead_code)]
pub struct Qwen3LiveSession {
    stdin: Option<tokio::process::ChildStdin>,
    child: Option<tokio::process::Child>,
    stdout_rx: mpsc::UnboundedReceiver<String>,
    _model_size: String,
}

#[allow(dead_code)]
impl Qwen3LiveSession {
    /// Start a new live session by spawning `qwen_asr.exe --stdin`.
    /// The model loads immediately; audio can then be fed via `feed_audio()`.
    pub async fn new(model_size: &str, _language: &str) -> Result<Self, String> {
        let binary_path = check_binary_available()?;
        let model_dir = get_model_dir(model_size);

        if !is_model_downloaded(&model_dir, model_size) {
            return Err(format!("Qwen3 model {} not downloaded", model_size));
        }

        let model_dir_str = model_dir.to_string_lossy().to_string();

        let mut cmd = prepare_command(&binary_path);
        cmd.arg("-d").arg(&model_dir_str)
            .arg("--stdin")
            .arg("--stream")
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped());

        let mut child = cmd.spawn()
            .map_err(|e| format!("Failed to spawn qwen_asr: {}", e))?;

        let stdin = child.stdin.take().ok_or("Failed to open stdin")?;
        let stdout = child.stdout.take().ok_or("Failed to capture stdout")?;

        // Background task: read stdout lines into channel
        let (tx, rx) = mpsc::unbounded_channel::<String>();
        tokio::spawn(async move {
            let reader = BufReader::new(stdout);
            let mut lines = reader.lines();
            while let Ok(Some(line)) = lines.next_line().await {
                let trimmed = line.trim().to_string();
                if !trimmed.is_empty() {
                    if tx.send(trimmed).is_err() {
                        break;
                    }
                }
            }
        });

        info!("Qwen3 live session started for model {}", model_size);

        Ok(Self {
            stdin: Some(stdin),
            child: Some(child),
            stdout_rx: rx,
            _model_size: model_size.to_string(),
        })
    }

    /// Feed raw PCM audio data (s16le 16kHz mono) to the process stdin.
    pub async fn feed_audio(&mut self, pcm_data: &[u8]) -> Result<(), String> {
        if let Some(ref mut stdin) = self.stdin {
            tokio::io::AsyncWriteExt::write_all(stdin, pcm_data).await
                .map_err(|e| format!("Failed to write audio to stdin: {}", e))?;
            Ok(())
        } else {
            Err("stdin already closed".to_string())
        }
    }

    /// Non-blocking read of the latest partial result from stdout (streaming tokens).
    /// Returns the last accumulated token text, or None if no new output.
    pub fn get_partial_result(&mut self) -> Option<String> {
        let mut last = None;
        while let Ok(line) = self.stdout_rx.try_recv() {
            if !line.is_empty() {
                last = Some(line);
            }
        }
        last
    }

    /// Close stdin (EOF), wait for the process to finish processing, return final text.
    pub async fn finish(&mut self) -> Result<String, String> {
        // Close stdin to signal EOF
        self.stdin.take();

        // Collect remaining stdout lines with timeout
        let mut final_text = String::new();
        loop {
            match tokio::time::timeout(
                std::time::Duration::from_secs(30),
                self.stdout_rx.recv(),
            ).await {
                Ok(Some(line)) => {
                    if !line.is_empty() {
                        final_text = line;
                    }
                }
                Ok(None) => break, // Channel closed (process exited)
                Err(_) => {
                    warn!("Timeout waiting for Qwen3 final result");
                    break;
                }
            }
        }

        // Wait for child process to exit
        if let Some(mut child) = self.child.take() {
            let _ = child.wait().await;
        }

        if final_text.trim().is_empty() {
            Err("No recognition result from Qwen3-ASR".to_string())
        } else {
            info!("Qwen3 live session result: {}", final_text);
            Ok(final_text)
        }
    }
}

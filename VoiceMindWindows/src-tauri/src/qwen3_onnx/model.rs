use std::path::PathBuf;
use tauri::Emitter;

const HF_ONNX_REPO: &str = "Daumee/Qwen3-ASR-0.6B-ONNX-CPU";

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

#[derive(Clone, serde::Serialize)]
pub struct Qwen3OnnxDownloadProgress {
    pub model_size: String,
    pub status: String,
    pub progress: f64,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub current_file: String,
}

/// Get the base models directory (same as qwen_asr module).
fn get_models_dir() -> PathBuf {
    std::env::var("LOCALAPPDATA")
        .map(|p| PathBuf::from(p).join("com.voicemind.voiceinput").join("models"))
        .unwrap_or_else(|_| PathBuf::from("./models"))
}

/// Get the ONNX model directory for a given size.
pub fn get_onnx_model_dir(size: &str) -> PathBuf {
    get_models_dir().join(format!("qwen3-asr-onnx-{}", size))
}

/// Check if all required ONNX model files exist.
pub fn is_onnx_model_downloaded(size: &str) -> bool {
    let dir = get_onnx_model_dir(size);
        REQUIRED_FILES.iter().all(|f| dir.join(f).exists())
}

/// Download ONNX model files from HuggingFace.
pub async fn download_onnx_model(
    size: &str,
    app_handle: &tauri::AppHandle,
) -> Result<(), String> {
    if size != "0.6b" {
        return Err("Only 0.6b model size is supported for ONNX engine currently".into());
    }

    let model_dir = get_onnx_model_dir(size);
    std::fs::create_dir_all(&model_dir)
        .map_err(|e| format!("Failed to create model directory: {}", e))?;

    let client = reqwest::Client::new();

    for filename in REQUIRED_FILES {
        let url = format!(
            "https://huggingface.co/{}/resolve/main/onnx_models/{}",
            HF_ONNX_REPO, filename
        );
        let file_path = model_dir.join(filename);
        let display_name = filename.to_string();

        // Emit progress: starting file
        let _ = app_handle.emit(
            "qwen3-onnx-download-progress",
            Qwen3OnnxDownloadProgress {
                model_size: size.to_string(),
                status: "downloading".to_string(),
                progress: 0.0,
                downloaded_bytes: 0,
                total_bytes: 0,
                current_file: display_name.clone(),
            },
        );

        let resp = client
            .head(&url)
            .send()
            .await
            .map_err(|e| format!("HEAD request failed for {}: {}", filename, e))?;

        let total_size = resp.content_length().unwrap_or(0);

        let mut response = client
            .get(&url)
            .send()
            .await
            .map_err(|e| format!("Download failed for {}: {}", filename, e))?;

        let mut file = std::fs::File::create(&file_path)
            .map_err(|e| format!("Failed to create file {}: {}", filename, e))?;

        let mut downloaded: u64 = 0;

        use std::io::Write;

        while let Some(chunk) = response.chunk().await.map_err(|e| format!("Download stream error: {}", e))? {
            file.write_all(&chunk)
                .map_err(|e| format!("Write error for {}: {}", filename, e))?;
            downloaded += chunk.len() as u64;

            let progress = if total_size > 0 {
                (downloaded as f64 / total_size as f64) * 100.0
            } else {
                0.0
            };

            let _ = app_handle.emit(
                "qwen3-onnx-download-progress",
                Qwen3OnnxDownloadProgress {
                    model_size: size.to_string(),
                    status: "downloading".to_string(),
                    progress,
                    downloaded_bytes: downloaded,
                    total_bytes: total_size,
                    current_file: display_name.clone(),
                },
            );
        }
    }

    // Emit completion
    let _ = app_handle.emit(
        "qwen3-onnx-download-progress",
        Qwen3OnnxDownloadProgress {
            model_size: size.to_string(),
            status: "completed".to_string(),
            progress: 100.0,
            downloaded_bytes: 0,
            total_bytes: 0,
            current_file: "".to_string(),
        },
    );

    Ok(())
}

/// Delete ONNX model files for a given size.
pub fn delete_onnx_model(size: &str) -> Result<(), String> {
    let dir = get_onnx_model_dir(size);
    if dir.exists() {
        std::fs::remove_dir_all(&dir)
            .map_err(|e| format!("Failed to delete model directory: {}", e))?;
    }
    Ok(())
}

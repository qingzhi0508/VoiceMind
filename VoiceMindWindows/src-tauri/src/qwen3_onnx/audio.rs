use ndarray::{Array2, Array3};
use rustfft::num_complex::Complex64;
use rustfft::FftPlanner;

/// Whisper-style mel spectrogram for Qwen3-ASR audio preprocessing.
pub struct MelSpectrogram {
    mel_filterbank: Array2<f64>,
    hann_window: Vec<f64>,
    n_fft: usize,
    hop_length: usize,
    n_mels: usize,
    chunk_size: usize,
}

/// Output of mel spectrogram computation.
pub struct MelOutput {
    pub data: Array3<f32>,
    pub num_frames: usize,
}

impl MelSpectrogram {
    pub fn new(sample_rate: u32) -> Self {
        let n_fft = 400;
        let hop_length = 160;
        let n_mels = 128;
        let fmax = 8000.0_f64;
        let fmin = 0.0_f64;
        let chunk_size = 100;

        // Build Hann window
        let mut hann_window = Vec::with_capacity(n_fft);
        for i in 0..n_fft {
            hann_window.push(0.5 * (1.0 - (2.0 * std::f64::consts::PI * i as f64 / (n_fft - 1) as f64).cos()));
        }

        // Build Slaney mel filterbank
        let mel_filterbank = build_mel_filterbank(n_fft, n_mels, sample_rate as f64, fmin, fmax);

        Self {
            mel_filterbank,
            hann_window,
            n_fft,
            hop_length,
            n_mels,
            chunk_size,
        }
    }

    /// Compute mel spectrogram from mono f32 PCM at 16kHz.
    pub fn compute(&self, pcm: &[f32]) -> MelOutput {
        let n_fft = self.n_fft;
        let hop = self.hop_length;

        // Pad with reflect (center=True)
        let pad_len = n_fft / 2;
        let mut padded = Vec::with_capacity(pcm.len() + pad_len * 2);
        // Reflect pre-pad
        for i in (1..=pad_len).rev() {
            padded.push(if i <= pcm.len() { pcm[i] } else { 0.0 });
        }
        padded.extend_from_slice(pcm);
        // Reflect post-pad
        for i in 0..pad_len {
            padded.push(if pad_len + i < pcm.len() { pcm[pcm.len() - 1 - (i + 1)] } else { 0.0 });
        }

        let num_frames = (padded.len() - n_fft) / hop + 1;

        // STFT + power spectrum
        let mut planner = FftPlanner::new();
        let fft = planner.plan_fft_forward(n_fft);

        let mut power_spec = Array2::<f64>::zeros((num_frames, n_fft / 2 + 1));

        for frame_idx in 0..num_frames {
            let offset = frame_idx * hop;
            let mut fft_input: Vec<Complex64> = (0..n_fft)
                .map(|i| {
                    let sample = padded[offset + i] as f64;
                    Complex64::new(sample * self.hann_window[i], 0.0)
                })
                .collect();

            fft.process(&mut fft_input);

            let num_bins = n_fft / 2 + 1;
            for bin in 0..num_bins {
                let re = fft_input[bin].re;
                let im = fft_input[bin].im;
                power_spec[[frame_idx, bin]] = re * re + im * im;
            }
        }

        // Apply mel filterbank: [num_frames, num_bins] * [n_mels, num_bins]^T
        let num_bins = n_fft / 2 + 1;
        let mut mel_spec = Array2::<f64>::zeros((num_frames, self.n_mels));
        for frame in 0..num_frames {
            for mel_bin in 0..self.n_mels {
                let mut sum = 0.0_f64;
                for freq_bin in 0..num_bins {
                    sum += power_spec[[frame, freq_bin]] * self.mel_filterbank[[mel_bin, freq_bin]];
                }
                mel_spec[[frame, mel_bin]] = sum;
            }
        }

        // Log compression
        let mut mel_log = mel_spec.mapv(|v| (v.max(1e-10)).log10());

        // Dynamic range compression per frame
        for frame in 0..num_frames {
            let mut max_val = f64::NEG_INFINITY;
            for mel_bin in 0..self.n_mels {
                if mel_log[[frame, mel_bin]] > max_val {
                    max_val = mel_log[[frame, mel_bin]];
                }
            }
            for mel_bin in 0..self.n_mels {
                mel_log[[frame, mel_bin]] = mel_log[[frame, mel_bin]].max(max_val - 8.0);
            }
        }

        // Normalize: (x + 4.0) / 4.0
        let mel_normalized = mel_log.mapv(|v| ((v + 4.0) / 4.0) as f32);

        // Transpose to [n_mels, num_frames] then shape as [1, n_mels, num_frames]
        let mel_transposed = mel_normalized.t();
        let data = Array3::from_shape_vec(
            (1, self.n_mels, num_frames),
            mel_transposed.iter().cloned().collect(),
        )
        .unwrap();

        MelOutput { data, num_frames }
    }

    /// Split mel into chunks of `chunk_size` frames, pad last chunk.
    /// Returns [num_chunks, 128, chunk_size].
    pub fn chunk_mel(&self, mel: &MelOutput) -> Array3<f32> {
        let num_frames = mel.num_frames;
        let n_mels = self.n_mels;
        let chunk_size = self.chunk_size;

        let num_chunks = (num_frames + chunk_size - 1) / chunk_size;
        let mut chunks = Array3::<f32>::zeros((num_chunks, n_mels, chunk_size));

        for (chunk_idx, chunk_start) in (0..num_frames).step_by(chunk_size).enumerate() {
            let chunk_end = (chunk_start + chunk_size).min(num_frames);
            let actual_len = chunk_end - chunk_start;

            for mel_bin in 0..n_mels {
                for f in 0..actual_len {
                    chunks[[chunk_idx, mel_bin, f]] = mel.data[[0, mel_bin, chunk_start + f]];
                }
            }
        }

        chunks
    }
}

/// Hz to mel (Slaney scale)
fn hz_to_mel(freq: f64) -> f64 {
    2595.0 * (1.0 + freq / 700.0).log10()
}

/// Mel to Hz (Slaney scale)
fn mel_to_hz(mel: f64) -> f64 {
    700.0 * (10.0_f64.powf(mel / 2595.0) - 1.0)
}

/// Build Slaney-normalized mel filterbank.
fn build_mel_filterbank(n_fft: usize, n_mels: usize, sample_rate: f64, fmin: f64, fmax: f64) -> Array2<f64> {
    let num_bins = n_fft / 2 + 1;
    let fft_freqs: Vec<f64> = (0..num_bins)
        .map(|i| i as f64 * sample_rate / n_fft as f64)
        .collect();

    let mel_min = hz_to_mel(fmin);
    let mel_max = hz_to_mel(fmax);
    let mel_points: Vec<f64> = (0..=n_mels)
        .map(|i| mel_to_hz(mel_min + (mel_max - mel_min) * i as f64 / n_mels as f64))
        .collect();

    let mut filterbank = Array2::<f64>::zeros((n_mels, num_bins));

    for i in 0..n_mels {
        let f_left = mel_points[i];
        let f_center = mel_points[i + 1];
        let f_right = mel_points[i + 2];

        let mut weights = Vec::with_capacity(num_bins);

        for &freq in &fft_freqs {
            let w = if freq >= f_left && freq <= f_center && f_center != f_left {
                (freq - f_left) / (f_center - f_left)
            } else if freq > f_center && freq <= f_right && f_right != f_center {
                (f_right - freq) / (f_right - f_center)
            } else {
                0.0
            };
            weights.push(w);
        }

        // Slaney normalization: divide by width of the mel filter
        let enorm = 2.0 / (mel_points[i + 2] - mel_points[i]);

        for (j, w) in weights.into_iter().enumerate() {
            filterbank[[i, j]] = w * enorm;
        }
    }

    filterbank
}

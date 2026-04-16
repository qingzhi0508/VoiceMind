use tracing::info;

/// VAD configuration parameters.
pub struct VadConfig {
    /// How long silence must last before triggering a segment boundary (ms).
    pub silence_threshold_ms: u64,
    /// Minimum duration of speech to be considered a valid segment (ms).
    pub min_speech_ms: u64,
    /// WebRTC VAD aggressiveness mode.
    pub mode: webrtc_vad::VadMode,
}

impl Default for VadConfig {
    fn default() -> Self {
        Self {
            silence_threshold_ms: 600,
            min_speech_ms: 300,
            mode: webrtc_vad::VadMode::Aggressive,
        }
    }
}

/// Events emitted by the VAD state machine.
#[derive(Debug)]
pub enum VadEvent {
    /// Transitioned from silence to speech.
    SpeechStart,
    /// A complete speech segment ended. `audio` contains the raw s16le PCM for
    /// the entire speech segment (including the silence tail up to the threshold).
    SpeechEnd { audio: Vec<u8> },
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum VadState {
    /// Currently in silence (or start), waiting for speech.
    Silence,
    /// Currently in speech, accumulating audio.
    Speech,
}

/// WebRTC VAD wrapper with speech-segment state machine.
///
/// SAFETY: `webrtc_vad::Vad` contains a raw pointer to a C `Fvad` struct.
/// It is NOT `Send`/`Sync` by default. We only ever access it through `&mut self`,
/// so concurrent access is impossible. Safe to send/share across threads as long
/// as we don't call methods from multiple threads simultaneously (guaranteed by
/// Rust's borrow checker).
pub struct VadSession {
    vad: webrtc_vad::Vad,
    silence_threshold_ms: u64,
    min_speech_ms: u64,
    state: VadState,

    // Buffering to 30ms frame boundaries.
    // At 16kHz s16le mono: 480 samples = 960 bytes per 30ms frame.
    frame_buf: Vec<u8>,
    frame_size: usize, // bytes per 30ms frame

    // State machine counters (in milliseconds).
    speech_duration_ms: u64,
    silence_duration_ms: u64,
    frame_ms: u64,

    // Accumulated audio for the current speech segment.
    segment_audio: Vec<u8>,
}

impl VadSession {
    pub fn new(config: VadConfig) -> Self {
        let vad = webrtc_vad::Vad::new_with_rate_and_mode(
            webrtc_vad::SampleRate::Rate16kHz,
            config.mode,
        );

        // Frame size: 30ms at 16kHz s16le mono = 480 samples * 2 bytes = 960 bytes.
        let frame_size = 960;
        let frame_ms = 30;

        let silence_threshold_ms = config.silence_threshold_ms;
        let min_speech_ms = config.min_speech_ms;

        Self {
            vad,
            silence_threshold_ms,
            min_speech_ms,
            state: VadState::Silence,
            frame_buf: Vec::with_capacity(frame_size),
            frame_size,
            speech_duration_ms: 0,
            silence_duration_ms: 0,
            frame_ms,
            segment_audio: Vec::new(),
        }
    }

    /// Feed raw PCM data (s16le 16kHz mono) of arbitrary size.
    /// Returns a list of VAD events detected during this chunk.
    pub fn feed(&mut self, pcm: &[u8]) -> Vec<VadEvent> {
        let mut events = Vec::new();

        // Buffer incoming PCM and process complete 30ms frames.
        self.frame_buf.extend_from_slice(pcm);

        while self.frame_buf.len() >= self.frame_size {
            let frame_data: Vec<u8> = self.frame_buf[..self.frame_size].to_vec();
            self.frame_buf.drain(..self.frame_size);

            // Convert bytes to i16 samples for WebRTC VAD.
            let samples: Vec<i16> = frame_data
                .chunks_exact(2)
                .map(|chunk| i16::from_le_bytes([chunk[0], chunk[1]]))
                .collect();

            let is_voice = self.vad.is_voice_segment(&samples).unwrap_or(false);

            match self.state {
                VadState::Silence => {
                    if is_voice {
                        self.speech_duration_ms += self.frame_ms;
                        self.silence_duration_ms = 0;

                        if self.speech_duration_ms >= self.min_speech_ms {
                            self.state = VadState::Speech;
                            // Include any previously buffered audio (from when
                            // speech first started being detected).
                            self.segment_audio
                                .extend_from_slice(&frame_data);
                            // Also include any frame_buf residue that was part
                            // of the pre-speech ramp-up — already consumed via
                            // drain above, so just note the transition.
                            events.push(VadEvent::SpeechStart);
                            info!(
                                "VAD: SpeechStart (speech_duration={}ms)",
                                self.speech_duration_ms
                            );
                        }
                    } else {
                        self.speech_duration_ms = 0;
                    }
                }
                VadState::Speech => {
                    // Always accumulate audio while in speech state.
                    self.segment_audio.extend_from_slice(&frame_data);

                    if is_voice {
                        self.silence_duration_ms = 0;
                        self.speech_duration_ms += self.frame_ms;
                    } else {
                        self.silence_duration_ms += self.frame_ms;

                        if self.silence_duration_ms >= self.silence_threshold_ms {
                            let audio = std::mem::take(&mut self.segment_audio);
                            info!(
                                "VAD: SpeechEnd ({} bytes, ~{}ms speech)",
                                audio.len(),
                                audio.len() as u64 * 1000 / (16000 * 2)
                            );
                            events.push(VadEvent::SpeechEnd { audio });

                            self.state = VadState::Silence;
                            self.speech_duration_ms = 0;
                            self.silence_duration_ms = 0;
                        }
                    }
                }
            }
        }

        events
    }

    /// Flush any remaining buffered audio as a speech segment (if in speech state).
    /// Call this when the audio stream ends to capture the final segment.
    pub fn flush(&mut self) -> Option<VadEvent> {
        // Append any leftover buffered samples to the segment.
        if !self.frame_buf.is_empty() && self.state == VadState::Speech {
            self.segment_audio.extend_from_slice(&self.frame_buf);
            self.frame_buf.clear();
        }

        if self.state == VadState::Speech && !self.segment_audio.is_empty() {
            let audio = std::mem::take(&mut self.segment_audio);
            info!(
                "VAD: Flush SpeechEnd ({} bytes)",
                audio.len()
            );
            Some(VadEvent::SpeechEnd { audio })
        } else {
            // Drain leftover buffer regardless.
            self.frame_buf.clear();
            None
        }
    }

    /// Reset the VAD session to initial state.
    #[allow(dead_code)]
    pub fn reset(&mut self) {
        self.state = VadState::Silence;
        self.speech_duration_ms = 0;
        self.silence_duration_ms = 0;
        self.frame_buf.clear();
        self.segment_audio.clear();
    }
}

// SAFETY: VadSession is only accessed through &mut self (exclusive access).
// The underlying WebRTC VAD C library is not thread-safe, but Rust's borrow
// checker guarantees no concurrent access. Safe to move between threads.
unsafe impl Send for VadSession {}
unsafe impl Sync for VadSession {}

# Technical Report — MATLAB Voice Classification / FFT Audio Analyzer

## 1) Project goal and scope
This project explores how far classic DSP and **explainable heuristics** can go for **rough voice attribute estimation** (age group and gender) using a spoken-word WAV input. It is intentionally simple and interpretable: the MATLAB implementation prints intermediate acoustic measurements and the scoring rules that lead to the final label.

Reference implementation (MATLAB only):
- Main entrypoint: [matlab/fft_analysis.m](matlab/fft_analysis.m)
- Helpers: [matlab/bandpass_filter.m](matlab/bandpass_filter.m), [matlab/extract_voice_features.m](matlab/extract_voice_features.m), [matlab/determine_age.m](matlab/determine_age.m), [matlab/determine_gender.m](matlab/determine_gender.m), [matlab/test_audio_playback.m](matlab/test_audio_playback.m), [matlab/waveform_info.m](matlab/waveform_info.m)

Important scope note: the output is a **heuristic estimate**, not a medically/forensically reliable classifier.

## 2) End-to-end pipeline (conceptual)
At a high level, the MATLAB pipeline follows these stages:

1. **Input acquisition**
   - Load a WAV file and convert to mono.
2. **Sample-rate normalization**
   - Resample to a fixed target sample rate (16 kHz) to keep feature extraction consistent.
3. **Pre-filtering (optional / configurable)**
   - Apply a Butterworth band-pass filter to suppress DC drift, low-frequency rumble, and high-frequency noise.
4. **Frequency analysis**
   - Compute the FFT and derive a dominant frequency estimate.
5. **Feature extraction**
   - Fundamental frequency (pitch) and spectral descriptors (centroid, bandwidth, rolloff), plus ZCR and RMS.
6. **Decision logic (heuristics)**
   - Convert features into simple scores and map scores → class labels.
7. **Visualization and reporting**
   - Plot waveform (time-domain) and magnitude spectrum (frequency-domain) and print a score breakdown.

## 3) Detailed pipeline (what happens and why)

### 3.1 Input loading and channel handling
**What happens**
- The waveform is read from disk.
- Stereo files are downmixed to mono by averaging channels.

**Why it’s done**
- The heuristic rules are designed for a single-channel voice signal.
- Mono avoids ambiguity about which channel contains the speaker and ensures deterministic feature extraction.

### 3.2 Sample-rate normalization to 16 kHz
**What happens**
- The waveform is resampled to `16,000 Hz`.

**Why it’s done**
- Many speech-relevant cues (pitch and low-order harmonics) are well represented at 16 kHz.
- A fixed sample rate makes FFT bin-to-Hz conversion and feature extraction consistent across files.

### 3.3 Band-pass filtering (pre-processing)
**What happens**
- A Butterworth band-pass filter is applied (commonly around 1–1000 Hz in this project).

**Why it’s done**
- Removes **DC offset** and very low-frequency drift which can dominate FFT magnitude near 0 Hz.
- Attenuates high-frequency noise that can inflate spectral centroid/rolloff and distort heuristics.
- Keeps the analysis focused on the voice’s fundamental frequency and early harmonics.

**Implementation notes**
- MATLAB uses `bandpass_filter()` from [matlab/bandpass_filter.m](matlab/bandpass_filter.m).
- The helper validates normalized cutoffs; if the `lowHz/highHz` pair is invalid (including `lowHz <= 0`), it returns the unmodified waveform to avoid generating an invalid filter.

### 3.4 FFT computation and dominant frequency
**What happens**
- The FFT is computed over the (optionally filtered) waveform.
- The “dominant frequency” is estimated by selecting the frequency bin with maximum magnitude.

**Why it’s done**
- FFT is a quick way to see where energy concentrates.
- The dominant bin can act as a coarse proxy for pitch/harmonics, but it is not a true pitch estimator.

**Important technical caveat**
- Using `argmax(|FFT|)` on the full spectrum can be biased by:
  - DC content (if not filtered)
  - window length / non-stationarity
  - harmonics overpowering the fundamental
- That’s why the pipeline also computes a dedicated pitch estimate (Section 3.5).

### 3.5 Acoustic feature extraction
The project extracts a small set of interpretable features commonly used in speech/audio analysis:

#### Pitch (fundamental frequency) statistics
- **Median pitch**: robust central tendency of $f_0$.
- **Pitch std**: variability.
- **Pitch range**: 95th–5th percentile spread.

**Why**
- Pitch is one of the strongest simple correlates of perceived age group (child vs adult) and typical male/female vocal ranges.

**MATLAB**
- Uses `pitch()` (Audio Toolbox) to track $f_0$ over time, then aggregates to median/std/range.

#### Spectral centroid / bandwidth / rolloff
- **Centroid**: “brightness” / average frequency weighted by energy.
- **Bandwidth**: spread of spectral energy.
- **Rolloff**: frequency below which a chosen percentage (e.g., 85%) of energy lies.

**Why**
- Brighter/noisier signals tend to raise centroid/rolloff and can help separate some voice qualities.

#### Zero crossing rate (ZCR)
- Approximates noisiness / high-frequency activity.

**Why**
- Complements centroid/rolloff and helps penalize overly smooth/overly noisy segments.

#### RMS energy
- A simple loudness proxy.

**Why**
- Useful for signal quality checks and potential gating; not heavily used in current heuristic decisions.

### 3.6 Heuristic scoring rules (decision stage)
The project avoids a black-box classifier and instead uses additive scores. This makes the system transparent and easy to tune.

#### Age group: Child vs Adult
Typical cues used:
- If median pitch $\ge 220\,Hz$ → child score +1
- If spectral centroid $\ge 2500\,Hz$ → child score +1
- If dominant frequency $\ge 300\,Hz$ → child score +1

Decision:
- If `child_score >= 2` → **Child**, else **Adult**

**Why**
- Children generally have higher $f_0$.
- Higher centroid can indicate smaller vocal tract / “brighter” speech (very rough proxy).
- Dominant frequency threshold provides a coarse fallback when pitch tracking is unreliable.

#### Gender: Male vs Female
Typical cues used:
- If median pitch `< 160 Hz` → male +2 else female +2
- Centroid threshold around 2000 Hz → male/female +1
- Rolloff threshold around 2600 Hz → male/female +0.75
- ZCR threshold around 0.075 → male/female +0.75
- Dominant frequency threshold around 160 Hz → male/female +0.5

Decision:
- If `male_score > female_score` → **Male**, else **Female**

**Why**
- Median pitch is the primary cue.
- Spectral descriptors and ZCR act as secondary cues to reduce dependence on a single feature.
- Dominant frequency provides a fallback if pitch estimation fails.

## 4) Implementation details

### 4.1 MATLAB implementation
Primary entrypoint: [matlab/fft_analysis.m](matlab/fft_analysis.m)

Helper functions (separate files):
- Band-pass filter: [matlab/bandpass_filter.m](matlab/bandpass_filter.m)
- Feature extraction: [matlab/extract_voice_features.m](matlab/extract_voice_features.m)
- Heuristics: [matlab/determine_age.m](matlab/determine_age.m), [matlab/determine_gender.m](matlab/determine_gender.m)

Toolbox requirements:
- Audio Toolbox for `pitch()` and spectral descriptors
- Signal Processing Toolbox for `butter`, `filtfilt`, and `resample`

## 5) Design choices and “why these measures”

### 5.1 Fixed sample rate (16 kHz)
- Makes FFT axis and thresholds consistent.
- Reduces compute while retaining speech-relevant information.

### 5.2 Filtering before FFT/features
- Prevents DC/rumble from dominating the spectrum.
- Stabilizes brightness-related metrics (centroid/rolloff).

### 5.3 Simple, interpretable features
- Each feature has an intuitive meaning.
- Easy to debug when results look wrong (plots + printed values).

### 5.4 Transparent scoring instead of ML
- No training data required.
- Easy to modify thresholds for different microphones/environments.
- Produces explainable outputs.

## 6) Limitations and known pitfalls
- **Dominant FFT bin is not pitch**; harmonics/noise can dominate.
- **Pitch estimation may fail** on noisy audio, whispering, or very short clips.
- Heuristic thresholds are **not universal** across microphones, languages, or recording conditions.
- Gender estimation is binary in this project’s current form and does not reflect the full diversity of voices.

## 7) Recommended next improvements (optional)
- Use **short-time FFT (STFT)** and aggregate features over voiced frames.
- Add **voiced/unvoiced detection** to avoid scoring silence.
- Add **formant estimation** (F1/F2) to better capture vocal-tract cues.
- Calibrate thresholds using a small labeled dataset and report accuracy/confusion matrices.

## 8) How to run

### MATLAB
- Ensure `matlab/` is on your MATLAB path.
- Run: `fft_analysis`

---

Appendix A — File map
- MATLAB pipeline: [matlab/fft_analysis.m](matlab/fft_analysis.m)
- MATLAB helpers: [matlab/](matlab/)

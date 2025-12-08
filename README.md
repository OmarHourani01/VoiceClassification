# Voice Classification / FFT Audio Analyzer

Small audio lab for exploring how far you can get with classic DSP blocks (FFT, spectral descriptors, heuristics) before reaching for a neural network. The Python script `fft.py` loads a spoken-word WAV file, plots it in both domains, extracts pitch/timbre descriptors with `librosa`, and assigns rough age/gender labels using transparent scoring rules. A MATLAB port (`fft_analysis.m`) mirrors the workflow for users who prefer MATLAB toolboxes.

---

## What you get

- **Feature extraction playground** – pitch (YIN), spectral centroid/bandwidth/rolloff, RMS, zero-crossing rate.
- **Explainable heuristics** – dominant FFT bins + acoustic descriptors feed into hand-crafted rules for age (child/adult) and gender (male/female) estimates.
- **Visualization hooks** – time-domain and frequency-domain plots to eyeball signal quality.
- **Optional playback** – use `sounddevice` when you have speakers, otherwise fall back to notebook audio widgets.
- **Cross-platform experiments** – Python implementation plus MATLAB function for the same workflow.

## Repository layout

| Path | Purpose |
| --- | --- |
| `fft.py` | Primary Python analyzer using `librosa`, `scipy`, and `matplotlib` |
| `fft_analysis.m` | MATLAB clone with Audio/Signal Toolbox dependencies |
| `samples/*.wav` | Ready-made demo utterances |
| `requirements.txt` | Python dependency pin list |

## Requirements

### Python

- Python < 3.1, >= 3.11

### MATLAB (optional)

- Audio Toolbox (for `pitch`, spectral descriptors)
- Signal Processing Toolbox (for `bandpass`, `filtfilt`, `resample`)

## Python Installation

```bash
# 1. Clone
git clone https://github.com/OmarHourani01/VoiceClassification.git
cd VoiceClassification

# 2. Create/activate a virtual environment (macOS/Linux example)
python3 -m venv venv
source venv/bin/activate

# 3. Install Python dependencies
pip install -r requirements.txt
```

### Using the Python analyzer

1. Choose an input WAV file.
	 - Easiest: edit the `AUDIO_FILE` constant at the top of `fft.py` (defaults to `ayah/Loaf_bread.wav`).
	 - Alternative: set `AUDIO_FILE = ""` to get a prompt every time you run the script.
2. (Optional) Adjust `SAMPLING_RATE` or uncomment the `bandpass_filter` line if you need pre-filtering.
3. Run the analyzer:

```bash
source venv/bin/activate
python fft.py
```

4. When prompted, type `y` to hear the audio via `sounddevice`, or `n` to continue silently.
5. Inspect the console summary and the two Matplotlib plots (time domain + FFT magnitude). On headless servers, set `MPLBACKEND=Agg` if you only want files saved instead of GUI windows.

### Sample console output

```
Do you want to play the audio? (y/n): n
Waveform Information:
Amplitude Range: 1.3483
Bit Depth: 64 bits

================================================================================
Age and Gender Estimation:
Estimated Age Group: Child
Estimated Gender: Female
Score Details: {'child_score': 2, 'adult_score': 1, 'male_score': 1.75, 'female_score': 3.25}

RESULTS FOR FILE: ayah/Loaf_bread.wav
```

### How the heuristics work

| Feature | Extracted via | How it’s used |
| --- | --- | --- |
| Dominant FFT bin | `np.argmax(|FFT|)` | Checks if energy concentrates above/below ~300 Hz |
| Fundamental frequency (`pitch_median`) | `librosa.yin` | Primary cue for both age (child voices above ~220 Hz) and gender (male voices below ~160 Hz) |
| Spectral centroid/rolloff/bandwidth | `librosa.feature.*` | Proxy for brightness; higher values skew toward child/female |
| Zero crossing rate | `librosa.feature.zero_crossing_rate` | Distinguishes noisier/brighter timbres |
| RMS energy | `librosa.feature.rms` | Included for completeness; not part of current scoring |

Scores accumulate with transparent weights (see `determine_age` and `determine_gender`). Because everything is hand-tuned, treat the labels as qualitative hints, not ground-truth classification.

### Working with plots

- `plot_waveform_time_domain` calls `librosa.display.waveshow` for a quick inspection of amplitude over time.
- `plot_waveform_frequency_domain` visualizes the single-sided FFT magnitude so you can spot dominant harmonics.
- You can save figures instead of showing them by inserting `plt.savefig("waveform.png")` / `plt.savefig("spectrum.png")` before `plt.show()` if you plan to run headless.

### Sample audio bundles

- `samples/omar.wav`, `samples/shot.wav`, `samples/woman*.wav`: shorter utterances to test different timbres quickly.
	- Tip: keep everything as mono WAV files; `librosa` will down-mix for you, but mono avoids surprises.

## MATLAB workflow

1. Open MATLAB in the repo root.
2. Run `fft_analysis_matlab`.
3. Provide a path (or press Enter to keep the default), optionally listen to playback, and review the printed scores + plots.

The MATLAB script mirrors the Python feature logic so results should qualitatively match.

## Troubleshooting & tips

- **Audio playback fails** – ensure `sounddevice` is installed and your Python session has access to the system audio device. On macOS, you may need to grant microphone/speaker permissions the first time.
- **Matplotlib windows on servers** – set `export MPLBACKEND=Agg` or switch to saving figures instead of `plt.show()`.
- **Different sample rates** – `librosa.load` resamples to `SAMPLING_RATE`. If you want the native rate, set `sr=None` in `librosa.load` and propagate the actual rate through the pipeline.
- **Non-WAV inputs** – install `ffmpeg` and point `AUDIO_FILE` at any format that `librosa` understands.

Happy experimenting! If you extend the heuristics (e.g., add formant tracking, energy ratios, or ML models), document the new rules to keep the tool explainable.

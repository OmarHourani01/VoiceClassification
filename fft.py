from scipy.fft import fft
from scipy.signal import butter, sosfiltfilt
from IPython.display import Audio, display

import queue
import librosa
import numpy as np
import matplotlib.pyplot as plt
import soundfile as sf
import sounddevice as sd
import wavio


# AUDIO_FILE = "samples/woman.wav"

AUDIO_FILE = None
SAMPLING_RATE = 16000


def test_audio_playback(waveform, sampling_rate):
    """Play audio via sounddevice when available; fall back to notebook widget."""

    if sd is not None:
        try:
            sd.play(waveform, samplerate=sampling_rate)
            sd.wait()
            return True
        except Exception as exc:  # pragma: no cover - runtime audio errors
            print(f"Audio playback failed: {exc}")
            return False

    if Audio is not None and display is not None:
        display(Audio(waveform, rate=sampling_rate))
        print("Displayed audio widget (requires notebook environment).")
        return True

    print(
        "Audio playback requires the 'sounddevice' package. Install it with"
        " 'pip install sounddevice'."
    )
    return False

def record_audio(filename="ouput"):

    sample_rate = 44100
    channels = 1
    block_size = 1024

    filename = filename + ".wav"

    print("Recording... Press Ctrl+C to stop.")

    frames = []
    audio_queue = queue.Queue()

    def callback(indata, frames_count, time_info, status):
        if status:
            print(f"Recording warning: {status}", flush=True)
        audio_queue.put(indata.copy())

    try:
        with sd.InputStream(
            samplerate=sample_rate,
            channels=channels,
            blocksize=block_size,
            callback=callback,
        ):
            while True:
                frames.append(audio_queue.get())
    except KeyboardInterrupt:
        print("\nStopped recording.")

    if not frames:
        raise RuntimeError("No audio data captured; recording aborted.")

    audio_data = np.concatenate(frames, axis=0)

    # Save WAV file
    wavio.write(filename, audio_data, sample_rate, sampwidth=2)

    print(f"Saved as {filename}")

    return filename
        

def waveform_info(waveform, audio_file):
    amplitude_range = np.max(waveform) - np.min(waveform)
    audio_data, _ = sf.read(audio_file)
    bit_depth = audio_data.dtype.itemsize * 8

    print(f"Amplitude Range: {amplitude_range}")
    print(f"Bit Depth: {bit_depth} bits")

    return amplitude_range, bit_depth


def bandpass_filter(waveform, sampling_rate, low_hz=1.0, high_hz=1000.0, order=4):
    """Apply a simple Butterworth band-pass filter between low_hz and high_hz."""

    nyquist = 0.5 * sampling_rate
    low = low_hz / nyquist
    high = high_hz / nyquist    

    sos = butter(order, [low, high], btype="band", output="sos")
    return sosfiltfilt(sos, waveform)


def plot_waveform_time_domain(waveform, sampling_rate):
    plt.figure(figsize=(8, 4))

    librosa.display.waveshow(waveform, sr=sampling_rate)
    plt.xlabel("Time")
    plt.ylabel("Amplitude")
    plt.title("Audio Waveform")
    plt.grid(True)
    plt.show()


def plot_waveform_frequency_domain(spectrum, sampling_rate):
    frequencies = np.fft.fftfreq(len(spectrum), 1 / sampling_rate)

    plt.figure(figsize=(8, 4))
    plt.plot(
        frequencies[: len(frequencies) // 2], np.abs(spectrum[: len(spectrum) // 2])
    )
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Amplitude")
    plt.title("Frequency Spectrum")
    plt.grid(True)
    plt.show()


def extract_voice_features(waveform, sampling_rate):
    """Compute richer acoustic features for downstream heuristics."""

    features = {}

    # f0 Fundamental frequency
    f0 = librosa.yin(
        waveform,
        fmin=50,
        fmax=2000,
        sr=sampling_rate,
        frame_length=2048,
    )
    f0 = f0[~np.isnan(f0)]
    if f0.size:
        features["pitch_median"] = float(np.median(f0))
        features["pitch_std"] = float(np.std(f0))
        features["pitch_range"] = float(np.percentile(f0, 95) - np.percentile(f0, 5))
    else:
        features["pitch_median"] = float("nan")
        features["pitch_std"] = float("nan")
        features["pitch_range"] = float("nan")

    # Spectral descriptors capture timbre/brightness often correlated with age/sex.
    spectral_centroid = librosa.feature.spectral_centroid(y=waveform, sr=sampling_rate)
    spectral_bandwidth = librosa.feature.spectral_bandwidth(
        y=waveform, sr=sampling_rate
    )
    spectral_rolloff = librosa.feature.spectral_rolloff(
        y=waveform, sr=sampling_rate, roll_percent=0.85
    )
    zero_crossing_rate = librosa.feature.zero_crossing_rate(waveform)
    rms = librosa.feature.rms(y=waveform)

    features["spectral_centroid"] = float(np.mean(spectral_centroid))
    features["spectral_bandwidth"] = float(np.mean(spectral_bandwidth))
    features["spectral_rolloff"] = float(np.mean(spectral_rolloff))
    features["zero_crossing_rate"] = float(np.mean(zero_crossing_rate))
    features["rms_energy"] = float(np.mean(rms))

    return features


def determine_age(spectrum, sampling_rate, voice_features):
    dominant_freq_index = np.argmax(np.abs(spectrum))
    dominant_frequency = np.fft.fftfreq(len(spectrum), 1 / sampling_rate)[
        dominant_freq_index
    ]

    pitch_median = voice_features.get("pitch_median", float("nan"))
    centroid = voice_features.get("spectral_centroid", float("nan"))    

    child_score = 0
    if not np.isnan(pitch_median) and pitch_median >= 220:
        child_score += 1
    if centroid >= 2500:
        child_score += 1
    if dominant_frequency >= 300:
        child_score += 1

    age_group = "Child" if child_score >= 2 else "Adult"

    score_snapshot = {
        "child_score": child_score,
        "adult_score": 3 - child_score,
    }

    return age_group, score_snapshot


def determine_gender(spectrum, sampling_rate, voice_features):
    dominant_freq_index = np.argmax(np.abs(spectrum))
    dominant_frequency = np.fft.fftfreq(len(spectrum), 1 / sampling_rate)[
        dominant_freq_index
    ]

    pitch_median = voice_features.get("pitch_median", float("nan"))
    centroid = voice_features.get("spectral_centroid", float("nan"))    
    zcr = voice_features.get("zero_crossing_rate", float("nan"))
    rolloff = voice_features.get("spectral_rolloff", float("nan"))
    
    if np.isnan(pitch_median):
        pitch_median = dominant_frequency

    male_score = 0
    female_score = 0

    if pitch_median < 160:
        male_score += 2
    elif pitch_median >= 160:
        female_score += 2
    else:
        male_score += 0
        female_score += 0

    if not np.isnan(centroid):
        if centroid < 2000:
            male_score += 1.0
        elif centroid > 2000:
            female_score += 1.0
        else:
            male_score += 0.5
            female_score += 0.5

    if not np.isnan(rolloff):
        if rolloff < 2600:
            male_score += 0.75
        elif rolloff > 2600:
            female_score += 0.75
        else:
            male_score += 0.25
            female_score += 0.25
    
    if not np.isnan(zcr):
        if zcr < 0.075:
            male_score += 0.75
        elif zcr > 0.075:
            female_score += 0.75
        else:
            male_score += 0.25
            female_score += 0.25

    if dominant_frequency < 160:
        male_score += 0.5
    else:
        female_score += 0.5

    if male_score > female_score:
        gender = "Male"
    else:
        gender = "Female"
        
    
    score_snapshot = {        
        "male_score": male_score,
        "female_score": female_score,
    }

    return gender, score_snapshot



def main():
    audio_ask = input("Do you want to record audio? (y/n): ")
    recorded_audio_file = None
    
    if audio_ask.lower() == "y":
        audio_dir = input("Enter name of file (optional):")
        if not audio_dir:
            recorded_audio_file = record_audio()
        else:
            recorded_audio_file = record_audio(audio_dir)
    
    if not AUDIO_FILE and not recorded_audio_file:
        audio_file = input("Enter path of WAV file: ")
    elif not recorded_audio_file:
        audio_file = AUDIO_FILE
    else:
        audio_file = recorded_audio_file
        
    raw_waveform, actual_sampling_rate = librosa.load(
        audio_file, sr=SAMPLING_RATE, mono=True
    )

    spectrum = fft(raw_waveform)

    playback = input("Do you want to play the audio? (y/n): ")
    if playback.lower() == "y":
        played = test_audio_playback(raw_waveform, actual_sampling_rate)
        
        if played:
            quit()
        else:
            print("Continuing without audio playback.")

    amplitude_range, bit_depth = waveform_info(raw_waveform, audio_file)

    print("Waveform Information:")
    print(f"Amplitude Range: {amplitude_range}")
    print(f"Bit Depth: {bit_depth} bits\n")

    voice_features = extract_voice_features(raw_waveform, actual_sampling_rate)
    age_group, age_scores = determine_age(spectrum, actual_sampling_rate, voice_features)
    gender, gender_scores = determine_gender(spectrum, actual_sampling_rate, voice_features)
    
    scores = {**age_scores, **gender_scores}
    print("=" * 80)
    print("Age and Gender Estimation:")
    print(f"Estimated Age Group: {age_group}")
    print(f"Estimated Gender: {gender}")
    print("Score Details:")
    print(scores)
    
    print(f"\nRESULTS FOR FILE: {audio_file}")

    plot_waveform_time_domain(raw_waveform, actual_sampling_rate)
    plot_waveform_frequency_domain(spectrum, actual_sampling_rate)


if __name__ == "__main__":
    main()

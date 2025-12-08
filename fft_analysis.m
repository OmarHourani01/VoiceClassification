function fft_analysis_matlab()
%FFT_ANALYSIS_MATLAB  MATLAB port of fft.py audio analyzer.
%   Run this function inside MATLAB to analyze a spoken-word WAV file,
%   optionally play the audio, visualize the waveform/spectrum, and produce
%   heuristic age/gender estimates based on acoustic features.
%
%   Requirements:
%     - Audio Toolbox (for pitch, spectral features)
%     - Signal Processing Toolbox (for bandpass filtering/resample)
%
%   Usage:
%     >> fft_analysis_matlab
%
%   You can edit the AUDIO_FILE default below or enter a new path when
%   prompted.

    AUDIO_FILE = 'samples/shot.wav';
    userInput = input('Enter path of WAV file (leave blank for default): ', 's');
    if ~isempty(strtrim(userInput))
        AUDIO_FILE = userInput;
    end

    TARGET_SR = 16000;

    if exist(AUDIO_FILE, 'file') ~= 2
        error('File not found: %s', AUDIO_FILE);
    end

    [rawWaveform, actualSR] = audioread(AUDIO_FILE);
    if size(rawWaveform, 2) > 1
        rawWaveform = mean(rawWaveform, 2); % convert to mono
    end

    if actualSR ~= TARGET_SR
        rawWaveform = resample(rawWaveform, TARGET_SR, actualSR);
        actualSR = TARGET_SR;
    end

    filteredWaveform = bandpass_filter(rawWaveform, actualSR, 50, 600, 4);
    spectrum = fft(filteredWaveform);

    playback = input('Do you want to play the audio? (y/n): ', 's');
    if ~isempty(playback) && lower(playback(1)) == 'y'
        sound(filteredWaveform, actualSR);
        return;
    end

    [amplitudeRange, bitDepth] = waveform_info(rawWaveform, AUDIO_FILE);

    fprintf('Waveform Information:\n');
    fprintf('Amplitude Range: %.6f\n', amplitudeRange);
    fprintf('Bit Depth: %d bits\n\n', bitDepth);

    voiceFeatures = extract_voice_features(rawWaveform, actualSR);
    [ageGroup, gender, scores] = determine_age_and_gender(spectrum, actualSR, voiceFeatures);

    fprintf(['%s\nAge and Gender Estimation:\nEstimated Age Group: %s\n' ...
             'Estimated Gender: %s\n'], repmat('=', 1, 80), ageGroup, gender);
    disp('Score Details:');
    disp(scores);

    plot_waveform_time_domain(filteredWaveform, actualSR);
    plot_waveform_frequency_domain(spectrum, actualSR);
end

function [amplitudeRange, bitDepth] = waveform_info(waveform, audioFile)
    amplitudeRange = max(waveform) - min(waveform);
    info = audioinfo(audioFile);
    bitDepth = info.BitsPerSample;
end

function filtered = bandpass_filter(waveform, samplingRate, lowHz, highHz, order)
    nyquist = 0.5 * samplingRate;
    low = lowHz / nyquist;
    high = highHz / nyquist;
    if ~(low > 0 && high < 1 && low < high)
        filtered = waveform;
        return;
    end
    [b, a] = butter(order, [low, high], 'bandpass');
    filtered = filtfilt(b, a, waveform);
end

function plot_waveform_time_domain(waveform, samplingRate)
    t = (0:length(waveform)-1) / samplingRate;
    figure('Name', 'Audio Waveform');
    plot(t, waveform);
    xlabel('Time (s)'); ylabel('Amplitude');
    title('Audio Waveform'); grid on;
end

function plot_waveform_frequency_domain(spectrum, samplingRate)
    n = length(spectrum);
    freqs = (0:n-1) * (samplingRate / n);
    halfIdx = 1:floor(n/2);
    figure('Name', 'Frequency Spectrum');
    plot(freqs(halfIdx), abs(spectrum(halfIdx)));
    xlabel('Frequency (Hz)'); ylabel('Amplitude');
    title('Frequency Spectrum'); grid on;
end

function features = extract_voice_features(waveform, samplingRate)
    features = struct();

    % Pitch tracking (YIN-based) using Audio Toolbox pitch().
    f0 = pitch(waveform, samplingRate, 'Method', 'SRH', 'Range', [50 2000]);
    f0 = f0(~isnan(f0));
    if ~isempty(f0)
        features.pitch_median = median(f0);
        features.pitch_std = std(f0);
        features.pitch_range = prctile(f0, 95) - prctile(f0, 5);
    else
        features.pitch_median = NaN;
        features.pitch_std = NaN;
        features.pitch_range = NaN;
    end

    % Spectral descriptors (Audio Toolbox)
    features.spectral_centroid = mean(spectralCentroid(waveform, samplingRate));
    features.spectral_bandwidth = mean(spectralBandwidth(waveform, samplingRate));
    features.spectral_rolloff = mean(spectralRolloffPoint(waveform, samplingRate, 'Cutoff', 0.85));

    % Zero-crossing rate and RMS energy
    zeroCrossings = sum(abs(diff(sign(waveform)))) / (2 * numel(waveform));
    features.zero_crossing_rate = zeroCrossings;
    features.rms_energy = rms(waveform);
end

function [ageGroup, gender, scores] = determine_age_and_gender(spectrum, samplingRate, features)
    [~, domIdx] = max(abs(spectrum));
    freqAxis = (0:length(spectrum)-1) * (samplingRate / length(spectrum));
    dominantFrequency = freqAxis(domIdx);

    pitchMedian = features.pitch_median;
    centroid = features.spectral_centroid;
    rolloff = features.spectral_rolloff;
    zcr = features.zero_crossing_rate;

    childScore = 0;
    if ~isnan(pitchMedian) && pitchMedian >= 220
        childScore = childScore + 1;
    end
    if centroid >= 2500
        childScore = childScore + 1;
    end
    if dominantFrequency >= 300
        childScore = childScore + 1;
    end

    if childScore >= 2
        ageGroup = 'Child';
    else
        ageGroup = 'Adult';
    end

    if isnan(pitchMedian)
        pitchMedian = dominantFrequency;
    end

    maleScore = 0;
    femaleScore = 0;

    if pitchMedian < 160
        maleScore = maleScore + 2;
    else
        femaleScore = femaleScore + 2;
    end

    if ~isnan(centroid)
        if centroid < 2000
            maleScore = maleScore + 1.0;
        else
            femaleScore = femaleScore + 1.0;
        end
    end

    if ~isnan(rolloff)
        if rolloff < 2600
            maleScore = maleScore + 0.75;
        else
            femaleScore = femaleScore + 0.75;
        end
    end

    if ~isnan(zcr)
        if zcr < 0.075
            maleScore = maleScore + 0.75;
        else
            femaleScore = femaleScore + 0.75;
        end
    end

    if dominantFrequency < 160
        maleScore = maleScore + 0.5;
    else
        femaleScore = femaleScore + 0.5;
    end

    if maleScore > femaleScore
        gender = 'Male';
    else
        gender = 'Female';
    end

    scores = struct('child_score', childScore, ...
                    'adult_score', 3 - childScore, ...
                    'male_score', maleScore, ...
                    'female_score', femaleScore);
end

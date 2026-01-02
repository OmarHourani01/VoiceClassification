function fft_analysis()
% How it works:
%     - load WAV -> mono -> resample to 16 kHz
%     - bandpass filter waveform
%     - FFT on filtered waveform
%     - optional playback
%     - heuristic age/gender via acoustic features
%     - waveform + spectrum plots

    AUDIO_FILE = '/Users/Omar/dev/DSPProject/samples/woman.wav';
    SAMPLING_RATE = 16000;

    if isempty(strtrim(AUDIO_FILE))
        audioFile = input('Enter path of WAV file: ', 's');
    else
        audioFile = AUDIO_FILE;
    end

    if exist(audioFile, 'file') ~= 2
        error('File not found: %s', audioFile);
    end

    [rawWaveform, actualSR] = audioread(audioFile);
    if size(rawWaveform, 2) > 1
        rawWaveform = mean(rawWaveform, 2);
    end

    if actualSR ~= SAMPLING_RATE
        rawWaveform = resample(rawWaveform, SAMPLING_RATE, actualSR);
        actualSR = SAMPLING_RATE;
    end

    % Apply a Butterworth bandpass filter (matching fft.py helper defaults).
    filteredWaveform = bandpass_filter(rawWaveform, actualSR, 0, 1000.0, 5);
    spectrum = fft(filteredWaveform);

    playback = input('Do you want to play the audio? (y/n): ', 's');
    if ~isempty(playback) && lower(playback(1)) == 'y'
        played = test_audio_playback(filteredWaveform, actualSR);
        if played
            return;
        else
            disp('Continuing without audio playback.');
        end
    end

    [amplitudeRange, bitDepth] = waveform_info(rawWaveform, audioFile);

    disp('Waveform Information:');
    fprintf('Amplitude Range: %.6f\n', amplitudeRange);
    fprintf('Bit Depth: %d bits\n\n', bitDepth);

    voiceFeatures = extract_voice_features(filteredWaveform, actualSR);
    [ageGroup, ageScores] = determine_age(spectrum, actualSR, voiceFeatures);
    [gender, genderScores] = determine_gender(spectrum, actualSR, voiceFeatures);

    scores = ageScores;
    scores.male_score = genderScores.male_score;
    scores.female_score = genderScores.female_score;

    disp(repmat('=', 1, 80));
    disp('Age and Gender Estimation:');
    fprintf('Estimated Age Group: %s\n', ageGroup);
    fprintf('Estimated Gender: %s\n', gender);
    disp('Score Details:');
    disp(scores);

    fprintf('\nRESULTS FOR FILE: %s\n', audioFile);

    plot_waveform_time_domain(filteredWaveform, actualSR);
    plot_waveform_frequency_domain(spectrum, actualSR);
end

function plot_waveform_time_domain(waveform, samplingRate)

    t = (0:length(waveform)-1) / samplingRate;
    figure('Name', 'Audio Waveform');
    plot(t, waveform);
    xlabel('Time');
    ylabel('Amplitude');
    title('Audio Waveform');
    grid on;
end

function plot_waveform_frequency_domain(spectrum, samplingRate)

    n = length(spectrum);
    frequencies = (0:n-1) * (samplingRate / n);

    figure('Name', 'Frequency Spectrum');
    halfN = floor(n/2);
    plot(frequencies(1:halfN), abs(spectrum(1:halfN)));
    xlabel('Frequency (Hz)');
    ylabel('Amplitude');
    title('Frequency Spectrum');
    grid on;
end

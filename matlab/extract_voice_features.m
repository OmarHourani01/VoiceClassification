function features = extract_voice_features(waveform, samplingRate)
%EXTRACT_VOICE_FEATURES Compute acoustic features similar to fft.py.

    features = struct();

    % Fundamental frequency estimate.
    try
        f0 = pitch(waveform, samplingRate, ...
            'Method', 'SRH', ...
            'Range', [50 2000], ...
            'WindowLength', 2048, ...
            'OverlapLength', 1024);
    catch
        f0 = [];
    end

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

    % Spectral descriptors.
    try
        features.spectral_centroid = mean(spectralCentroid(waveform, samplingRate));
    catch
        features.spectral_centroid = NaN;
    end

    try
        features.spectral_bandwidth = mean(spectralBandwidth(waveform, samplingRate));
    catch
        features.spectral_bandwidth = NaN;
    end

    try
        features.spectral_rolloff = mean(spectralRolloffPoint(waveform, samplingRate, 'Cutoff', 0.85));
    catch
        features.spectral_rolloff = NaN;
    end

    % Zero-crossing rate + RMS.
    zeroCrossings = sum(abs(diff(sign(waveform)))) / (2 * numel(waveform));
    features.zero_crossing_rate = zeroCrossings;
    features.rms_energy = rms(waveform);
end

function [ageGroup, scores] = determine_age(spectrum, samplingRate, voiceFeatures)

    dominantFrequency = dominant_frequency_from_spectrum(spectrum, samplingRate);

    pitchMedian = voiceFeatures.pitch_median;
    centroid = voiceFeatures.spectral_centroid;

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

    scores = struct('child_score', childScore, 'adult_score', 3 - childScore);
end

function domFreq = dominant_frequency_from_spectrum(spectrum, samplingRate)
    n = length(spectrum);
    freqs = (0:n-1) * (samplingRate / n);
    [~, idx] = max(abs(spectrum));
    domFreq = freqs(idx);
end

function [gender, scores] = determine_gender(spectrum, samplingRate, voiceFeatures)

    dominantFrequency = dominant_frequency_from_spectrum(spectrum, samplingRate);

    pitchMedian = voiceFeatures.pitch_median;
    centroid = voiceFeatures.spectral_centroid;
    zcr = voiceFeatures.zero_crossing_rate;
    rolloff = voiceFeatures.spectral_rolloff;

    if isnan(pitchMedian)
        pitchMedian = dominantFrequency;
    end

    maleScore = 0;
    femaleScore = 0;

    if pitchMedian < 160
        maleScore = maleScore + 2;
    elseif pitchMedian >= 160
        femaleScore = femaleScore + 2;
    else
        maleScore = maleScore + 0;
        femaleScore = femaleScore + 0;
    end

    if ~isnan(centroid)
        if centroid < 2000
            maleScore = maleScore + 1.0;
        elseif centroid > 2000
            femaleScore = femaleScore + 1.0;
        else
            maleScore = maleScore + 0.5;
            femaleScore = femaleScore + 0.5;
        end
    end

    if ~isnan(rolloff)
        if rolloff < 2600
            maleScore = maleScore + 0.75;
        elseif rolloff > 2600
            femaleScore = femaleScore + 0.75;
        else
            maleScore = maleScore + 0.25;
            femaleScore = femaleScore + 0.25;
        end
    end

    if ~isnan(zcr)
        if zcr < 0.075
            maleScore = maleScore + 0.75;
        elseif zcr > 0.075
            femaleScore = femaleScore + 0.75;
        else
            maleScore = maleScore + 0.25;
            femaleScore = femaleScore + 0.25;
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

    scores = struct('male_score', maleScore, 'female_score', femaleScore);
end

function domFreq = dominant_frequency_from_spectrum(spectrum, samplingRate)
    n = length(spectrum);
    freqs = (0:n-1) * (samplingRate / n);
    [~, idx] = max(abs(spectrum));
    domFreq = freqs(idx);
end

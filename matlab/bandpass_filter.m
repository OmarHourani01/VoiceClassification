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

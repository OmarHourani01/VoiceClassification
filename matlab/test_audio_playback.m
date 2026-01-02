function played = test_audio_playback(waveform, samplingRate)

    played = false;
    try
        sound(waveform, samplingRate);
        played = true;
    catch
        played = false;
    end
end

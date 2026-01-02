function played = test_audio_playback(waveform, samplingRate)
%TEST_AUDIO_PLAYBACK Play audio and return true if successful.

    played = false;
    try
        sound(waveform, samplingRate);
        played = true;
    catch
        played = false;
    end
end

function [amplitudeRange, bitDepth] = waveform_info(waveform, audioFile)
%WAVEFORM_INFO Match fft.py behavior: amplitude range + sample type bit depth.

    amplitudeRange = max(waveform) - min(waveform);

    % fft.py uses soundfile.read() and reports dtype bit depth (often float64 => 64).
    bitDepth = class_bit_depth(waveform);

    fprintf('Amplitude Range: %.6f\n', amplitudeRange);
    fprintf('Bit Depth: %d bits\n', bitDepth);

    %#ok<NASGU>
    % audioFile is kept for signature parity with fft.py.
end

function bits = class_bit_depth(x)
    xClass = class(x);
    switch xClass
        case 'double'
            bits = 64;
        case 'single'
            bits = 32;
        case 'int16'
            bits = 16;
        case 'int32'
            bits = 32;
        case 'int8'
            bits = 8;
        case 'uint8'
            bits = 8;
        case 'uint16'
            bits = 16;
        case 'uint32'
            bits = 32;
        otherwise
            info = whos('x');
            bits = round(8 * info.bytes / max(1, numel(x)));
    end
end

% Lookahead feedback compressor with soft and hard knee
% Author: Ashay Dave
% email: apd122@miami.edu


classdef Compressure < audioPlugin

    properties
        inputGain = 0;
        threshold = -10;
        attackTime = 0;
        releaseTime = 50;
        ratio = 1;
        kneeType = 'Soft';
        makeupGain = 0;
        lookaheadTime = 1;
        fs = 48000;
        bypass = 'OFF';
    end

    properties (Constant)
        PluginInterface = audioPluginInterface(...
            audioPluginParameter('inputGain', 'DisplayName', 'Input Gain', 'Label', 'dB', 'Mapping',{'lin',0,36}),...
            audioPluginParameter('threshold', 'DisplayName', 'Threshold', 'Label', 'dB', 'Mapping',{'lin',-36,0}), ...
            audioPluginParameter('attackTime', 'DisplayName', 'Attack', 'Label', 'ms', 'Mapping',{'lin',0, 500}), ...
            audioPluginParameter('releaseTime', 'DisplayName', 'Release', 'Label', 'ms', 'Mapping',{'lin',50, 5000}), ...
            audioPluginParameter('lookaheadTime', 'DisplayName', 'Lookahead', 'Label', 'ms', 'Mapping',{'lin', 1, 10 }), ...
            audioPluginParameter('ratio', 'DisplayName', 'Ratio(1:x)', 'Mapping',{'lin',1, 10}), ...
            audioPluginParameter('kneeType', 'DisplayName', 'Knee', 'Mapping', {'enum','Soft','Hard'}), ...
            audioPluginParameter('makeupGain', 'DisplayName', 'Makeup Gain', 'Label', 'dB','Mapping',{'lin',-12, 36}), ...
            audioPluginParameter('bypass', 'DisplayName','Bypass','Mapping',{'enum', 'OFF', 'ON'}));
    end

    methods
        function output = process(obj, audio)
            
            numSamples = size(audio, 1);
            
            envelope = zeros(numSamples, 2);
            output = zeros(numSamples, 2);
            previousGain = ones(1, 2);
            
            attackTime = obj.attackTime / 1000;
            releaseTime = obj.releaseTime / 1000;
            threshold = 10.^(obj.threshold / 20);
            ratio = 1 ./ obj.ratio;
            lookaheadSamples = round(obj.lookaheadTime * 0.001 * obj.fs);

            if strcmpi(obj.bypass, 'ON')
                output = audio;
                return;
            end

            for channel = 1:2
                audioChannel = audio(:, channel);
                for n = 1:numSamples
                    % Calculating the envelope of audio using RMS
                    lookaheadStart = max(1, n - lookaheadSamples);
                    envelope(n, channel) = sqrt(mean(audioChannel(lookaheadStart:n).^2));

                    % Calculating the compressor gain
                    % Hard knee
                    if strcmpi(obj.kneeType, 'Hard')
                        if envelope(n, channel) >= threshold
                            gain = 1 - (1 - ratio) * (threshold / envelope(n, channel));
                        else
                            gain = 1;
                        end
                    else
                        % Soft knee
                        softKneeWidth = 5; % Setting soft knee width to 5
                        delta = envelope(n, channel) - threshold;
                        if delta >= softKneeWidth
                            gain = 1 - (1 - ratio) * (threshold / envelope(n, channel));
                        else
                            gain = 1 - (1 - ratio) * (threshold / envelope(n, channel)) - (delta / softKneeWidth) * (1 - ratio);
                        end
                    end

                    % Attack and Release
                    if gain > previousGain(channel)
                        gain = (1 - exp(-1 / (obj.fs * attackTime))) * gain + (1 - (1 - exp(-1 / (obj.fs * attackTime))) * previousGain(channel));
                    else
                        gain = (1 - exp(-1 / (obj.fs * releaseTime))) * gain + (1 - (1 - exp(-1 / (obj.fs * releaseTime))) * previousGain(channel));
                    end

                    % Makeup Gain
                    gain = gain * 10.^(obj.makeupGain / 20);

                    % Final Gain
                    output(n, channel) = obj.inputGain * audioChannel(n) * gain;
                    previousGain(channel) = gain;
                end
            end
        end
    end
end
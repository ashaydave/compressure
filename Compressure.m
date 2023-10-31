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
        audioPluginParameter('inputGain', 'Label', 'dB', 'Mapping',{'lin',0,36}, 'Style', 'rotaryknob', 'Layout', [3,1], 'DisplayName', 'Input Gain', 'DisplayNameLocation', 'Above'),...
        audioPluginParameter('threshold', 'Label', 'dB', 'Mapping',{'lin',-36,0}, 'Style', 'rotaryknob', 'Layout', [3,2], 'DisplayName', 'Threshold', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('attackTime', 'Label', 'ms', 'Mapping',{'lin',0, 500}, 'Style', 'rotaryknob', 'Layout', [3,3], 'DisplayName', 'Attack', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('releaseTime', 'Label', 'ms', 'Mapping',{'lin',50, 5000}, 'Style', 'rotaryknob', 'Layout', [3,4], 'DisplayName', 'Release', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('lookaheadTime', 'Label', 'ms', 'Mapping',{'lin', 1, 10 }, 'Style', 'rotaryknob', 'Layout', [5,1], 'DisplayName', 'Lookahead', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('ratio', 'Mapping',{'lin',1, 10}, 'Style', 'rotaryknob', 'Layout', [5,2], 'DisplayName', 'Ratio (1:x)', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('makeupGain', 'Label', 'dB','Mapping',{'lin',-12, 36}, 'Style', 'rotaryknob', 'Layout', [5,3], 'DisplayName', 'Makeup Gain', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('kneeType', 'Mapping', {'enum','Soft','Hard'}, 'Style', 'vtoggle', 'Layout', [5,4], 'DisplayName', 'Knee Type', 'DisplayNameLocation', 'Above'), ...
        audioPluginParameter('bypass','Mapping',{'enum', 'OFF', 'ON'}, 'Style', 'vtoggle', 'Layout', [4,5], 'DisplayName', 'Bypass', 'DisplayNameLocation', 'Above', 'Filmstrip','compressure.png', 'FilmstripFrameSize',[150,100]), ...
        audioPluginGridLayout('RowHeight', [20, 20, 160, 120, 160], 'ColumnWidth', [100, 100, 100, 100, 100]));
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
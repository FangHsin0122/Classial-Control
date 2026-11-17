%% Deep Learning Data Synthesis for 5G Channel Estimation
%
% This example shows how to train a convolutional neural network (CNN) for
% channel estimation using Deep Learning Toolbox(TM) and data generated
% with 5G Toolbox(TM). Using the trained CNN, you perform channel
% estimation in single-input single-output (SISO) mode, utilizing the
% physical downlink shared channel (PDSCH) demodulation reference signal
% (DM-RS).
% 
% Copyright 2019-2023 The MathWorks, Inc.

%% Introduction
%
% The general approach to channel estimation is to insert known reference
% pilot symbols into the transmission and then interpolate the rest of the
% channel response by using these pilot symbols.
%
% <<../DeepLearningDataSynthesis5G_ChEstimationOverview.png>>
%
% 
% For an example showing how to use this channel estimation approach, see
% <docid:5g_ug#mw_new-radio-pdsch-throughput NR PDSCH
% Throughput>.
%
% You can also use deep learning techniques to perform channel estimation.
% For example, by viewing the resource grid as a 2-D image, you can turn
% the problem of channel estimation into an image processing problem,
% similar to denoising or super-resolution, where CNNs are effective.
%
% Using 5G Toolbox, you can customize and generate standard-compliant
% waveforms and channel models to use as training data. Using Deep Learning
% Toolbox, you can use this training data to train a channel estimation
% CNN. This example shows how to generate such training data and how to
% train a channel estimation CNN. The example also shows how to use the
% channel estimation CNN to process images that contain linearly
% interpolated received pilot symbols. The example concludes by visualizing
% the results of the neural network channel estimator in comparison to
% practical and perfect estimators.
%
% <<../DeepLearningDataSynthesis5G_ExampleOverview.png>>
% 


rng(42,"twister")

% Generate the training data
[trainData,trainDataClean, trainLabels] = hGenerateTrainingData(256);

% Set the number of examples per mini-batch
batchSize = 32;


% Split into training and validation sets
valData = trainData(:,:,1:batchSize);
valDataClean = trainDataClean(:,:,1:batchSize);
valLabels = trainLabels(:,:,1:batchSize);

trainData = trainData(:,:,batchSize+1:end);
trainDataClean = trainDataClean(:,:,batchSize+1:end);
trainLabels = trainLabels(:,:,batchSize+1:end);

% Validate roughly 5 times every epoch
valFrequency = round(size(trainData,4)/batchSize/5);
lossFunction = "mean-squared-error";


%% 

% Convert results to complex 
%estChannelGridNN = complex(estChannelGridNN(:,:,:,1),estChannelGridNN(:,:,:,2));

[H_pred, nmse_time, mse, nmse, nmse_dB] = kalman_predict_3D_tensor(real(trainData(:, :,1: 100)), real(trainLabels(:, :, 1:100)), 6);

% Time and frequency axes (optional)
t = 0:14;     % Time axis
f = 0:612;   % Frequency axis

% Plot
figure(1);
imagesc(t, f, nmse_dB);
axis xy;
colormap jet;
colorbar;
title('Error Plot - NMSE Accuracy (dB)')
% Scale colorbar according to min and max of M
caxis([min(nmse_dB(:)), max(nmse_dB(:))]);
xlabel('OFDM Symbols (Time)')
ylabel('Subcarriers (Frequency)')
set(gca, 'YDir','reverse')

figure(2);
imagesc(t, f, real(trainData(:,:,7)));
axis xy;
colormap jet;
colorbar;
title('Training Data - Channel + Noise')
% Scale colorbar according to min and max of M
caxis([min(reshape(real(trainData(:, :,7)),1, [])), max(reshape(real(trainData(:, :,7)),1, []))]);
xlabel('OFDM Symbols (Time)')
ylabel('Subcarriers (Frequency)')
set(gca, 'YDir','reverse')

figure(3);
imagesc(t, f, real(H_pred(:,:,1)));
axis xy;
colormap jet;
colorbar;
title('Estimated Channel from Kalman Filter')
% Scale colorbar according to min and max of M
%caxis([min(reshape(real(H_pred(:, :,1)), 1, [])), max(reshape(real(H_pred(:, :,1)), 1, []))]);
caxis([min(reshape(real(trainData(:, :,7)),1, [])), max(reshape(real(trainData(:, :,7)),1, []))]);
xlabel('OFDM Symbols (Time)')
ylabel('Subcarriers (Frequency)')
set(gca, 'YDir','reverse')

figure(4);
imagesc(t, f, real(trainLabels(:,:,7)));
axis xy;
colormap jet;
colorbar;
title('Perfect Channel Measurement')
% Scale colorbar according to min and max of M
%caxis([min(reshape(real(trainLabels(:, :,7)), 1, [])), max(reshape(real(trainLabels(:, :,7)), 1, []))]);
caxis([min(reshape(real(trainData(:, :,7)),1, [])), max(reshape(real(trainData(:, :,7)),1, []))]);
xlabel('OFDM Symbols (Time)')
ylabel('Subcarriers (Frequency)')
set(gca, 'YDir','reverse')

samples = 7:100;
figure(5);
plot(samples, nmse_time, 'LineWidth', 1.5)
title('Prediction Error vs. Time Slots')
xlabel('Time Slots')
ylabel('NMSE Accuracy')




%% kalman filter part

function [H_pred,nmse_time, mse, nmse, nmse_dB] = kalman_predict_3D_tensor(x_series, y_series, order)
    % Inputs:
    %   x_series: [F x T x N] → AR inputs over time
    %   y_series: [F x T x N] → noisy observations over time
    %   y_clean:  [F x T x N] → ground truth channel (for MSE)
    % Output:
    %   H_pred:   [F x T x (N-order)] Kalman-predicted signal
    %   mse, nmse, nmse_dB: [F x T] error metrics

    [F, T, N] = size(x_series);
    H_pred = zeros(F, T, N - order);
    A_all = zeros(F, T, order);
    mse = zeros(F, T);
    nmse = zeros(F, T);
    nmse_dB = zeros(F, T);

    Q1 = 1;

    Q = eye(order) * Q1;
    R = 0.01;

    for f = 1:F
        for t = 1:T
            x = squeeze(x_series(f, t, :));     % [N x 1]
            y = squeeze(y_series(f, t, :));     % [N x 1]
            

            % Estimate AR coefficients (from first few samples)
            ar_input = x(1 : min(N, order + 10));
            A = estimateAR_LS_from_series(ar_input, order);
           
            % Build transition matrix
            M = zeros(order);
            M(1, :) = A;
            M(2:end, 1:end-1) = eye(order - 1);
        
            C = A;  % Observation matrix
            x_est = x(order:-1:1);  % Initial AR state vector
            
            P = eye(order) * 0.1;

            for n = order+1:N
                % Predict
                x_pred = M * x_est;
                P_pred = M * P * M' + Q;

                % Observation
                y_meas = y(n);
                innovation = y_meas - C * x_pred;
                S = C * P_pred * C' + R;
                K = P_pred * C' / S;

                % update
                x_est = x_pred + K * innovation;%state esti
                P = (eye(order) - K * C) * P_pred;%uncertainty

                % store prediction
                H_pred(f, t, n - order) = x_est(1);  
                H_est_all(f, t, n - order) = x_est(1);
                H_true_all(f, t, n - order) = y(n);

            end

            % Evaluate MSE/NMSE over filtered region
            h_true = y(order+1:end);
            h_est = squeeze(H_pred(f, t, :));
            
            mse(f, t) = mean((h_true - h_est).^2);
            denom = mean(h_true.^2) + eps;
            nmse(f, t) = mse(f, t) / denom;
            nmse_dB(f, t) = 10 * log10(nmse(f, t));

            
            % sys = tf(1, [1, -A]);  % AR model in transfer function form
            % figure(8)
            % step(sys);  % or impulse(sys)
            % hold on
        end
    end
    % [F x T x N-order] → collapse F & T into 1st dim, leave time
    H_est_flat = reshape(H_est_all, [], N - order);   % [F*T x time]
    H_true_flat = reshape(H_true_all, [], N - order); % [F*T x time]
    
    % Error at each time step (n-order steps)
    mse_time = mean((H_true_flat - H_est_flat).^2, 1);  % [1 x time]
    nmse_time = mse_time ./ (mean(H_true_flat.^2, 1) + eps);
    nmse_dB_time = 10 * log10(nmse_time);
    
    samples = 7:100;
    figure(7);
    plot(samples, nmse_time, 'LineWidth', 1.5)
    title(sprintf('Prediction Error vs. Time Slots - Q = %.1f , R = %.2f', Q1, R));    
                innovation = y_meas - C * x_pred;
    xlabel('Time Slots')
    ylabel('NMSE Accuracy')
    xlim([7, 100])
    grid on
end

function A = estimateAR_LS_from_series(data, order)
    % Estimate AR coefficients from 1D signal vector `data`
    N = length(data);
    if N <= order
        A = zeros(1, order);
        return;
    end

    X = zeros(N - order, order);
    for i = 1:order
        X(:, i) = data(order - i + 1:N - i);
    end
    y = data(order + 1:N);
    A = (X' * X) \ (X' * y);
    A = A';  % row vector
end





%% Local Functions


function [trainData,trainDataClean, trainLabels] = hGenerateTrainingData(dataSize)
% Generate training data examples for channel estimation. Run dataSize
% number of iterations to create random channel configurations and pass an
% OFDM-modulated fixed resource grid with only the DM-RS symbols inserted.
% Perform perfect timing synchronization and OFDM demodulation, extracting
% the pilot symbols and performing linear interpolation at each iteration.
% Use perfect channel information to create the label data. The function
% returns 2 arrays - the training data and labels.

    fprintf("Starting data generation...\n")

   
    simParameters = hChanEstSimParameters();
    carrier = simParameters.Carrier;
    pdsch = simParameters.PDSCH;

    % Create the channel model object
    nTxAnts = simParameters.NTxAnts;
    nRxAnts = simParameters.NRxAnts;

    channel = nrTDLChannel; % TDL channel object
    channel.NumTransmitAntennas = nTxAnts;
    channel.NumReceiveAntennas = nRxAnts;

    % Use the value returned from <matlab:edit('nrOFDMInfo') nrOFDMInfo> to
    % set the channel model sample rate
    waveformInfo = nrOFDMInfo(carrier);
    channel.SampleRate = waveformInfo.SampleRate;

    % Get the maximum channel delay.
    chInfo = info(channel);
    maxChDelay = chInfo.MaximumChannelDelay;

    % Return DM-RS indices and symbols
    dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
    dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);

    % Create resource grid
    grid = nrResourceGrid(carrier,nTxAnts);

    % PDSCH DM-RS precoding and mapping
    [~,dmrsAntIndices] = nrExtractResources(dmrsIndices,grid);
    grid(dmrsAntIndices) = dmrsSymbols;

    % OFDM modulation of associated resource elements
    txWaveform_original = nrOFDMModulate(carrier,grid);

    % Acquire linear interpolator coordinates for neural net preprocessing
    [rows,cols] = find(grid ~= 0);
    dmrsSubs = [rows, cols, ones(size(cols))];
    hest = zeros(size(grid));
    [l_hest,k_hest] = meshgrid(1:size(hest,2),1:size(hest,1));

    % Preallocate memory for the training data and labels
    numExamples = dataSize;
    [trainData,  trainLabels] = deal(zeros([612 14 numExamples]));

    % Main loop for data generation, iterating over the number of examples
    % specified in the function call. Each iteration of the loop produces a
    % new channel realization with a random delay spread, doppler shift,
    % and delay profile. Every perturbed version of the transmitted
    % waveform with the DM-RS symbols is stored in trainData, and the
    % perfect channel realization in trainLabels.
    for i = 1:numExamples
        % Release the channel to change nontunable properties
        channel.release

        % Pick a random seed to create different channel realizations
        channel.Seed =0;

        % Pick a random delay profile, delay spread, and maximum doppler shift
        channel.DelayProfile = "TDL-A";
        channel.DelaySpread = 3e-7;
        channel.MaximumDopplerShift = 50;

        % Send data through the channel model. Append zeros at the end of
        % the transmitted waveform to flush channel content. These zeros
        % take into account any delay introduced in the channel, such as
        % multipath delay and implementation delay. This value depends on
        % the sampling rate, delay profile, and delay spread
        txWaveform = [txWaveform_original; zeros(maxChDelay, size(txWaveform_original,2))];
        [rxWaveform1,pathGains,sampleTimes] = channel(txWaveform);

        % Add additive white Gaussian noise (AWGN) to the received time-domain
        % waveform. To take into account sampling rate, normalize the noise power.
        % The SNR is defined per RE for each receive antenna (3GPP TS 38.101-4).   
        SNRdB = randi([0 10]);  % Random SNR values between 0 and 10 dB
        SNR = 10^(SNRdB/10);    % Calculate linear SNR
        N0 = 1/sqrt(2.0*nRxAnts*double(waveformInfo.Nfft)*SNR);
        noise = N0*complex(randn(size(rxWaveform1)),randn(size(rxWaveform1)));
        rxWaveform = rxWaveform1 + noise;

        % Perfect synchronization. Use information provided by the channel
        % to find the strongest multipath component
        pathFilters = getPathFilters(channel); % Get path filters for perfect channel estimation
        [offset,~] = nrPerfectTimingEstimate(pathGains,pathFilters);

        rxWaveform = rxWaveform(1+offset:end, :);
        rxWaveform1 = rxWaveform1(1+offset:end, :);

        % Perform OFDM demodulation on the received data to recreate the
        % resource grid, including padding in case practical
        % synchronization results in an incomplete slot being demodulated
        rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
        rxGrid1 = nrOFDMDemodulate(carrier,rxWaveform1);

        [K,L,R] = size(rxGrid);
        if (L < carrier.SymbolsPerSlot)
            rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
        end
            
        [K1,L1,R1] = size(rxGrid1);
        if (L1 < carrier.SymbolsPerSlot)
            rxGrid1 = cat(2,rxGrid1,zeros(K1,carrier.SymbolsPerSlot-L1,R1));
        end
        % Perfect channel estimation, using the value of the path gains
        % provided by the channel. This channel estimate does not
        % include the effect of transmitter precoding

        estChannelGridPerfect = nrPerfectChannelEstimate(carrier,pathGains, ...
            pathFilters,offset,sampleTimes);

        % Linear interpolation
        dmrsRx = rxGrid(dmrsIndices);
        dmrsRx1 = rxGrid1(dmrsIndices);

        dmrsEsts = dmrsRx .* conj(dmrsSymbols);
        f = scatteredInterpolant(dmrsSubs(:,2),dmrsSubs(:,1),dmrsEsts);
        hest = f(l_hest,k_hest);


        dmrsEsts1 = dmrsRx1 .* conj(dmrsSymbols);
        f1 = scatteredInterpolant(dmrsSubs(:,2),dmrsSubs(:,1),dmrsEsts1);
        hest1 = f1(l_hest,k_hest);

        % size(hest)
        % Split interpolated grid into real and imaginary components and
        % concatenate them along the third dimension, as well as for the
        % true channel response
        % rx_grid = cat(3, real(hest), imag(hest));
        % est_grid = cat(3, real(estChannelGridPerfect), ...
        %     imag(estChannelGridPerfect));
        % size(rx_grid)
        % Add generated training example and label to the respective arrays
        trainData(:,:,i) = hest;
        trainDataClean(:,:,i) = hest1;
        trainLabels(:,:,i) = estChannelGridPerfect;

        % Data generation tracker
        if mod(i,round(numExamples/25)) == 0
            fprintf("%3.2f%% complete\n",i/numExamples*100);
        end
    end
    fprintf("Data generation complete!\n")
end

function simParameters = hChanEstSimParameters()
% Set simulation parameters for Deep Learning Data Synthesis for 5G Channel Estimation example

    % Carrier configuration
    simParameters.Carrier = nrCarrierConfig;
    simParameters.Carrier.NSizeGrid = 51;            % Bandwidth in number of resource blocks (51 RBs at 30 kHz SCS for 20 MHz BW)
    simParameters.Carrier.SubcarrierSpacing = 30;    % 15, 30, 60, 120, 240 (kHz)
    simParameters.Carrier.CyclicPrefix = "Normal";   % "Normal" or "Extended" (Extended CP is relevant for 60 kHz SCS only)
    simParameters.Carrier.NCellID = 2;               % Cell identity

    % Number of transmit and receive antennas
    simParameters.NTxAnts = 1;                      % Number of PDSCH transmission antennas
    simParameters.NRxAnts = 1;                      % Number of UE receive antennas

    % PDSCH and DM-RS configuration
    simParameters.PDSCH = nrPDSCHConfig;
    simParameters.PDSCH.PRBSet = 0:simParameters.Carrier.NSizeGrid-1; % PDSCH PRB allocation
    simParameters.PDSCH.SymbolAllocation = [0, simParameters.Carrier.SymbolsPerSlot];           % PDSCH symbol allocation in each slot
    simParameters.PDSCH.MappingType = "A";     % PDSCH mapping type ("A"(slot-wise),"B"(non slot-wise))
    simParameters.PDSCH.NID = simParameters.Carrier.NCellID;
    simParameters.PDSCH.RNTI = 1;
    simParameters.PDSCH.VRBToPRBInterleaving = 0; % Disable interleaved resource mapping
    simParameters.PDSCH.NumLayers = 1;            % Number of PDSCH transmission layers
    simParameters.PDSCH.Modulation = "16QAM";                       % "QPSK", "16QAM", "64QAM", "256QAM"

    % DM-RS configuration
    simParameters.PDSCH.DMRS.DMRSPortSet = 0:simParameters.PDSCH.NumLayers-1; % DM-RS ports to use for the layers
    simParameters.PDSCH.DMRS.DMRSTypeAPosition = 2;      % Mapping type A only. First DM-RS symbol position (2,3)
    simParameters.PDSCH.DMRS.DMRSLength = 1;             % Number of front-loaded DM-RS symbols (1(single symbol),2(double symbol))
    simParameters.PDSCH.DMRS.DMRSAdditionalPosition = 1; % Additional DM-RS symbol positions (max range 0...3)
    simParameters.PDSCH.DMRS.DMRSConfigurationType = 2;  % DM-RS configuration type (1,2)
    simParameters.PDSCH.DMRS.NumCDMGroupsWithoutData = 1;% Number of CDM groups without data
    simParameters.PDSCH.DMRS.NIDNSCID = 1;               % Scrambling identity (0...65535)
    simParameters.PDSCH.DMRS.NSCID = 0;                  % Scrambling initialization (0,1)
end


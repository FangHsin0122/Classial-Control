%% Deep Learning Data Synthesis for 5G Channel Estimation
%% This example shows how to train a convolutional neural network (CNN) for
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
%設定隨機數種子為 42，使用 "twister" 隨機演算法。
%這樣每次執行程式時產生的隨機數列會相同（方便重現實驗結果）。

    % Generate the training data
    [trainData,trainLabels] = hGenerateTrainingData(256);
% 呼叫自訂的 hGenerateTrainingData 函數，產生 256 筆訓練資料，輸出：
% trainData：資料本身（例如圖像或訊號）
% trainLabels：對應的標籤（ground truth）

    % Set the number of examples per mini-batch
    batchSize = 32;
% 設定每個 mini-batch（訓練時一次處理的資料量）為 32 筆資料。

    % Split into training and validation sets
    valData = trainData(:,:,1:batchSize);
    valLabels = trainLabels(:,:,1:batchSize);
% 把前 32 筆資料（從第 1 筆到第 32 筆）作為驗證集（validation set），分別取出資料和標籤。

    trainData = trainData(:,:,batchSize+1:end);
    trainLabels = trainLabels(:,:,batchSize+1:end);
% 剩下的資料（從第 33 筆到第 256 筆）作為訓練集（training set），更新 trainData 和 trainLabels。

    % Validate roughly 5 times every epoch
    valFrequency = round(size(trainData,4)/batchSize/5);
    lossFunction = "mean-squared-error";
% 計算每個 epoch 中驗證的頻率（valFrequency）：
% size(trainData,4) 是訓練樣本總數
% 除以 batchSize 得到總共的 mini-batch 數
% 再除以 5，大約每跑完 1/5 的 mini-batch 驗證一次
% 指定訓練模型時使用的損失函數為「均方誤差（mean squared error）」，常用於回歸問題。


%% Create Channel Model for Simulation
%% - 這一段是用來建立通訊模擬的通道模型。
% Set the simulation noise level in dB. For an explanation of the SNR
% definition that this example uses, see <SNR Definition used in Link Simulations>.
% 設定模擬時的 訊號對雜訊比（SNR）為 20 dB，這表示：
% 訊號強度比雜訊強 100 倍（因為 10*log10(100) = 20）
% 用來模擬在某個 SNR 條件下，系統的通訊效能
% 註：這段註解也提到 SNR 的定義可能會依照模擬設計有所不同，
SNRdB = 20;

%% 
% Load the predefined simulation parameters, including the PDSCH
% parameters and DM-RS configuration.
simParameters = hChanEstSimParameters();
% 呼叫一個預先定義的函數 hChanEstSimParameters()，
% 回傳一個包含模擬設定的結構（simParameters）。這些設定會包括：
% PDSCH：下行共享通道（Physical Downlink Shared Channel）
% DM-RS：解調參考信號（Demodulation Reference Signal）
% 這些是 5G NR（New Radio）物理層模擬中常見的參數。

carrier = simParameters.Carrier;
% 從 simParameters 中取出載波參數(carrier configuration)，通常包含頻率、時域、子載波間距等設定。
pdsch = simParameters.PDSCH;
% 從 simParameters 中取出 PDSCH 設定，這包含了模擬中用來發送數據的下行通道參數，
% 例如 modulation、resource allocation、layering 等。

%%

%這段程式碼的目的在於：
% 1.建立一個 TDL-A 標準模型的無線通道。
% 2.設定基本通道參數如 delay spread、doppler shift。
% 3.指定為 SISO 架構。
% 4.設定通道的 sample rate。
% 5.擷取最大通道延遲供後續使用。

% Create a TDL channel model and set channel parameters. To compare
% different channel responses of the estimators, you can change these
% parameters later.

channel = nrTDLChannel;%建立一個 5G TDL 通道模型 實例，nrTDLChannel 是 MATLAB 中 5G Toolbox 提供的 TDL channel object。
channel.Seed = 0;
%設定隨機種子為 0，使得模擬結果每次都一致（可重現性）。
channel.DelayProfile = "TDL-A";
%指定使用 TDL-A 延遲剖面，代表一種標準化的多徑通道模型，常見於 5G NR 測試場景。
channel.DelaySpread = 3e-7;
%設定通道的 延遲擴展(delay spread) 為 300 ns，這表示不同多徑訊號之間的最大時間差。
channel.MaximumDopplerShift = 50;
%設定最大都卜勒頻移為 50 Hz，用來模擬移動裝置或通道變化速度（如車輛行駛中通訊）。

% This example supports only SISO configuration
channel.NumTransmitAntennas = 1;
channel.NumReceiveAntennas = 1;
% 天線數設定

waveformInfo = nrOFDMInfo(carrier);
channel.SampleRate = waveformInfo.SampleRate;
%使用 nrOFDMInfo 來根據 carrier 設定取得 OFDM 的相關資訊（例如 sample rate）
%並把這個取樣率設定給通道模型，確保傳送訊號和通道的時域一致性。


%% 
% Get the maximum channel delay.
chInfo = info(channel);
maxChDelay = chInfo.MaximumChannelDelay;
%使用 info(channel) 取得通道模型的結構資訊。
%從中擷取出 最大通道延遲，用於後續設定緩衝、對齊或收尾時間的考量（例如設定接收窗口大小）。

%% Simulate PDSCH DM-RS Transmission: 5G 下行共享通道（PDSCH）的解調參考訊號（DM-RS）傳送過程。
% by performing these steps:
% * Generate the resource grid(資源格)
% * Insert DM-RS symbols(Demodulation Reference Signal)
% * Perform OFDM modulation
% * Send modulated waveform through the channel model通過通道模型
% * Add white Gaussian noise
% * Perform perfect timing synchronization做同步（理想情況）
% * Perform OFDM demodulation 
% 
% The DM-RS symbols in the grid are used for channel estimation. 
% This example does not transmit any data, 
% therefore, the resource grid does not include any PDSCH symbols.
% 只模擬 DM-RS（Demodulation Reference Signal），不包含實際數據符號，
% 也就是資源格中只有參考訊號，用於通道估測（channel estimation）。

% Generate DM-RS indices and symbols
dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
% dmrsSymbols: 依據 carrier 和 PDSCH 設定產生 DM-RS 符號（即實際傳送的複數值）
% dmrsIndices: 這些符號要插入在哪些 resource element 上（位置）

% Create resource grid
pdschGrid = nrResourceGrid(carrier);
% 建立一個空白的 resource grid，依據 carrier 設定來定義維度（子載波數、time slot no.等）

% Map PDSCH DM-RS symbols to the grid
pdschGrid(dmrsIndices) = dmrsSymbols;
% 把剛剛產生的 DM-RS 符號填入資源格對應位置。

% OFDM-modulate associated resource elements
txWaveform = nrOFDMModulate(carrier,pdschGrid);
% 將 resource grid 中的訊號進行 OFDM 調變（也就是 IFFT 與加 CP 的動作），
% 產生要傳送的time domain波形 txWaveform。

%% Aviod losting info. so append 0 in the tail
% To flush the channel content, append zeros at the end of the transmitted
% waveform. These zeros take into account any delay introduced in the
% channel, such as multipath and implementation delay. The number of
% zeros depends on the sampling rate, delay profile, and delay spread.
% 傳送訊號時，通道可能會因為 多徑效應 或 硬體延遲 造成訊號 延後 到達。
% 為了讓這些「延遲的尾巴訊號」能完整傳完、不會被截掉，我們在訊號尾端補 0。
% 補多少 0 取決於：1.最大通道延遲（maxChDelay）：根據先前通道設定計算出來的值
% 2.取樣率、delay spread、delay profile 

txWaveform = [txWaveform; zeros(maxChDelay,size(txWaveform,2))];

%txWaveform：原本的時間域波形（用來傳送的訊號）
%zeros(maxChDelay, size(txWaveform,2))：補上一段零矩陣，
% 有 maxChDelay 個 sample、與原波形相同的列數（通常是 1 或天線數）
%% 將準備好的訊號送進模擬的無線通道，回傳經過通道擾動後的版本+這通道的詳細特性
% Send data through the TDL channel model. 
[rxWaveform,pathGains,sampleTimes] = channel(txWaveform);
%rxWaveform：接收端收到的時間域波形。
%原本的 txWaveform 經過通道擾動後的版本，也就是有扭曲、延遲、多徑影響的訊號。
%pathGains：每一條多徑的通道增益（複數值），表示訊號在每個 path 上被放大/衰減、相位改變的程度。
%這可以拿來做通道估測、分析某條路徑的變化情形。
%sampleTimes：多徑 path 的取樣時間點，也就是這些增益是發生在什麼時刻（通常對應到符號時間軸）。
% pathGains 和 sampleTimes 是：回音的強度與方向 & 回音何時到


%% 講了一段話（rxWaveform），對方在嘈雜的市中心(加入 AWGN)，聽到的內容可能有干擾。
% Add additive white Gaussian noise (AWGN) to the received time-domain
% waveform. To take into account sampling rate, normalize the noise power.
% The SNR is defined per resource element (RE) for each receive antenna
% (3GPP TS 38.101-4). For an explanation of the SNR definition that this
% example uses, see <docid:5g_ug#mw_37cef3ca-2f4b-433d-8d68-117a881ca5fd
% SNR Definition used in Link Simulations>.

SNR = 10^(SNRdB/10); % Calculate linear SNR from dB unit

N0 = 1/sqrt(simParameters.NRxAnts*double(waveformInfo.Nfft)*SNR);
%根據 SNR 計算出 雜訊的標準差 N0（每 sample 的 noise power）
% simParameters.NRxAnts: 接收天線數
% waveformInfo.Nfft: OFDM 的 FFT 點數（即每個 OFDM 符號的資源元素數）
% (公式from SNR 的定義)

noise = N0*randn(size(rxWaveform),"like",rxWaveform);
%產生與 rxWaveform 相同大小、相同資料型別的高斯分佈隨機雜訊
%randn(...)：高斯分布 N(0, 1)
%"like", rxWaveform：讓雜訊資料型別與 rxWaveform 一致（例如單精度、GPU 陣列等）

rxWaveform = rxWaveform + noise;


%% Perform perfect synchronization. 找到頭的起始位置。
% To find the strongest multipathcomponent, 
% use the information provided by the channel.
%執行「完美同步」：因為多徑傳播會讓訊號在時間上有延遲、重疊（像回音）
%根據 通道資訊(pathGains)找出最強的那一條路徑（最可靠的傳送時間點），當作訊號的「真正開始點」

% Get path filters for perfect channel estimation
pathFilters = getPathFilters(channel); 
%從 channel（之前建立的 TDL 通道模型）中，取得通道的path filters
% 這些 filters 描述每一條多徑的脈衝響應(impulse response)，
% 是做「通道估測」與「時間同步」的重要依據。


[offset,~] = nrPerfectTimingEstimate(pathGains,pathFilters);
%利用 pathGains 和 pathFilters 呼叫 MATLAB提供的函數 nrPerfectTimingEstimate()
% 功能是：找出最強多徑分量的位置（也就是訊號應該對齊的起始時間點）
% offset: 表示應該將接收波形 rxWaveform 往右偏移多少 sample 才對齊
% ~: 忽略第二個回傳值（通常是 peak value）

rxWaveform = rxWaveform(1+offset:end, :);
%根據 offset，把接收波形前面那一段沒對齊的部分剪掉
% 意思是：「從正確的時間點開始解調」，避免後續的錯誤解碼。

%% 
% OFDM-demodulate the received data to recreate the resource grid.
% 這行將時間域接收波形 rxWaveform 做 OFDM 解調，也就是：

rxGrid = nrOFDMDemodulate(carrier,rxWaveform);

%去除 cyclic prefix（CP）
%做 FFT 把時間域資料轉回頻域
%回到「子載波 × 時槽」的格式（也就是我們熟悉的資源格 resource grid）
%解調後的 rxGrid 是一個 3D array：通常是 Subcarriers×SymbolsPerSlot×RxAntennas



% Pad the grid with zeros in case an incomplete slot has been demodulated
[K,L,R] = size(rxGrid);
if (L < carrier.SymbolsPerSlot)
    rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
end
% 拆解 rxGrid 的維度成：
% K: 子載波數（通常 = Nfft）
% L: 實際解調出來的 OFDM symbol 數（可能少於一個 slot 滿格）
% R: 接收天線數

% 判斷目前解調出來的符號數 L 是否 少於理論上一個 slot 該有的符號數（carrier.SymbolsPerSlot）。
% 出現這種情況可能是因為：1.最後一個 slot 不完整（例如只收到了前 10 個 symbols）
% 2.通道延遲導致少解了幾個 symbols

%如果真的不夠，就在第 2 維（symbol 方向）補上 0，補滿成完整的 slot。
%cat(2, ...)：代表沿著第 2 維（symbols）做拼接
%zeros(...)：產生對應大小的 0 填充（空的 symbols）


%% Compare and Visualize Various Channel Estimations
%
% You can perform and compare the results of perfect, practical, and neural
% network estimations of the same channel model. 
% 
% To perform perfect channel estimation, use the
% <docid:5g_ref#mw_function_nrPerfectChannelEstimate
% nrPerfectChannelEstimate> function using the value of the path gains
% provided by the channel.
estChannelGridPerfect = nrPerfectChannelEstimate(carrier,pathGains, pathFilters,offset,sampleTimes);

%% 
% To perform practical channel estimation, use the
% <docid:5g_ref#mw_function_nrChannelEstimate nrChannelEstimate> function.
[estChannelGrid,~] = nrChannelEstimate(carrier,rxGrid,dmrsIndices,dmrsSymbols,"CDMLengths",pdsch.DMRS.CDMLengths);


%%

% Interpolate the received resource grid using pilot symbol locations
interpChannelGrid = hPreprocessInput(rxGrid,dmrsIndices,dmrsSymbols);

[H_pred, pred_error] = kalman_predict_3D(trainData, 6);


%% kalman filter part

function [H_pred, pred_error] = kalman_predict_3D(H, order)
    % Applies Kalman prediction to each (f, t) time series in H
    % H: [frequency x symbol x time], real-valued only
    % order: AR model order
    % Output:
    %   H_pred: predicted channel values [f x t x (n-order)]
    %   pred_error: MSE per (f, t)

    [F, T, N] = size(H);                 
    H_pred = zeros(F, T, N - order);     
    pred_error = zeros(F, T);            

    Q = eye(order) * 0.1;    % Process noise
    R = 0.5;                 % Measurement noise

    for f = 1:F
        for t = 1:T
            h_series = squeeze(real(H(f, t, :)));  % Extract real-valued time series
            
            % Estimate AR coefficients using least-squares
            ar_input = h_series(1 : min(end, order + 10));
            A = estimateAR_LS(ar_input, order);

            % Build state transition matrix M
            M = zeros(order);
            M(1, :) = A;
            M(2:end, 1:end-1) = eye(order - 1);

            % Observation matrix: h[n] = A * x[n]
            C = A;

            x_est = h_series(1:order); 

            P = eye(order) * 0.1;

            % Kalman prediction over time
            for n = order+1:N
                % Predict
                x_pred = M * x_est;
                P_pred = M * P * M' + Q;

                % Measurement
                y_meas = h_series(n);
                innovation = y_meas - C * x_pred;
                S = C * P_pred * C' + R;
                K = P_pred * C' / S;

                % Update
                x_est = x_pred + K * innovation;
                P = (eye(order) - K * C) * P_pred;

                % Store corrected prediction
                H_pred(f, t, n - order) = x_est(1);
            end

            % Compute MSE over time for this location
            h_actual = h_series(order+1:end);
            h_est = squeeze(H_pred(f, t, :));
            pred_error(f, t) = mean((h_actual - h_est).^2);
        end
    end
end

function A = estimateAR_LS(data, order)
    % Least-squares AR coefficient estimator
    % data: 1D real-valued signal
    % order: AR model order
    % returns A: [1 x order] AR coefficients

    N = length(data);
    if N <= order
        A = zeros(1, order);  % Not enough data
        return;
    end

    % Create Toeplitz matrix of past values
    X = zeros(N - order, order);
    for i = 1:order
        X(:, i) = data(order - i + 1:N - i);
    end
    y = data(order + 1:N);

    % Solve least squares: X * A' ≈ y
    A = (X' * X) \ (X' * y);
    A = A';  % Return as row vector
end




















%% Local Functions

function hest = hPreprocessInput(rxGrid,dmrsIndices,dmrsSymbols)
% Perform linear interpolation of the grid and input the result to the
% neural network This helper function extracts the DM-RS symbols from
% dmrsIndices locations in the received grid rxGrid and performs linear
% interpolation on the extracted pilots.

    % Obtain pilot symbol estimates
    dmrsRx = rxGrid(dmrsIndices);
    dmrsEsts = dmrsRx .* conj(dmrsSymbols);

    % Create empty grids to fill after linear interpolation
    [rxDMRSGrid, hest] = deal(zeros(size(rxGrid)));
    rxDMRSGrid(dmrsIndices) = dmrsSymbols;
    
    % Find the row and column coordinates for a given DMRS configuration
    [rows,cols] = find(rxDMRSGrid ~= 0);
    dmrsSubs = [rows,cols,ones(size(cols))];
    [l_hest,k_hest] = meshgrid(1:size(hest,2),1:size(hest,1));

    % Perform linear interpolation
    f = scatteredInterpolant(dmrsSubs(:,2),dmrsSubs(:,1),dmrsEsts);
    hest = f(l_hest,k_hest);

end

function [trainData,trainLabels] = hGenerateTrainingData(dataSize)
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
    [trainData, trainLabels] = deal(zeros([612 14 numExamples]));

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
        [rxWaveform,pathGains,sampleTimes] = channel(txWaveform);

        % Add additive white Gaussian noise (AWGN) to the received time-domain
        % waveform. To take into account sampling rate, normalize the noise power.
        % The SNR is defined per RE for each receive antenna (3GPP TS 38.101-4).   
        SNRdB = randi([0 10]);  % Random SNR values between 0 and 10 dB
        SNR = 10^(SNRdB/10);    % Calculate linear SNR
        N0 = 1/sqrt(2.0*nRxAnts*double(waveformInfo.Nfft)*SNR);
        noise = N0*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));
        rxWaveform = rxWaveform + noise;

        % Perfect synchronization. Use information provided by the channel
        % to find the strongest multipath component
        pathFilters = getPathFilters(channel); % Get path filters for perfect channel estimation
        [offset,~] = nrPerfectTimingEstimate(pathGains,pathFilters);

        rxWaveform = rxWaveform(1+offset:end, :);

        % Perform OFDM demodulation on the received data to recreate the
        % resource grid, including padding in case practical
        % synchronization results in an incomplete slot being demodulated
        rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
        [K,L,R] = size(rxGrid);
        if (L < carrier.SymbolsPerSlot)
            rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
        end

        % Perfect channel estimation, using the value of the path gains
        % provided by the channel. This channel estimate does not
        % include the effect of transmitter precoding
        estChannelGridPerfect = nrPerfectChannelEstimate(carrier,pathGains, ...
            pathFilters,offset,sampleTimes);

        % Linear interpolation
        dmrsRx = rxGrid(dmrsIndices);
        dmrsEsts = dmrsRx .* conj(dmrsSymbols);
        f = scatteredInterpolant(dmrsSubs(:,2),dmrsSubs(:,1),dmrsEsts);
        hest = f(l_hest,k_hest);
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

function plotChEstimates(interpChannelGrid,estChannelGrid,estChannelGridNN,estChannelGridPerfect,...
                         interp_mse,practical_mse,neural_mse)
% Plot the different channel estimates and display the measured MSE

    % To CPU in case estChannelGridNN and neural_mse are gpuArrays
    estChannelGridNN = gather(estChannelGridNN);
    neural_mse = gather(neural_mse);

    figure;
    cmax = max(abs([estChannelGrid(:); estChannelGridNN(:); estChannelGridPerfect(:)]));

    subplot(1,4,1)
    imagesc(abs(interpChannelGrid));
    xlabel("OFDM Symbol");
    ylabel("Subcarrier");
    title(["Linear Interpolation", "MSE: "+interp_mse]);
    clim([0 cmax]);

    subplot(1,4,2)
    imagesc(abs(estChannelGrid));
    xlabel("OFDM Symbol");
    ylabel("Subcarrier");
    title(["Practical Estimator", "MSE: "+practical_mse]);
    clim([0 cmax]);

    subplot(1,4,3)
    imagesc(abs(estChannelGridNN));
    xlabel("OFDM Symbol");
    ylabel("Subcarrier");
    title(["Neural Network", "MSE: "+neural_mse]);
    clim([0 cmax]);

    subplot(1,4,4)
    imagesc(abs(estChannelGridPerfect));
    xlabel("OFDM Symbol");
    ylabel("Subcarrier");
    title("Actual Channel");
    clim([0 cmax]);

end
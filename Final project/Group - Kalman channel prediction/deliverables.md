# Kalman Channel Prediction Group Project: High-Level Conclusion

Group final project with Rana Bogrekci, spring 2025 (slides dated April 24, 2025). We used a linear Kalman filter to estimate and predict a 5G wireless channel from past samples, then studied how the noise settings Q and R change the prediction error.

**Code** (MATLAB, in `code/`, not re-run for this summary):

- `ChanPrediction.m` (Apr 23, 2025): the final version, which made the figures in slides 16–19. It's set to the last setting tried, Q = 1·I and R = 0.01. The Q/R sweeps came from editing these values and re-running.
- `channelestimation.m` (Apr 13, 2025): the first draft. It walks through the MathWorks example step by step, with comments in Chinese, and has an earlier Kalman function with Q = 0.1·I, R = 0.5, MSE only, and no plots.

## Problem and data

- **What a channel is.** In a wireless link, the received symbol is Y(k) = H(k)·X(k) + noise. H(k) is the complex channel gain. The receiver has to know H to decode the data, and in 5G the transmitter sends known pilot symbols so the receiver can estimate it. When the user moves, the channel ages, so predicting the next H from past ones helps.
- **Data.** We generated the data with MATLAB 5G Toolbox, starting from MathWorks' "Deep Learning Data Synthesis for 5G Channel Estimation" example. Setup: SISO, 16-QAM, 51 resource blocks at 30 kHz subcarrier spacing (612 subcarriers × 14 OFDM symbols per slot), TDL-A channel with 300 ns delay spread and 50 Hz maximum Doppler shift, and SNR picked at random from 0–10 dB. Each slot gives two grids. One is a noisy estimate, made by linear interpolation between the DM-RS pilots. The other is the perfect channel.
- **Time series.** We treated each of the 612 × 14 grid positions as its own time series across 100 slots and filtered each one separately. Only the real part was used.

## Method

1. **AR model.** For each grid position, we fit an order-6 autoregressive model h[n] = Σ aᵢ·h[n − i] by least squares on the first 16 samples.
2. **State-space form.** The AR coefficients become the transition matrix M (companion form), so x[n] = M·x[n − 1] + w[n] and y[n] = C·x[n] + v[n]. Here w has covariance Q (how much we distrust the model) and v has covariance R (how much we distrust the measurement).
3. **Kalman loop.** Predict x̂ and P, compute the gain K, then update x̂ and P with the innovation y[n] − C·x̂. Initial P = 0.1·I. The filter ran over slots 7–100.
4. **Error metric.** NMSE = ‖ŷ − y‖² / ‖y‖², also shown in dB.

## Results

**Error map.** For most subcarriers and symbols, the NMSE is between about −20 and −50 dB. The error is higher on a few subcarrier bands and in the first two and last two OFDM symbols. The DM-RS pilots sit in symbols 2 and 11, so those edge symbols are extrapolated instead of interpolated. That's a likely reason they're noisier.

**Effect of Q and R.** Steady-state NMSE, read off the plots by eye (approximate):

| Q | R | Steady-state NMSE |
|---|---|---|
| 0.1 | 0.01 | ≈ 0.01 |
| 0.1 | 0.1 | ≈ 0.015 |
| 0.1 | 0.5 | ≈ 0.05 |
| 0.1 | 1 | ≈ 0.08 |
| 0.001 | 0.01 | ≈ 0.08 |
| 0.01 | 0.01 | ≈ 0.015 |
| 1 | 0.01 | ≈ 0.01 |

- **Raising R raises the error.** A larger R tells the filter to trust the measurements less and lean on the AR model more, and the model is the weaker part here.
- **Raising Q lowers the error, up to a point.** Q = 0.001 is far too confident in the model: the error first dips, then climbs back to about 0.08. Going from Q = 0.01 to 0.1 helps. Q = 0.1 and Q = 1 land almost on top of each other, so the plots don't clearly show the error rising again at Q = 1, which the slides say happens.
- **Q > R works best.** Every low-error setting trusts the measurements more than the model.
- **The filter settles fast.** Every setting reaches its steady-state error within about 10–30 slots.

## What the results do and don't show

Reading the code (`code/ChanPrediction.m`) shows that the setup makes the problem easier than real channel prediction:

- **The channel doesn't change between slots.** The channel seed is fixed (`channel.Seed = 0`) for every slot, so all 100 slots see the same channel realization. Only the noise changes. This is the "static channel" case that the slides' conclusion refers to.
- **The filter measures the answer.** The perfect channel is used both as the filter's measurement y and as the reference for NMSE. So trusting the measurement more (lower R, higher Q) has to lower the error. In a real receiver, the measurement would be the noisy pilot-based estimate. The first draft (`code/channelestimation.m`) actually did that: it used the noisy grid both to fit the AR model and as the measurement. The final version switched the measurement to the perfect channel.
- **The output is a filtered estimate, not a forecast.** The stored value is x̂ after the update with y[n], so it has already seen the current sample. A true one-step-ahead prediction would use x̂[n | n − 1].
- **The observation matrix is the AR coefficients (C = A),** not a selector that picks out the current sample (C = [1 0 … 0]). This mixes the model into the measurement equation.

So the low NMSE shows that the Kalman machinery works and responds to Q and R the way theory says it should. It doesn't yet show how well the filter can predict a changing channel.

## Overall

1. **A Kalman filter is a weighted vote between the model and the data.** Q and R set the weights. The tuning plots show this directly: whichever side we trust more drives the result, and the best setting trusts the stronger side.
2. **The model is the weak link.** An order-6 AR model fit on 16 samples is rough, which is why every good setting leans on the measurements. Better system identification would let the model carry more weight.
3. **The test setup decides what the numbers mean.** A fixed channel, and the true channel used as the measurement, make the problem much easier than real prediction. The next tests are random channel seeds, the noisy pilot estimate as the measurement, and NMSE on x̂[n | n − 1].
4. **A changing channel needs more than a linear filter.** For a channel that changes over time, the slides point to an extended (nonlinear) Kalman filter. They also suggest a continuous-time channel model to compare with the discrete-time one. Both are listed as future work.
5. **This connects back to control.** The state-space model, prediction–correction loop, and covariance tuning are the same tools behind the observer in state-feedback control. Here they're used on a communications problem.

# Classical Control Projects (MATLAB)

Two final projects from EECE 5580 Classical Control Systems at Northeastern University (spring 2025):

1. **[Twin-rotor (TWR) control design](#1-twin-rotor-twr-control-design-individual)** (individual): built a plant model from frequency-response data, designed a lead-lag controller that stabilizes an unstable loop, and tested it against hidden dynamics and time delay.
2. **[Kalman filter for 5G channel prediction](#2-kalman-filter-for-5g-channel-prediction-group)** (group, with Rana Bogrekci): fit an AR model to simulated 5G channel data, ran a Kalman filter on it, and studied how the Q/R noise settings change the prediction error.

**Tools:** MATLAB (Control System Toolbox, System Identification Toolbox, 5G Toolbox)
**Topics:** system identification, root locus, Bode and Nyquist analysis, lead-lag and PID design, robustness, state-space models, Kalman filtering

---

## 1. Twin-rotor (TWR) control design (individual)

**Problem.** We're given 11 frequency-response measurements of a twin-rotor propulsion system. The goal: build a model, then design a controller that makes the closed loop stable, fast, and accurate.

**What I did**

- **Modeled the plant from data.** Fit transfer functions of order 1–4 with `idfrd` + `tfest`. Order 3 fit the data at 99.92% (order 2: 89.86%), so that's the model I used.
- **Showed the uncompensated loop is unstable** with root locus, Bode (gain margin −8.02 dB, phase margin −21.4°), Nyquist, and the step response.
- **Designed the controller step by step.** P was stable but levels off near 0.30 instead of 1. Lead fixed stability but left a large steady-state error. Adding lag fixed the error. The final lead-lag design has **5.3% overshoot, 2.3 s rise time, and 24 s settling time**.
- **Tested robustness.** The design stayed stable with the measured data scaled by ±2% and with 2% random noise. I then added a hidden all-pass factor (invisible in gain-only data) and retuned the controller. The retuned design handled a 0.1 s time delay well.
- **Analyzed a plant that only an unstable controller can stabilize.** For G(s) = (s − 1)/((s + 1)(s − 2)), I showed why P and PID fail, and used the parity interlacing property to show that no stable controller can work. Then I showed how moving the poles to 2 ± j makes a stable controller possible.

| Before: unity feedback | After: lead-lag controller |
|---|---|
| ![Closed-loop step response before the controller: oscillations grow without bound](<Final project/Individual - TWR control design/figures/original unstable step resp.jpg>) | ![Closed-loop step response with the lead-lag controller: settles near 0.95](<Final project/Individual - TWR control design/figures/llc step resp.jpg>) |

**Files**

- [Final report (PDF, 23 pages)](<Final project/Individual - TWR control design/report/Fanghsin_Li_ClassicalControl_Final.pdf>)
- [Controller-tuning notes (PDF)](<Final project/Individual - TWR control design/report/Final Design version Controller.pdf>): P and PID gain sweeps
- [Summary of results and takeaways](<Final project/Individual - TWR control design/deliverables.md>)
- [All figures](<Final project/Individual - TWR control design/figures/>): root locus, Bode, Nyquist, step responses, robustness checks

---

## 2. Kalman filter for 5G channel prediction (group)

**Problem.** A 5G receiver needs to know the wireless channel to decode data, and the channel changes as the user moves. We tested whether a Kalman filter can estimate and predict it from past samples.

**What we did**

- **Generated the data** with MATLAB 5G Toolbox: 16-QAM, 612 subcarriers × 14 OFDM symbols per slot, TDL-A channel, random SNR from 0–10 dB.
- **Built the model.** Treated each grid position as a time series, fit an order-6 autoregressive (AR) model by least squares, and turned it into state-space form.
- **Ran a Kalman filter** on every grid position and measured the error as NMSE. Most positions came out between −20 and −50 dB.
- **Tuned Q and R.** Swept the process and measurement noise settings. Trusting the measurements more than the AR model (Q > R) gave the lowest error (NMSE ≈ 0.01). Every setting converged within 10–30 slots.
- **Reviewed our own test setup.** We found that it makes the problem easier than real prediction: the channel realization is fixed and the true channel is used as the measurement. We wrote up the next tests needed to measure true prediction performance.

**Files**

- [Slides (PDF)](<Final project/Group - Kalman channel prediction/Channel_Prediction_with_Kalman_Filter.pdf>)
- [MATLAB code](<Final project/Group - Kalman channel prediction/code/>): `ChanPrediction.m` is the final version
- [Project README](<Final project/Group - Kalman channel prediction/README.md>): files and code notes
- [Summary of results and takeaways](<Final project/Group - Kalman channel prediction/deliverables.md>)

---

Course handouts, exam prompts, and textbooks aren't included because they aren't mine to publish.

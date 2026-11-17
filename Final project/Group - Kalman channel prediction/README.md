# Kalman Channel Prediction (group final project)

Group final project for EECE 5580 Classical Control (spring 2025), with Rana Bogrekci. We fit an autoregressive (AR) model to 5G channel data, turned it into a state-space model, and used a linear Kalman filter to estimate and predict the channel. Then we studied how the noise settings Q and R change the error.

**Summary: [deliverables.md](deliverables.md)**: problem, method, results, and what the test setup does and doesn't show.

## Files

```
Group - Kalman channel prediction/
├── README.md                                     this file
├── deliverables.md                               high-level conclusion
├── Channel_Prediction_with_Kalman_Filter.pdf     slides, 22 pages
├── Kalman Filters.docx                           written report
├── Channel Estimation with Kalman Filter.docx    research notes
├── Kalman filter.docx                            background notes
├── Simulate PDSCH DM.docx                        note on zero-padding the received grid
└── code/                                         final MATLAB code (5G Toolbox data)
    ├── channelestimation.m                       first draft
    └── ChanPrediction.m                          final version; made the figures in the slides
```

| File | What it is |
|---|---|
| [deliverables.md](deliverables.md) | Our high-level conclusion of the project: data, method, Q/R results, limits of the test setup, and takeaways. |
| [Channel_Prediction_with_Kalman_Filter.pdf](Channel_Prediction_with_Kalman_Filter.pdf) | The final presentation (Apr 24, 2025): channel estimation background, the AR + Kalman filter method, Q/R tuning results, and conclusions. |
| `Kalman Filters.docx` | Our written report. It has the same content as slides 10–20 (Kalman filter benefits, state-space model, algorithm steps, Q/R results, conclusions). |
| `Channel Estimation with Kalman Filter.docx` | Our shared planning doc, exported from Google Drive: useful links, related-work notes, the plan to start with one channel, and who worked on what. |
| `Kalman filter.docx` | A ChatGPT-generated explanation of how the Kalman filter applies to channel time-series prediction (state vector, M, C, Q, R, predict/update). |
| `Simulate PDSCH DM.docx` | A short note (in Chinese, one screenshot) on why the received grid gets zero-padded when fewer than 14 OFDM symbols are demodulated. |
| [code/channelestimation.m](code/channelestimation.m) | First MATLAB draft: the MathWorks 5G example with detailed Chinese comments, plus our first Kalman filter function. |
| [code/ChanPrediction.m](code/ChanPrediction.m) | Final MATLAB version: generates the 5G channel data, runs the AR + Kalman filter, and draws the NMSE figures used in the slides. |

## Group project code

Both scripts in `code/` start from MathWorks' "Deep Learning Data Synthesis for 5G Channel Estimation" example (SISO, 612 subcarriers × 14 OFDM symbols). They fit an AR model by least squares, then run a linear Kalman filter on each grid position.

**[channelestimation.m](code/channelestimation.m) is the first draft, and [ChanPrediction.m](code/ChanPrediction.m) is the version that made the figures in the slides.**

| | `channelestimation.m` (Apr 13, 2025) | `ChanPrediction.m` (Apr 23, 2025) |
|---|---|---|
| Purpose | Working through the MathWorks example, with detailed Chinese comments on each step (TDL channel, DM-RS, OFDM, AWGN, sync) | Cleaned-up project version |
| Kalman function | `kalman_predict_3D(H, 6)`, noisy data only | `kalman_predict_3D_tensor(noisy, perfect, 6)` |
| Q / R | Q = 0.1·I, R = 0.5 | Q = 1·I, R = 0.01 (the last setting tried) |
| Error metric | MSE | MSE, NMSE, NMSE (dB), NMSE over time |
| Figures | None for the Kalman part | Same titles as slides 16–19 |

### Things noticed while reading the code (not re-run)

Line numbers refer to `ChanPrediction.m`. What these mean for the results is covered in [deliverables.md](deliverables.md) under "What the results do and don't show."

1. **The "time slots" don't change over time.** Each loop iteration sets `channel.Seed = 0` and the same TDL-A / 300 ns / 50 Hz settings (lines 332–337). So all 256 examples are the same channel, and only the noise changes (random SNR, 0–10 dB). This is why slide 20 says the method works for a "static channel."
2. **The filter's measurement is the ground truth.** `y_series = trainLabels` (the perfect channel). The Kalman update uses `y(n)` as the measurement (line 188), and NMSE is scored against the same `y` (line 205). This explains why lower R works better and why the filter "trusts the measurements more." In a real receiver, the measurement would be the noisy `trainData`.
3. **`C = A`** (line 177). For an AR state vector, the usual observation matrix is `C = [1 0 … 0]`.
4. **Only the real part** of the complex channel is used (line 72).
5. **Leftover code:** line 233 repeats `innovation = ...` inside the plotting section. It's harmless but can be deleted.

`trainDataClean` (the noise-free interpolated grid) is computed but never used. Using it, or the noisy `trainData`, as the measurement would fix point 2.

# Classical Control Final Project: High-Level Conclusion

EECE 5580 Classical Control Systems, spring 2025. The final project is a two-part take-home exam. In Part 1 we build a model of a twin-rotor (TWR) propulsion system from 11 frequency-response measurements and design a controller for it. In Part 2 we test that design against a hidden all-pass factor and a time delay, then work on a plant that can only be stabilized by an unstable controller.

## Part 1: TWR plant, from data to controller

**Modeling.** We fit transfer functions of order 1 to 4 to the frequency data (`idfrd` + `tfest`) and compared the fit rates:

| Order | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| Fit rate | 40.86% | 89.86% | 99.92% | 99.92% |

Order 3 is the smallest model that fits the data almost perfectly, so we used it. Order 4 adds complexity without improving the fit.

**Open-loop analysis.** All three tools tell the same story: with unity feedback, the loop is unstable.

- Root locus: two branches cross into the right half-plane once the gain passes a critical value.
- Bode: gain margin −8.02 dB and phase margin −21.4°. Both are negative.
- Nyquist: the curve encircles (−1, 0) clockwise.
- Step response: the oscillations grow without bound.

**Controller design.** We tried the controllers in order of complexity:

| Controller | Result |
|---|---|
| P (Kp = 0.1) | Stable, but large overshoot, slow settling, and the output levels off near 0.30 instead of 1 |
| PID | Could not find gains that gave the performance we wanted |
| Lead | Stable with no overshoot, but still a large steady-state error |
| Lead-lag (final) | Stable, overshoot 5.3%, rise time 2.3 s, settling time 24 s, output near 0.9–0.95, phase margin 38.8° at 0.8 rad/s |

The lead part adds phase margin and speed. The lag part raises the low-frequency gain to cut the steady-state error. Neither part does both jobs alone.

**Robustness.** With the same lead-lag controller, we scaled the measured response by +2% and −2% and added 2% random noise. The closed loop stayed stable with a similar step response in all three cases.

## Part 2: Hidden dynamics and an unstable plant

### Q1: The missing all-pass factor and time delay

- An all-pass factor (1 − Ts)/(1 + Ts) has a magnitude of exactly 1 at every frequency. If an experiment only records gain, the factor is invisible. It still adds phase lag that grows from 0° to −180°: each of the numerator and denominator adds up to −90° as the frequency goes up.
- That extra lag is a right-half-plane zero at s = 1/T, which eats into the phase margin. We picked T = 0.5 and retuned the lead-lag controller.
- With a time delay added and the plant kept the same, the retuned design handled a 0.1 s delay well. Overshoot went above 10% once the delay reached 0.2 s. Based on the plots, the report puts the edge of marginal stability at about an 8 s delay.

### Q2: G(s) = (s − 1) / ((s + 1)(s − 2))

- **(a) P or PID can't stabilize it.** With a P controller, the closed-loop polynomial is s² + (K − 1)s − (2 + K). Stability needs K > 1 and K < −2 at the same time, which is impossible. With the right-half-plane zero at s = 1, one root-locus branch always stays trapped between the zero and the unstable pole at s = 2.
- **(b) No stable controller can work.** This follows from the parity interlacing property. Between the real right-half-plane zeros at s = 1 and s = ∞, there is an odd number of real unstable poles (just the one at s = 2). So any controller that stabilizes this plant must be unstable itself. The hint controller H(s) = 9(s + 1)/(s − 5) does stabilize it: the closed-loop polynomial is (s + 1)³, so all three closed-loop poles sit at s = −1. In Nyquist terms, the loop has 2 open-loop unstable poles (s = 2 and s = 5), so it needs 2 counterclockwise encirclements of (−1, 0). A negative phase margin read off the Bode plot does not prove instability here, because the usual margin rules assume a stable open loop.
- **(c) Downsides of an unstable controller.** If the loop opens (a sensor fails, an actuator saturates, or the controller starts before the loop closes), the controller's own states blow up. The design is also sensitive to model errors, and the RHP zero and pole together limit what performance we can get. A state-feedback-plus-observer design can place the closed-loop poles directly, and the separation principle lets us design the two parts separately. Even so, the resulting controller can still be unstable on its own. The same parity rule applies to any LTI controller.
- **(d) Unstable poles at 2 ± j instead of 2.** Complex poles don't count toward the parity test, so there's now an even number (zero) of real unstable poles between s = 1 and s = ∞. The plant becomes stabilizable with a **stable** controller. The hint H(s) = 30(s + 1.1)/(s + 8) works: the closed-loop poles are at about −4.14, −0.52, and −0.17 ± 1.80j, all in the left half-plane. The lightly damped pair at −0.17 ± 1.80j shows that performance is still limited by the RHP zero.

### Q3: Using an AI tool for a simple design

We asked ChatGPT to design a controller for G(s) = 1/(s + 1). It went through three versions, and we checked each one with `stepinfo`:

1. PI, C(s) = 1.8 + 4/s: removes the steady-state error, with a small overshoot.
2. More aggressive PI, C(s) = 4.6 + 16/s: much faster, but more overshoot.
3. PID, C(s) = 4.6 + 16/s + 0.7s: fast rise and settling with the overshoot kept under control. This was the best overall.

The AI's first answer (PI is enough for a first-order plant) was already sound. The useful part was checking each suggestion in MATLAB instead of trusting it.

## Overall

1. **A model is only as good as what we measured.** A third-order fit matched the gain data at 99.9%, but the gain data alone couldn't reveal the all-pass factor. Measuring phase, or testing the design against plausible hidden dynamics, is part of the job.
2. **Root locus, Bode, and Nyquist are three views of the same thing.** They agreed on stability every time in Part 1. Part 2 showed where the shortcuts break down: gain and phase margins read off a Bode plot assume a stable open loop, and only the full Nyquist count is reliable when the open loop has unstable poles.
3. **Pick the compensator for the job.** Lead fixed stability and speed but not accuracy. Adding lag fixed the accuracy. Trying controllers from simple to complex made it clear what each piece contributes.
4. **Some limits come from the plant, not the controller.** RHP zeros and unstable poles set hard limits. When a real unstable pole lies between RHP zeros, even the controller has to be unstable. Moving those poles off the real axis changes the answer completely.
5. **Robustness checks are cheap and worth it.** Perturbing the data by ±2%, adding noise, and adding delay were all quick tests that showed how much margin the lead-lag design really had.

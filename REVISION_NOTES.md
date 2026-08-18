# JURI revision notes — JURI-00314-2026-01

This branch was created to keep the public code synchronized with the peer-review revision.

## Reviewer-driven changes

1. Added an explicit novelty statement to the manuscript abstract.
2. Redrew the system synoptic and reduced-order Simulink-logic figure at publication quality.
3. Replaced the dense 3×3 time-domain panel with separate readable plots.
4. Expanded the literature review with recent studies and quantitative findings.
5. Added a prior-work comparison table.
6. Rebuilt and audited citations/references.
7. Split long sentences and standardized notation/formatting.
8. Extended numerical verification across Scenarios A/B/C and the three requested metrics: nadir, 200 ms RoCoF and peak ΔVDC.
9. Added BESS power, saturation-time, delivered-energy and SOC evidence per scenario.
10. Resolved the `Sbase` ambiguity by defining `Pload0` separately.

## Numerical integrity policy

The independent Python loop refines numerical step size only. Controller gains, BESS rating and physical parameters are not optimized to force a favorable conclusion.

The all-scenario extension is an independent BDF/RK4 software-in-the-loop cross-verification of the reduced-order equations. It is **not** represented as new Simulink, HIL or experimental validation.

## Corrected interpretation

- The 49.0 Hz value is a study-specific under-frequency screening threshold.
- Scenario B with the 200 MW BESS reaches 48.383 Hz and therefore still crosses that threshold.
- The 2 Hz/s / 200 ms RoCoF value is a study benchmark, not a universal regulatory limit.
- Reproduced DC-voltage-excursion reductions are approximately 37.0%, 30.8% and 54.2% for A/B/C.
- Mean RoCoF reduction across A/B/C is approximately 54.7%.
- A 10-MW-step Scenario-B sensitivity sweep finds 280 MW as the first tested rating with nadir ≥49.0 Hz. This is not claimed as a universal optimum.

## Double-anonymized manuscript note

The public repository URL and QR code are deliberately excluded from the blinded revision. They should only be inserted after deanonymization if the journal permits it.

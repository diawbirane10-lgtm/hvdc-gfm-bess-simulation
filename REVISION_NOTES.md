# JURI revision notes — JURI-00314-2026-01

This branch was created to keep the public code synchronized with the peer-review revision.

## Reviewer-driven changes

1. Added an explicit novelty statement to the manuscript abstract.
2. Redrew the three-terminal system synoptic at publication quality. The underlying Simulink block diagram was **not redesigned or altered**; its original content was retained and only rendered at 4K/high resolution for legibility.
3. Replaced the dense 3×3 time-domain panel with separate, full-width, publication-readable plots.
4. Expanded the literature review with recent studies, quantitative findings, and a directly relevant 2022 study on DC-link storage for grid-forming HVDC control.
5. Added a prior-work comparison table.
6. Rebuilt and audited citations/references in Nature-style numerical order of first appearance.
7. Split long sentences and standardized notation, symbols, units, captions, and formatting.
8. Extended numerical cross-verification across Scenarios A/B/C and the three reviewer-requested metrics: frequency nadir, 200 ms RoCoF, and peak ΔVDC.
9. Added BESS peak power, time-to-saturation, delivered-energy, and SOC evidence per scenario.
10. Resolved the `Sbase` ambiguity by defining the nominal physical load `Pload0` separately from the per-unit/system normalization base `Sbase`.

## Numerical integrity policy

The independent Python verification loop refines numerical step size only. Controller gains, BESS rating, disturbance magnitudes, and physical parameters are not optimized to force a favorable conclusion.

The all-scenario extension is an independent BDF/RK4/Radau software-in-the-loop cross-verification of the reduced-order equations. It is **not** represented as new hardware-in-the-loop, experimental, or unexecuted Simulink validation.

Two substantive numerical verification loops are used:

- adaptive stiff BDF versus independently coded fixed-step RK4 with automatic time-step refinement against pre-declared tolerances;
- BDF versus implicit Radau, followed by physical regression checks including DC-droop equilibrium and SOC/energy consistency.

## Corrected interpretation

- The 49.0 Hz value is a study-specific under-frequency screening threshold.
- Scenario B with the 200 MW BESS reaches approximately 48.383 Hz and therefore still crosses that threshold.
- The 2 Hz/s over 200 ms value is a study screening benchmark, not a universal regulatory limit.
- Reproduced DC-voltage-excursion reductions are approximately 37.0%, 30.8%, and 54.2% for Scenarios A/B/C.
- Mean RoCoF reduction across A/B/C is approximately 54.7%.
- The approximately 1.615–1.616 Hz nadir improvement across the three cases is supported by explicit BESS saturation and energy-delivery data.
- A 10-MW-step Scenario-B sensitivity sweep finds 280 MW as the first tested rating with nadir ≥49.0 Hz. This is a model-specific discrete sensitivity result, not a universal sizing optimum.

## Double-anonymized manuscript note

No repository URL, QR code, portfolio link, email address, author name, affiliation, or other identifying link is included in the blinded manuscript. Repository work remains separate from the revision document during blind review.

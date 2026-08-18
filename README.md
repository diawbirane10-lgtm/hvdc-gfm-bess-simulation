# 3-Terminal VSC-HVDC — Grid-Forming VSM-BESS Frequency Stability

Reproducible reduced-order study of a **three-terminal VSC-HVDC renewable power system** comparing a passive-BESS **grid-following (GFL)** baseline with a **grid-forming (GFM) Virtual Synchronous Machine (VSM)** controller supported by a **DC-coupled 200 MW / 200 MWh BESS**.

> **JURI manuscript JURI-00314-2026-01 — revision branch.**  
> The journal requested revisions after peer review. This branch synchronizes the public research code with the revised numerical results. It does **not** claim final publication acceptance.

## Study system

| Quantity | Value |
|---|---:|
| System normalization base `Sbase` | 1400 MW |
| Nominal physical load `Pload0` | 1400 MW |
| Common DC-bus voltage | 320 kV |
| Equivalent AC-grid inertia | 3.0 s |
| BESS | 200 MW / 200 MWh |
| VSM virtual inertia | 6.0 s |
| VSM virtual damping | 20 pu |
| BESS inner-loop time constant | 25 ms |

The revised notation deliberately separates `Sbase` (normalization base) from `Pload0` (nominal load), even though both are 1400 MW in the present operating point.

## Contingencies

| Scenario | Disturbance |
|---|---|
| A | +280 MW load step (+20%) |
| B | −400 MW offshore-wind trip |
| C | −300 MW PV ramp completed in 100 ms |

## Revised numerical results

The values below are reproduced by the independent Python/SciPy implementation on this branch.

| Scenario | Mode | Nadir (Hz) | |RoCoF|, 200 ms (Hz/s) | Peak ΔVDC (kV) | 49.0-Hz study threshold crossed? |
|---|---|---:|---:|---:|---|
| A | GFL | 47.737 | 1.530 | −9.333 | Yes |
| A | GFM+BESS | 49.353 | 0.593 | −5.884 | No |
| B | GFL | 46.768 | 2.186 | −13.333 | Yes |
| B | GFM+BESS | 48.383 | 1.244 | −9.223 | Yes |
| C | GFL | 47.576 | 1.212 | −10.000 | Yes |
| C | GFM+BESS | 49.192 | 0.487 | −4.576 | No |

**Important correction:** Scenario B remains below the **49.0 Hz study-specific screening threshold** with the 200 MW BESS. Earlier README wording that placed Scenario B above 49 Hz was incorrect.

The 2 Hz/s value used in the paper is likewise treated as a **study screening benchmark**, not as a universal grid-code limit.

## Reviewer-requested BESS evidence

The BESS reaches 99% of its 200 MW discharge rating in about **0.117–0.166 s** in all three scenarios. Energy delivered up to the frequency nadir is about **0.141–0.144 MWh**, explaining why the nadir improvement is nearly identical (about **1.615–1.616 Hz**) across the tested disturbances: the controller encounters the same power ceiling early in each event.

A post-review Scenario-B sensitivity sweep changes only the BESS discharge ceiling. In the tested 10 MW increments, **280 MW is the first rating with nadir ≥49.0 Hz**; this is a model-specific sensitivity result, not a universal sizing optimum.

## Independent software-in-the-loop cross-verification

`python/hvdc_gfm_bess_sil.py` translates the five-state reduced-order equations to Python/SciPy and compares adaptive stiff **BDF** with an independently coded fixed-step **RK4** solver.

An automatic refinement loop tests RK4 time steps of 1 ms, 0.5 ms, 0.2 ms and 0.1 ms. It accepts the first step satisfying pre-defined numerical-consistency tolerances for nadir, RoCoF and peak DC-voltage excursion. The accepted step is **0.2 ms**.

This loop **does not tune VSM/BESS parameters to obtain a desired stability result**. It refines numerical accuracy only.

Across the six GFL/GFM runs, the maximum BDF/RK4 discrepancies at the accepted step are:

- frequency nadir: `7.33e-09 Hz`;
- 200 ms RoCoF: `3.76e-04 Hz/s`;
- peak ΔVDC: `3.38e-05 kV`.

The existing Simulink model remains a separate implementation check. The previously available Scenario-B GFM nadir is approximately **48.4 Hz**, versus **48.38 Hz** in the reduced-order simulation. No unexecuted A/C Simulink results are presented as measured data.

## Repository structure

```text
.
├── hvdc_gfm_bess.slx
├── hvdc_gfm_bess_sim.m
├── hvdc_scenarios.m
├── set_scenario.m
├── sim_postprocess.m
├── run_via_mcp.m
├── python/
│   ├── hvdc_gfm_bess_sil.py
│   └── requirements.txt
├── results/revision/
│   ├── performance_metrics.csv
│   ├── bess_energy_metrics.csv
│   ├── solver_convergence_loop.csv
│   ├── solver_cross_validation.csv
│   └── scenario_B_bess_sizing_sweep.csv
└── REVISION_NOTES.md
```

The original MATLAB/Simulink files are retained for traceability. The revision assets explicitly document the notation correction and the independent Python numerical cross-check. Publication-quality revised figures are distributed with the blinded revision package rather than committed here at this stage.

## Reproduce the Python revision check

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# Linux/macOS: source .venv/bin/activate

pip install -r python/requirements.txt
python python/hvdc_gfm_bess_sil.py --out results/revision_reproduced
```

## Scope and limitations

This is a **reduced-order dynamic screening study**. It is not an EMT, real-time, hardware-in-the-loop, protection-coordination, converter-switching or grid-code certification model. Parameters are representative rather than calibrated to a specific real HVDC installation.

## Citation status

Manuscript: **JURI-00314-2026-01**, *Grid-Forming Virtual Synchronous Machine Control with DC-Coupled Battery Storage for Frequency Stability in a Multi-Terminal VSC-HVDC Renewable Power System*.

The paper is still in the revision/final-decision process. Please do not cite it as a formally published JURI article until the journal issues final acceptance/publication metadata.

function set_scenario(k)
%SET_SCENARIO  Load disturbance signals into base workspace for Simulink.
%
%   set_scenario(1)  →  Scenario A : load step   +280 MW  (+20% Sbase)
%   set_scenario(2)  →  Scenario B : wind trip   -400 MW  (N-1, default)
%   set_scenario(3)  →  Scenario C : solar ramp  -300 MW  in 100 ms
%
%   Call BEFORE Ctrl+T in hvdc_gfm_bess.slx.
%   The model reads dPw_ws, dPpv_ws, dPload_ws from the base workspace.
%
%   Each variable is a [N×2] matrix: column 1 = time (s), column 2 = power (MW).
%   Simulink From Workspace blocks interpolate linearly between time points.
%
%   Convention:
%     dPw_ws    > 0 : extra wind generation  |  < 0 : wind loss
%     dPpv_ws   > 0 : extra solar            |  < 0 : cloud ramp-down
%     dPload_ws > 0 : load increase          |  < 0 : load reduction
%
%   Validation against ODE model (hvdc_scenarios.m):
%     Scenario A GFM nadir  ≈ 49.35 Hz
%     Scenario B GFM nadir  ≈ 48.38 Hz  (Simulink: 48.4 Hz, <0.05% error)
%     Scenario C GFM nadir  ≈ 49.19 Hz

labels = {'A — Load step  +20%  (+280 MW)', ...
          'B — Wind trip  N-1   (-400 MW)', ...
          'C — Solar ramp -50%  (-300 MW / 100 ms)'};

t_f   = 0.1;     % event start time (s)
T     = 10.0;    % simulation end   (s)
eps_t = 1e-6;    % sharp edge for step signals

% Generic step time vector
tb = [0; t_f-eps_t; t_f; T];
z  = [0; 0; 0; 0];          % zero signal (same length as tb)

switch k
  % ── Scenario A : sudden load step +280 MW ─────────────────────────────
  case 1
    dPw_ws    = [tb, z];
    dPpv_ws   = [tb, z];
    dPload_ws = [tb, [0; 0; 280; 280]];

  % ── Scenario B : N-1 wind trip -400 MW ────────────────────────────────
  case 2
    dPw_ws    = [tb, [0; 0; -400; -400]];
    dPpv_ws   = [tb, z];
    dPload_ws = [tb, z];

  % ── Scenario C : solar cloud ramp -300 MW in 100 ms ───────────────────
  case 3
    t_ramp = 0.1;                               % ramp duration (s)
    t5 = [0; t_f-eps_t; t_f; t_f+t_ramp; T];   % 5-point time vector
    dPw_ws    = [tb, z];
    dPpv_ws   = [t5, [0; 0; 0; -300; -300]];    % linear ramp to -300 MW
    dPload_ws = [tb, z];

  otherwise
    error('set_scenario: k must be 1, 2, or 3  (got %d)', k);
end

% Push to base workspace (where Simulink reads From Workspace blocks)
assignin('base', 'dPw_ws',    dPw_ws);
assignin('base', 'dPpv_ws',   dPpv_ws);
assignin('base', 'dPload_ws', dPload_ws);

fprintf('\n=== Scenario %s loaded ===\n', labels{k});
fprintf('Workspace : dPw_ws | dPpv_ws | dPload_ws\n');
fprintf('Next step : Ctrl+T in hvdc_gfm_bess.slx, then sim_postprocess\n\n');

end

%% build_hvdc_simulink.m
% Builds the 3-terminal VSC-HVDC reduced-order Simulink model
% Supports all 3 scenarios via From Workspace inputs
%
% Workflow:
%   1. >> build_hvdc_simulink       % builds & saves hvdc_gfm_bess.slx
%   2. >> set_scenario(1|2|3)       % loads disturbance into workspace
%   3. Ctrl+T in hvdc_gfm_bess.slx % run simulation
%   4. >> sim_postprocess           % plot + metrics
%
% Scenario mapping:
%   1 → A: load step  +280 MW (+20% Sbase)
%   2 → B: wind trip  -400 MW  (N-1, DEFAULT)
%   3 → C: solar ramp -300 MW in 100 ms

function build_hvdc_simulink()

%% ── Parameters ──────────────────────────────────────────────────────────────
f0=50; Vdc0=320; Sbase=1400;
H=3.0; D=1.5; K_gov=15; tau_gov=8;
tau_dc=0.08; k_droop=30;
H_vsm=6.0; Df=20.0; tau_b=0.025;
Pb_max=200;
t_f=0.1;
CVdc0 = tau_dc*Sbase/Vdc0;          % MW·s/kV  (= 0.08*1400/320 = 0.35)

%% ── Default workspace variables (Scenario B) ─────────────────────────────
eps_t = 1e-6;
tb = [0; t_f-eps_t; t_f; 10];
assignin('base','dPw_ws',    [tb, [0;0;-400;-400]]);
assignin('base','dPpv_ws',   [tb, zeros(4,1)]);
assignin('base','dPload_ws', [tb, zeros(4,1)]);

%% ── Create / reset model ─────────────────────────────────────────────────
mdl = 'hvdc_gfm_bess';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl); open_system(mdl);
set_param(mdl,'Solver','ode23tb','StopTime','10',...
    'RelTol','1e-7','AbsTol','1e-9','MaxStep','2e-4',...
    'SaveTime','on','TimeSaveName','tout',...
    'SaveOutput','on','OutputSaveName','yout');

B = @(x,y,w,h) [x, y, x+w, y+h];

%% ── BLOCKS ──────────────────────────────────────────────────────────────────

% ── Disturbance sources (From Workspace — one per perturbation type) ──────
% dPw_ws   : wind power change  (MW), negative = generation loss
% dPpv_ws  : PV power change    (MW), negative = cloud ramp-down
% dPload_ws: load power change  (MW), positive = demand increase
add_block('simulink/Sources/From Workspace',[mdl '/dPw'],...
    'Position',B(30,35,115,30),...
    'VariableName','dPw_ws','SampleTime','0','Interpolate','on');
add_block('simulink/Sources/From Workspace',[mdl '/dPpv'],...
    'Position',B(30,85,115,30),...
    'VariableName','dPpv_ws','SampleTime','0','Interpolate','on');
add_block('simulink/Sources/From Workspace',[mdl '/dPload'],...
    'Position',B(30,135,115,30),...
    'VariableName','dPload_ws','SampleTime','0','Interpolate','on');

% Sign inversion for load: DC bus balance subtracts dPload
add_block('simulink/Math Operations/Gain',[mdl '/Load_Neg'],...
    'Position',B(170,135,65,30),'Gain','-1');

% ── DC Bus ────────────────────────────────────────────────────────────────
% Sum = dPw(+) + dPpv(+) + Pbess(+) + DC_FB(-k_droop·dVdc)(+) + Load_Neg(-dPload)(+)
add_block('simulink/Math Operations/Sum',[mdl '/DC_Sum'],...
    'Position',B(265,15,40,175),'Inputs','+++++');
add_block('simulink/Math Operations/Gain',[mdl '/DC_Gain'],...
    'Position',B(325,80,90,35),'Gain',num2str(1/CVdc0));
add_block('simulink/Continuous/Integrator',[mdl '/DC_Int'],...
    'Position',B(445,80,60,35),'InitialCondition','0');
% Droop feedback: dVDC → -k_droop*dVdc (already negative from gain)
add_block('simulink/Math Operations/Gain',[mdl '/DC_FB'],...
    'Position',B(360,205,90,30),'Gain',num2str(-k_droop));

% ── AC Frequency (swing equation) ─────────────────────────────────────────
add_block('simulink/Math Operations/Gain',[mdl '/AC_kDroop'],...
    'Position',B(265,305,90,30),'Gain',num2str(k_droop));
add_block('simulink/Math Operations/Gain',[mdl '/AC_dP_pu'],...
    'Position',B(395,305,90,30),'Gain',num2str(1/Sbase));
add_block('simulink/Math Operations/Gain',[mdl '/AC_Gov_pu'],...
    'Position',B(395,355,90,30),'Gain',num2str(1/Sbase));
% Sum: dP_pu(+) + Pgov_pu(+) - D·df/f0(-)
add_block('simulink/Math Operations/Sum',[mdl '/AC_Sum'],...
    'Position',B(530,300,40,55),'Inputs','++-');
add_block('simulink/Math Operations/Gain',[mdl '/AC_f0o2H'],...
    'Position',B(620,302,90,35),'Gain',num2str(f0/(2*H)));
add_block('simulink/Continuous/Integrator',[mdl '/AC_Int'],...
    'Position',B(765,302,60,35),'InitialCondition','0');
% Damping: D/f0
add_block('simulink/Math Operations/Gain',[mdl '/AC_Damp'],...
    'Position',B(620,400,90,30),'Gain',num2str(D/f0));

% ── Governor ──────────────────────────────────────────────────────────────
add_block('simulink/Math Operations/Gain',[mdl '/Gov_K'],...
    'Position',B(265,480,90,30),'Gain',num2str(-K_gov*Sbase/f0));
add_block('simulink/Continuous/Transfer Fcn',[mdl '/Gov_TF'],...
    'Position',B(400,475,110,40),...
    'Numerator','[1]','Denominator',sprintf('[%g 1]',tau_gov));

% ── VSM-BESS Control ──────────────────────────────────────────────────────
% Droop term: Pdroop = -Df·Sbase/f0 · df
add_block('simulink/Math Operations/Gain',[mdl '/BESS_Droop'],...
    'Position',B(265,580,100,30),'Gain',num2str(-Df*Sbase/f0));
% Inertia term (filtered derivative): -2·Hvsm·Sbase/f0 · s/(0.02s+1)
add_block('simulink/Continuous/Transfer Fcn',[mdl '/BESS_Inertia'],...
    'Position',B(265,635,130,35),...
    'Numerator',sprintf('[%g 0]',-2*H_vsm*Sbase/f0),...
    'Denominator','[0.02 1]');
% Sum droop + inertia
add_block('simulink/Math Operations/Sum',[mdl '/BESS_Sum'],...
    'Position',B(445,583,40,40),'Inputs','++');
% Rating saturation: Pmax=200 MW, Pmin=-50 MW (charging limit)
add_block('simulink/Discontinuities/Saturation',[mdl '/BESS_Sat'],...
    'Position',B(535,583,80,35),...
    'UpperLimit',num2str(Pb_max),'LowerLimit','-50');
% Inner-loop first-order lag: 1/(τb·s+1)
add_block('simulink/Continuous/Transfer Fcn',[mdl '/BESS_Lag'],...
    'Position',B(665,583,110,35),...
    'Numerator','[1]','Denominator',sprintf('[%g 1]',tau_b));

% ── GFL / GFM Manual Switch ───────────────────────────────────────────────
% UP   (CurrentSetting=0) = GFM : BESS active
% DOWN (CurrentSetting=1) = GFL : BESS = 0
add_block('simulink/Signal Routing/Manual Switch',[mdl '/Mode_SW'],...
    'Position',B(835,580,50,50),'CurrentSetting','0');
add_block('simulink/Sources/Constant',[mdl '/GFL_Zero'],...
    'Position',B(750,655,55,25),'Value','0');

% ── Outputs (To Workspace) ────────────────────────────────────────────────
add_block('simulink/Sinks/To Workspace',[mdl '/OUT_df'],...
    'Position',B(880,302,120,28),...
    'VariableName','df_sim','SampleTime','-1','SaveFormat','Array');
add_block('simulink/Sinks/To Workspace',[mdl '/OUT_dVdc'],...
    'Position',B(530,80,120,28),...
    'VariableName','dVdc_sim','SampleTime','-1','SaveFormat','Array');
add_block('simulink/Sinks/To Workspace',[mdl '/OUT_Pbess'],...
    'Position',B(940,583,120,28),...
    'VariableName','Pbess_sim','SampleTime','-1','SaveFormat','Array');
add_block('simulink/Sinks/Scope',[mdl '/Scope'],...
    'Position',B(880,415,50,60),'NumInputPorts','3');

%% ── CONNECTIONS ─────────────────────────────────────────────────────────────
ar = {'autorouting','on'};

% Disturbances → DC_Sum (port assignment)
%   port 1: dPw   (gen loss → negative value)
%   port 2: dPpv  (PV drop → negative value)
%   port 3: Pbess (from Mode_SW, positive = injection)
%   port 4: DC_FB (-k_droop*dVdc, already negative from gain)
%   port 5: Load_Neg = -dPload  (positive demand = negative on bus)
add_line(mdl,'dPw/1',    'DC_Sum/1',ar{:});
add_line(mdl,'dPpv/1',   'DC_Sum/2',ar{:});
% port 3 connected below with Mode_SW
add_line(mdl,'DC_FB/1',  'DC_Sum/4',ar{:});
add_line(mdl,'dPload/1', 'Load_Neg/1',ar{:});
add_line(mdl,'Load_Neg/1','DC_Sum/5',ar{:});

% DC Bus chain
add_line(mdl,'DC_Sum/1', 'DC_Gain/1',ar{:});
add_line(mdl,'DC_Gain/1','DC_Int/1', ar{:});
add_line(mdl,'DC_Int/1', 'OUT_dVdc/1',ar{:});
add_line(mdl,'DC_Int/1', 'DC_FB/1',  ar{:});
add_line(mdl,'DC_Int/1', 'AC_kDroop/1',ar{:});   % dVDC coupling to AC freq

% AC Frequency chain
add_line(mdl,'AC_kDroop/1','AC_dP_pu/1',ar{:});
add_line(mdl,'AC_dP_pu/1', 'AC_Sum/1',  ar{:});
add_line(mdl,'AC_Sum/1',   'AC_f0o2H/1',ar{:});
add_line(mdl,'AC_f0o2H/1', 'AC_Int/1',  ar{:});
add_line(mdl,'AC_Int/1',   'OUT_df/1',  ar{:});
add_line(mdl,'AC_Int/1',   'Scope/1',   ar{:});

% Damping feedback
add_line(mdl,'AC_Int/1','AC_Damp/1',ar{:});
add_line(mdl,'AC_Damp/1','AC_Sum/3', ar{:});

% Governor
add_line(mdl,'AC_Int/1',   'Gov_K/1',    ar{:});
add_line(mdl,'Gov_K/1',    'Gov_TF/1',   ar{:});
add_line(mdl,'Gov_TF/1',   'AC_Gov_pu/1',ar{:});
add_line(mdl,'AC_Gov_pu/1','AC_Sum/2',   ar{:});

% VSM-BESS control
add_line(mdl,'AC_Int/1',    'BESS_Droop/1',  ar{:});
add_line(mdl,'AC_Int/1',    'BESS_Inertia/1',ar{:});
add_line(mdl,'BESS_Droop/1','BESS_Sum/1',    ar{:});
add_line(mdl,'BESS_Inertia/1','BESS_Sum/2',  ar{:});
add_line(mdl,'BESS_Sum/1',  'BESS_Sat/1',    ar{:});
add_line(mdl,'BESS_Sat/1',  'BESS_Lag/1',    ar{:});
add_line(mdl,'BESS_Lag/1',  'Mode_SW/1',     ar{:});   % GFM path
add_line(mdl,'GFL_Zero/1',  'Mode_SW/2',     ar{:});   % GFL path

% Pbess → DC_Sum port 3 + output
add_line(mdl,'Mode_SW/1','DC_Sum/3',   ar{:});
add_line(mdl,'Mode_SW/1','OUT_Pbess/1',ar{:});

% Scope: df | dVdc | Pbess
add_line(mdl,'DC_Int/1',  'Scope/2',ar{:});
add_line(mdl,'Mode_SW/1', 'Scope/3',ar{:});

%% ── Finalize ─────────────────────────────────────────────────────────────────
set_param(mdl,'ZoomFactor','FitSystem');
save_system(mdl, fullfile(pwd,[mdl '.slx']));

fprintf('\n=== hvdc_gfm_bess.slx built (3-scenario version) ===\n');
fprintf('Default loaded : Scenario B — Wind trip -400 MW\n\n');
fprintf('  set_scenario(1)  → Scenario A: load step  +280 MW\n');
fprintf('  set_scenario(2)  → Scenario B: wind trip  -400 MW  (N-1)\n');
fprintf('  set_scenario(3)  → Scenario C: solar ramp -300 MW / 100 ms\n\n');
fprintf('  Mode_SW UP   = GFM+BESS  (double-click to toggle)\n');
fprintf('  Mode_SW DOWN = GFL baseline\n');
fprintf('  Ctrl+T → run 10 s → sim_postprocess\n\n');

end

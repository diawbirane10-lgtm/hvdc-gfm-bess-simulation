%% hvdc_scenarios.m  ─────────────────────────────────────────────────────────
%  3-Terminal VSC-HVDC │ GFM-BESS vs GFL │ 3 Publication Scenarios
%
%  Scenario A  Load step +20% (280 MW)             moderate load contingency
%  Scenario B  Wind trip −400 MW                   severe N-1 contingency
%  Scenario C  Solar cloud pass −50% in 100 ms     slow-ramp contingency
%
%  Run from MATLAB: cd .../matlab_sim && hvdc_scenarios
%  Outputs:
%    fig_scenarios_3x3.png       3×3 master panel (paper Figure 3)
%    fig_nadir_comparison.png    bar chart nadir (paper Figure 4)
%    fig_rocof_comparison.png    RoCoF bar chart  (paper Figure 5)
%    hvdc_results_3sc.mat        all simulation data + metrics
% ─────────────────────────────────────────────────────────────────────────────
clear; clc; close all;

%% ═══════════════════════════════════════════════════════════════════════════
%  PARAMETERS  (identical to hvdc_gfm_bess_sim.m for consistency)
%  ═══════════════════════════════════════════════════════════════════════════
p.f0      = 50;     % Hz   nominal frequency
p.Vdc0    = 320;    % kV   nominal DC bus voltage (STN-2)
p.Sbase   = 1400;   % MW   system base power

% AC equivalent grid (weak grid, Gulf/MENA region)
p.H       = 3.0;    % s    equivalent inertia constant
p.D       = 1.5;    % pu   load damping coefficient
p.K_gov   = 15;     % pu   governor gain (1/R, droop R ≈ 6.7%)
p.tau_gov = 8;      % s    steam-turbine governor time constant

% DC bus dynamics
p.tau_dc  = 0.08;   % s    C_dc·V_dc0/S_base equivalent time constant
p.k_droop = 30;     % MW/kV  P-V droop at STN-2 (inverter / mainland)

% VSM-BESS control
p.H_vsm   = 6.0;    % s    virtual inertia constant (target: 5–10 s)
p.Df      = 20.0;   % pu   virtual damping gain
p.tau_b   = 0.025;  % s    BESS inner-loop (converter) time constant

% BESS ratings
p.Pb_max  = 200;    % MW   rated discharge power
p.Pb_min  = -50;    % MW   rated charge power (negative)
p.Erated  = 200;    % MWh  energy capacity
p.eta     = 0.95;   % -    round-trip efficiency
p.SOC_min = 0.20;   % -    lower SOC limit (SoC protection)
p.SOC_max = 0.90;   % -    upper SOC limit

% Steady-state generation
p.Pw0     = 800;    % MW   offshore wind (STN-1, rectifier)
p.Ppv0    = 600;    % MW   local solar PV (STN-3, AC side)

% Timing
p.t_f     = 0.1;    % s    event trigger time
p.f_ufls  = 49.0;   % Hz   UFLS activation threshold (ENTSO-E / GCC)

%% ═══════════════════════════════════════════════════════════════════════════
%  SCENARIO DEFINITIONS
%  ═══════════════════════════════════════════════════════════════════════════
%  Fields:
%    dP_wind   [MW]  step change in wind power   (negative = generation loss)
%    dP_load   [MW]  step change in load demand  (positive = demand increase)
%    dPpv_end  [MW]  final solar power change at end of ramp
%    t_ramp    [s]   ramp duration (0 = instantaneous step)

sc(1).label  = 'A';
sc(1).title  = 'Load step +20% (280 MW)';
sc(1).dP_wind  = 0;
sc(1).dP_load  = 280;
sc(1).dPpv_end = 0;
sc(1).t_ramp   = 0;

sc(2).label  = 'B';
sc(2).title  = 'Wind trip -400 MW (N-1)';
sc(2).dP_wind  = -400;
sc(2).dP_load  = 0;
sc(2).dPpv_end = 0;
sc(2).t_ramp   = 0;

sc(3).label  = 'C';
sc(3).title  = 'Solar cloud pass -50% in 100 ms';
sc(3).dP_wind  = 0;
sc(3).dP_load  = 0;
sc(3).dPpv_end = -300;
sc(3).t_ramp   = 0.1;

Ns = numel(sc);

%% ═══════════════════════════════════════════════════════════════════════════
%  SIMULATION
%  ═══════════════════════════════════════════════════════════════════════════
tspan = [0, 10];
x0    = [0; 0; 0; 0.60; 0];   % [Δf(Hz), ΔVdc(kV), Pbess(MW), SOC(-), Pgov(MW)]
opts  = odeset('RelTol',1e-7,'AbsTol',1e-9,'MaxStep',2e-4);

R = struct();
for k = 1:Ns
    fprintf('[Scenario %s] GFL ...', sc(k).label);
    [t,x] = ode23tb(@(t,x) odefun(t,x,p,sc(k),'GFL'), tspan, x0, opts);
    R(k).t_gfl = t;  R(k).x_gfl = x;
    fprintf(' GFM-BESS ...', sc(k).label);
    [t,x] = ode23tb(@(t,x) odefun(t,x,p,sc(k),'GFM'), tspan, x0, opts);
    R(k).t_gfm = t;  R(k).x_gfm = x;
    fprintf(' done.\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  COMPUTE METRICS
%  ═══════════════════════════════════════════════════════════════════════════
for k = 1:Ns
    R(k).gfl = compute_metrics(R(k).t_gfl, R(k).x_gfl, p);
    R(k).gfm = compute_metrics(R(k).t_gfm, R(k).x_gfm, p);
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PRINT TABLE II  (copy-paste ready for LaTeX)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('\n%s\n', repmat('═',1,74));
fprintf('  TABLE II — Performance Metrics: GFL vs GFM-BESS (3 Scenarios)\n');
fprintf('%s\n', repmat('═',1,74));
for k = 1:Ns
    g = R(k).gfl;  q = R(k).gfm;
    fprintf('\n  Scenario %s — %s\n', sc(k).label, sc(k).title);
    fprintf('  %-28s  %9s  %9s  %s\n','Metric','GFL','GFM-BESS','Limit');
    fprintf('  %s\n',repmat('-',1,62));
    fprintf('  %-28s  %9.3f  %9.3f  Hz  [> 49.0]\n','Frequency nadir (Hz)',g.fnd,q.fnd);
    fprintf('  %-28s  %9s  %9s\n','UFLS triggered',yn(g.ufls),yn(q.ufls));
    fprintf('  %-28s  %9.3f  %9.3f  Hz/s\n','RoCoF (Hz/s)',g.rocof,q.rocof);
    fprintf('  %-28s  %9.1f  %9.1f  kV  [> -16 kV]\n','ΔVdc peak (kV)',g.dVpk,q.dVpk);
    fprintf('  %-28s  %9.1f  %9.1f  %%\n','ΔVdc peak (%)',g.dVpk/p.Vdc0*100,q.dVpk/p.Vdc0*100);
    fprintf('  %-28s  %9s  %9.1f  MW\n','BESS peak power (MW)','—',q.Ppk);
    fprintf('  %-28s  %9s  %9s\n','Recovery to 49.5 Hz',g.trec,q.trec);
    fprintf('  %-28s  %9.2f  %9.2f  s\n','Nadir time after fault',g.tnd,q.tnd);
end
fprintf('\n%s\n', repmat('═',1,74));

%% ═══════════════════════════════════════════════════════════════════════════
%  FIGURE 1 — 3×3 Master Panel  (Paper: Fig. 3)
%  ═══════════════════════════════════════════════════════════════════════════
C_gfl = [0.20 0.40 0.78];   % steel blue  — GFL baseline
C_gfm = [0.84 0.18 0.15];   % crimson red — GFM+BESS
C_bss = [0.10 0.60 0.20];   % forest green — BESS power
ta    = [-0.2, 9.8];

sc_hdr = {'(A) Load step +20%','(B) Wind trip -400 MW (N-1)','(C) Solar cloud pass -50%'};
row_lbl = {{'Frequency (Hz)'},{'V_{DC} at STN-2 (kV)'},{'P_{BESS} (MW)'}};

fig1 = figure('Position',[30 30 1140 800],'Color','w');
for k = 1:Ns
    g  = R(k).gfl;  q  = R(k).gfm;
    s1 = R(k).t_gfl - p.t_f;
    s2 = R(k).t_gfm - p.t_f;

    % ── Row 1: Frequency ──────────────────────────────────────────────────
    subplot(3,3,k); hold on;
    plot(s1, g.f,'--','Color',C_gfl,'LineWidth',1.9);
    plot(s2, q.f,'-', 'Color',C_gfm,'LineWidth',1.9);
    yline(49.0,'k:','LineWidth',1.4);
    yline(49.5,'k--','LineWidth',0.8,'Alpha',0.45);
    plot(g.tnd, g.fnd, 'v','Color',C_gfl,'MarkerSize',8,'MarkerFaceColor',C_gfl);
    plot(q.tnd, q.fnd, '^','Color',C_gfm,'MarkerSize',8,'MarkerFaceColor',C_gfm);
    text(g.tnd+0.15, g.fnd-0.12, sprintf('%.2f Hz',g.fnd),'Color',C_gfl,'FontSize',7.5);
    text(q.tnd+0.15, q.fnd+0.07, sprintf('%.2f Hz',q.fnd),'Color',C_gfm,'FontSize',7.5);
    xlim(ta);
    title(sc_hdr{k},'FontSize',9,'FontWeight','bold');
    if k==1
        ylabel('Frequency (Hz)','FontSize',9);
        legend('GFL','GFM+BESS','UFLS 49 Hz','','Location','southeast','FontSize',7.5);
    end
    grid on; box on; set(gca,'FontSize',8.5);

    % ── Row 2: DC Voltage ─────────────────────────────────────────────────
    subplot(3,3,3+k); hold on;
    plot(s1, g.V,'--','Color',C_gfl,'LineWidth',1.9);
    plot(s2, q.V,'-', 'Color',C_gfm,'LineWidth',1.9);
    yline(p.Vdc0,     'k:','LineWidth',1.1);
    yline(p.Vdc0*0.95,'r:','LineWidth',0.9,'Alpha',0.75);  % −5% NC-HVDC limit
    xlim(ta);
    if k==1
        ylabel('V_{DC} at STN-2 (kV)','FontSize',9);
        legend('GFL','GFM+BESS','Nominal','−5% limit','Location','southeast','FontSize',7.5);
    end
    grid on; box on; set(gca,'FontSize',8.5);

    % ── Row 3: BESS power ─────────────────────────────────────────────────
    subplot(3,3,6+k); hold on;
    area(s2, q.Pb,'FaceColor',C_bss,'FaceAlpha',0.25,'EdgeColor',C_bss,'LineWidth',1.8);
    yline(p.Pb_max,'r--','LineWidth',1.3);
    yline(0,'k:','LineWidth',0.8);
    xlim(ta); ylim([-25 235]);
    xlabel('Time after fault (s)','FontSize',9);
    if k==1
        ylabel('P_{BESS} (MW)','FontSize',9);
        legend('GFM+BESS injection','200 MW rating','Location','northeast','FontSize',7.5);
    end
    grid on; box on; set(gca,'FontSize',8.5);
end

sgtitle({'VSC-HVDC Desert Grid — GFL vs GFM-BESS Control: Three Contingency Scenarios';...
         'System: 3-terminal VSC-HVDC, S_{base}=1400 MW, V_{DC}=320 kV, H_{grid}=3 s'},...
         'FontSize',10,'FontWeight','bold');
exportgraphics(fig1,'fig_scenarios_3x3.png','Resolution',300);
fprintf('Saved: fig_scenarios_3x3.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  FIGURE 2 — Frequency Nadir Bar Chart  (Paper: Fig. 4a)
%  ═══════════════════════════════════════════════════════════════════════════
fig2 = figure('Position',[200 100 700 360],'Color','w');
fnd_gfl = arrayfun(@(k) R(k).gfl.fnd, 1:Ns);
fnd_gfm = arrayfun(@(k) R(k).gfm.fnd, 1:Ns);
bw = 0.30;
b1 = bar((1:Ns)-bw/2, fnd_gfl, bw,'FaceColor',C_gfl,'EdgeColor','none');
hold on;
b2 = bar((1:Ns)+bw/2, fnd_gfm, bw,'FaceColor',C_gfm,'EdgeColor','none');
yline(49.0,'k:','LineWidth',1.6,'Label','UFLS threshold (49 Hz)',...
    'LabelHorizontalAlignment','left','FontSize',8.5);
yline(49.5,'k--','LineWidth',1.0,'Label','Warning level (49.5 Hz)',...
    'LabelHorizontalAlignment','left','FontSize',8.5);
for k=1:Ns
    text(k-bw/2, fnd_gfl(k)-0.05, sprintf('%.2f',fnd_gfl(k)),...
        'HorizontalAlignment','center','FontSize',8,'Color','w','FontWeight','bold');
    text(k+bw/2, fnd_gfm(k)-0.05, sprintf('%.2f',fnd_gfm(k)),...
        'HorizontalAlignment','center','FontSize',8,'Color','w','FontWeight','bold');
end
set(gca,'XTick',1:Ns,'XTickLabel',{'A: Load step','B: Wind trip','C: Solar ramp'},...
    'FontSize',9);
ylim([46.3 50.6]);
ylabel('Frequency Nadir (Hz)','FontSize',10);
legend([b1,b2],{'GFL baseline','GFM+BESS'},'Location','southeast','FontSize',9);
title('Frequency Nadir Improvement — Three N-1 Contingency Scenarios',...
    'FontSize',10,'FontWeight','bold');
grid on; box on;
exportgraphics(fig2,'fig_nadir_comparison.png','Resolution',300);
fprintf('Saved: fig_nadir_comparison.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  FIGURE 3 — RoCoF Bar Chart  (Paper: Fig. 4b)
%  ═══════════════════════════════════════════════════════════════════════════
fig3 = figure('Position',[250 150 700 360],'Color','w');
roc_gfl = arrayfun(@(k) abs(R(k).gfl.rocof), 1:Ns);
roc_gfm = arrayfun(@(k) abs(R(k).gfm.rocof), 1:Ns);
b3 = bar((1:Ns)-bw/2, roc_gfl, bw,'FaceColor',C_gfl,'EdgeColor','none');
hold on;
b4 = bar((1:Ns)+bw/2, roc_gfm, bw,'FaceColor',C_gfm,'EdgeColor','none');
yline(2.0,'r--','LineWidth',1.6,'Label','NC-HVDC limit (2 Hz/s)',...
    'LabelHorizontalAlignment','left','FontSize',8.5);
for k=1:Ns
    text(k-bw/2, roc_gfl(k)+0.03, sprintf('%.2f',roc_gfl(k)),...
        'HorizontalAlignment','center','FontSize',8,'Color','k');
    text(k+bw/2, roc_gfm(k)+0.03, sprintf('%.2f',roc_gfm(k)),...
        'HorizontalAlignment','center','FontSize',8,'Color','k');
end
set(gca,'XTick',1:Ns,'XTickLabel',{'A: Load step','B: Wind trip','C: Solar ramp'},...
    'FontSize',9);
ylabel('|RoCoF| (Hz/s)   — 200 ms window','FontSize',10);
legend([b3,b4],{'GFL baseline','GFM+BESS'},'Location','northeast','FontSize',9);
title('Rate of Change of Frequency (RoCoF) — Three Scenarios',...
    'FontSize',10,'FontWeight','bold');
grid on; box on;
exportgraphics(fig3,'fig_rocof_comparison.png','Resolution',300);
fprintf('Saved: fig_rocof_comparison.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  SAVE ALL RESULTS
%  ═══════════════════════════════════════════════════════════════════════════
save('hvdc_results_3sc.mat','R','sc','p');
fprintf('\nAll results saved to hvdc_results_3sc.mat\n');
fprintf('Summary: %d scenarios × 2 modes (GFL/GFM) = %d simulations.\n', Ns, Ns*2);

%% ═══════════════════════════════════════════════════════════════════════════
%  LOCAL FUNCTIONS
%  ═══════════════════════════════════════════════════════════════════════════

function dx = odefun(t, x, p, sc, mode)
% Reduced-order 5-state model of 3-terminal VSC-HVDC with GFM-BESS
%   States: [Δf(Hz), ΔVdc(kV), Pbess(MW), SOC(-), Pgov(MW)]
    df    = x(1);
    dVdc  = x(2);
    Pbess = x(3);
    SOC   = x(4);
    Pgov  = x(5);

    %% Active disturbances (post-fault)
    dPw    = 0;  dPload = 0;  dPpv = 0;
    if t >= p.t_f
        dPw    = sc.dP_wind;
        dPload = sc.dP_load;
        if sc.t_ramp > 0
            alpha = min((t - p.t_f) / sc.t_ramp, 1.0);
            dPpv  = sc.dPpv_end * alpha;   % linear ramp
        else
            dPpv  = sc.dPpv_end;
        end
    end

    %% DC bus energy balance
    P_gen   = (p.Pw0 + dPw) + (p.Ppv0 + dPpv) + Pbess;
    P_load  = (p.Sbase + dPload) + p.k_droop * dVdc;
    P_sur   = P_gen - P_load;
    CVdc    = p.tau_dc * p.Sbase / p.Vdc0;
    dVdc_dt = P_sur / CVdc;

    %% AC frequency — swing equation with governor
    dP_ac = p.k_droop * dVdc;   % HVDC injection change at STN-2
    df_dt = (p.f0 / (2*p.H)) * ((dP_ac + Pgov) / p.Sbase - p.D * df / p.f0);

    %% Primary frequency regulation (governor)
    Pgov_ref = p.K_gov * (-df / p.f0) * p.Sbase;
    dPgov    = (Pgov_ref - Pgov) / p.tau_gov;

    %% BESS control law
    switch mode
        case 'GFL'
            dPb = 0;   % Grid-Following: BESS is passive
        case 'GFM'
            % Virtual Synchronous Machine: droop + virtual inertia
            Pref = p.Df * (-df / p.f0) * p.Sbase ...
                 + 2 * p.H_vsm * (-df_dt / p.f0) * p.Sbase;
            Pref = min(max(Pref, p.Pb_min), p.Pb_max);
            if SOC <= p.SOC_min && Pref > 0, Pref = 0; end   % SoC protection
            if SOC >= p.SOC_max && Pref < 0, Pref = 0; end
            dPb  = (Pref - Pbess) / p.tau_b;
    end

    dSOC = -max(Pbess, 0) / (p.Erated * 3600 * p.eta);
    dx   = [df_dt; dVdc_dt; dPb; dSOC; dPgov];
end


function M = compute_metrics(t, x, p)
% Extract standard power-system stability metrics from ODE output
    M.f   = p.f0   + x(:,1);
    M.V   = p.Vdc0 + x(:,2);
    M.Pb  = x(:,3);
    M.SOC = x(:,4);

    pf = t > p.t_f;

    % Frequency nadir
    [M.fnd, ii] = min(M.f(pf));
    abs_idx     = find(pf,1) - 1 + ii;
    M.tnd       = t(abs_idx) - p.t_f;

    % DC voltage excursion
    M.dVpk = min(M.V(pf)) - p.Vdc0;

    % BESS peak power
    M.Ppk = max(M.Pb);

    % UFLS flag
    M.ufls = any(M.f(pf) < p.f_ufls);

    % RoCoF — 200 ms window starting at fault
    ia = find(t >= p.t_f,       1);
    ib = find(t >= p.t_f + 0.2, 1);
    if ~isempty(ia) && ~isempty(ib) && ib > ia
        M.rocof = (M.f(ib) - M.f(ia)) / (t(ib) - t(ia));
    else
        M.rocof = NaN;
    end

    % Recovery time to 49.5 Hz
    ri = find(t > t(abs_idx) & M.f > 49.5, 1);
    if isempty(ri)
        M.trec = '>10s';
    else
        M.trec = sprintf('%.1fs', t(ri) - p.t_f);
    end
end


function s = yn(v)
    if v, s = 'Yes'; else, s = 'No'; end
end

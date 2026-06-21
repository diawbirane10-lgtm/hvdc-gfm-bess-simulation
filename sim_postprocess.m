%% sim_postprocess.m
% Compare Simulink output vs ODE results
% Run AFTER: build_hvdc_simulink + Ctrl+T in the model

if ~exist('tout','var') || ~exist('df_sim','var')
    error('Run the Simulink model first (Ctrl+T), then re-run this script.');
end

f0=50; Vdc0=320;
t  = tout;
f  = f0 + df_sim;
V  = Vdc0 + dVdc_sim;
Pb = Pbess_sim;
t_f=0.1;

pf = t > t_f;
[fnd, i] = min(f(pf)); tnd = t(find(pf,1)-1+i) - t_f;
dVpk = min(V(pf)) - Vdc0;
Ppk  = max(Pb);
dt=0.2; ia=find(t>=t_f,1); ib=find(t>=t_f+dt,1);
rocof = (f(ib)-f(ia))/(t(ib)-t(ia));
ufls = any(f(pf)<49);
ri=find(t>t(find(pf,1)-1+i) & f>49.5,1);
if isempty(ri), trec='>10s'; else, trec=sprintf('%.1fs',t(ri)-t_f); end

fprintf('=== Simulink Results ===\n');
fprintf('Freq nadir   : %.2f Hz (at t=%.2fs)\n', fnd, tnd);
fprintf('UFLS         : %s\n', yn(ufls));
fprintf('RoCoF        : %.2f Hz/s\n', rocof);
fprintf('ΔVdc peak    : %.1f kV\n', dVpk);
fprintf('BESS peak    : %.1f MW\n', Ppk);
fprintf('Recovery     : %s\n', trec);

figure('Name','Simulink vs ODE Comparison','Position',[100 100 900 600]);

subplot(3,1,1); hold on;
plot(t-t_f, f, 'b-', 'LineWidth',1.8);
yline(49,'k:'); yline(49.5,'k--','Alpha',0.5);
xlim([-0.2 9.8]); ylabel('Freq (Hz)'); grid on;
title('Simulink model output');
legend('Frequency','UFLS 49Hz');

subplot(3,1,2); hold on;
plot(t-t_f, V, 'r-', 'LineWidth',1.8);
yline(Vdc0,'k:');
xlim([-0.2 9.8]); ylabel('Vdc STN-2 (kV)'); grid on;

subplot(3,1,3); hold on;
plot(t-t_f, Pb, 'g-', 'LineWidth',1.8);
yline(200,'r--');
xlim([-0.2 9.8]); ylabel('BESS (MW)'); xlabel('Time (s)'); grid on;

exportgraphics(gcf,'fig_simulink_results.png','Resolution',200);
fprintf('Figure saved: fig_simulink_results.png\n');

function s=yn(v), if v, s='Yes'; else, s='No'; end, end

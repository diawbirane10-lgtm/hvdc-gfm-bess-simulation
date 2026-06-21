%% hvdc_gfm_bess_sim.m  —  3-terminal VSC-HVDC | GFM-BESS vs GFL
% States: [Δf(Hz), ΔVdc(kV), P_bess(MW), SOC, P_gov(MW)]
% P_gov = primary frequency regulation (governor) of the AC grid at STN-3
clear; clc; close all;

%% Parameters
p.f0=50; p.Vdc0=320; p.Sbase=1400;
p.H=3.0;        % s  (inertia — lower → faster RoCoF, matches ~2.3 Hz/s)
p.D=1.5;        % pu (load damping only)
p.K_gov=15;     % pu (governor gain = 1/R, R = 6.7% droop)
p.tau_gov=8;    % s  (steam turbine governor time constant)
p.tau_dc=0.08; p.k_droop=30;
p.H_vsm=6.0; p.Df=20.0; p.tau_b=0.025;
p.Pb_max=200; p.Erated=200; p.eta=0.95;
p.SOC_min=0.2; p.SOC_max=0.9;
p.Pw0=800; p.Ppv=600;
p.t_f=0.1; p.dP=400;
p.f_ufls=49.0;

%% Simulation
tspan=[0,10]; x0=[0;0;0;0.60;0];   % 5 states, longer horizon for recovery
opts=odeset('RelTol',1e-7,'AbsTol',1e-9,'MaxStep',2e-4);

fprintf('GFL...\n');
[t1,x1]=ode23tb(@(t,x) odefun(t,x,p,'GFL'),tspan,x0,opts);
fprintf('GFM-BESS...\n');
[t2,x2]=ode23tb(@(t,x) odefun(t,x,p,'GFM'),tspan,x0,opts);
fprintf('Done.\n\n');

%% Post-processing
f1=p.f0+x1(:,1); f2=p.f0+x2(:,1);
V1=p.Vdc0+x1(:,2); V2=p.Vdc0+x2(:,2);
Pb=x2(:,3); SOC=x2(:,4);

pf1=t1>p.t_f; pf2=t2>p.t_f;
[nd1,i1]=min(f1(pf1)); tnd1=t1(find(pf1,1)-1+i1)-p.t_f;
[nd2,i2]=min(f2(pf2)); tnd2=t2(find(pf2,1)-1+i2)-p.t_f;

dt=0.2;
ia=find(t1>=p.t_f,1); ib=find(t1>=p.t_f+dt,1);
roc1=(f1(ib)-f1(ia))/(t1(ib)-t1(ia));
ia=find(t2>=p.t_f,1); ib=find(t2>=p.t_f+dt,1);
roc2=(f2(ib)-f2(ia))/(t2(ib)-t2(ia));

dV1=min(V1(pf1))-p.Vdc0; dV2=min(V2(pf2))-p.Vdc0;
u1=any(f1(pf1)<p.f_ufls); u2=any(f2(pf2)<p.f_ufls);
Ppk=max(Pb);

% Recovery: first time freq crosses 49.5 Hz on the way UP after nadir
[~,ind_nd1]=min(f1(pf1)); abs_nd1=find(pf1,1)-1+ind_nd1;
ri=find(t1>t1(abs_nd1) & f1>49.5,1);
if isempty(ri), tr1='>10s'; else, tr1=sprintf('%.1fs',t1(ri)-p.t_f); end
[~,ind_nd2]=min(f2(pf2)); abs_nd2=find(pf2,1)-1+ind_nd2;
ri=find(t2>t2(abs_nd2) & f2>49.5,1);
if isempty(ri), tr2='>10s'; else, tr2=sprintf('%.1fs',t2(ri)-p.t_f); end

%% Table 2
fprintf('%-28s %10s %10s\n','Indicator','GFL','GFM-BESS');
fprintf('%s\n',repmat('-',1,50));
fprintf('%-28s %10.2f %10.2f\n','Freq nadir (Hz)',nd1,nd2);
fprintf('%-28s %10s %10s\n','UFLS',yn(u1),yn(u2));
fprintf('%-28s %10.2f %10.2f\n','Nadir time (s)',tnd1,tnd2);
fprintf('%-28s %10.2f %10.2f\n','RoCoF (Hz/s)',roc1,roc2);
fprintf('%-28s %10.1f %10.1f\n','ΔVdc peak (kV)',dV1,dV2);
fprintf('%-28s %10s %10.1f\n','BESS peak (MW)','—',Ppk);
fprintf('%-28s %10s %10s\n','Recovery',tr1,tr2);

%% Figures  (time axis shifted to t=0 at fault)
s1=t1-p.t_f; s2=t2-p.t_f; xlm=[-0.2 9.8];

figure(1); set(gcf,'Position',[50 80 680 370]);
plot(s1,f1,'b--','LineWidth',1.8); hold on;
plot(s2,f2,'r-','LineWidth',1.8);
yline(49,'k:','LineWidth',1.2); yline(49.5,'k--','LineWidth',0.8,'Alpha',0.5);
plot(tnd1,nd1,'bv','MarkerSize',8,'MarkerFaceColor','b');
plot(tnd2,nd2,'r^','MarkerSize',8,'MarkerFaceColor','r');
text(tnd1+0.1,nd1-0.1,sprintf('%.2f Hz',nd1),'Color','b','FontSize',9);
text(tnd2+0.1,nd2+0.06,sprintf('%.2f Hz',nd2),'Color','r','FontSize',9);
xlim(xlm); ylim([47.5 50.2]);
xlabel('Time (s)'); ylabel('Frequency (Hz)');
legend('GFL baseline','GFM + BESS','UFLS (49 Hz)','49.5 Hz warning','Location','southeast');
grid on; box on; title('Frequency response — 400 MW generation-loss event');
exportgraphics(gcf,'fig_frequency_response.png','Resolution',200);

figure(2); set(gcf,'Position',[50 500 680 320]);
plot(s1,V1,'b--','LineWidth',1.8); hold on;
plot(s2,V2,'r-','LineWidth',1.8);
yline(p.Vdc0,'k:','LineWidth',1);
xlim(xlm);
xlabel('Time (s)'); ylabel('DC voltage STN-2 (kV)');
legend('GFL','GFM+BESS','Nominal 320 kV','Location','southeast');
grid on; box on; title('DC-bus voltage response');
exportgraphics(gcf,'fig_dc_voltage.png','Resolution',200);

figure(3); set(gcf,'Position',[750 80 680 320]);
plot(s2,Pb,'b-','LineWidth',1.8); hold on;
yline(p.Pb_max,'r--','LineWidth',1.3);
xlim(xlm); ylim([-5 220]);
xlabel('Time (s)'); ylabel('Power (MW)');
legend('BESS injection','200 MW rating','Location','northeast');
grid on; box on; title('BESS active-power injection');
exportgraphics(gcf,'fig_bess_power.png','Resolution',200);

figure(4); set(gcf,'Position',[750 450 680 280]);
plot(s2,SOC*100,'g-','LineWidth',1.6);
yline(p.SOC_min*100,'r:'); yline(p.SOC_max*100,'r:');
xlim(xlm); ylim([18 95]);
xlabel('Time (s)'); ylabel('SOC (%)');
grid on; box on; title('BESS State of Charge');
exportgraphics(gcf,'fig_soc.png','Resolution',200);

results.t1=s1; results.f_gfl=f1; results.Vdc_gfl=V1;
results.t2=s2; results.f_gfm=f2; results.Vdc_gfm=V2;
results.Pb=Pb; results.SOC=SOC;
save('hvdc_results.mat','-struct','results');
fprintf('\nFigures + hvdc_results.mat saved.\n');

%% ODE
function dx=odefun(t,x,p,mode)
    df=x(1); dVdc=x(2); Pbess=x(3); SOC=x(4); Pgov=x(5);

    dPw=0; if t>=p.t_f, dPw=-p.dP; end

    % DC bus
    P_stn3=p.Sbase+p.k_droop*dVdc;
    P_sur=(p.Pw0+dPw)+p.Ppv+Pbess-P_stn3;
    CVdc=p.tau_dc*p.Sbase/p.Vdc0;
    dVdc_dt=P_sur/CVdc;

    % AC frequency (swing + governor contribution)
    dP_ac=p.k_droop*dVdc;   % HVDC injection change [MW]
    df_dt=(p.f0/(2*p.H))*((dP_ac+Pgov)/p.Sbase - p.D*df/p.f0);

    % Primary frequency regulation (governor)
    Pgov_ref=p.K_gov*(-df/p.f0)*p.Sbase;
    dPgov=(Pgov_ref-Pgov)/p.tau_gov;

    % BESS
    switch mode
        case 'GFL'
            dPb=0;
        case 'GFM'
            Pref=p.Df*(-df/p.f0)*p.Sbase + 2*p.H_vsm*(-df_dt/p.f0)*p.Sbase;
            Pref=min(max(Pref,-50),p.Pb_max);
            if SOC<=p.SOC_min && Pref>0, Pref=0; end
            if SOC>=p.SOC_max && Pref<0, Pref=0; end
            dPb=(Pref-Pbess)/p.tau_b;
    end

    dSOC=-max(Pbess,0)/(p.Erated*3600);
    dx=[df_dt;dVdc_dt;dPb;dSOC;dPgov];
end

function s=yn(v), if v, s='Yes'; else, s='No'; end, end

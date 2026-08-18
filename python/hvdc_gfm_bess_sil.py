"""JURI revision support for the 3-terminal VSC-HVDC GFM-BESS study.

Reproduces the reduced-order MATLAB equations in Python/SciPy, runs the three
paper contingencies for GFL and GFM+BESS, and performs an independent fixed-step
RK4 software-in-the-loop (SIL) cross-validation against an adaptive BDF solver.

The automatic loop refines only the numerical RK4 step until solver-consistency
criteria are met. It does NOT tune controller parameters to force a desired
frequency-stability conclusion.
"""
from pathlib import Path
import json
import argparse
import numpy as np
import pandas as pd
from scipy.integrate import solve_ivp

P = {
    "f0":50.0,"Vdc0":320.0,"Sbase":1400.0,"Pload0":1400.0,
    "H":3.0,"D":1.5,"K_gov":15.0,"tau_gov":8.0,
    "tau_dc":0.08,"k_droop":30.0,"H_vsm":6.0,"Df":20.0,"tau_b":0.025,
    "Pb_max":200.0,"Pb_min":-50.0,"Erated":200.0,"eta":0.95,
    "SOC_min":0.20,"SOC_max":0.90,"Pw0":800.0,"Ppv0":600.0,
    "t_f":0.1,"f_screen":49.0,
}
SCENARIOS = [
    {"label":"A","title":"Load step +20% (280 MW)","dP_wind":0.0,"dP_load":280.0,"dPpv_end":0.0,"t_ramp":0.0},
    {"label":"B","title":"Wind trip N-1 (400 MW)","dP_wind":-400.0,"dP_load":0.0,"dPpv_end":0.0,"t_ramp":0.0},
    {"label":"C","title":"Solar ramp -50% (300 MW / 100 ms)","dP_wind":0.0,"dP_load":0.0,"dPpv_end":-300.0,"t_ramp":0.1},
]

def rhs(t,x,sc,mode,p):
    df,dVdc,Pbess,SOC,Pgov=x
    dPw=dPload=dPpv=0.0
    if t>=p["t_f"]:
        dPw=sc["dP_wind"]; dPload=sc["dP_load"]
        if sc["t_ramp"]>0:
            dPpv=sc["dPpv_end"]*min((t-p["t_f"])/sc["t_ramp"],1.0)
        else:
            dPpv=sc["dPpv_end"]
    Pgen=(p["Pw0"]+dPw)+(p["Ppv0"]+dPpv)+Pbess
    Pload=(p["Pload0"]+dPload)+p["k_droop"]*dVdc
    dVdc_dt=(Pgen-Pload)/(p["tau_dc"]*p["Sbase"]/p["Vdc0"])
    dPac=p["k_droop"]*dVdc
    df_dt=(p["f0"]/(2*p["H"]))*((dPac+Pgov)/p["Sbase"]-p["D"]*df/p["f0"])
    Pgov_ref=p["K_gov"]*(-df/p["f0"])*p["Sbase"]
    dPgov=(Pgov_ref-Pgov)/p["tau_gov"]
    if mode=="GFL":
        dPb=0.0
    else:
        Pref=p["Df"]*(-df/p["f0"])*p["Sbase"] + 2*p["H_vsm"]*(-df_dt/p["f0"])*p["Sbase"]
        Pref=float(np.clip(Pref,p["Pb_min"],p["Pb_max"]))
        if SOC<=p["SOC_min"] and Pref>0: Pref=0.0
        if SOC>=p["SOC_max"] and Pref<0: Pref=0.0
        dPb=(Pref-Pbess)/p["tau_b"]
    dSOC=-max(Pbess,0.0)/(p["Erated"]*3600.0*p["eta"])
    return np.array([df_dt,dVdc_dt,dPb,dSOC,dPgov],float)

def solve_bdf(sc,mode,p=P):
    sol=solve_ivp(lambda t,x:rhs(t,x,sc,mode,p),(0,10),[0,0,0,0.60,0],
                  method="BDF",rtol=1e-7,atol=1e-9,max_step=1e-3,dense_output=True)
    if not sol.success: raise RuntimeError(sol.message)
    t=np.arange(0,10.0000001,2e-4)
    return t,sol.sol(t).T

def solve_rk4(sc,mode,p=P,dt=2e-4):
    n=int(round(10/dt))+1
    t=np.linspace(0,10,n); x=np.zeros((n,5)); x[0]=[0,0,0,0.60,0]
    for i in range(n-1):
        ti=t[i]; xi=x[i]
        k1=rhs(ti,xi,sc,mode,p)
        k2=rhs(ti+dt/2,xi+dt*k1/2,sc,mode,p)
        k3=rhs(ti+dt/2,xi+dt*k2/2,sc,mode,p)
        k4=rhs(ti+dt,xi+dt*k3,sc,mode,p)
        x[i+1]=xi+dt*(k1+2*k2+2*k3+k4)/6
    return t,x

def metrics(t,x,p=P):
    f=p["f0"]+x[:,0]; V=p["Vdc0"]+x[:,1]; Pb=x[:,2]; SOC=x[:,3]
    pf=t>p["t_f"]; ids=np.flatnonzero(pf); i=ids[np.argmin(f[pf])]
    ia=np.searchsorted(t,p["t_f"]); ib=np.searchsorted(t,p["t_f"]+0.2)
    rec=np.flatnonzero((t>t[i])&(f>49.5))
    nd=(t>=p["t_f"])&(t<=t[i]); ev=t>=p["t_f"]
    sat=np.flatnonzero((t>=p["t_f"])&(Pb>=0.99*p["Pb_max"]))
    return {
        "nadir_Hz":f[i],"nadir_time_s":t[i]-p["t_f"],
        "RoCoF_200ms_Hz_s":(f[ib]-f[ia])/(t[ib]-t[ia]),
        "dVdc_peak_kV":V[pf].min()-p["Vdc0"],
        "dVdc_peak_pct":100*(V[pf].min()-p["Vdc0"])/p["Vdc0"],
        "BESS_peak_MW":Pb.max(),"threshold_49Hz_crossed":bool(np.any(f[pf]<p["f_screen"])),
        "recovery_49p5_s":np.nan if len(rec)==0 else t[rec[0]]-p["t_f"],
        "BESS_P_at_200ms_MW":Pb[ib],
        "BESS_time_to_99pct_s":np.nan if len(sat)==0 else t[sat[0]]-p["t_f"],
        "BESS_energy_to_nadir_MWh":np.trapezoid(np.maximum(Pb[nd],0),t[nd])/3600,
        "BESS_energy_10s_MWh":np.trapezoid(np.maximum(Pb[ev],0),t[ev])/3600,
        "SOC_drop_percentage_points":(SOC[ia]-SOC[-1])*100,
        "BESS_saturation_duration_s":np.trapezoid(((t>=p["t_f"])&(Pb>=0.99*p["Pb_max"])).astype(float),t),
    }

def run(outdir="results_python"):
    out=Path(outdir); out.mkdir(parents=True,exist_ok=True)
    ref={}
    for sc in SCENARIOS:
        for mode in ("GFL","GFM"):
            t,x=solve_bdf(sc,mode); ref[(sc["label"],mode)]=(t,x,metrics(t,x))

    loop=[]; selected=None
    for dt in [1e-3,5e-4,2e-4,1e-4]:
        wn=wr=wv=0.0
        for sc in SCENARIOS:
            for mode in ("GFL","GFM"):
                t,x=solve_rk4(sc,mode,dt=dt); mr=metrics(t,x); mb=ref[(sc["label"],mode)][2]
                wn=max(wn,abs(mb["nadir_Hz"]-mr["nadir_Hz"]))
                wr=max(wr,abs(abs(mb["RoCoF_200ms_Hz_s"])-abs(mr["RoCoF_200ms_Hz_s"])))
                wv=max(wv,abs(mb["dVdc_peak_kV"]-mr["dVdc_peak_kV"]))
        loop.append({"dt_s":dt,"max_nadir_error_Hz":wn,"max_RoCoF_error_Hz_s":wr,"max_dVdc_error_kV":wv})
        if wn<=1e-4 and wr<=5e-4 and wv<=1e-3:
            selected=dt; break
    if selected is None: raise RuntimeError("Cross-solver tolerance not reached")

    perf=[]; bess=[]; cv=[]
    for sc in SCENARIOS:
        g=ref[(sc["label"],"GFL")][2]; q=ref[(sc["label"],"GFM")][2]
        for mode,m in (("GFL",g),("GFM+BESS",q)):
            perf.append({"Scenario":sc["label"],"Mode":mode,**{k:v for k,v in m.items() if not k.startswith("BESS_") and not k.startswith("SOC_")}})
        bess.append({"Scenario":sc["label"],"Nadir_improvement_Hz":q["nadir_Hz"]-g["nadir_Hz"],
                     **{k:v for k,v in q.items() if k.startswith("BESS_") or k.startswith("SOC_")}})
        for mode in ("GFL","GFM"):
            tr,xr=solve_rk4(sc,mode,dt=selected); mr=metrics(tr,xr); mb=ref[(sc["label"],mode)][2]
            cv.append({"Scenario":sc["label"],"Mode":mode,"RK4_dt_s":selected,
                       "BDF_nadir_Hz":mb["nadir_Hz"],"RK4_nadir_Hz":mr["nadir_Hz"],
                       "abs_error_nadir_Hz":abs(mb["nadir_Hz"]-mr["nadir_Hz"]),
                       "BDF_abs_RoCoF_Hz_s":abs(mb["RoCoF_200ms_Hz_s"]),"RK4_abs_RoCoF_Hz_s":abs(mr["RoCoF_200ms_Hz_s"]),
                       "abs_error_RoCoF_Hz_s":abs(abs(mb["RoCoF_200ms_Hz_s"])-abs(mr["RoCoF_200ms_Hz_s"])),
                       "BDF_dVdc_peak_kV":mb["dVdc_peak_kV"],"RK4_dVdc_peak_kV":mr["dVdc_peak_kV"],
                       "abs_error_dVdc_kV":abs(mb["dVdc_peak_kV"]-mr["dVdc_peak_kV"])})

    pd.DataFrame(loop).to_csv(out/"solver_convergence_loop.csv",index=False)
    pd.DataFrame(cv).to_csv(out/"solver_cross_validation.csv",index=False)
    pd.DataFrame(perf).to_csv(out/"performance_metrics.csv",index=False)
    pd.DataFrame(bess).to_csv(out/"bess_energy_metrics.csv",index=False)
    summary={"selected_RK4_dt_s":selected,"note":"Step refinement is numerical only; no controller tuning is performed."}
    (out/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
    print(pd.DataFrame(perf).to_string(index=False))
    print("\nBESS energy/saturation metrics\n",pd.DataFrame(bess).to_string(index=False))
    print("\nSelected RK4 dt:",selected,"s")

if __name__=="__main__":
    parser = argparse.ArgumentParser(description="Independent SIL cross-verification for the JURI VSC-HVDC GFM-BESS study.")
    parser.add_argument("--out", default="results_python", help="Output directory for CSV/JSON results.")
    args = parser.parse_args()
    run(args.out)

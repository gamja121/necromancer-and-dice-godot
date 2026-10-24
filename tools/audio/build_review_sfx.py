"""Build distinct, deterministic game SFX; no external samples or services.
Run with a Python environment containing NumPy. Runtime uses only exported WAVs.
"""
from pathlib import Path
import hashlib, math, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/audio/sfx'
SR=24000
LENGTHS={'card_use':.22,'book_confirm':.085,'reward_gain':.55,'capture_success':.85,'recovery':.8,'cleanse':.7,'battle_heal':.5,'shop_trade':.35,'prayer_bless':.7,'prayer_fail':.5,'prophecy_bless':.85,'prophecy_curse':.8,'ritual_complete':1.1,'inheritance_complete':1.45,'final_clear':1.5,'dragon_intro':1.7,'dragon_roar':1.8,'dragon_attack':.65,'dragon_impact':.6,'dragon_hit':.55,'dragon_critical':.7,'dragon_death':2.3,'swamp_hit':.5}

def build(name,duration):
    seed=int.from_bytes(hashlib.sha256(name.encode()).digest()[:8],'little')
    rng=np.random.default_rng(seed)
    t=np.arange(round(duration*SR))/SR
    n=len(t)
    def noise(lo,hi):
        data=rng.normal(size=n)
        f=np.fft.rfftfreq(n,1/SR)
        width=max(12.,(hi-lo)*.06)
        mask=np.clip((f-lo)/width,0,1)*np.clip((hi-f)/width,0,1)
        result=np.fft.irfft(np.fft.rfft(data)*mask,n=n)
        return result/(np.sqrt(np.mean(result*result))+1e-9)
    def env(start,length,attack=.008,decay=2.):
        u=np.clip((t-start)/max(length,.001),0,1)
        return ((t>=start)&(t<start+length))*np.minimum(1.,np.maximum(0,t-start)/attack)*(1-u)**decay
    def bell(start,length,freq,amp=1.,partials=(1.,2.73,4.19)):
        phase=2*np.pi*freq*(t-start)
        y=sum(np.sin(phase*p+rng.uniform(-.15,.15))*(.5**i)*np.exp(-np.maximum(t-start,0)*(4+9*i)/length) for i,p in enumerate(partials))
        return amp*y*env(start,length,.003,.6)
    def thump(start,length,freq=100,amp=1.):
        u=np.maximum(0,t-start)
        phase=2*np.pi*(freq*u+(freq*.7/18)*(1-np.exp(-18*u)))
        return amp*(np.sin(phase)+.16*noise(140,1700))*env(start,length,.002,3.1)
    def breath(start,length,lo=600,hi=4300,amp=1.,decay=1.):
        return amp*noise(lo,hi)*env(start,length,.025,decay)
    def voice(start,length,f0,fall,amp=1.):
        u=np.clip((t-start)/length,0,1)
        irregular=noise(.2,13)
        hz=np.maximum(28.,f0+fall*u)*(1+.035*irregular)
        phase=2*np.pi*np.cumsum(hz)/SR
        harmonics=sum(np.sin(k*phase+.07*irregular)/(k**1.3) for k in range(1,14))
        rasp=noise(270,2100)*(.5+.5*np.clip(irregular*.25+.5,0,1))
        return amp*(.7*np.tanh(1.7*harmonics)+.35*rasp)*env(start,length,.06,1.2)
    def crack(start,amp=1.):
        return amp*(noise(1000,7200)*env(start,.09,.001,4)+bell(start,.12,1630,.13,(1,1.87,3.14)))
    def bubbles(start,length,amp=1.):
        result=np.zeros(n)
        for when in start+np.sort(rng.uniform(0,max(.01,length-.06),6)):
            freq=rng.uniform(170,460)
            u=np.maximum(0,t-when)
            phase=2*np.pi*(freq*u-freq*.65*(u-(1-np.exp(-30*u))/30))
            result+=amp*rng.uniform(.3,1.)*np.sin(phase)*env(when,.075,.003,2.8)
        return result
    y=np.zeros(n)
    if name=='card_use':
        y=.19*breath(0,.18,1000,6500)+.1*bell(.13,.08,360,1.,(1,2.61))
    elif name=='book_confirm':
        y=.22*noise(1100,5400)*env(0,.07,.002,3)+.09*thump(.008,.07,95)
    elif name=='reward_gain':
        y=.09*breath(0,.07,1200,5000)+bell(.04,.27,650,.24)+bell(.18,.32,1090,.16)
    elif name=='capture_success':
        u=t/duration; phase=2*np.pi*(110*t+245*t*t/duration)
        y=.12*noise(350,2800)*np.sin(np.pi*u)**2*(1-u)+.24*np.sin(phase)*env(.03,.68,.19,.8)+bell(.62,.22,470,.1,(1,1.53,2.08))
    elif name in ('recovery','battle_heal'):
        length=duration; amplitude=np.sin(np.pi*np.clip(t/length,0,1))**1.5
        y=(.19*np.sin(2*np.pi*212*t)+.08*np.sin(2*np.pi*343*t)+.04*noise(230,1700))*amplitude
        if name=='battle_heal': y+=bell(.04,.28,438,.06,(1,1.91))
    elif name=='cleanse':
        y=breath(0,.64,1500,6200,.2,.9)+.05*noise(600,1400)*env(.03,.25,.02,1.4)
    elif name=='shop_trade':
        y=.12*breath(0,.22,1400,5600)+.13*thump(.035,.15,270)+.08*bell(.2,.13,680,1.,(1,2.47))
    elif name=='prayer_bless':
        y=bell(.01,.68,220,.23,(1,2.55,4.33))+.035*breath(.08,.6,240,1350)
    elif name=='prayer_fail':
        y=thump(.01,.21,83,.2)+thump(.19,.27,65,.13)+breath(.04,.4,440,1800,.07)
    elif name=='prophecy_bless':
        for start,freq,gain in [(0.025,666,.18),(.135,1041,.12),(.275,1550,.08)]: y+=bell(start,.55,freq,gain,(1,1.971,3.113))
        y+=noise(700,2600)*np.clip(t/.18,0,1)*np.clip((.23-t)/.05,0,1)*.035
    elif name=='prophecy_curse':
        y=breath(0,.72,600,2500,.10,.8)+bell(.02,.34,306,.13,(1,1.43,2.17))+bell(.25,.33,188,.14,(1,1.61))+bell(.49,.28,126,.13,(1,1.37))
    elif name=='ritual_complete':
        for start,freq,amp in [(0,88,.2),(.2,139,.17),(.43,220,.15)]: y+=thump(start,.3,freq,amp)
        y+=bell(.53,.56,330,.11,(1,1.51,2.02))+breath(.4,.6,300,1800,.045)
    elif name=='inheritance_complete':
        u=t/duration
        y=.11*noise(750,4100)*np.sin(np.pi*u)**2
        for start in [.08,.21,.42,.71,.9]: y+=crack(start,.025)
        phase=2*np.pi*(130*t+80*t*t)
        y+=.12*np.sin(phase)*env(.1,1.04,.18,.7)+bell(1.03,.39,411,.1,(1,1.51,2.11))
    elif name=='final_clear':
        y=bell(.10,1.35,110,.24,(1,2.01,3.02))+bell(.43,1.03,165.5,.17,(1,2.13,3.1))+breath(.03,1.3,200,1600,.035,.65)
    elif name=='dragon_intro':
        y=.21*noise(28,185)*np.sin(np.pi*t/duration)**.8
        y+=breath(.16,.6,180,2200,.10,.5)+breath(.93,.7,230,3100,.14,.65)
        y+=thump(.36,.38,45,.1)+thump(1.11,.45,38,.11)
    elif name=='dragon_roar':
        y=breath(0,.3,600,3500,.13,.8)+voice(.11,1.55,79,-29,.43)+breath(.2,1.55,500,4200,.22,.75)
        y+=.06*noise(30,150)*env(.15,1.5,.12,.7)
    elif name=='dragon_attack':
        y=breath(0,.19,500,2100,.13,.7)+breath(.12,.47,700,5300,.25,.6)+voice(.1,.48,97,-40,.17)
    elif name=='dragon_impact':
        y=thump(0,.5,43,.36)+crack(.015,.11)+crack(.065,.06)+breath(.06,.42,220,2400,.10,1.5)
    elif name in ('dragon_hit','dragon_critical'):
        critical=name=='dragon_critical'
        y=thump(0,.29,61,.26)+crack(.007,.14 if critical else .08)+voice(.025,duration-.045,130 if critical else 99,-57 if critical else -43,.25)
        if critical: y+=crack(.055,.1)+crack(.16,.055)+breath(.09,.5,1100,5700,.11,1.2)
    elif name=='dragon_death':
        y=voice(.01,.66,73,-36,.22)+breath(.15,2.08,200,2700,.09,.55)
        for start,amp in [(.04,.12),(.17,.1),(.32,.08),(.56,.09),(.81,.055),(1.2,.04),(1.63,.025)]: y+=crack(start,amp)+thump(start,.19,55,.07)
        y+=bubbles(.19,1.55,.075)+.06*noise(28,180)*env(.1,1.9,.1,2.2)
    elif name=='swamp_hit':
        y=bubbles(0,.43,.23)+breath(.015,.4,170,2300,.12,1.7)+thump(.005,.23,68,.12)
    else: raise ValueError(name)
    y-=np.mean(y)
    fade_in=np.minimum(1.,t/.004)
    fade_out=np.minimum(1.,np.maximum(0,duration-t)/.025)
    y=np.tanh(y*1.35)*fade_in*fade_out
    y*=.76/(np.max(np.abs(y))+1e-12)
    y[0]=0.;y[-1]=0.
    pcm=np.rint(y*32767).astype('<i2')
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
    return y

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    result={name:build(name,duration) for name,duration in LENGTHS.items()}
    for a,b in [('cleanse','prayer_bless'),('capture_success','prophecy_bless')]:
        print('CORRELATION',a,b,round(float(np.corrcoef(result[a],result[b])[0,1]),5))
    roar=result['dragon_roar'];power=np.abs(np.fft.rfft(roar))**2;freq=np.fft.rfftfreq(len(roar),1/SR)
    print('ROAR_ABOVE_1KHZ_PERCENT',round(100*float(power[freq>1000].sum()/power.sum()),2))
    print('REBUILT',len(result),'peak',max(float(np.max(np.abs(x))) for x in result.values()))
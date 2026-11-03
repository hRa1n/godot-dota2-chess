"""程序合成游戏音效：短、轻、无外部素材。输出 22050Hz 16bit 单声道 wav。"""
import numpy as np, wave, sys, os
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(7)

def t(d): return np.linspace(0, d, int(SR*d), endpoint=False)
def env(n, a=0.005, r=None, curve=3.0):
    x = np.ones(n); ai = max(1, int(SR*a)); x[:ai] = np.linspace(0, 1, ai)
    tail = np.linspace(1, 0, n-ai) ** curve; x[ai:] = tail; return x
def noise(d): return rng.uniform(-1, 1, int(SR*d))
def lowpass(x, k):   # 简单一阶低通，k 越小越闷
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x): acc += k*(v-acc); y[i] = acc
    return y
def highpass(x, k): return x - lowpass(x, k)
def sweep(f0, f1, d, wave_='sin'):
    tt = t(d); f = np.geomspace(f0, f1, len(tt)); ph = 2*np.pi*np.cumsum(f)/SR
    return np.sin(ph) if wave_ == 'sin' else np.sign(np.sin(ph))*0.6
def tone(f, d, harm=(1,), decay=3.0):
    tt = t(d); s = sum(np.sin(2*np.pi*f*h*tt)/(i+1) for i, h in enumerate(harm)); return s*env(len(tt), r=d, curve=decay)
def mix(*xs):
    n = max(len(x) for x in xs); y = np.zeros(n)
    for x in xs: y[:len(x)] += x
    return y
def at(x, sec): return np.concatenate([np.zeros(int(SR*sec)), x])
def save(name, x, gain=0.6):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), 200); x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name + '.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype(np.int16).tobytes())

# 普通攻击：短促的挥砍（带通噪声 + 下滑）
d=0.16; save('hit', mix(highpass(noise(d),0.25)*env(int(SR*d),curve=4)*0.8, sweep(900,200,d)*env(int(SR*d),curve=5)*0.4), 0.5)
# 受伤：闷的撞击
d=0.18; save('hurt', mix(lowpass(noise(d),0.08)*env(int(SR*d),curve=3), sweep(220,70,d)*env(int(SR*d),curve=4)*0.8), 0.55)
# 闪电：噼啪电流
d=0.45; crack = noise(d)*(rng.uniform(0,1,int(SR*d))>0.82)*env(int(SR*d),curve=1.5)
save('zap', mix(highpass(crack,0.4), sweep(2400,300,d,'sq')*env(int(SR*d),curve=3)*0.25), 0.5)
# 雷鸣：电流 + 低频轰隆
d=0.9; save('thunder', mix(highpass(noise(0.25),0.5)*env(int(SR*0.25),curve=2), lowpass(noise(d),0.02)*env(int(SR*d),a=0.03,curve=1.6)*1.4), 0.6)
# 冰：高频叮 + 碎冰
d=0.6; save('ice', mix(tone(1760,d,(1,2.7,5.1),4)*0.6, tone(2637,d*0.7,(1,),5)*0.3, highpass(noise(0.12),0.6)*env(int(SR*0.12),curve=3)*0.5), 0.45)
# 暴风雪：长的风声
d=1.0; w=lowpass(noise(d),0.06); lfo=0.6+0.4*np.sin(2*np.pi*3*t(d)); save('blizzard', w*lfo*env(int(SR*d),a=0.15,curve=1.2), 0.5)
# 旋风：快速循环的呼呼声
d=0.6; w=highpass(lowpass(noise(d),0.3),0.05); lfo=0.5+0.5*np.sin(2*np.pi*14*t(d)); save('spin', w*lfo*env(int(SR*d),a=0.05,curve=1.5), 0.5)
# 魔法飞弹：上扬的嗖 + 低沉余韵
d=0.4; save('magic', mix(sweep(300,1400,d)*env(int(SR*d),a=0.02,curve=2)*0.6, lowpass(noise(d),0.1)*env(int(SR*d),curve=2)*0.5), 0.5)
# 传送：反向扫频
d=0.4; save('warp', mix(sweep(1600,200,d)*env(int(SR*d),a=0.02,curve=1.5)*0.5, sweep(200,1600,d)*env(int(SR*d),a=0.02,curve=1.5)*0.3), 0.45)
# 治疗：上行琶音
save('heal', mix(*[at(tone(f,0.35,(1,2),3)*0.5, i*0.07) for i,f in enumerate([659,784,988,1319])]), 0.4)
# 怒吼：低频锯齿 + 噪声
d=0.5; tt=t(d); saw=2*((tt*110)%1)-1; save('roar', mix(lowpass(saw,0.2)*env(int(SR*d),a=0.03,curve=1.5), lowpass(noise(d),0.08)*env(int(SR*d),curve=2)*0.6), 0.55)
# 斩杀：重击 + 金属
d=0.5; save('cull', mix(lowpass(noise(0.2),0.1)*env(int(SR*0.2),curve=3)*1.2, tone(180,d,(1,1.5),3), tone(1200,0.3,(1,2.3),6)*0.4), 0.6)
# 肉钩：铁链哗啦 + 拉回
d=0.5; chain = mix(*[at(highpass(noise(0.03),0.5)*env(int(SR*0.03),curve=2), i*0.04) for i in range(10)])
save('hook', mix(chain*0.7, at(sweep(500,150,0.2)*env(int(SR*0.2),curve=2)*0.5, 0.3)), 0.5)
# 腐烂：咕嘟气泡
bub = mix(*[at(sweep(200+60*i, 500+90*i, 0.06)*env(int(SR*0.06),curve=2), i*0.07+rng.uniform(0,0.03)) for i in range(7)])
save('rot', mix(bub*0.6, lowpass(noise(0.6),0.03)*env(int(SR*0.6),a=0.05,curve=1.5)*0.5), 0.45)
# 肢解：撕裂
d=0.45; save('dismember', mix(lowpass(noise(d),0.25)*env(int(SR*d),curve=2), sweep(160,60,d)*env(int(SR*d),curve=2)*0.8), 0.55)
# 移动：轻脚步
save('step', mix(lowpass(noise(0.05),0.15)*env(int(SR*0.05),curve=3), at(lowpass(noise(0.05),0.15)*env(int(SR*0.05),curve=3)*0.7, 0.11)), 0.3)
# 抽卡：纸牌滑出
d=0.18; save('card', highpass(noise(d),0.2)*env(int(SR*d),a=0.03,curve=2), 0.3)
# 翻牌：清脆一下
save('flip', mix(highpass(noise(0.04),0.5)*env(int(SR*0.04),curve=3), tone(1400,0.08,(1,),6)*0.4), 0.35)
# 解锁技能：闪亮琶音
save('unlock', mix(*[at(tone(f,0.5,(1,2,3),3)*0.5, i*0.06) for i,f in enumerate([784,988,1175,1568,1976])]), 0.45)
# 装备：金属扣
save('equip', mix(tone(880,0.25,(1,2.76,5.4),5), at(tone(1320,0.2,(1,2.76),6)*0.6,0.05), highpass(noise(0.03),0.5)*env(int(SR*0.03),curve=3)*0.5), 0.45)
# 阵亡：下坠
d=0.6; save('death', mix(sweep(400,60,d)*env(int(SR*d),curve=1.5), lowpass(noise(d),0.05)*env(int(SR*d),curve=2)*0.5), 0.5)
# 回合开始：钟声
save('turn', mix(tone(523,1.0,(1,2.01,3.02,4.1),2.5), tone(784,0.8,(1,2),3)*0.4), 0.4)
# 复活：上扬光
save('respawn', mix(sweep(300,1200,0.5)*env(int(SR*0.5),a=0.05,curve=1.5)*0.5, at(tone(1047,0.5,(1,2),3)*0.5,0.3)), 0.45)
# 胜利：小号角
save('victory', mix(*[at(tone(f,0.45 if i<3 else 1.0,(1,2,3,4),2)*0.6, i*0.16) for i,f in enumerate([523,659,784,1047])]), 0.5)
print('ok', sorted(os.listdir(OUT)))

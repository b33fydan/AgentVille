// ============= Sound Manager =============
// Web Audio API procedural synth, no audio file dependencies
// Forked from Payday Kingdom architecture

class SoundManager {
  constructor() {
    this.ctx = null;
    this.muted = false;
    this.initialized = false;
  }

  init() {
    if (this.initialized) return;
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.initialized = true;
    } catch (e) {
      console.warn('[SoundManager] Web Audio API not available:', e);
    }
  }

  ensureContext() {
    if (!this.ctx) this.init();
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume();
    }
  }

  play(name) {
    if (this.muted || !this.ctx) return;
    this.ensureContext();
    if (typeof this[name] === 'function') {
      try {
        this[name]();
      } catch (e) {
        console.warn(`[SoundManager] Error playing ${name}:`, e);
      }
    }
  }

  setMuted(muted) {
    this.muted = muted;
    localStorage.setItem('av-muted', JSON.stringify(muted));
  }

  getMuted() {
    return this.muted;
  }

  // ===== HELPERS =====

  createOscillator(type, freq, gain, startTime = 0, duration = 0.1) {
    const osc = this.ctx.createOscillator();
    const gainNode = this.ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gainNode.gain.setValueAtTime(gain, this.ctx.currentTime + startTime);
    gainNode.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + startTime + duration);
    osc.connect(gainNode);
    gainNode.connect(this.ctx.destination);
    return { osc, gainNode };
  }

  // ===== DAY CYCLE =====

  dayAdvance() {
    const now = this.ctx.currentTime;

    // Tick: square wave click
    const tickOsc = this.ctx.createOscillator();
    const tickGain = this.ctx.createGain();
    tickOsc.type = 'square';
    tickOsc.frequency.value = 1200;
    tickGain.gain.setValueAtTime(0.15, now);
    tickGain.gain.exponentialRampToValueAtTime(0.001, now + 0.05);
    tickOsc.connect(tickGain).connect(this.ctx.destination);
    tickOsc.start(now);
    tickOsc.stop(now + 0.05);

    // Chime: sine wave
    const chimeOsc = this.ctx.createOscillator();
    const chimeGain = this.ctx.createGain();
    chimeOsc.type = 'sine';
    chimeOsc.frequency.value = 880;
    chimeGain.gain.setValueAtTime(0.2, now + 0.08);
    chimeGain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
    chimeOsc.connect(chimeGain).connect(this.ctx.destination);
    chimeOsc.start(now + 0.08);
    chimeOsc.stop(now + 0.4);
  }

  // ===== RESOURCES =====

  resourceGain() {
    const now = this.ctx.currentTime;
    const freqVariation = 1300 + Math.random() * 200; // 1300-1500 Hz

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.value = freqVariation;
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.08);
  }

  // ===== AGENT EVENTS =====

  agentAssign() {
    const now = this.ctx.currentTime;

    // Click
    const clickOsc = this.ctx.createOscillator();
    const clickGain = this.ctx.createGain();
    clickOsc.type = 'square';
    clickOsc.frequency.value = 2000;
    clickGain.gain.setValueAtTime(0.15, now);
    clickGain.gain.exponentialRampToValueAtTime(0.001, now + 0.02);
    clickOsc.connect(clickGain).connect(this.ctx.destination);
    clickOsc.start(now);
    clickOsc.stop(now + 0.02);

    // Rising tone
    const toneOsc = this.ctx.createOscillator();
    const toneGain = this.ctx.createGain();
    toneOsc.type = 'sine';
    toneOsc.frequency.setValueAtTime(400, now + 0.02);
    toneOsc.frequency.linearRampToValueAtTime(600, now + 0.14);
    toneGain.gain.setValueAtTime(0.2, now + 0.02);
    toneGain.gain.exponentialRampToValueAtTime(0.001, now + 0.14);
    toneOsc.connect(toneGain).connect(this.ctx.destination);
    toneOsc.start(now + 0.02);
    toneOsc.stop(now + 0.14);
  }

  agentReaction() {
    const now = this.ctx.currentTime;
    for (let i = 0; i < 4; i++) {
      const clickOsc = this.ctx.createOscillator();
      const clickGain = this.ctx.createGain();
      clickOsc.type = 'square';
      clickOsc.frequency.value = 3000;
      clickGain.gain.setValueAtTime(0.1, now + i * 0.03);
      clickGain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.03 + 0.02);
      clickOsc.connect(clickGain).connect(this.ctx.destination);
      clickOsc.start(now + i * 0.03);
      clickOsc.stop(now + i * 0.03 + 0.02);
    }
  }

  agentDesert() {
    const now = this.ctx.currentTime;

    // Descending tone
    const toneOsc = this.ctx.createOscillator();
    const toneGain = this.ctx.createGain();
    toneOsc.type = 'sine';
    toneOsc.frequency.setValueAtTime(500, now);
    toneOsc.frequency.linearRampToValueAtTime(200, now + 0.4);
    toneGain.gain.setValueAtTime(0.25, now);
    toneGain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
    toneOsc.connect(toneGain).connect(this.ctx.destination);
    toneOsc.start(now);
    toneOsc.stop(now + 0.4);

    // Door slam
    const slamOsc = this.ctx.createOscillator();
    const slamGain = this.ctx.createGain();
    slamOsc.type = 'square';
    slamOsc.frequency.value = 200;
    slamGain.gain.setValueAtTime(0.3, now + 0.3);
    slamGain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
    slamOsc.connect(slamGain).connect(this.ctx.destination);
    slamOsc.start(now + 0.3);
    slamOsc.stop(now + 0.35);
  }

  // ===== MORALE =====

  moraleUp() {
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(400, now);
    osc.frequency.linearRampToValueAtTime(700, now + 0.15);
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.15);
  }

  moraleDown() {
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(600, now);
    osc.frequency.linearRampToValueAtTime(300, now + 0.15);
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.15);
  }

  moraleCritical() {
    const now = this.ctx.currentTime;

    // Drone
    const droneOsc = this.ctx.createOscillator();
    const droneGain = this.ctx.createGain();
    droneOsc.type = 'sawtooth';
    droneOsc.frequency.value = 100;
    droneGain.gain.setValueAtTime(0.15, now);
    droneGain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
    droneOsc.connect(droneGain).connect(this.ctx.destination);
    droneOsc.start(now);
    droneOsc.stop(now + 0.3);

    // Notes
    const notes = [400, 300];
    notes.forEach((freq, idx) => {
      const noteOsc = this.ctx.createOscillator();
      const noteGain = this.ctx.createGain();
      noteOsc.type = 'sine';
      noteOsc.frequency.value = freq;
      noteGain.gain.setValueAtTime(0.2, now + 0.08 + idx * 0.1);
      noteGain.gain.exponentialRampToValueAtTime(0.001, now + 0.18 + idx * 0.1);
      noteOsc.connect(noteGain).connect(this.ctx.destination);
      noteOsc.start(now + 0.08 + idx * 0.1);
      noteOsc.stop(now + 0.18 + idx * 0.1);
    });
  }

  // ===== CRISIS =====

  crisisAlert() {
    const now = this.ctx.currentTime;
    const freqs = [600, 400, 600];

    freqs.forEach((freq, idx) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.25, now + idx * 0.15);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.15 + 0.14);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now + idx * 0.15);
      osc.stop(now + idx * 0.15 + 0.14);
    });
  }

  crisisResolve() {
    const now = this.ctx.currentTime;
    const freqs = [523, 659, 784]; // C5, E5, G5 (major chord)

    freqs.forEach((freq, idx) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.2, now + idx * 0.1);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.1 + 0.1);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now + idx * 0.1);
      osc.stop(now + idx * 0.1 + 0.1);
    });
  }

  crisisResolveBad() {
    const now = this.ctx.currentTime;

    // Descending buzz
    const buzzOsc = this.ctx.createOscillator();
    const buzzGain = this.ctx.createGain();
    buzzOsc.type = 'sawtooth';
    buzzOsc.frequency.setValueAtTime(400, now);
    buzzOsc.frequency.linearRampToValueAtTime(200, now + 0.2);
    buzzGain.gain.setValueAtTime(0.2, now);
    buzzGain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
    buzzOsc.connect(buzzGain).connect(this.ctx.destination);
    buzzOsc.start(now);
    buzzOsc.stop(now + 0.2);

    // Thud
    const thudOsc = this.ctx.createOscillator();
    const thudGain = this.ctx.createGain();
    thudOsc.type = 'sine';
    thudOsc.frequency.value = 80;
    thudGain.gain.setValueAtTime(0.3, now + 0.2);
    thudGain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
    thudOsc.connect(thudGain).connect(this.ctx.destination);
    thudOsc.start(now + 0.2);
    thudOsc.stop(now + 0.3);
  }

  // ===== DEMANDS =====

  demandAppear() {
    const now = this.ctx.currentTime;

    for (let i = 0; i < 3; i++) {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = 300;
      gain.gain.setValueAtTime(0.2, now + i * 0.1);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.1 + 0.04);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now + i * 0.1);
      osc.stop(now + i * 0.1 + 0.04);
    }
  }

  demandAccept() {
    const now = this.ctx.currentTime;
    const freqs = [500, 700];

    freqs.forEach((freq, idx) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.2, now + idx * 0.08);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.08 + 0.08);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now + idx * 0.08);
      osc.stop(now + idx * 0.08 + 0.08);
    });
  }

  demandReject() {
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sawtooth';
    osc.frequency.value = 200;
    gain.gain.setValueAtTime(0.2, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.15);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.15);
  }

  // ===== SALE DAY =====

  harvestTally() {
    const now = this.ctx.currentTime;
    const freqVariation = 1200 + (Math.random() - 0.5) * 400; // ±200Hz variation

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.value = freqVariation;
    gain.gain.setValueAtTime(0.15, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.04);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.04);
  }

  profitReveal() {
    const now = this.ctx.currentTime;
    const freqs = [330, 415, 523]; // C, E, G major chord

    freqs.forEach((freq) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.15, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + 0.4);
    });
  }

  profitRevealBad() {
    const now = this.ctx.currentTime;
    const freqs = [330, 392, 494]; // C, Eb, Gb minor chord

    freqs.forEach((freq) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.12, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now);
      osc.stop(now + 0.4);
    });
  }

  agentReview() {
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(800, now);
    osc.frequency.linearRampToValueAtTime(1200, now + 0.06);
    gain.gain.setValueAtTime(0.15, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.06);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.06);
  }

  seasonComplete() {
    const now = this.ctx.currentTime;
    const freqs = [392, 523, 659, 784]; // G4, C5, E5, G5

    freqs.forEach((freq, idx) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = freq;
      const duration = idx === 3 ? 0.3 : 0.15;
      gain.gain.setValueAtTime(0.2, now + idx * 0.15);
      gain.gain.exponentialRampToValueAtTime(0.001, now + idx * 0.15 + duration);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(now + idx * 0.15);
      osc.stop(now + idx * 0.15 + duration);
    });
  }

  // ===== STRIKE =====

  strikeAlarm() {
    const now = this.ctx.currentTime;

    // Drone
    const droneOsc = this.ctx.createOscillator();
    const droneGain = this.ctx.createGain();
    droneOsc.type = 'sawtooth';
    droneOsc.frequency.value = 250;
    droneGain.gain.setValueAtTime(0.1, now);
    droneGain.gain.exponentialRampToValueAtTime(0.001, now + 0.6);
    droneOsc.connect(droneGain).connect(this.ctx.destination);
    droneOsc.start(now);
    droneOsc.stop(now + 0.6);

    // Thuds
    for (let i = 0; i < 5; i++) {
      const thudOsc = this.ctx.createOscillator();
      const thudGain = this.ctx.createGain();
      thudOsc.type = 'sine';
      thudOsc.frequency.value = 120;
      thudGain.gain.setValueAtTime(0.3, now + i * 0.12);
      thudGain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.12 + 0.06);
      thudOsc.connect(thudGain).connect(this.ctx.destination);
      thudOsc.start(now + i * 0.12);
      thudOsc.stop(now + i * 0.12 + 0.06);
    }
  }

  // ===== RIOT =====

  riotSiren() {
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(300, now);
    osc.frequency.linearRampToValueAtTime(900, now + 1.5);
    gain.gain.setValueAtTime(0.25, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 1.5);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 1.5);

    // Undertone
    const undertoneOsc = this.ctx.createOscillator();
    const undertoneGain = this.ctx.createGain();
    undertoneOsc.type = 'sawtooth';
    undertoneOsc.frequency.value = 80;
    undertoneGain.gain.setValueAtTime(0.15, now);
    undertoneGain.gain.exponentialRampToValueAtTime(0.001, now + 1.5);
    undertoneOsc.connect(undertoneGain).connect(this.ctx.destination);
    undertoneOsc.start(now);
    undertoneOsc.stop(now + 1.5);
  }

  riotExplosion() {
    const now = this.ctx.currentTime;

    // Noise burst
    const noiseOsc = this.ctx.createOscillator();
    const noiseGain = this.ctx.createGain();
    noiseOsc.type = 'square';
    noiseOsc.frequency.setValueAtTime(2000 + Math.random() * 4000, now);
    noiseGain.gain.setValueAtTime(0.4, now);
    noiseGain.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
    noiseOsc.connect(noiseGain).connect(this.ctx.destination);
    noiseOsc.start(now);
    noiseOsc.stop(now + 0.3);

    // Crackling
    for (let i = 0; i < 20; i++) {
      const crackOsc = this.ctx.createOscillator();
      const crackGain = this.ctx.createGain();
      crackOsc.type = 'square';
      crackOsc.frequency.value = Math.random() * 8000;
      crackGain.gain.setValueAtTime(0.1, now + 0.3 + i * 0.02);
      crackGain.gain.exponentialRampToValueAtTime(0.001, now + 0.3 + i * 0.02 + 0.01);
      crackOsc.connect(crackGain).connect(this.ctx.destination);
      crackOsc.start(now + 0.3 + i * 0.02);
      crackOsc.stop(now + 0.3 + i * 0.02 + 0.01);
    }
  }

  riotRoast() {
    const now = this.ctx.currentTime;
    const freqs = [250, 225, 200, 150];
    const durations = [0.2, 0.2, 0.2, 0.4];

    freqs.forEach((freq, idx) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'sawtooth';
      osc.frequency.value = freq;
      const duration = durations[idx];
      const startTime = now + freqs.slice(0, idx).reduce((sum, _, i) => sum + durations[i], 0);
      gain.gain.setValueAtTime(0.2, startTime);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + duration);
      osc.connect(gain).connect(this.ctx.destination);
      osc.start(startTime);
      osc.stop(startTime + duration);
    });
  }

  // ===== UI =====

  buttonClick() {
    const now = this.ctx.currentTime;

    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = 'square';
    osc.frequency.value = 4000;
    gain.gain.setValueAtTime(0.08, now);
    gain.gain.exponentialRampToValueAtTime(0.001, now + 0.015);
    osc.connect(gain).connect(this.ctx.destination);
    osc.start(now);
    osc.stop(now + 0.015);
  }

  shareCapture() {
    const now = this.ctx.currentTime;

    // First click
    const click1Osc = this.ctx.createOscillator();
    const click1Gain = this.ctx.createGain();
    click1Osc.type = 'square';
    click1Osc.frequency.value = 2000;
    click1Gain.gain.setValueAtTime(0.15, now);
    click1Gain.gain.exponentialRampToValueAtTime(0.001, now + 0.02);
    click1Osc.connect(click1Gain).connect(this.ctx.destination);
    click1Osc.start(now);
    click1Osc.stop(now + 0.02);

    // Second click (after gap)
    const click2Osc = this.ctx.createOscillator();
    const click2Gain = this.ctx.createGain();
    click2Osc.type = 'square';
    click2Osc.frequency.value = 2000;
    click2Gain.gain.setValueAtTime(0.15, now + 0.07);
    click2Gain.gain.exponentialRampToValueAtTime(0.001, now + 0.09);
    click2Osc.connect(click2Gain).connect(this.ctx.destination);
    click2Osc.start(now + 0.07);
    click2Osc.stop(now + 0.09);
  }
}

// Singleton export
export const soundManager = new SoundManager();

// Load persisted mute state
const savedMute = localStorage.getItem('av-muted');
if (savedMute !== null) {
  soundManager.setMuted(JSON.parse(savedMute));
}

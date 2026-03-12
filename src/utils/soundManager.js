import * as Tone from 'tone';

// ============= Sound Manager =============
// Procedural synth effects using Tone.js

class SoundManager {
  constructor() {
    this.isMuted = false;
    this.masterGain = null;
    try {
      this.masterGain = new Tone.Gain(0.3);
      this.masterGain.toDestination();
    } catch (e) {
      console.warn('Audio init failed (will retry on interaction):', e.message);
    }
  }

  async ensureAudioContext() {
    if (!this.masterGain) {
      try {
        this.masterGain = new Tone.Gain(0.3);
        this.masterGain.toDestination();
      } catch (e) {
        return false;
      }
    }
    if (Tone.getContext().state === 'suspended') {
      await Tone.start();
    }
    return true;
  }

  /**
   * Crisis alert sound (ascending beep)
   */
  async playCrisisAlert() {
    if (this.isMuted || !(await this.ensureAudioContext())) return;

    const synth = new Tone.PolySynth(Tone.Synth, {
      oscillator: { type: 'square' },
      envelope: { attack: 0.005, decay: 0.1, sustain: 0, release: 0.1 }
    }).connect(this.masterGain);

    // Quick ascending notes
    const now = Tone.now();
    synth.triggerAttackRelease('C4', '0.1', now);
    synth.triggerAttackRelease('E4', '0.1', now + 0.12);
    synth.triggerAttackRelease('G4', '0.1', now + 0.24);

    setTimeout(() => synth.dispose(), 500);
  }

  /**
   * Resource collected sound (pleasant chime)
   */
  async playResourceCollect() {
    if (this.isMuted || !(await this.ensureAudioContext())) return;

    const synth = new Tone.PolySynth(Tone.Synth, {
      oscillator: { type: 'triangle' },
      envelope: { attack: 0.01, decay: 0.2, sustain: 0, release: 0.1 }
    }).connect(this.masterGain);

    const now = Tone.now();
    synth.triggerAttackRelease('G4', '0.15', now);
    synth.triggerAttackRelease('B4', '0.15', now + 0.1);

    setTimeout(() => synth.dispose(), 300);
  }

  /**
   * Sale/Success sound (ascending chord)
   */
  async playSaleSuccess() {
    if (this.isMuted || !(await this.ensureAudioContext())) return;

    const synth = new Tone.PolySynth(Tone.Synth, {
      oscillator: { type: 'sine' },
      envelope: { attack: 0.05, decay: 0.3, sustain: 0, release: 0.2 }
    }).connect(this.masterGain);

    const now = Tone.now();
    synth.triggerAttackRelease('C4', '0.3', now);
    synth.triggerAttackRelease('E4', '0.3', now);
    synth.triggerAttackRelease('G4', '0.3', now);

    setTimeout(() => synth.dispose(), 600);
  }

  /**
   * Negative/failure sound (descending notes)
   */
  async playNegative() {
    if (this.isMuted || !(await this.ensureAudioContext())) return;

    const synth = new Tone.PolySynth(Tone.Synth, {
      oscillator: { type: 'square' },
      envelope: { attack: 0.01, decay: 0.15, sustain: 0, release: 0.1 }
    }).connect(this.masterGain);

    const now = Tone.now();
    synth.triggerAttackRelease('G4', '0.1', now);
    synth.triggerAttackRelease('E4', '0.1', now + 0.12);
    synth.triggerAttackRelease('C4', '0.15', now + 0.24);

    setTimeout(() => synth.dispose(), 500);
  }

  /**
   * Day advance sound (neutral beep)
   */
  async playDayAdvance() {
    if (this.isMuted || !(await this.ensureAudioContext())) return;

    const synth = new Tone.PolySynth(Tone.Synth, {
      oscillator: { type: 'sine' },
      envelope: { attack: 0.01, decay: 0.1, sustain: 0, release: 0.05 }
    }).connect(this.masterGain);

    synth.triggerAttackRelease('A4', '0.1', Tone.now());

    setTimeout(() => synth.dispose(), 200);
  }

  toggleMute() {
    this.isMuted = !this.isMuted;
    return this.isMuted;
  }

  setVolume(level) {
    if (this.masterGain) {
      this.masterGain.gain.value = Math.max(0, Math.min(1, level));
    }
  }
}

export const soundManager = new SoundManager();

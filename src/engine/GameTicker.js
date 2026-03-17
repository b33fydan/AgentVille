// ============= GAME TICKER ENGINE =============
// Continuous game loop that replaces button-click advancement.
// Tracks game-hours (0-24), triggers advanceDayLogic() at phase boundaries.
// Speed controls: 0 (pause), 1 (1x), 2 (2x), 3 (3x).

import { useGameStore } from '../store/gameStore';
import { advanceDayLogic } from '../utils/advanceDayHandler';
import { tickAgentAI, initAgentAI } from './AgentAI';
import { soundManager } from '../utils/soundManager';

// ─── Constants ───
const SECONDS_PER_GAME_DAY = 180; // 3 real minutes = 1 game day at 1x
const HOURS_PER_DAY = 24;
const GAME_HOURS_PER_SECOND = HOURS_PER_DAY / SECONDS_PER_GAME_DAY; // ~0.1333

// Phase boundaries (game-hours)
const PHASE_MORNING = 0;
const PHASE_AFTERNOON = 6;
const PHASE_EVENING = 12;
const PHASE_NIGHT = 18;

// ─── Day Phase Helper ───
export function getDayPhaseFromHour(hour) {
  if (hour < PHASE_AFTERNOON) return 'morning';
  if (hour < PHASE_EVENING) return 'afternoon';
  if (hour < PHASE_NIGHT) return 'evening';
  return 'night';
}

export function getDayPhaseEmoji(phase) {
  switch (phase) {
    case 'morning': return '🌅';
    case 'afternoon': return '☀️';
    case 'evening': return '🌆';
    case 'night': return '🌙';
    default: return '☀️';
  }
}

// ─── GameTicker Singleton ───
class GameTicker {
  constructor() {
    this.gameHour = 0;
    this.speed = 0; // Start paused — will be set to 1 when game begins
    this.running = false;
    this.animFrameId = null;
    this.lastTimestamp = null;
    this.currentDayPhase = 'morning';

    // Track which half-day boundary we've fired (to avoid double-firing)
    this._firedMorningToEvening = false; // fires at hour 12
    this._firedEveningToNextDay = false; // fires at hour 24 (wraps to 0)

    // Event listeners
    this._listeners = {
      tick: [],
      dayPhaseChange: [],
      dayAdvance: [],
      speedChange: []
    };
  }

  // ─── Public API ───

  start() {
    if (this.running) return;
    this.running = true;
    this.lastTimestamp = performance.now();

    // Sync initial state from store
    const state = useGameStore.getState();
    if (state.gameHour !== undefined) {
      this.gameHour = state.gameHour;
    }
    if (state.gameSpeed !== undefined) {
      this.speed = state.gameSpeed;
    }
    this.currentDayPhase = getDayPhaseFromHour(this.gameHour);
    this._syncBoundaryFlags();

    // Initialize agent AI task states
    initAgentAI();

    // Start ambient soundscape for current phase
    soundManager.setAmbientPhase(this.currentDayPhase);

    this._loop();
  }

  stop() {
    this.running = false;
    if (this.animFrameId) {
      cancelAnimationFrame(this.animFrameId);
      this.animFrameId = null;
    }
  }

  setSpeed(speed) {
    const clamped = Math.max(0, Math.min(3, speed));
    this.speed = clamped;
    useGameStore.getState().setGameSpeed(clamped);
    this._emit('speedChange', clamped);
  }

  getSpeed() {
    return this.speed;
  }

  getGameHour() {
    return this.gameHour;
  }

  getDayPhase() {
    return this.currentDayPhase;
  }

  // Subscribe to events: 'tick', 'dayPhaseChange', 'dayAdvance', 'speedChange'
  on(event, callback) {
    if (this._listeners[event]) {
      this._listeners[event].push(callback);
    }
    return () => this.off(event, callback);
  }

  off(event, callback) {
    if (this._listeners[event]) {
      this._listeners[event] = this._listeners[event].filter((cb) => cb !== callback);
    }
  }

  // ─── Internal ───

  _emit(event, ...args) {
    if (this._listeners[event]) {
      this._listeners[event].forEach((cb) => cb(...args));
    }
  }

  _syncBoundaryFlags() {
    // Set flags based on current hour so we don't re-fire boundaries on resume
    this._firedMorningToEvening = this.gameHour >= PHASE_EVENING;
    this._firedEveningToNextDay = false; // Never pre-fire this
  }

  _shouldPause() {
    const gamePhase = useGameStore.getState().gamePhase;
    // Auto-pause during modals (crisis, saleDay, riot, cooldown)
    return gamePhase !== 'playing';
  }

  _loop() {
    if (!this.running) return;

    this.animFrameId = requestAnimationFrame((timestamp) => {
      if (!this.running) return;

      const delta = Math.min((timestamp - this.lastTimestamp) / 1000, 0.1); // Cap at 100ms
      this.lastTimestamp = timestamp;

      // Only tick if speed > 0 and game is in playing phase
      if (this.speed > 0 && !this._shouldPause()) {
        this._tick(delta);
      }

      this._loop();
    });
  }

  _tick(deltaSeconds) {
    const hourAdvance = GAME_HOURS_PER_SECOND * this.speed * deltaSeconds;
    const prevHour = this.gameHour;
    this.gameHour += hourAdvance;

    // Check for phase transitions
    const prevPhase = this.currentDayPhase;
    const newPhase = getDayPhaseFromHour(this.gameHour % HOURS_PER_DAY);
    if (newPhase !== prevPhase) {
      this.currentDayPhase = newPhase;
      useGameStore.getState().setDayPhase(newPhase);
      this._emit('dayPhaseChange', newPhase, prevPhase);

      // Update ambient soundscape
      soundManager.setAmbientPhase(newPhase);
    }

    // Morning → Evening boundary (hour crosses 12)
    // This triggers one advanceDayLogic call (morning→evening)
    if (!this._firedMorningToEvening && this.gameHour >= PHASE_EVENING) {
      this._firedMorningToEvening = true;
      this._triggerDayAdvance();
    }

    // Day boundary (hour crosses 24)
    // This triggers one advanceDayLogic call (evening→next morning + increment day)
    if (this.gameHour >= HOURS_PER_DAY) {
      this.gameHour -= HOURS_PER_DAY;
      this._firedMorningToEvening = false;
      this._firedEveningToNextDay = false;
      this._triggerDayAdvance();
    }

    // Persist game hour to store (throttled — every ~0.5 game-hours to reduce writes)
    if (Math.floor(prevHour * 2) !== Math.floor(this.gameHour * 2)) {
      useGameStore.getState().setGameHour(this.gameHour);
    }

    // Tick agent AI with delta game-hours
    tickAgentAI(hourAdvance, this.gameHour);

    this._emit('tick', deltaSeconds, this.gameHour);
  }

  _triggerDayAdvance() {
    const gamePhase = useGameStore.getState().gamePhase;
    if (gamePhase !== 'playing') return;

    console.log(`[GameTicker] Day advance at hour ${this.gameHour.toFixed(1)}`);
    const success = advanceDayLogic();

    if (success) {
      this._emit('dayAdvance', useGameStore.getState().day, useGameStore.getState().timeOfDay);
    }

    // Persist hour after advance
    useGameStore.getState().setGameHour(this.gameHour % HOURS_PER_DAY);
  }
}

// ─── Singleton Export ───
export const gameTicker = new GameTicker();

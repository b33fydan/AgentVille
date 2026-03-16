import { useState, useEffect, useCallback } from 'react';
import { useGameStore } from '../../store/gameStore';
import { useAgentStore } from '../../store/agentStore';
import { soundManager } from '../../utils/soundManager';
import { tradeMarket } from '../../utils/agentTrading';
import { cardGenerator } from '../../utils/cardGenerator';
import { gameTicker, getDayPhaseEmoji } from '../../engine/GameTicker';
import ShareModal from './ShareModal';

const SPEED_OPTIONS = [
  { value: 0, label: '⏸', title: 'Pause' },
  { value: 1, label: '▶', title: '1x Speed' },
  { value: 2, label: '▶▶', title: '2x Speed' },
  { value: 3, label: '▶▶▶', title: '3x Speed' }
];

export default function SeasonHUD() {
  const resources = useGameStore((state) => state.resources);
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const gamePhase = useGameStore((state) => state.gamePhase);
  const getProfit = useGameStore((state) => state.getProfit);
  const dayPhase = useGameStore((state) => state.dayPhase);
  const gameSpeed = useGameStore((state) => state.gameSpeed);
  const gameHour = useGameStore((state) => state.gameHour);

  const agents = useAgentStore((state) => state.agents);
  const [marketPrices, setMarketPrices] = useState({ wood: 2, wheat: 5, hay: 3 });
  const [isMuted, setIsMuted] = useState(() => soundManager.getMuted());
  const [islandCard, setIslandCard] = useState(null);
  const [showShareModal, setShowShareModal] = useState(false);

  // Update market prices from tradeMarket
  useEffect(() => {
    const prices = tradeMarket.getPrices();
    if (prices.wood && prices.wheat && prices.hay) {
      setMarketPrices({
        wood: prices.wood,
        wheat: prices.wheat,
        hay: prices.hay
      });
    }
  }, [day, season]);

  const profit = getProfit();

  const getSeasonPhase = () => {
    if (day <= 2) return 'Setup';
    if (day <= 5) return 'Survival';
    if (day === 6) return 'Profit Push';
    return 'Sale Day';
  };

  // Speed control handler
  const handleSpeedChange = useCallback((speed) => {
    gameTicker.setSpeed(speed);
    soundManager.play('buttonClick');
  }, []);

  // Keyboard shortcuts: Space = pause/play, 1/2/3 = speed
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

      if (e.code === 'Space') {
        e.preventDefault();
        const currentSpeed = gameTicker.getSpeed();
        handleSpeedChange(currentSpeed === 0 ? 1 : 0);
      } else if (e.key === '1') {
        handleSpeedChange(1);
      } else if (e.key === '2') {
        handleSpeedChange(2);
      } else if (e.key === '3') {
        handleSpeedChange(3);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handleSpeedChange]);

  const toggleMute = () => {
    const newMuted = !isMuted;
    soundManager.setMuted(newMuted);
    setIsMuted(newMuted);
  };

  const handleCapture = async () => {
    soundManager.play('shareCapture');
    const canvas = document.querySelector('canvas');
    if (!canvas) return;
    const screenshotUrl = canvas.toDataURL('image/png');
    const islandName = useGameStore.getState().islandName || 'AgentVille Island';
    const avgMorale = agents.length > 0
      ? Math.round(agents.reduce((sum, a) => sum + a.morale, 0) / agents.length)
      : 50;
    const card = await cardGenerator.generateCard('island', {
      screenshotUrl,
      islandName,
      season,
      day,
      agentCount: agents.length,
      morale: avgMorale
    });
    setIslandCard(card);
    setShowShareModal(true);
  };

  const handleShare = async () => {
    try {
      if (navigator.share) {
        await navigator.share({
          title: 'AgentVille',
          text: `Season ${season}, Day ${day}/7 - Profit: $${Math.round(profit)}`,
          url: window.location.href
        });
      } else {
        const text = `AgentVille - Season ${season}: $${Math.round(profit)} profit! Play: agentville.app`;
        await navigator.clipboard.writeText(text);
        alert('Copied to clipboard! Share it on social media.');
      }
    } catch (err) {
      console.error('Share failed:', err);
    }
  };

  // Hide during SaleDay (full-screen modal takes over)
  if (gamePhase === 'saleDay') {
    return null;
  }

  const phaseEmoji = getDayPhaseEmoji(dayPhase);
  const hourDisplay = Math.floor(gameHour || 0);
  const isPaused = gameSpeed === 0;
  const isAutoPlaying = gamePhase === 'playing' && gameSpeed > 0;

  return (
    <div className="fixed bottom-4 left-4 right-4 z-50 flex flex-col gap-3 rounded-lg border border-slate-700 bg-slate-900/95 p-4 backdrop-blur md:absolute md:top-4 md:bottom-auto md:right-4 md:w-80 md:left-auto">
      {/* Season / Day / Time-of-Day */}
      <div className="grid grid-cols-3 gap-2">
        <div className="rounded bg-slate-800 p-2 text-center">
          <div className="text-xs uppercase tracking-widest text-slate-400">Season</div>
          <div className="text-2xl font-bold text-yellow-400">{season}</div>
        </div>
        <div className="rounded bg-slate-800 p-2 text-center">
          <div className="text-xs uppercase tracking-widest text-slate-400">Day</div>
          <div className="text-2xl font-bold text-blue-400">{day}/7</div>
        </div>
        <div className="rounded bg-slate-800 p-2 text-center">
          <div className="text-xs uppercase tracking-widest text-slate-400">Time</div>
          <div className="text-lg font-semibold text-slate-200">{phaseEmoji} {hourDisplay}h</div>
        </div>
      </div>

      {/* Speed Controls */}
      <div className="flex items-center gap-1">
        {SPEED_OPTIONS.map(({ value, label, title }) => (
          <button
            key={value}
            onClick={() => handleSpeedChange(value)}
            title={`${title} (${value === 0 ? 'Space' : value})`}
            className={`flex-1 rounded-lg py-2 text-sm font-bold transition-all active:scale-95
              ${gameSpeed === value
                ? 'bg-blue-600 text-white ring-2 ring-blue-400'
                : 'bg-slate-700 text-slate-300 hover:bg-slate-600'
              }
              ${gamePhase !== 'playing' && value > 0 ? 'opacity-40 cursor-not-allowed' : ''}
            `}
            disabled={gamePhase !== 'playing' && value > 0}
          >
            {label}
          </button>
        ))}
        <div className="ml-2 text-xs text-slate-400 min-w-[50px] text-right">
          {isPaused ? 'PAUSED' : `${gameSpeed}x`}
        </div>
      </div>

      {/* Day Progress Bar */}
      <div>
        <div className="flex items-center justify-between mb-1">
          <div className="text-xs uppercase tracking-widest text-slate-400">{getSeasonPhase()}</div>
          <div className="text-xs text-slate-300 font-semibold">{dayPhase}</div>
        </div>
        <div className="h-2 rounded-full bg-slate-700">
          <div
            className="h-full rounded-full bg-gradient-to-r from-blue-500 to-purple-500 transition-all"
            style={{ width: `${((day - 1 + (gameHour || 0) / 24) / 7) * 100}%` }}
          />
        </div>
      </div>

      {/* Resources */}
      <div className="grid grid-cols-3 gap-2">
        <div className="rounded bg-green-900/30 p-2">
          <div className="text-xs text-green-300">🌲 Wood</div>
          <div className="text-lg font-bold text-green-400">{resources.wood}</div>
          <div className="text-xs text-green-300">${resources.wood * marketPrices.wood}</div>
        </div>
        <div className="rounded bg-amber-900/30 p-2">
          <div className="text-xs text-amber-300">🌾 Wheat</div>
          <div className="text-lg font-bold text-amber-400">{resources.wheat}</div>
          <div className="text-xs text-amber-300">${resources.wheat * marketPrices.wheat}</div>
        </div>
        <div className="rounded bg-blue-900/30 p-2">
          <div className="text-xs text-blue-300">🌊 Hay</div>
          <div className="text-lg font-bold text-blue-400">{resources.hay}</div>
          <div className="text-xs text-blue-300">${resources.hay * marketPrices.hay}</div>
        </div>
      </div>

      {/* Profit Preview */}
      <div className="rounded bg-slate-800 p-3">
        <div className="flex items-center justify-between">
          <div className="text-xs uppercase tracking-widest text-slate-400">Projected Profit</div>
          <div className={`text-xl font-bold ${profit >= 0 ? 'text-green-400' : 'text-red-400'}`}>
            ${profit >= 0 ? '+' : ''}{profit}
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex gap-2">
        <button
          onClick={handleCapture}
          className="flex-1 rounded-lg px-3 py-2 text-sm font-bold bg-blue-600 hover:bg-blue-500 text-white transition-all active:scale-95"
          title="Capture island screenshot"
        >
          📸 Capture
        </button>
        <button
          onClick={handleShare}
          className="flex-1 rounded-lg px-3 py-2 text-sm font-bold bg-green-600 hover:bg-green-500 text-white transition-all active:scale-95"
          title="Share your progress"
        >
          📤 Share
        </button>
        <button
          onClick={toggleMute}
          className="rounded-lg px-3 py-2 text-sm font-bold bg-slate-700 hover:bg-slate-600 text-white transition-all active:scale-95"
          title={isMuted ? 'Unmute sounds' : 'Mute sounds'}
        >
          {isMuted ? '🔇' : '🔊'}
        </button>
      </div>

      {/* Game Phase Status */}
      {gamePhase === 'crisis' && (
        <div className="rounded-lg border border-red-600 bg-red-900/20 p-3 text-center text-red-300 animate-pulse">
          <div className="font-bold">⚠️ CRISIS ALERT</div>
          <div className="text-xs">Resolve the crisis first — game paused</div>
        </div>
      )}

      {showShareModal && (
        <ShareModal
          card={islandCard}
          title="📸 Island Screenshot"
          onClose={() => setShowShareModal(false)}
        />
      )}
    </div>
  );
}

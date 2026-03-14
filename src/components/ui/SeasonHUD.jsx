import { useGameStore } from '../../store/gameStore';
import { useAgentStore } from '../../store/agentStore';
import { useLogStore } from '../../store/logStore';
import { soundManager } from '../../utils/soundManager';
import { advanceDayLogic, canAdvanceDay, getAdvanceButtonLabel, getAdvanceButtonColor } from '../../utils/advanceDayHandler';

export default function SeasonHUD() {
  const resources = useGameStore((state) => state.resources);
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const timeOfDay = useGameStore((state) => state.timeOfDay);
  const gamePhase = useGameStore((state) => state.gamePhase);
  const getProfit = useGameStore((state) => state.getProfit);
  
  const agents = useAgentStore((state) => state.agents);

  const profit = getProfit();
  const marketPrices = { wood: 2, wheat: 5, hay: 3 };

  const getDayPhase = () => {
    if (day <= 2) return 'Setup';
    if (day <= 5) return 'Survival';
    if (day === 6) return 'Profit Push';
    return 'Sale Day';
  };

  const handleAdvanceDay = () => {
    // Run the full game loop
    const success = advanceDayLogic();
    if (!success) {
      console.warn('[SeasonHUD] Could not advance day');
    }
  };

  const handleShare = async () => {
    try {
      if (navigator.share) {
        await navigator.share({
          title: '🏝️ AgentVille',
          text: `Season ${season}, Day ${day}/7 - Profit: $${Math.round(profit)}`,
          url: window.location.href
        });
      } else {
        // Fallback: copy to clipboard
        const text = `🏝️ AgentVille - Season ${season}: $${Math.round(profit)} profit! 🌾🌲 Play: agentville.app`;
        await navigator.clipboard.writeText(text);
        alert('Copied to clipboard! Share it on social media.');
      }
    } catch (err) {
      console.error('Share failed:', err);
    }
  };

  return (
    <div className="fixed bottom-4 left-4 right-4 flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-900/95 p-4 backdrop-blur md:bottom-auto md:right-4 md:w-80 md:left-auto">
      {/* Season Info */}
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
          <div className="text-xs uppercase tracking-widest text-slate-400">Phase</div>
          <div className="text-xs font-semibold text-slate-200">{getDayPhase()}</div>
        </div>
      </div>

      {/* Day Progress Bar */}
      <div className="h-2 rounded-full bg-slate-700">
        <div
          className="h-full rounded-full bg-gradient-to-r from-blue-500 to-purple-500 transition-all"
          style={{ width: `${(day / 7) * 100}%` }}
        />
      </div>

      {/* Resources */}
      <div className="space-y-2">
        <h3 className="text-xs font-bold uppercase tracking-wider text-slate-300">Resources</h3>
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
      </div>

      {/* Profit Preview */}
      <div className="rounded bg-slate-800 p-3">
        <div className="text-xs uppercase tracking-widest text-slate-400">Projected Profit</div>
        <div className={`text-2xl font-bold ${profit >= 0 ? 'text-green-400' : 'text-red-400'}`}>
          ${profit >= 0 ? '+' : ''}{profit}
        </div>
        <div className="mt-1 text-xs text-slate-400">
          Sale Day = Harvest {' → '} Revenue {' → '} Review
        </div>
      </div>

      {/* ADVANCE DAY Button (MAIN CTA) */}
      <button
        onClick={handleAdvanceDay}
        disabled={!canAdvanceDay() || gamePhase !== 'playing'}
        style={{
          backgroundColor: canAdvanceDay() && gamePhase === 'playing' 
            ? getAdvanceButtonColor(day, timeOfDay) 
            : '#4b5563'
        }}
        className="w-full rounded-lg px-4 py-4 font-bold text-lg uppercase tracking-wider text-white transition-all active:scale-95 disabled:cursor-not-allowed disabled:opacity-60 hover:enabled:scale-105"
      >
        {getAdvanceButtonLabel(day, timeOfDay)}
      </button>

      {/* Info: Day Progress */}
      <div className="rounded-lg bg-slate-800 p-3">
        <div className="flex items-center justify-between mb-2">
          <div className="text-xs uppercase tracking-widest text-slate-400">Day Progress</div>
          <div className="text-xs text-slate-300 font-semibold">{day}/7</div>
        </div>
        <div className="h-2 rounded-full bg-slate-700">
          <div
            className="h-full rounded-full bg-gradient-to-r from-blue-500 to-purple-500 transition-all"
            style={{ width: `${(day / 7) * 100}%` }}
          />
        </div>
        <div className="mt-2 text-xs text-slate-400 text-center">{getDayPhase()}</div>
      </div>

      {/* Action Buttons (Secondary) */}
      <div className="flex gap-2">
        <button
          onClick={handleShare}
          className="flex-1 rounded-lg px-3 py-2 text-sm font-bold bg-green-600 hover:bg-green-500 text-white transition-all active:scale-95"
          title="Share your progress"
        >
          📤 Share
        </button>
      </div>

      {/* Game Phase Status */}
      {gamePhase === 'saleDay' && (
        <div className="rounded-lg border border-yellow-600 bg-yellow-900/20 p-3 text-center text-yellow-300 animate-pulse">
          <div className="font-bold">📦 SALE DAY</div>
          <div className="text-xs">Season complete. Review time...</div>
        </div>
      )}

      {gamePhase === 'crisis' && (
        <div className="rounded-lg border border-red-600 bg-red-900/20 p-3 text-center text-red-300 animate-pulse">
          <div className="font-bold">⚠️ CRISIS ALERT</div>
          <div className="text-xs">Resolve the crisis first</div>
        </div>
      )}
    </div>
  );
}

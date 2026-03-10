import { useAgentStore } from '../../store/agentStore';

export default function SeasonHUD() {
  const resources = useAgentStore((state) => state.resources);
  const season = useAgentStore((state) => state.season);
  const advanceDay = useAgentStore((state) => state.advanceDay);
  const getProfit = useAgentStore((state) => state.getProfit);

  const profit = getProfit();
  const marketPrices = { wood: 2, wheat: 5, hay: 3 };

  const getDayPhase = () => {
    const day = season.currentDay;
    if (day <= 2) return 'Setup';
    if (day <= 5) return 'Survival';
    if (day === 6) return 'Profit Push';
    return 'Sale Day';
  };

  return (
    <div className="fixed bottom-4 left-4 right-4 flex flex-col gap-4 rounded-lg border border-slate-700 bg-slate-900/95 p-4 backdrop-blur md:bottom-auto md:right-4 md:w-80 md:left-auto">
      {/* Season Info */}
      <div className="grid grid-cols-3 gap-2">
        <div className="rounded bg-slate-800 p-2 text-center">
          <div className="text-xs uppercase tracking-widest text-slate-400">Season</div>
          <div className="text-2xl font-bold text-yellow-400">{season.seasonNumber}</div>
        </div>
        <div className="rounded bg-slate-800 p-2 text-center">
          <div className="text-xs uppercase tracking-widest text-slate-400">Day</div>
          <div className="text-2xl font-bold text-blue-400">{season.currentDay}/7</div>
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
          style={{ width: `${(season.currentDay / 7) * 100}%` }}
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

      {/* Day Advance Button */}
      <button
        onClick={advanceDay}
        disabled={season.currentDay >= 7}
        className={`rounded-lg px-4 py-3 font-bold uppercase tracking-wider transition-all ${
          season.currentDay >= 7
            ? 'cursor-not-allowed bg-slate-700 text-slate-500'
            : 'bg-blue-600 hover:bg-blue-500 text-white active:scale-95'
        }`}
      >
        {season.currentDay >= 7 ? '📊 Sale Day Complete' : '⏭️ Next Day'}
      </button>

      {/* Sale Day Message */}
      {season.currentDay >= 7 && (
        <div className="rounded-lg border border-yellow-600 bg-yellow-900/20 p-3 text-center text-yellow-300">
          <div className="font-bold">🎪 Sale Day!</div>
          <div className="text-xs">Agents review your management...</div>
        </div>
      )}
    </div>
  );
}

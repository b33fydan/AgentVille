import { useState } from 'react';
import { useGameStore } from '../../store/gameStore';
import { useLogStore } from '../../store/logStore';
import { soundManager } from '../../utils/soundManager';

export default function StrikeModal({ strike, onClose }) {
  const [dismissed, setDismissed] = useState(false);
  const addLogEntry = useLogStore((state) => state.addLogEntry);

  if (!strike || dismissed) {
    return null;
  }

  const handleConfirm = () => {
    // Log the strike
    addLogEntry({
      agentId: null,
      agentName: 'Team',
      type: 'strike',
      message: `🏴 The team refused to work! Average morale was ${Math.round(strike.avgMorale)}%. Resources harvested at 50% capacity.`,
      emoji: '✊'
    });

    // Play angry/protest sound
    soundManager.playNegative();

    setDismissed(true);
    onClose();
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/70 backdrop-blur-sm z-50">
      <div className="w-full max-w-md rounded-lg border-2 border-yellow-600 bg-slate-900 p-6 shadow-2xl">
        {/* Header */}
        <div className="mb-4 text-center">
          <div className="text-5xl mb-2">✊</div>
          <h2 className="text-2xl font-bold text-yellow-400">STRIKE!</h2>
        </div>

        {/* Subtitle */}
        <div className="text-center text-slate-300 mb-4">
          <div className="font-semibold text-lg">Team Refuses to Work</div>
          <div className="text-sm text-slate-400 mt-1">Your agents' morale is too low.</div>
        </div>

        {/* Morale Stat */}
        <div className="mb-4 rounded-lg bg-yellow-900/20 border border-yellow-600/50 p-4 text-center">
          <div className="text-xs text-yellow-300 uppercase font-bold">Average Morale</div>
          <div className="text-3xl font-bold text-yellow-400 mt-2">{Math.round(strike.avgMorale)}%</div>
          <div className="text-xs text-yellow-200 mt-2">Threshold for strike: &lt; 40%</div>
        </div>

        {/* Consequences */}
        <div className="mb-4 rounded-lg bg-red-900/20 border border-red-600/50 p-4">
          <div className="text-xs font-bold text-red-300 uppercase mb-2">Consequences</div>
          <ul className="text-sm text-red-200 space-y-1">
            {strike.consequences?.map((consequence, idx) => (
              <li key={idx} className="flex items-start gap-2">
                <span>•</span>
                <span>{consequence}</span>
              </li>
            ))}
          </ul>
          <div className="mt-3 pt-3 border-t border-red-600/30 text-sm font-semibold text-red-300">
            Resource Harvest: 50% (instead of 100%)
          </div>
        </div>

        {/* What You Should Do */}
        <div className="mb-4 rounded-lg bg-slate-800 p-4">
          <div className="text-xs font-bold text-slate-300 uppercase mb-2">Next Season</div>
          <ul className="text-sm text-slate-300 space-y-1">
            <li>✓ Increase agent morale to 40+</li>
            <li>✓ Avoid crisis events that damage morale</li>
            <li>✓ Assign agents to zones they specialize in</li>
            <li>✓ Make smart crisis decisions</li>
          </ul>
        </div>

        {/* Button */}
        <button
          onClick={handleConfirm}
          className="w-full rounded-lg px-4 py-3 font-bold uppercase tracking-wider bg-yellow-600 hover:bg-yellow-500 text-white transition-all active:scale-95"
        >
          Accept Outcome
        </button>
      </div>
    </div>
  );
}

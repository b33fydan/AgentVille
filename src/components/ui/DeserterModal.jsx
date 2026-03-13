import { useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useLogStore } from '../../store/logStore';
import { soundManager } from '../../utils/soundManager';

export default function DeserterModal({ desertion, onClose }) {
  const [dismissed, setDismissed] = useState(false);
  const desertAgent = useAgentStore((state) => state.desertAgent);
  const addLogEntry = useLogStore((state) => state.addLogEntry);

  if (!desertion || dismissed) {
    return null;
  }

  const handleConfirm = () => {
    // Remove agent from game
    desertAgent(desertion.agentId);

    // Log the desertion
    addLogEntry({
      agentId: desertion.agentId,
      agentName: desertion.agentName,
      type: 'desertion',
      message: `${desertion.agentName} abandoned the island. Morale was critically low (${desertion.morale}%).`,
      emoji: '🚶'
    });

    // Play sad sound
    soundManager.playNegative();

    setDismissed(true);
    onClose();
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/70 backdrop-blur-sm z-50">
      <div className="w-full max-w-md rounded-lg border-2 border-red-600 bg-slate-900 p-6 shadow-2xl">
        {/* Header */}
        <div className="mb-4 text-center">
          <div className="text-5xl mb-2">🚶‍♂️</div>
          <h2 className="text-2xl font-bold text-red-400">Agent Deserted!</h2>
        </div>

        {/* Agent Name */}
        <div className="mb-4 rounded-lg bg-red-900/20 border border-red-600/50 p-4 text-center">
          <div className="text-lg font-semibold text-red-300">{desertion.agentName}</div>
          <div className="text-sm text-red-200 mt-2">
            Morale: <span className="font-bold">{desertion.morale}%</span>
          </div>
        </div>

        {/* Message */}
        <p className="text-slate-300 mb-4 text-center">
          {desertion.agentName} couldn't take it anymore and left the island. Your management drove them away.
        </p>

        {/* Severity Info */}
        {desertion.severity === 'critical' && (
          <div className="mb-4 rounded-lg bg-red-900/30 border border-red-600/50 p-3">
            <div className="text-xs font-bold text-red-300 uppercase">Critical Desertion</div>
            <div className="text-xs text-red-200 mt-1">
              This agent's morale was dangerously low. You had multiple opportunities to improve their situation.
            </div>
          </div>
        )}

        {/* Team Size Impact */}
        <div className="mb-4 rounded-lg bg-slate-800 p-3 text-center">
          <div className="text-xs text-slate-400 uppercase">Team Impact</div>
          <div className="text-sm text-slate-300 mt-1">Your workforce is now smaller. Remaining agents work harder.</div>
        </div>

        {/* Buttons */}
        <div className="flex gap-2">
          <button
            onClick={handleConfirm}
            className="flex-1 rounded-lg px-4 py-3 font-bold uppercase tracking-wider bg-red-600 hover:bg-red-500 text-white transition-all active:scale-95"
          >
            Acknowledge
          </button>
        </div>
      </div>
    </div>
  );
}

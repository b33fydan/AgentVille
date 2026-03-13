import { useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';
import { useLogStore } from '../../store/logStore';
import { soundManager } from '../../utils/soundManager';

export default function AgentDemandsModal({ demandQueue, onClose }) {
  const [currentIndex, setCurrentIndex] = useState(0);
  const [resolvedCount, setResolvedCount] = useState(0);

  const updateMorale = useAgentStore((state) => state.updateMorale);
  const desertAgent = useAgentStore((state) => state.desertAgent);
  const addResource = useGameStore((state) => state.addResource);
  const addLogEntry = useLogStore((state) => state.addLogEntry);

  if (!demandQueue || demandQueue.length === 0) {
    return null;
  }

  const current = demandQueue[currentIndex];
  if (!current) {
    onClose();
    return null;
  }

  const handleAcceptDemand = (demand) => {
    // Accept the demand
    if (demand.type === 'bonus' && demand.cost > 0) {
      // Spend coins
      addResource('coins', -demand.cost);
    }

    // Improve morale
    updateMorale(current.agentId, 10);

    // Log
    addLogEntry({
      agentId: current.agentId,
      agentName: current.agentName,
      type: 'demand_accepted',
      message: `${current.agentName} accepted: "${demand.text}"`,
      emoji: '✅'
    });

    soundManager.playResourceCollect();
    moveToNext();
  };

  const handleRejectDemand = (demand) => {
    // Reject the demand
    if (current.mustResolve) {
      // Critical demand: agent deserts if denied
      desertAgent(current.agentId);
      addLogEntry({
        agentId: current.agentId,
        agentName: current.agentName,
        type: 'desertion',
        message: `${current.agentName} abandoned the island after you rejected their demand.`,
        emoji: '🚶'
      });
      soundManager.playNegative();
    } else {
      // Non-critical: morale drops further
      updateMorale(current.agentId, -5);
      addLogEntry({
        agentId: current.agentId,
        agentName: current.agentName,
        type: 'demand_rejected',
        message: `${current.agentName} is upset: you rejected their demand.`,
        emoji: '😠'
      });
      soundManager.playNegative();
    }

    moveToNext();
  };

  const moveToNext = () => {
    if (currentIndex < demandQueue.length - 1) {
      setCurrentIndex(currentIndex + 1);
      setResolvedCount(resolvedCount + 1);
    } else {
      // All demands resolved
      onClose();
    }
  };

  const demandOptions = current.demands || [];

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/70 backdrop-blur-sm z-50">
      <div className="w-full max-w-md rounded-lg border-2 border-purple-600 bg-slate-900 p-6 shadow-2xl">
        {/* Header */}
        <div className="mb-4">
          <div className="flex items-center justify-between mb-2">
            <h2 className="text-xl font-bold text-purple-400">💬 Agent Demand</h2>
            <div className="text-xs text-slate-400">
              {currentIndex + 1} / {demandQueue.length}
            </div>
          </div>
        </div>

        {/* Agent Info */}
        <div className="mb-4 rounded-lg bg-purple-900/20 border border-purple-600/50 p-4">
          <div className="font-semibold text-purple-300">{current.agentName}</div>
          <div className="text-sm text-purple-200 mt-1">
            Morale: <span className="font-bold">{current.morale}%</span>
          </div>

          {current.mustResolve && (
            <div className="mt-2 rounded px-2 py-1 bg-red-900/50 border border-red-600/50">
              <div className="text-xs font-bold text-red-300">⚠️ CRITICAL</div>
              <div className="text-xs text-red-200">Agent will leave if denied!</div>
            </div>
          )}
        </div>

        {/* Demands */}
        <div className="mb-4 space-y-2">
          {demandOptions.map((demand) => (
            <div
              key={demand.id}
              className="rounded-lg border border-slate-600 bg-slate-800 p-3"
            >
              <div className="font-semibold text-slate-200 mb-2">{demand.text}</div>

              {demand.cost > 0 && (
                <div className="text-xs text-yellow-300 mb-2">
                  💰 Costs: {demand.cost} coins
                </div>
              )}

              <div className="text-xs text-slate-400 mb-3">
                <span className="text-slate-500">If denied:</span> {demand.consequence}
              </div>

              {/* Accept/Reject Buttons */}
              <div className="flex gap-2">
                <button
                  onClick={() => handleAcceptDemand(demand)}
                  className="flex-1 rounded px-3 py-2 text-xs font-bold bg-green-600 hover:bg-green-500 text-white transition-all active:scale-95"
                >
                  Accept
                </button>
                <button
                  onClick={() => handleRejectDemand(demand)}
                  className={`flex-1 rounded px-3 py-2 text-xs font-bold transition-all active:scale-95 ${
                    current.mustResolve
                      ? 'bg-red-700 hover:bg-red-600 text-white'
                      : 'bg-slate-700 hover:bg-slate-600 text-slate-200'
                  }`}
                >
                  {current.mustResolve ? 'Reject (⚠️)' : 'Reject'}
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Progress Bar */}
        <div className="mb-3 h-1 rounded-full bg-slate-700">
          <div
            className="h-full rounded-full bg-purple-500 transition-all"
            style={{ width: `${((currentIndex + 1) / demandQueue.length) * 100}%` }}
          />
        </div>

        <div className="text-center text-xs text-slate-400">
          Resolving {currentIndex + 1} of {demandQueue.length} agent(s)
        </div>
      </div>
    </div>
  );
}

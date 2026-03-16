import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';
import { cardGenerator } from '../../utils/cardGenerator';
import { soundManager } from '../../utils/soundManager';
import ShareModal from './ShareModal';

export default function RiotModal() {
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const agents = useAgentStore((state) => state.agents);
  const crisisLog = useGameStore((state) => state.crisisLog);
  const getAverageMorale = useAgentStore((state) => state.getAverageMorale);
  const getProfit = useGameStore((state) => state.getProfit);
  const endSeason = useGameStore((state) => state.endSeason);
  const addRiotToHistory = useGameStore((state) => state.addRiotToHistory);

  const [showRiot, setShowRiot] = useState(false);
  const [riotCard, setRiotCard] = useState(null);
  const [showShareModal, setShowShareModal] = useState(false);

  // Check for riot on Sale Day
  useEffect(() => {
    if (day !== 7) return;

    const avgMorale = getAverageMorale();
    const profit = getProfit();
    const ignoredCrises = crisisLog.filter((log) => log.season === season).length === 0;
    const lowMoraleCount = agents.filter((a) => a.morale < 20).length;

    // Riot conditions
    const hasRiotRisk = lowMoraleCount > 0 && profit < 0 && ignoredCrises;
    if (hasRiotRisk) {
      const riotChance = Math.random();
      if (riotChance < 0.001) {
        // RIOT!
        setShowRiot(true);
      }
    }
  }, [day, agents, crisisLog, getAverageMorale, getProfit]);

  if (!showRiot) {
    return null;
  }

  const generateRoastReport = () => {
    const violations = [];
    agents.forEach((agent) => {
      if (agent.morale < 20) {
        violations.push(`${agent.name} - Severe morale violation (${agent.morale}%)`);
      }
    });

    const crisisCount = crisisLog.filter((log) => log.season === season).length;
    if (crisisCount > 5) {
      violations.push(`Ignored ${crisisCount} critical events`);
    }

    const profit = getProfit();
    if (profit < 0) {
      violations.push(`Operational loss of $${Math.abs(profit)}`);
    }

    return violations;
  };

  const violations = generateRoastReport();

  const roasts = [
    "Enron wishes they managed this badly.",
    "Your agents have formed a union. Good luck.",
    "This farm is a case study in bad management.",
    "Even the island is trying to leave.",
    "The ACA has decided to make this public."
  ];

  const roast = roasts[Math.floor(Math.random() * roasts.length)];

  const handleShareRiot = async () => {
    soundManager.play('shareCapture');
    const islandName = useGameStore.getState().islandName || 'Unknown Island';
    const card = await cardGenerator.generateCard('riot', {
      islandName,
      season,
      charges: violations,
      roast
    });
    setRiotCard(card);
    setShowShareModal(true);
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/90 backdrop-blur-sm z-50">
      <div className="w-full max-w-2xl rounded-lg border-4 border-red-600 bg-slate-900 p-8 shadow-2xl">
        <h1 className="text-4xl font-bold text-red-500 mb-2">🔥 AGENT CARETAKER ASSOCIATION VIOLATION 🔥</h1>
        <p className="text-red-400 text-sm mb-6">FARM ID: Island-{season}</p>

        {/* Violations */}
        <div className="bg-red-900/30 border border-red-700 rounded-lg p-4 mb-6">
          <h2 className="text-red-400 font-bold mb-2">Violations Found:</h2>
          <ul className="space-y-1">
            {violations.map((violation, idx) => (
              <li key={idx} className="text-red-300 text-sm">✗ {violation}</li>
            ))}
          </ul>
        </div>

        {/* Roast */}
        <div className="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4 mb-6">
          <p className="text-yellow-300 text-center text-lg italic font-semibold">"{roast}"</p>
        </div>

        {/* Summary */}
        <div className="text-slate-300 text-center text-sm mb-6">
          <p>Your island farm has been seized by the ACA.</p>
          <p>All agents have abandoned their posts.</p>
          <p className="mt-2 font-bold text-red-400">Season {season}: TOTAL LOSS</p>
        </div>

        {/* Continue Button */}
        <button
          onClick={() => {
            endSeason({ profit: getProfit(), finalMorale: getAverageMorale(), events: violations });
            setShowRiot(false);
          }}
          className="w-full rounded-lg bg-red-600 hover:bg-red-500 text-white font-bold py-3 transition-all active:scale-95"
        >
          🔄 Start Season {season + 1} (Learn & Retry)
        </button>

        {/* Share Violation Report */}
        <button
          onClick={handleShareRiot}
          className="w-full rounded-lg bg-yellow-600 hover:bg-yellow-500 text-white font-bold py-3 mt-2 transition-all active:scale-95"
        >
          📤 SHARE THIS SHAME
        </button>
      </div>

      {showShareModal && (
        <ShareModal
          card={riotCard}
          title="🔥 ACA Violation Report"
          onClose={() => setShowShareModal(false)}
        />
      )}
    </div>
  );
}

import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';

const STORAGE_KEY = 'agentville-onboarding-complete';

export default function OnboardingFlow() {
  const [isOpen, setIsOpen] = useState(false);
  const [stage, setStage] = useState(0); // 0=welcome, 1=rules, 2=goals, 3=done

  const islandName = useAgentStore((state) => state.islandName);
  const setIslandName = useAgentStore((state) => state.setIslandName);
  const agents = useAgentStore((state) => state.agents);
  const setGamePhase = useGameStore((state) => state.setGamePhase);

  useEffect(() => {
    const completed = localStorage.getItem(STORAGE_KEY) === 'true';
    if (!completed) {
      setIsOpen(true);
    } else {
      // If onboarding was completed before, make sure game phase is set
      if (useGameStore.getState().gamePhase === 'onboarding') {
        setGamePhase('playing');
      }
    }
  }, [setGamePhase]);

  const completeOnboarding = () => {
    localStorage.setItem(STORAGE_KEY, 'true');
    setGamePhase('playing');
    setIsOpen(false);
  };

  if (!isOpen) {
    return null;
  }

  const stages = [
    {
      title: '🏝️ Welcome to AgentVille',
      content: (
        <div className="space-y-4">
          <p className="text-lg text-slate-200">
            You've inherited an island farm with 3 agents. Your job: manage them, harvest resources, and maximize profit.
          </p>
          <p className="text-slate-300">
            Every week you'll face crises. Your decisions affect morale, resources, and the bottom line.
          </p>
          <div className="rounded-lg bg-blue-900/30 border border-blue-700 p-3">
            <p className="text-sm text-blue-200">
              <strong>Your agents:</strong> {agents.map((a) => a.name).join(', ')}
            </p>
          </div>
        </div>
      )
    },
    {
      title: '🎮 How to Play',
      content: (
        <div className="space-y-3">
          <div className="rounded bg-slate-800 p-2">
            <p className="font-semibold text-slate-200">1. Assign Zones</p>
            <p className="text-xs text-slate-400">Choose forest, plains, or wetlands for each agent. Specialists get +10% efficiency.</p>
          </div>
          <div className="rounded bg-slate-800 p-2">
            <p className="font-semibold text-slate-200">2. Advance Days</p>
            <p className="text-xs text-slate-400">Click "Next Day." Agents generate resources. Morale +1 if working, -2 if idle.</p>
          </div>
          <div className="rounded bg-slate-800 p-2">
            <p className="font-semibold text-slate-200">3. Handle Crises</p>
            <p className="text-xs text-slate-400">Each day brings 2 crises. Choose wisely—decisions affect morale + resources.</p>
          </div>
          <div className="rounded bg-slate-800 p-2">
            <p className="font-semibold text-slate-200">4. Sale Day</p>
            <p className="text-xs text-slate-400">Day 7: harvest sold, profit calculated, agents reviewed. Then season resets.</p>
          </div>
        </div>
      )
    },
    {
      title: '🎯 Your Goals',
      content: (
        <div className="space-y-3">
          <div className="rounded-lg bg-green-900/30 border border-green-700 p-3">
            <p className="text-sm text-green-300"><strong>Primary:</strong> Maximize profit each season</p>
          </div>
          <div className="rounded-lg bg-amber-900/30 border border-amber-700 p-3">
            <p className="text-sm text-amber-300"><strong>Challenge:</strong> Keep agents happy (morale 50+)</p>
          </div>
          <div className="rounded-lg bg-red-900/30 border border-red-700 p-3">
            <p className="text-sm text-red-300"><strong>Risk:</strong> Low morale + ignored crises = riot (0.001% chance per season)</p>
          </div>
          <p className="text-xs text-slate-400 mt-4">
            💡 Tip: Agents in their specialty zones gain +10% efficiency. Mismatched assignments cost -5%.
          </p>
        </div>
      )
    }
  ];

  const currentStage = stages[stage];

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/80 backdrop-blur-sm z-50">
      <div className="w-full max-w-2xl rounded-lg border-2 border-blue-600 bg-slate-900 p-8 shadow-2xl">
        <h1 className="text-3xl font-bold text-blue-400 mb-4">{currentStage.title}</h1>

        <div className="mb-6">{currentStage.content}</div>

        {/* Navigation */}
        <div className="flex gap-3 justify-between mt-8">
          <button
            onClick={() => setStage(Math.max(0, stage - 1))}
            disabled={stage === 0}
            className={`px-4 py-2 rounded font-semibold transition-all ${
              stage === 0
                ? 'bg-slate-700 text-slate-500 cursor-not-allowed'
                : 'bg-slate-700 hover:bg-slate-600 text-white'
            }`}
          >
            ← Back
          </button>

          <div className="flex gap-1">
            {stages.map((_, idx) => (
              <div
                key={idx}
                className={`h-2 w-8 rounded-full transition-all ${
                  idx === stage ? 'bg-blue-500' : 'bg-slate-700'
                }`}
              />
            ))}
          </div>

          <button
            onClick={() => {
              if (stage === stages.length - 1) {
                completeOnboarding();
              } else {
                setStage(stage + 1);
              }
            }}
            className="px-4 py-2 rounded font-semibold bg-blue-600 hover:bg-blue-500 text-white transition-all active:scale-95"
          >
            {stage === stages.length - 1 ? '✅ Start Game' : 'Next →'}
          </button>
        </div>

        {/* Skip Button */}
        <button
          onClick={completeOnboarding}
          className="w-full mt-4 text-xs text-slate-400 hover:text-slate-300 underline"
        >
          Skip Tutorial
        </button>
      </div>
    </div>
  );
}

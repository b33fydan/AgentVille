import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { generateCrisis, resolveCrisis, getCrisisDescription } from '../../utils/crisisEngine';
import { soundManager } from '../../utils/soundManager';

export default function CrisisModal() {
  const [currentCrisis, setCurrentCrisis] = useState(null);
  const [selectedChoice, setSelectedChoice] = useState(null);
  const [isResolving, setIsResolving] = useState(false);

  const agents = useAgentStore((state) => state.agents);
  const recordCrisis = useAgentStore((state) => state.recordCrisis);
  const season = useAgentStore((state) => state.season);

  // Generate a crisis at start or when modal is closed
  useEffect(() => {
    if (!currentCrisis && !isResolving) {
      // Automatically generate crisis
      const crisis = generateCrisis();
      setCurrentCrisis(crisis);
      setSelectedChoice(null);
      // Play alert sound
      soundManager.playCrisisAlert();
    }
  }, [currentCrisis, isResolving]);

  const handleChoice = (choiceIndex) => {
    setSelectedChoice(choiceIndex);
    setIsResolving(true);

    // Simulate resolution delay
    setTimeout(() => {
      const outcome = resolveCrisis(currentCrisis, choiceIndex);
      if (outcome) {
        // Record in crisis log
        recordCrisis({
          season: season.seasonNumber,
          day: season.currentDay,
          crisis: currentCrisis.id,
          choice: choiceIndex,
          outcome
        });

        // Play outcome sound
        if (outcome.moraleDelta > 0) {
          soundManager.playSaleSuccess();
        } else if (outcome.moraleDelta < 0) {
          soundManager.playNegative();
        } else {
          soundManager.playResourceCollect();
        }

        // TODO: Apply outcome to game state (morale, resources)
        // This will be wired to the store in AV-005
      }

      // Close modal
      setCurrentCrisis(null);
      setIsResolving(false);
    }, 800);
  };

  if (!currentCrisis) {
    return null;
  }

  const description = getCrisisDescription(currentCrisis, agents);
  const choice = selectedChoice !== null ? currentCrisis.choices[selectedChoice] : null;
  const isLoading = isResolving && selectedChoice !== null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="w-full max-w-md rounded-lg border-2 border-amber-600 bg-slate-900 p-6 shadow-2xl">
        {/* Crisis Title */}
        <h2 className="mb-2 text-2xl font-bold text-amber-400">⚠️ {currentCrisis.title}</h2>

        {/* Crisis Description */}
        <p className="mb-4 text-slate-300">{description}</p>

        {/* Choices */}
        <div className="mb-4 space-y-2">
          {currentCrisis.choices.map((option, index) => (
            <button
              key={index}
              onClick={() => handleChoice(index)}
              disabled={isLoading}
              className={`w-full rounded-lg border px-4 py-3 text-left transition-all ${
                selectedChoice === index
                  ? 'border-green-500 bg-green-900/50 text-green-300'
                  : isLoading
                    ? 'border-slate-600 bg-slate-800 text-slate-400 cursor-not-allowed'
                    : 'border-slate-600 bg-slate-800 text-slate-200 hover:border-amber-500 hover:bg-amber-900/30'
              }`}
            >
              <div className="flex items-start justify-between">
                <span>{option.text}</span>
                <span className={`ml-2 text-xs font-bold ${
                  option.moraleDelta > 0 ? 'text-green-300' :
                  option.moraleDelta < 0 ? 'text-red-300' : 'text-slate-400'
                }`}>
                  {option.moraleDelta > 0 ? '+' : ''}{option.moraleDelta}
                </span>
              </div>
              {/* Resource Delta Preview */}
              {option.resourceDelta && Object.keys(option.resourceDelta).length > 0 && (
                <div className="mt-1 text-xs text-slate-400">
                  {Object.entries(option.resourceDelta).map(([resource, delta]) => (
                    <div key={resource}>
                      {resource}: {delta > 0 ? '+' : ''}{Math.round(delta)}
                    </div>
                  ))}
                </div>
              )}
            </button>
          ))}
        </div>

        {/* Outcome (if resolving) */}
        {isLoading && choice && (
          <div className="rounded-lg border border-green-600 bg-green-900/20 p-3 text-center">
            <div className="text-sm font-semibold text-green-300">You chose:</div>
            <div className="text-xs text-green-200">{choice.text}</div>
            {choice.moraleDelta !== 0 && (
              <div className={`mt-1 text-xs font-bold ${choice.moraleDelta > 0 ? 'text-green-400' : 'text-red-400'}`}>
                Morale: {choice.moraleDelta > 0 ? '+' : ''}{choice.moraleDelta}
              </div>
            )}
          </div>
        )}

        {/* Resolving Indicator */}
        {isLoading && (
          <div className="mt-4 text-center">
            <div className="inline-flex items-center gap-2 rounded-lg bg-slate-800 px-3 py-2">
              <div className="h-2 w-2 animate-pulse rounded-full bg-amber-400" />
              <span className="text-xs text-slate-400">Resolving...</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

import { useEffect, useState } from 'react';
import { useAgentStore } from '../../store/agentStore';
import { useGameStore } from '../../store/gameStore';
import { useLogStore } from '../../store/logStore';
import {
  CrisisQueue,
  generateCrisis,
  resolveCrisis,
  enrichCrisisDescription,
  getAgentReactionQuote
} from '../../utils/crisisEngine';
import { soundManager } from '../../utils/soundManager';
import { selectReaction, getMoraleState } from '../../utils/agentReactions';

// Module-level singleton — survives component remounts
const crisisQueue = new CrisisQueue();

export default function CrisisModal() {
  const [currentCrisis, setCurrentCrisis] = useState(null);
  const [enrichedDescription, setEnrichedDescription] = useState('');
  const [selectedChoice, setSelectedChoice] = useState(null);
  const [isResolving, setIsResolving] = useState(false);

  const agents = useAgentStore((state) => state.agents);
  const updateMorale = useAgentStore((state) => state.updateMorale);
  const addResource = useGameStore((state) => state.addResource);
  const addCrisisToLog = useGameStore((state) => state.addCrisisToLog);
  const season = useGameStore((state) => state.season);
  const day = useGameStore((state) => state.day);
  const timeOfDay = useGameStore((state) => state.timeOfDay);
  const addLogEntry = useLogStore((state) => state.addLogEntry);

  // Check for crisis trigger on day/time change
  useEffect(() => {
    if (isResolving || currentCrisis) return; // Already has a crisis

    const newCrisis = crisisQueue.checkTrigger(season, day, timeOfDay);

    if (newCrisis) {
      setCurrentCrisis(newCrisis);
      setSelectedChoice(null);
      setEnrichedDescription(''); // Will be enriched
      soundManager.play('crisisAlert');
    }
  }, [season, day, timeOfDay, isResolving, currentCrisis]);

  // Enrich crisis description with Claude when crisis appears
  useEffect(() => {
    if (!currentCrisis || enrichedDescription) return;

    const enrich = async () => {
      const enriched = await enrichCrisisDescription(currentCrisis, agents);
      setEnrichedDescription(enriched);
    };

    enrich();
  }, [currentCrisis, agents, enrichedDescription]);

  // ===== OUTCOME CASCADE =====
  const applyOutcome = (outcome) => {
    if (!outcome) return;

    // 1. Apply morale delta to all agents (with threshold reactions)
    if (outcome.moraleDelta !== 0) {
      agents.forEach((agent) => {
        updateMorale(agent.id, outcome.moraleDelta, (agentId, agentName, traits, direction, threshold) => {
          // Log morale threshold crossing
          const isDropping = direction === 'down';
          if (isDropping) {
            const reaction = selectReaction('morale', 
              traits.workEthic < 30 ? 'lazy' : traits.risk < 30 ? 'nervous' : 'pragmatic',
              'low'
            );
            if (reaction) {
              addLogEntry({
                agentId,
                agentName,
                type: 'morale_crisis',
                message: `⚠️ Morale dropped below ${threshold}. ${reaction.text}`,
                emoji: '😟'
              });
            }
          } else {
            // Morale recovery
            const reaction = selectReaction('morale', 
              traits.workEthic > 70 ? 'bold' : 'cheerful',
              'good'
            );
            if (reaction) {
              addLogEntry({
                agentId,
                agentName,
                type: 'morale_recovery',
                message: `✨ Morale recovered above ${threshold}. ${reaction.text}`,
                emoji: '😊'
              });
            }
          }
        });
      });
    }

    // 2. Apply resource delta
    if (outcome.resourceDelta && Object.keys(outcome.resourceDelta).length > 0) {
      Object.entries(outcome.resourceDelta).forEach(([resource, delta]) => {
        if (delta !== 0) {
          addResource(resource, delta);
        }
      });
    }

    // 3. Log to Field Log with agent reactions
    addLogEntry({
      agentId: null,
      agentName: 'Crisis',
      type: 'crisis_resolution',
      message: `${outcome.crisisTitle}: "${outcome.choiceText}". ${outcome.consequenceText}`
    });

    // 4. Add agent reaction quotes (optional, adds personality)
    if (agents.length > 0) {
      // Pick 1-3 random agents to react
      const numReactions = Math.min(Math.ceil(agents.length / 2), 3);
      const shuffled = [...agents].sort(() => Math.random() - 0.5);
      
      for (let i = 0; i < numReactions; i++) {
        const agent = shuffled[i];
        if (!agent) break;
        
        // Determine outcome type based on morale delta
        let outcomeType = 'mixed';
        if (outcome.moraleDelta > 5) outcomeType = 'success';
        else if (outcome.moraleDelta < -5) outcomeType = 'failure';
        
        // Select trait-based reaction
        const primaryTrait = agent.traits.workEthic > 70 ? 'bold' :
                            agent.traits.workEthic < 30 ? 'lazy' :
                            agent.traits.risk > 70 ? 'bold' :
                            agent.traits.risk < 30 ? 'cautious' : 'pragmatic';
        
        const reaction = selectReaction('crisis', primaryTrait, outcomeType);
        if (reaction) {
          addLogEntry({
            agentId: agent.id,
            agentName: agent.name,
            type: 'crisis_reaction',
            message: reaction.text,
            emoji: reaction.emoji
          });
        }
      }
    }

    // 5. Record in game crisis log
    addCrisisToLog({
      season,
      day,
      crisis: currentCrisis.id,
      choice: outcome.choiceIndex,
      outcome
    });

    // 6. Play audio feedback
    if (outcome.moraleDelta > 0) {
      soundManager.play('crisisResolve');
    } else if (outcome.moraleDelta < 0) {
      soundManager.play('crisisResolveBad');
    } else {
      soundManager.play('crisisResolve');
    }

    // 7. Check for morale consequences (desertions, strikes, demands)
    // These will be shown as modals in sequence
    if (window.gameConsequences && window.gameConsequences.checkConsequences) {
      // Schedule consequences check for next tick (after modals update)
      setTimeout(() => {
        window.gameConsequences.checkConsequences();
      }, 100);
    }

    // TODO: Handle agent status changes (injured, recovering, etc.)
    // TODO: Handle follow-up crises (nextCrisisHint)
  };

  const handleChoice = (choiceIndex) => {
    setSelectedChoice(choiceIndex);
    setIsResolving(true);

    // Simulate resolution delay
    setTimeout(() => {
      const outcome = crisisQueue.resolveCrisis(currentCrisis.id, choiceIndex);

      if (outcome) {
        applyOutcome(outcome);
      }

      // Close modal
      setCurrentCrisis(null);
      setSelectedChoice(null);
      setEnrichedDescription('');
      setIsResolving(false);
    }, 800);
  };

  if (!currentCrisis) {
    return null;
  }

  const choice = selectedChoice !== null ? currentCrisis.choices[selectedChoice] : null;
  const isLoading = isResolving && selectedChoice !== null;
  const displayDescription = enrichedDescription || currentCrisis.baseDescription;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/70 backdrop-blur-sm z-40">
      <div className="w-full max-w-md rounded-lg border-2 border-amber-600 bg-slate-900 p-6 shadow-2xl">
        {/* Crisis Title */}
        <h2 className="mb-2 text-2xl font-bold text-amber-400">{currentCrisis.title}</h2>

        {/* Severity Badge */}
        {currentCrisis.severity && (
          <div className="mb-3 inline-block rounded px-2 py-1 text-xs font-bold">
            {currentCrisis.severity === 1 && <span className="bg-yellow-900/50 text-yellow-300">Minor</span>}
            {currentCrisis.severity === 2 && <span className="bg-orange-900/50 text-orange-300">Major</span>}
            {currentCrisis.severity === 3 && <span className="bg-red-900/50 text-red-300">CRITICAL</span>}
          </div>
        )}

        {/* Crisis Description (Claude-enriched or template) */}
        <p className="mb-4 text-slate-300">
          {displayDescription}
        </p>
        {enrichedDescription && (
          <p className="mb-2 text-xs text-slate-500">✨ Enhanced by Claude</p>
        )}

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
              {/* Choice Text + Morale Delta */}
              <div className="flex items-start justify-between">
                <span className="font-medium">{option.text}</span>
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

              {/* Consequence Text (what happens) */}
              {option.consequenceText && (
                <div className="mt-1 text-xs text-slate-400 italic">{option.consequenceText}</div>
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

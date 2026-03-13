import { useState, useEffect } from 'react';
import { useAgentStore } from '../store/agentStore';
import { useGameStore } from '../store/gameStore';
import DeserterModal from './ui/DeserterModal';
import StrikeModal from './ui/StrikeModal';
import AgentDemandsModal from './ui/AgentDemandsModal';
import { MoraleConsequenceQueue } from '../utils/moraleConsequences';

export default function ConsequencesHandler() {
  const [activeDesertions, setActiveDesertions] = useState([]);
  const [activeStrike, setActiveStrike] = useState(null);
  const [activeDemands, setActiveDemands] = useState([]);
  const [processingIndex, setProcessingIndex] = useState(0);

  const agents = useAgentStore((state) => state.agents);
  const day = useGameStore((state) => state.day);
  const season = useGameStore((state) => state.season);
  const getAverageMorale = useAgentStore((state) => state.getAverageMorale);

  // Process consequences when morale changes (triggered by a game event)
  // This is called from CrisisModal after outcome is applied
  const checkConsequences = () => {
    const queue = new MoraleConsequenceQueue();
    const avgMorale = getAverageMorale();

    // Check for desertions
    const desertions = queue.processDesertions(agents);
    if (desertions.length > 0) {
      setActiveDesertions(desertions);
    }

    // Check for strikes (on Sale Day: day 7)
    const strike = queue.checkStrike(avgMorale, day);
    if (strike) {
      setActiveStrike(strike);
    }

    // Generate demands for low-morale agents
    const demands = [];
    agents.forEach((agent) => {
      if (agent.morale < 50 && agent.morale >= 20) {
        const demand = queue.generateDemands(agent.id, agent.name, agent.morale, agent.traits);
        if (demand) {
          demands.push(demand);
        }
      }
    });
    if (demands.length > 0) {
      setActiveDemands(demands);
    }
  };

  const handleDeserterClose = () => {
    // Move to next desertion or close all
    const nextDesertions = activeDesertions.slice(1);
    if (nextDesertions.length > 0) {
      setActiveDesertions(nextDesertions);
    } else {
      // Check for strike next
      if (activeStrike) {
        // Strike modal will show after deserter closes
      } else if (activeDemands.length > 0) {
        // Demands modal will show after strike
      }
      setActiveDesertions([]);
    }
  };

  const handleStrikeClose = () => {
    setActiveStrike(null);
    // Check for demands next
    if (activeDemands.length > 0) {
      // Demands will show
    }
  };

  const handleDemandsClose = () => {
    setActiveDemands([]);
    setProcessingIndex(0);
  };

  // Expose checkConsequences to the game (will be called from CrisisModal)
  useEffect(() => {
    window.gameConsequences = { checkConsequences };
  }, [agents, day]);

  // Display modals in sequence: deserters -> strike -> demands
  if (activeDesertions.length > 0) {
    return <DeserterModal desertion={activeDesertions[0]} onClose={handleDeserterClose} />;
  }

  if (activeStrike) {
    return <StrikeModal strike={activeStrike} onClose={handleStrikeClose} />;
  }

  if (activeDemands.length > 0) {
    return <AgentDemandsModal demandQueue={activeDemands} onClose={handleDemandsClose} />;
  }

  return null;
}

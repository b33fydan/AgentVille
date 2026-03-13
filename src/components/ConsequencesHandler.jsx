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
    const newDesertions = [];
    const newDemands = [];

    // Check for desertions first
    agents.forEach((agent) => {
      if (agent.morale < 20) {
        const result = queue.checkDesertion(agent.id, agent.name, agent.morale);
        if (result) {
          newDesertions.push(result);
        }
      }
    });

    if (newDesertions.length > 0) {
      setActiveDesertions(newDesertions);
    }

    // Check for strikes (on Sale Day: day 7)
    const strike = queue.checkStrike(avgMorale, day);
    if (strike) {
      setActiveStrike(strike);
    }

    // Generate demands for low-morale agents (30-50 morale range)
    agents.forEach((agent) => {
      if (agent.morale >= 30 && agent.morale < 50) {
        const demand = queue.generateDemands(agent.id, agent.name, agent.morale, agent.traits);
        if (demand) {
          newDemands.push(demand);
        }
      }
    });

    if (newDemands.length > 0) {
      setActiveDemands(newDemands);
    }

    console.log(`[Consequences] Checked: ${newDesertions.length} desertions, ${newDemands.length} demands, strike=${!!strike}`);
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

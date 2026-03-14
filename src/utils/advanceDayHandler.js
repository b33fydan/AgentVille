// ============= ADVANCE DAY HANDLER =============
// Complete game loop logic for day advancement
// Orchestrates: resource generation, morale, crises, consequences, AUTONOMOUS DECISIONS

import { useGameStore } from '../store/gameStore';
import { useAgentStore } from '../store/agentStore';
import { useLogStore } from '../store/logStore';
import { soundManager } from './soundManager';
import { selectReaction } from './agentReactions';
import { DecisionMatrix, processAllAgentDecisions } from './agentDecisions';

const RESOURCE_OUTPUTS = {
  forest: { resource: 'wood', baseOutput: 5 },
  plains: { resource: 'wheat', baseOutput: 8 },
  wetlands: { resource: 'hay', baseOutput: 6 }
};

function calculateEfficiency(agent, zone) {
  // Morale: 0-100 → 0.2-1.0 multiplier
  const moraleMultiplier = 0.2 + (agent.morale / 100) * 0.8;

  // Work ethic bonus
  const workEthicBonus = (agent.traits?.workEthic || 50) / 100 * 0.2; // Up to +20%

  // Zone fit bonus (specialization match)
  let zoneFitBonus = 0;
  if (agent.traits?.specialization === zone) {
    zoneFitBonus = 0.15; // +15% for matching specialization
  }

  return Math.max(0.1, moraleMultiplier + workEthicBonus + zoneFitBonus);
}

export function advanceDayLogic() {
  const gameState = useGameStore.getState();
  const agentState = useAgentStore.getState();
  const logState = useLogStore.getState();

  // ===== 1. ADVANCE TIME =====
  console.log('[advanceDay] Starting day advance...');

  const currentPhase = gameState.gamePhase;
  const currentDay = gameState.day;
  const currentTime = gameState.timeOfDay;
  const agents = agentState.agents || [];

  // Only allow advancement if game is in playing state
  if (currentPhase !== 'playing' && currentPhase !== 'onboarding') {
    console.log('[advanceDay] Cannot advance during', currentPhase);
    return false;
  }

  // Advance time
  gameState.advanceTime();
  const newDay = gameState.day;
  const newTime = gameState.timeOfDay;

  console.log(`[advanceDay] Time: ${currentTime} → ${newTime}, Day: ${currentDay} → ${newDay}`);

  // ===== 1.5. APPLY NEED DRAINS & AUTONOMOUS DECISIONS =====
  // Agents age by hunger, fatigue, and equipment wear each day
  agents.forEach((agent) => {
    agentState.applyNeedsDrain(agent.id);
  });

  // Process autonomous decisions for all agents
  const decisions = processAllAgentDecisions(agents);
  
  decisions.forEach((decision) => {
    const agent = agents.find((a) => a.id === decision.agentId);
    if (!agent) return;

    // Log the decision
    const decisionEmoji = {
      'sleep': '😴',
      'eat': '🍖',
      'repair': '🔧',
      'work': '💼',
      'trade': '🤝',
      'idle': '🪑'
    }[decision.decision] || '?';

    logState.addLogEntry({
      agentId: decision.agentId,
      agentName: agent.name,
      type: 'autonomous_decision',
      message: `${agent.name} decided to ${decision.decision}: ${decision.reason}`,
      emoji: decisionEmoji,
      season: gameState.season,
      day: gameState.day
    });

    // Execute the decision
    switch (decision.decision) {
      case 'sleep':
        agentState.sleep(decision.agentId);
        break;

      case 'eat':
        agentState.eatFood(decision.agentId);
        break;

      case 'repair':
        agentState.repairEquipment(decision.agentId);
        break;

      case 'work':
        if (decision.selectedZone) {
          agentState.setAutonomousDecision(decision.agentId, 'working', decision.selectedZone);
        }
        break;

      case 'idle':
      default:
        agentState.setAutonomousDecision(decision.agentId, 'idle', null);
        break;
    }

    console.log(`[advanceDay] ${agent.name} → ${decision.decision} (priority: ${decision.priority})`);
  });

  // ===== 2. GENERATE RESOURCES =====
  agents.forEach((agent) => {
    if (agent.assignedZone && agent.status === 'working') {
      const zoneConfig = RESOURCE_OUTPUTS[agent.assignedZone];
      if (!zoneConfig) return;

      // Calculate efficiency from morale + traits + zone fit
      const moraleEfficiency = calculateEfficiency(agent, agent.assignedZone);
      
      // Apply need-based penalties (hunger/fatigue/equipment)
      const needsMultiplier = agentState.getAgentEfficiencyMultiplier(agent.id);
      
      const totalEfficiency = moraleEfficiency * needsMultiplier;
      const output = Math.floor(zoneConfig.baseOutput * totalEfficiency);

      if (output > 0) {
        gameState.addResource(zoneConfig.resource, output);
        soundManager.play('resourceGain');
        console.log(`[advanceDay] ${agent.name} produced ${output} ${zoneConfig.resource} (morale*${moraleEfficiency.toFixed(2)} × needs*${needsMultiplier.toFixed(2)})`);
      } else if (agent.fatigue > 90) {
        // Log work failure from exhaustion
        logState.addLogEntry({
          agentId: agent.id,
          agentName: agent.name,
          type: 'work_failure',
          message: `${agent.name} collapsed from exhaustion - produced nothing!`,
          emoji: '💔',
          season: gameState.season,
          day: gameState.day
        });
      }
    }
  });

  // ===== 3. PASSIVE MORALE CHANGES & NEED CONSEQUENCES =====
  agents.forEach((agent) => {
    // Unassigned agents lose morale
    if (!agent.assignedZone && agent.currentDecision !== 'sleeping' && agent.currentDecision !== 'eating' && agent.currentDecision !== 'repairing') {
      agentState.updateMorale(agent.id, -2);
    }

    // Critical need consequences
    if (agent.hunger > 80) {
      logState.addLogEntry({
        agentId: agent.id,
        agentName: agent.name,
        type: 'need_crisis',
        message: `${agent.name} is STARVING (${agent.hunger}% hunger) - working at reduced capacity!`,
        emoji: '🍖',
        season: gameState.season,
        day: gameState.day
      });
      agentState.updateMorale(agent.id, -5); // Morale hit from starvation
    }

    if (agent.fatigue > 90) {
      logState.addLogEntry({
        agentId: agent.id,
        agentName: agent.name,
        type: 'need_crisis',
        message: `${agent.name} is EXHAUSTED (${agent.fatigue}% fatigue) - about to collapse!`,
        emoji: '😴',
        season: gameState.season,
        day: gameState.day
      });
      agentState.updateMorale(agent.id, -10); // Severe morale hit from exhaustion
    }

    if (agent.equipmentWear > 90) {
      logState.addLogEntry({
        agentId: agent.id,
        agentName: agent.name,
        type: 'need_crisis',
        message: `${agent.name}'s equipment is BROKEN (${agent.equipmentWear}% wear) - needs immediate repair!`,
        emoji: '🔧',
        season: gameState.season,
        day: gameState.day
      });
    }

    // Very low morale agents complain
    if (agent.morale < 30) {
      logState.addLogEntry({
        agentId: agent.id,
        agentName: agent.name,
        type: 'complaint',
        message: `${agent.name} is very unhappy... (${agent.morale}% morale)`,
        emoji: '😢',
        season: gameState.season,
        day: gameState.day
      });
    }
  });

  // ===== 4. TRIGGER CRISIS (50% chance, max 1 active) =====
  const shouldTriggerCrisis = Math.random() < 0.5;
  if (shouldTriggerCrisis) {
    console.log('[advanceDay] Crisis triggered! Setting gamePhase to "crisis"');
    // This will cause CrisisModal to render and handle the crisis
    gameState.setGamePhase('crisis');
    soundManager.play('crisisAlert');
  }

  // ===== 5. CHECK MORALE CONSEQUENCES (desertions) =====
  agents.forEach((agent) => {
    if (agent.morale < 20 && Math.random() < 0.3) {
      console.log(`[advanceDay] ${agent.name} is abandoning the island!`);
      // Consequence system will handle this via modal
      logState.addLogEntry({
        agentId: agent.id,
        agentName: agent.name,
        type: 'desertion_risk',
        message: `${agent.name} is considering leaving...`,
        emoji: '🚶',
        season: gameState.season,
        day: gameState.day
      });
    }
  });

  // ===== 6. AMBIENT REACTIONS =====
  if (newTime === 'morning' || newTime === 'evening') {
    const numReactions = Math.random() > 0.5 ? 1 : 2;
    const shuffled = [...agents].sort(() => Math.random() - 0.5);

    for (let i = 0; i < Math.min(numReactions, shuffled.length); i++) {
      const agent = shuffled[i];
      const primaryTrait =
        agent.traits.workEthic > 70
          ? 'bold'
          : agent.traits.workEthic < 30
            ? 'lazy'
            : 'pragmatic';

      const reaction = selectReaction('dayChange', primaryTrait, newTime === 'morning' ? 'morning' : 'evening');
      if (reaction && Math.random() > 0.3) {
        logState.addLogEntry({
          agentId: agent.id,
          agentName: agent.name,
          type: 'ambient',
          message: reaction.text,
          emoji: reaction.emoji,
          season: gameState.season,
          day: gameState.day
        });
      }
    }
  }

  // ===== 7. CHECK SALE DAY (day > 7) - Reset needs for next season =====
  if (newDay > 7) {
    console.log('[advanceDay] SALE DAY triggered!');
    agentState.resetNeedsForNewSeason();
    useGameStore.getState().setGamePhase('saleDay');
    soundManager.play('profitReveal');
    return true;
  }

  // ===== 8. PLAY SOUND =====
  soundManager.play('dayAdvance');

  console.log('[advanceDay] Day advance complete');
  return true;
}

// ===== STATE HELPERS =====

export function canAdvanceDay() {
  const gamePhase = useGameStore.getState().gamePhase;
  return gamePhase === 'playing' || gamePhase === 'onboarding';
}

export function getAdvanceButtonLabel(day, timeOfDay) {
  if (day >= 7 && timeOfDay === 'evening') {
    return '📦 BEGIN SALE DAY';
  }
  if (timeOfDay === 'morning') {
    return '☀️ ADVANCE TO EVENING';
  }
  return '🌙 ADVANCE TO NEXT DAY';
}

export function getAdvanceButtonColor(day, timeOfDay) {
  if (day >= 7 && timeOfDay === 'evening') {
    return '#f59e0b'; // gold
  }
  if (timeOfDay === 'morning') {
    return '#22c55e'; // green
  }
  return '#6366f1'; // indigo
}

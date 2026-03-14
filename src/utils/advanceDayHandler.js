// ============= ADVANCE DAY HANDLER =============
// Complete game loop logic for day advancement
// Orchestrates: resource generation, morale, crises, consequences

import { useGameStore } from '../store/gameStore';
import { useAgentStore } from '../store/agentStore';
import { useLogStore } from '../store/logStore';
import { soundManager } from './soundManager';
import { selectReaction } from './agentReactions';

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

  // ===== 2. GENERATE RESOURCES =====
  agents.forEach((agent) => {
    if (agent.assignedZone && agent.status === 'working') {
      const zoneConfig = RESOURCE_OUTPUTS[agent.assignedZone];
      if (!zoneConfig) return;

      const efficiency = calculateEfficiency(agent, agent.assignedZone);
      const output = Math.floor(zoneConfig.baseOutput * efficiency);

      if (output > 0) {
        gameState.addResource(zoneConfig.resource, output);
        soundManager.play('resourceGain');
        console.log(`[advanceDay] ${agent.name} produced ${output} ${zoneConfig.resource}`);
      }
    }
  });

  // ===== 3. PASSIVE MORALE CHANGES =====
  agents.forEach((agent) => {
    // Unassigned agents lose morale
    if (!agent.assignedZone) {
      agentState.updateMorale(agent.id, -2);
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
  const shouldTriggerCrisis = Math.random() < 0.5 && !gameState.activeCrisis;
  if (shouldTriggerCrisis) {
    // For now, just mark that a crisis should trigger
    // The actual CrisisModal will handle this on next render
    console.log('[advanceDay] Crisis should trigger (CrisisModal will handle)');
    soundManager.play('crisisAlert');
    // CrisisModal component watches for gamePhase changes
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

  // ===== 7. CHECK SALE DAY (day > 7) =====
  if (newDay > 7) {
    console.log('[advanceDay] SALE DAY triggered!');
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

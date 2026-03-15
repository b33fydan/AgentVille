// ============= AGENT CONFLICT SYSTEM =============
// Theft, alliances, boycotts, reputation system

import { useAgentStore } from '../store/agentStore';
import { useLogStore } from '../store/logStore';

export class ConflictEngine {
  constructor() {
    this.alliances = []; // Array of { leader: agentId, members: [agentIds] }
    this.conflicts = []; // Array of active conflicts
  }

  /**
   * Attempt theft based on desperation and opportunity
   * Returns: { attempted, successful, stolenAmount, targetAgent }
   */
  attemptTheft(agent, targetAgent, gameState) {
    const agentStore = useAgentStore.getState();
    const logStore = useLogStore.getState();

    const result = {
      attempted: false,
      successful: false,
      stolenAmount: 0,
      targetAgent: targetAgent.name,
      reason: ''
    };

    // Only desperate agents (hunger > 70 OR coins < 5) attempt theft
    const isDesperate = agent.hunger > 70 || (agent.inventory?.coins || 0) < 5;
    if (!isDesperate) {
      return result;
    }

    result.attempted = true;

    // Success chance: risky agents have better chance
    const riskFactor = (agent.traits?.risk || 50) / 100; // 0-1
    const successChance = riskFactor * 0.8; // 0-80% chance

    if (Math.random() > successChance) {
      // Failed theft!
      result.successful = false;
      result.reason = 'Caught red-handed';

      // Damage reputation severely
      agentStore.updateAgentRelationship(agent.id, targetAgent.id, -50);
      agentStore.updateAgentRelationship(targetAgent.id, agent.id, -50);

      // Target might boycott thief
      if (Math.random() < 0.7) {
        agentStore.boycottAgent(targetAgent.id, agent.id);
      }

      logStore.addLogEntry({
        id: `theft-attempt-${Date.now()}`,
        agentId: agent.id,
        agentName: agent.name,
        type: 'conflict_theft_caught',
        message: `${agent.name} CAUGHT trying to steal from ${targetAgent.name}! 😲`,
        emoji: '😲',
        season: gameState.season,
        day: gameState.day
      });

      return result;
    }

    // Successful theft!
    result.successful = true;

    // Steal a random amount of food (wheat is preferred)
    const targetWheat = targetAgent.inventory?.wheat || 0;
    const targetWood = targetAgent.inventory?.wood || 0;
    const targetHay = targetAgent.inventory?.hay || 0;

    let stolenResource = 'wheat';
    let stolenAmount = Math.min(10, Math.floor(targetWheat * 0.5)); // Steal up to half their wheat

    if (stolenAmount === 0) {
      // Try wood or hay instead
      stolenResource = Math.random() > 0.5 ? 'wood' : 'hay';
      stolenAmount = Math.min(5, Math.floor((targetResource[stolenResource] || 0) * 0.5));
    }

    if (stolenAmount > 0) {
      agentStore.removeResourceFromInventory(targetAgent.id, stolenResource, stolenAmount);
      agentStore.addResourceToInventory(agent.id, stolenResource, stolenAmount);

      result.stolenAmount = stolenAmount;
    }

    // Damage relationship
    agentStore.updateAgentRelationship(agent.id, targetAgent.id, -30);
    agentStore.updateAgentRelationship(targetAgent.id, agent.id, -40);

    // Target will likely boycott
    if (Math.random() < 0.9) {
      agentStore.boycottAgent(targetAgent.id, agent.id);
    }

    // Record theft
    agentStore.recordTrade(agent.id, false, stolenResource, stolenAmount, 0);

    logStore.addLogEntry({
      id: `theft-success-${Date.now()}`,
      agentId: agent.id,
      agentName: agent.name,
      type: 'conflict_theft_success',
      message: `${agent.name} stole ${stolenAmount} ${stolenResource} from ${targetAgent.name}! 😡`,
      emoji: '😡',
      season: gameState.season,
      day: gameState.day
    });

    return result;
  }

  /**
   * Form alliance between leader and member
   */
  formAlliance(leaderAgent, memberAgent) {
    const agentStore = useAgentStore.getState();

    // Find or create alliance
    let alliance = this.alliances.find((a) => a.leader === leaderAgent.id);

    if (!alliance) {
      alliance = {
        leader: leaderAgent.id,
        members: [],
        formedDay: 1,
        purpose: 'resource_control' // or 'mutual_defense', 'trading_cartel'
      };
      this.alliances.push(alliance);
    }

    if (!alliance.members.includes(memberAgent.id)) {
      alliance.members.push(memberAgent.id);
      agentStore.updateAgentRelationship(leaderAgent.id, memberAgent.id, 30);
      agentStore.updateAgentRelationship(memberAgent.id, leaderAgent.id, 30);
    }

    return alliance;
  }

  /**
   * Alliance members benefit from cooperative pricing
   */
  getAllianceDiscount(agent, targetAgent) {
    const alliance = this.alliances.find(
      (a) => a.members.includes(agent.id) && a.members.includes(targetAgent.id)
    );

    if (alliance) {
      return 0.9; // 10% discount for allies
    }

    return 1.0; // No discount
  }

  /**
   * Simulate agent-to-agent conflict and resolution
   */
  simulateConflict(agents, gameState) {
    const logStore = useLogStore.getState();

    // 10% chance of conflict each day
    if (Math.random() > 0.1) return;

    const agentA = agents[Math.floor(Math.random() * agents.length)];
    const agentB = agents[Math.floor(Math.random() * agents.length)];

    if (agentA.id === agentB.id) return;

    // Determine conflict type based on relationship
    const trust = agentA.relationships?.[agentB.id]?.trust || 0;

    let conflictType = '';
    let resolution = '';

    if (trust < -50) {
      // High tension: theft or boycott
      if (Math.random() < 0.6) {
        this.attemptTheft(agentA, agentB, gameState);
        return; // Theft already logged
      } else {
        conflictType = 'trade_refusal';
        resolution = `${agentA.name} refuses to trade with ${agentB.name} - trust too low`;
      }
    } else if (trust > 50) {
      // High trust: potential alliance
      if (Math.random() < 0.4) {
        const alliance = this.formAlliance(agentA, agentB);
        conflictType = 'alliance';
        resolution = `${agentA.name} and ${agentB.name} formed an alliance!`;

        logStore.addLogEntry({
          id: `alliance-${Date.now()}`,
          agentId: agentA.id,
          agentName: agentA.name,
          type: 'alliance_formed',
          message: resolution,
          emoji: '🤝',
          season: gameState.season,
          day: gameState.day
        });
      }
      return;
    } else {
      // Neutral: normal negotiation
      return;
    }

    if (conflictType && resolution) {
      logStore.addLogEntry({
        id: `conflict-${Date.now()}`,
        agentId: agentA.id,
        agentName: agentA.name,
        type: 'conflict_' + conflictType,
        message: resolution,
        emoji: '⚔️',
        season: gameState.season,
        day: gameState.day
      });
    }
  }

  /**
   * Update agent reputation based on behavior
   */
  updateReputation(agent, action, delta) {
    const agentStore = useAgentStore.getState();

    agentStore.updateAgentTraits(agent.id, {});

    // Directly modify reputation in agent object
    // This is a bit hacky but necessary for real-time update
    agent.reputation = Math.max(0, Math.min(100, (agent.reputation || 50) + delta));
  }

  /**
   * Clear old boycotts (after N days)
   */
  decayBoycotts(agents, currentDay, decayDays = 14) {
    const agentStore = useAgentStore.getState();

    agents.forEach((agent) => {
      if (agent.boycottList?.length > 0) {
        agent.boycottList.forEach((targetId) => {
          const relationship = agent.relationships?.[targetId];
          
          // Decay: reduce negative trust over time
          if (relationship && relationship.lastInteraction) {
            const daysSinceInteraction = currentDay - Math.floor(relationship.lastInteraction / 1000 / 86400);
            
            if (daysSinceInteraction > decayDays) {
              agentStore.removeFromBoycott(agent.id, targetId);
              agentStore.updateAgentRelationship(agent.id, targetId, 20); // Slight recovery
            }
          }
        });
      }
    });
  }

  /**
   * Get conflict summary for a given agent
   */
  getConflictSummary(agent) {
    return {
      boycottCount: agent.boycottList?.length || 0,
      allyCount: this.alliances
        .filter((a) => a.members.includes(agent.id) || a.leader === agent.id)
        .reduce((sum, a) => sum + a.members.length, 0),
      averageTrust: Object.values(agent.relationships || {})
        .reduce((sum, r) => sum + r.trust, 0) / Math.max(1, Object.keys(agent.relationships || {}).length),
      reputation: agent.reputation || 50
    };
  }
}

// ============= SINGLETON =============
export const conflictEngine = new ConflictEngine();

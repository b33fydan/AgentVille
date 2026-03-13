// ============= Morale Consequences Engine =============
// Handles desertions, strikes, agent demands based on morale thresholds

export class MoraleConsequenceQueue {
  constructor() {
    this.pendingDesertions = []; // [{ agentId, agentName, morale, day }]
    this.strikeActive = false; // Boolean: team refused to work this season
    this.agentDemands = []; // [{ agentId, agentName, demand, severity }]
    this.recoverySchedule = []; // [{ agentId, agentName, daysRemaining }]
  }

  // ===== DESERTIONS =====
  // Agent leaves if morale < 20 (daily roll)
  checkDesertion(agentId, agentName, morale) {
    if (morale < 20) {
      // Daily roll: 30% chance to leave
      if (Math.random() < 0.3) {
        return {
          type: 'desertion',
          agentId,
          agentName,
          morale,
          message: `${agentName} has abandoned the island.`,
          severity: morale < 10 ? 'critical' : 'major'
        };
      }
    }
    return null;
  }

  // Process desertions at day end
  processDesertions(agents) {
    const desertions = [];
    agents.forEach((agent) => {
      if (agent.morale < 20) {
        const result = this.checkDesertion(agent.id, agent.name, agent.morale);
        if (result) {
          desertions.push(result);
        }
      }
    });
    return desertions;
  }

  // ===== STRIKES =====
  // If avg morale < 40 on Sale Day, team refuses to work
  checkStrike(avgMorale, day) {
    // Strike only triggered on Sale Day (day 7 evening)
    if (day !== 7) return null;

    if (avgMorale < 40) {
      return {
        type: 'strike',
        avgMorale,
        message: 'The team is refusing to work! Morale is too low.',
        severity: 'critical',
        resourceMultiplier: 0.5, // Reduce all harvest by 50%
        consequences: [
          'All agents refuse work',
          'Resources only 50% harvested',
          'No profit bonus for high efficiency',
          'Team demands compensation'
        ]
      };
    }

    return null;
  }

  // ===== AGENT DEMANDS =====
  // Low morale → agents request bonuses, time off, etc.
  generateDemands(agentId, agentName, morale, traits) {
    if (morale >= 50) return null; // Only low morale agents demand

    const severityLevels = {
      low: 40, // 40-49 morale: mild request
      medium: 30, // 30-39 morale: serious demand
      critical: 0 // < 30 morale: ultimatum
    };

    let severity = 'low';
    if (morale < 30) severity = 'critical';
    else if (morale < 40) severity = 'medium';

    // Demand type based on traits
    const demands = [];

    if (traits.workEthic < 30 || severity === 'critical') {
      demands.push({
        id: `demand-bonus-${agentId}`,
        type: 'bonus',
        text: 'Demand: +5 coin bonus (or I leave)',
        cost: 5,
        consequence: 'If denied: agent deserts',
        severity
      });
    }

    if (traits.risk > 70 || severity === 'critical') {
      demands.push({
        id: `demand-risk-${agentId}`,
        type: 'challenge',
        text: 'Demand: Assign me to the hardest zone (or I leave)',
        cost: 0, // No coin cost, but risky
        consequence: 'If denied: agent deserts',
        severity
      });
    }

    if (traits.loyalty < 40 || severity === 'critical') {
      demands.push({
        id: `demand-timeoff-${agentId}`,
        type: 'timeoff',
        text: 'Demand: 2 days off next season (or I leave)',
        cost: 0, // No direct cost, but productivity hit
        consequence: 'If denied: agent deserts',
        severity
      });
    }

    // Everyone can make a basic bonus demand
    if (demands.length === 0) {
      demands.push({
        id: `demand-coin-${agentId}`,
        type: 'bonus',
        text: 'Request: +3 coin bonus',
        cost: 3,
        consequence: 'If denied: morale drops further',
        severity: 'low'
      });
    }

    return {
      agentId,
      agentName,
      morale,
      demands,
      mustResolve: severity === 'critical'
    };
  }

  // ===== RECOVERY SCHEDULING =====
  // Injured agents need rest before returning
  scheduleRecovery(agentId, agentName, daysNeeded = 2) {
    return {
      agentId,
      agentName,
      status: 'recovering',
      daysRemaining: daysNeeded,
      message: `${agentName} is recovering and can't work for ${daysNeeded} days.`
    };
  }

  decrementRecovery() {
    return this.recoverySchedule.map((recovery) => ({
      ...recovery,
      daysRemaining: Math.max(0, recovery.daysRemaining - 1)
    })).filter((r) => r.daysRemaining > 0);
  }

  // ===== CRISIS -> CONSEQUENCE MAPPING =====
  // Apply morale delta from crisis, check all consequences
  applyConsequence(agents, crisisOutcome, day, avgMorale) {
    const results = {
      desertions: [],
      strikes: null,
      demands: []
    };

    // 1. Check desertions (if any agent morale < 20)
    results.desertions = this.processDesertions(agents);

    // 2. Check for strikes (if avg morale < 40 on day 7)
    results.strikes = this.checkStrike(avgMorale, day);

    // 3. Generate demands (for agents with morale 30-50)
    agents.forEach((agent) => {
      if (agent.morale < 50 && agent.morale >= 20) {
        const demand = this.generateDemands(agent.id, agent.name, agent.morale, agent.traits);
        if (demand) {
          results.demands.push(demand);
        }
      }
    });

    return results;
  }
}

// ============= Helper: Get consequence severity color =============
export function getConsequenceSeverityColor(severity) {
  if (severity === 'critical') return 'border-red-600/50 bg-red-900/20 text-red-100';
  if (severity === 'major') return 'border-orange-600/50 bg-orange-900/20 text-orange-100';
  return 'border-yellow-600/50 bg-yellow-900/20 text-yellow-100';
}

// ============= Helper: Format consequence display =============
export function formatConsequence(consequence) {
  if (consequence.type === 'desertion') {
    return {
      title: `❌ AGENT DESERTED`,
      subtitle: consequence.agentName,
      message: consequence.message,
      severity: consequence.severity,
      icon: '🚶‍♂️'
    };
  }

  if (consequence.type === 'strike') {
    return {
      title: `⛔ STRIKE!`,
      subtitle: 'Team refuses to work',
      message: consequence.message,
      severity: consequence.severity,
      icon: '✊',
      consequences: consequence.consequences,
      resourceMultiplier: consequence.resourceMultiplier
    };
  }

  return null;
}

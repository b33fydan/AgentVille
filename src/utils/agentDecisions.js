// ============= AGENT DECISIONS ENGINE =============
// Autonomous decision-making based on agent needs and personality
// Each agent evaluates: sleep? eat? work? trade? idle?

export class DecisionMatrix {
  constructor(agent) {
    this.agent = agent;
    this.traits = agent.traits || {};
  }

  /**
   * Evaluate agent's top priority action based on needs
   * Returns: { action, priority, reason, isUrgent }
   */
  evaluatePriority() {
    const { hunger, fatigue, equipmentWear } = this.agent;

    // Critical urgency thresholds
    const isStarving = hunger > 80;
    const isExhausted = fatigue > 90;
    const isEquipmentBroken = equipmentWear > 90;

    // Calculate priority scores (0-100)
    const hungerPriority = this.calculateHungerPriority(hunger);
    const fatiguePriority = this.calculateFatiguePriority(fatigue);
    const equipmentPriority = this.calculateEquipmentPriority(equipmentWear);
    const workPriority = this.calculateWorkPriority(hunger, fatigue);

    // If agent is in crisis, override everything
    if (isStarving) {
      return {
        action: 'eat',
        priority: 100,
        reason: 'STARVING - must eat immediately',
        isUrgent: true
      };
    }

    if (isExhausted) {
      return {
        action: 'sleep',
        priority: 100,
        reason: 'EXHAUSTED - must rest immediately',
        isUrgent: true
      };
    }

    if (isEquipmentBroken) {
      return {
        action: 'repair',
        priority: 95,
        reason: 'Equipment critically damaged',
        isUrgent: true
      };
    }

    // Normal priority evaluation (highest wins)
    const priorities = {
      sleep: fatiguePriority,
      eat: hungerPriority,
      repair: equipmentPriority,
      work: workPriority,
      trade: 10, // Lower baseline
      idle: 5
    };

    const selectedAction = Object.keys(priorities).reduce((a, b) =>
      priorities[a] > priorities[b] ? a : b
    );

    return {
      action: selectedAction,
      priority: priorities[selectedAction],
      reason: this.getReasonForAction(selectedAction, hunger, fatigue, equipmentWear),
      isUrgent: priorities[selectedAction] > 70
    };
  }

  calculateHungerPriority(hunger) {
    // Hunger scales from 0 to 100
    // At 0: priority 0, at 100: priority 100
    if (hunger < 30) return 5; // Not hungry
    if (hunger < 60) return 40; // Moderately hungry
    if (hunger < 80) return 75; // Very hungry
    return 100; // Critical
  }

  calculateFatiguePriority(fatigue) {
    // Personality modifier: cautious types sleep early, risk-takers push through
    let basePriority = 0;

    if (fatigue < 40) basePriority = 5;
    else if (fatigue < 70) basePriority = 50;
    else if (fatigue < 90) basePriority = 80;
    else basePriority = 100;

    // Risk-takers ignore fatigue (subtract up to 30%)
    const riskModifier = (this.traits.risk || 50) / 100; // 0-1
    if (riskModifier > 0.7) {
      basePriority *= 0.7; // -30% for high-risk agents
    }

    // Cautious types sleep early (add up to 20%)
    const cautionFactor = 1 - riskModifier;
    if (cautionFactor > 0.7) {
      basePriority *= 1.2; // +20% for cautious agents
    }

    return Math.min(100, basePriority);
  }

  calculateEquipmentPriority(wear) {
    // Equipment scales from 0 to 100
    if (wear < 40) return 5; // Acceptable
    if (wear < 70) return 35; // Deteriorating
    if (wear < 90) return 65; // Poor condition
    return 95; // Critical
  }

  calculateWorkPriority(hunger, fatigue) {
    // Work priority is inverse to needs
    // High work ethic agents push through needs
    const workEthic = (this.traits.workEthic || 50) / 100; // 0-1

    let basePriority = 50;

    // Reduce work priority if hungry or tired
    if (hunger > 60) basePriority -= 30;
    if (fatigue > 70) basePriority -= 40;

    // Work ethic modifier: overachievers work anyway
    if (workEthic > 0.7) {
      basePriority += 20;
    } else if (workEthic < 0.3) {
      basePriority -= 20; // Lazy agents avoid work
    }

    return Math.max(0, basePriority);
  }

  getReasonForAction(action, hunger, fatigue, wear) {
    switch (action) {
      case 'eat':
        return hunger > 60 ? 'Feeling hungry' : 'Should grab some food';
      case 'sleep':
        return fatigue > 70 ? 'Very tired' : 'Could use some rest';
      case 'repair':
        return wear > 70 ? 'Equipment degrading' : 'Equipment needs maintenance';
      case 'work':
        return 'Ready to work';
      case 'trade':
        return 'Considering trading';
      case 'idle':
        return 'Taking a break';
      default:
        return 'Idle';
    }
  }

  /**
   * Determine which zone the agent will self-assign to
   * High-risk: seek forest (dangerous, lucrative)
   * Cautious: seek plains (safe, steady)
   * Lazy: avoid work, prefer idle
   */
  selectZone() {
    const { risk, workEthic, specialization } = this.traits;
    const { hunger, fatigue } = this.agent;

    // If too tired/hungry, don't work
    if (hunger > 60 || fatigue > 70) {
      return null;
    }

    // Lazy agents try to avoid work
    if (workEthic < 30 && Math.random() < 0.4) {
      return null;
    }

    // Risk-takers prefer forest (high danger, high reward)
    if (risk > 70) {
      return Math.random() > 0.3 ? 'forest' : 'plains';
    }

    // Cautious agents prefer plains (safe, steady)
    if (risk < 30) {
      return Math.random() > 0.3 ? 'plains' : 'forest';
    }

    // Specialization match
    if (Math.random() > 0.5) {
      return specialization;
    }

    // Default to plains
    return 'plains';
  }

  /**
   * Evaluate trading decision based on prices and inventory
   * Returns: { shouldTrade, resource, action }
   */
  evaluateTrading(prices) {
    const { wood, wheat, hay, coins } = this.agent.inventory || {};
    const workEthic = this.traits.workEthic || 50;

    // Don't trade if risk-averse and prices haven't changed much
    if (workEthic < 30) return null;

    // High wood supply: sell wood, buy wheat
    if (prices.wheat > prices.wood * 1.5 && (wood || 0) > 20) {
      return { shouldTrade: true, sell: 'wood', buy: 'wheat', reason: 'Selling cheap wood, buying expensive wheat' };
    }

    // High wheat supply: sell wheat, buy wood
    if (prices.wood > prices.wheat * 1.5 && (wheat || 0) > 20) {
      return { shouldTrade: true, sell: 'wheat', buy: 'wood', reason: 'Selling cheap wheat, buying expensive wood' };
    }

    // Low coins: sell excess resources
    if ((coins || 0) < 10 && (wood || 0) > 30) {
      return { shouldTrade: true, sell: 'wood', buy: null, reason: 'Need coins, selling wood' };
    }

    if ((coins || 0) < 10 && (wheat || 0) > 20) {
      return { shouldTrade: true, sell: 'wheat', buy: null, reason: 'Need coins, selling wheat' };
    }

    return null;
  }

  /**
   * Check if agent will rebel or refuse orders
   * Returns true if agent should refuse player commands
   */
  shouldRefuseOrder() {
    const { hunger, fatigue } = this.agent;

    // Rebellion conditions:
    // - Starving: 60% chance to refuse
    // - Exhausted: 80% chance to refuse
    // - Broken equipment: 40% chance to refuse

    if (hunger > 80) return Math.random() < 0.6;
    if (fatigue > 90) return Math.random() < 0.8;

    return false;
  }

  /**
   * Get visual feedback for agent's state
   * Used for animation modifiers
   */
  getStateModifiers() {
    const { hunger, fatigue, equipmentWear } = this.agent;

    return {
      // Movement speed (0.2 = very slow, 1.0 = normal)
      speedMultiplier: this.calculateSpeedMultiplier(hunger, fatigue),

      // Posture (slouched, stumbling, etc.)
      posture: this.calculatePosture(hunger, fatigue),

      // Whether agent can work at full efficiency
      canWork: hunger < 80 && fatigue < 90,

      // Work efficiency penalty
      efficiencyPenalty: this.calculateEfficiencyPenalty(hunger, fatigue, equipmentWear)
    };
  }

  calculateSpeedMultiplier(hunger, fatigue) {
    let multiplier = 1.0;

    // Hunger slowdown
    if (hunger > 80) multiplier *= 0.3; // Very slow
    else if (hunger > 60) multiplier *= 0.6;
    else if (hunger > 40) multiplier *= 0.8;

    // Fatigue slowdown (stacks)
    if (fatigue > 90) multiplier *= 0.2; // Nearly stopped
    else if (fatigue > 70) multiplier *= 0.5;
    else if (fatigue > 50) multiplier *= 0.7;

    return Math.max(0.2, multiplier); // Never slower than 20%
  }

  calculatePosture(hunger, fatigue) {
    if (hunger > 80) return 'slouched'; // Starving
    if (fatigue > 90) return 'stumbling'; // Exhausted
    if (fatigue > 70) return 'tired'; // Fatigued
    return 'normal';
  }

  calculateEfficiencyPenalty(hunger, fatigue, wear) {
    let penalty = 1.0; // 1.0 = no penalty

    // Hunger: >80 = -50% efficiency
    if (hunger > 80) penalty *= 0.5;
    else if (hunger > 60) penalty *= 0.8;

    // Fatigue: >90 = random work failures, >70 = -30% efficiency
    if (fatigue > 90) {
      // Random failure chance
      penalty *= Math.random() > 0.5 ? 0.2 : 1.0;
    } else if (fatigue > 70) {
      penalty *= 0.7;
    }

    // Equipment wear: >70 = -20% efficiency
    if (wear > 70) penalty *= 0.8;

    return penalty;
  }
}

/**
 * Process all agent decisions for the game loop
 * Called once per day advance
 */
export function processAllAgentDecisions(agents) {
  return agents.map((agent) => {
    const decision = new DecisionMatrix(agent);
    const priority = decision.evaluatePriority();
    const selectedZone = decision.selectZone();
    const modifiers = decision.getStateModifiers();

    return {
      agentId: agent.id,
      decision: priority.action,
      priority: priority.priority,
      reason: priority.reason,
      isUrgent: priority.isUrgent,
      selectedZone,
      modifiers,
      willRefuse: decision.shouldRefuseOrder()
    };
  });
}

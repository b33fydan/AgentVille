// ============= Crisis Event Engine (Full) =============
// Queue-based system with 20+ templates, Claude enrichment, outcome cascades
// This is the heartbeat of gameplay

import { enrichCrisisEvent } from './claudeService';

/**
 * CrisisQueue manages all crisis triggers, pending crises, and history
 * Handles probability-based triggering, cooldowns, and outcome application
 */
export class CrisisQueue {
  constructor() {
    this.pending = []; // Crises waiting for player decision
    this.resolved = []; // Crisis history this season
    this.maxCrisisPerDay = 2; // Max concurrent crises
    this.lastTriggerDay = -10; // Day of last trigger
  }

  /**
   * Check if a new crisis should trigger
   * Called on day advance or time of day change
   */
  checkTrigger(season, day, timeOfDay) {
    // Only check once per day (morning)
    if (timeOfDay !== 'morning' || day === this.lastTriggerDay) {
      return null;
    }

    const triggerChance = this.calculateTriggerChance(day);
    const roll = Math.random();

    // Too many pending crises
    if (this.pending.length >= this.maxCrisisPerDay) {
      return null;
    }

    // Trigger check
    if (roll < triggerChance) {
      const crisis = generateCrisis();
      crisis.triggeredDay = day;
      crisis.season = season;
      this.pending.push(crisis);
      this.lastTriggerDay = day;
      return crisis;
    }

    return null;
  }

  /**
   * Calculate trigger probability based on game phase
   * Days 1-2: Setup, low crisis (10%)
   * Days 3-5: Mid-season, normal crisis (35%)
   * Day 6: Crunch time, high crisis (60%)
   * Day 7: Sale day, no new crises (0%)
   */
  calculateTriggerChance(day) {
    if (day <= 2) return 0.1;
    if (day === 6) return 0.6;
    if (day >= 7) return 0;
    return 0.35;
  }

  /**
   * Resolve a crisis (apply choice, get outcome)
   */
  resolveCrisis(crisisId, choiceIndex) {
    const crisis = this.pending.find((c) => c.id === crisisId);
    if (!crisis) return null;

    if (!crisis.choices || choiceIndex < 0 || choiceIndex >= crisis.choices.length) {
      return null;
    }

    const choice = crisis.choices[choiceIndex];
    const outcome = {
      crisisId: crisis.id,
      crisisTitle: crisis.title,
      choiceIndex,
      choiceText: choice.text,
      moraleDelta: choice.moraleDelta || 0,
      resourceDelta: choice.resourceDelta || {},
      efficiencyDelta: choice.efficiencyDelta || 0,
      agentStatus: choice.agentStatus || null,
      consequenceText: choice.consequenceText || '',
      nextCrisisHint: choice.nextCrisisHint || null,
    };

    // Remove from pending, add to resolved
    this.pending = this.pending.filter((c) => c.id !== crisisId);
    this.resolved.push({ crisis, choiceIndex, outcome, day: crisis.triggeredDay });

    return outcome;
  }

  /**
   * Get crisis history for a season
   */
  getSeasonHistory(season) {
    return this.resolved.filter((r) => r.crisis.season === season);
  }

  /**
   * Clear history (new season)
   */
  reset() {
    this.resolved = [];
    this.pending = [];
    this.lastTriggerDay = -10;
  }
}

/**
 * Crisis Templates (20+)
 * Structure:
 * {
 *   id: unique string,
 *   title: display name,
 *   baseDescription: template description,
 *   zone: 'forest' | 'plains' | 'wetlands' | null (null = cross-zone),
 *   severity: 1-3,
 *   affectedAgent: null (can be filtered by player choice),
 *   choices: [{ text, moraleDelta, resourceDelta, efficiencyDelta, agentStatus, consequenceText, nextCrisisHint }]
 * }
 */

export const CRISIS_TEMPLATES = [
  // ===== FOREST CRISES (5) =====
  {
    id: 'forest_drought',
    title: '🌲 Forest Drought',
    baseDescription: 'Your forest zone is drying up. Wood production slowing.',
    zone: 'forest',
    severity: 2,
    choices: [
      {
        text: 'Pray for rain',
        moraleDelta: -1,
        resourceDelta: { wood: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Morale drops slightly. No real solution.'
      },
      {
        text: 'Irrigate with well (cost 5 wheat)',
        moraleDelta: +2,
        resourceDelta: { wood: +3, wheat: -5 },
        efficiencyDelta: +0.05,
        agentStatus: null,
        consequenceText: 'Agents appreciate the effort. Forest recovers.'
      },
      {
        text: 'Ignore it',
        moraleDelta: -3,
        resourceDelta: { wood: -3 },
        efficiencyDelta: -0.1,
        agentStatus: null,
        consequenceText: 'Forest suffers. Agents disappointed.'
      }
    ]
  },
  {
    id: 'forest_pests',
    title: '🐛 Forest Pests',
    baseDescription: 'Insects swarm your forest. Wood under threat.',
    zone: 'forest',
    severity: 2,
    choices: [
      {
        text: 'Treat with herbs (natural)',
        moraleDelta: +1,
        resourceDelta: { wood: +2, hay: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Agents like the eco-friendly approach.'
      },
      {
        text: 'Cull infected trees',
        moraleDelta: -2,
        resourceDelta: { wood: +5 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Short-term wood gain, but agents uncomfortable.'
      },
      {
        text: 'Do nothing',
        moraleDelta: 0,
        resourceDelta: { wood: -2 },
        efficiencyDelta: -0.05,
        agentStatus: null,
        consequenceText: 'Pests persist. Slow wood loss.'
      }
    ]
  },
  {
    id: 'forest_wildfire_threat',
    title: '🔥 Wildfire Threat',
    baseDescription: 'Dry conditions spark fire danger. Forest at risk.',
    zone: 'forest',
    severity: 3,
    choices: [
      {
        text: 'Clear brush defensively (risky)',
        moraleDelta: -1,
        resourceDelta: { wood: +4 },
        efficiencyDelta: -0.15,
        agentStatus: null,
        consequenceText: 'Exhausting work. Morale drops. Fire prevented.'
      },
      {
        text: 'Create firebreaks (balanced)',
        moraleDelta: +1,
        resourceDelta: { wood: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Expensive but safe. Agents feel prepared.'
      },
      {
        text: 'Hope it doesn\'t reach you',
        moraleDelta: -4,
        resourceDelta: { wood: -5 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Fire spreads. Disaster. Agents furious.'
      }
    ]
  },
  {
    id: 'forest_poachers',
    title: '🎯 Poachers in Forest',
    baseDescription: 'Unauthorized loggers stealing your timber.',
    zone: 'forest',
    severity: 2,
    choices: [
      {
        text: 'Confront them (dangerous)',
        moraleDelta: +2,
        resourceDelta: { wood: +3 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Risky but agents love your courage.'
      },
      {
        text: 'Pay them to leave',
        moraleDelta: -1,
        resourceDelta: { wood: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Forest saved but agents see you as weak.'
      },
      {
        text: 'Report to authorities',
        moraleDelta: 0,
        resourceDelta: { wood: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Slow legal process. Wood lost to poachers.'
      }
    ]
  },
  {
    id: 'forest_old_growth',
    title: '🌳 Ancient Trees Discovered',
    baseDescription: 'Your forest harbors rare, ancient trees. Logging them = profit or preservation?',
    zone: 'forest',
    severity: 1,
    choices: [
      {
        text: 'Log the ancient trees (short-term profit)',
        moraleDelta: -3,
        resourceDelta: { wood: +8, coins: +20 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Big profit but agents troubled by destruction.'
      },
      {
        text: 'Preserve them (eco legacy)',
        moraleDelta: +4,
        resourceDelta: { wood: +1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Agents proud. Forest stays healthy long-term.'
      },
      {
        text: 'Selective harvest',
        moraleDelta: +1,
        resourceDelta: { wood: +4, coins: +10 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Balanced approach. Modest profit, satisfied agents.'
      }
    ]
  },

  // ===== PLAINS CRISES (5) =====
  {
    id: 'plains_blight',
    title: '🍞 Wheat Blight',
    baseDescription: 'Disease spreads through your wheat field.',
    zone: 'plains',
    severity: 2,
    choices: [
      {
        text: 'Burn infected crops (drastic)',
        moraleDelta: -2,
        resourceDelta: { wheat: +3 },
        efficiencyDelta: -0.1,
        agentStatus: null,
        consequenceText: 'Severe but contains disease. Agents worried.'
      },
      {
        text: 'Quarantine + treat carefully',
        moraleDelta: +1,
        resourceDelta: { wheat: +1, hay: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Slow recovery. Agents appreciate care.'
      },
      {
        text: 'Accept the loss',
        moraleDelta: -4,
        resourceDelta: { wheat: -3 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Fields devastated. Agents demoralized.'
      }
    ]
  },
  {
    id: 'plains_locusts',
    title: '🦗 Locust Swarm',
    baseDescription: 'Millions of locusts descend on your plains.',
    zone: 'plains',
    severity: 3,
    choices: [
      {
        text: 'Fight swarm (dangerous, aggressive)',
        moraleDelta: +2,
        resourceDelta: { wheat: +2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Risky but brave. Agents rally. Some harvest saved.'
      },
      {
        text: 'Harvest early and run',
        moraleDelta: 0,
        resourceDelta: { wheat: +3 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Practical retreat. Most wheat saved.'
      },
      {
        text: 'Abandon field',
        moraleDelta: -5,
        resourceDelta: { wheat: -5 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Disaster. Total crop loss. Agents furious.'
      }
    ]
  },
  {
    id: 'plains_drought',
    title: '☀️ Plains Drought',
    baseDescription: 'No rain for weeks. Wheat withering.',
    zone: 'plains',
    severity: 2,
    choices: [
      {
        text: 'Build irrigation (expensive)',
        moraleDelta: +2,
        resourceDelta: { wheat: +2, wood: -3, coins: -15 },
        efficiencyDelta: +0.1,
        agentStatus: null,
        consequenceText: 'Investment pays off. Wheat grows. Agents proud.'
      },
      {
        text: 'Pray and wait',
        moraleDelta: -1,
        resourceDelta: { wheat: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'No relief. Slow loss.'
      },
      {
        text: 'Switch to hardy crops',
        moraleDelta: +1,
        resourceDelta: { hay: +3, wheat: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Pragmatic pivot. Agents adapt.'
      }
    ]
  },
  {
    id: 'plains_market_crash',
    title: '📉 Market Crash',
    baseDescription: 'Wheat prices plummet overnight. Your harvest timing is bad.',
    zone: 'plains',
    severity: 2,
    choices: [
      {
        text: 'Sell now anyway (minimize loss)',
        moraleDelta: -1,
        resourceDelta: { coins: -30 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Financial loss. Agents worried.'
      },
      {
        text: 'Hold and hope prices recover',
        moraleDelta: 0,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Risky gamble. Outcome unknown.'
      },
      {
        text: 'Trade wheat for other goods',
        moraleDelta: +1,
        resourceDelta: { wheat: -2, wood: +2, hay: +1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Creative workaround. Agents appreciate resourcefulness.'
      }
    ]
  },
  {
    id: 'plains_seed_shortage',
    title: '🌱 Seed Shortage',
    baseDescription: 'Next season\'s seeds are nearly impossible to find.',
    zone: 'plains',
    severity: 1,
    choices: [
      {
        text: 'Hunt for seeds (risky trade)',
        moraleDelta: +1,
        resourceDelta: { wheat: +1, coins: -10 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'You find seeds. Cost high but next season secured.'
      },
      {
        text: 'Use last season\'s seeds',
        moraleDelta: -2,
        resourceDelta: { wheat: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Risky. Crop quality suffers.'
      },
      {
        text: 'Wait for restocking',
        moraleDelta: 0,
        resourceDelta: { wheat: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Seeds arrive but expensive.'
      }
    ]
  },

  // ===== WETLANDS CRISES (5) =====
  {
    id: 'wetlands_flooding',
    title: '💧 Heavy Flooding',
    baseDescription: 'Water levels rise dangerously. Hay fields at risk.',
    zone: 'wetlands',
    severity: 3,
    choices: [
      {
        text: 'Build dikes (expensive, labor-intensive)',
        moraleDelta: +2,
        resourceDelta: { hay: +2, wood: -3, wheat: -2 },
        efficiencyDelta: -0.2,
        agentStatus: null,
        consequenceText: 'Exhausting work saves the crop. Agents proud but tired.'
      },
      {
        text: 'Evacuate crops',
        moraleDelta: -2,
        resourceDelta: { hay: -3 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Fields lost to water. Morale drops.'
      },
      {
        text: 'Hope water recedes',
        moraleDelta: -3,
        resourceDelta: { hay: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Water worsens. Major crop loss.'
      }
    ]
  },
  {
    id: 'wetlands_disease',
    title: '🍃 Hay Rot',
    baseDescription: 'Moisture breeds fungal infection in stored hay.',
    zone: 'wetlands',
    severity: 2,
    choices: [
      {
        text: 'Dry out field aggressively',
        moraleDelta: +1,
        resourceDelta: { hay: +2, wood: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Effective. Hay saved.'
      },
      {
        text: 'Compost infected hay (loss)',
        moraleDelta: 0,
        resourceDelta: { hay: -2, wheat: +1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Controlled loss. Move on.'
      },
      {
        text: 'Spray fungicide',
        moraleDelta: +2,
        resourceDelta: { hay: +3, coins: -10 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Expensive chemical solution. Hay flourishes.'
      }
    ]
  },
  {
    id: 'wetlands_predators',
    title: '🐺 Predators in Wetlands',
    baseDescription: 'Large animals have moved in, threatening workers.',
    zone: 'wetlands',
    severity: 2,
    choices: [
      {
        text: 'Hunt the predators',
        moraleDelta: -1,
        resourceDelta: { hay: +1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Danger. Employees rattled.'
      },
      {
        text: 'Build barriers',
        moraleDelta: +2,
        resourceDelta: { wood: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Workers feel protected. Agents grateful.'
      },
      {
        text: 'Leave them alone',
        moraleDelta: 0,
        resourceDelta: { hay: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Coexistence but productivity drops.'
      }
    ]
  },
  {
    id: 'wetlands_migration',
    title: '🦆 Bird Migration',
    baseDescription: 'Millions of migratory birds pass through, eating crops.',
    zone: 'wetlands',
    severity: 1,
    choices: [
      {
        text: 'Scare them with noise',
        moraleDelta: -1,
        resourceDelta: { hay: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Some birds leave, some don\'t.'
      },
      {
        text: 'Let them feed (eco view)',
        moraleDelta: +2,
        resourceDelta: { hay: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Agents impressed by kindness. But hay lost.'
      },
      {
        text: 'Set traps for food',
        moraleDelta: 0,
        resourceDelta: { hay: +1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'You harvest some birds. Mixed morale.'
      }
    ]
  },
  {
    id: 'wetlands_canal_break',
    title: '💦 Canal Break',
    baseDescription: 'Irrigation canal breaks, draining water to your fields.',
    zone: 'wetlands',
    severity: 2,
    choices: [
      {
        text: 'Repair immediately (all hands)',
        moraleDelta: +1,
        resourceDelta: { wood: -3, wheat: -1 },
        efficiencyDelta: -0.15,
        agentStatus: null,
        consequenceText: 'Exhausting work but canal fixed. Agents tired.'
      },
      {
        text: 'Quick patch (temporary)',
        moraleDelta: 0,
        resourceDelta: { wood: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Patch holds for now. Issue returns.'
      },
      {
        text: 'Ignore it',
        moraleDelta: -2,
        resourceDelta: { hay: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Water lost. Agents furious.'
      }
    ]
  },

  // ===== CROSS-ZONE CRISES (5) =====
  {
    id: 'agent_injury',
    title: '🤕 Agent Injured',
    baseDescription: 'One of your agents got hurt working.',
    zone: null,
    severity: 2,
    choices: [
      {
        text: 'Tend their wounds carefully',
        moraleDelta: +5,
        resourceDelta: { wheat: -1 },
        efficiencyDelta: 0,
        agentStatus: 'recovering',
        consequenceText: 'Agent will heal. Agents appreciate your care.'
      },
      {
        text: 'Send them back to work',
        moraleDelta: -5,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: 'injured',
        consequenceText: 'Injury worsens. Agents horrified by callousness.'
      },
      {
        text: 'Give them a day off',
        moraleDelta: +2,
        resourceDelta: {},
        efficiencyDelta: -0.1,
        agentStatus: 'resting',
        consequenceText: 'Partial recovery. Balanced approach.'
      }
    ]
  },
  {
    id: 'agent_demands',
    title: '📢 Agent Demands',
    baseDescription: 'Your agents are demanding better conditions.',
    zone: null,
    severity: 2,
    choices: [
      {
        text: 'Give them a bonus',
        moraleDelta: +5,
        resourceDelta: { coins: -30 },
        efficiencyDelta: +0.1,
        agentStatus: null,
        consequenceText: 'Expensive but loyalty secure. Agents motivated.'
      },
      {
        text: 'Negotiate terms',
        moraleDelta: +2,
        resourceDelta: { coins: -10 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Compromise reached. Morale improves.'
      },
      {
        text: 'Ignore demands',
        moraleDelta: -8,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Agents furious. Revolt risk rises.'
      }
    ]
  },
  {
    id: 'weather_storm',
    title: '⛈️ Bad Weather',
    baseDescription: 'Storm rolling in. All crops at risk.',
    zone: null,
    severity: 3,
    choices: [
      {
        text: 'Secure everything',
        moraleDelta: +2,
        resourceDelta: { wood: -2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Preparation saves crops. Agents feel prepared.'
      },
      {
        text: 'Harvest now (risky gamble)',
        moraleDelta: 0,
        resourceDelta: { wheat: +2, hay: +2, wood: +1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Some crops saved, some lost to storm.'
      },
      {
        text: 'Seek shelter',
        moraleDelta: -2,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Safety first. But all crops destroyed.'
      }
    ]
  },
  {
    id: 'festival_day',
    title: '🎪 Festival Approaching',
    baseDescription: 'Village festival! Your agents want to attend.',
    zone: null,
    severity: 1,
    choices: [
      {
        text: 'Give them festival time (morale boost)',
        moraleDelta: +6,
        resourceDelta: { wheat: -1 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Agents return happy and reinvigorated.'
      },
      {
        text: 'Half day off',
        moraleDelta: +2,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Compromise. Moderate morale boost.'
      },
      {
        text: 'Work as usual',
        moraleDelta: -4,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Agents resentful. They missed the fun.'
      }
    ]
  },
  {
    id: 'rival_farm',
    title: '⚔️ Rival Farm Competition',
    baseDescription: 'A rival farm is outproducing you.',
    zone: null,
    severity: 1,
    choices: [
      {
        text: 'Work harder (risky)',
        moraleDelta: -2,
        resourceDelta: { wheat: +3, wood: +1 },
        efficiencyDelta: -0.1,
        agentStatus: null,
        consequenceText: 'Exhausting push. You pull ahead but agents tired.'
      },
      {
        text: 'Collaborate',
        moraleDelta: +3,
        resourceDelta: { hay: +2 },
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'Cooperation is good. Trade benefits both farms.'
      },
      {
        text: 'Ignore them',
        moraleDelta: 0,
        resourceDelta: {},
        efficiencyDelta: 0,
        agentStatus: null,
        consequenceText: 'They pull further ahead. You fall behind.'
      }
    ]
  }
];

// ============= CRISIS GENERATION =============

/**
 * Generate a random crisis from templates
 * @returns {object} Crisis with full structure
 */
export function generateCrisis() {
  const template = CRISIS_TEMPLATES[Math.floor(Math.random() * CRISIS_TEMPLATES.length)];
  
  // Add unique ID
  return {
    ...template,
    id: `crisis-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    description: template.baseDescription // Will be enriched by Claude later
  };
}

/**
 * Resolve a crisis choice
 * Returns outcome object ready for application
 */
export function resolveCrisis(crisis, choiceIndex) {
  if (!crisis || !crisis.choices || choiceIndex < 0 || choiceIndex >= crisis.choices.length) {
    return null;
  }

  const choice = crisis.choices[choiceIndex];

  return {
    crisisId: crisis.id,
    crisisTitle: crisis.title,
    choiceIndex,
    choiceText: choice.text,
    consequenceText: choice.consequenceText || '',
    moraleDelta: choice.moraleDelta || 0,
    resourceDelta: choice.resourceDelta || {},
    efficiencyDelta: choice.efficiencyDelta || 0,
    agentStatus: choice.agentStatus || null,
    nextCrisisHint: choice.nextCrisisHint || null
  };
}

/**
 * Enrich crisis description with Claude
 * Falls back to template description if API unavailable
 */
export async function enrichCrisisDescription(crisis, agents) {
  // Try Claude if available
  try {
    const enriched = await enrichCrisisEvent({
      crisisType: crisis.id,
      baseDescription: crisis.baseDescription
    });
    return enriched.description;
  } catch (error) {
    // Fallback to template
    console.warn('Crisis enrichment failed, using template:', error);
    return crisis.description || crisis.baseDescription;
  }
}

/**
 * Generate agent reaction quote for a crisis choice
 * Used in Field Log for personality
 */
export function getAgentReactionQuote(agent, choice, moraleDelta) {
  if (!agent) return null;

  // Simple trait-based reactions
  if (moraleDelta > 5) {
    if (agent.traits?.loyalty > 70) return `${agent.name}: "I trust your judgment completely."`;
    if (agent.traits?.workEthic > 70) return `${agent.name}: "Great call. Let's get to work!"`;
    return `${agent.name}: "I like this decision."`;
  } else if (moraleDelta < -5) {
    if (agent.traits?.loyalty < 30) return `${agent.name}: "Really? I'm not sure about you anymore..."`;
    if (agent.traits?.workEthic < 30) return `${agent.name}: "This is too hard."`;
    return `${agent.name}: "I'm disappointed."`;
  } else {
    return `${agent.name}: "Okay... I suppose that's fair."`;
  }
}

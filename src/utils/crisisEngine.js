// ============= Crisis Event Engine =============
// Template-first crisis system
// 20+ hardcoded templates + state-aware generation

export const CRISIS_TEMPLATES = [
  // ===== Forest Biome Crises =====
  {
    id: 'forest_drought',
    title: 'Forest Drought',
    description: 'Your forest zone is drying up. Wood production slowing.',
    choices: [
      { text: 'Pray for rain', moraleDelta: -1, resourceDelta: { wood: -1 }, risk: 'safe' },
      { text: 'Irrigate with well (cost 5 wheat)', moraleDelta: 2, resourceDelta: { wood: 3, wheat: -5 }, risk: 'balanced' },
      { text: 'Ignore it', moraleDelta: -3, resourceDelta: { wood: -3 }, risk: 'risky' }
    ]
  },
  {
    id: 'forest_pests',
    title: 'Forest Pests',
    description: 'Insects swarm your forest. Wood under threat.',
    choices: [
      { text: 'Treat with herbs', moraleDelta: 1, resourceDelta: { wood: 2, hay: -2 }, risk: 'safe' },
      { text: 'Cull the trees', moraleDelta: -2, resourceDelta: { wood: 5 }, risk: 'risky' },
      { text: 'Do nothing', moraleDelta: 0, resourceDelta: { wood: -1 }, risk: 'safe' }
    ]
  },
  {
    id: 'forest_wild_animals',
    title: 'Wild Animals',
    description: 'Creatures have moved into your forest.',
    choices: [
      { text: 'Set traps for food', moraleDelta: 1, resourceDelta: { hay: 2 }, risk: 'balanced' },
      { text: 'Chase them away (danger)', moraleDelta: -2, resourceDelta: {}, risk: 'risky' },
      { text: 'Coexist peacefully', moraleDelta: 3, resourceDelta: {}, risk: 'safe' }
    ]
  },

  // ===== Plains Biome Crises =====
  {
    id: 'plains_blight',
    title: 'Wheat Blight',
    description: 'Disease spreads through your wheat field.',
    choices: [
      { text: 'Burn infected crops', moraleDelta: -2, resourceDelta: { wheat: 3 }, risk: 'risky' },
      { text: 'Quarantine + treat', moraleDelta: 1, resourceDelta: { wheat: 1, hay: -1 }, risk: 'balanced' },
      { text: 'Accept the loss', moraleDelta: -4, resourceDelta: { wheat: -3 }, risk: 'safe' }
    ]
  },
  {
    id: 'plains_locusts',
    title: 'Locust Swarm',
    description: 'Millions of locusts descend on your plains.',
    choices: [
      { text: 'Fight swarm (dangerous)', moraleDelta: 2, resourceDelta: { wheat: 2 }, risk: 'risky' },
      { text: 'Harvest early', moraleDelta: 0, resourceDelta: { wheat: 3 }, risk: 'balanced' },
      { text: 'Abandon field', moraleDelta: -5, resourceDelta: { wheat: -5 }, risk: 'safe' }
    ]
  },
  {
    id: 'plains_drought',
    title: 'Plains Drought',
    description: 'No rain for weeks. Wheat withering.',
    choices: [
      { text: 'Build irrigation', moraleDelta: 2, resourceDelta: { wheat: 2, wood: -3 }, risk: 'balanced' },
      { text: 'Pray and wait', moraleDelta: -1, resourceDelta: { wheat: -2 }, risk: 'safe' },
      { text: 'Switch to drought crops', moraleDelta: 1, resourceDelta: { hay: 3, wheat: -1 }, risk: 'risky' }
    ]
  },

  // ===== Wetlands Biome Crises =====
  {
    id: 'wetlands_flooding',
    title: 'Heavy Flooding',
    description: 'Water levels rise dangerously. Hay fields at risk.',
    choices: [
      { text: 'Build dikes (costs resources)', moraleDelta: 2, resourceDelta: { hay: 2, wood: -3, wheat: -2 }, risk: 'balanced' },
      { text: 'Evacuate crops', moraleDelta: -2, resourceDelta: { hay: -3 }, risk: 'safe' },
      { text: 'Hope water recedes', moraleDelta: -3, resourceDelta: { hay: -2 }, risk: 'risky' }
    ]
  },
  {
    id: 'wetlands_disease',
    title: 'Hay Rot',
    description: 'Moisture breeds fungal infection in hay.',
    choices: [
      { text: 'Dry out field', moraleDelta: 1, resourceDelta: { hay: 2, wood: -2 }, risk: 'balanced' },
      { text: 'Compost infected hay', moraleDelta: 0, resourceDelta: { hay: -2, wheat: 1 }, risk: 'safe' },
      { text: 'Spray fungicide', moraleDelta: 2, resourceDelta: { hay: 3 }, risk: 'risky' }
    ]
  },

  // ===== Cross-Biome / Random Crises =====
  {
    id: 'agent_injury',
    title: 'Agent Injured',
    description: 'One of your agents got hurt working.',
    choices: [
      { text: 'Tend their wounds', moraleDelta: 5, resourceDelta: { wheat: -1 }, risk: 'safe' },
      { text: 'Send them back to work', moraleDelta: -5, resourceDelta: {}, risk: 'risky' },
      { text: 'Rest day', moraleDelta: 2, resourceDelta: {}, risk: 'balanced' }
    ]
  },
  {
    id: 'agent_morale_crisis',
    title: 'Agent Rebellion',
    description: 'Your agents are demanding better conditions.',
    choices: [
      { text: 'Grant them a bonus', moraleDelta: 5, resourceDelta: { wheat: -2, hay: -1 }, risk: 'safe' },
      { text: 'Negotiate terms', moraleDelta: 2, resourceDelta: {}, risk: 'balanced' },
      { text: 'Ignore demands', moraleDelta: -8, resourceDelta: {}, risk: 'risky' }
    ]
  },
  {
    id: 'weather_storm',
    title: 'Bad Weather',
    description: 'Storm rolling in. All crops at risk.',
    choices: [
      { text: 'Secure everything', moraleDelta: 2, resourceDelta: { wood: -2 }, risk: 'safe' },
      { text: 'Harvest now (risky)', moraleDelta: 0, resourceDelta: { wheat: 2, hay: 2, wood: 1 }, risk: 'risky' },
      { text: 'Seek shelter', moraleDelta: -2, resourceDelta: {}, risk: 'balanced' }
    ]
  },
  {
    id: 'resource_abundance',
    title: 'Abundant Harvest',
    description: 'Your crops flourish! Extra resources everywhere.',
    choices: [
      { text: 'Celebrate! (Boost morale)', moraleDelta: 4, resourceDelta: { wood: 2, wheat: 2, hay: 2 }, risk: 'safe' },
      { text: 'Store for winter', moraleDelta: 1, resourceDelta: { wood: 3, wheat: 3, hay: 3 }, risk: 'balanced' },
      { text: 'Trade away extras', moraleDelta: 0, resourceDelta: { wood: 5, wheat: 1, hay: 1 }, risk: 'risky' }
    ]
  },
  {
    id: 'stranger_trader',
    title: 'Mysterious Trader',
    description: 'A traveler offers strange deals.',
    choices: [
      { text: 'Trade fairly', moraleDelta: 1, resourceDelta: { wood: -1, wheat: 2 }, risk: 'balanced' },
      { text: 'Haggle hard', moraleDelta: -1, resourceDelta: { wood: 2 }, risk: 'risky' },
      { text: 'Politely decline', moraleDelta: 0, resourceDelta: {}, risk: 'safe' }
    ]
  },
  {
    id: 'tax_collector',
    title: 'Tax Collector Arrives',
    description: 'The realm demands tribute.',
    choices: [
      { text: 'Pay full tax', moraleDelta: -2, resourceDelta: { wheat: -3 }, risk: 'safe' },
      { text: 'Negotiate reduction', moraleDelta: 0, resourceDelta: { wheat: -2 }, risk: 'balanced' },
      { text: 'Hide resources (danger)', moraleDelta: -4, resourceDelta: {}, risk: 'risky' }
    ]
  },
  {
    id: 'rare_seed',
    title: 'Rare Seed Found',
    description: 'You find an unusual seed. Plant it?',
    choices: [
      { text: 'Plant immediately', moraleDelta: 2, resourceDelta: { wheat: 3, hay: 1 }, risk: 'risky' },
      { text: 'Study it first', moraleDelta: 1, resourceDelta: { wood: 1 }, risk: 'balanced' },
      { text: 'Save for later', moraleDelta: 0, resourceDelta: {}, risk: 'safe' }
    ]
  },
  {
    id: 'festival_day',
    title: 'Festival Approaching',
    description: 'Village festival! Agents want to attend.',
    choices: [
      { text: 'Give them festival time (morale boost)', moraleDelta: 6, resourceDelta: { wheat: -1 }, risk: 'safe' },
      { text: 'Half day off', moraleDelta: 2, resourceDelta: {}, risk: 'balanced' },
      { text: 'Work as usual', moraleDelta: -4, resourceDelta: {}, risk: 'risky' }
    ]
  },
  {
    id: 'rival_farm',
    title: 'Rival Farm',
    description: 'A rival farm is outproducing you.',
    choices: [
      { text: 'Work harder (risky)', moraleDelta: -2, resourceDelta: { wheat: 3, wood: 1 }, risk: 'risky' },
      { text: 'Collaborate', moraleDelta: 3, resourceDelta: { hay: 2 }, risk: 'balanced' },
      { text: 'Ignore them', moraleDelta: 0, resourceDelta: {}, risk: 'safe' }
    ]
  },
  {
    id: 'supply_shortage',
    title: 'Supply Shortage',
    description: 'Tools and seeds are hard to find.',
    choices: [
      { text: 'Hunt for supplies (dangerous)', moraleDelta: 1, resourceDelta: { wood: 1, wheat: 1 }, risk: 'risky' },
      { text: 'Make do with what you have', moraleDelta: -1, resourceDelta: {}, risk: 'balanced' },
      { text: 'Wait for restock', moraleDelta: -2, resourceDelta: { wheat: -1 }, risk: 'safe' }
    ]
  }
];

// ============= Crisis Selection =============

/**
 * Generates a crisis for the current state
 * Picks randomly from templates (Phase 1 MVP)
 * State-aware selection comes in Phase 1.5
 * @returns {object} Crisis template
 */
export function generateCrisis() {
  const randomIndex = Math.floor(Math.random() * CRISIS_TEMPLATES.length);
  return CRISIS_TEMPLATES[randomIndex];
}

/**
 * Applies a crisis choice to game state
 * Returns the outcome summary
 * @param {object} crisis - Crisis template
 * @param {number} choiceIndex - Index of chosen option
 * @returns {object} Outcome with morale/resource/risk
 */
export function resolveCrisis(crisis, choiceIndex) {
  if (!crisis || !crisis.choices || choiceIndex < 0 || choiceIndex >= crisis.choices.length) {
    return null;
  }

  const choice = crisis.choices[choiceIndex];

  return {
    choiceText: choice.text,
    moraleDelta: choice.moraleDelta,
    resourceDelta: choice.resourceDelta,
    riskLevel: choice.risk
  };
}

/**
 * Apply crisis outcome to game state
 * (Store integration happens in component)
 */
export function applyCrisisOutcome(state, outcome) {
  if (!outcome) return state;

  const nextState = { ...state };

  // Apply morale delta to all agents
  if (outcome.moraleDelta) {
    nextState.agents = nextState.agents.map((agent) => ({
      ...agent,
      morale: Math.max(0, Math.min(100, agent.morale + outcome.moraleDelta))
    }));
  }

  // Apply resource delta
  if (outcome.resourceDelta) {
    nextState.resources = { ...nextState.resources };
    Object.entries(outcome.resourceDelta).forEach(([resource, delta]) => {
      nextState.resources[resource] = Math.max(0, nextState.resources[resource] + delta);
    });
  }

  return nextState;
}

/**
 * Get crisis description with variable substitution
 * (Variables like {agent_name}, {resource_type}, etc.)
 */
export function getCrisisDescription(crisis, agents) {
  let desc = crisis.description;

  // Substitute first agent name if needed
  if (agents && agents.length > 0) {
    desc = desc.replace('{agent_name}', agents[0].name);
  }

  return desc;
}

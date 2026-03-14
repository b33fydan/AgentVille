import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { soundManager } from '../utils/soundManager';

const STORAGE_KEY = 'agentville-agents';

// ============= Helpers =============

function generateAgentName() {
  const firstNames = [
    'Alex', 'Bailey', 'Casey', 'Drew', 'Ellis', 'Finley', 'Grey', 'Harper',
    'Indigo', 'Jordan', 'Kira', 'Logan', 'Morgan', 'Nathan', 'Orion', 'Parker'
  ];
  const lastNames = [
    'Wood', 'Stone', 'Field', 'Rivers', 'Mills', 'Banks', 'Hayes', 'Cross',
    'Sands', 'Brooks', 'Wells', 'Parks', 'Gates', 'Hills', 'Dale', 'Vale'
  ];

  const first = firstNames[Math.floor(Math.random() * firstNames.length)];
  const last = lastNames[Math.floor(Math.random() * lastNames.length)];
  return `${first} ${last}`;
}

function generateAgentTraits() {
  return {
    workEthic: Math.floor(Math.random() * 100), // 0=lazy, 100=overachiever
    risk: Math.floor(Math.random() * 100), // 0=cautious, 100=gambler
    loyalty: Math.floor(Math.random() * 100), // 0=independent, 100=obedient
    specialization: ['forest', 'plains', 'wetlands'][Math.floor(Math.random() * 3)]
  };
}

function generateAgentAppearance() {
  const bodyColors = [
    '#ef4444', '#f97316', '#eab308', '#22c55e', '#10b981', '#14b8a6',
    '#06b6d4', '#0ea5e9', '#3b82f6', '#6366f1', '#8b5cf6', '#d946ef',
    '#ec4899', '#f43f5e'
  ];

  const hatTypes = ['hardhat', 'straw', 'cap', 'none'];
  const toolTypes = ['axe', 'hoe', 'rake', 'spade'];

  return {
    bodyColor: bodyColors[Math.floor(Math.random() * bodyColors.length)],
    hatType: hatTypes[Math.floor(Math.random() * hatTypes.length)],
    toolType: toolTypes[Math.floor(Math.random() * toolTypes.length)]
  };
}

function createAgent(index) {
  const id = `agent-${index}-${Date.now()}`;
  return {
    id,
    name: generateAgentName(),
    role: 'Worker',
    level: 1,
    xp: 0,
    traits: generateAgentTraits(),
    morale: 75,
    assignedZone: null, // null | tileIndex
    status: 'idle', // 'idle' | 'working' | 'crisis' | 'riot'
    appearance: generateAgentAppearance(),
    efficiency: 1.0,
    // ===== AUTONOMOUS NEEDS SYSTEM =====
    hunger: 30, // 0-100: 0=not hungry, 100=starving
    fatigue: 25, // 0-100: 0=well-rested, 100=exhausted
    equipmentWear: 20, // 0-100: 0=perfect, 100=broken
    currentDecision: 'idle', // Current autonomous decision
    decidedZone: null // Zone agent decided to work in
  };
}

function calculateEfficiency(morale, traits, assignedZone) {
  // Morale: 0-100 → 0.2-1.0 multiplier
  const moraleMultiplier = 0.2 + (morale / 100) * 0.8;

  // Work ethic factor
  const workEthicBonus = (traits?.workEthic || 50) / 100 * 0.2; // Up to +20%

  // Zone fit bonus (if assignedZone is provided, assume it's a zone name)
  // TODO: This will be enhanced when we have proper tile-to-zone mapping
  let zoneFitBonus = 0;

  return Math.max(0.1, moraleMultiplier + workEthicBonus + zoneFitBonus);
}

// ============= Initial State =============

const initialAgents = [
  createAgent(0),
  createAgent(1),
  createAgent(2)
];

// ============= Store =============

export const useAgentStore = create(
  persist(
    (set, get) => ({
      // ===== Island Metadata =====
      islandName: 'My Island',

      setIslandName: (name) => {
        set({ islandName: String(name ?? '').trim() || 'My Island' });
      },

      // ===== Agents =====
      agents: initialAgents,

      assignAgentToZone: (agentId, tileIndex, onReaction = null) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            // Trigger assignment reaction if callback provided
            if (onReaction) {
              onReaction(agent.id, agent.name, agent.traits);
            }

            return {
              ...agent,
              assignedZone: tileIndex,
              status: 'working',
              morale: Math.max(0, Math.min(100, agent.morale + 2)), // Small morale boost when assigned
              efficiency: calculateEfficiency(agent.morale + 2, agent.traits, tileIndex)
            };
          })
        }));
      },

      unassignAgent: (agentId) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              assignedZone: null,
              status: 'idle',
              morale: Math.max(0, Math.min(100, agent.morale - 2)), // Small morale penalty when unassigned
              efficiency: calculateEfficiency(agent.morale - 2, agent.traits, null)
            };
          })
        }));
      },

      updateMorale: (agentId, delta, onThresholdCross = null) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            const oldMorale = agent.morale;
            const newMorale = Math.max(0, Math.min(100, agent.morale + delta));

            // Play morale sounds
            if (delta > 0) {
              soundManager.play('moraleUp');
            } else if (delta < 0 && oldMorale > 20) {
              soundManager.play('moraleDown');
            }

            // Check for threshold crossings
            if (onThresholdCross) {
              const thresholds = [80, 60, 40, 20];
              for (const threshold of thresholds) {
                if (oldMorale >= threshold && newMorale < threshold) {
                  // Crossed down
                  onThresholdCross(agentId, agent.name, agent.traits, 'down', threshold);
                  // Critical morale sound if crossing below 20
                  if (threshold === 20) {
                    soundManager.play('moraleCritical');
                  }
                } else if (oldMorale < threshold && newMorale >= threshold) {
                  // Crossed up
                  onThresholdCross(agentId, agent.name, agent.traits, 'up', threshold);
                }
              }
            }

            return {
              ...agent,
              morale: newMorale,
              efficiency: calculateEfficiency(newMorale, agent.traits, agent.assignedZone)
            };
          })
        }));
      },

      addAgentXP: (agentId, amount) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            const newXP = agent.xp + amount;
            const newLevel = agent.level + Math.floor(newXP / 100); // 100 XP per level
            return {
              ...agent,
              xp: newXP % 100, // Keep remainder
              level: newLevel
            };
          })
        }));
      },

      setAgentStatus: (agentId, status) => {
        set((state) => ({
          agents: state.agents.map((agent) =>
            agent.id === agentId ? { ...agent, status } : agent
          )
        }));
      },

      fireAgent: (agentId) => {
        set((state) => ({
          agents: state.agents.filter((agent) => agent.id !== agentId)
        }));
      },

      desertAgent: (agentId) => {
        // Same as fire, but triggers a consequence instead
        set((state) => ({
          agents: state.agents.filter((agent) => agent.id !== agentId)
        }));
      },

      hireNewAgent: (agentData) => {
        const newAgent = agentData || createAgent(Math.random());
        set((state) => ({
          agents: [...state.agents, newAgent]
        }));
      },

      updateAgentTraits: (agentId, traitUpdates) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              traits: {
                ...agent.traits,
                ...traitUpdates
              }
            };
          })
        }));
      },

      resetAgentsForNewSeason: () => {
        set((state) => ({
          agents: state.agents.map((agent) => ({
            ...agent,
            status: 'idle',
            assignedZone: null
            // Keep morale, xp, level
          }))
        }));
      },

      // ===== AUTONOMOUS NEEDS SYSTEM =====

      /**
       * Update agent's hunger, fatigue, equipment wear (drain per day)
       * Called during day advancement
       */
      applyNeedsDrain: (agentId, drainRates = {}) => {
        const rates = {
          hunger: drainRates.hunger ?? 1,      // +1/day
          fatigue: drainRates.fatigue ?? 1.5,  // +1.5/day
          wear: drainRates.wear ?? 0.5         // +0.5/day
        };

        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              hunger: Math.min(100, agent.hunger + rates.hunger),
              fatigue: Math.min(100, agent.fatigue + rates.fatigue),
              equipmentWear: Math.min(100, agent.equipmentWear + rates.wear)
            };
          })
        }));
      },

      /**
       * Agent eats food - reduces hunger
       */
      eatFood: (agentId, hungerReduction = 30) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              hunger: Math.max(0, agent.hunger - hungerReduction),
              currentDecision: 'eating'
            };
          })
        }));
      },

      /**
       * Agent sleeps - reduces fatigue
       */
      sleep: (agentId, fatigueReduction = 40) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              fatigue: Math.max(0, agent.fatigue - fatigueReduction),
              currentDecision: 'sleeping'
            };
          })
        }));
      },

      /**
       * Agent repairs equipment - reduces wear
       */
      repairEquipment: (agentId, wearReduction = 50) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              equipmentWear: Math.max(0, agent.equipmentWear - wearReduction),
              currentDecision: 'repairing'
            };
          })
        }));
      },

      /**
       * Set agent's autonomous decision and optionally assigned zone
       */
      setAutonomousDecision: (agentId, decision, zone = null) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;

            return {
              ...agent,
              currentDecision: decision,
              decidedZone: zone,
              assignedZone: zone, // Auto-assign to decided zone for work
              status: decision === 'working' ? 'working' : 'idle'
            };
          })
        }));
      },

      /**
       * Apply efficiency penalty based on hunger/fatigue
       * Returns: efficiency multiplier (0.1 - 1.0)
       */
      getAgentEfficiencyMultiplier: (agentId) => {
        const { agents } = get();
        const agent = agents.find((a) => a.id === agentId);
        if (!agent) return 1.0;

        let multiplier = 1.0;

        // Hunger penalty: >80 = -50% efficiency
        if (agent.hunger > 80) {
          multiplier *= 0.5;
        }

        // Fatigue penalty: >90 = random failures, >70 = -30% efficiency
        if (agent.fatigue > 90) {
          multiplier *= Math.random() > 0.5 ? 0.2 : 1.0; // 50% chance of failure
        } else if (agent.fatigue > 70) {
          multiplier *= 0.7;
        }

        // Equipment penalty: >70 = -20% efficiency
        if (agent.equipmentWear > 70) {
          multiplier *= 0.8;
        }

        return Math.max(0.1, multiplier);
      },

      /**
       * Reset needs for new season
       */
      resetNeedsForNewSeason: () => {
        set((state) => ({
          agents: state.agents.map((agent) => ({
            ...agent,
            hunger: 30,
            fatigue: 25,
            equipmentWear: 20,
            currentDecision: 'idle',
            decidedZone: null,
            assignedZone: null,
            status: 'idle'
          }))
        }));
      },

      // ===== Utilities =====
      getAverageMorale: () => {
        const { agents } = get();
        if (agents.length === 0) return 50;
        const sum = agents.reduce((acc, agent) => acc + agent.morale, 0);
        return Math.round(sum / agents.length);
      },

      getAverageHunger: () => {
        const { agents } = get();
        if (agents.length === 0) return 30;
        const sum = agents.reduce((acc, agent) => acc + (agent.hunger ?? 30), 0);
        return Math.round(sum / agents.length);
      },

      getAverageFatigue: () => {
        const { agents } = get();
        if (agents.length === 0) return 25;
        const sum = agents.reduce((acc, agent) => acc + (agent.fatigue ?? 25), 0);
        return Math.round(sum / agents.length);
      }
    }),
    {
      name: STORAGE_KEY,
      storage: createJSONStorage(() => localStorage)
    }
  )
);

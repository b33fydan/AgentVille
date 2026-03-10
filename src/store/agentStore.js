import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

const AGENT_STORAGE_KEY = 'agentville-game';
const ISLAND_STORAGE_KEY = 'agentville-island';
const DEFAULT_ISLAND_NAME = 'My Island';

// ============= Helpers =============

function toNumber(value, fallback = 0) {
  const next = Number(value);
  return Number.isFinite(next) ? next : fallback;
}

function getStorage() {
  return typeof window === 'undefined' ? null : window.localStorage;
}

function sanitizeIslandName(value) {
  const next = String(value ?? '').trim();
  return next || DEFAULT_ISLAND_NAME;
}

function readIslandMetadata() {
  const storage = getStorage();
  if (!storage) {
    return {
      islandName: DEFAULT_ISLAND_NAME
    };
  }

  try {
    const raw = storage.getItem(ISLAND_STORAGE_KEY);
    if (!raw) {
      return {
        islandName: DEFAULT_ISLAND_NAME
      };
    }

    const parsed = JSON.parse(raw);
    return {
      islandName: sanitizeIslandName(parsed?.islandName)
    };
  } catch {
    return {
      islandName: DEFAULT_ISLAND_NAME
    };
  }
}

function writeIslandMetadata({ islandName }) {
  const storage = getStorage();
  if (!storage) {
    return;
  }

  try {
    storage.setItem(
      ISLAND_STORAGE_KEY,
      JSON.stringify({
        islandName: sanitizeIslandName(islandName)
      })
    );
  } catch {
    // Ignore localStorage write failures.
  }
}

// ============= Agent Generation =============

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
  // Sliders: 0-100
  return {
    workEthic: Math.floor(Math.random() * 100), // 0=lazy, 100=overachiever
    risk: Math.floor(Math.random() * 100), // 0=cautious, 100=gambler
    loyalty: Math.floor(Math.random() * 100), // 0=independent, 100=obedient
    specialization: ['forest', 'plains', 'wetlands'][Math.floor(Math.random() * 3)]
  };
}

function createAgent(index) {
  const id = `agent-${index}-${Date.now()}`;
  return {
    id,
    name: generateAgentName(),
    morale: 75, // Start at neutral-happy
    traits: generateAgentTraits(),
    xp: 0,
    zoneName: null, // 'forest' | 'plains' | 'wetlands' | null
    efficiency: 1.0, // Multiplier based on morale + zone fit
    lastComment: null // For Field Log display
  };
}

// ============= Initial State =============

const initialIsland = readIslandMetadata();
const initialAgents = [
  createAgent(0),
  createAgent(1),
  createAgent(2)
];

// ============= Store =============

export const useAgentStore = create(
  persist(
    (set, get) => ({
      // ===== Island Metadata & Grid =====
      islandName: initialIsland.islandName,
      island: {
        terrainGrid: [], // 8x8 array of terrain types
        seed: 0
      },
      setIslandName: (name) => {
        const nextName = sanitizeIslandName(name);
        set({ islandName: nextName });
        writeIslandMetadata({ islandName: nextName });
      },

      // ===== Agents =====
      agents: initialAgents,
      updateAgent: (agentId, updates) => {
        set((state) => ({
          agents: state.agents.map((agent) =>
            agent.id === agentId ? { ...agent, ...updates } : agent
          )
        }));
      },
      setAgentZone: (agentId, zoneName) => {
        const agent = get().agents.find((a) => a.id === agentId);
        if (!agent) return;

        // Update zone
        get().updateAgent(agentId, { 
          zoneName,
          efficiency: calculateEfficiency(agent.morale, agent.traits, zoneName)
        });

        // Apply morale bonus/penalty based on zone fit
        if (zoneName) {
          const isFit = agent.traits?.specialization === zoneName;
          const moraleDelta = isFit ? 5 : -2; // +5 if matched, -2 if mismatched
          get().updateAgentMorale(agentId, moraleDelta);
        }
      },
      updateAgentMorale: (agentId, delta) => {
        set((state) => ({
          agents: state.agents.map((agent) => {
            if (agent.id !== agentId) return agent;
            const newMorale = Math.max(0, Math.min(100, agent.morale + delta));
            const newEfficiency = calculateEfficiency(newMorale, agent.traits, agent.zoneName);
            return {
              ...agent,
              morale: newMorale,
              efficiency: newEfficiency
            };
          })
        }));
      },
      hireAgent: () => {
        const nextIndex = get().agents.length;
        set((state) => ({
          agents: [...state.agents, createAgent(nextIndex)]
        }));
      },
      fireAgent: (agentId) => {
        set((state) => ({
          agents: state.agents.filter((agent) => agent.id !== agentId)
        }));
      },

      // ===== Resources =====
      resources: {
        wood: 0,
        wheat: 0,
        hay: 0
      },
      addResource: (resourceType, amount) => {
        set((state) => ({
          resources: {
            ...state.resources,
            [resourceType]: Math.max(0, state.resources[resourceType] + toNumber(amount, 0))
          }
        }));
      },
      setResource: (resourceType, amount) => {
        set((state) => ({
          resources: {
            ...state.resources,
            [resourceType]: Math.max(0, toNumber(amount, 0))
          }
        }));
      },

      // ===== Season State =====
      season: {
        currentDay: 1, // 1-7
        seasonNumber: 1,
        isInSaleDay: false
      },
      advanceDay: () => {
        // Apply morale effects before day advance
        const { agents } = get();
        agents.forEach((agent) => {
          if (!agent.zoneName) {
            // Idle agents lose morale (-2 per day)
            get().updateAgentMorale(agent.id, -2);
          } else {
            // Working agents gain morale (+1 per day)
            get().updateAgentMorale(agent.id, 1);
          }
        });

        // Generate resources from assigned agents
        get().generateResourcesFromAgents();

        set((state) => {
          const nextDay = state.season.currentDay + 1;
          if (nextDay > 7) {
            return {
              season: {
                currentDay: 1,
                seasonNumber: state.season.seasonNumber + 1,
                isInSaleDay: false
              }
            };
          }
          return {
            season: {
              ...state.season,
              currentDay: nextDay
            }
          };
        });
      },
      triggerSaleDay: () => {
        set((state) => ({
          season: {
            ...state.season,
            isInSaleDay: true
          }
        }));
      },
      completeSeason: () => {
        set((state) => ({
          season: {
            currentDay: 1,
            seasonNumber: state.season.seasonNumber + 1,
            isInSaleDay: false
          },
          resources: {
            wood: 0,
            wheat: 0,
            hay: 0
          }
        }));
      },

      // ===== Crisis System =====
      crisisLog: [], // Array of { season, day, crisis, choice, outcome }
      crisisCount: 0, // Crises triggered this day (max 2)
      recordCrisis: (crisisData) => {
        set((state) => ({
          crisisLog: [...state.crisisLog, crisisData],
          crisisCount: state.crisisCount + 1
        }));
      },

      // ===== Calculations =====
      getProfit: () => {
        const { resources } = get();
        const marketPrices = { wood: 2, wheat: 5, hay: 3 };
        const total =
          resources.wood * marketPrices.wood +
          resources.wheat * marketPrices.wheat +
          resources.hay * marketPrices.hay;
        return total;
      },
      getAverageMorale: () => {
        const { agents } = get();
        if (agents.length === 0) return 50;
        const sum = agents.reduce((acc, agent) => acc + agent.morale, 0);
        return Math.round(sum / agents.length);
      },
      getRiotRisk: () => {
        const { agents, crisisLog, season } = get();
        const ignoredCrises = crisisLog.filter((log) => log.season === season.seasonNumber && log.ignored).length;
        const lowMoraleAgents = agents.filter((agent) => agent.morale < 20).length;
        const profit = get().getProfit();

        if (lowMoraleAgents === 0 && ignoredCrises < 3 && profit >= 0) {
          return 0;
        }

        // Simplified riot risk: 0.001 baseline if conditions are bad
        const baseRisk = 0.001;
        const ignoredFactor = ignoredCrises * 0.0005;
        const moraleFactor = lowMoraleAgents * 0.0003;
        const lossessFactor = profit < 0 ? 0.0005 : 0;

        return Math.min(1, baseRisk + ignoredFactor + moraleFactor + lossessFactor);
      },

      // ===== Resource Generation =====
      generateResourcesFromAgents: () => {
        const { agents } = get();

        // Each agent generates resources based on zone + efficiency
        agents.forEach((agent) => {
          if (!agent.zoneName) return;

          const baseAmount = 0.5; // Resources per agent per generation tick
          const efficiency = agent.efficiency || 1.0;
          const totalGeneration = baseAmount * efficiency;

          // Assign resources by zone specialization
          if (agent.zoneName === 'forest') {
            get().addResource('wood', totalGeneration);
          } else if (agent.zoneName === 'plains') {
            get().addResource('wheat', totalGeneration);
          } else if (agent.zoneName === 'wetlands') {
            get().addResource('hay', totalGeneration);
          }
        });
      }
    }),
    {
      name: AGENT_STORAGE_KEY,
      storage: createJSONStorage(() => localStorage),
      merge: (persistedState, currentState) => {
        const merged = {
          ...currentState,
          ...(persistedState ?? {})
        };
        const islandFromLocal = readIslandMetadata();
        return {
          ...merged,
          islandName: sanitizeIslandName(islandFromLocal.islandName || merged.islandName)
        };
      }
    }
  )
);

// ============= Efficiency Calculation =============

function calculateEfficiency(morale, traits, zoneName) {
  // Morale: 0-100 → 0.2-1.0 multiplier
  const moraleMultiplier = 0.2 + (morale / 100) * 0.8;

  // Work ethic factor
  const workEthicBonus = (traits?.workEthic || 50) / 100 * 0.2; // Up to +20%

  // Zone fit bonus
  let zoneFitBonus = 0;
  if (zoneName && traits?.specialization === zoneName) {
    // Perfect match: +10% efficiency bonus
    zoneFitBonus = 0.1;
  } else if (zoneName) {
    // Mismatch: -5% efficiency penalty
    zoneFitBonus = -0.05;
  }

  return Math.max(0.1, moraleMultiplier + workEthicBonus + zoneFitBonus);
}

import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

const STORAGE_KEY = 'agentville-game';

// ============= Helpers =============

function toNumber(value, fallback = 0) {
  const next = Number(value);
  return Number.isFinite(next) ? next : fallback;
}

function getStorage() {
  return typeof window === 'undefined' ? null : window.localStorage;
}

// ============= Store =============

export const useGameStore = create(
  persist(
    (set, get) => ({
      // ===== Island =====
      islandName: 'My Island',
      islandSeed: 0,
      terrain: [], // 64 tile objects: [{ x, z, type: 'forest'|'plains'|'wetlands'|'barren' }, ...]

      setIslandName: (name) => {
        set({ islandName: String(name ?? '').trim() || 'My Island' });
      },

      setTerrain: (tiles) => {
        set({ terrain: tiles });
      },

      setIslandSeed: (seed) => {
        set({ islandSeed: seed });
      },

      // ===== Resources =====
      resources: {
        wood: 0,
        wheat: 0,
        hay: 0,
        coins: 42 // Starting capital
      },

      addResource: (type, amount) => {
        set((state) => ({
          resources: {
            ...state.resources,
            [type]: Math.max(0, state.resources[type] + toNumber(amount, 0))
          }
        }));
      },

      spendResource: (type, amount) => {
        const current = get().resources[type];
        if (current < amount) {
          return false;
        }
        get().addResource(type, -amount);
        return true;
      },

      setResource: (type, amount) => {
        set((state) => ({
          resources: {
            ...state.resources,
            [type]: Math.max(0, toNumber(amount, 0))
          }
        }));
      },

      // ===== Season =====
      season: 1,
      day: 1,
      timeOfDay: 'morning', // 'morning' | 'evening'
      daysInSeason: 7,

      advanceTime: () => {
        set((state) => {
          let nextDay = state.day;
          let nextTimeOfDay = state.timeOfDay;

          if (nextTimeOfDay === 'morning') {
            nextTimeOfDay = 'evening';
          } else {
            // Evening → next morning (increment day)
            nextTimeOfDay = 'morning';
            nextDay += 1;

            if (nextDay > state.daysInSeason) {
              // Season ended
              return {
                day: 1,
                timeOfDay: 'morning',
                season: state.season + 1,
                // Resources stay for sale day calculation
              };
            }
          }

          return {
            day: nextDay,
            timeOfDay: nextTimeOfDay
          };
        });
      },

      resetSeason: () => {
        set({
          day: 1,
          timeOfDay: 'morning',
          season: get().season + 1,
          resources: {
            wood: 0,
            wheat: 0,
            hay: 0,
            coins: 42
          }
        });
      },

      // ===== Game Phase =====
      gamePhase: 'onboarding', // 'onboarding' | 'playing' | 'crisis' | 'saleDay' | 'riot' | 'cooldown'

      setGamePhase: (phase) => {
        set({ gamePhase: phase });
      },

      // ===== Season Tracking =====
      crisisLog: [], // { season, day, crisis, choice, outcome }
      seasonHistory: [], // { season, profit, finalMorale, events }
      riotHistory: [], // { season, day, outcome }

      addCrisisToLog: (crisisResult) => {
        set((state) => ({
          crisisLog: [...state.crisisLog, crisisResult]
        }));
      },

      endSeason: (results) => {
        set((state) => ({
          seasonHistory: [...state.seasonHistory, results],
          crisisLog: [] // Clear for next season
        }));
        get().resetSeason();
      },

      addRiotToHistory: (riotData) => {
        set((state) => ({
          riotHistory: [...state.riotHistory, riotData]
        }));
      },

      // ===== Market Prices =====
      prices: {
        wood: 2,
        wheat: 5,
        hay: 3
      },

      getProfit: () => {
        const { resources, prices } = get();
        const total =
          resources.wood * prices.wood +
          resources.wheat * prices.wheat +
          resources.hay * prices.hay;
        return total;
      },

      // ===== Utilities =====
      clearOldStorage: () => {
        const storage = getStorage();
        if (!storage) return;
        try {
          // Clear legacy monolith key if it exists
          storage.removeItem('agentville-store');
        } catch {
          // Ignore
        }
      }
    }),
    {
      name: STORAGE_KEY,
      storage: createJSONStorage(() => localStorage),
      onRehydrateStorage: () => (state) => {
        // One-time migration: clear old monolith storage
        if (state) {
          state.clearOldStorage();
        }
      }
    }
  )
);

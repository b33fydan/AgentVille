import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { useGameStore } from './gameStore';

const STORAGE_KEY = 'agentville-log';

// ============= Store =============

export const useLogStore = create(
  persist(
    (set, get) => ({
      // ===== Field Log Entries =====
      entries: [], // [{ id, agentId, agentName, type, message, season, day, timeOfDay }, ...]

      addLogEntry: ({ agentId, agentName, type, message }) => {
        const gameState = useGameStore.getState();
        const { season, day, timeOfDay } = gameState;

        const entry = {
          id: `log-${Date.now()}-${Math.random()}`,
          agentId,
          agentName,
          type, // 'status' | 'crisis_reaction' | 'complaint' | 'feedback' | 'riot_warning' | 'outcome'
          message,
          season,
          day,
          timeOfDay
        };

        set((state) => ({
          entries: [...state.entries, entry]
        }));
      },

      clearSeasonLog: () => {
        // Archive current entries (in real app, might move to separate archive)
        // For now, just clear them
        set({ entries: [] });
      },

      getEntriesBySeason: (season) => {
        return get().entries.filter((entry) => entry.season === season);
      },

      getEntriesByAgent: (agentId) => {
        return get().entries.filter((entry) => entry.agentId === agentId);
      },

      getRecentEntries: (limit = 10) => {
        const entries = get().entries;
        return entries.slice(Math.max(0, entries.length - limit));
      }
    }),
    {
      name: STORAGE_KEY,
      storage: createJSONStorage(() => localStorage)
    }
  )
);

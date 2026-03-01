import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

export const LEVEL_THRESHOLDS = [3000, 6000, 10000, 20000, 50000, 80000, 120000, 170000, 230000, 300000, 380000];

const ARMOR_TIER_BY_LEVEL = [
  { minLevel: 12, tier: 'legend' },
  { minLevel: 8, tier: 'champion' },
  { minLevel: 5, tier: 'knight' },
  { minLevel: 3, tier: 'soldier' },
  { minLevel: 2, tier: 'recruit' },
  { minLevel: 1, tier: 'peasant' }
];

function toNumber(value, fallback = 0) {
  const next = Number(value);
  return Number.isFinite(next) ? next : fallback;
}

export function getArmorTierForLevel(level) {
  const safeLevel = Math.max(1, Math.floor(toNumber(level, 1)));
  return ARMOR_TIER_BY_LEVEL.find((entry) => safeLevel >= entry.minLevel)?.tier ?? 'peasant';
}

export function getIslandStageForMonths(monthsCompleted) {
  const safeMonths = Math.max(0, Math.floor(toNumber(monthsCompleted, 0)));

  if (safeMonths >= 12) {
    return 6;
  }

  if (safeMonths >= 8) {
    return 5;
  }

  if (safeMonths >= 5) {
    return 4;
  }

  if (safeMonths >= 3) {
    return 3;
  }

  if (safeMonths >= 2) {
    return 2;
  }

  if (safeMonths >= 1) {
    return 1;
  }

  return 0;
}

function getLevelFromXP(xp) {
  const safeXP = Math.max(0, toNumber(xp, 0));
  let level = 1;

  LEVEL_THRESHOLDS.forEach((threshold) => {
    if (safeXP >= threshold) {
      level += 1;
    }
  });

  return level;
}

function getNextLevelXP(level) {
  const index = Math.max(0, Math.floor(level) - 1);
  return LEVEL_THRESHOLDS[index] ?? null;
}

function getXPProgress(xp, level) {
  const safeXP = Math.max(0, toNumber(xp, 0));
  const safeLevel = Math.max(1, Math.floor(toNumber(level, 1)));
  const previousThreshold = safeLevel <= 1 ? 0 : LEVEL_THRESHOLDS[safeLevel - 2] ?? LEVEL_THRESHOLDS.at(-1) ?? 0;
  const nextThreshold = LEVEL_THRESHOLDS[safeLevel - 1];

  if (!nextThreshold) {
    return 100;
  }

  const span = Math.max(1, nextThreshold - previousThreshold);
  const current = Math.min(Math.max(0, safeXP - previousThreshold), span);
  return Math.max(0, Math.min(100, (current / span) * 100));
}

function withComputed(state) {
  const level = Math.max(1, Math.floor(toNumber(state.level, 1)));
  const xp = Math.max(0, toNumber(state.xp, 0));
  const monthsCompleted = Math.max(0, Math.floor(toNumber(state.monthsCompleted, 0)));

  return {
    ...state,
    level,
    xp,
    armorTier: getArmorTierForLevel(level),
    nextLevelXP: getNextLevelXP(level),
    xpProgress: getXPProgress(xp, level),
    monthsCompleted,
    islandStage: getIslandStageForMonths(monthsCompleted),
    totalBillsSlain: Math.max(0, Math.floor(toNumber(state.totalBillsSlain, 0)))
  };
}

const transientDefaults = {
  isInBattle: false,
  battleRequest: null,
  battleDisplayXP: null,
  hudAnnouncement: null
};

const initialState = withComputed({
  level: 1,
  xp: 0,
  totalBillsSlain: 0,
  heroVisible: false,
  heroPosition: { x: 0, z: 0 },
  armorTier: 'peasant',
  monthsCompleted: 0,
  islandStage: 0,
  nextLevelXP: LEVEL_THRESHOLDS[0],
  xpProgress: 0,
  ...transientDefaults
});

export const useGameStore = create(
  persist(
    (set, get) => ({
      ...initialState,
      addXP: (amount) => {
        const safeAmount = Math.max(0, toNumber(amount, 0));

        set((state) => {
          const nextXP = state.xp + safeAmount;
          const nextLevel = getLevelFromXP(nextXP);
          return withComputed({
            ...state,
            xp: nextXP,
            level: nextLevel
          });
        });
      },
      levelUp: () => {
        set((state) =>
          withComputed({
            ...state,
            level: state.level + 1
          })
        );
      },
      incrementMonthsCompleted: () => {
        set((state) =>
          withComputed({
            ...state,
            monthsCompleted: state.monthsCompleted + 1
          })
        );
      },
      incrementBillsSlain: (count = 1) => {
        const safeCount = Math.max(0, Math.floor(toNumber(count, 0)));

        set((state) => ({
          totalBillsSlain: state.totalBillsSlain + safeCount
        }));
      },
      setHeroVisible: (visible) => {
        set({ heroVisible: Boolean(visible) });
      },
      setHeroPosition: ({ x, z }) => {
        set({
          heroPosition: {
            x: toNumber(x, 0),
            z: toNumber(z, 0)
          }
        });
      },
      resetXP: () => {
        set((state) =>
          withComputed({
            ...state,
            xp: 0
          })
        );
      },
      requestBattle: (bills) => {
        const safeBills = Array.isArray(bills)
          ? bills
              .filter((bill) => bill && Number.isFinite(Number(bill.amount)))
              .map((bill) => ({
                id: String(bill.id ?? ''),
                name: String(bill.name ?? 'Bill'),
                amount: Math.max(0, Number(bill.amount)),
                category: String(bill.category ?? 'other')
              }))
          : [];

        if (safeBills.length === 0) {
          return;
        }

        set((state) => {
          if (state.isInBattle) {
            return state;
          }

          return {
            battleRequest: {
              id: globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`,
              bills: safeBills
            }
          };
        });
      },
      clearBattleRequest: () => {
        set({ battleRequest: null });
      },
      setBattleState: (isInBattle) => {
        set({ isInBattle: Boolean(isInBattle) });
      },
      setBattleDisplayXP: (xp) => {
        set({ battleDisplayXP: Number.isFinite(Number(xp)) ? Math.max(0, Number(xp)) : null });
      },
      clearBattleDisplayXP: () => {
        set({ battleDisplayXP: null });
      },
      announceHUD: ({ type, headline, subtitle = '' }) => {
        if (!type || !headline) {
          return;
        }

        set({
          hudAnnouncement: {
            id: globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`,
            type: String(type),
            headline: String(headline),
            subtitle: String(subtitle)
          }
        });
      },
      clearHUDAnnouncement: () => {
        set({ hudAnnouncement: null });
      },
      getProgressSnapshot: () => {
        const state = get();

        return {
          level: state.level,
          xp: state.xp,
          armorTier: state.armorTier,
          nextLevelXP: state.nextLevelXP,
          xpProgress: state.xpProgress,
          monthsCompleted: state.monthsCompleted,
          islandStage: state.islandStage,
          totalBillsSlain: state.totalBillsSlain
        };
      }
    }),
    {
      name: 'payday-kingdom-game',
      storage: createJSONStorage(() => localStorage),
      partialize: (state) => ({
        level: state.level,
        xp: state.xp,
        totalBillsSlain: state.totalBillsSlain,
        heroVisible: state.heroVisible,
        heroPosition: state.heroPosition,
        armorTier: state.armorTier,
        monthsCompleted: state.monthsCompleted
      }),
      merge: (persistedState, currentState) => {
        const merged = {
          ...currentState,
          ...(persistedState ?? {}),
          ...transientDefaults
        };

        return withComputed({
          ...merged,
          level: getLevelFromXP(merged.xp)
        });
      }
    }
  )
);

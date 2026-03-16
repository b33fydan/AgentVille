# AgentVille — Phase 3A: Game Tick + Agent Autonomy

**Status:** Active
**Executor:** Claude Code
**Estimated Effort:** 8–12 hours
**Depends On:** Nothing — starts from stable main branch
**Previous:** AV-MOVE-001 (Complete), CC-FIX Desktop SeasonHUD (Complete)

---

## Vision

Transform AgentVille from button-click-to-advance into a living world. Same game mechanics, same crisis engine, same morale system — new continuous tick model where agents act autonomously and time flows.

**The shift:** discrete event model → continuous tick model.

Today: Player clicks "Advance" → advanceDay() fires → everything happens at once.
Phase 3A: GameTicker runs continuously → agents evaluate tasks → move → work → resources trickle in → crises roll per tick → day boundaries trigger season logic.

---

## Execution Order

```
3A-1: GameTicker Engine          [FIRST — everything depends on this]
3A-2: Agent Task Queue + Movement [SECOND — depends on 3A-1]
3A-3: UI Migration (Speed Controls) [PARALLEL with 3A-2]
3A-4: Day/Night Lighting Cycle     [PARALLEL with 3A-2]
```

---

## 3A-1: GameTicker Engine

**New file:** `src/engine/GameTicker.js`

- `requestAnimationFrame`-based loop with delta time accumulator
- Configurable tick rate: 1 game-day = 3 real-minutes at 1x speed
- Speed controls: Pause / 1x / 2x / 3x (multiplies tick rate)
- Emits events on boundaries: `tick`, `hourChange`, `dayPhaseChange` (morning/afternoon/evening/night), `dayChange`, `seasonEnd`
- Zustand integration: reads/writes to gameStore time state
- Pause automatically on: crisis modal open, sale day modal, any consequence modal
- Resume on modal close
- Exposed via singleton for component access

**Time model:**
```
1 game-day = 3 minutes real time (at 1x)
1 game-season = 7 days = 21 minutes real time (at 1x)
Morning:   0:00 - 6:00 game-hours (0-25% of day)
Afternoon: 6:00 - 12:00 game-hours (25-50%)
Evening:   12:00 - 18:00 game-hours (50-75%)
Night:     18:00 - 24:00 game-hours (75-100%)
```

**Acceptance Criteria:**
- [ ] Game time advances without player input
- [ ] Speed buttons (Pause/1x/2x/3x) replace "Advance to..." button
- [ ] Game pauses when any modal is open
- [ ] Day counter increments automatically at day boundary
- [ ] Season end triggers SaleDay sequence at Day 7 boundary
- [ ] All existing crisis/morale/consequence logic fires at correct time boundaries
- [ ] localStorage persists game time state across refreshes

---

## 3A-2: Agent Task Queue + Autonomous Movement

**New file:** `src/engine/AgentAI.js`
**Modified:** `src/store/agentStore.js` (READ — do NOT change store shape)

**Agent Task State Machine:**
```
IDLE → WALKING_TO_ZONE → WORKING → WALKING_TO_STORAGE → DEPOSITING → IDLE
                                      ↓ (crisis)
                                  REACTING → resume previous
                                      ↓ (low morale)
                                  SULKING (reduced speed, no work)
                                      ↓ (break time)
                                  WANDERING (random movement, ambient reactions)
```

**Task Cycle (per agent, per tick):**
- IDLE + assignedZone → pick tile in zone → WALKING_TO_ZONE
- WALKING_TO_ZONE → move one step toward target → if arrived → WORKING
- WORKING → play work animation, increment workTicks → when done → generate resource → loop
- Unassigned agents → WANDERING (random nearby tile movement)

**Movement:** Lerp between tiles, face direction of travel, bob animation. Simple adjacent-tile stepping (no A* needed on 8x8 grid).

**Acceptance Criteria:**
- [ ] Agents walk smoothly between tiles (no teleporting)
- [ ] Agents face their direction of travel
- [ ] Agents perform work cycles when at their assigned zone
- [ ] Resources trickle in gradually (not all-at-once)
- [ ] Unassigned agents wander randomly
- [ ] Agents pause/react visually when crisis fires
- [ ] Movement speed scales with game speed (1x/2x/3x)
- [ ] Field log entries still fire for assignments, crises, morale

---

## 3A-3: UI Migration — Speed Controls + Time HUD

**Modified:** `SeasonHUD.jsx`, mobile overlay

Replace "Advance" button with speed controls and live time display:
```
Season 1 | Day 3 | Afternoon
 Pause  1x  2x  3x  | Wood 24  Wheat 18  Hay 12 | $42 coins
```

- Speed buttons: Pause / 1x / 2x / 3x (highlight active)
- Time-of-day indicator (Morning/Afternoon/Evening/Night)
- Resources update live as agents deposit
- Day counter increments automatically
- Keyboard shortcuts: Space = pause/play, 1/2/3 = speed

**Acceptance Criteria:**
- [ ] Speed controls visible and functional on desktop and mobile
- [ ] Active speed visually highlighted
- [ ] Time-of-day label updates in real time
- [ ] Resources animate as they increment
- [ ] Keyboard shortcuts work on desktop
- [ ] "Advance" button fully removed from both layouts

---

## 3A-4: Day/Night Lighting Cycle

**Modified:** `IslandSceneManager.js`

**Lighting States:**
```
Morning:   DirectionalLight warm gold (#FFE4B5), intensity 0.8, angle 15deg
Afternoon: DirectionalLight bright white (#FFFFFF), intensity 1.0, angle 60deg
Evening:   DirectionalLight orange (#FF8C42), intensity 0.6, angle 15deg (opposite side)
Night:     DirectionalLight cool blue (#4A6FA5), intensity 0.3, angle 45deg (moon)
           + AmbientLight bump to 0.4 to keep scene visible
```

- Lerp between states based on game-hour (smooth transitions)
- Sky/background color shifts with time
- Shadow direction rotates with sun position
- Scene always visible (night is dim, never black)

**Acceptance Criteria:**
- [ ] Smooth lighting transitions over the course of a game day
- [ ] Scene is always visible (night is dim, not black)
- [ ] Shadows rotate with light source
- [ ] Background color shifts match time-of-day
- [ ] Zero additional draw calls (just parameter changes on existing lights)

---

## What NOT to Change

- **Crisis Engine** — just triggered by tick instead of button
- **Morale Consequences** — same triggers, same modals
- **Agent Reactions Library** — same library, new trigger contexts
- **Share Card System** — untouched
- **Field Log** — same system
- **Zustand Store Architecture** — extended, not replaced
- **Claude API Integration** — untouched
- **Onboarding Flow** — untouched

---

## DO NOT TOUCH (Stable Game Logic)

- `crisisEngine.js` — stable, 20+ templates
- `moraleConsequences.js` — stable
- `agentReactions.js` — stable, 190+ reactions
- `cardGenerator.js` — stable
- `soundManager.js` — stable (will be extended in 3C-4, not now)

---

## Test Checkpoint (After All 3A Complete)

Game should be fully playable with:
- Agents moving autonomously
- Speed controls working
- Day/night cycle visible
- All existing mechanics firing on tick events
- 60fps maintained
- No regressions to crisis/morale/share systems

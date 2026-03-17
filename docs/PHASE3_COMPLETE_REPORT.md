# AgentVille Phase 3 — Complete Build Report

**Date:** March 16, 2026
**Executor:** Claude Code (Opus 4.6)
**Commits:** 12 (4021cb2 → 8328899)
**Deploy:** Live on agent-ville-kappa.vercel.app

---

## What Was Built

Phase 3 transformed AgentVille from a button-click state management app into a living, breathing farm simulation. Same game mechanics — new presentation layer.

### Before Phase 3
- Player clicks "Advance to Evening" / "Advance to Next Day" button
- Everything happens instantly (resources, crises, morale)
- Static lighting, no ambient life
- ~12 cube agents, ~4,000 individual terrain meshes
- No sound atmosphere
- SeasonHUD invisible on desktop (bug)

### After Phase 3
- Game time flows continuously (1 day = 3 real minutes at 1x)
- Speed controls: Pause / 1x / 2x / 3x + keyboard shortcuts (Space, 1/2/3)
- Agents walk to zones, work autonomously, wander when idle
- Resources trickle in during work cycles (not batch)
- Day/night cycle: dawn gold → noon white → sunset orange → night blue
- 9 farm animals wander with idle/walk animations
- Crops visually grow over the season (seed → sprout → growing → mature)
- Chimney smoke (morning/evening), fireflies (night)
- Ambient soundscape: bird chirps (day), crickets (evening), quiet hum (night)
- ~180 cube agents with hair, belt, shoes, face detail
- Terrain props batched via InstancedMesh (~25 draw calls vs ~4,000)
- Water color shimmer tied to animation loop
- Crisis modal properly triggers with continuous ticker

---

## Commit Log

| Commit | Type | Description |
|--------|------|-------------|
| `4021cb2` | fix | Desktop SeasonHUD not rendering (canvas overflow + z-index) |
| `44b5787` | feat | Quick-wins: Riot Roast Card share, Island Screenshot Card, Sound Toggle |
| `b4af3ef` | feat | **3A-1:** GameTicker engine — continuous game loop with speed controls |
| `cbe5813` | feat | **3A-4:** Day/night lighting cycle (8 presets, smooth lerp) |
| `be2deb9` | feat | **3A-2:** Agent AI — autonomous task queue + resource trickle |
| `8507fce` | feat | **3B-1:** InstancedMesh batching for terrain props |
| `3f049ea` | feat | **3B-3:** Farm animals (chickens, cows, dog, cat) |
| `7e9fd42` | feat | **3B-2:** High-density voxel agent models (~180 cubes each) |
| `947f514` | feat | **3C:** Living world polish (crops, particles, water, ambient sound) |
| `8328899` | fix | Crisis modal not triggering with GameTicker |

---

## Technical Architecture

### New Engine Layer (`src/engine/`)

| File | Purpose | Lines |
|------|---------|-------|
| `GameTicker.js` | RAF-based game loop, speed controls, day boundary triggers | ~220 |
| `AgentAI.js` | Per-agent task state machine (idle/walk/work/wander/react) | ~200 |
| `DayNightCycle.js` | 8-preset lighting interpolation, sun/shadow/sky/fog | ~170 |
| `AnimalAI.js` | 9 NPC animals with mesh builders + wander AI | ~400 |
| `CropGrowth.js` | Day-based crop stage visualization | ~120 |
| `AmbientParticles.js` | Chimney smoke + firefly particle pools | ~170 |

### Modified Files

| File | Changes |
|------|---------|
| `gameStore.js` | Added: `gameHour`, `dayPhase`, `gameSpeed` + setters |
| `advanceDayHandler.js` | Resource gen skipped when ticker active (AgentAI handles trickle) |
| `soundManager.js` | Added: ambient soundscape system (bird/cricket/night loops, phase crossfade) |
| `agentBuilder.js` | Rebuilt: ~180 voxel cubes per agent (was ~12), shared geometry/materials |
| `terrainPropsBuilder.js` | Rebuilt: uses VoxelBatcher for InstancedMesh rendering |
| `SeasonHUD.jsx` | Replaced Advance button with speed controls, added Capture + Mute buttons |
| `IslandScene.jsx` | Wired: day/night cycle, animals, crops, particles, water shimmer |
| `CrisisModal.jsx` | Fixed: trigger on gamePhase change, fallback to generateCrisis() |
| `RiotModal.jsx` | Added: "SHARE THIS SHAME" button with card generation |
| `App.jsx` | Wired: GameTicker lifecycle, container-relative scene sizing |

### New Utilities

| File | Purpose |
|------|---------|
| `voxelBatcher.js` | Collects box/cone/sphere instances → flushes as InstancedMesh |

---

## How Systems Connect

```
GameTicker (RAF loop, speed controls)
  ├── tracks gameHour (0-24)
  ├── fires advanceDayLogic() at phase boundaries (hour 12, hour 24)
  ├── ticks AgentAI every frame → agents decide tasks, produce resources
  ├── triggers ambient sound crossfade on dayPhaseChange
  └── writes gameHour/dayPhase/gameSpeed to gameStore

IslandScene (RAF animation loop)
  ├── reads gameHour → applyDayNightLighting() → updates lights/sky/fog
  ├── updateAgentPositions() → smooth movement toward targets
  ├── agent.updateAnimation() → idle/walk/work animations per frame
  ├── updateAnimals() → NPC wander + idle/walk animations
  ├── updateCrops() → rebuild crop meshes on day change
  ├── updateParticles() → smoke (morning/evening) + fireflies (night)
  └── water color shimmer

AgentAI (ticked by GameTicker)
  ├── IDLE → wander randomly near center
  ├── WALKING_TO_ZONE → setAgentTarget() in agentMovement.js
  ├── WORKING → produce resources every 2 game-hours
  └── REACTING → pause during crisis phase

Stores (Zustand + localStorage)
  ├── gameStore: season, day, gameHour, dayPhase, gameSpeed, resources, crisisLog
  ├── agentStore: agents (morale, zone, inventory, needs, decisions)
  └── logStore: field log entries
```

---

## Performance

| Metric | Before Phase 3 | After Phase 3 |
|--------|----------------|---------------|
| Terrain draw calls | ~4,000+ individual meshes | ~25 InstancedMeshes |
| Agent cubes | ~36 total (12 × 3 agents) | ~540 total (180 × 3 agents) |
| Animal meshes | 0 | ~90 (9 animals × ~10 parts) |
| Particle pool | 0 | 32 (12 smoke + 20 firefly, pooled) |
| JS Bundle (main) | 134.6 KB | 144.5 KB (+10 KB for 6 engine files) |
| IslandScene chunk | 23.4 KB | 35.5 KB (+12 KB for day/night + animals + crops + particles) |
| Build time | ~3.0s | ~3.0s (no change) |
| Target FPS | 60 | 60 (maintained) |

---

## What's Stable (Do Not Touch)

These systems were NOT modified during Phase 3 and remain stable:

- `crisisEngine.js` — 20+ crisis templates, CrisisQueue singleton
- `moraleConsequences.js` — desertions, strikes, demands
- `agentReactions.js` — 190+ trait-based reactions
- `cardGenerator.js` — 4 card types (season, quote, riot, island)
- `ShareModal.jsx` — download/copy/share pipeline
- `agentDecisions.js` — autonomous decision matrix
- `economicEngine.js` — supply/demand price simulation
- `agentConflict.js` — theft, alliances, boycotts
- `agentTrading.js` — agent-to-agent market trading
- `OnboardingFlow.jsx` — 3-stage intro
- `LandingPage.jsx` — pre-game landing

---

## Known Issues / Tech Debt

| Issue | Impact | Notes |
|-------|--------|-------|
| Agent models use individual meshes (~180 each) | Higher draw calls per agent | Could be InstancedMesh batched, but animation requires per-part transforms |
| Crop growth only covers plains biome | Forest/wetlands don't show growth | Could extend CropGrowth.js for zone-specific crop types |
| Ambient sound is very basic (procedural) | Not immersive enough for long sessions | Could add more variation, spatial audio, volume scaling with camera |
| Animal models are static meshes (not batched) | 9 × ~10 = 90 individual meshes | Small count, not a bottleneck, but could batch static parts |
| No multiplayer/accounts | Single-player only | Phase 4+ scope |
| No cosmetics system | Limited replayability | Phase 4+ scope |

---

## What's Ready for Next Phase

### Phase 4 Candidates (from original plan)

1. **Cosmetics System** — Agent hats, tools, body customization, unlocks
2. **Content Expansion** — More crisis templates, agent reactions, roast variety
3. **Game Balance** — Crisis probability curves, threshold tuning, resource balancing
4. **Growth/Social** — Leaderboard, user accounts, multiplayer lobbies
5. **Advanced Agent Systems** — Recovery scheduling, individual strike modulation, demand chains
6. **Bundle Optimization** — Lazy-load Three.js further, code-split modals

### Quick Wins Still Available

| Feature | Effort | Status |
|---------|--------|--------|
| More crisis templates (expand from 20) | Low | crisisEngine.js ready |
| More agent reaction text variety | Low | agentReactions.js ready |
| Seasonal variants (autumn leaves, winter snow) | Medium | DayNightCycle + particles framework ready |
| Camera presets (zoom to zone, follow agent) | Medium | OrbitControls already configured |
| Tutorial/hint system | Medium | OnboardingFlow can be extended |

---

## Deployment

- **Host:** Vercel (agent-ville-kappa.vercel.app)
- **Repo:** github.com/b33fydan/AgentVille (main branch)
- **Build:** `npm run build` → dist/ (auto-deployed on push to main)
- **Build time:** ~3 seconds
- **Total bundle:** ~1.05 MB raw, ~285 KB gzip

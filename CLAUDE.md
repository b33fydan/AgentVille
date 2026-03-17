# AgentVille — Current State

**Last Updated:** March 16, 2026
**Phase 3:** Complete (Living World)
**Deploy:** agent-ville-kappa.vercel.app
**Repo:** github.com/b33fydan/AgentVille

---

## Architecture Overview

```
src/
  engine/                    ← NEW (Phase 3) — game simulation layer
    GameTicker.js            — RAF loop, speed controls, day boundaries
    AgentAI.js               — per-agent task state machine + resource trickle
    DayNightCycle.js         — 8-preset lighting interpolation
    AnimalAI.js              — 9 NPC farm animals with wander AI
    CropGrowth.js            — day-based crop stage visualization
    AmbientParticles.js      — chimney smoke + firefly particle pools

  store/                     ← Zustand + localStorage
    gameStore.js             — season, day, gameHour, dayPhase, gameSpeed, resources
    agentStore.js            — agents (morale, zone, inventory, needs, decisions, trading)
    logStore.js              — field log entries

  utils/                     ← game logic + rendering
    advanceDayHandler.js     — game loop logic (crises, morale, needs, economy)
    crisisEngine.js          — 20+ crisis templates, CrisisQueue
    agentReactions.js        — 190+ trait-based reactions
    moraleConsequences.js    — desertions, strikes, demands
    agentDecisions.js        — autonomous decision matrix
    economicEngine.js        — supply/demand price simulation
    agentConflict.js         — theft, alliances, boycotts
    agentTrading.js          — agent-to-agent trading
    soundManager.js          — 22 procedural sounds + ambient soundscape
    cardGenerator.js         — 4 share card types
    agentBuilder.js          — ~180 voxel agent models with animation
    agentMovement.js         — smooth position interpolation
    voxelBuilder.js          — voxel primitives + terrain colors
    voxelBatcher.js          — InstancedMesh batching utility
    terrainBuilder.js        — 16x16 terrain grid + cliff layers (InstancedMesh)
    terrainPropsBuilder.js   — trees/bushes/rocks/reeds (batched via VoxelBatcher)
    islandSceneManager.js    — Three.js scene sync (agents, resources, flags)

  components/
    scene/IslandScene.jsx    — Three.js canvas, animation loop, all visual systems
    ui/SeasonHUD.jsx         — speed controls, time display, resources, capture/share/mute
    ui/AgentPanel.jsx        — agent list, assignments, field log
    ui/CrisisModal.jsx       — crisis choices + resolution
    ui/SaleDay.jsx           — harvest tally, profit, season card
    ui/RiotModal.jsx         — ACA violation + share card
    ui/ShareModal.jsx        — download/copy/share pipeline
    ui/OnboardingFlow.jsx    — 3-stage intro
    ui/LandingPage.jsx       — pre-game landing
    ConsequencesHandler.jsx  — orchestrates desertion/strike/demand modals
```

---

## Game Loop Flow

```
GameTicker (continuous, speed-controlled)
  ├── gameHour advances (0-24, 1 day = 3 min at 1x)
  ├── AgentAI ticked every frame → agents work → resources trickle
  ├── At hour 12: advanceDayLogic() → crises, morale, economy, needs
  ├── At hour 24: advanceDayLogic() → day increments, season check
  ├── dayPhaseChange → ambient sound crossfade
  └── Auto-pause on crisis/saleDay/consequence modals

IslandScene (RAF animation loop)
  ├── DayNightCycle → lights/sky/fog based on gameHour
  ├── Agent movement + animations
  ├── Animal wander + animations
  ├── Crop growth rebuild on day change
  ├── Particles (smoke morning/evening, fireflies night)
  └── Water shimmer
```

---

## DO NOT TOUCH (Stable Systems)

These are proven and should not be modified without good reason:

- `crisisEngine.js` — 20+ templates, CrisisQueue
- `moraleConsequences.js` — desertions, strikes, demands
- `agentReactions.js` — 190+ reactions
- `agentDecisions.js` — autonomous decision matrix
- `economicEngine.js` — price simulation
- `agentConflict.js` — theft/alliances
- `agentTrading.js` — agent trading
- `cardGenerator.js` — 4 card types
- `terrainBuilder.js` — InstancedMesh terrain

---

## Key Constants

| Constant | Value | Location |
|----------|-------|----------|
| Game day duration | 180s real time (at 1x) | GameTicker.js |
| Season length | 7 days | gameStore.js |
| Agent work cycle | 2 game-hours | AgentAI.js |
| Resource per work cycle | 2 base | AgentAI.js |
| Crisis probability | 50% per advanceDay call | advanceDayHandler.js |
| Move speed (agents) | 2.0 units/sec | agentMovement.js |
| Move speed (animals) | 0.4 units/sec | AnimalAI.js |
| Voxel unit (agents) | 0.06 units | agentBuilder.js |
| Max animals | 9 (5 chicken, 2 cow, 1 dog, 1 cat) | AnimalAI.js |
| Particle pool | 12 smoke + 20 firefly | AmbientParticles.js |

---

## Completed Phases

- **Phase 0:** Foundation cleanup (store split, legacy deletion)
- **Phase 1:** Living island (voxel terrain, agent rendering, terrain props)
- **Phase 1-001:** Agent needs + autonomous decisions
- **Phase 1-002:** Dynamic economy + agent trading
- **Phase 2A:** Game loop + crisis engine + morale consequences
- **Phase 2B:** Audio + sharing (22 sounds, 4 card types)
- **AV-MOVE-001:** Agent movement + work animations + morale visual states
- **Phase 3A:** GameTicker + Agent AI + speed controls + day/night cycle
- **Phase 3B:** InstancedMesh batching + high-density models + farm animals
- **Phase 3C:** Crop growth + particles + water shimmer + ambient sound

---

## Next Phase Candidates

See `docs/PHASE3_COMPLETE_REPORT.md` for detailed recommendations.

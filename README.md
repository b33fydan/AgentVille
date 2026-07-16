# AgentVille

AgentVille is a Godot 4.6 voxel farm game that teaches coding and agent engineering through play. The player writes small programs in the in-game **Agent Workbench**, compiles them into safe Skill Specs, and watches Bert, Marigold, or Chuck carry the resulting work out on the farm. Farming is the curriculum; the Workbench is the classroom.

The live product is entirely under [`godot/`](godot/). It is local-first and deterministic: player programs pass through a hand-written parser, an allowlist validator, runtime guards, a named-NPC crew order, and an observed world-state check. The game does not evaluate arbitrary code or make model/network calls in its runtime loop.

## What is playable

- A ten-lesson learn-to-code ladder spanning reading, modifying, debugging, and authoring bounded agent programs.
- A live compiler trace with tutor guidance, parse/validation feedback, order lifecycle state, and honest pass/fail receipts from the resulting farm state.
- A first reactive-programming step: optional `on day_start` source arms one in-memory run against the currently selected tile, then fires it once after the next End Day advances the farm without pressing Send.
- Exact-source program saving plus local lesson and view-setting persistence in `user://agentville_progress.json`.
- An editable voxel farm with crops, brush, roads, structures, crafting, crew orders, demands, missions, Parley, local NPC memory, and deterministic day summaries.
- Three visible NPC farmhands with bounded pathfinding, grounded movement, work-order execution, local utility decisions, and personality-flavored reactions.
- Fixed-isometric camera controls: wheel or `WORLD` buttons to zoom; WASD/arrows, right/middle drag, or the `View` tool to pan; `WORLD -> Center` to reset.
- Five Skill Forge starter workflows: Tend Crops, Plant Seed, Clear Patch, Harvest Crops, and Build Fence.

The exact shipped Skill Script v1 grammar and sandbox contract live in [`godot/docs/skill_forge_prd.md`](godot/docs/skill_forge_prd.md). The full system map, controls, and smoke/capture registry live in [`godot/README.md`](godot/README.md).

## Run the game

Prerequisite: Godot 4.6.x. The commands below use the team's Godot 4.6.3 app as a fallback; set `GODOT` to another compatible executable when needed.

From the repository root:

```bash
export GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path "$PWD/godot"
```

That boots the configured main scene, `godot/scenes/Main.tscn`. No npm install, API key, account, or backend is required for the Godot game.

Optional licensed MEGAVOX GLBs are local-only. When they are absent, the game silently uses its procedural voxel fallbacks.

## Build for the browser

AgentVille has a static Godot Web export path for browser playtests. It keeps the desktop renderer unchanged, selects Godot's Compatibility renderer only on Web, and deliberately excludes the local licensed MEGAVOX folder.

After installing the matching Godot 4.6.3 export templates:

```bash
export GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"
GODOT="$GODOT" ./godot/tools/export_web.sh
python3 -m http.server 8060 --directory godot/build/web
```

Open `http://127.0.0.1:8060/`. The generated `godot/build/web` directory is the Vercel-ready static artifact; do not point Vercel at the repository root, which still contains the dead React/Vite prototype. See [`godot/docs/web_export.md`](godot/docs/web_export.md) for browser acceptance checks and the deployment boundary.

## Validate the project

Run the headless project sanity check and the complete smoke registry:

```bash
export GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path "$PWD/godot" --quit
GODOT="$GODOT" ./godot/tools/run_all_smokes.sh
```

Run one focused smoke with:

```bash
"$GODOT" --headless --path "$PWD/godot" --script res://tools/smoke_<name>.gd
```

Visual capture scripts must run windowed, never with `--headless`:

```bash
"$GODOT" --path "$PWD/godot" --script res://tools/capture_<name>.gd
```

## Live architecture

- `godot/scenes/Main.tscn` and `godot/scripts/core/Game.gd` compose and orchestrate the game.
- `godot/scripts/ui/GameUI.gd` builds the command dock, crew/status rails, Field Log, lessons, saved programs, and Agent Workbench.
- `godot/scripts/systems/SkillScriptParser.gd` compiles Skill Script v1 source into data-only Skill Specs.
- `godot/scripts/systems/SkillSpecValidator.gd`, `SkillTriggerScheduler.gd`, `SkillForgeRunHarness.gd`, and `SkillCheckEvaluator.gd` enforce the allowlist, hold the single one-shot day-start arm, draft deterministic directives, and verify observed outcomes.
- `godot/scripts/systems/SkillLessonLibrary.gd`, `SkillTutorLibrary.gd`, and `PlayerProgress.gd` own the curriculum, deterministic teaching copy, and local progress.
- `godot/scripts/world/`, `godot/scripts/ai/`, and `godot/scripts/tools/` own the farm, NPC behavior, and pointer tools.
- `godot/tools/` contains the executable smoke, walkthrough, QA, and windowed capture harnesses.

## Current boundaries

Skill Script v1 intentionally supports one selected tile, one named agent, one farm action, an optional single guard, and one concrete success check per run. Runs are either manual or a single in-memory, one-shot `day_start` arm. It has no repeating schedules, other events, loops, branching beyond that guard, multi-tile or multi-agent programs, arbitrary scripting, runtime model calls, cloud sync, or automatic Web deployment pipeline yet.

## Legacy browser prototype

The remaining `src/`, `api/`, `dist/`, root `package.json`, and historical notes below belong to an earlier React/Three.js **Island Overseer** prototype. They are retained for reference but are not the live AgentVille product, launch path, architecture, or roadmap.

<details>
<summary>Historical Island Overseer documentation</summary>

### Island Overseer Edition

You inherited a pixel-perfect island farm. You hired opinionated AI agents to run it. They harvest autonomously, judge your decisions, and occasionally unionize to burn it all down. Each week you sell the harvest — profit makes you a hero, loss gets you roasted publicly.

**AgentVille isn't farming. It's being fired by your own employees.**

## What Is This?

AgentVille is a browser-based AI management sim where:

- You assign 3 opinionated agents to island zones (forest, plains, wetlands)
- Each day brings 2 crisis events that test your management decisions
- Agents develop morale based on your choices, zone fit, and neglect
- Weekly seasons end with a Sale Day where agents publicly roast or praise your performance
- 0.001% chance: agents unionize, burn the farm, and hit you with a shareable violation report

Think *Papers, Please* energy meets *Stardew Valley* aesthetics with AI personalities that have opinions.

## Features

- **3D Isometric Island** (Three.js voxel renderer, forked from Payday Kingdom)
- **Agent Personalities** (LLM-driven traits: work ethic, risk, loyalty, specialization)
- **Crisis Events** (20+ dynamic scenarios with visible tradeoffs)
- **Weekly Season Loop** (7 days of survival, Sale Day settlement, agent reviews)
- **Morale System** (affects agent efficiency, tone, and riot risk)
- **LLM Integration** (Claude Haiku/Sonnet for agent feedback and crisis narratives)
- **Riot Mechanic** (legendary failure state with shareable ACA violation report)
- **Screenshot & Share** (island snapshots, season reviews, agent quote cards, riot roasts)
- **Local-First** (no accounts, no backend, all state in localStorage)

## Tech Stack

- **React 18** + **Vite**
- **Three.js** for voxel-style 3D island rendering
- **Zustand** for game state (agents, resources, morale, season)
- **Tailwind CSS** for responsive UI (dark theme, terminal aesthetic)
- **Claude API** (Haiku for feedback, Sonnet for reviews/riots)
- **Canvas 2D** for shareable card generation
- **Tone.js** for procedural retro SFX
- **localStorage** for persistence

## Getting Started

### Prerequisites

- Node.js 18+
- npm
- (Optional) Claude API key for LLM features

### Install & Run

```bash
npm install
npm run dev
```

Open `http://localhost:5173`.

### Production Build

```bash
npm run build
npm run preview
```

## How to Play

1. Name your island and meet your 3 agents.
2. Assign agents to zones (forest, plains, wetlands).
3. Each day: read agent reports, make crisis decisions, watch morale shift.
4. By Day 6, optimize for the final profit push.
5. **Sale Day (Day 7):** Harvest sold → Agents review your management → Season resets.
6. If morale + decisions align poorly: **0.001% chance of RIOT** 🔥

### Quick Tips

- Keep agent morale above 50% or they get salty.
- Crisis decisions have tradeoffs — you can't please everyone.
- Ignoring crises tanks morale faster than wrong choices.
- Great seasons earn agent loyalty; repeated losses force you to hire new staff.

## Architecture

### Core UI / Scene

- `src/App.jsx` - app shell, season flow, desktop/mobile layout
- `src/components/scene/IslandScene.jsx` - Three.js scene, island rendering, agent positions
- `src/components/ui/AgentPanel.jsx` - agent cards, morale bars, zone assignments
- `src/components/ui/FieldLog.jsx` - scrollable agent commentary and status feed
- `src/components/ui/CrisisModal.jsx` - crisis event presentation and decision handling
- `src/components/ui/SaleDay.jsx` - animated harvest sequence, profit tally, agent reviews
- `src/components/onboarding/OnboardingFlow.jsx` - island naming, agent intro

### State Stores (Zustand)

- `src/store/agentStore.js` - agents[], morale{}, resources{}, season state, decisions log
- `src/store/crisisStore.js` - active crisis, templates, LLM enrichment

### Utilities

- `src/utils/voxelBuilder.js` - voxel primitives + terrain types (forest/plains/wetlands)
- `src/utils/agentBuilder.js` - agent appearance, personality trait visuals
- `src/utils/terrainBuilder.js` - terrain generation, biome coloring, crop/structure placement
- `src/utils/crisisEngine.js` - crisis template library, state-aware generation, LLM calls
- `src/utils/llmManager.js` - Claude API integration, rate limiting, template fallback
- `src/utils/screenshotCapture.js` - island snapshots, season result cards, roast reports
- `src/utils/soundManager.js` - procedural SFX for crisis outcomes, harvest, riot
- `src/utils/constants.js` - game config, morale thresholds, profit tiers, VOXEL_SCALE

## Roadmap

### MVP (Phase 1, 7 Days)

- [x] Fork PK codebase, strip budget logic
- [ ] Agent system + personality traits + morale
- [ ] Crisis engine + 20 hardcoded templates
- [ ] Season loop + Sale Day animated sequence
- [ ] Riot mechanic + shareable ACA report
- [ ] LLM integration (Haiku for feedback, Sonnet for reviews)
- [ ] Field Log + agent commentary
- [ ] 4 shareable asset types (island, review card, riot roast, quote cards)
- [ ] Onboarding + landing page
- [ ] Responsive layout + mobile touch controls

### Phase 2 (Future)

- Real-time passive harvesting + background workers
- Agent hiring/firing + roster evolution
- More terrain types (rocky, volcanic)
- Cross-game cosmetics with Payday Kingdom
- Shared engine extraction (`@skyframe/voxel-engine`)
- Backend + accounts + leaderboards
- Mobile app version

## Privacy

**No account required. No backend required.**

All gameplay data is stored locally in your browser using `localStorage`. Screenshots are generated client-side.

LLM calls (Claude API) are opt-in and configurable. If no API key is set, the game plays beautifully with template-based agent feedback.

## Known Limitations

- MVP uses manual day advance (button click = next day). Real-time passive generation comes in Phase 2.
- Terrain grid is currently placeholder. Terrain type rendering and crop placement are Day 2-3 work.
- LLM features gracefully degrade to templates if API unavailable or rate-limited.

## Built With

- Forked from **Payday Kingdom** (same voxel engine, visual language, sharing pipeline)
- Built by **Dan (Beefy Dan)** and **Bernie** with **Codex** (GPT-5.3-codex)
- Powered by React, Three.js, Zustand, Claude API, and the sweet schadenfreude of AI feedback

---

**Watch your agents judge you. Every week. Without mercy.**

Deployed at: `https://agentville.app` (coming soon)

</details>

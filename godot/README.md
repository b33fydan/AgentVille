# AgentVille Voxel Farm Prototype

Small Godot 4 vertical slice for a cozy isometric voxel farm builder.

## Play

- Open `project.godot` in Godot 4.
- Run `scenes/Main.tscn`.
- Use the left toolbar to till, plant, harvest, erase, place, or pan.
- Use the bottom tray to pick terrain, crops, dirt roads, fences, signs, flowers, the well, silo, or barn.
- Palette selections attach a small item ghost to the cursor.
- Hovering a selected palette item over the farm shows a hologram footprint before placement.
- The Tools tab includes Pickaxe for breaking rocks/structures/roads and Sickle for cutting brush or harvesting ready crops.
- Use the Crops and Nature tabs to add corn, wheat, tall grass, and flowers.
- Click farm tiles to apply the active tool.
- Press `End Day` to grow planted crops by one stage.
- Harvest full corn or wheat to earn coins.
- The visible NPC crew now walks to small jobs: harvesting ready crops, clearing brush, and inspecting farm pieces.
- Player and NPC work now feeds a tiny stash: brush gives Fiber, harvests give Grain, and rock breaking gives Stone.
- The right panel has a first crafting recipe: Fence Kit costs 2 Fiber and 1 Grain.
- Placing fences now consumes Fence Kits.
- The right panel's crew-order controls let the player mark a tile for Fence, Clear, or Harvest work.
- Marked crew jobs show small in-world order pins until the job is complete.
- Completed, waiting, or blocked crew orders can be cleared from the compact order list.
- Marked fence orders can use an existing kit, craft one from stash resources, or gather missing Fiber/Grain first.
- Pan with right/middle mouse drag, the Pan tool, or WASD/arrow keys.
- Zoom with the mouse wheel.

## Structure

- `scripts/world/GridManager.gd` owns the farm grid and day growth.
- `scripts/world/Tile.gd` owns each tile's visual state and contents.
- `scripts/world/Crop.gd` owns crop growth stages.
- Vegetation has subtle procedural wind sway for crops and tall grass.
- `scripts/tools/PlacementTool.gd` owns pointer interaction and tool actions.
- `scripts/tools/PlacementPreview.gd` owns selected-item holograms for tile hover previews.
- `scripts/audio/SoundManager.gd` owns named sound stamps and temporary placeholder tones.
- `scripts/ui/BuildPalette.gd` owns the bottom item tray.
- `scripts/ui/GameUI.gd` owns the editor-style HUD panels, crew panel, stash/crafting controls, and compact Field Log.
- `scripts/camera/CameraController.gd` owns the fixed isometric camera.
- `scripts/ai/GameEventLog.gd` records structured player/agent events for future observer summaries.
- `scripts/ai/AgentManager.gd` spawns the current NPC crew: Bert, Marigold, and Chuck.
- `scripts/ai/AgentActor.gd` owns each visible NPC, its state, memory, movement, reactions, and small world actions.
- `scripts/ai/UtilityAgentDecisionModel.gd` is the deterministic decision layer that an LSTM can later replace or assist.
- `tools/smoke_receipts.gd` exercises player-action receipts, agent reactions, and day summaries.
- `tools/smoke_agents.gd` exercises NPC harvesting, coin updates, and brush clearing.
- `tools/smoke_palette_tools.gd` exercises rock placement, pickaxe breaking, and sickle cutting.
- `tools/smoke_crafting.gd` exercises resource spending and Fence Kit crafting.
- `tools/smoke_ui_field_targeting.gd` exercises selecting a right-panel crew-order button and then clicking the farm field.
- `tools/smoke_work_orders.gd` exercises blocked fence placement, marked fence orders, order pins, clearing/dropping order rows, gather-craft-build support, clear orders, and harvest orders.
- `tools/capture_crafting.gd` captures `artifacts/screenshots/agentville-crafting.png`.
- `tools/capture_work_order.gd` captures `artifacts/screenshots/agentville-work-order.png`.
- `tools/capture_npc_work.gd` captures `artifacts/screenshots/agentville-npc-work.png`.
- `tools/capture_placement_preview.gd` captures `artifacts/screenshots/agentville-placement-preview.png`.
- `tools/capture_receipts_screenshot.gd` captures `artifacts/screenshots/agentville-receipts.png`.

## AI Direction

The Godot prototype follows the observer-agent pattern from the architecture notes:

- NPCs act locally with deterministic utility decisions, schedules, and memory.
- Player actions are logged as structured receipts.
- Agents react to meaningful events with lightweight template lines and can perform simple local work.
- NPC world actions are recorded as receipts, including crop harvest value and brush clearing.
- Resource gains are stored locally in the Godot runtime as the seed of the crafting economy.
- Tile-authored work orders are the first bridge from crafted inventory back into NPC-driven world changes.
- The crew priority loop now chooses between building, crafting support, and gathering missing resources for active orders.
- End-day summaries turn action history into compact receipts the crew can judge.
- A future observer model can read day/week summaries from `GameEventLog.gd` and generate richer reviews without running live LLM calls every few seconds.

For now, LSTM/ML is intentionally out of the runtime loop. The current seam is the decision model: replace or wrap `UtilityAgentDecisionModel.gd` when the game has enough action history to justify learned intent prediction.

## Sound Stamps

Drop final `.ogg` files into `audio/sfx/` using these names whenever the sound direction is ready. Until then, `SoundManager.gd` plays quiet generated placeholder tones.

- `ui_click`: light panel/button tap.
- `tool_select`: slightly firmer toolbar selection.
- `till_soft`: earthy soil scrape.
- `plant_pop`: small seed/pop confirmation.
- `place_soft`: cozy object placement.
- `erase_puff`: soft remove/clear puff.
- `harvest_chime`: satisfying crop pickup.
- `coin_burst`: tiny reward sparkle after selling/harvest.
- `day_advance`: gentle morning/time transition.
- `error_soft`: warm, non-punishing blocked-action sound.

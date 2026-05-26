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
- The right panel has crafting recipes for Fence Kits, Seed Bundles, and Rush Kits.
- Placing fences now consumes Fence Kits.
- The right panel's crew-order controls let the player mark a tile for Fence, Clear, or Harvest work.
- Marked crew jobs show small in-world order pins until the job is complete.
- Completed, waiting, or blocked crew orders can be cleared from the compact order list.
- Marked fence orders can use an existing kit, craft one from stash resources, or gather missing Fiber/Grain first.
- NPCs now have a first local adversarial reaction layer: repeated failed player actions can trigger side-eye, annoyance, warmer face tint, shake, and sarcastic local dialogue.
- End-day summaries now include a local player vibe label such as chaotic, productive, careful, or neglectful.
- The crew panel's Parley button opens the first bounded grievance encounter with a patience meter and local menu responses.
- Repeated failed actions or chaotic day summaries can queue a crew grievance and pulse the Parley button.
- Resolved grievances can grant a small coin/resource bonus and a short crew focus boost; lost patience can arm a small next-order crew tax.
- Resolved Parley sessions now create compact crew crafting demands; crafting and delivering the requested supply, such as Bert's Fence Kit or Marigold's Seed Bundle, completes the contract and cools the NPC down.
- Delivering Bert's Fence Kit now activates Fence Hands, a short crew perk that places one practical fence on an open grass tile.
- Delivering Marigold's Seed Bundle now activates Spring Hands, a short crew perk that plants wheat on a prepared tilled tile or nudges a crop one growth stage.
- Delivering Chuck's Rush Kit now activates Hustle Hands, a short crew perk that clears one rock, tall grass, or flower patch.
- Crew demands now vary between delivery and farm-work contracts, age across days, raise NPC pressure when ignored, and award small NPC-specific perks when completed.
- Farm-work crew demands now pick real target tiles, show compact coordinates in the demand row, place distinct in-world demand markers, and only complete from work on the requested tile.
- Aged targeted crew demands now let the NPC draft a linked work order for the same tile, so the player can send the crew to resolve the original social contract.
- Ignored NPC-authored orders now escalate the next morning, adding author pressure and auto-sending the crew when someone is free.
- Escalated NPC-authored orders now attach small bargain incentives, surface the resource offer in both demand and order rows, and pay it once the order is completed.
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
- `scripts/ai/AgentReactionModel.gd` scores player receipts into local NPC mood, irritation, and expression changes.
- `scripts/ai/AgentDialogueLibrary.gd` stores the first no-API sarcastic reaction lines.
- `scripts/ai/PlayerVibeScorer.gd` classifies day summaries into local player vibe labels for sharper crew verdicts.
- `scripts/ai/AdversarialSessionManager.gd` runs bounded no-API NPC grievance sessions with patience, turns, claims, verdicts, and rewards or penalties.
- `scripts/ai/UtilityAgentDecisionModel.gd` is the deterministic decision layer that an LSTM can later replace or assist.
- `tools/smoke_receipts.gd` exercises player-action receipts, agent reactions, and day summaries.
- `tools/smoke_agents.gd` exercises NPC harvesting, coin updates, and brush clearing.
- `tools/smoke_adversarial_reactions.gd` exercises local NPC irritation, sarcastic reactions, and crew UI expression state.
- `tools/smoke_adversarial_session.gd` exercises bounded NPC grievance sessions, scene UI wiring, result receipts, and rewards.
- `tools/smoke_crafting_demands.gd` exercises Parley-created crafting demands, player delivery, demand receipts, and NPC cooldown.
- `tools/smoke_npc_supply_recipes.gd` exercises agent-specific supply demands, the Seed Bundle recipe, delivery consumption, UI registration, and receipts.
- `tools/smoke_fence_hands_perk.gd` exercises Bert's Fence Kit payoff, crew status display, Fence Hands placement, and farm-perk receipts.
- `tools/smoke_spring_hands_perk.gd` exercises Marigold's Seed Bundle payoff, crew status display, Spring Hands planting, and farm-perk receipts.
- `tools/smoke_hustle_hands_perk.gd` exercises Chuck's Rush Kit payoff, Stone/Fiber crafting, Hustle Hands clearing, and farm-perk receipts.
- `tools/smoke_demand_reward_preview.gd` exercises compact demand-row payoff previews for Fence Hands, Spring Hands, and Hustle Hands before delivery.
- `tools/smoke_demand_craftable_status.gd` exercises crew demand rows switching from missing supply to `Can craft` when recipe ingredients are available.
- `tools/smoke_demand_variety.gd` exercises demand type selection, demand aging, pressure receipts, action completion, and NPC-specific perks.
- `tools/smoke_demand_targeting.gd` exercises targeted demand tile selection, UI coordinates, demand markers, target focus, and tile-specific completion.
- `tools/smoke_npc_authored_work_orders.gd` exercises aged targeted demands becoming NPC-authored work orders that complete the source demand through crew action.
- `tools/smoke_npc_order_escalation.gd` exercises second-day escalation for ignored NPC-authored orders, including escalation receipts, author pressure, auto-send, and source-demand completion.
- `tools/smoke_npc_escalation_bargains.gd` exercises escalated NPC-authored order incentives, compact demand-row bargain text, payout, and receipt logging.
- `tools/smoke_order_bargain_row.gd` exercises compact `Bonus` and `Claimed` bargain states in the crew-order row.
- `tools/smoke_vibe_scorer.gd` exercises local vibe scoring, formatted day summaries, and NPC vibe verdicts.
- `tools/smoke_palette_tools.gd` exercises rock placement, pickaxe breaking, and sickle cutting.
- `tools/smoke_crafting.gd` exercises resource spending and Fence Kit crafting.
- `tools/smoke_ui_field_targeting.gd` exercises selecting a right-panel crew-order button and then clicking the farm field.
- `tools/smoke_work_orders.gd` exercises blocked fence placement, marked fence orders, order pins, clearing/dropping order rows, gather-craft-build support, clear orders, and harvest orders.
- `tools/capture_crafting.gd` captures `artifacts/screenshots/agentville-crafting.png`.
- `tools/capture_crafting_demand.gd` captures `artifacts/screenshots/agentville-crafting-demand.png`.
- `tools/capture_demand_variety.gd` captures `artifacts/screenshots/agentville-demand-variety.png`.
- `tools/capture_demand_targeting.gd` captures `artifacts/screenshots/agentville-demand-targeting.png`.
- `tools/capture_npc_authored_work_order.gd` captures `artifacts/screenshots/agentville-npc-authored-work-order.png`.
- `tools/capture_npc_order_escalation.gd` captures `artifacts/screenshots/agentville-npc-order-escalation.png`.
- `tools/capture_npc_escalation_bargain.gd` captures `artifacts/screenshots/agentville-npc-escalation-bargain.png`.
- `tools/capture_npc_supply_recipe.gd` captures `artifacts/screenshots/agentville-npc-supply-recipe.png`.
- `tools/capture_fence_hands_perk.gd` captures `artifacts/screenshots/agentville-fence-hands-perk.png`.
- `tools/capture_spring_hands_perk.gd` captures `artifacts/screenshots/agentville-spring-hands-perk.png`.
- `tools/capture_hustle_hands_perk.gd` captures `artifacts/screenshots/agentville-hustle-hands-perk.png`.
- `tools/capture_adversarial_reaction.gd` captures `artifacts/screenshots/agentville-adversarial-reaction.png`.
- `tools/capture_adversarial_session.gd` captures `artifacts/screenshots/agentville-adversarial-session.png`.
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
- The first adversarial NPC layer is local and deterministic: no runtime API calls or LSTM model are used for moment-to-moment reactions yet.
- The first bounded adversarial encounter harness is also local and menu-driven. It records session result receipts, but it does not call a live model.
- Encounter triggers and consequences are deterministic: repeated misses or chaotic summaries queue the grievance, while resolved/lost sessions feed compact rewards, boosts, irritation changes, and next-order tax receipts.
- Crafting demands are the first contract bridge from social friction back into production: a resolved grievance can request NPC-flavored supplies, and player crafting satisfies the demand without API calls.
- Bert's Fence Kit has a deterministic farm payoff too: Fence Hands briefly appears in the crew header, places one open-tile fence, and records `farm_perk` receipts.
- Marigold's Seed Bundle now has a deterministic farm payoff: Spring Hands briefly appears in the crew header, plants one prepared tilled tile or grows one crop, and records `farm_perk` receipts.
- Chuck's Rush Kit gives Stone a deterministic use: Hustle Hands briefly appears in the crew header, clears one obstacle, and records `farm_perk` receipts.
- Demand variety is still deterministic and local: Parley context chooses delivery, brush-clearing, crop-harvest, or fence-building contracts; aging open contracts adds pressure, while completion applies small personality-flavored perks.
- Targeted demand selection is deterministic and local too: action demands bind to live farm tiles and become visible world intent markers before later NPC-authored contracts get smarter.
- NPC-authored work orders are the next local bridge: an ignored targeted demand can draft a crew order with source-demand metadata, and the existing agent action receipt completes both records.
- Ignored authored orders now have deterministic escalation: a second missed morning records escalation metadata, sharpens the author irritation, and uses the existing crew queue to push the work forward.
- Escalation bargains are deterministic too: the author attaches a tiny resource incentive to the linked order, the UI exposes the offer in demand and order rows, and order completion records and pays the incentive once.
- The first vibe scorer is also local and threshold-based. It creates structured labels that a future observer model or LSTM/classifier can consume later.
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

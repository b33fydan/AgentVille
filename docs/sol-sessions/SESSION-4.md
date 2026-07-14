# Session 4 — Wake an agent on day start

## Mission
Teach the first reactive agent program through one visible, deterministic event: a graduate can add `on day_start` to a Skill Script, compile it into a one-shot arm, end the day, and watch the named farmhand execute the captured single-tile action without pressing Send.

## Player contract
```text
agent "Marigold" {
  on day_start
  observe selected_tile
  when tile.empty {
    use plant_seed(selected_tile)
  }
  verify crop_state
  receipt "Morning Plant run"
}
```

- Omitting `on day_start` preserves the existing manual Compile → Send flow exactly.
- Compile validates and arms one program in memory. It captures the currently selected tile, creates no work order, performs no guard check, and mutates no world state.
- The Workbench shows `ARMED ONCE · DAY START` plus an explicit `DISARM` control. Compiling another program replaces the arm; loading saved source never arms it automatically.
- End Day advances and grows the world first, then fires the arm once. The runtime checks the authored guard against the new-day state and auto-dispatches the resulting order through the existing crew path.
- Pass, block, runtime-busy skip, or explicit disarm consumes the arm. The source remains available so the player can correct or re-arm it deliberately.
- The captured target is immutable. Moving selection after Compile cannot retarget the armed program.

## Deliverables
1. Extend Skill Script with one optional `on day_start` statement and source-linked diagnostics. Keep `manual` as the implicit default and reject every other event through the validator allowlist.
2. Add a small `RefCounted` trigger scheduler that owns at most one in-memory, one-shot arm and exposes deterministic arm, replace, disarm, and consume behavior.
3. Generalize the Forge harness just enough to start a run for its declared trigger while preserving `start_manual_run()` compatibility and rejecting trigger mismatches.
4. Wire Workbench arm/disarm/fired states into `Game.gd` and `GameUI.gd`. Trigger firing must never cancel or replace an existing pending Forge run.
5. Auto-dispatch a fired run through the existing work-order and `AgentActor` route. Arrival guards and world checks remain authoritative; automatic action failure is terminal for that activation and cannot stall an order.
6. Record source-linked teaching trace and Field Log evidence for armed, fired, passed, blocked, skipped, replaced, and disarmed states. Automatic runs do not complete the ten manual lessons.
7. Add focused smokes, a 1600×900 windowed capture, and register every new tool in `godot/README.md`.

## Acceptance
- A canonical manual program behaves exactly as it did before this session.
- A valid `on day_start` program creates no order and no mutation at Compile, shows its captured target, and fires exactly once on the next End Day without Send.
- Selection movement after arming does not change the execution target.
- A busy Forge runtime is not replaced; the trigger emits one visible skipped receipt and is consumed.
- Invalid-at-fire guards and failed crew actions terminate honestly with a correlated receipt and no stuck pending run.
- Disarm and replacement are explicit, deterministic, and covered by smoke tests.
- Parser, validator, harness, Workbench, lesson, persistence, day-advance, and responsive-layout regressions remain green.
- `tools/capture_day_start_trigger.gd` writes `res://artifacts/screenshots/agentville-day-start-trigger.png` at 1600×900 from the real game UI.
- `tools/run_all_smokes.sh` passes in full after the focused packet.

## Out of scope
Repeating schedules, persisted arms, any event besides `day_start`, Lesson 11, multi-tile or multi-agent programs, loops, arbitrary timers, player-script evaluation, network calls, and changes to the legacy web app.

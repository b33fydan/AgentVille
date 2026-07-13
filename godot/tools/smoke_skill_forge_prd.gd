extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_skill_forge_prd_has_required_sections()
	if not _failed:
		quit()


func _test_skill_forge_prd_has_required_sections() -> void:
	var text := FileAccess.get_file_as_string("res://docs/skill_forge_prd.md")
	if text == "":
		_fail("Skill Forge PRD was missing or empty.")
		return

	var required_sections := [
		"# Skill Forge PRD",
		"## Product Summary",
		"## Skill Script v1 Grammar",
		"## Compiled Skill Spec v1",
		"## Existing System Mapping",
		"## Safety Model",
		"## Shipped Acceptance Contract",
		"## Current Non-Goals",
		"## Shipped Implementation Map",
		"## Foundation Decisions Now Shipped"
	]
	for section in required_sections:
		if not text.contains(section):
			_fail("Skill Forge PRD missing required section: %s" % section)
			return

	var shipped_truth := [
		"Status: implemented and playable",
		"agent \"Marigold\"",
		"observe selected_tile",
		"when crop.ready",
		"use harvest_crop(selected_tile)",
		"verify inventory_delta",
		"receipt \"Harvest Crops run\"",
		"`Bert`, `Marigold`, `Chuck`",
		"`clear_brush`, `harvest_crop`, `plant_seed`, `tend_crop`, `build_fence`",
		"`always`, `inspect.has_brush`, `crop.needs_tending`, `crop.ready`, `tile.empty`",
		"`tile_state`, `crop_state`, `inventory_delta`",
		"Each program must contain exactly one `observe`, one `use`, one `verify`, and one `receipt`.",
		"The single `use` may appear directly, which implies the `always` guard, or inside one `when` block.",
		"Comments, variables, arithmetic, user-defined functions, loops, and nested control flow are not part of v1.",
		"Identifiers outside these semantic allowlists can tokenize and parse so the validator can explain the problem; they cannot run.",
		"one-based line and column, offending token, plain-language cause, and one fix suggestion",
		"not a rejection of code authoring",
		"No arbitrary scripting or GDScript execution.",
		"No network access.",
		"No file writes from player-authored specs."
	]
	for truth in shipped_truth:
		if not text.contains(truth):
			_fail("Skill Forge PRD missing shipped truth: %s" % truth)
			return

	var stale_claims := [
		"Status: pre-implementation vision",
		"## Skill Spec v0",
		"- General code editing.",
		"## Recommended First Implementation Slice",
		"Before coding the Forge, choose:"
	]
	for stale_claim in stale_claims:
		if text.contains(stale_claim):
			_fail("Skill Forge PRD retained stale pre-implementation claim: %s" % stale_claim)
			return

	if not text.contains("SkillSpecValidator.gd") or not text.contains("SkillScriptParser.gd"):
		_fail("Skill Forge PRD did not name the shipped validator and parser foundation.")
		return


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)

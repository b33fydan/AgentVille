extends Node

const GameEventLogScript: Script = preload("res://scripts/ai/GameEventLog.gd")
const AgentManagerScript: Script = preload("res://scripts/ai/AgentManager.gd")
const AdversarialSessionManagerScript: Script = preload("res://scripts/ai/AdversarialSessionManager.gd")
const SkillCheckEvaluatorScript: Script = preload("res://scripts/systems/SkillCheckEvaluator.gd")
const SkillForgeRunHarnessScript: Script = preload("res://scripts/systems/SkillForgeRunHarness.gd")
const SkillForgeTemplateLibraryScript: Script = preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")
const SkillLessonLibraryScript: Script = preload("res://scripts/systems/SkillLessonLibrary.gd")
const SkillScriptParserScript: Script = preload("res://scripts/systems/SkillScriptParser.gd")
const SkillSpecValidatorScript: Script = preload("res://scripts/systems/SkillSpecValidator.gd")
const SkillTriggerSchedulerScript: Script = preload("res://scripts/systems/SkillTriggerScheduler.gd")
const SkillTutorLibraryScript: Script = preload("res://scripts/systems/SkillTutorLibrary.gd")
const PlayerProgressScript: Script = preload("res://scripts/systems/PlayerProgress.gd")
const PRODUCT_WINDOW_TITLE := "AgentVille — Learn-to-Code Voxel Farm"
const RECIPES: Dictionary = {
	"fence_kit": {
		"label": "Fence Kit",
		"cost": {
			"fiber": 2,
			"grain": 1
		}
	},
	"seed_bundle": {
		"label": "Seed Bundle",
		"cost": {
			"grain": 2
		}
	},
	"rush_kit": {
		"label": "Rush Kit",
		"cost": {
			"fiber": 1,
			"stone": 1
		}
	}
}
const WORK_ORDER_ACTIONS: Dictionary = {
	"build_fence": {
		"label": "Fence",
		"verb": "Build fence",
		"agent_action": "build_fence_order",
		"preview_item": "fence",
		"required_item": "fence_kit"
	},
	"clear_brush": {
		"label": "Clear",
		"verb": "Clear brush",
		"agent_action": "clear_brush",
		"preview_item": "sickle",
		"required_item": ""
	},
	"harvest_crop": {
		"label": "Harvest",
		"verb": "Harvest crop",
		"agent_action": "harvest_crop",
		"preview_item": "sickle",
		"required_item": ""
	},
	"plant_seed": {
		"label": "Plant",
		"verb": "Plant seed",
		"agent_action": "plant_seed",
		"preview_item": "wheat_seed",
		"required_item": ""
	},
	"tend_crop": {
		"label": "Tend",
		"verb": "Tend crop",
		"agent_action": "tend_crop",
		"preview_item": "watering_can",
		"required_item": ""
	}
}
const SPRING_HANDS_SECONDS := 12.0
const FENCE_HANDS_SECONDS := 12.0
const HUSTLE_HANDS_SECONDS := 12.0

@export var progress_storage_path: String = ""

@onready var camera_controller = $CameraController
@onready var farm_world: Node3D = $FarmWorld
@onready var grid_manager = $FarmWorld/GridManager
@onready var placement_tool = $PlacementTool
@onready var sound_manager = $SoundManager
@onready var game_ui = $GameUI

var money: int = 42
var resources: Dictionary = {
	"fiber": 0,
	"grain": 0,
	"stone": 0
}
var crafted_items: Dictionary = {
	"fence_kit": 0,
	"seed_bundle": 0,
	"rush_kit": 0
}
var reserved_crafted_items: Dictionary = {
	"fence_kit": 0,
	"seed_bundle": 0,
	"rush_kit": 0
}
var crafting_demands: Dictionary = {}
var crafting_demand_ids: Array[String] = []
var work_orders: Dictionary = {}
var work_order_ids: Array[String] = []
var crew_missions: Dictionary = {}
var crew_mission_ids: Array[String] = []

var _environment: Environment
var _sun: DirectionalLight3D
var _event_log
var _agent_manager
var _adversarial_session
var _skill_forge_templates = SkillForgeTemplateLibraryScript.new()
var _skill_forge_run_harness = SkillForgeRunHarnessScript.new()
var _skill_check_evaluator = SkillCheckEvaluatorScript.new()
var _skill_script_parser = SkillScriptParserScript.new()
var _skill_trigger_scheduler = SkillTriggerSchedulerScript.new()
var _pending_skill_forge_run: Dictionary = {}
var _player_progress
var _skill_lesson_library = SkillLessonLibraryScript.new()
var _skill_tutor_library = SkillTutorLibraryScript.new()
var _last_valid_compiled_source: String = ""
var _last_valid_compiled_spec: Dictionary = {}
var _active_lesson_id: String = ""
var _lesson_failure_counts: Dictionary = {}
var _lesson_failure_keys: Dictionary = {}
var _farm_sandbox_unlocked: bool = true
var _post_ladder_goal_seeded: bool = false
var _crew_priority_timer: float = 0.0
var _next_work_order_number: int = 1
var _next_crafting_demand_number: int = 1
var _next_crew_mission_number: int = 1
var _queued_grievance_agent_id: String = ""
var _queued_grievance_context: Dictionary = {}
var _last_failure_grievance_day: int = 0
var _last_failure_grievance_count: int = 0
var _patience_tax_orders: int = 0
var _spring_hands_timer: float = 0.0
var _spring_hands_charges: int = 0
var _fence_hands_timer: float = 0.0
var _fence_hands_charges: int = 0
var _hustle_hands_timer: float = 0.0
var _hustle_hands_charges: int = 0


func _ready() -> void:
	get_window().title = PRODUCT_WINDOW_TITLE
	RenderingServer.set_default_clear_color(Color("#f6f3ec"))
	_setup_environment()
	_setup_ai_layer()
	_setup_player_progress()
	_connect_systems()
	camera_controller.center_on_farm()
	game_ui.set_day(grid_manager.day)
	game_ui.set_money(money)
	game_ui.set_skill_forge_templates(_skill_forge_templates.list_template_previews())
	_apply_player_progress(true)
	_refresh_inventory_and_orders()


func _process(delta: float) -> void:
	_update_spring_hands(delta)
	_update_fence_hands(delta)
	_update_hustle_hands(delta)
	_crew_priority_timer -= delta
	if _crew_priority_timer > 0.0:
		return
	_crew_priority_timer = 0.45
	_continue_resource_orders(true)


func _connect_systems() -> void:
	placement_tool.configure(grid_manager, camera_controller, game_ui)
	placement_tool.set_item_availability_checker(Callable(self, "_can_place_palette_item"))
	placement_tool.set_crew_order_target_checker(Callable(self, "_can_target_crew_order"))
	placement_tool.set_agent_occupancy_checker(Callable(_agent_manager, "is_grid_pos_occupied"))
	placement_tool.action_performed.connect(game_ui.show_message)
	placement_tool.harvest_collected.connect(_on_harvest_collected)
	placement_tool.sound_requested.connect(sound_manager.play_stamp)
	placement_tool.action_logged.connect(_on_player_action_logged)
	placement_tool.crew_order_targeted.connect(_on_crew_order_targeted)
	placement_tool.selected_tile_changed.connect(_on_selected_tile_changed)

	game_ui.tool_selected.connect(_on_tool_selected)
	game_ui.item_selected.connect(_on_palette_item_selected)
	game_ui.advance_day_requested.connect(_on_advance_day_requested)
	game_ui.grid_visibility_changed.connect(_on_grid_visibility_changed)
	game_ui.shadows_changed.connect(_on_shadows_changed)
	game_ui.ambient_occlusion_changed.connect(_on_ambient_occlusion_changed)
	game_ui.camera_zoom_requested.connect(camera_controller.adjust_zoom)
	game_ui.camera_recenter_requested.connect(camera_controller.center_on_farm)
	game_ui.sound_requested.connect(sound_manager.play_stamp)
	game_ui.craft_requested.connect(_on_craft_requested)
	game_ui.work_order_requested.connect(_on_work_order_requested)
	game_ui.work_order_cancel_requested.connect(_on_work_order_cancel_requested)
	game_ui.work_order_tool_selected.connect(_on_work_order_tool_selected)
	game_ui.adversarial_encounter_requested.connect(_on_adversarial_encounter_requested)
	game_ui.adversarial_response_selected.connect(_on_adversarial_response_selected)
	game_ui.crafting_demand_target_requested.connect(_on_crafting_demand_target_requested)
	game_ui.crafting_demand_requested.connect(_on_crafting_demand_requested)
	game_ui.skill_forge_run_requested.connect(_on_skill_forge_run_requested)
	game_ui.skill_forge_review_requested.connect(_on_skill_forge_review_requested)
	game_ui.skill_forge_revision_requested.connect(_on_skill_forge_revision_requested)
	game_ui.workbench_compile_requested.connect(_on_workbench_compile_requested)
	game_ui.workbench_trigger_disarm_requested.connect(_on_workbench_trigger_disarm_requested)
	game_ui.lesson_selected.connect(_on_lesson_selected)
	game_ui.program_save_requested.connect(_on_program_save_requested)
	game_ui.program_load_requested.connect(_on_program_load_requested)

	if _agent_manager:
		_agent_manager.agent_comment.connect(game_ui.show_message)
		_agent_manager.agent_comment.connect(game_ui.add_field_log)
		_agent_manager.agent_world_action.connect(_on_agent_world_action)
		_agent_manager.crew_updated.connect(game_ui.set_agent_snapshots)
		game_ui.set_agent_snapshots(_agent_manager.call("get_agent_snapshots"))


func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("#f6f3ec")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#eee6d9")
	_environment.ambient_light_energy = 0.48
	_environment.ssao_enabled = true
	_environment.ssao_radius = 0.75
	_environment.ssao_intensity = 1.52
	_environment.ssao_power = 1.35
	_environment.ssao_detail = 0.68
	_environment.ssao_light_affect = 0.10
	_apply_reference_contrast_atmosphere()
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "WarmSun"
	_sun.light_color = Color("#fff5e8")
	_sun.light_energy = 1.20
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.55
	_sun.shadow_opacity = 0.80
	_sun.position = Vector3(-4.0, 10.5, -4.5)
	add_child(_sun)
	_sun.look_at(Vector3.ZERO, Vector3.UP)

	var fill := OmniLight3D.new()
	fill.name = "SoftFill"
	fill.light_color = Color("#dfe9f2")
	fill.light_energy = 0.08
	fill.omni_range = 12.0
	fill.position = Vector3(3.0, 5.0, 4.0)
	add_child(fill)

func _setup_ai_layer() -> void:
	_event_log = Node.new()
	_event_log.set_script(GameEventLogScript)
	_event_log.name = "GameEventLog"
	add_child(_event_log)

	_adversarial_session = AdversarialSessionManagerScript.new()

	_agent_manager = Node3D.new()
	_agent_manager.set_script(AgentManagerScript)
	_agent_manager.name = "AgentManager"
	_agent_manager.call("configure", grid_manager, _event_log)
	farm_world.add_child(_agent_manager)


func _setup_player_progress() -> void:
	var storage_path := progress_storage_path.strip_edges()
	var disk_enabled := storage_path != "" or DisplayServer.get_name() != "headless"
	if storage_path == "":
		storage_path = PlayerProgressScript.DEFAULT_PATH
	_player_progress = PlayerProgressScript.new(storage_path, disk_enabled, _skill_lesson_library.first_lesson_id())
	_player_progress.load()
	_normalize_current_lesson()


func _normalize_current_lesson() -> void:
	if _player_progress == null:
		return
	var lesson_ids: Array = _skill_lesson_library.get_lesson_ids()
	_player_progress.normalize_lesson_sequence(lesson_ids)
	_active_lesson_id = str(_player_progress.get_current_lesson())


func _apply_player_progress(load_lesson_source: bool = false) -> void:
	if _player_progress == null:
		return
	var completed: Array = _player_progress.get_completed_lessons()
	var current: String = str(_player_progress.get_current_lesson())
	game_ui.set_lesson_ladder(_skill_lesson_library.list_lessons(completed), current, completed)
	var displayed_lesson_id: String = _active_lesson_id if _active_lesson_id != "" else current
	var lesson: Dictionary = _skill_lesson_library.get_lesson(displayed_lesson_id)
	game_ui.set_current_lesson_goal(lesson)
	game_ui.set_saved_programs(_player_progress.list_programs())

	var view_toggles: Dictionary = _player_progress.get_view_toggles()
	game_ui.set_view_toggle_states(view_toggles)
	grid_manager.set_grid_visible(bool(view_toggles.get("grid", false)))
	_set_shadows_enabled(bool(view_toggles.get("shadows", true)), false)
	_set_ambient_occlusion_enabled(bool(view_toggles.get("ambient_occlusion", true)), false)

	if load_lesson_source and not lesson.is_empty():
		game_ui.set_workbench_source(
			str(lesson.get("starting_editor_text", "")),
			"lesson_%02d.agent" % int(lesson.get("order", 0))
		)
		var first_hint := str(lesson.get("tutor", {}).get("first_hint", "")).strip_edges()
		game_ui.set_workbench_trace({
			"stage": "LESSON READY",
			"status": "READY",
			"runtime_status": "READY  ·  LOCAL COMPILER",
			"tutor_lines": [first_hint] if first_hint != "" else [],
			"lines": ["Select a compatible farm tile, then press COMPILE."]
		})
	_apply_onboarding_state(not load_lesson_source)
	_ensure_post_ladder_goal_loop()


func _apply_onboarding_state(announce_unlock: bool = false) -> void:
	var gate_enabled := _player_progress != null and bool(_player_progress.call("is_disk_enabled"))
	var first_lesson_id: String = str(_skill_lesson_library.first_lesson_id())
	var was_unlocked := _farm_sandbox_unlocked
	_farm_sandbox_unlocked = not gate_enabled or bool(_player_progress.call("is_lesson_completed", first_lesson_id))
	if placement_tool != null and placement_tool.has_method("set_farm_sandbox_unlocked"):
		placement_tool.call("set_farm_sandbox_unlocked", _farm_sandbox_unlocked)
	var current_lesson: Dictionary = _skill_lesson_library.get_lesson(_active_lesson_id)
	game_ui.set_onboarding_state(_farm_sandbox_unlocked, current_lesson)

	if not _farm_sandbox_unlocked:
		placement_tool.set_tool("select")
		if not bool(placement_tool.call("has_selected_tile")):
			var starter_tile = _first_onboarding_target()
			if starter_tile != null:
				placement_tool.call("select_tile_without_action", starter_tile)
	elif announce_unlock and not was_unlocked:
		game_ui.add_field_log("Farm sandbox unlocked: FARM tools, free-play recipes, and End Day are ready.")
		game_ui.show_message("FARM SANDBOX UNLOCKED  ·  Keep learning or explore the farm.")
		sound_manager.play_stamp("success_chime")


func _first_onboarding_target():
	if grid_manager == null:
		return null
	for tile in grid_manager.tiles.values():
		if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _sandbox_action_blocked(action_label: String) -> bool:
	if _farm_sandbox_unlocked:
		return false
	game_ui.show_message("Complete Lesson 1 before %s." % action_label)
	sound_manager.play_stamp("error_soft")
	return true


func _ensure_post_ladder_goal_loop() -> bool:
	if _post_ladder_goal_seeded or _player_progress == null:
		return _post_ladder_goal_seeded
	var lesson_ids: Array = _skill_lesson_library.get_lesson_ids()
	var completed: Array = _player_progress.get_completed_lessons()
	if not str(_player_progress.get_current_lesson()).is_empty() or completed.size() != lesson_ids.size():
		return false

	# Progress persists while the farm world resets, so returning graduates need a
	# small deterministic stake that makes the first existing-system mission viable.
	resources["fiber"] = maxi(int(resources.get("fiber", 0)), 2)
	resources["grain"] = maxi(int(resources.get("grain", 0)), 1)
	_refresh_inventory_and_orders()
	var mission_id := _create_crew_mission({
		"label": "Graduate Field Loop",
		"steps": [
			{
				"kind": "deliver_item",
				"required_item": "fence_kit",
				"amount": 1,
				"label": "Build Bert a Fence Kit"
			},
			{
				"kind": "clear_brush",
				"required_action": "clear_brush",
				"amount": 1,
				"label": "Run a Brush Program"
			}
		],
		"completion_resource_delta": {"grain": 1}
	}, {
		"agent_id": "bert",
		"agent_name": "Bert"
	})
	if mission_id == "":
		return false
	_post_ladder_goal_seeded = true
	game_ui.add_field_log("Graduate kit ready: +2 Fiber, +1 Grain. Build Bert's Fence Kit, then run a brush program.")
	game_ui.show_message("FREE PLAY GOAL  ·  Complete Bert's Graduate Field Loop.")
	return true


func _pipeline_tutor_line(state_key: String, detail_key: String = "", context: Dictionary = {}) -> String:
	if _skill_tutor_library == null:
		return ""
	return str(_skill_tutor_library.line_for(state_key, detail_key, context)).strip_edges()


func _lesson_failure_tutor(
	lesson_id: String,
	failure_key: String,
	state_key: String,
	detail_key: String = "",
	context: Dictionary = {}
) -> Array[String]:
	var lines: Array[String] = []
	var pipeline_line := _pipeline_tutor_line(state_key, detail_key, context)
	if pipeline_line != "":
		lines.append(pipeline_line)
	var lesson: Dictionary = _skill_lesson_library.get_lesson(lesson_id)
	if lesson.is_empty():
		return lines

	var failures: Array = _lesson_failure_keys.get(lesson_id, [])
	if failure_key != "" and not failures.has(failure_key):
		failures.append(failure_key)
	_lesson_failure_keys[lesson_id] = failures
	var attempt := int(_lesson_failure_counts.get(lesson_id, 0)) + 1
	_lesson_failure_counts[lesson_id] = attempt
	for hint_line in _skill_tutor_library.lesson_hint_lines(lesson, attempt, false):
		var clean_line := str(hint_line).strip_edges()
		if clean_line != "" and not lines.has(clean_line):
			lines.append(clean_line)
	return lines


func _lesson_evidence(pending: Dictionary, result: Dictionary, verdict: Dictionary = {}) -> Dictionary:
	var run: Dictionary = result.get("run", {}) if typeof(result.get("run", {})) == TYPE_DICTIONARY else {}
	var lesson_id := str(pending.get("lesson_id", ""))
	return {
		"lesson_id": lesson_id,
		"player_initiated": str(pending.get("origin", "")) == "workbench",
		"origin": str(pending.get("origin", "")),
		"source_text": str(pending.get("source_text", "")),
		"spec": pending.get("compiled_spec", {}).duplicate(true),
		"status": str(result.get("status", run.get("status", ""))),
		"run": run.duplicate(true),
		"action": _skill_forge_primary_action(pending.get("compiled_spec", {})),
		"agent_id": str(pending.get("agent_id", run.get("agent_id", ""))),
		"guard_condition": str(pending.get("guard_condition", "")),
		"check_type": str(verdict.get("check_type", run.get("success_check_type", ""))),
		"check_passed": bool(verdict.get("passed", false)),
		"check_verdict": verdict.duplicate(true),
		"receipt_label": str(run.get("receipt_label", "")),
		"target_tile": pending.get("target_tile", Vector2i(-1, -1)),
		"target_source": str(pending.get("target_source", "")),
		"failure_keys": (_lesson_failure_keys.get(lesson_id, []) as Array).duplicate()
	}


func _evaluate_lesson_terminal(pending: Dictionary, result: Dictionary, verdict: Dictionary = {}) -> Array[String]:
	var lesson_id := str(pending.get("lesson_id", ""))
	var check_type := str(verdict.get("check_type", result.get("run", {}).get("success_check_type", "")))
	if lesson_id == "" or str(pending.get("origin", "")) != "workbench":
		return [_pipeline_tutor_line("check", check_type, {"passed": bool(verdict.get("passed", false))})]

	var lesson: Dictionary = _skill_lesson_library.get_lesson(lesson_id)
	var evidence := _lesson_evidence(pending, result, verdict)
	var evaluation: Dictionary = _skill_lesson_library.evaluate_completion(lesson_id, evidence)
	if bool(evaluation.get("complete", false)):
		var tutor_lines: Array[String] = []
		var check_line := _pipeline_tutor_line("check", check_type, {"passed": true})
		if check_line != "":
			tutor_lines.append(check_line)
		for hint_line in _skill_tutor_library.lesson_hint_lines(lesson, 0, true):
			var clean_line := str(hint_line).strip_edges()
			if clean_line != "" and not tutor_lines.has(clean_line):
				tutor_lines.append(clean_line)

		if not _player_progress.is_lesson_completed(lesson_id):
			var next_lesson_id: String = _skill_lesson_library.next_lesson_id(lesson_id)
			_player_progress.complete_lesson(lesson_id, next_lesson_id)
			if next_lesson_id == "":
				_player_progress.set_current_lesson("")
			_lesson_failure_counts.erase(lesson_id)
			_lesson_failure_keys.erase(lesson_id)
			_active_lesson_id = next_lesson_id
			var receipt := "Lesson complete: %02d · %s. Concept: %s." % [
				int(lesson.get("order", 0)),
				str(lesson.get("title", "Lesson")),
				str(lesson.get("concept", "agent workflow"))
			]
			game_ui.add_field_log(receipt)
			game_ui.show_message(receipt)
			_apply_player_progress(false)
			game_ui.pulse_lesson_complete()
			sound_manager.play_stamp("lesson_complete")
		return tutor_lines

	var failure_key := "check.%s.failed" % (check_type if check_type != "" else "lesson")
	return _lesson_failure_tutor(
		lesson_id,
		failure_key,
		"check",
		check_type,
		{"passed": bool(verdict.get("passed", false)), "mismatches": evaluation.get("mismatches", [])}
	)


func _apply_reference_contrast_atmosphere() -> void:
	_set_environment_property("tonemap_mode", 2)
	_set_environment_property("tonemap_exposure", 0.84)
	_set_environment_property("tonemap_white", 1.25)
	_set_environment_property("glow_enabled", true)
	_set_environment_property("glow_normalized", true)
	_set_environment_property("glow_intensity", 0.06)
	_set_environment_property("glow_strength", 0.14)
	_set_environment_property("glow_bloom", 0.03)
	_set_environment_property("glow_blend_mode", 1)
	_set_environment_property("glow_hdr_threshold", 1.05)
	_set_environment_property("glow_hdr_scale", 1.0)
	_set_environment_property("glow_hdr_luminance_cap", 3.0)
	_set_environment_property("adjustment_enabled", true)
	_set_environment_property("adjustment_brightness", 0.95)
	_set_environment_property("adjustment_contrast", 1.14)
	_set_environment_property("adjustment_saturation", 1.00)
	_set_environment_property("fog_enabled", false)


func _set_environment_property(property_name: StringName, value) -> void:
	for property in _environment.get_property_list():
		if property.name == property_name:
			_environment.set(property_name, value)
			return


func _on_tool_selected(tool_name: String) -> void:
	if tool_name not in ["select", "pan"] and _sandbox_action_blocked("using FARM tools"):
		game_ui.set_selected_tool("select")
		placement_tool.set_tool("select")
		return
	placement_tool.clear_crew_order_targeting()
	game_ui.set_selected_work_order_tool("")
	placement_tool.set_tool(tool_name)


func _on_palette_item_selected(item_id: String) -> void:
	if _sandbox_action_blocked("placing farm items"):
		return
	placement_tool.clear_crew_order_targeting()
	game_ui.set_selected_work_order_tool("")
	placement_tool.set_selected_item(item_id)
	placement_tool.set_tool("place")


func _on_work_order_tool_selected(action_id: String) -> void:
	if action_id == "":
		placement_tool.clear_crew_order_targeting()
		game_ui.set_selected_work_order_tool("")
		game_ui.show_message("Crew order cleared.")
		sound_manager.play_stamp("ui_click")
		return
	if _sandbox_action_blocked("marking free-play crew orders"):
		game_ui.set_selected_work_order_tool("")
		return

	if not WORK_ORDER_ACTIONS.has(action_id):
		game_ui.show_message("Unknown crew order.")
		sound_manager.play_stamp("error_soft")
		return

	var action: Dictionary = WORK_ORDER_ACTIONS[action_id]
	placement_tool.set_tool("select")
	placement_tool.set_crew_order_targeting(action_id, str(action.get("preview_item", "fence")))
	game_ui.set_selected_tool("select")
	game_ui.set_selected_work_order_tool(action_id)
	game_ui.show_message("%s: mark a farm tile." % str(action.get("verb", "Crew order")))
	sound_manager.play_stamp("tool_select")


func _on_skill_forge_run_requested(template_id: String) -> void:
	if _sandbox_action_blocked("running free-play Forge recipes"):
		return
	_run_skill_forge_template(template_id, "Skill Forge order drafted.")


func _on_skill_forge_revision_requested(template_id: String) -> void:
	if _sandbox_action_blocked("running free-play Forge recipes"):
		return
	_run_skill_forge_template(template_id, "Skill Forge revision compiled.")


func _on_skill_forge_review_requested(template_id: String) -> void:
	if _sandbox_action_blocked("reviewing free-play Forge recipes"):
		return
	if _skill_forge_templates == null or _skill_forge_run_harness == null:
		return

	var spec: Dictionary = _skill_forge_templates.get_template_spec(template_id)
	if spec.is_empty():
		game_ui.show_message("Unknown Forge template.")
		sound_manager.play_stamp("error_soft")
		return

	var draft_spec := _skill_forge_blocked_draft_for_template(template_id, spec)
	var blocked_result: Dictionary = _skill_forge_run_harness.start_manual_run(draft_spec, _skill_forge_request_for_template(template_id))
	_apply_skill_forge_result(blocked_result)
	if str(blocked_result.get("status", "")) == "blocked":
		game_ui.show_message("Skill Forge found a revision.")
		sound_manager.play_stamp("error_soft")
		return

	game_ui.show_message("Skill Forge draft passed.")


func _run_skill_forge_template(template_id: String, success_message: String) -> void:
	if _skill_forge_templates == null or _skill_forge_run_harness == null:
		return

	var spec: Dictionary = _skill_forge_templates.get_template_spec(template_id)
	if spec.is_empty():
		game_ui.show_message("Unknown Forge template.")
		sound_manager.play_stamp("error_soft")
		return

	var start_result := _start_skill_forge_spec(spec, _skill_forge_request_for_template(template_id), "skill_forge")
	if str(start_result.get("status", "")) == "started":
		game_ui.show_message("%s Send the drafted crew order to verify it." % success_message)


func _on_selected_tile_changed(grid_pos: Vector2i) -> void:
	if _skill_trigger_scheduler != null and _skill_trigger_scheduler.has_armed():
		var armed: Dictionary = _skill_trigger_scheduler.snapshot()
		var captured_request: Dictionary = armed.get("request", {})
		var captured_target: Vector2i = captured_request.get("target_tile", Vector2i(-1, -1))
		game_ui.set_workbench_trace({
			"stage": "TRIGGER ARMED",
			"status": "WAITING FOR DAY START",
			"runtime_status": "ARMED ONCE  ·  DAY START",
			"runtime_color": Color("#9ac76e"),
			"agent_name": str(captured_request.get("agent_name", "Crew")),
			"target_tile": captured_target,
			"target_source": "captured selected_tile",
			"tutor_lines": [_pipeline_tutor_line("lifecycle", "armed")],
			"lines": [
				"Selection moved to (%s,%s); the armed target remains (%s,%s)." % [grid_pos.x, grid_pos.y, captured_target.x, captured_target.y],
				"No crew order exists yet. End Day fires this program once."
			]
		})
		return
	var tutor_lines: Array[String] = []
	var lesson: Dictionary = _skill_lesson_library.get_lesson(_active_lesson_id)
	if not lesson.is_empty():
		var first_hint := str(lesson.get("tutor", {}).get("first_hint", "")).strip_edges()
		if first_hint != "":
			tutor_lines.append(first_hint)
	game_ui.set_workbench_trace({
		"stage": "TARGET SELECTED",
		"status": "READY",
		"runtime_status": "READY  ·  LOCAL COMPILER",
		"target_tile": grid_pos,
		"target_source": "selected_tile",
		"tutor_lines": tutor_lines,
		"lines": ["selected_tile -> (%s,%s)" % [grid_pos.x, grid_pos.y], "Press COMPILE or Cmd/Ctrl+Enter."]
	})


func _on_lesson_selected(lesson_id: String) -> void:
	if _player_progress == null:
		return
	var lesson: Dictionary = _skill_lesson_library.get_lesson(lesson_id)
	var completed: Array = _player_progress.get_completed_lessons()
	if lesson.is_empty() or not _skill_lesson_library.is_unlocked(lesson_id, completed):
		game_ui.show_message("That lesson is still locked by the previous receipt.")
		sound_manager.play_stamp("error_soft")
		return
	_active_lesson_id = lesson_id
	_disarm_workbench_trigger("lesson_loaded", false)
	game_ui.set_current_lesson_goal(lesson)
	game_ui.set_workbench_source(
		str(lesson.get("starting_editor_text", "")),
		"lesson_%02d.agent" % int(lesson.get("order", 0))
	)
	var mode := "Review" if completed.has(lesson_id) else "Current"
	game_ui.show_message("%s lesson loaded: %s." % [mode, str(lesson.get("title", "Lesson"))])


func _on_program_save_requested(program_name: String, source_text: String) -> void:
	if _player_progress == null:
		return
	if source_text != _last_valid_compiled_source or _last_valid_compiled_spec.is_empty():
		game_ui.show_message("Compile this exact source before saving it to the shelf.")
		sound_manager.play_stamp("error_soft")
		return
	if not _player_progress.save_program(program_name, source_text):
		game_ui.show_message("Program shelf could not save that name.")
		sound_manager.play_stamp("error_soft")
		return
	game_ui.set_saved_programs(_player_progress.list_programs())
	game_ui.add_field_log("Program saved: %s." % program_name.strip_edges())
	game_ui.show_message("Program saved: %s." % program_name.strip_edges())


func _on_program_load_requested(program_name: String) -> void:
	if _player_progress == null:
		return
	var source_text: String = str(_player_progress.get_program(program_name))
	if source_text == "":
		game_ui.show_message("That saved program is empty or missing.")
		sound_manager.play_stamp("error_soft")
		return
	_disarm_workbench_trigger("program_loaded", false)
	game_ui.set_workbench_source(source_text, "%s.agent" % program_name.to_snake_case())
	var parsed: Dictionary = _skill_script_parser.parse(source_text)
	if bool(parsed.get("ok", false)):
		var loaded_spec: Dictionary = parsed.get("spec", {})
		if bool(SkillSpecValidatorScript.new().validate(loaded_spec).get("valid", false)):
			_last_valid_compiled_source = source_text
			_last_valid_compiled_spec = loaded_spec.duplicate(true)
	game_ui.show_message("Program loaded: %s." % program_name)


func _on_workbench_compile_requested(source_text: String) -> void:
	if _skill_script_parser == null:
		return
	var parsed: Dictionary = _skill_script_parser.parse(source_text)
	if not bool(parsed.get("ok", false)):
		_disarm_workbench_trigger("compile_replaced", false)
		var parse_error: Dictionary = parsed.get("error", {})
		var parse_class := str(parse_error.get("class", "syntax"))
		var tutor_lines := _lesson_failure_tutor(
			_active_lesson_id,
			"parse.%s" % parse_class,
			"parse",
			parse_class,
			{"code": str(parse_error.get("code", "expected_token"))}
		)
		game_ui.set_workbench_trace({
			"stage": "PARSE ERROR",
			"status": "BLOCKED",
			"runtime_status": "BLOCKED  ·  FIX LINE %s" % int(parse_error.get("line", 1)),
			"runtime_color": Color("#e7785b"),
			"issues": [parse_error],
			"tutor_lines": tutor_lines,
			"lines": ["Parser stopped before validation."]
		})
		game_ui.show_message("Workbench parse stopped at line %s." % int(parse_error.get("line", 1)))
		sound_manager.play_stamp("error_soft")
		return

	var spec: Dictionary = parsed.get("spec", {})
	var request: Dictionary = parsed.get("request", {}).duplicate(true)
	var target_info := _workbench_target_for_spec(spec)
	request["target_tile"] = target_info.get("target_tile", Vector2i(-1, -1))
	request["target_source"] = str(target_info.get("target_source", "template_fallback"))
	request["day"] = grid_manager.day
	request["source_context"] = {
		"source": "skill_forge",
		"label": "Agent Workbench"
	}
	var source_map: Dictionary = parsed.get("source_map", {})
	var trigger_type := str(spec.get("trigger", {}).get("type", "manual")).strip_edges()
	if trigger_type == "day_start":
		_arm_workbench_day_start(spec, request, source_text, source_map)
		return
	_disarm_workbench_trigger("compile_replaced", false)
	_start_skill_forge_spec(spec, request, "workbench", source_text, source_map, "manual")


func _arm_workbench_day_start(
	spec: Dictionary,
	request: Dictionary,
	source_text: String,
	source_map: Dictionary
) -> void:
	var validation: Dictionary = SkillSpecValidatorScript.new().validate(spec)
	if not bool(validation.get("valid", false)):
		_disarm_workbench_trigger("compile_replaced", false)
		_start_skill_forge_spec(spec, request, "workbench", source_text, source_map, "day_start")
		return
	if str(request.get("target_source", "")) != "selected_tile":
		_disarm_workbench_trigger("compile_replaced", false)
		var target_detail := "A day-start program needs a tile selected at Compile so its future target is explicit."
		game_ui.set_workbench_trigger_armed(false)
		game_ui.set_workbench_trace({
			"stage": "TRIGGER ARM BLOCKED",
			"status": "SELECT A TILE",
			"runtime_status": "BLOCKED  ·  TARGET REQUIRED",
			"runtime_color": Color("#e7785b"),
			"agent_name": str(request.get("agent_name", "Crew")),
			"issues": [_workbench_runtime_issue(
				source_map,
				"context.target",
				"trigger_target_required",
				target_detail,
				"Select one compatible farm tile, then compile again to capture it."
			)],
			"lines": ["No trigger armed, crew order drafted, or farm tile changed."]
		})
		game_ui.show_message("DAY START NEEDS A TARGET  ·  Select one farm tile first.")
		sound_manager.play_stamp("error_soft")
		return

	var arm_result: Dictionary = _skill_trigger_scheduler.arm(
		spec,
		request,
		source_text,
		source_map,
		grid_manager.day
	)
	if str(arm_result.get("status", "")) not in ["armed", "replaced"]:
		game_ui.set_workbench_trigger_armed(false)
		game_ui.show_message("That trigger could not be armed by the local scheduler.")
		sound_manager.play_stamp("error_soft")
		return

	var arm: Dictionary = arm_result.get("arm", {})
	var captured_request: Dictionary = arm.get("request", {})
	var target: Vector2i = captured_request.get("target_tile", Vector2i(-1, -1))
	_last_valid_compiled_source = source_text
	_last_valid_compiled_spec = spec.duplicate(true)
	game_ui.set_workbench_trigger_armed(true)
	game_ui.pulse_workbench_compile()
	sound_manager.play_stamp("compile_success")
	if bool(arm_result.get("replaced", false)):
		var previous: Dictionary = arm_result.get("previous_arm", {})
		_record_skill_trigger_event("replaced", previous, "A newer day-start compile replaced this arm.")
		game_ui.add_field_log("Day-start trigger replaced: %s." % str(previous.get("id", "previous arm")))
	_record_skill_trigger_event("armed", arm, "Captured at Compile; no crew order drafted.")
	game_ui.add_field_log("Day-start trigger armed once: %s for %s at (%s,%s)." % [
		str(arm.get("id", "day_start_arm")),
		str(captured_request.get("agent_name", "Crew")),
		target.x,
		target.y
	])
	game_ui.set_workbench_trace({
		"stage": "TRIGGER ARMED",
		"status": "WAITING FOR DAY START",
		"runtime_status": "ARMED ONCE  ·  DAY START",
		"runtime_color": Color("#9ac76e"),
		"agent_name": str(captured_request.get("agent_name", "Crew")),
		"target_tile": target,
		"target_source": "captured selected_tile",
		"run_id": str(arm.get("id", "")),
		"tutor_lines": [_pipeline_tutor_line("lifecycle", "armed")],
		"lines": [
			"Parse passed. Validation passed.",
			"No guard checked, crew order drafted, or farm tile changed at Compile.",
			"End Day advances the farm, then fires this program once."
		]
	})
	game_ui.show_message("DAY START ARMED ONCE  ·  End Day will wake %s." % str(captured_request.get("agent_name", "Crew")))


func _on_workbench_trigger_disarm_requested() -> void:
	var result := _disarm_workbench_trigger("player_requested", true)
	if result.is_empty():
		game_ui.show_message("No day-start trigger is armed.")
		sound_manager.play_stamp("ui_click")


func _disarm_workbench_trigger(reason: String, announce: bool) -> Dictionary:
	if _skill_trigger_scheduler == null:
		return {}
	var result: Dictionary = _skill_trigger_scheduler.disarm(reason)
	if not bool(result.get("disarmed", false)):
		return {}
	var arm: Dictionary = result.get("arm", {})
	var status := "replaced" if reason == "compile_replaced" else "disarmed"
	var detail := "A newer compile replaced the one-shot arm." if status == "replaced" else "The one-shot arm was removed before day start."
	_record_skill_trigger_event(status, arm, detail)
	game_ui.set_workbench_trigger_armed(false)
	game_ui.add_field_log("Day-start trigger %s: %s." % [status, str(arm.get("id", "day_start_arm"))])
	if announce:
		var captured_request: Dictionary = arm.get("request", {})
		game_ui.set_workbench_trace({
			"stage": "TRIGGER DISARMED",
			"status": "READY",
			"runtime_status": "READY  ·  LOCAL COMPILER",
			"agent_name": str(captured_request.get("agent_name", "Crew")),
			"target_tile": captured_request.get("target_tile", Vector2i(-1, -1)),
			"target_source": "captured selected_tile",
			"tutor_lines": [_pipeline_tutor_line("lifecycle", "disarmed")],
			"lines": [detail, "The source remains in the editor and can be armed again."]
		})
		game_ui.show_message("DAY START DISARMED  ·  No automatic run is scheduled.")
		sound_manager.play_stamp("ui_click")
	return result


func _fire_workbench_day_start() -> void:
	if _skill_trigger_scheduler == null:
		return
	var activation: Dictionary = _skill_trigger_scheduler.consume_day_start(grid_manager.day)
	if not bool(activation.get("fired", false)):
		return
	var arm: Dictionary = activation.get("arm", {})
	var request: Dictionary = arm.get("request", {}).duplicate(true)
	var target: Vector2i = request.get("target_tile", Vector2i(-1, -1))
	game_ui.set_workbench_trigger_armed(false)
	_record_skill_trigger_event("fired", arm, "Day %s began; automatic dispatch requested." % grid_manager.day)
	game_ui.add_field_log("Day-start trigger fired: %s on Day %s for %s at (%s,%s)." % [
		str(arm.get("id", "day_start_arm")),
		grid_manager.day,
		str(request.get("agent_name", "Crew")),
		target.x,
		target.y
	])

	if not _pending_skill_forge_run.is_empty():
		var busy_detail := "Day-start trigger skipped because another Forge world check is still pending; the active run was not replaced."
		_record_skill_trigger_event("skipped", arm, busy_detail)
		game_ui.add_field_log("Day-start trigger skipped: Forge pipeline busy; arm consumed without replacement.")
		game_ui.set_workbench_trace({
			"stage": "TRIGGER SKIPPED",
			"status": "PIPELINE BUSY",
			"runtime_status": "SKIPPED  ·  PIPELINE BUSY",
			"runtime_color": Color("#e7785b"),
			"agent_name": str(request.get("agent_name", "Crew")),
			"target_tile": target,
			"target_source": "captured selected_tile",
			"run_id": str(_pending_skill_forge_run.get("run_id", "")),
			"order_id": str(_pending_skill_forge_run.get("order_id", "")),
			"issues": [_workbench_runtime_issue(
				arm.get("source_map", {}),
				"trigger.type",
				"trigger_runtime_busy",
				busy_detail,
				_pipeline_tutor_line("lifecycle", "skipped")
			)],
			"tutor_lines": [_pipeline_tutor_line("lifecycle", "skipped")],
			"lines": ["The existing run and crew order remain authoritative."]
		})
		game_ui.show_message("DAY START SKIPPED  ·  Forge pipeline was already busy.")
		sound_manager.play_stamp("error_soft")
		return

	request["day"] = grid_manager.day
	request["run_id"] = "%s_day_%03d" % [str(arm.get("id", "day_start_arm")), grid_manager.day]
	request["trigger_arm_id"] = str(arm.get("id", ""))
	request["target_source"] = "captured selected_tile"
	request["source_context"] = {
		"source": "day_start",
		"label": "One-shot Workbench trigger"
	}
	var result := _start_skill_forge_spec(
		arm.get("spec", {}),
		request,
		"workbench_trigger",
		str(arm.get("source", "")),
		arm.get("source_map", {}),
		"day_start",
		false
	)
	if str(result.get("status", "")) != "started":
		var detail := str(result.get("run", {}).get("result_detail", "Day-start activation was blocked before dispatch."))
		_record_skill_trigger_event(str(result.get("status", "blocked")), arm, detail)
		return
	var order_id := str(result.get("drafted_order_id", ""))
	if order_id == "":
		return
	_on_work_order_requested(order_id)
	if str(work_orders.get(order_id, {}).get("status", "")) == "waiting":
		game_ui.pulse_workbench_run(order_id)
		sound_manager.play_stamp("run_dispatch")


func _record_skill_trigger_event(status: String, arm: Dictionary, detail: String) -> void:
	if _event_log == null or arm.is_empty():
		return
	var request: Dictionary = arm.get("request", {})
	var spec: Dictionary = arm.get("spec", {})
	_event_log.record_event("skill_trigger_%s" % status.to_snake_case(), {
		"day": grid_manager.day,
		"status": status,
		"arm_id": str(arm.get("id", "")),
		"trigger_type": str(arm.get("trigger_type", spec.get("trigger", {}).get("type", "day_start"))),
		"skill_id": str(spec.get("id", "")),
		"skill_name": str(spec.get("name", "Skill Run")),
		"agent_id": str(request.get("agent_id", "")),
		"agent_name": str(request.get("agent_name", "Crew")),
		"target_tile": request.get("target_tile", Vector2i(-1, -1)),
		"detail": detail
	})


func _workbench_target_for_spec(spec: Dictionary) -> Dictionary:
	if placement_tool != null and placement_tool.has_method("has_selected_tile") and bool(placement_tool.call("has_selected_tile")):
		return {
			"target_tile": placement_tool.call("get_selected_grid_pos"),
			"target_source": "selected_tile"
		}
	var action := _skill_forge_primary_action(spec)
	var template_by_action := {
		"build_fence": "build_fence_starter",
		"clear_brush": "clear_patch_starter",
		"harvest_crop": "harvest_crops_starter",
		"plant_seed": "plant_seed_starter",
		"tend_crop": "tend_crops_starter"
	}
	return {
		"target_tile": _skill_forge_target_for_template(str(template_by_action.get(action, ""))),
		"target_source": "template_fallback"
	}


func _start_skill_forge_spec(
	spec: Dictionary,
	request: Dictionary,
	origin: String,
	source_text: String = "",
	source_map: Dictionary = {},
	fired_trigger: String = "manual",
	replace_pending: bool = true
) -> Dictionary:
	var is_workbench_origin := origin in ["workbench", "workbench_trigger"]
	var lesson_id_for_run := _active_lesson_id if origin == "workbench" and fired_trigger == "manual" else ""
	if replace_pending:
		_cancel_pending_skill_forge_run("order never completed; replaced by a newer compile", true)
	elif not _pending_skill_forge_run.is_empty():
		return {
			"status": "runtime_busy",
			"can_run": false,
			"run": {"result_detail": "Another Forge world check is still pending."}
		}
	var start_result: Dictionary = _skill_forge_run_harness.start_run(spec, request, fired_trigger)
	var validation: Dictionary = start_result.get("validation", {})
	var target: Vector2i = request.get("target_tile", Vector2i(-1, -1))
	if str(start_result.get("status", "")) != "started":
		_apply_skill_forge_result(start_result)
		if is_workbench_origin:
			var validation_errors: Array = _workbench_diagnostics(validation.get("errors", []), source_map)
			var validation_warnings: Array = _workbench_diagnostics(validation.get("warnings", []), source_map)
			var first_issue: Dictionary = validation_errors[0] if not validation_errors.is_empty() and typeof(validation_errors[0]) == TYPE_DICTIONARY else {}
			var issue_code := str(first_issue.get("code", "validator_error"))
			var tutor_lines := _lesson_failure_tutor(
				lesson_id_for_run,
				"validation.%s" % issue_code,
				"validator",
				issue_code,
				{"drift": str(validation.get("drift", {}).get("level", "hallucinating"))}
			)
			game_ui.set_workbench_trace({
				"stage": "VALIDATION BLOCKED",
				"status": "BLOCKED",
				"runtime_status": "BLOCKED  ·  VALIDATION",
				"runtime_color": Color("#e7785b"),
				"agent_name": str(request.get("agent_name", "Crew")),
				"target_tile": target,
				"target_source": str(request.get("target_source", "selected_tile")),
				"issues": validation_errors,
				"warnings": validation_warnings,
				"drift": validation.get("drift", {}),
				"tutor_lines": tutor_lines,
				"lines": ["Parse passed.", "Validator rejected the Skill Spec."]
			})
		game_ui.show_message("Workbench validation blocked the run.")
		sound_manager.play_stamp("error_soft")
		return start_result

	if is_workbench_origin:
		_last_valid_compiled_source = source_text
		_last_valid_compiled_spec = spec.duplicate(true)

	var before := _skill_forge_snapshot(target)
	var guard_condition := _skill_forge_guard_condition(spec)
	var guard_result: Dictionary = _skill_check_evaluator.evaluate_guard(guard_condition, before)
	if not bool(guard_result.get("allowed", false)):
		var guard_detail := str(guard_result.get("result_detail", "Runtime guard blocked the run."))
		var blocked_result: Dictionary = _skill_forge_run_harness.block_run(start_result, {
			"result_detail": guard_detail,
			"day": grid_manager.day
		})
		_apply_skill_forge_result(blocked_result)
		if is_workbench_origin:
			var tutor_lines := _lesson_failure_tutor(
				lesson_id_for_run,
				"guard.%s" % guard_condition,
				"guard",
				guard_condition,
				{"allowed": false, "observed": guard_result.get("observed", "")}
			)
			game_ui.set_workbench_trace({
				"stage": "TRIGGER BLOCKED" if origin == "workbench_trigger" else "RUNTIME GUARD",
				"status": "BLOCKED",
				"runtime_status": "BLOCKED  ·  DAY START" if origin == "workbench_trigger" else "BLOCKED  ·  GUARD",
				"runtime_color": Color("#e7785b"),
				"agent_name": str(request.get("agent_name", "Crew")),
				"target_tile": target,
				"target_source": str(request.get("target_source", "selected_tile")),
				"issues": [_workbench_runtime_issue(
					source_map,
					"steps[0].when",
					"runtime_guard_blocked",
					guard_detail,
					_pipeline_tutor_line("guard", guard_condition, {"allowed": false})
				)],
				"drift": validation.get("drift", {}),
				"tutor_lines": tutor_lines,
				"lines": [
					"Day %s began; the one-shot trigger checked its captured target." % grid_manager.day if origin == "workbench_trigger" else "Parse passed.",
					"Validation passed.",
					guard_detail
				]
			})
		game_ui.show_message(str(guard_result.get("result_detail", "Workbench guard blocked the run.")))
		sound_manager.play_stamp("error_soft")
		return blocked_result

	_apply_skill_forge_result(start_result)
	var order_id := str(start_result.get("drafted_order_id", ""))
	if order_id == "":
		var failure_detail := str(start_result.get("drafted_order_blocked_detail", "order never completed because no crew order could be drafted"))
		var failed_result: Dictionary = _skill_forge_run_harness.complete_run(start_result, false, {
			"result_detail": failure_detail,
			"day": grid_manager.day
		})
		_apply_skill_forge_result(failed_result)
		if is_workbench_origin:
			var tutor_lines := _lesson_failure_tutor(
				lesson_id_for_run,
				"order.blocked",
				"order",
				"blocked",
				{"detail": failure_detail}
			)
			game_ui.set_workbench_trace({
				"stage": "TRIGGER FAILED" if origin == "workbench_trigger" else "ORDER BLOCKED",
				"status": "FAILED",
				"runtime_status": "FAILED  ·  DAY START" if origin == "workbench_trigger" else "FAILED  ·  ORDER BLOCKED",
				"runtime_color": Color("#e7785b"),
				"agent_name": str(request.get("agent_name", "Crew")),
				"target_tile": target,
				"target_source": str(request.get("target_source", "selected_tile")),
				"issues": [_workbench_runtime_issue(
					source_map,
					"steps[0].tool",
					"order_blocked",
					failure_detail,
					_pipeline_tutor_line("order", "blocked", {"detail": failure_detail})
				)],
				"warnings": validation.get("warnings", []),
				"drift": validation.get("drift", {}),
				"tutor_lines": tutor_lines,
				"lines": ["Parse passed.", "Validation passed.", failure_detail]
			})
		return failed_result

	_pending_skill_forge_run = {
		"run_id": str(start_result.get("run", {}).get("id", "")),
		"start_result": start_result.duplicate(true),
		"order_id": order_id,
		"target_tile": target,
		"agent_id": str(request.get("agent_id", "")),
		"agent_name": str(request.get("agent_name", "Crew")),
		"success_check": spec.get("success_check", {}).duplicate(true),
		"guard_condition": guard_condition,
		"guard_action": str(work_orders.get(order_id, {}).get("agent_action", _skill_forge_primary_action(spec))),
		"before_snapshot": before.duplicate(true),
		"started_day": grid_manager.day,
		"day_advances": 0,
		"origin": origin,
		"trigger_type": fired_trigger,
		"trigger_arm_id": str(request.get("trigger_arm_id", "")),
		"lesson_id": lesson_id_for_run,
		"source_text": source_text,
		"compiled_spec": spec.duplicate(true),
		"target_source": str(request.get("target_source", "selected_tile")),
		"source_map": source_map.duplicate(true)
	}
	if is_workbench_origin:
		if fired_trigger == "manual":
			game_ui.pulse_workbench_compile()
			sound_manager.play_stamp("compile_success")
		var tutor_lines: Array[String] = [
			_pipeline_tutor_line("lifecycle", "fired" if fired_trigger == "day_start" else "pending")
		]
		var drift_level := str(validation.get("drift", {}).get("level", "steady"))
		if drift_level != "steady":
			tutor_lines.push_front(_pipeline_tutor_line("drift", drift_level))
		game_ui.set_workbench_trace({
			"stage": "TRIGGER FIRED" if fired_trigger == "day_start" else "ORDER DRAFTED",
			"status": "PENDING WORLD CHECK",
			"runtime_status": "RUNNING  ·  DAY START" if fired_trigger == "day_start" else "PENDING  ·  WORLD CHECK",
			"agent_name": str(request.get("agent_name", "Crew")),
			"target_tile": target,
			"target_source": str(request.get("target_source", "selected_tile")),
			"warnings": _workbench_diagnostics(validation.get("warnings", []), source_map),
			"drift": validation.get("drift", {}),
			"run_id": str(_pending_skill_forge_run.get("run_id", "")),
			"order_id": order_id,
			"tutor_lines": tutor_lines,
			"lines": [
				"Day %s began; the one-shot trigger fired without Send." % grid_manager.day if fired_trigger == "day_start" else "Parse passed.",
				"Validation passed.",
				str(guard_result.get("result_detail", "Guard passed.")),
				"Crew order auto-dispatched; verification is pending." if fired_trigger == "day_start" else "Crew order drafted; verification is pending."
			]
		})
	return start_result


func _workbench_diagnostics(issues, source_map: Dictionary) -> Array:
	var enriched: Array = []
	if typeof(issues) != TYPE_ARRAY:
		return enriched
	for issue_value in issues:
		if typeof(issue_value) != TYPE_DICTIONARY:
			continue
		var issue: Dictionary = issue_value.duplicate(true)
		var field := str(issue.get("field", "")).strip_edges()
		var location_value = source_map.get(field, {})
		if typeof(location_value) != TYPE_DICTIONARY or (location_value as Dictionary).is_empty():
			location_value = source_map.get(_workbench_source_alias(field), {})
		if typeof(location_value) == TYPE_DICTIONARY:
			var location: Dictionary = location_value
			issue["line"] = maxi(1, int(location.get("line", 1)))
			issue["col"] = maxi(1, int(location.get("col", 1)))
			issue["token"] = str(location.get("token", field if field != "" else "<spec>"))
		else:
			issue["line"] = 1
			issue["col"] = 1
			issue["token"] = field if field != "" else "<spec>"
		var code := str(issue.get("code", "validator_error"))
		issue["suggestion"] = _pipeline_tutor_line("validator", code)
		enriched.append(issue)
	return enriched


func _workbench_runtime_issue(
	source_map: Dictionary,
	field: String,
	code: String,
	cause: String,
	suggestion: String
) -> Dictionary:
	var source_field := _workbench_source_alias(field)
	var location_value = source_map.get(field, source_map.get(source_field, {}))
	var location: Dictionary = location_value if typeof(location_value) == TYPE_DICTIONARY else {}
	var clean_field := field.strip_edges()
	return {
		"field": clean_field if clean_field != "" else "runtime",
		"code": code.strip_edges() if code.strip_edges() != "" else "runtime_error",
		"line": maxi(1, int(location.get("line", 1))),
		"col": maxi(1, int(location.get("col", 1))),
		"token": str(location.get("token", source_field if source_field != "" else "<runtime>")),
		"message": cause.strip_edges() if cause.strip_edges() != "" else "The runtime could not complete this program.",
		"suggestion": suggestion.strip_edges() if suggestion.strip_edges() != "" else _pipeline_tutor_line("lifecycle", "cancelled")
	}


func _workbench_source_alias(field: String) -> String:
	if field.begins_with("steps["):
		if field.ends_with(".when"):
			return "steps[0].when"
		if field.ends_with(".target"):
			return "steps[0].target"
		if field.ends_with(".tool") or field.ends_with(".id"):
			return "steps[0].tool"
		return "steps[0]"
	if field.begins_with("success_check."):
		return "success_check.type"
	return field


func _skill_forge_primary_action(spec: Dictionary) -> String:
	var steps = spec.get("steps", [])
	if typeof(steps) == TYPE_ARRAY:
		for index in range(steps.size() - 1, -1, -1):
			var step = steps[index]
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var tool_name := str(step.get("tool", "")).strip_edges()
			if tool_name != "" and tool_name != "inspect_tile":
				return tool_name
	return ""


func _skill_forge_guard_condition(spec: Dictionary) -> String:
	var action := _skill_forge_primary_action(spec)
	var steps = spec.get("steps", [])
	if typeof(steps) == TYPE_ARRAY:
		for step in steps:
			if typeof(step) == TYPE_DICTIONARY and str(step.get("tool", "")) == action:
				var condition := str(step.get("when", "always")).strip_edges()
				return condition if condition != "" else "always"
	return "always"


func _skill_forge_snapshot(target: Vector2i) -> Dictionary:
	var tile = grid_manager.get_tile(target) if grid_manager != null else null
	return _skill_check_evaluator.snapshot(tile, {
		"resources": resources.duplicate(true),
		"crafted_items": crafted_items.duplicate(true),
		"money": money
	}, target)


func _cancel_pending_skill_forge_run(reason: String, remove_order: bool) -> bool:
	if _pending_skill_forge_run.is_empty():
		return false
	var pending := _pending_skill_forge_run.duplicate(true)
	_pending_skill_forge_run.clear()
	var run_id := str(pending.get("run_id", ""))
	if _agent_manager != null and _agent_manager.has_method("cancel_forge_run"):
		_agent_manager.call("cancel_forge_run", run_id)
	var order_id := str(pending.get("order_id", ""))
	if remove_order and work_orders.has(order_id):
		var order: Dictionary = work_orders[order_id]
		_release_order_reservation(order)
		work_orders.erase(order_id)
		work_order_ids.erase(order_id)
		_record_removed_work_order_event(order, "forge_cancelled")
		_refresh_inventory_and_orders()
	var failure: Dictionary = _skill_forge_run_harness.complete_run(pending.get("start_result", {}), false, {
		"result_detail": reason,
		"day": grid_manager.day
	})
	_apply_skill_forge_result(failure)
	if str(pending.get("origin", "")).begins_with("workbench"):
		var lifecycle_state := "cancelled"
		if reason.contains("replaced"):
			lifecycle_state = "replaced"
		elif reason.contains("two day"):
			lifecycle_state = "timeout"
		var tutor_lines := _lesson_failure_tutor(
			str(pending.get("lesson_id", "")),
			"lifecycle.%s" % lifecycle_state,
			"lifecycle",
			lifecycle_state,
			{"detail": reason}
		)
		game_ui.set_workbench_trace({
			"stage": "DAY START WORLD CHECK" if str(pending.get("trigger_type", "manual")) == "day_start" else "WORLD CHECK",
			"status": "FAILED",
			"runtime_status": "FAILED  ·  DAY START" if str(pending.get("trigger_type", "manual")) == "day_start" else "FAILED",
			"runtime_color": Color("#e7785b"),
			"agent_name": str(pending.get("agent_name", "Crew")),
			"target_tile": pending.get("target_tile", Vector2i(-1, -1)),
			"target_source": str(pending.get("target_source", "selected_tile")),
			"run_id": run_id,
			"order_id": order_id,
			"issues": [_workbench_runtime_issue(
				pending.get("source_map", {}),
				"steps[0].tool",
				"lifecycle_%s" % lifecycle_state,
				reason,
				_pipeline_tutor_line("lifecycle", lifecycle_state, {"detail": reason})
			)],
			"tutor_lines": tutor_lines,
			"lines": [reason]
		})
	if str(pending.get("trigger_type", "manual")) == "day_start":
		_record_pending_skill_trigger_event("failed", pending, reason)
	return true


func _finish_pending_skill_forge_run(event: Dictionary) -> void:
	if _pending_skill_forge_run.is_empty():
		return
	var run_id := str(event.get("forge_run_id", ""))
	var order_id := str(event.get("work_order_id", ""))
	if run_id == "" or run_id != str(_pending_skill_forge_run.get("run_id", "")):
		return
	if order_id == "" or order_id != str(_pending_skill_forge_run.get("order_id", "")):
		return
	if str(event.get("action", "")) != str(_pending_skill_forge_run.get("guard_action", "")):
		return
	if _demand_target_from_value(event.get("grid_pos", Vector2i(-1, -1))) != _pending_skill_forge_run.get("target_tile", Vector2i(-1, -1)):
		return

	var pending := _pending_skill_forge_run.duplicate(true)
	if str(event.get("blocked_condition", "")) != "":
		_pending_skill_forge_run.clear()
		var blocked: Dictionary = _skill_forge_run_harness.block_run(pending.get("start_result", {}), {
			"result_detail": str(event.get("block_detail", "Runtime guard blocked the crew action.")),
			"day": grid_manager.day
		})
		_remove_skill_forge_order(order_id, "guard_blocked")
		_apply_skill_forge_result(blocked)
		_record_pending_skill_trigger_event("blocked", pending, str(blocked.get("run", {}).get("result_detail", "Runtime guard blocked the trigger.")))
		_update_workbench_terminal_trace(pending, blocked)
		return
	if not bool(event.get("success", false)):
		if str(pending.get("trigger_type", "manual")) == "day_start":
			_pending_skill_forge_run.clear()
			var failure_detail := str(event.get("message", "Crew could not complete the automatic action."))
			var failed: Dictionary = _skill_forge_run_harness.complete_run(pending.get("start_result", {}), false, {
				"result_detail": failure_detail,
				"day": grid_manager.day
			})
			_remove_skill_forge_order(order_id, "trigger_action_failed")
			_apply_skill_forge_result(failed)
			_record_pending_skill_trigger_event("failed", pending, failure_detail)
			_update_workbench_terminal_trace(pending, failed)
		return

	var after := _skill_forge_snapshot(pending.get("target_tile", Vector2i(-1, -1)))
	var verdict: Dictionary = _skill_check_evaluator.evaluate(
		pending.get("success_check", {}),
		pending.get("before_snapshot", {}),
		after
	)
	_pending_skill_forge_run.clear()
	var completion: Dictionary = _skill_forge_run_harness.complete_run(pending.get("start_result", {}), bool(verdict.get("passed", false)), {
		"result_detail": str(verdict.get("result_detail", "World check did not report a result.")),
		"day": grid_manager.day
	})
	_apply_skill_forge_result(completion)
	_record_pending_skill_trigger_event("passed" if bool(verdict.get("passed", false)) else "failed", pending, str(verdict.get("result_detail", "World check finished.")))
	if bool(verdict.get("passed", false)):
		game_ui.pulse_workbench_receipt_passed()
		sound_manager.play_stamp("receipt_pass")
	_update_workbench_terminal_trace(pending, completion, verdict)


func _update_workbench_terminal_trace(pending: Dictionary, result: Dictionary, verdict: Dictionary = {}) -> void:
	if not str(pending.get("origin", "")).begins_with("workbench"):
		return
	var status := str(result.get("status", "failed")).to_upper()
	var is_day_start := str(pending.get("trigger_type", "manual")) == "day_start"
	var detail := str(verdict.get("result_detail", result.get("run", {}).get("result_detail", "World check finished.")))
	var tutor_lines: Array[String] = []
	var runtime_issues: Array = []
	if not verdict.is_empty():
		tutor_lines = _evaluate_lesson_terminal(pending, result, verdict)
		if status != "PASSED":
			var check_type := str(verdict.get("check_type", result.get("run", {}).get("success_check_type", "")))
			runtime_issues.append(_workbench_runtime_issue(
				pending.get("source_map", {}),
				"success_check.type",
				"world_check_failed",
				detail,
				_pipeline_tutor_line("check", check_type, {"passed": false})
			))
	elif status == "BLOCKED":
		var guard_condition := str(pending.get("guard_condition", "always"))
		tutor_lines = _lesson_failure_tutor(
			str(pending.get("lesson_id", "")),
			"guard.%s" % guard_condition,
			"guard",
			guard_condition,
			{"allowed": false, "detail": detail}
		)
		runtime_issues.append(_workbench_runtime_issue(
			pending.get("source_map", {}),
			"steps[0].when",
			"runtime_guard_blocked",
			detail,
			_pipeline_tutor_line("guard", guard_condition, {"allowed": false})
		))
	else:
		var check_type := str(result.get("run", {}).get("success_check_type", ""))
		tutor_lines = _lesson_failure_tutor(
			str(pending.get("lesson_id", "")),
			"check.failed",
			"check",
			check_type,
			{"passed": false, "detail": detail}
		)
		runtime_issues.append(_workbench_runtime_issue(
			pending.get("source_map", {}),
			"success_check.type",
			"world_check_failed",
			detail,
			_pipeline_tutor_line("check", check_type, {"passed": false})
		))
	game_ui.set_workbench_trace({
		"stage": "DAY START WORLD CHECK" if is_day_start else "WORLD CHECK",
		"status": status,
		"agent_name": str(pending.get("agent_name", "Crew")),
		"target_tile": pending.get("target_tile", Vector2i(-1, -1)),
		"target_source": str(pending.get("target_source", "selected_tile")),
		"run_id": str(pending.get("run_id", "")),
		"order_id": str(pending.get("order_id", "")),
		"runtime_status": "%s  ·  DAY START" % status if is_day_start else status,
		"runtime_color": Color("#8fbe67") if status == "PASSED" else Color("#e7785b"),
		"issues": runtime_issues,
		"tutor_lines": tutor_lines,
		"lines": [detail]
	})


func _record_pending_skill_trigger_event(status: String, pending: Dictionary, detail: String) -> void:
	if str(pending.get("trigger_type", "manual")) != "day_start":
		return
	var spec: Dictionary = pending.get("compiled_spec", {})
	var target: Vector2i = pending.get("target_tile", Vector2i(-1, -1))
	game_ui.add_field_log("Day-start trigger %s: %s for %s at (%s,%s)." % [
		status,
		str(spec.get("name", "Skill Run")),
		str(pending.get("agent_name", "Crew")),
		target.x,
		target.y
	])
	if _event_log == null:
		return
	_event_log.record_event("skill_trigger_%s" % status.to_snake_case(), {
		"day": grid_manager.day,
		"status": status,
		"arm_id": str(pending.get("trigger_arm_id", "")),
		"run_id": str(pending.get("run_id", "")),
		"order_id": str(pending.get("order_id", "")),
		"trigger_type": "day_start",
		"skill_id": str(spec.get("id", "")),
		"skill_name": str(spec.get("name", "Skill Run")),
		"agent_id": str(pending.get("agent_id", "")),
		"agent_name": str(pending.get("agent_name", "Crew")),
		"target_tile": pending.get("target_tile", Vector2i(-1, -1)),
		"detail": detail
	})


func _remove_skill_forge_order(order_id: String, removal_status: String) -> void:
	if not work_orders.has(order_id):
		return
	var order: Dictionary = work_orders[order_id]
	_release_order_reservation(order)
	work_orders.erase(order_id)
	work_order_ids.erase(order_id)
	_record_removed_work_order_event(order, removal_status)
	_refresh_inventory_and_orders()


func _block_pending_skill_forge_target(order_id: String) -> bool:
	if _pending_skill_forge_run.is_empty() or order_id != str(_pending_skill_forge_run.get("order_id", "")):
		return false
	var pending := _pending_skill_forge_run.duplicate(true)
	_pending_skill_forge_run.clear()
	var target: Vector2i = pending.get("target_tile", Vector2i(-1, -1))
	var guard_result: Dictionary = _skill_check_evaluator.evaluate_guard(
		str(pending.get("guard_condition", "always")),
		_skill_forge_snapshot(target)
	)
	var detail := str(guard_result.get("result_detail", "")).strip_edges()
	if bool(guard_result.get("allowed", false)):
		detail = "Crew order blocked at tile (%s,%s): the target no longer accepts %s." % [target.x, target.y, str(work_orders.get(order_id, {}).get("action", "this action"))]
	if _agent_manager != null and _agent_manager.has_method("cancel_forge_run"):
		_agent_manager.call("cancel_forge_run", str(pending.get("run_id", "")))
	var blocked: Dictionary = _skill_forge_run_harness.block_run(pending.get("start_result", {}), {
		"result_detail": detail,
		"day": grid_manager.day
	})
	_remove_skill_forge_order(order_id, "target_blocked")
	_apply_skill_forge_result(blocked)
	_update_workbench_terminal_trace(pending, blocked)
	game_ui.show_message(detail)
	sound_manager.play_stamp("error_soft")
	return true


func _skill_forge_blocked_draft_for_template(template_id: String, spec: Dictionary) -> Dictionary:
	var draft := spec.duplicate(true)
	var expected_tool := _skill_forge_expected_revision_tool(template_id, draft)
	var tools = draft.get("tools", [])
	if typeof(tools) != TYPE_ARRAY:
		tools = []
	var revised_tools: Array = tools.duplicate()
	if revised_tools.is_empty():
		revised_tools.append("summon_rain")
	else:
		revised_tools[revised_tools.size() - 1] = "summon_rain"
	draft["tools"] = revised_tools

	var steps = draft.get("steps", [])
	if typeof(steps) == TYPE_ARRAY and not steps.is_empty():
		var revised_steps: Array = steps.duplicate(true)
		for index in range(revised_steps.size() - 1, -1, -1):
			var step = revised_steps[index]
			if typeof(step) != TYPE_DICTIONARY:
				continue
			step["tool"] = "summon_rain"
			revised_steps[index] = step
			break
		draft["steps"] = revised_steps

	var failure_handling = draft.get("failure_handling", {})
	if typeof(failure_handling) != TYPE_DICTIONARY:
		failure_handling = {}
	var revised_failure: Dictionary = failure_handling.duplicate(true)
	revised_failure["on_blocked"] = str(revised_failure.get("on_blocked", "record_receipt"))
	revised_failure["suggestion"] = "Replace summon_rain with %s and rerun." % expected_tool
	draft["failure_handling"] = revised_failure
	return draft


func _skill_forge_request_for_template(template_id: String) -> Dictionary:
	var agent := _skill_forge_agent_for_template(template_id)
	return {
		"agent_id": str(agent.get("id", "")),
		"agent_name": str(agent.get("name", "Crew")),
		"target_tile": _skill_forge_target_for_template(template_id),
		"day": grid_manager.day,
		"source_context": {
			"source": "skill_forge",
			"label": "Starter Lab"
		}
	}


func _skill_forge_agent_for_template(template_id: String) -> Dictionary:
	match template_id:
		"build_fence_starter":
			return {
				"id": "bert",
				"name": "Bert"
			}
		"clear_patch_starter":
			return {
				"id": "chuck",
				"name": "Chuck"
			}
		"harvest_crops_starter":
			return {
				"id": "bert",
				"name": "Bert"
			}
		"plant_seed_starter":
			return {
				"id": "marigold",
				"name": "Marigold"
			}
		"tend_crops_starter":
			return {
				"id": "marigold",
				"name": "Marigold"
			}
	return {
		"id": "bert",
		"name": "Bert"
	}


func _skill_forge_target_for_template(template_id: String) -> Vector2i:
	if placement_tool != null and placement_tool.has_method("has_selected_tile") and bool(placement_tool.call("has_selected_tile")):
		return placement_tool.call("get_selected_grid_pos")
	match template_id:
		"build_fence_starter":
			var fence_target := _find_demand_target_tile({"kind": "build_fence"})
			if fence_target != Vector2i(-1, -1):
				return fence_target
			return Vector2i(4, 5)
		"clear_patch_starter":
			var clear_target := _find_demand_target_tile({"kind": "clear_brush"})
			if clear_target != Vector2i(-1, -1):
				return clear_target
			return Vector2i(0, 1)
		"harvest_crops_starter":
			var harvest_target := _find_demand_target_tile({"kind": "harvest_crop"})
			if harvest_target != Vector2i(-1, -1):
				return harvest_target
			return Vector2i(1, 6)
		"plant_seed_starter":
			var open_seed_tile := _first_plant_seed_order_tile()
			if open_seed_tile != Vector2i(-1, -1):
				return open_seed_tile
			return Vector2i(0, 0)
		"tend_crops_starter":
			var crop_target := _first_tend_crop_order_tile()
			if crop_target != Vector2i(-1, -1):
				return crop_target
			return Vector2i(1, 4)
	return Vector2i(0, 0)


func _first_crop_tile() -> Vector2i:
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var grid_pos := Vector2i(x, z)
			var tile = grid_manager.get_tile(grid_pos)
			if tile != null and tile.crop != null:
				return grid_pos
	return Vector2i(-1, -1)


func _first_plant_seed_order_tile() -> Vector2i:
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var grid_pos := Vector2i(x, z)
			if _can_target_crew_order("plant_seed", grid_pos):
				return grid_pos
	return Vector2i(-1, -1)


func _first_tend_crop_order_tile() -> Vector2i:
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var grid_pos := Vector2i(x, z)
			if _can_target_crew_order("tend_crop", grid_pos):
				return grid_pos
	return Vector2i(-1, -1)


func _skill_forge_expected_revision_tool(template_id: String, spec: Dictionary) -> String:
	match template_id:
		"build_fence_starter":
			return "build_fence"
		"clear_patch_starter":
			return "clear_brush"
		"harvest_crops_starter":
			return "harvest_crop"
		"plant_seed_starter":
			return "plant_seed"
		"tend_crops_starter":
			return "tend_crop"

	var steps = spec.get("steps", [])
	if typeof(steps) == TYPE_ARRAY:
		for index in range(steps.size() - 1, -1, -1):
			var step = steps[index]
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var tool_name := str(step.get("tool", "")).strip_edges()
			if tool_name != "" and tool_name != "inspect_tile":
				return tool_name
	return "an allowlisted tool"


func _apply_skill_forge_result(result: Dictionary) -> void:
	var run_value = result.get("run", {})
	if str(result.get("status", "")) == "blocked" and typeof(run_value) == TYPE_DICTIONARY:
		var blocked_run: Dictionary = run_value
		_show_named_agent_drift_reaction(
			str(blocked_run.get("agent_id", "")),
			blocked_run.get("drift", {})
		)
	for line in result.get("field_log_lines", []):
		game_ui.add_field_log(str(line))

	if _event_log:
		for entry in result.get("event_log_entries", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var payload = entry.get("payload", {})
			if typeof(payload) != TYPE_DICTIONARY:
				payload = {}
			_event_log.record_event(str(entry.get("type", "skill_forge_run")), payload)

	var order_id := ""
	if str(result.get("status", "")) == "started":
		order_id = _maybe_draft_skill_forge_work_order(result)
	if order_id == "":
		order_id = _skill_forge_order_id_for_result(result)
	if order_id != "":
		result["drafted_order_id"] = order_id
		var order: Dictionary = work_orders.get(order_id, {})
		result["drafted_order_label"] = str(order.get("label", ""))

	game_ui.set_skill_forge_result(result)


func _maybe_draft_skill_forge_work_order(result: Dictionary) -> String:
	var directive_value = result.get("directive", {})
	if typeof(directive_value) != TYPE_DICTIONARY:
		return ""
	var directive: Dictionary = directive_value
	if str(directive.get("kind", "")).strip_edges() != "work_order_directive":
		return ""

	var forge_run_id := str(directive.get("forge_run_id", "")).strip_edges()
	if forge_run_id == "":
		var run_value = result.get("run", {})
		if typeof(run_value) == TYPE_DICTIONARY:
			var run: Dictionary = run_value
			forge_run_id = str(run.get("id", "")).strip_edges()
	if forge_run_id == "" or _has_skill_forge_work_order(forge_run_id):
		return ""

	var action_id := str(directive.get("action", "")).strip_edges()
	if not WORK_ORDER_ACTIONS.has(action_id):
		return ""

	var target_tile := _demand_target_from_value(directive.get("target_tile", Vector2i(-1, -1)))
	var skill_name := str(directive.get("skill_name", "Skill Run")).strip_edges()
	if skill_name == "":
		skill_name = "Skill Run"
	if target_tile == Vector2i(-1, -1) or not _can_target_crew_order(action_id, target_tile):
		var target_label := "%s,%s" % [target_tile.x, target_tile.y] if target_tile != Vector2i(-1, -1) else "unknown target"
		result["drafted_order_blocked_reason"] = "target changed"
		result["drafted_order_blocked_detail"] = "target changed before %s could draft %s crew work at %s" % [skill_name, action_id, target_label]
		game_ui.add_field_log("Forge order blocked: target changed for %s." % skill_name)
		return ""

	var action: Dictionary = WORK_ORDER_ACTIONS[action_id]
	var order_id := "order_%03d" % _next_work_order_number
	_next_work_order_number += 1
	var base_label := _work_order_label(action_id, target_tile)
	var order := {
		"id": order_id,
		"label": "%s: %s" % [skill_name, base_label],
		"status": "ready",
		"action": action_id,
		"agent_action": str(directive.get("agent_action", action.get("agent_action", ""))),
		"target_tile": target_tile,
		"required_item": str(directive.get("required_item", action.get("required_item", ""))),
		"created_day": grid_manager.day,
		"source": "skill_forge",
		"preference_source": "skill_forge",
		"preference_label": skill_name,
		"forge_run_id": forge_run_id,
		"skill_id": str(directive.get("skill_id", "")),
		"skill_name": skill_name,
		"agent_id": str(directive.get("agent_id", "")),
		"agent_name": str(directive.get("agent_name", "")),
		"directive_id": str(directive.get("id", "")),
		"directive_kind": str(directive.get("kind", "")),
		"drift": directive.get("drift", {}).duplicate(true),
		"source_context": directive.get("source_context", {}),
		"steps": directive.get("steps", []).duplicate(true),
		"success_check": directive.get("success_check", {}).duplicate(true),
		"failure_handling": directive.get("failure_handling", {}).duplicate(true),
		"guard_condition": _skill_forge_guard_condition_from_directive(directive),
		"guard_action": str(directive.get("agent_action", action.get("agent_action", action_id)))
	}
	work_orders[order_id] = order
	work_order_ids.append(order_id)
	_refresh_work_orders()
	game_ui.add_field_log("Forge order drafted: %s -> %s." % [skill_name, base_label])
	_record_work_order_event(order_id, "forge_drafted")
	return order_id


func _skill_forge_guard_condition_from_directive(directive: Dictionary) -> String:
	var action := str(directive.get("action", ""))
	var steps = directive.get("steps", [])
	if typeof(steps) == TYPE_ARRAY:
		for step in steps:
			if typeof(step) != TYPE_DICTIONARY or str(step.get("tool", "")) != action:
				continue
			var condition := str(step.get("when", "always")).strip_edges()
			return condition if condition != "" else "always"
	return "always"


func _has_skill_forge_work_order(forge_run_id: String) -> bool:
	for order_id in work_order_ids:
		if not work_orders.has(str(order_id)):
			continue
		var order: Dictionary = work_orders[str(order_id)]
		if str(order.get("forge_run_id", "")) == forge_run_id:
			return true
	return false


func _skill_forge_order_id_for_result(result: Dictionary) -> String:
	var forge_run_id := ""
	var run_value = result.get("run", {})
	if typeof(run_value) == TYPE_DICTIONARY:
		var run: Dictionary = run_value
		forge_run_id = str(run.get("id", "")).strip_edges()
	if forge_run_id == "":
		var directive_value = result.get("directive", {})
		if typeof(directive_value) == TYPE_DICTIONARY:
			var directive: Dictionary = directive_value
			forge_run_id = str(directive.get("forge_run_id", "")).strip_edges()
	if forge_run_id == "":
		return ""

	for order_id in work_order_ids:
		var order_key := str(order_id)
		if not work_orders.has(order_key):
			continue
		var order: Dictionary = work_orders[order_key]
		if str(order.get("forge_run_id", "")).strip_edges() == forge_run_id:
			return order_key
	return ""


func _maybe_update_skill_forge_receipt_trace(payload: Dictionary, receipt: String) -> void:
	var forge_run_id := str(payload.get("forge_run_id", "")).strip_edges()
	var skill_name := str(payload.get("skill_name", "")).strip_edges()
	if forge_run_id == "" and skill_name == "":
		return
	game_ui.set_skill_forge_work_receipt_trace(payload, receipt)


func _maybe_update_skill_forge_work_order_trace(order: Dictionary, trace_status: String) -> void:
	var forge_run_id := str(order.get("forge_run_id", "")).strip_edges()
	var skill_name := str(order.get("skill_name", order.get("preference_label", ""))).strip_edges()
	if str(order.get("source", "")).strip_edges() != "skill_forge" and forge_run_id == "" and skill_name == "":
		return
	game_ui.set_skill_forge_work_order_trace(order, trace_status)


func _on_crafting_demand_target_requested(demand_id: String) -> void:
	if not crafting_demands.has(demand_id):
		game_ui.show_message("Unknown crew demand.")
		sound_manager.play_stamp("error_soft")
		return

	var demand: Dictionary = crafting_demands[demand_id]
	if not _demand_has_target(demand):
		game_ui.show_message("That demand has no field target.")
		sound_manager.play_stamp("error_soft")
		return

	var target_tile: Vector2i = demand.get("target_tile", Vector2i(-1, -1))
	var tile = grid_manager.get_tile(target_tile)
	if tile == null:
		game_ui.show_message("Demand target is no longer on the farm.")
		sound_manager.play_stamp("error_soft")
		return

	if camera_controller != null and camera_controller.has_method("focus_world_position"):
		camera_controller.call("focus_world_position", tile.global_position, 6.8)
	if tile.has_method("pulse_demand_marker"):
		tile.call("pulse_demand_marker")
	var authored_order_id := str(demand.get("authored_order_id", ""))
	if authored_order_id != "" and work_orders.has(authored_order_id) and tile.has_method("pulse_order_marker"):
		tile.call("pulse_order_marker")
	game_ui.show_message("%s wants %s." % [str(demand.get("agent_name", "Crew")), str(demand.get("label", "that target"))])
	sound_manager.play_stamp("ui_click")


func _on_adversarial_encounter_requested(agent_id: String = "") -> void:
	if _agent_manager == null or _adversarial_session == null:
		return

	if bool(_adversarial_session.call("has_active_session")):
		game_ui.set_adversarial_session(_adversarial_session.call("get_session_snapshot"))
		sound_manager.play_stamp("ui_click")
		return

	var target_agent_id := agent_id
	if target_agent_id == "" and _queued_grievance_agent_id != "":
		target_agent_id = _queued_grievance_agent_id

	var agent_snapshot := _select_adversarial_agent(target_agent_id)
	if agent_snapshot.is_empty():
		game_ui.show_message("No crew member is available for a grievance.")
		sound_manager.play_stamp("error_soft")
		return

	var session: Dictionary = _adversarial_session.call("start_session", agent_snapshot, _build_adversarial_context(agent_snapshot))
	_clear_adversarial_grievance()
	game_ui.set_adversarial_session(session)
	game_ui.add_field_log("%s raised a grievance." % str(session.get("agent_name", "Crew")))
	sound_manager.play_stamp("ui_click")


func _on_adversarial_response_selected(choice_id: String) -> void:
	if _adversarial_session == null or not bool(_adversarial_session.call("has_active_session")):
		return

	var update: Dictionary = _adversarial_session.call("choose_response", choice_id)
	if update.is_empty():
		return

	var npc_line := str(update.get("npc_line", ""))
	if npc_line != "":
		game_ui.add_field_log(npc_line)
	game_ui.set_adversarial_session(update)
	sound_manager.play_stamp("ui_click")

	if not bool(update.get("active", false)):
		_apply_adversarial_result(update)


func _select_adversarial_agent(agent_id: String = "") -> Dictionary:
	if _agent_manager == null:
		return {}

	var snapshots: Array = _agent_manager.call("get_agent_snapshots")
	var selected: Dictionary = {}
	var highest_irritation := -1.0
	for snapshot in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		if agent_id != "" and str(snapshot.get("id", "")) == agent_id:
			return snapshot.duplicate(true)
		if agent_id == "":
			var irritation := float(snapshot.get("irritation", 0.0))
			if selected.is_empty() or irritation > highest_irritation:
				selected = snapshot.duplicate(true)
				highest_irritation = irritation
	return selected


func _build_adversarial_context(agent_snapshot: Dictionary = {}) -> Dictionary:
	var recent_events: Array = _event_log.call("get_recent_events", 16) if _event_log else []
	var failed_actions: Dictionary = {}
	var recent_failures := 0
	for event in recent_events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "player_action" or bool(event.get("success", true)):
			continue
		recent_failures += 1
		var action := str(event.get("action", "work"))
		failed_actions[action] = int(failed_actions.get(action, 0)) + 1

	var top_failed_action := "farm_work"
	var top_failed_count := 0
	for action in failed_actions.keys():
		var count := int(failed_actions[action])
		if count > top_failed_count:
			top_failed_action = str(action)
			top_failed_count = count

	var demand_hint := "preference_run" if _agent_snapshot_prefers_mission(agent_snapshot) else "deliver_agent_supply"
	var context := {
		"day": grid_manager.day,
		"recent_events": recent_events,
		"recent_failures": recent_failures,
		"top_failed_action": top_failed_action,
		"open_work_orders": work_order_ids.size(),
		"money": money,
		"resources": resources.duplicate(true),
		"crafted_items": crafted_items.duplicate(true),
		"demand_history": _crafting_demand_history_for_context(),
		"demand_hint": demand_hint
	}
	if demand_hint == "preference_run":
		context["mission_hint"] = "preference_run"
	return context.merged(_queued_grievance_context, true)


func _agent_snapshot_prefers_mission(agent_snapshot: Dictionary) -> bool:
	if agent_snapshot.is_empty():
		return false
	if int(agent_snapshot.get("memory_consequence_days", 0)) <= 0:
		return false
	return str(agent_snapshot.get("memory_consequence_source", "")).strip_edges() != "" and str(agent_snapshot.get("memory_consequence_label", "")).strip_edges() != ""


func _crafting_demand_history_for_context(limit: int = 8) -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	for index in range(crafting_demand_ids.size() - 1, -1, -1):
		var demand_id := str(crafting_demand_ids[index])
		if not crafting_demands.has(demand_id):
			continue
		var demand: Dictionary = crafting_demands[demand_id]
		history.append({
			"id": demand_id,
			"agent_id": str(demand.get("agent_id", "")),
			"agent_name": str(demand.get("agent_name", "")),
			"kind": str(demand.get("kind", "")),
			"required_item": str(demand.get("required_item", "")),
			"required_action": str(demand.get("required_action", "")),
			"label": str(demand.get("label", "")),
			"status": str(demand.get("status", "")),
			"created_day": int(demand.get("created_day", grid_manager.day)),
			"completed_day": int(demand.get("completed_day", demand.get("created_day", grid_manager.day))),
			"preference_source": str(demand.get("preference_source", "")),
			"preference_label": str(demand.get("preference_label", ""))
		})
		if history.size() >= limit:
			break
	return history


func _apply_adversarial_result(result: Dictionary) -> void:
	var payload := result.duplicate(true)
	payload["day"] = grid_manager.day
	if _event_log:
		_event_log.record_event("adversarial_session", payload)

	if _agent_manager:
		_agent_manager.call("apply_adversarial_result", payload)

	var money_delta := int(payload.get("money_delta", 0))
	if money_delta != 0:
		money = maxi(0, money + money_delta)
		game_ui.set_money(money)

	var resource_delta: Dictionary = payload.get("resource_delta", {})
	var accepted_resources := _add_resources(resource_delta)
	if not accepted_resources.is_empty():
		game_ui.add_field_log("Parley bonus: +%s." % _format_resource_list(accepted_resources))

	var crew_boost_seconds := float(payload.get("crew_boost_seconds", 0.0))
	if crew_boost_seconds > 0.0 and _agent_manager:
		_agent_manager.call("apply_crew_boost", crew_boost_seconds, 1.30)
		game_ui.add_field_log("Crew focus sharpened for the next few jobs.")

	var tax_orders := int(payload.get("patience_tax_orders", 0))
	if tax_orders > 0:
		_patience_tax_orders += tax_orders
		game_ui.add_field_log("Crew patience tax armed for the next order.")

	var crew_mission: Dictionary = payload.get("crew_mission", {})
	if not crew_mission.is_empty():
		_create_crew_mission(crew_mission, payload)

	var crafting_demand: Dictionary = payload.get("crafting_demand", {})
	if not crafting_demand.is_empty():
		_create_crafting_demand(crafting_demand, payload)

	var remembered_help_label := str(payload.get("remembered_help_label", "")).strip_edges()
	if remembered_help_label != "":
		game_ui.add_field_log("Memory discussed: %s remembered %s." % [str(payload.get("agent_name", "Crew")), remembered_help_label])

	var verdict := str(payload.get("verdict", "The encounter ended."))
	game_ui.add_field_log(verdict)
	game_ui.show_message(_format_adversarial_result(payload))
	if money_delta < 0:
		sound_manager.play_stamp("error_soft")
	elif money_delta > 0:
		sound_manager.play_stamp("coin_burst")


func _maybe_queue_failure_grievance(event: Dictionary) -> void:
	if bool(event.get("success", true)):
		return
	if _adversarial_session and bool(_adversarial_session.call("has_active_session")):
		return
	if _queued_grievance_agent_id != "":
		return

	var recent_failures := _count_recent_failed_player_actions(8)
	if recent_failures < 3:
		return
	if grid_manager.day == _last_failure_grievance_day and recent_failures < _last_failure_grievance_count + 3:
		return

	var agent_snapshot := _select_adversarial_agent("")
	if agent_snapshot.is_empty():
		return

	_last_failure_grievance_day = grid_manager.day
	_last_failure_grievance_count = recent_failures
	_queue_adversarial_grievance(
		str(agent_snapshot.get("id", "")),
		"%s noticed %s failed field calls." % [str(agent_snapshot.get("name", "Crew")), recent_failures],
		{
			"grievance_text": "Three field misses in quick succession made the crew put down the tools and stare.",
			"npc_goal": "make the player admit the mess and choose one cleaner next step",
			"recent_failures": recent_failures,
			"top_failed_action": str(event.get("action", "work"))
		}
	)


func _maybe_queue_day_grievance(summary: Dictionary) -> void:
	if _queued_grievance_agent_id != "":
		return
	if _adversarial_session and bool(_adversarial_session.call("has_active_session")):
		return

	var vibe: Dictionary = summary.get("vibe", {})
	var vibe_label := str(vibe.get("label", "mixed"))
	var failed := int(summary.get("failed_player_actions", 0))
	if vibe_label != "chaotic" and failed < 3:
		return

	var agent_snapshot := _select_adversarial_agent("")
	if agent_snapshot.is_empty():
		return

	_queue_adversarial_grievance(
		str(agent_snapshot.get("id", "")),
		"%s wants a post-day Parley about the %s vibe." % [str(agent_snapshot.get("name", "Crew")), vibe_label],
		{
			"grievance_text": "The day ended with a %s vibe, and the crew wants that explained before tomorrow gets ideas." % vibe_label,
			"npc_goal": "turn the day summary into one practical commitment",
			"recent_failures": failed,
			"top_failed_action": str(summary.get("top_action", "work")),
			"grievance_day": int(summary.get("day", grid_manager.day))
		}
	)


func _queue_adversarial_grievance(agent_id: String, reason: String, context: Dictionary = {}) -> void:
	if agent_id == "":
		return

	_queued_grievance_agent_id = agent_id
	_queued_grievance_context = context.duplicate(true)
	game_ui.set_adversarial_prompt(true, reason)
	game_ui.add_field_log(reason)
	sound_manager.play_stamp("error_soft")


func _clear_adversarial_grievance() -> void:
	_queued_grievance_agent_id = ""
	_queued_grievance_context = {}
	game_ui.set_adversarial_prompt(false)


func _count_recent_failed_player_actions(limit: int = 8) -> int:
	if _event_log == null:
		return 0

	var recent_events: Array = _event_log.call("get_recent_events", limit)
	var count := 0
	for recent_event in recent_events:
		if typeof(recent_event) != TYPE_DICTIONARY:
			continue
		if int(recent_event.get("day", grid_manager.day)) != grid_manager.day:
			continue
		if str(recent_event.get("type", "")) == "player_action" and not bool(recent_event.get("success", true)):
			count += 1
	return count


func _apply_patience_tax(order: Dictionary) -> bool:
	if _patience_tax_orders <= 0:
		return true

	var tax := 2
	if money < tax:
		game_ui.show_message("Crew patience tax needs %s coins first." % tax)
		sound_manager.play_stamp("error_soft")
		return false

	_patience_tax_orders -= 1
	money -= tax
	game_ui.set_money(money)
	game_ui.add_field_log("Paid %s coins in crew patience tax for %s." % [tax, str(order.get("label", "the order"))])
	if _event_log:
		_event_log.record_event("work_order", {
			"day": grid_manager.day,
			"order_id": str(order.get("id", "")),
			"label": str(order.get("label", "")),
			"status": "patience_tax",
			"tax": tax,
			"target_tile": order.get("target_tile", Vector2i.ZERO)
		})
	return true


func _age_open_crafting_demands() -> void:
	for demand_id in crafting_demand_ids:
		var demand: Dictionary = crafting_demands.get(demand_id, {})
		if str(demand.get("status", "")) != "open":
			continue
		demand["age_days"] = int(demand.get("age_days", 0)) + 1
		demand["status_text"] = _demand_status_text(demand)
		crafting_demands[demand_id] = demand
		var authored_order_id := _maybe_author_work_order_for_demand(demand_id)
		_record_crafting_demand_event(demand_id, "aged")
		game_ui.add_field_log("%s is still open. %s noticed." % [str(demand.get("label", "Crew demand")), str(demand.get("agent_name", "Crew"))])
		if authored_order_id != "":
			var authored_order: Dictionary = work_orders.get(authored_order_id, {})
			var authored_label := _work_order_label(str(authored_order.get("action", "")), authored_order.get("target_tile", Vector2i.ZERO))
			game_ui.add_field_log("%s drafted a crew order for %s." % [str(demand.get("agent_name", "Crew")), authored_label])
		if _agent_manager:
			var agent_id := str(demand.get("agent_id", ""))
			if bool(_agent_manager.call("has_active_truce", agent_id)):
				game_ui.add_field_log("%s's truce kept the pressure low." % str(demand.get("agent_name", "Crew")))
			else:
				_agent_manager.call("apply_adversarial_result", {
					"agent_id": agent_id,
					"outcome": "walked_away",
					"agent_mood_delta": -1.0,
					"agent_irritation_delta": 5.0
				})
	_refresh_crafting_demands()
	_refresh_crew_missions()


func _create_crafting_demand(template: Dictionary, source_event: Dictionary) -> String:
	var demand_kind := str(template.get("kind", "deliver_item"))
	var required_item := str(template.get("required_item", ""))
	var required_action := str(template.get("required_action", ""))
	if required_item == "" and required_action == "":
		return ""

	var demand_id := "demand_%03d" % _next_crafting_demand_number
	_next_crafting_demand_number += 1
	var demand := template.duplicate(true)
	demand["id"] = demand_id
	demand["status"] = "open"
	demand["kind"] = demand_kind
	demand["agent_id"] = str(source_event.get("agent_id", ""))
	demand["agent_name"] = str(source_event.get("agent_name", "Crew"))
	demand["created_day"] = grid_manager.day
	demand["age_days"] = 0
	demand["required_item"] = required_item
	demand["required_action"] = required_action
	demand["amount"] = maxi(1, int(demand.get("amount", 1)))
	demand["label"] = str(demand.get("label", _default_demand_label(demand)))
	_assign_demand_target(demand)
	demand["status_text"] = _demand_status_text(demand)
	demand["reward_text"] = _demand_reward_text(demand)
	var perk := _perk_for_demand(demand)
	demand["perk_id"] = str(perk.get("id", ""))
	demand["perk_label"] = str(perk.get("label", ""))
	demand["perk"] = perk

	crafting_demands[demand_id] = demand
	crafting_demand_ids.append(demand_id)
	_refresh_crafting_demands()
	game_ui.add_field_log("%s requested: %s." % [str(demand.get("agent_name", "Crew")), str(demand.get("label", "Crafting demand"))])
	_record_crafting_demand_event(demand_id, "open")
	return demand_id


func _create_crew_mission(template: Dictionary, source_event: Dictionary) -> String:
	var steps: Array = template.get("steps", [])
	if steps.size() <= 1:
		return ""

	var mission_id := "mission_%03d" % _next_crew_mission_number
	_next_crew_mission_number += 1
	var mission := template.duplicate(true)
	mission["id"] = mission_id
	mission["status"] = "active"
	mission["agent_id"] = str(source_event.get("agent_id", ""))
	mission["agent_name"] = str(source_event.get("agent_name", "Crew"))
	mission["created_day"] = grid_manager.day
	mission["current_step_index"] = 0
	mission["completed_steps"] = 0
	mission["total_steps"] = steps.size()
	mission["label"] = str(mission.get("label", "Crew Mission"))
	mission["status_text"] = "Step 1/%s" % steps.size()
	mission["current_demand_id"] = ""

	crew_missions[mission_id] = mission
	crew_mission_ids.append(mission_id)
	_record_crew_mission_event(mission_id, "started")
	game_ui.add_field_log("%s started mission: %s." % [str(mission.get("agent_name", "Crew")), str(mission.get("label", "Crew Mission"))])
	_start_next_crew_mission_step(mission_id)
	_refresh_crew_missions()
	return mission_id


func _start_next_crew_mission_step(mission_id: String) -> String:
	if not crew_missions.has(mission_id):
		return ""

	var mission: Dictionary = crew_missions[mission_id]
	if str(mission.get("status", "")) != "active":
		return ""

	var steps: Array = mission.get("steps", [])
	var step_index := int(mission.get("current_step_index", 0))
	if step_index < 0 or step_index >= steps.size():
		return ""

	var step: Dictionary = steps[step_index].duplicate(true)
	step["mission_id"] = mission_id
	step["mission_label"] = str(mission.get("label", "Crew Mission"))
	step["mission_step_index"] = step_index
	step["mission_total_steps"] = steps.size()
	step["mission_step_label"] = str(step.get("label", "Step %s" % (step_index + 1)))
	var mission_preference_source := str(mission.get("preference_source", "")).strip_edges()
	var mission_preference_label := str(mission.get("preference_label", "")).strip_edges()
	if mission_preference_source != "" and str(step.get("preference_source", "")).strip_edges() == "":
		step["preference_source"] = mission_preference_source
	if mission_preference_label != "" and str(step.get("preference_label", "")).strip_edges() == "":
		step["preference_label"] = mission_preference_label

	var demand_id := _create_crafting_demand(step, {
		"agent_id": str(mission.get("agent_id", "")),
		"agent_name": str(mission.get("agent_name", "Crew"))
	})
	if demand_id == "":
		return ""

	mission["current_demand_id"] = demand_id
	mission["status_text"] = "Step %s/%s" % [step_index + 1, steps.size()]
	crew_missions[mission_id] = mission
	return demand_id


func _satisfy_open_crafting_demands(item_id: String, source: String) -> void:
	if source != "player":
		return

	for demand_id in crafting_demand_ids:
		var demand: Dictionary = crafting_demands.get(demand_id, {})
		if str(demand.get("status", "")) != "open":
			continue
		if str(demand.get("kind", "deliver_item")) != "deliver_item":
			continue
		if str(demand.get("required_item", "")) != item_id:
			continue

		var amount := maxi(1, int(demand.get("amount", 1)))
		if _available_crafted_item(item_id) < amount:
			continue

		_consume_crafted_cost({item_id: amount})
		_complete_crafting_demand(demand_id, "%s delivered to %s." % [_pretty_crafted_name(item_id), str(demand.get("agent_name", "Crew"))])
		return


func _satisfy_open_action_demands(event: Dictionary) -> void:
	if not bool(event.get("success", false)):
		return

	for demand_id in crafting_demand_ids:
		var demand: Dictionary = crafting_demands.get(demand_id, {})
		if str(demand.get("status", "")) != "open":
			continue
		if not _event_satisfies_demand(event, demand):
			continue
		_complete_crafting_demand(demand_id, "%s completed for %s." % [str(demand.get("label", "Demand")), str(demand.get("agent_name", "Crew"))])
		return


func _event_satisfies_demand(event: Dictionary, demand: Dictionary) -> bool:
	var demand_kind := str(demand.get("kind", ""))
	var action := str(event.get("action", ""))
	if _demand_has_target(demand):
		if not event.has("grid_pos") or event.get("grid_pos", Vector2i(-1, -1)) != demand.get("target_tile", Vector2i(-1, -1)):
			return false
	match demand_kind:
		"clear_brush":
			if action == "clear_brush":
				return true
			return action == "sickle" and int(event.get("resources", {}).get("fiber", 0)) > 0
		"harvest_crop":
			if action == "harvest_crop" or action == "harvest":
				return true
			return action == "sickle" and int(event.get("value", 0)) > 0
		"build_fence":
			if action == "build_fence_order":
				return true
			return action == "place" and str(event.get("item_id", "")) == "fence"
	return false


func _assign_demand_target(demand: Dictionary) -> void:
	if not _demand_needs_target(demand):
		return

	var target_tile := _demand_target_from_value(demand.get("target_tile", Vector2i(-1, -1)))
	if target_tile == Vector2i(-1, -1) or not _is_valid_demand_target(str(demand.get("kind", "")), target_tile):
		target_tile = _find_demand_target_tile(demand)
	if target_tile == Vector2i(-1, -1):
		return

	demand["target_tile"] = target_tile
	demand["label"] = _demand_label_with_target(str(demand.get("label", _default_demand_label(demand))), target_tile)


func _demand_needs_target(demand: Dictionary) -> bool:
	return str(demand.get("kind", "")) in ["clear_brush", "harvest_crop", "build_fence"]


func _demand_has_target(demand: Dictionary) -> bool:
	return typeof(demand.get("target_tile", null)) == TYPE_VECTOR2I


func _demand_target_from_value(value) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(int(value.x), int(value.y))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _find_demand_target_tile(demand: Dictionary) -> Vector2i:
	var demand_kind := str(demand.get("kind", ""))
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var grid_pos := Vector2i(x, z)
			if _is_valid_demand_target(demand_kind, grid_pos):
				return grid_pos
	return Vector2i(-1, -1)


func _is_valid_demand_target(demand_kind: String, grid_pos: Vector2i) -> bool:
	match demand_kind:
		"clear_brush":
			return _can_target_crew_order("clear_brush", grid_pos)
		"harvest_crop":
			return _can_target_crew_order("harvest_crop", grid_pos)
		"build_fence":
			return _can_target_crew_order("build_fence", grid_pos)
	return false


func _demand_label_with_target(label: String, target_tile: Vector2i) -> String:
	var suffix := "%s,%s" % [target_tile.x, target_tile.y]
	if label.ends_with(suffix) or label.contains(" %s" % suffix):
		return label
	return "%s %s" % [label, suffix]


func _maybe_author_work_order_for_demand(demand_id: String) -> String:
	if not crafting_demands.has(demand_id):
		return ""

	var demand: Dictionary = crafting_demands[demand_id]
	if str(demand.get("status", "")) != "open" or not _demand_has_target(demand):
		return ""

	var existing_order_id := str(demand.get("authored_order_id", ""))
	if existing_order_id != "" and work_orders.has(existing_order_id):
		return ""
	if existing_order_id != "":
		demand.erase("authored_order_id")

	var action_id := _work_order_action_for_demand(demand)
	if action_id == "":
		crafting_demands[demand_id] = demand
		return ""

	var target_tile: Vector2i = demand.get("target_tile", Vector2i(-1, -1))
	if not _can_target_crew_order(action_id, target_tile):
		crafting_demands[demand_id] = demand
		return ""

	var order_id := _create_npc_authored_work_order(action_id, target_tile, demand_id, demand)
	if order_id == "":
		crafting_demands[demand_id] = demand
		return ""

	demand["authored_order_id"] = order_id
	demand["status_text"] = _demand_status_text(demand)
	crafting_demands[demand_id] = demand
	_record_crafting_demand_event(demand_id, "authored_order")
	return order_id


func _work_order_action_for_demand(demand: Dictionary) -> String:
	match str(demand.get("kind", "")):
		"clear_brush":
			return "clear_brush"
		"harvest_crop":
			return "harvest_crop"
		"build_fence":
			return "build_fence"
	return ""


func _complete_crafting_demand(demand_id: String, message: String) -> void:
	if not crafting_demands.has(demand_id):
		return

	var demand: Dictionary = crafting_demands[demand_id]
	demand["status"] = "done"
	demand["status_text"] = "Delivered"
	demand["completed_day"] = grid_manager.day
	crafting_demands[demand_id] = demand
	_refresh_crafting_demands()
	_record_crafting_demand_event(demand_id, "done")
	game_ui.add_field_log(message)
	_apply_demand_completion_effects(demand)
	_advance_crew_mission_from_demand(demand)


func _apply_demand_completion_effects(demand: Dictionary) -> void:
	if _agent_manager:
		_agent_manager.call("apply_adversarial_result", {
			"agent_id": str(demand.get("agent_id", "")),
			"outcome": "resolved",
			"agent_mood_delta": 3.0,
			"agent_irritation_delta": -12.0
		})

	var perk: Dictionary = demand.get("perk", {})
	var resource_delta: Dictionary = perk.get("resource_delta", {})
	var accepted := _add_resources(resource_delta)
	if not accepted.is_empty():
		game_ui.add_field_log("%s: +%s." % [str(perk.get("label", "Crew perk")), _format_resource_list(accepted)])

	var boost_seconds := float(perk.get("crew_boost_seconds", 0.0))
	if boost_seconds > 0.0 and _agent_manager:
		_agent_manager.call("apply_crew_boost", boost_seconds, float(perk.get("speed_multiplier", 1.16)))
		game_ui.add_field_log(str(perk.get("label", "Crew focus improved.")))

	if str(demand.get("agent_id", "")) == "marigold" and str(demand.get("required_item", "")) == "seed_bundle":
		_activate_spring_hands(demand)
	elif str(demand.get("agent_id", "")) == "bert" and str(demand.get("required_item", "")) == "fence_kit":
		_activate_fence_hands(demand)
	elif str(demand.get("agent_id", "")) == "chuck" and str(demand.get("required_item", "")) == "rush_kit":
		_activate_hustle_hands(demand)
	_acknowledge_completed_demand(demand)


func _advance_crew_mission_from_demand(demand: Dictionary) -> void:
	var mission_id := str(demand.get("mission_id", ""))
	if mission_id == "" or not crew_missions.has(mission_id):
		return

	var mission: Dictionary = crew_missions[mission_id]
	if str(mission.get("status", "")) != "active":
		return

	var step_index := int(demand.get("mission_step_index", -1))
	if step_index < 0:
		return

	var completed_steps := int(mission.get("completed_steps", 0))
	if completed_steps > step_index:
		return

	var next_step_index := step_index + 1
	mission["completed_steps"] = next_step_index
	mission["current_step_index"] = next_step_index
	mission["current_demand_id"] = ""
	mission["status_text"] = "Step %s/%s complete" % [next_step_index, int(mission.get("total_steps", 0))]
	crew_missions[mission_id] = mission
	_record_crew_mission_event(mission_id, "step_done", demand)

	if next_step_index >= int(mission.get("total_steps", 0)):
		_complete_crew_mission(mission_id)
		return

	game_ui.add_field_log("%s advanced: %s step %s/%s." % [
		str(mission.get("agent_name", "Crew")),
		str(mission.get("label", "Crew Mission")),
		next_step_index + 1,
		int(mission.get("total_steps", 0))
	])
	_start_next_crew_mission_step(mission_id)
	_refresh_crew_missions()


func _complete_crew_mission(mission_id: String) -> void:
	if not crew_missions.has(mission_id):
		return

	var mission: Dictionary = crew_missions[mission_id]
	mission["status"] = "done"
	mission["completed_day"] = grid_manager.day
	mission["status_text"] = "Done"
	crew_missions[mission_id] = mission

	if _agent_manager:
		_agent_manager.call("apply_adversarial_result", {
			"agent_id": str(mission.get("agent_id", "")),
			"outcome": "resolved",
			"agent_mood_delta": 2.0,
			"agent_irritation_delta": -4.0
		})
		_agent_manager.call(
			"acknowledge_completed_mission",
			str(mission.get("agent_id", "")),
			str(mission.get("label", "Crew Mission")),
			str(mission.get("preference_source", "")),
			str(mission.get("preference_label", ""))
		)

	var resource_delta: Dictionary = mission.get("completion_resource_delta", {})
	var accepted := _add_resources(resource_delta)
	if not accepted.is_empty():
		game_ui.add_field_log("%s complete: +%s." % [str(mission.get("label", "Crew Mission")), _format_resource_list(accepted)])

	game_ui.add_field_log("%s completed mission: %s%s." % [
		str(mission.get("agent_name", "Crew")),
		str(mission.get("label", "Crew Mission")),
		_format_mission_preference_suffix(mission)
	])
	_record_crew_mission_event(mission_id, "done")
	_refresh_crew_missions()


func _acknowledge_completed_demand(demand: Dictionary) -> void:
	var agent_id := str(demand.get("agent_id", ""))
	var agent_name := str(demand.get("agent_name", "Crew"))
	var is_supply_delivery := str(demand.get("kind", "")) == "deliver_item"
	var item_label := _demand_social_credit_label(demand)
	var payoff_label := str(demand.get("reward_text", ""))
	if payoff_label == "":
		payoff_label = _demand_reward_text(demand)
	if is_supply_delivery:
		var payoff_text := " %s ready." % payoff_label if payoff_label != "" else ""
		game_ui.add_field_log("%s accepted %s.%s" % [agent_name, item_label, payoff_text])
	else:
		game_ui.add_field_log("%s noticed %s completed." % [agent_name, item_label])
	if _agent_manager:
		_agent_manager.call("acknowledge_supply_delivery", agent_id, item_label, payoff_label)


func _demand_social_credit_label(demand: Dictionary) -> String:
	if str(demand.get("kind", "")) == "deliver_item":
		return _pretty_crafted_name(str(demand.get("required_item", "")))
	return _default_demand_label(demand)


func _activate_spring_hands(demand: Dictionary) -> void:
	_spring_hands_timer = maxf(_spring_hands_timer, SPRING_HANDS_SECONDS)
	_spring_hands_charges += 1
	_refresh_crew_status()
	game_ui.add_field_log("Spring Hands active: Marigold will seed one prepared tile.")
	if _event_log:
		_event_log.record_event("farm_perk", {
			"day": grid_manager.day,
			"perk_id": "spring_hands",
			"status": "applied",
			"agent_id": str(demand.get("agent_id", "")),
			"agent_name": str(demand.get("agent_name", "")),
			"source_demand_id": str(demand.get("id", "")),
			"charges": _spring_hands_charges,
			"duration_seconds": SPRING_HANDS_SECONDS
		})
	_try_use_spring_hands()


func _activate_fence_hands(demand: Dictionary) -> void:
	_fence_hands_timer = maxf(_fence_hands_timer, FENCE_HANDS_SECONDS)
	_fence_hands_charges += 1
	_refresh_crew_status()
	game_ui.add_field_log("Fence Hands active: Bert will set one practical fence.")
	if _event_log:
		_event_log.record_event("farm_perk", {
			"day": grid_manager.day,
			"perk_id": "fence_hands",
			"status": "applied",
			"agent_id": str(demand.get("agent_id", "")),
			"agent_name": str(demand.get("agent_name", "")),
			"source_demand_id": str(demand.get("id", "")),
			"charges": _fence_hands_charges,
			"duration_seconds": FENCE_HANDS_SECONDS
		})
	_try_use_fence_hands()


func _activate_hustle_hands(demand: Dictionary) -> void:
	_hustle_hands_timer = maxf(_hustle_hands_timer, HUSTLE_HANDS_SECONDS)
	_hustle_hands_charges += 1
	_refresh_crew_status()
	game_ui.add_field_log("Hustle Hands active: Chuck will clear one obstacle.")
	if _event_log:
		_event_log.record_event("farm_perk", {
			"day": grid_manager.day,
			"perk_id": "hustle_hands",
			"status": "applied",
			"agent_id": str(demand.get("agent_id", "")),
			"agent_name": str(demand.get("agent_name", "")),
			"source_demand_id": str(demand.get("id", "")),
			"charges": _hustle_hands_charges,
			"duration_seconds": HUSTLE_HANDS_SECONDS
		})
	_try_use_hustle_hands()


func _update_spring_hands(delta: float) -> void:
	if _spring_hands_timer <= 0.0:
		return

	_spring_hands_timer = maxf(0.0, _spring_hands_timer - delta)
	if _spring_hands_charges > 0:
		_try_use_spring_hands()
	_refresh_crew_status()


func _update_fence_hands(delta: float) -> void:
	if _fence_hands_timer <= 0.0:
		return

	_fence_hands_timer = maxf(0.0, _fence_hands_timer - delta)
	if _fence_hands_charges > 0:
		_try_use_fence_hands()
	_refresh_crew_status()


func _update_hustle_hands(delta: float) -> void:
	if _hustle_hands_timer <= 0.0:
		return

	_hustle_hands_timer = maxf(0.0, _hustle_hands_timer - delta)
	if _hustle_hands_charges > 0:
		_try_use_hustle_hands()
	_refresh_crew_status()


func _try_use_spring_hands() -> bool:
	if _spring_hands_timer <= 0.0 or _spring_hands_charges <= 0 or grid_manager == null:
		return false

	var target_tile = _find_spring_hands_seed_tile()
	if target_tile != null and target_tile.plant_wheat():
		_spring_hands_charges -= 1
		_record_spring_hands_use(target_tile.grid_pos, "plant_wheat")
		game_ui.add_field_log("Spring Hands planted wheat at (%s,%s)." % [target_tile.grid_pos.x, target_tile.grid_pos.y])
		sound_manager.play_stamp("plant_pop")
		return true

	target_tile = _find_spring_hands_growth_tile()
	if target_tile != null and target_tile.grow_crop():
		_spring_hands_charges -= 1
		_record_spring_hands_use(target_tile.grid_pos, "grow_crop")
		game_ui.add_field_log("Spring Hands nudged a crop at (%s,%s)." % [target_tile.grid_pos.x, target_tile.grid_pos.y])
		sound_manager.play_stamp("plant_pop")
		return true

	return false


func _try_use_fence_hands() -> bool:
	if _fence_hands_timer <= 0.0 or _fence_hands_charges <= 0 or grid_manager == null:
		return false

	var target_tile = _find_fence_hands_tile()
	if target_tile == null or _is_agent_tile_occupied(target_tile.grid_pos) or not target_tile.place_item("fence"):
		return false

	_fence_hands_charges -= 1
	_record_fence_hands_use(target_tile.grid_pos)
	game_ui.add_field_log("Fence Hands placed fence at (%s,%s)." % [target_tile.grid_pos.x, target_tile.grid_pos.y])
	sound_manager.play_stamp("place_soft")
	sound_manager.play_stamp("plant_pop")
	return true


func _try_use_hustle_hands() -> bool:
	if _hustle_hands_timer <= 0.0 or _hustle_hands_charges <= 0 or grid_manager == null:
		return false

	var target_tile = _find_hustle_hands_tile()
	if target_tile == null:
		return false

	var effect := "clear_brush"
	var success := false
	match str(target_tile.decor_id):
		"rock":
			effect = "clear_rock"
			success = target_tile.break_with_pickaxe()
		"tall_grass", "flower_patch":
			success = target_tile.cut_with_sickle() != 0
	if not success:
		return false

	_hustle_hands_charges -= 1
	_record_hustle_hands_use(target_tile.grid_pos, effect)
	var subject := "rock" if effect == "clear_rock" else "brush"
	game_ui.add_field_log("Hustle Hands cleared %s at (%s,%s)." % [subject, target_tile.grid_pos.x, target_tile.grid_pos.y])
	sound_manager.play_stamp("plant_pop")
	return true


func _find_spring_hands_seed_tile():
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var tile = grid_manager.get_tile(Vector2i(x, z))
			if tile != null and tile.is_tilled and tile.crop == null and str(tile.structure_id) == "":
				return tile
	return null


func _find_spring_hands_growth_tile():
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var tile = grid_manager.get_tile(Vector2i(x, z))
			if tile != null and tile.crop != null and not tile.crop.is_ready():
				return tile
	return null


func _find_fence_hands_tile():
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var tile = grid_manager.get_tile(Vector2i(x, z))
			if tile == null:
				continue
			if str(tile.terrain) == "dirt_path" or str(tile.decor_id) != "" or str(tile.structure_id) != "" or tile.crop != null:
				continue
			if _is_agent_tile_occupied(tile.grid_pos):
				continue
			if tile.can_apply_item("fence"):
				return tile
	return null


func _find_hustle_hands_tile():
	for x in range(grid_manager.width):
		for z in range(grid_manager.height):
			var tile = grid_manager.get_tile(Vector2i(x, z))
			if tile != null and str(tile.decor_id) in ["rock", "tall_grass", "flower_patch"]:
				return tile
	return null


func _record_spring_hands_use(target_tile: Vector2i, effect: String) -> void:
	_refresh_crew_status()
	if _event_log:
		_event_log.record_event("farm_perk", {
			"day": grid_manager.day,
			"perk_id": "spring_hands",
			"status": "used",
			"effect": effect,
			"target_tile": target_tile,
			"charges_remaining": _spring_hands_charges
		})


func _record_fence_hands_use(target_tile: Vector2i) -> void:
	_refresh_crew_status()
	if _event_log:
		_event_log.record_event("farm_perk", {
			"day": grid_manager.day,
			"perk_id": "fence_hands",
			"status": "used",
			"effect": "place_fence",
			"target_tile": target_tile,
			"charges_remaining": _fence_hands_charges
		})


func _record_hustle_hands_use(target_tile: Vector2i, effect: String) -> void:
	_refresh_crew_status()
	if _event_log:
		_event_log.record_event("farm_perk", {
			"day": grid_manager.day,
			"perk_id": "hustle_hands",
			"status": "used",
			"effect": effect,
			"target_tile": target_tile,
			"charges_remaining": _hustle_hands_charges
		})


func _refresh_crew_status() -> void:
	if _spring_hands_timer > 0.0:
		game_ui.set_crew_status("Spring Hands %ss" % ceili(_spring_hands_timer), true)
	elif _fence_hands_timer > 0.0:
		game_ui.set_crew_status("Fence Hands %ss" % ceili(_fence_hands_timer), true)
	elif _hustle_hands_timer > 0.0:
		game_ui.set_crew_status("Hustle Hands %ss" % ceili(_hustle_hands_timer), true)
	else:
		game_ui.set_crew_status("watching")


func _record_crafting_demand_event(demand_id: String, status: String) -> void:
	if _event_log == null or not crafting_demands.has(demand_id):
		return

	var demand: Dictionary = crafting_demands[demand_id]
	_event_log.record_event("crafting_demand", {
		"day": grid_manager.day,
		"demand_id": demand_id,
		"label": str(demand.get("label", "")),
		"status": status,
		"agent_id": str(demand.get("agent_id", "")),
		"agent_name": str(demand.get("agent_name", "")),
		"kind": str(demand.get("kind", "")),
		"required_item": str(demand.get("required_item", "")),
		"required_action": str(demand.get("required_action", "")),
		"target_tile": demand.get("target_tile", Vector2i(-1, -1)),
		"authored_order_id": str(demand.get("authored_order_id", "")),
		"amount": int(demand.get("amount", 1)),
		"age_days": int(demand.get("age_days", 0)),
		"preference_source": str(demand.get("preference_source", "")),
		"preference_label": str(demand.get("preference_label", "")),
		"preference_origin_source": str(demand.get("preference_origin_source", "")),
		"preference_origin_label": str(demand.get("preference_origin_label", "")),
		"mission_id": str(demand.get("mission_id", "")),
		"mission_label": str(demand.get("mission_label", "")),
		"mission_step_index": int(demand.get("mission_step_index", -1)),
		"mission_total_steps": int(demand.get("mission_total_steps", 0)),
		"mission_step_label": str(demand.get("mission_step_label", "")),
		"perk_id": str(demand.get("perk_id", "")),
		"perk_label": str(demand.get("perk_label", ""))
	})


func _record_crew_mission_event(mission_id: String, status: String, demand: Dictionary = {}) -> void:
	if _event_log == null or not crew_missions.has(mission_id):
		return

	var mission: Dictionary = crew_missions[mission_id]
	_event_log.record_event("crew_mission", {
		"day": grid_manager.day,
		"mission_id": mission_id,
		"label": str(mission.get("label", "")),
		"status": status,
		"agent_id": str(mission.get("agent_id", "")),
		"agent_name": str(mission.get("agent_name", "")),
		"created_day": int(mission.get("created_day", grid_manager.day)),
		"completed_day": int(mission.get("completed_day", 0)),
		"current_step_index": int(mission.get("current_step_index", 0)),
		"completed_steps": int(mission.get("completed_steps", 0)),
		"total_steps": int(mission.get("total_steps", 0)),
		"current_demand_id": str(mission.get("current_demand_id", "")),
		"preference_source": str(mission.get("preference_source", "")),
		"preference_label": str(mission.get("preference_label", "")),
		"step_demand_id": str(demand.get("id", "")),
		"mission_step_index": int(demand.get("mission_step_index", -1)),
		"completion_resource_delta": mission.get("completion_resource_delta", {})
	})


func _default_demand_label(demand: Dictionary) -> String:
	match str(demand.get("kind", "deliver_item")):
		"clear_brush":
			return "Clear Brush"
		"harvest_crop":
			return "Harvest Crop"
		"build_fence":
			return "Build Fence"
	var required_item := str(demand.get("required_item", ""))
	return "Deliver %s" % _pretty_crafted_name(required_item)


func _demand_status_text(demand: Dictionary) -> String:
	if str(demand.get("status", "")) == "done":
		return "Done"

	var age_days := int(demand.get("age_days", 0))
	var age_prefix := "%sd " % age_days if age_days > 0 else ""
	var authored_order_id := str(demand.get("authored_order_id", ""))
	if authored_order_id != "" and work_orders.has(authored_order_id):
		var linked_order: Dictionary = work_orders[authored_order_id]
		if int(linked_order.get("escalation_count", 0)) > 0:
			var incentive: Dictionary = linked_order.get("incentive_resource_delta", {})
			if not incentive.is_empty() and not bool(linked_order.get("incentive_claimed", false)):
				return "%s+%s" % [age_prefix, _format_resource_list(incentive)]
			return "%sEscalated" % age_prefix
		match str(linked_order.get("status", "ready")):
			"queued", "gathering":
				return "%sSent" % age_prefix
			"waiting":
				return "%sWaiting crew" % age_prefix
			"done":
				return "%sDone" % age_prefix
		return "%sOrder drafted" % age_prefix
	if authored_order_id != "":
		return "%sOrder drafted" % age_prefix
	match str(demand.get("kind", "deliver_item")):
		"deliver_item":
			var required_item := str(demand.get("required_item", ""))
			var amount := maxi(1, int(demand.get("amount", 1)))
			if required_item != "" and _available_crafted_item(required_item) >= amount:
				return "%sReady" % age_prefix
			if required_item != "" and _can_craft_required_item_for_demand(demand):
				return "%sCan craft" % age_prefix
			return "%sNeeds %s" % [age_prefix, _pretty_crafted_name(required_item)]
		"clear_brush":
			return "%sNeeds brush" % age_prefix
		"harvest_crop":
			return "%sNeeds crop" % age_prefix
		"build_fence":
			return "%sNeeds fence" % age_prefix
	return "%sOpen" % age_prefix


func _demand_reward_text(demand: Dictionary) -> String:
	if str(demand.get("kind", "deliver_item")) != "deliver_item":
		return ""

	var agent_id := str(demand.get("agent_id", ""))
	var required_item := str(demand.get("required_item", ""))
	if agent_id == "bert" and required_item == "fence_kit":
		return "Fence Hands"
	if agent_id == "marigold" and required_item == "seed_bundle":
		return "Spring Hands"
	if agent_id == "chuck" and required_item == "rush_kit":
		return "Hustle Hands"
	return ""


func _perk_for_demand(demand: Dictionary) -> Dictionary:
	var agent_id := str(demand.get("agent_id", ""))
	var demand_kind := str(demand.get("kind", "deliver_item"))
	match agent_id:
		"bert":
			return {
				"id": "bert_practical_focus_%s" % demand_kind,
				"label": "Bert's practical focus",
				"crew_boost_seconds": 7.0,
				"speed_multiplier": 1.18
			}
		"marigold":
			return {
				"id": "marigold_goodwill_%s" % demand_kind,
				"label": "Marigold's goodwill",
				"resource_delta": {"grain": 1}
			}
		"chuck":
			return {
				"id": "chuck_hustle_%s" % demand_kind,
				"label": "Chuck's sprint focus",
				"crew_boost_seconds": 6.0,
				"speed_multiplier": 1.24
			}
	return {
		"id": "crew_focus_%s" % demand_kind,
		"label": "Crew focus",
		"crew_boost_seconds": 5.0,
		"speed_multiplier": 1.16
	}


func _on_crew_order_targeted(action_id: String, grid_pos: Vector2i) -> void:
	if _sandbox_action_blocked("marking free-play crew orders"):
		return
	if not WORK_ORDER_ACTIONS.has(action_id):
		game_ui.show_message("Unknown crew order.")
		sound_manager.play_stamp("error_soft")
		return

	if not _can_target_crew_order(action_id, grid_pos):
		game_ui.show_message(_targeting_error_message(action_id))
		sound_manager.play_stamp("error_soft")
		return

	var order_id := _create_user_work_order(action_id, grid_pos)
	if order_id == "":
		return
	_on_work_order_requested(order_id)


func _create_user_work_order(action_id: String, grid_pos: Vector2i) -> String:
	var action: Dictionary = WORK_ORDER_ACTIONS[action_id]
	var order_id := "order_%03d" % _next_work_order_number
	_next_work_order_number += 1

	var order := {
		"id": order_id,
		"label": _work_order_label(action_id, grid_pos),
		"status": "ready",
		"action": action_id,
		"agent_action": str(action.get("agent_action", "")),
		"target_tile": grid_pos,
		"required_item": str(action.get("required_item", "")),
		"created_day": grid_manager.day
	}
	work_orders[order_id] = order
	work_order_ids.append(order_id)
	_refresh_work_orders()
	game_ui.add_field_log("Marked order: %s." % str(order.get("label", "Crew task")))
	_record_work_order_event(order_id, "ready")
	return order_id


func _create_npc_authored_work_order(action_id: String, grid_pos: Vector2i, demand_id: String, demand: Dictionary) -> String:
	if not WORK_ORDER_ACTIONS.has(action_id):
		return ""

	var action: Dictionary = WORK_ORDER_ACTIONS[action_id]
	var order_id := "order_%03d" % _next_work_order_number
	_next_work_order_number += 1
	var author_name := str(demand.get("agent_name", "Crew"))
	var base_label := _work_order_label(action_id, grid_pos)
	var order := {
		"id": order_id,
		"label": "%s: %s" % [author_name, base_label],
		"status": "ready",
		"action": action_id,
		"agent_action": str(action.get("agent_action", "")),
		"target_tile": grid_pos,
		"required_item": str(action.get("required_item", "")),
		"created_day": grid_manager.day,
		"source": "npc_demand",
		"source_demand_id": demand_id,
		"author_agent_id": str(demand.get("agent_id", "")),
		"author_agent_name": author_name
	}
	_add_preference_context_to_order(order, demand)
	_add_mission_context_to_order(order, demand)
	work_orders[order_id] = order
	work_order_ids.append(order_id)
	_refresh_work_orders()
	_record_work_order_event(order_id, "authored")
	return order_id


func _work_order_label(action_id: String, grid_pos: Vector2i) -> String:
	var action: Dictionary = WORK_ORDER_ACTIONS.get(action_id, {})
	return "%s %s,%s" % [str(action.get("label", "Order")), grid_pos.x, grid_pos.y]


func _add_preference_context_to_order(order: Dictionary, demand: Dictionary) -> void:
	var preference_source := str(demand.get("preference_source", "")).strip_edges()
	var preference_label := str(demand.get("preference_label", "")).strip_edges()
	if preference_source == "" or preference_label == "":
		return
	order["preference_source"] = preference_source
	order["preference_label"] = preference_label
	order["social_preference_source"] = _social_preference_source_for_order(preference_source)
	order["social_preference_label"] = preference_label
	var origin_source := str(demand.get("preference_origin_source", "")).strip_edges()
	var origin_label := str(demand.get("preference_origin_label", "")).strip_edges()
	if origin_source != "":
		order["preference_origin_source"] = origin_source
	if origin_label != "":
		order["preference_origin_label"] = origin_label


func _add_mission_context_to_order(order: Dictionary, demand: Dictionary) -> void:
	var mission_id := str(demand.get("mission_id", "")).strip_edges()
	if mission_id == "":
		return
	order["mission_id"] = mission_id
	order["mission_label"] = str(demand.get("mission_label", "Crew Mission"))
	order["mission_step_index"] = int(demand.get("mission_step_index", -1))
	order["mission_total_steps"] = int(demand.get("mission_total_steps", 0))
	order["mission_step_label"] = str(demand.get("mission_step_label", ""))


func _social_preference_source_for_order(preference_source: String) -> String:
	if preference_source == "remembered_help":
		return "memory"
	return preference_source


func _escalate_ignored_npc_authored_orders() -> void:
	for order_id in work_order_ids:
		if not work_orders.has(order_id):
			continue
		var order: Dictionary = work_orders[order_id]
		if str(order.get("source", "")) != "npc_demand":
			continue
		if str(order.get("status", "ready")) != "ready":
			continue
		if int(order.get("created_day", grid_manager.day)) >= grid_manager.day:
			continue
		if int(order.get("escalated_day", 0)) == grid_manager.day:
			continue
		if _delay_escalation_with_truce(order_id):
			continue
		_escalate_npc_authored_order(order_id)


func _delay_escalation_with_truce(order_id: String) -> bool:
	if _agent_manager == null or not work_orders.has(order_id):
		return false

	var order: Dictionary = work_orders[order_id]
	var author_id := str(order.get("author_agent_id", ""))
	if author_id == "":
		return false

	var escalation_label := _work_order_label(str(order.get("action", "")), order.get("target_tile", Vector2i.ZERO))
	var receipt: Dictionary = _agent_manager.call("absorb_order_escalation_with_truce", author_id, escalation_label)
	if receipt.is_empty():
		return false

	order["truce_delayed_day"] = grid_manager.day
	order["truce_label"] = str(receipt.get("truce_label", ""))
	order["last_escalation"] = "truce"
	order["status_text"] = "%s truce" % str(order.get("author_agent_name", "Crew"))
	work_orders[order_id] = order
	_refresh_work_orders()
	_refresh_crafting_demands()
	_record_work_order_event(order_id, "truce_delayed")
	game_ui.add_field_log("%s held truce over %s." % [str(order.get("author_agent_name", "Crew")), escalation_label])
	return true


func _escalate_npc_authored_order(order_id: String) -> bool:
	if not work_orders.has(order_id):
		return false

	var order: Dictionary = work_orders[order_id]
	var author_name := str(order.get("author_agent_name", "Crew"))
	order["escalation_count"] = int(order.get("escalation_count", 0)) + 1
	order["escalated_day"] = grid_manager.day
	order["status_text"] = "%s escalated" % author_name
	order["last_escalation"] = "auto_send" if _can_order_target(order) and _agent_manager != null and bool(_agent_manager.call("has_available_agent")) else "waiting"
	var incentive := _escalation_incentive_for_order(order)
	if not incentive.is_empty():
		order["incentive_label"] = str(incentive.get("label", "Crew bargain"))
		order["incentive_resource_delta"] = incentive.get("resource_delta", {})
	work_orders[order_id] = order
	_refresh_work_orders()
	_refresh_crafting_demands()
	_record_work_order_event(order_id, "escalated")
	var escalation_label := _work_order_label(str(order.get("action", "")), order.get("target_tile", Vector2i.ZERO))
	game_ui.add_field_log("%s escalated %s." % [author_name, escalation_label])
	var incentive_delta: Dictionary = order.get("incentive_resource_delta", {})
	if not incentive_delta.is_empty():
		game_ui.add_field_log("%s offered +%s if it gets done now." % [author_name, _format_resource_list(incentive_delta)])

	if _agent_manager:
		_agent_manager.call("remember_ignored_ask", str(order.get("author_agent_id", "")), escalation_label)
		_agent_manager.call("apply_adversarial_result", {
			"agent_id": str(order.get("author_agent_id", "")),
			"outcome": "walked_away",
			"agent_mood_delta": -0.8,
			"agent_irritation_delta": 4.0
		})

	if str(order.get("last_escalation", "")) != "auto_send":
		return false

	return _queue_escalated_work_order(order_id)


func _escalation_incentive_for_order(order: Dictionary) -> Dictionary:
	match str(order.get("author_agent_id", "")):
		"bert":
			return {
				"label": "Bert's practical bargain",
				"resource_delta": {"grain": 1}
			}
		"marigold":
			return {
				"label": "Marigold's goodwill bargain",
				"resource_delta": {"grain": 1}
			}
		"chuck":
			return {
				"label": "Chuck's hurry-up bargain",
				"resource_delta": {"fiber": 1}
			}
	return {
		"label": "Crew bargain",
		"resource_delta": {"fiber": 1}
	}


func _queue_escalated_work_order(order_id: String) -> bool:
	if not work_orders.has(order_id):
		return false

	var order: Dictionary = work_orders[order_id]
	if not _can_order_target(order):
		order["status_text"] = "Target changed"
		order["last_escalation"] = "blocked"
		work_orders[order_id] = order
		_refresh_work_orders()
		return false

	var action_id := str(order.get("action", "build_fence"))
	if action_id != "build_fence":
		return _queue_directive_order(order_id, true)

	if _has_required_item_for_order(order):
		return _queue_build_order(order_id, true)

	if _can_craft_required_item_for_order(order):
		if _craft_recipe(str(order.get("required_item", "")), "crew_quiet"):
			return _queue_build_order(order_id, true)
		return false

	return _queue_supply_for_order(order_id, true)


func _on_advance_day_requested() -> void:
	if _sandbox_action_blocked("ending the day"):
		return
	sound_manager.play_stamp("day_advance")
	var ending_day: int = grid_manager.day
	if _event_log:
		var summary: Dictionary = _event_log.build_day_summary(ending_day)
		_event_log.record_event("day_summary", {
			"day": ending_day,
			"summary": summary
		})
		game_ui.add_field_log(_format_day_summary(summary))
		_maybe_queue_day_grievance(summary)

	grid_manager.advance_day()
	game_ui.set_day(grid_manager.day)
	if _event_log:
		_event_log.record_event("day_advanced", {
			"day": grid_manager.day,
			"previous_day": ending_day
		})
	_age_open_crafting_demands()
	_escalate_ignored_npc_authored_orders()
	if not _pending_skill_forge_run.is_empty():
		_pending_skill_forge_run["day_advances"] = int(_pending_skill_forge_run.get("day_advances", 0)) + 1
		if int(_pending_skill_forge_run.get("day_advances", 0)) >= 2:
			_cancel_pending_skill_forge_run("order never completed after two day advances", true)
	game_ui.show_message("A warm morning rolls in. Crops advanced one stage.")
	_fire_workbench_day_start()


func _on_harvest_collected(amount: int) -> void:
	money += amount
	game_ui.set_money(money)


func _on_player_action_logged(event: Dictionary) -> void:
	if _event_log == null:
		return

	var payload := event.duplicate(true)
	payload["day"] = grid_manager.day
	if bool(payload.get("success", false)):
		_consume_crafted_cost(payload.get("crafted_cost", {}))
	_add_resources(payload.get("resources", {}))
	_event_log.record_event("player_action", payload)
	game_ui.add_field_log(_format_player_receipt(payload))
	_satisfy_open_action_demands(payload)
	_maybe_queue_failure_grievance(payload)


func _on_agent_world_action(event: Dictionary) -> void:
	var payload := event.duplicate(true)
	payload["day"] = grid_manager.day

	if _event_log:
		_event_log.record_event("agent_world_action", payload)

	var value := int(payload.get("value", 0))
	if value > 0:
		money += value
		game_ui.set_money(money)
	if bool(payload.get("success", false)):
		_consume_crafted_cost(payload.get("crafted_cost", {}))
	_add_resources(payload.get("resources", {}))
	_satisfy_open_action_demands(payload)
	_update_work_order_from_agent_action(payload)
	_continue_resource_orders()

	for stamp in payload.get("stamps", []):
		sound_manager.play_stamp(str(stamp))

	var receipt := _format_agent_receipt(payload)
	if receipt != "":
		game_ui.add_field_log(receipt)
		_maybe_update_skill_forge_receipt_trace(payload, receipt)
		if bool(payload.get("success", false)):
			game_ui.show_message(receipt)
	_finish_pending_skill_forge_run(payload)


func _on_craft_requested(recipe_id: String) -> void:
	if _sandbox_action_blocked("using the Supply Bench"):
		return
	_craft_recipe(recipe_id, "player")


func _on_crafting_demand_requested(demand_id: String) -> void:
	if _sandbox_action_blocked("delivering free-play supplies"):
		return
	if not crafting_demands.has(demand_id):
		game_ui.show_message("Unknown crew demand.")
		sound_manager.play_stamp("error_soft")
		return

	var demand: Dictionary = crafting_demands[demand_id]
	if str(demand.get("status", "")) != "open":
		game_ui.show_message("%s is already handled." % str(demand.get("label", "Crew demand")))
		return
	if str(demand.get("kind", "deliver_item")) != "deliver_item":
		game_ui.show_message("That demand needs field work.")
		sound_manager.play_stamp("error_soft")
		return

	var required_item := str(demand.get("required_item", ""))
	var amount := maxi(1, int(demand.get("amount", 1)))
	if required_item == "":
		game_ui.show_message("That demand is missing a supply.")
		sound_manager.play_stamp("error_soft")
		return

	var missing_count := maxi(0, amount - _available_crafted_item(required_item))
	if missing_count > 0:
		if not _can_craft_required_item_for_demand(demand):
			game_ui.show_message("%s needs more ingredients." % _pretty_crafted_name(required_item))
			sound_manager.play_stamp("error_soft")
			return

		for _index in range(missing_count):
			if not _craft_recipe(required_item, "player_demand_quiet"):
				return

	if _available_crafted_item(required_item) < amount:
		game_ui.show_message("%s is still short." % _pretty_crafted_name(required_item))
		sound_manager.play_stamp("error_soft")
		return

	_consume_crafted_cost({required_item: amount})
	_complete_crafting_demand(demand_id, "%s delivered to %s." % [_pretty_crafted_name(required_item), str(demand.get("agent_name", "Crew"))])
	game_ui.show_message("Delivered %s to %s." % [_pretty_crafted_name(required_item), str(demand.get("agent_name", "Crew"))])


func _on_work_order_requested(order_id: String) -> void:
	if not work_orders.has(order_id):
		game_ui.show_message("Unknown work order.")
		sound_manager.play_stamp("error_soft")
		return

	var order: Dictionary = work_orders[order_id]
	var status := str(order.get("status", "ready"))
	if status == "done":
		game_ui.show_message("%s is already complete." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("ui_click")
		return
	if status in ["queued", "gathering"]:
		game_ui.show_message("%s is already assigned." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("ui_click")
		return

	if not _can_order_target(order):
		if _block_pending_skill_forge_target(order_id):
			return
		game_ui.show_message(_targeting_error_message(str(order.get("action", "build_fence"))))
		sound_manager.play_stamp("error_soft")
		return

	if not _apply_patience_tax(order):
		return

	var action_id := str(order.get("action", "build_fence"))
	if action_id != "build_fence":
		if _queue_directive_order(order_id):
			_emit_skill_run_dispatch_feedback(order_id, order)
		return

	if _has_required_item_for_order(order):
		if _queue_build_order(order_id):
			_emit_skill_run_dispatch_feedback(order_id, order)
		return

	if _can_craft_required_item_for_order(order):
		if _craft_recipe(str(order.get("required_item", "")), "crew"):
			if _queue_build_order(order_id):
				_emit_skill_run_dispatch_feedback(order_id, order)
		return

	if _queue_supply_for_order(order_id):
		_emit_skill_run_dispatch_feedback(order_id, order)


func _emit_skill_run_dispatch_feedback(order_id: String, order: Dictionary) -> void:
	if str(order.get("source", "")) != "skill_forge":
		return
	game_ui.pulse_workbench_run(order_id)
	sound_manager.play_stamp("run_dispatch")


func _on_work_order_cancel_requested(order_id: String) -> void:
	if not work_orders.has(order_id):
		game_ui.show_message("Unknown work order.")
		sound_manager.play_stamp("error_soft")
		return

	var order: Dictionary = work_orders[order_id]
	if not _pending_skill_forge_run.is_empty() and order_id == str(_pending_skill_forge_run.get("order_id", "")):
		var label := str(order.get("label", "Work order"))
		_cancel_pending_skill_forge_run("order never completed; player cancelled %s" % label, true)
		game_ui.show_message("Cancelled pending Forge run: %s." % label)
		game_ui.add_field_log("Cancelled pending Forge run: %s." % label)
		sound_manager.play_stamp("erase_puff")
		return
	var status := str(order.get("status", "ready"))
	if status in ["queued", "gathering"]:
		game_ui.show_message("%s is already with the crew." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("error_soft")
		return

	_release_order_reservation(order)
	work_orders.erase(order_id)
	work_order_ids.erase(order_id)
	_refresh_inventory_and_orders()

	var label := str(order.get("label", "Work order"))
	if status == "done":
		game_ui.show_message("Cleared order: %s." % label)
		game_ui.add_field_log("Cleared completed order: %s." % label)
		_record_removed_work_order_event(order, "cleared")
	else:
		game_ui.show_message("Dropped order: %s." % label)
		game_ui.add_field_log("Dropped order: %s." % label)
		_record_removed_work_order_event(order, "dropped")
	sound_manager.play_stamp("erase_puff")


func _craft_recipe(recipe_id: String, source: String = "player") -> bool:
	if not RECIPES.has(recipe_id):
		game_ui.show_message("Unknown recipe.")
		sound_manager.play_stamp("error_soft")
		return false

	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.get("cost", {})
	var label := str(recipe.get("label", recipe_id.replace("_", " ").capitalize()))

	if not _can_afford(cost):
		game_ui.show_message("%s needs %s." % [label, _format_cost(cost)])
		sound_manager.play_stamp("error_soft")
		return false

	for resource_id in cost.keys():
		resources[resource_id] = int(resources.get(resource_id, 0)) - int(cost[resource_id])
	crafted_items[recipe_id] = int(crafted_items.get(recipe_id, 0)) + 1
	_refresh_inventory_and_orders()

	var payload := {
		"day": grid_manager.day,
		"recipe_id": recipe_id,
		"label": label,
		"cost": cost.duplicate(true),
		"inventory": crafted_items.duplicate(true),
		"source": source
	}
	if _event_log:
		_event_log.record_event("craft_action", payload)

	var receipt := "Crafted %s from %s." % [label, _format_cost(cost)]
	if source.begins_with("crew"):
		receipt = "Crew prepped %s from %s." % [label, _format_cost(cost)]
	game_ui.add_field_log(receipt)
	_satisfy_open_crafting_demands(recipe_id, source)
	if not source.ends_with("_quiet"):
		game_ui.show_message(receipt)
		sound_manager.play_stamp("place_soft")
		sound_manager.play_stamp("plant_pop")
	return true


func _queue_build_order(order_id: String, quiet: bool = false) -> bool:
	var order: Dictionary = work_orders[order_id]
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent", str(order.get("agent_id", "")))):
		if not quiet:
			game_ui.show_message("Crew is busy; order is waiting.")
			sound_manager.play_stamp("ui_click")
		_mark_order_waiting(order_id)
		return false

	var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
	if not _reserve_required_item_for_order(order):
		if not quiet:
			game_ui.show_message("%s needs a Fence Kit." % str(order.get("label", "Work order")))
			sound_manager.play_stamp("error_soft")
		return false

	order["status"] = "queued"
	work_orders[order_id] = order
	_refresh_work_orders()
	_refresh_crafting_demands()
	if not quiet:
		game_ui.show_message("Crew assigned: %s." % str(order.get("label", "Work order")))
		if str(order.get("source", "")) != "skill_forge":
			sound_manager.play_stamp("tool_select")
	game_ui.add_field_log("Work order queued: %s%s." % [str(order.get("label", "Crew task")), _format_work_order_context_suffix(order)])
	_record_work_order_event(order_id, "queued")

	var assigned := bool(_agent_manager.call("assign_work_order", order.duplicate(true)))
	if not assigned:
		_release_order_reservation(order)
		_mark_order_waiting(order_id)
	else:
		_maybe_update_skill_forge_work_order_trace(order, "Crew Queued")
	return assigned


func _queue_directive_order(order_id: String, quiet: bool = false) -> bool:
	var order: Dictionary = work_orders[order_id]
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent", str(order.get("agent_id", "")))):
		if not quiet:
			game_ui.show_message("Crew is busy; order is waiting.")
			sound_manager.play_stamp("ui_click")
		_mark_order_waiting(order_id)
		return false

	var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
	var agent_action := str(order.get("agent_action", ""))
	if agent_action == "":
		if not quiet:
			game_ui.show_message("That order has no crew action.")
			sound_manager.play_stamp("error_soft")
		return false

	order["status"] = "queued"
	work_orders[order_id] = order
	_refresh_work_orders()
	_refresh_crafting_demands()
	if not quiet:
		game_ui.show_message("Crew assigned: %s." % str(order.get("label", "Work order")))
		if str(order.get("source", "")) != "skill_forge":
			sound_manager.play_stamp("tool_select")
	game_ui.add_field_log("Work order queued: %s%s." % [str(order.get("label", "Crew task")), _format_work_order_context_suffix(order)])
	_record_work_order_event(order_id, "queued")

	var directive_extra := _work_order_directive_extra(order_id, order)
	var assigned := bool(_agent_manager.call("assign_directive", agent_action, target_tile, "work order: %s" % str(order.get("label", "crew task")), directive_extra))
	if not assigned:
		_mark_order_waiting(order_id)
	else:
		_maybe_update_skill_forge_work_order_trace(order, "Crew Queued")
	return assigned


func _queue_supply_for_order(order_id: String, quiet: bool = false) -> bool:
	var order: Dictionary = work_orders[order_id]
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent", str(order.get("agent_id", "")))):
		if not quiet:
			game_ui.show_message("Crew is busy; order is waiting.")
			sound_manager.play_stamp("ui_click")
		_mark_order_waiting(order_id)
		return false

	var required_item := str(order.get("required_item", ""))
	var recipe: Dictionary = RECIPES.get(required_item, {})
	var missing := _missing_resources(recipe.get("cost", {}))
	var supply_action := ""
	var supply_target := Vector2i.ZERO
	var supply_label := ""

	if int(missing.get("fiber", 0)) > 0:
		supply_target = _nearest_supply_tile("fiber")
		supply_action = "clear_brush"
		supply_label = "fiber"
	elif int(missing.get("grain", 0)) > 0:
		supply_target = _nearest_supply_tile("grain")
		supply_action = "harvest_crop"
		supply_label = "grain"

	if supply_action == "" or grid_manager.get_tile(supply_target) == null:
		if not quiet:
			game_ui.show_message("Crew needs %s, but no source is ready." % _format_resource_list(missing))
			sound_manager.play_stamp("error_soft")
		return false
	
	order["status"] = "gathering"
	order["status_text"] = "Gathering %s" % supply_label.capitalize()
	work_orders[order_id] = order
	_refresh_work_orders()
	_refresh_crafting_demands()
	game_ui.add_field_log("Crew gathering %s for %s%s." % [supply_label, str(order.get("label", "work order")), _format_work_order_context_suffix(order)])
	if not quiet:
		game_ui.show_message("Crew gathering %s." % supply_label)
		sound_manager.play_stamp("tool_select")
	_record_work_order_event(order_id, "gathering")

	var directive_extra := _work_order_directive_extra(order_id, order)
	var assigned := bool(_agent_manager.call("assign_directive", supply_action, supply_target, "gather %s for %s" % [supply_label, str(order.get("label", "work order"))], directive_extra))
	if not assigned:
		_mark_order_waiting(order_id)
	return assigned


func _continue_resource_orders(quiet: bool = false) -> void:
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent")):
		return

	for order_id in work_order_ids:
		var order: Dictionary = work_orders.get(order_id, {})
		var status := str(order.get("status", ""))
		if status not in ["waiting", "gathering"]:
			continue
		if not _can_order_target(order):
			if _block_pending_skill_forge_target(str(order_id)):
				continue
			order["status"] = "ready"
			order["status_text"] = "Target changed"
			work_orders[order_id] = order
			_refresh_work_orders()
			_refresh_crafting_demands()
			continue

		if str(order.get("action", "build_fence")) != "build_fence":
			_queue_directive_order(order_id, quiet)
			continue

		if _has_required_item_for_order(order):
			_queue_build_order(order_id, quiet)
		elif _can_craft_required_item_for_order(order):
			if _craft_recipe(str(order.get("required_item", "")), "crew" if not quiet else "crew_quiet"):
				_queue_build_order(order_id, quiet)
		else:
			_queue_supply_for_order(order_id, quiet)


func _add_resources(gains) -> Dictionary:
	if typeof(gains) != TYPE_DICTIONARY:
		return {}

	var accepted: Dictionary = {}
	for resource_id in gains.keys():
		var amount := int(gains[resource_id])
		if amount <= 0:
			continue
		resources[resource_id] = int(resources.get(resource_id, 0)) + amount
		accepted[resource_id] = amount

	if not accepted.is_empty():
		_refresh_inventory_and_orders()
	return accepted


func _work_order_directive_extra(order_id: String, order: Dictionary) -> Dictionary:
	var extra := {
		"work_order_id": order_id,
		"agent_id": str(order.get("agent_id", "")),
		"guard_condition": str(order.get("guard_condition", "always")),
		"guard_action": str(order.get("guard_action", order.get("action", "")))
	}
	var social_context := _work_order_social_preference_context(order)
	for key in social_context.keys():
		extra[key] = social_context[key]
	var forge_context := _work_order_skill_forge_context(order)
	for key in forge_context.keys():
		extra[key] = forge_context[key]
	var mission_id := str(order.get("mission_id", "")).strip_edges()
	if mission_id != "":
		extra["mission_id"] = mission_id
		extra["mission_label"] = str(order.get("mission_label", "Crew Mission"))
		extra["mission_step_index"] = int(order.get("mission_step_index", -1))
		extra["mission_total_steps"] = int(order.get("mission_total_steps", 0))
		extra["mission_step_label"] = str(order.get("mission_step_label", ""))
	return extra


func _format_work_order_context_suffix(order: Dictionary) -> String:
	return _format_work_order_social_preference_suffix(order) + _format_work_order_skill_forge_suffix(order)


func _format_work_order_social_preference_suffix(order: Dictionary) -> String:
	return _format_social_preference_suffix(_work_order_social_preference_context(order))


func _format_work_order_skill_forge_suffix(order: Dictionary) -> String:
	return _format_skill_forge_suffix(_work_order_skill_forge_context(order))


func _work_order_social_preference_context(order: Dictionary) -> Dictionary:
	var context := {}
	var source := str(order.get("social_preference_source", "")).strip_edges()
	var label := str(order.get("social_preference_label", "")).strip_edges()
	var preference_source := str(order.get("preference_source", "")).strip_edges()
	if source == "skill_forge" or preference_source == "skill_forge":
		return context
	if source == "":
		source = _social_preference_source_for_order(preference_source)
	if label == "":
		label = str(order.get("preference_label", "")).strip_edges()
	if source != "" and label != "":
		context["social_preference_source"] = source
		context["social_preference_label"] = label
		var origin_source := str(order.get("social_preference_origin_source", "")).strip_edges()
		var origin_label := str(order.get("social_preference_origin_label", "")).strip_edges()
		if origin_source == "":
			origin_source = str(order.get("preference_origin_source", "")).strip_edges()
		if origin_label == "":
			origin_label = str(order.get("preference_origin_label", "")).strip_edges()
		if origin_source != "" and origin_label != "" and not (origin_source == source and origin_label == label):
			context["social_preference_origin_source"] = origin_source
			context["social_preference_origin_label"] = origin_label
	return context


func _work_order_skill_forge_context(order: Dictionary) -> Dictionary:
	var forge_run_id := str(order.get("forge_run_id", "")).strip_edges()
	var skill_name := str(order.get("skill_name", "")).strip_edges()
	if skill_name == "":
		skill_name = str(order.get("preference_label", "")).strip_edges()
	if forge_run_id == "" and skill_name == "" and str(order.get("source", "")) != "skill_forge":
		return {}

	var context := {
		"forge_run_id": forge_run_id,
		"skill_id": str(order.get("skill_id", "")),
		"skill_name": skill_name,
		"directive_id": str(order.get("directive_id", "")),
		"directive_kind": str(order.get("directive_kind", ""))
	}
	var source_context = order.get("source_context", {})
	if typeof(source_context) == TYPE_DICTIONARY and not source_context.is_empty():
		context["forge_source_context"] = source_context.duplicate(true)
	var drift = order.get("drift", {})
	if typeof(drift) == TYPE_DICTIONARY and not drift.is_empty():
		context["forge_drift"] = drift.duplicate(true)
	return context


func _show_named_agent_drift_reaction(agent_id: String, drift) -> bool:
	if _agent_manager == null or agent_id.strip_edges() == "" or typeof(drift) != TYPE_DICTIONARY:
		return false
	for actor in _agent_manager.agents:
		if str(actor.get("agent_id")) != agent_id:
			continue
		if actor.has_method("show_forge_drift_reaction"):
			return bool(actor.call("show_forge_drift_reaction", drift))
	return false


func _consume_crafted_cost(cost) -> Dictionary:
	if typeof(cost) != TYPE_DICTIONARY:
		return {}

	var consumed: Dictionary = {}
	for item_id in cost.keys():
		var amount := int(cost[item_id])
		if amount <= 0:
			continue
		var available := int(crafted_items.get(item_id, 0))
		var applied := mini(available, amount)
		if applied <= 0:
			continue
		crafted_items[item_id] = available - applied
		reserved_crafted_items[item_id] = maxi(0, int(reserved_crafted_items.get(item_id, 0)) - applied)
		consumed[item_id] = applied

	if not consumed.is_empty():
		_refresh_inventory_and_orders()
	return consumed


func _refresh_inventory_and_orders() -> void:
	game_ui.set_inventory(resources, _available_crafted_items_snapshot())
	_refresh_crafting_demands()
	_refresh_work_orders()


func _refresh_crafting_demands() -> void:
	_refresh_demand_markers()
	game_ui.set_crafting_demands(_crafting_demand_snapshots())


func _refresh_work_orders() -> void:
	_refresh_order_markers()
	game_ui.set_work_orders(_work_order_snapshots())
	_refresh_crew_missions()


func _refresh_crew_missions() -> void:
	game_ui.set_crew_missions(_crew_mission_snapshots())


func _refresh_order_markers() -> void:
	if grid_manager == null:
		return

	for tile in grid_manager.tiles.values():
		if tile.has_method("set_order_marker"):
			tile.set_order_marker({})

	for order_id in work_order_ids:
		if not work_orders.has(order_id):
			continue
		var order := _work_order_snapshot(order_id)
		if order.is_empty() or str(order.get("status", "")) == "done":
			continue
		var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
		var tile = grid_manager.get_tile(target_tile)
		if tile != null and tile.has_method("set_order_marker"):
			tile.set_order_marker(order)


func _refresh_demand_markers() -> void:
	if grid_manager == null:
		return

	for tile in grid_manager.tiles.values():
		if tile.has_method("set_demand_marker"):
			tile.set_demand_marker({})

	for demand_id in crafting_demand_ids:
		if not crafting_demands.has(demand_id):
			continue
		var demand := _crafting_demand_snapshot(demand_id)
		if demand.is_empty() or str(demand.get("status", "")) == "done" or not _demand_has_target(demand):
			continue
		var target_tile: Vector2i = demand.get("target_tile", Vector2i(-1, -1))
		var tile = grid_manager.get_tile(target_tile)
		if tile != null and tile.has_method("set_demand_marker"):
			tile.set_demand_marker(demand)


func _can_place_palette_item(item_id: String) -> bool:
	match item_id:
		"fence":
			return _available_crafted_item("fence_kit") > 0
	return true


func _available_crafted_items_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for item_id in crafted_items.keys():
		snapshot[item_id] = _available_crafted_item(str(item_id))
	return snapshot


func _available_crafted_item(item_id: String) -> int:
	return maxi(0, int(crafted_items.get(item_id, 0)) - int(reserved_crafted_items.get(item_id, 0)))


func _mark_order_waiting(order_id: String) -> void:
	if not work_orders.has(order_id):
		return
	var order: Dictionary = work_orders[order_id]
	if str(order.get("status", "")) == "done":
		return
	order["status"] = "waiting"
	order["status_text"] = "Waiting crew"
	work_orders[order_id] = order
	_refresh_work_orders()
	_refresh_crafting_demands()
	_maybe_update_skill_forge_work_order_trace(order, "Crew Waiting")


func _reserve_required_item_for_order(order: Dictionary) -> bool:
	var required_item := str(order.get("required_item", ""))
	if required_item == "":
		return true
	if str(order.get("reserved_item", "")) == required_item:
		return true
	if _available_crafted_item(required_item) <= 0:
		return false

	reserved_crafted_items[required_item] = int(reserved_crafted_items.get(required_item, 0)) + 1
	order["reserved_item"] = required_item
	_refresh_inventory_and_orders()
	return true


func _release_order_reservation(order: Dictionary) -> void:
	var reserved_item := str(order.get("reserved_item", ""))
	if reserved_item == "":
		return
	reserved_crafted_items[reserved_item] = maxi(0, int(reserved_crafted_items.get(reserved_item, 0)) - 1)
	order.erase("reserved_item")
	if work_orders.has(str(order.get("id", ""))):
		work_orders[str(order.get("id", ""))] = order
	_refresh_inventory_and_orders()


func _can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(resources.get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true


func _has_required_item_for_order(order: Dictionary) -> bool:
	var required_item := str(order.get("required_item", ""))
	if required_item == "":
		return true
	if str(order.get("reserved_item", "")) == required_item:
		return true
	return _available_crafted_item(required_item) > 0


func _can_craft_required_item_for_order(order: Dictionary) -> bool:
	var required_item := str(order.get("required_item", ""))
	if not RECIPES.has(required_item):
		return false
	return _can_afford(RECIPES[required_item].get("cost", {}))


func _can_craft_required_item_for_demand(demand: Dictionary) -> bool:
	var required_item := str(demand.get("required_item", ""))
	if not RECIPES.has(required_item):
		return false

	var amount := maxi(1, int(demand.get("amount", 1)))
	var needed := maxi(0, amount - _available_crafted_item(required_item))
	if needed <= 0:
		return false
	return _can_afford(_scaled_recipe_cost(required_item, needed))


func _missing_resources_for_demand(demand: Dictionary) -> Dictionary:
	var required_item := str(demand.get("required_item", ""))
	if not RECIPES.has(required_item):
		return {}

	var amount := maxi(1, int(demand.get("amount", 1)))
	var needed := maxi(0, amount - _available_crafted_item(required_item))
	if needed <= 0:
		return {}
	return _missing_resources(_scaled_recipe_cost(required_item, needed))


func _scaled_recipe_cost(recipe_id: String, count: int) -> Dictionary:
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	var base_cost: Dictionary = recipe.get("cost", {})
	var scaled_cost: Dictionary = {}
	for resource_id in base_cost.keys():
		scaled_cost[resource_id] = int(base_cost[resource_id]) * count
	return scaled_cost


func _can_build_order_target(order: Dictionary) -> bool:
	var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
	return _can_target_crew_order("build_fence", target_tile)


func _can_order_target(order: Dictionary) -> bool:
	return _can_target_crew_order(str(order.get("action", "build_fence")), order.get("target_tile", Vector2i.ZERO))


func _can_target_crew_order(action_id: String, grid_pos: Vector2i) -> bool:
	var tile = grid_manager.get_tile(grid_pos)
	if tile == null:
		return false

	match action_id:
		"build_fence":
			return tile.can_apply_item("fence") and not _is_agent_tile_occupied(grid_pos)
		"clear_brush":
			return str(tile.decor_id) in ["tall_grass", "flower_patch"]
		"harvest_crop":
			return tile.crop != null and tile.crop.is_ready()
		"plant_seed":
			return tile.crop == null and str(tile.decor_id) == "" and str(tile.structure_id) == "" and str(tile.terrain) != "dirt_path"
		"tend_crop":
			return tile.crop != null and not tile.crop.is_ready()
	return false


func _is_agent_tile_occupied(grid_pos: Vector2i) -> bool:
	return _agent_manager != null and bool(_agent_manager.call("is_grid_pos_occupied", grid_pos))


func _targeting_error_message(action_id: String) -> String:
	match action_id:
		"build_fence":
			return "Fence orders need an open tile."
		"clear_brush":
			return "Clear orders need flowers or tall grass."
		"harvest_crop":
			return "Harvest orders need a ready crop."
		"plant_seed":
			return "Plant orders need an open tile."
		"tend_crop":
			return "Tend orders need a growing crop."
	return "That tile cannot take this order."


func _missing_resources(cost: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for resource_id in cost.keys():
		var needed := int(cost[resource_id]) - int(resources.get(resource_id, 0))
		if needed > 0:
			missing[resource_id] = needed
	return missing


func _nearest_supply_tile(resource_id: String) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for tile in grid_manager.tiles.values():
		match resource_id:
			"fiber":
				if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
					candidates.append(tile.grid_pos)
			"grain":
				if tile.crop != null and tile.crop.is_ready():
					candidates.append(tile.grid_pos)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	var origin := Vector2i(grid_manager.width / 2, grid_manager.height / 2)
	var best := candidates[0]
	var best_distance := origin.distance_squared_to(best)
	for candidate in candidates:
		var distance := origin.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _update_work_order_from_agent_action(event: Dictionary) -> void:
	var order_id := str(event.get("work_order_id", ""))
	if order_id == "" or not work_orders.has(order_id):
		return

	var order: Dictionary = work_orders[order_id]
	var action_id := str(order.get("action", "build_fence"))
	var completed_action := str(event.get("action", ""))
	var expected_action := str(order.get("agent_action", "build_fence_order"))
	if completed_action != expected_action:
		return

	var success := bool(event.get("success", false))
	if success:
		order.erase("reserved_item")
	else:
		_release_order_reservation(order)
	order["status"] = "done" if success else "ready"
	order.erase("status_text")
	work_orders[order_id] = order
	if success:
		_claim_work_order_incentive(order_id)
		if str(order.get("source", "")) == "npc_demand" and _agent_manager:
			_agent_manager.call("acknowledge_completed_authored_order", str(order.get("author_agent_id", "")), _work_order_label(action_id, order.get("target_tile", Vector2i.ZERO)))
	_refresh_work_orders()
	if not success and not _pending_skill_forge_run.is_empty():
		var pending_order_id := str(_pending_skill_forge_run.get("order_id", ""))
		if pending_order_id == order_id and str(_pending_skill_forge_run.get("origin", "")) == "workbench":
			var retry_detail := "Crew attempt failed; the correlated order returned to ready."
			game_ui.set_workbench_trace({
				"stage": "CREW RETRY",
				"status": "PENDING WORLD CHECK",
				"runtime_status": "PENDING  ·  RETRY READY",
				"agent_name": str(_pending_skill_forge_run.get("agent_name", "Crew")),
				"target_tile": _pending_skill_forge_run.get("target_tile", Vector2i(-1, -1)),
				"target_source": str(_pending_skill_forge_run.get("target_source", "selected_tile")),
				"run_id": str(_pending_skill_forge_run.get("run_id", "")),
				"order_id": order_id,
				"issues": [_workbench_runtime_issue(
					_pending_skill_forge_run.get("source_map", {}),
					"steps[0].tool",
					"lifecycle_retrying",
					retry_detail,
					_pipeline_tutor_line("lifecycle", "retrying")
				)],
				"tutor_lines": [_pipeline_tutor_line("lifecycle", "retrying")],
				"lines": [retry_detail]
			})

	_record_work_order_event(order_id, str(order.get("status", "ready")))


func _claim_work_order_incentive(order_id: String) -> void:
	if not work_orders.has(order_id):
		return

	var order: Dictionary = work_orders[order_id]
	if bool(order.get("incentive_claimed", false)):
		return

	var incentive_delta: Dictionary = order.get("incentive_resource_delta", {})
	if incentive_delta.is_empty():
		return

	var accepted := _add_resources(incentive_delta)
	if accepted.is_empty():
		return

	order["incentive_claimed"] = true
	order["incentive_claimed_day"] = grid_manager.day
	work_orders[order_id] = order
	game_ui.add_field_log("%s paid: +%s." % [str(order.get("incentive_label", "Crew bargain")), _format_resource_list(accepted)])
	_record_work_order_event(order_id, "incentive_claimed")


func _record_work_order_event(order_id: String, status: String) -> void:
	if _event_log == null or not work_orders.has(order_id):
		return

	var order: Dictionary = work_orders[order_id]
	_event_log.record_event("work_order", {
		"day": grid_manager.day,
		"order_id": order_id,
		"label": str(order.get("label", "")),
		"status": status,
		"target_tile": order.get("target_tile", Vector2i.ZERO),
		"source": str(order.get("source", "player")),
		"source_demand_id": str(order.get("source_demand_id", "")),
		"author_agent_id": str(order.get("author_agent_id", "")),
		"author_agent_name": str(order.get("author_agent_name", "")),
		"escalation_count": int(order.get("escalation_count", 0)),
		"escalated_day": int(order.get("escalated_day", 0)),
		"last_escalation": str(order.get("last_escalation", "")),
		"truce_delayed_day": int(order.get("truce_delayed_day", 0)),
		"truce_label": str(order.get("truce_label", "")),
		"preference_source": str(order.get("preference_source", "")),
		"preference_label": str(order.get("preference_label", "")),
		"preference_origin_source": str(order.get("preference_origin_source", "")),
		"preference_origin_label": str(order.get("preference_origin_label", "")),
		"social_preference_source": str(order.get("social_preference_source", "")),
		"social_preference_label": str(order.get("social_preference_label", "")),
		"mission_id": str(order.get("mission_id", "")),
		"mission_label": str(order.get("mission_label", "")),
		"mission_step_index": int(order.get("mission_step_index", -1)),
		"mission_total_steps": int(order.get("mission_total_steps", 0)),
		"mission_step_label": str(order.get("mission_step_label", "")),
		"forge_run_id": str(order.get("forge_run_id", "")),
		"skill_id": str(order.get("skill_id", "")),
		"skill_name": str(order.get("skill_name", "")),
		"directive_id": str(order.get("directive_id", "")),
		"directive_kind": str(order.get("directive_kind", "")),
		"source_context": order.get("source_context", {}),
		"incentive_label": str(order.get("incentive_label", "")),
		"incentive_resource_delta": order.get("incentive_resource_delta", {}),
		"incentive_claimed": bool(order.get("incentive_claimed", false))
	})


func _record_removed_work_order_event(order: Dictionary, status: String) -> void:
	if _event_log == null:
		return

	_event_log.record_event("work_order", {
		"day": grid_manager.day,
		"order_id": str(order.get("id", "")),
		"label": str(order.get("label", "")),
		"status": status,
		"target_tile": order.get("target_tile", Vector2i.ZERO),
		"source": str(order.get("source", "player")),
		"source_demand_id": str(order.get("source_demand_id", "")),
		"author_agent_id": str(order.get("author_agent_id", "")),
		"author_agent_name": str(order.get("author_agent_name", "")),
		"escalation_count": int(order.get("escalation_count", 0)),
		"escalated_day": int(order.get("escalated_day", 0)),
		"last_escalation": str(order.get("last_escalation", "")),
		"truce_delayed_day": int(order.get("truce_delayed_day", 0)),
		"truce_label": str(order.get("truce_label", "")),
		"preference_source": str(order.get("preference_source", "")),
		"preference_label": str(order.get("preference_label", "")),
		"preference_origin_source": str(order.get("preference_origin_source", "")),
		"preference_origin_label": str(order.get("preference_origin_label", "")),
		"social_preference_source": str(order.get("social_preference_source", "")),
		"social_preference_label": str(order.get("social_preference_label", "")),
		"mission_id": str(order.get("mission_id", "")),
		"mission_label": str(order.get("mission_label", "")),
		"mission_step_index": int(order.get("mission_step_index", -1)),
		"mission_total_steps": int(order.get("mission_total_steps", 0)),
		"mission_step_label": str(order.get("mission_step_label", "")),
		"forge_run_id": str(order.get("forge_run_id", "")),
		"skill_id": str(order.get("skill_id", "")),
		"skill_name": str(order.get("skill_name", "")),
		"directive_id": str(order.get("directive_id", "")),
		"directive_kind": str(order.get("directive_kind", "")),
		"source_context": order.get("source_context", {}),
		"incentive_label": str(order.get("incentive_label", "")),
		"incentive_resource_delta": order.get("incentive_resource_delta", {}),
		"incentive_claimed": bool(order.get("incentive_claimed", false))
	})


func _work_order_snapshot(order_id: String) -> Dictionary:
	if not work_orders.has(order_id):
		return {}

	var order: Dictionary = work_orders[order_id].duplicate(true)
	var required_item := str(order.get("required_item", ""))
	var action_id := str(order.get("action", "build_fence"))
	order["has_required_item"] = required_item == "" or str(order.get("reserved_item", "")) == required_item or _available_crafted_item(required_item) > 0
	order["can_craft_item"] = _can_craft_required_item_for_order(order)
	order["can_progress"] = str(order.get("status", "ready")) == "ready" and _can_order_target(order)
	order["incentive_status_text"] = _work_order_incentive_status_text(order)
	if str(order.get("status", "ready")) == "ready" and not bool(order["can_progress"]):
		order["status_text"] = "Target changed"
	elif str(order.get("status", "ready")) == "ready" and action_id == "build_fence" and not bool(order["has_required_item"]) and not bool(order["can_craft_item"]):
		var recipe: Dictionary = RECIPES.get(required_item, {})
		var missing := _missing_resources(recipe.get("cost", {}))
		if not missing.is_empty():
			order["status_text"] = "Needs %s" % _format_resource_list(missing)
	elif str(order.get("status", "ready")) == "ready" and action_id != "build_fence":
		order["status_text"] = "Ready"
	return order


func _work_order_incentive_status_text(order: Dictionary) -> String:
	var incentive_delta: Dictionary = order.get("incentive_resource_delta", {})
	if incentive_delta.is_empty():
		return ""

	var prefix := "Claimed" if bool(order.get("incentive_claimed", false)) else "Bonus"
	return "%s +%s" % [prefix, _format_resource_list(incentive_delta)]


func _crafting_demand_snapshot(demand_id: String) -> Dictionary:
	if not crafting_demands.has(demand_id):
		return {}

	var demand: Dictionary = crafting_demands[demand_id].duplicate(true)
	var required_item := str(demand.get("required_item", ""))
	var amount := maxi(1, int(demand.get("amount", 1)))
	demand["has_required_item"] = required_item != "" and _available_crafted_item(required_item) >= amount
	demand["can_craft_required_item"] = required_item != "" and _can_craft_required_item_for_demand(demand)
	var missing_resources := _missing_resources_for_demand(demand)
	demand["missing_resources"] = missing_resources
	demand["missing_resource_text"] = _format_resource_list(missing_resources)
	demand["reward_text"] = _demand_reward_text(demand)
	if str(demand.get("status", "")) == "open":
		demand["status_text"] = _demand_status_text(demand)
	return demand


func _crafting_demand_snapshots() -> Array:
	var snapshots: Array = []
	var visible_ids := crafting_demand_ids.duplicate()
	visible_ids.reverse()
	for demand_id in visible_ids.slice(0, 2):
		snapshots.append(_crafting_demand_snapshot(demand_id))
	return snapshots


func _crew_mission_snapshot(mission_id: String) -> Dictionary:
	if not crew_missions.has(mission_id):
		return {}

	var mission: Dictionary = crew_missions[mission_id].duplicate(true)
	var status := str(mission.get("status", "active"))
	var total_steps := int(mission.get("total_steps", 0))
	var current_step_index := int(mission.get("current_step_index", 0))
	if status == "done":
		mission["status_text"] = "Done"
		mission["current_step_label"] = "Completed"
		return mission

	var display_step := clampi(current_step_index + 1, 1, maxi(1, total_steps))
	var progress_text := "%s/%s" % [display_step, maxi(1, total_steps)]
	var status_prefix := "Step"
	var step_label := ""
	var current_demand_id := str(mission.get("current_demand_id", ""))
	mission["current_order_id"] = ""
	if crafting_demands.has(current_demand_id):
		var demand: Dictionary = crafting_demands[current_demand_id]
		step_label = str(demand.get("mission_step_label", "")).strip_edges()
		mission["current_order_id"] = str(demand.get("authored_order_id", ""))
		status_prefix = _mission_tracker_order_status_prefix(str(mission.get("current_order_id", "")))
	if step_label == "":
		var steps: Array = mission.get("steps", [])
		if current_step_index >= 0 and current_step_index < steps.size() and typeof(steps[current_step_index]) == TYPE_DICTIONARY:
			step_label = str((steps[current_step_index] as Dictionary).get("label", "")).strip_edges()
	if step_label == "":
		step_label = "Active"
	mission["status_text"] = "%s %s" % [status_prefix, progress_text]
	mission["current_step_label"] = step_label
	return mission


func _mission_tracker_order_status_prefix(order_id: String) -> String:
	if order_id == "":
		return "Step"
	if not work_orders.has(order_id):
		return "Queued"

	var order: Dictionary = work_orders[order_id]
	if int(order.get("escalation_count", 0)) > 0:
		var incentive: Dictionary = order.get("incentive_resource_delta", {})
		if not incentive.is_empty() and not bool(order.get("incentive_claimed", false)):
			return "Bonus"
		return "Escalated"
	match str(order.get("status", "ready")):
		"queued", "gathering":
			return "Sent"
		"waiting":
			return "Waiting"
		"done":
			return "Done"
	return "Queued"


func _crew_mission_snapshots() -> Array:
	var snapshots: Array = []
	var visible_ids := crew_mission_ids.duplicate()
	visible_ids.reverse()
	for mission_id in visible_ids.slice(0, 2):
		var snapshot := _crew_mission_snapshot(str(mission_id))
		if not snapshot.is_empty():
			snapshots.append(snapshot)
	return snapshots


func _work_order_snapshots() -> Array:
	var snapshots: Array = []
	var visible_ids := work_order_ids.duplicate()
	visible_ids.reverse()
	for order_id in visible_ids.slice(0, 3):
		snapshots.append(_work_order_snapshot(order_id))
	return snapshots


func _format_player_receipt(event: Dictionary) -> String:
	var action := str(event.get("action", "work"))
	var item_id := str(event.get("item_id", ""))
	var grid_pos: Vector2i = event.get("grid_pos", Vector2i.ZERO)
	var success := bool(event.get("success", false))

	var target := "(%s,%s)" % [grid_pos.x, grid_pos.y]
	if not success:
		return "Missed %s at %s: %s" % [action, target, str(event.get("message", "blocked"))]

	match action:
		"place":
			return "Placed %s at %s.%s%s" % [_pretty_item_name(item_id), target, _format_resource_suffix(event.get("resources", {})), _format_crafted_cost_suffix(event.get("crafted_cost", {}))]
		"pickaxe":
			return "Swung pickaxe at %s.%s" % [target, _format_resource_suffix(event.get("resources", {}))]
		"sickle":
			return "Cut or harvested at %s.%s" % [target, _format_resource_suffix(event.get("resources", {}))]
		"till":
			return "Tilled soil at %s." % target
		"plant":
			return "Planted corn at %s." % target
		"harvest":
			return "Harvested %s coins at %s.%s" % [int(event.get("value", 0)), target, _format_resource_suffix(event.get("resources", {}))]
		"erase":
			return "Cleared tile at %s." % target
	return "%s succeeded at %s." % [action.capitalize(), target]


func _format_day_summary(summary: Dictionary) -> String:
	var total := int(summary.get("total_player_actions", 0))
	var failed := int(summary.get("failed_player_actions", 0))
	var harvest_value := int(summary.get("harvest_value", 0))
	var agent_harvest_value := int(summary.get("agent_harvest_value", 0))
	var craft_count := int(summary.get("craft_count", 0))
	var adversarial_session_count := int(summary.get("adversarial_session_count", 0))
	var resolved_adversarial_sessions := int(summary.get("resolved_adversarial_sessions", 0))
	var called_favors := int(summary.get("called_favors", 0))
	var player_actions: Dictionary = summary.get("player_actions", {})
	var supply_deliveries := int(player_actions.get("deliver_supply", 0))
	var resources_gained: Dictionary = summary.get("resources_gained", {})
	var work_order_events: Dictionary = summary.get("work_order_events", {})
	var truce_delayed_orders := int(work_order_events.get("truce_delayed", 0))
	var helped_agents: Dictionary = summary.get("helped_agents", {})
	var favored_agents: Dictionary = summary.get("favored_agents", {})
	var remembered_help_sessions: Dictionary = summary.get("remembered_help_sessions", {})
	var remembered_context_text := _format_remembered_help_session_names(remembered_help_sessions)
	var social_preference_actions: Dictionary = summary.get("agent_social_preference_actions", {})
	var social_autonomy_text := _format_agent_social_preference_names(social_preference_actions)
	var social_run_recap_text := _format_agent_social_preference_run_recaps(social_preference_actions)
	var skill_forge_run_recap_text := _format_skill_forge_run_recaps(summary.get("skill_forge_runs", {}))
	var skill_forge_work_recap_text := _format_skill_forge_work_recaps(summary.get("agent_skill_forge_actions", {}))
	var completed_crew_missions := int(summary.get("completed_crew_missions", 0))
	var completed_mission_text := _format_completed_crew_mission_names(summary.get("crew_missions", {}))
	var top_action := str(summary.get("top_action", "none"))
	var vibe: Dictionary = summary.get("vibe", {})
	var vibe_label := str(vibe.get("label", "mixed"))
	var vibe_score := int(vibe.get("score", 50))

	if total == 0:
		var empty_line := "Day %s: neglectful, no farm work logged" % int(summary.get("day", 1))
		if remembered_context_text != "":
			empty_line += ", remembered %s" % remembered_context_text
		if social_autonomy_text != "":
			empty_line += ", crew followed %s" % social_autonomy_text
		if social_run_recap_text != "":
			empty_line += ", run recap %s" % social_run_recap_text
		if skill_forge_run_recap_text != "":
			empty_line += ", forge recap %s" % skill_forge_run_recap_text
		if skill_forge_work_recap_text != "":
			empty_line += ", forge work %s" % skill_forge_work_recap_text
		if truce_delayed_orders > 0:
			empty_line += ", truce delayed %s order%s" % [truce_delayed_orders, "" if truce_delayed_orders == 1 else "s"]
		if completed_crew_missions > 0:
			empty_line += ", completed %s mission%s" % [completed_crew_missions, "" if completed_crew_missions == 1 else "s"]
			if completed_mission_text != "":
				empty_line += ": %s" % completed_mission_text
		return empty_line + "."

	var line := "Day %s: %s vibe (%s), %s actions, %s missed" % [int(summary.get("day", 1)), vibe_label, vibe_score, total, failed]
	if harvest_value > 0:
		line += ", %s coins harvested" % harvest_value
	if agent_harvest_value > 0:
		line += ", crew added %s" % agent_harvest_value
	if adversarial_session_count > 0:
		line += ", settled %s/%s grievances" % [resolved_adversarial_sessions, adversarial_session_count]
	if called_favors > 0:
		line += ", called %s" % _format_called_favor_names(favored_agents)
	if remembered_context_text != "":
		line += ", remembered %s" % remembered_context_text
	if social_autonomy_text != "":
		line += ", crew followed %s" % social_autonomy_text
	if social_run_recap_text != "":
		line += ", run recap %s" % social_run_recap_text
	if skill_forge_run_recap_text != "":
		line += ", forge recap %s" % skill_forge_run_recap_text
	if skill_forge_work_recap_text != "":
		line += ", forge work %s" % skill_forge_work_recap_text
	if truce_delayed_orders > 0:
		line += ", truce delayed %s order%s" % [truce_delayed_orders, "" if truce_delayed_orders == 1 else "s"]
	if completed_crew_missions > 0:
		line += ", completed %s mission%s" % [completed_crew_missions, "" if completed_crew_missions == 1 else "s"]
		if completed_mission_text != "":
			line += ": %s" % completed_mission_text
	if craft_count > 0:
		line += ", %s craft%s" % [craft_count, "" if craft_count == 1 else "s"]
	if supply_deliveries > 0:
		line += ", %s supply%s delivered" % [supply_deliveries, "" if supply_deliveries == 1 else "s"]
	var helped_text := _format_helped_agent_names(helped_agents)
	if helped_text != "":
		line += ", helped %s" % helped_text
	if not resources_gained.is_empty():
		line += ", gathered %s" % _format_resource_list(resources_gained)
	if top_action != "none":
		line += ", mostly %s" % top_action
	return line + "."


func _format_agent_receipt(event: Dictionary) -> String:
	var action := str(event.get("action", "work"))
	var name := str(event.get("agent_name", "Crew"))
	var grid_pos: Vector2i = event.get("grid_pos", Vector2i.ZERO)
	var target := "(%s,%s)" % [grid_pos.x, grid_pos.y]
	var success := bool(event.get("success", false))
	var subject := str(event.get("subject", "tile"))
	var context_suffix := _format_social_preference_suffix(event) + _format_skill_forge_suffix(event)

	if not success:
		return "%s missed %s at %s%s." % [name, action.replace("_", " "), target, context_suffix]

	match action:
		"build_fence_order":
			return "%s built fence at %s.%s%s" % [name, target, _format_crafted_cost_suffix(event.get("crafted_cost", {})), context_suffix]
		"harvest_crop":
			return "%s harvested %s coins at %s.%s%s" % [name, int(event.get("value", 0)), target, _format_resource_suffix(event.get("resources", {})), context_suffix]
		"clear_brush":
			return "%s cleared %s at %s.%s%s" % [name, subject, target, _format_resource_suffix(event.get("resources", {})), context_suffix]
		"plant_seed":
			return "%s planted %s at %s%s." % [name, subject, target, context_suffix]
		"tend_crop":
			return "%s tended %s at %s%s." % [name, subject, target, context_suffix]
		"inspect_structure":
			return "%s inspected %s at %s%s." % [name, subject, target, context_suffix]
		"inspect_ready_crop":
			return "%s checked %s at %s%s." % [name, subject, target, context_suffix]
		"inspect_soil":
			return "%s checked open soil at %s%s." % [name, target, context_suffix]
	return "%s completed %s at %s%s." % [name, action.replace("_", " "), target, context_suffix]


func _format_adversarial_result(result: Dictionary) -> String:
	var verdict := str(result.get("verdict", "The encounter ended."))
	var money_delta := int(result.get("money_delta", 0))
	if money_delta > 0:
		return "%s +%s coins." % [verdict, money_delta]
	if money_delta < 0:
		return "%s %s coins." % [verdict, money_delta]
	return verdict


func _format_resource_suffix(gains) -> String:
	var text := _format_resource_list(gains)
	if text == "":
		return ""
	return " +%s" % text


func _format_crafted_cost_suffix(cost) -> String:
	var text := _format_crafted_cost_list(cost)
	if text == "":
		return ""
	return " -%s" % text


func _format_helped_agent_names(helped_agents: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in helped_agents.keys():
		var receipt: Dictionary = helped_agents.get(agent_id, {})
		var name := str(receipt.get("name", str(agent_id).capitalize()))
		if name != "" and not names.has(name):
			names.append(name)
	names.sort()
	return _join_names(names)


func _format_called_favor_names(favored_agents: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in favored_agents.keys():
		var receipt: Dictionary = favored_agents.get(agent_id, {})
		var name := str(receipt.get("name", str(agent_id).capitalize()))
		if name == "":
			continue
		var count := int(receipt.get("called_favors", 0))
		var label := "%s's favor" % name
		if count > 1:
			label += " x%s" % count
		if not names.has(label):
			names.append(label)
	names.sort()
	if names.is_empty():
		return "a favor"
	return _join_names(names)


func _format_remembered_help_session_names(memory_sessions: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in memory_sessions.keys():
		var receipt: Dictionary = memory_sessions.get(agent_id, {})
		var name := str(receipt.get("name", str(agent_id).capitalize()))
		var memory_label := str(receipt.get("last_memory_label", ""))
		if name == "" or memory_label == "":
			continue
		var count := int(receipt.get("memory_context_sessions", 0))
		var label := "%s's %s" % [name, memory_label]
		if count > 1:
			label += " x%s" % count
		if not names.has(label):
			names.append(label)
	names.sort()
	return _join_names(names)


func _format_agent_social_preference_names(social_actions) -> String:
	if typeof(social_actions) != TYPE_DICTIONARY:
		return ""

	var names: Array[String] = []
	for agent_id in social_actions.keys():
		var receipt: Dictionary = social_actions.get(agent_id, {})
		var name := str(receipt.get("name", str(agent_id).capitalize()))
		var label := str(receipt.get("last_label", ""))
		var source := _readable_social_preference_source(str(receipt.get("last_source", "")))
		if name == "" or label == "":
			continue
		var detail := "%s's %s" % [name, label]
		if source != "":
			detail += " %s" % source
		var origin_detail := _format_social_preference_origin_detail(receipt)
		if origin_detail != "":
			detail += " (%s)" % origin_detail
		var count := int(receipt.get("actions", 0))
		if count > 1:
			detail += " x%s" % count
		if not names.has(detail):
			names.append(detail)
	names.sort()
	return _join_names(names)


func _format_agent_social_preference_run_recaps(social_actions: Dictionary) -> String:
	var recaps: Array[String] = []
	for agent_id in social_actions.keys():
		var receipt: Dictionary = social_actions.get(agent_id, {})
		if str(receipt.get("last_source", "")).strip_edges() != "completed_mission":
			continue
		var name := str(receipt.get("name", str(agent_id).capitalize())).strip_edges()
		var run_label := str(receipt.get("last_label", "")).strip_edges()
		if name == "" or run_label == "":
			continue
		var detail := "%s ran %s" % [name, run_label]
		var origin_detail := _format_social_preference_origin_detail(receipt)
		if origin_detail != "":
			detail += " from %s" % origin_detail
		var count := int(receipt.get("actions", 0))
		if count > 1:
			detail += " x%s" % count
		if not recaps.has(detail):
			recaps.append(detail)
	recaps.sort()
	return _join_names(recaps)


func _format_skill_forge_run_recaps(forge_runs) -> String:
	if typeof(forge_runs) != TYPE_DICTIONARY:
		return ""

	var recaps: Array[String] = []
	for run_id in forge_runs.keys():
		var receipt: Dictionary = forge_runs.get(run_id, {})
		var status := str(receipt.get("status", "")).strip_edges()
		if status == "":
			continue
		var agent_name := str(receipt.get("agent_name", "Crew")).strip_edges()
		if agent_name == "":
			agent_name = "Crew"
		var skill_name := str(receipt.get("skill_name", "Skill Run")).strip_edges()
		if skill_name == "":
			skill_name = "Skill Run"
		var detail := "%s %s %s" % [agent_name, status, skill_name]
		var drift_level := str(receipt.get("drift_level", "")).strip_edges()
		if status in ["blocked", "failed"] and drift_level != "" and drift_level != "steady":
			detail += " [Drift %s]" % drift_level
		if not recaps.has(detail):
			recaps.append(detail)
	recaps.sort()
	return _join_names(recaps)


func _format_skill_forge_work_recaps(forge_actions) -> String:
	if typeof(forge_actions) != TYPE_DICTIONARY:
		return ""

	var recaps: Array[String] = []
	for agent_id in forge_actions.keys():
		var receipt: Dictionary = forge_actions.get(agent_id, {})
		var completed_count := int(receipt.get("completed_actions", 0))
		if completed_count <= 0:
			continue
		var agent_name := str(receipt.get("name", str(agent_id).capitalize())).strip_edges()
		if agent_name == "":
			agent_name = "Crew"
		var skill_name := str(receipt.get("skill_name", "Skill Run")).strip_edges()
		if skill_name == "":
			skill_name = "Skill Run"
		var detail := "%s ran %s" % [agent_name, skill_name]
		if completed_count > 1:
			detail += " x%s" % completed_count
		if not recaps.has(detail):
			recaps.append(detail)
	recaps.sort()
	return _join_names(recaps)


func _format_completed_crew_mission_names(crew_missions) -> String:
	if typeof(crew_missions) != TYPE_DICTIONARY:
		return ""

	var names: Array[String] = []
	for mission_id in crew_missions.keys():
		var receipt: Dictionary = crew_missions.get(mission_id, {})
		if str(receipt.get("status", "")) != "done":
			continue
		var mission_label := str(receipt.get("label", "Crew Mission")).strip_edges()
		var agent_name := str(receipt.get("agent_name", "")).strip_edges()
		var detail := mission_label if mission_label != "" else "Crew Mission"
		if agent_name != "" and not detail.contains(agent_name):
			detail = "%s's %s" % [agent_name, detail]
		detail += _format_mission_preference_suffix(receipt)
		if not names.has(detail):
			names.append(detail)
	names.sort()
	return _join_names(names)


func _format_mission_preference_suffix(mission: Dictionary) -> String:
	var source := str(mission.get("preference_source", "")).strip_edges()
	var label := str(mission.get("preference_label", "")).strip_edges()
	if source == "" and label == "":
		return ""
	if source == "":
		return " [%s]" % label
	if label == "":
		return " [%s]" % _readable_social_preference_source(source)
	return " [%s: %s]" % [_readable_social_preference_source(source), label]


func _format_social_preference_suffix(event: Dictionary) -> String:
	var source := str(event.get("social_preference_source", "")).strip_edges()
	var label := str(event.get("social_preference_label", "")).strip_edges()
	if source == "" or label == "":
		return ""
	var suffix := " [%s: %s]" % [_readable_social_preference_source(source), label]
	var origin_source := str(event.get("social_preference_origin_source", "")).strip_edges()
	var origin_label := str(event.get("social_preference_origin_label", "")).strip_edges()
	if origin_source != "" and origin_label != "" and not (origin_source == source and origin_label == label):
		suffix += " [%s: %s]" % [_readable_social_preference_source(origin_source), origin_label]
	return suffix


func _format_skill_forge_suffix(event: Dictionary) -> String:
	var forge_run_id := str(event.get("forge_run_id", "")).strip_edges()
	var skill_name := str(event.get("skill_name", "")).strip_edges()
	if forge_run_id == "" and skill_name == "":
		return ""
	if skill_name == "":
		skill_name = "Skill Run"
	return " [Forge: %s]" % skill_name


func _format_social_preference_origin_detail(receipt: Dictionary) -> String:
	var origin_source := str(receipt.get("last_origin_source", "")).strip_edges()
	var origin_label := str(receipt.get("last_origin_label", "")).strip_edges()
	if origin_source == "" or origin_label == "":
		return ""
	return "%s: %s" % [_readable_social_preference_source(origin_source), origin_label]


func _readable_social_preference_source(source: String) -> String:
	match source.strip_edges():
		"memory", "remembered_help":
			return "Memory"
		"truce":
			return "Truce"
		"repeated_help":
			return "Streak"
		"completed_order":
			return "Follow-up"
		"completed_mission":
			return "Momentum"
		"ignored_ask":
			return "Pressure"
		"held_truce":
			return "Held"
	return source.replace("_", " ").capitalize()


func _join_names(names: Array[String]) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var last := names[names.size() - 1]
	var head := names.slice(0, names.size() - 1)
	return "%s, and %s" % [", ".join(head), last]


func _format_resource_list(gains) -> String:
	if typeof(gains) != TYPE_DICTIONARY:
		return ""

	var parts: Array[String] = []
	for resource_id in ["fiber", "grain", "stone"]:
		var amount := int(gains.get(resource_id, 0))
		if amount > 0:
			parts.append("%s %s" % [amount, _pretty_resource_name(resource_id)])
	return ", ".join(parts)


func _format_crafted_cost_list(cost) -> String:
	if typeof(cost) != TYPE_DICTIONARY:
		return ""

	var parts: Array[String] = []
	for item_id in ["fence_kit", "seed_bundle", "rush_kit"]:
		var amount := int(cost.get(item_id, 0))
		if amount > 0:
			parts.append("%s %s" % [amount, _pretty_crafted_name(item_id)])
	return ", ".join(parts)


func _format_cost(cost: Dictionary) -> String:
	return _format_resource_list(cost)


func _pretty_resource_name(resource_id: String) -> String:
	match resource_id:
		"fiber":
			return "Fiber"
		"grain":
			return "Grain"
		"stone":
			return "Stone"
	return resource_id.capitalize()


func _pretty_crafted_name(item_id: String) -> String:
	match item_id:
		"fence_kit":
			return "Fence Kit"
		"seed_bundle":
			return "Seed Bundle"
		"rush_kit":
			return "Rush Kit"
	return item_id.replace("_", " ").capitalize()


func _pretty_item_name(item_id: String) -> String:
	return item_id.replace("_", " ")


func _on_grid_visibility_changed(is_visible: bool) -> void:
	grid_manager.set_grid_visible(is_visible)
	if _player_progress != null:
		_player_progress.set_view_toggle("grid", is_visible)
	game_ui.show_message("Grid on." if is_visible else "Grid off.")


func _on_shadows_changed(is_enabled: bool) -> void:
	_set_shadows_enabled(is_enabled)
	if _player_progress != null:
		_player_progress.set_view_toggle("shadows", is_enabled)


func _on_ambient_occlusion_changed(is_enabled: bool) -> void:
	_set_ambient_occlusion_enabled(is_enabled)
	if _player_progress != null:
		_player_progress.set_view_toggle("ambient_occlusion", is_enabled)


func _set_shadows_enabled(is_enabled: bool, announce: bool = true) -> void:
	if _sun:
		_sun.shadow_enabled = is_enabled
	if announce:
		game_ui.show_message("Soft shadows on." if is_enabled else "Soft shadows off.")


func _set_ambient_occlusion_enabled(is_enabled: bool, announce: bool = true) -> void:
	if _environment:
		_environment.ssao_enabled = is_enabled
	if announce:
		game_ui.show_message("Ambient occlusion on." if is_enabled else "Ambient occlusion off.")

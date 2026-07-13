extends SceneTree

const PlayerProgressScript := preload("res://scripts/systems/PlayerProgress.gd")
const FIRST_LESSON := "run_starter"
const SECOND_LESSON := "read_receipt"
const HARVEST_PROGRAM := "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Harvest Crops run\"\n}"
const UPDATED_HARVEST_PROGRAM := "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"My exact harvest replacement\"\n}\n"
const CLEAR_PROGRAM := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}"

var _test_path: String


func _initialize() -> void:
	_test_path = OS.get_temp_dir().path_join("agentville-player-progress-%s.json" % OS.get_process_id())
	_cleanup()
	call_deferred("_run")


func _run() -> void:
	if not _test_default_path_contract():
		return
	if not _test_missing_file_defaults():
		return
	if not _test_immediate_roundtrip():
		return
	if not _test_corrupt_file_recovery():
		return
	if not _test_structural_recovery():
		return
	if not _test_mastery_gating_recovery():
		return
	if not _test_disk_disabled_mode():
		return

	_cleanup()
	quit()


func _test_default_path_contract() -> bool:
	if PlayerProgressScript.DEFAULT_PATH != "user://agentville_progress.json":
		_fail("Player progress default path changed. path=%s" % PlayerProgressScript.DEFAULT_PATH)
		return false
	var default_progress = PlayerProgressScript.new()
	if default_progress.get_storage_path() != "user://agentville_progress.json":
		_fail("Default PlayerProgress instance did not use the required user path.")
		return false
	return true


func _test_missing_file_defaults() -> bool:
	var progress = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	var fresh: Dictionary = progress.load()
	if fresh != _expected_fresh_progress():
		_fail("Missing progress file did not produce normalized fresh defaults. progress=%s" % str(fresh))
		return false
	if FileAccess.file_exists(_test_path):
		_fail("Loading a missing progress file wrote to disk before any change.")
		return false
	return true


func _test_immediate_roundtrip() -> bool:
	var progress = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	progress.load()

	if not progress.complete_lesson(FIRST_LESSON, SECOND_LESSON):
		_fail("Completing a lesson did not persist.")
		return false
	if not progress.complete_lesson(FIRST_LESSON, SECOND_LESSON):
		_fail("Completing an already-completed lesson was rejected.")
		return false
	var lesson_reload = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	lesson_reload.load()
	if not lesson_reload.is_lesson_completed(FIRST_LESSON) or lesson_reload.get_current_lesson() != SECOND_LESSON:
		_fail("Completed/current lesson state did not save immediately.")
		return false
	if lesson_reload.get_completed_lessons() != [FIRST_LESSON]:
		_fail("Completing the same lesson twice created duplicate mastery state. completed=%s" % str(lesson_reload.get_completed_lessons()))
		return false
	if not progress.set_current_lesson("debug_guard"):
		_fail("Setting the current lesson did not persist.")
		return false
	var current_lesson_reload = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	current_lesson_reload.load()
	if current_lesson_reload.get_current_lesson() != "debug_guard":
		_fail("Current lesson setter did not save immediately.")
		return false

	if not progress.save_program("Harvest Ready Corn", HARVEST_PROGRAM):
		_fail("Saving a named program failed.")
		return false
	if not progress.save_program("Clear Brush", CLEAR_PROGRAM):
		_fail("Saving the second named program failed.")
		return false
	if not progress.save_program("Harvest Ready Corn", UPDATED_HARVEST_PROGRAM):
		_fail("Replacing a named program failed.")
		return false
	var program_reload = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	program_reload.load()
	if program_reload.list_programs() != ["Clear Brush", "Harvest Ready Corn"]:
		_fail("Named program shelf did not reload in deterministic order. names=%s" % str(program_reload.list_programs()))
		return false
	if program_reload.get_program("Harvest Ready Corn") != UPDATED_HARVEST_PROGRAM or program_reload.get_program("Clear Brush") != CLEAR_PROGRAM:
		_fail("Saved or replaced multiline program source did not roundtrip exactly.")
		return false

	if not progress.set_view_toggle("grid", true):
		_fail("Grid toggle did not persist.")
		return false
	if not progress.set_view_toggle("shadows", false):
		_fail("Shadows toggle did not persist.")
		return false
	if not progress.set_view_toggle("ao", false):
		_fail("AO toggle alias did not persist.")
		return false
	var toggle_reload = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	var reloaded: Dictionary = toggle_reload.load()
	if reloaded.get("view_toggles", {}) != {
		"grid": true,
		"shadows": false,
		"ambient_occlusion": false
	}:
		_fail("View-toggle state did not roundtrip. toggles=%s" % str(reloaded.get("view_toggles", {})))
		return false
	if toggle_reload.get_view_toggle("ambient_occlusion") or toggle_reload.get_view_toggle("ao"):
		_fail("AO aliases did not both report the persisted false value.")
		return false

	var serialized_file := FileAccess.open(_test_path, FileAccess.READ)
	if serialized_file == null:
		_fail("Persisted progress file could not be reopened.")
		return false
	var serialized := serialized_file.get_as_text()
	serialized_file = null
	var parsed = JSON.parse_string(serialized)
	if typeof(parsed) != TYPE_DICTIONARY or not _contains_json_values_only(parsed):
		_fail("Persisted progress was not primitive JSON. data=%s" % str(parsed))
		return false
	return true


func _test_corrupt_file_recovery() -> bool:
	if not _write_test_file("{ this is not valid progress JSON"):
		return false

	var recovered = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	var recovered_state: Dictionary = recovered.load()
	if recovered_state != _expected_fresh_progress():
		_fail("Corrupt progress did not recover to fresh defaults. progress=%s" % str(recovered_state))
		return false
	if not recovered.save_program("Recovered Skill", HARVEST_PROGRAM):
		_fail("Fresh state after corrupt recovery could not be saved.")
		return false
	var repaired = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	repaired.load()
	if repaired.get_program("Recovered Skill") != HARVEST_PROGRAM:
		_fail("First mutation after corrupt recovery did not repair the progress file.")
		return false
	return true


func _test_structural_recovery() -> bool:
	if not _write_test_file(JSON.stringify(["progress", "must", "be", "an", "object"])):
		return false
	var non_dictionary = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	var non_dictionary_state: Dictionary = non_dictionary.load()
	if non_dictionary_state != _expected_fresh_progress():
		_fail("Non-dictionary JSON did not recover to fresh defaults. progress=%s" % str(non_dictionary_state))
		return false
	if not non_dictionary.set_current_lesson(SECOND_LESSON):
		_fail("State recovered from non-dictionary JSON could not be saved.")
		return false
	var non_dictionary_reload = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	non_dictionary_reload.load()
	if non_dictionary_reload.get_current_lesson() != SECOND_LESSON:
		_fail("Mutation after non-dictionary recovery did not repair the file.")
		return false

	var invalid_shapes := {
		"version": "old",
		"completed_lessons": "run_starter",
		"current_lesson": 17,
		"saved_programs": [HARVEST_PROGRAM],
		"view_toggles": {
			"grid": "on",
			"shadows": 0,
			"ambient_occlusion": null,
			"unknown_toggle": true
		}
	}
	if not _write_test_file(JSON.stringify(invalid_shapes)):
		return false
	var normalized = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	var normalized_state: Dictionary = normalized.load()
	if normalized_state != _expected_fresh_progress():
		_fail("Invalid progress field shapes did not normalize to field defaults. progress=%s" % str(normalized_state))
		return false
	if not normalized.save_program("Normalized Skill", CLEAR_PROGRAM):
		_fail("State recovered from invalid field shapes could not be saved.")
		return false
	var normalized_reload = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	normalized_reload.load()
	if normalized_reload.get_program("Normalized Skill") != CLEAR_PROGRAM:
		_fail("Mutation after invalid-shape recovery did not repair the file.")
		return false
	return true


func _test_disk_disabled_mode() -> bool:
	_cleanup()
	var memory_only = PlayerProgressScript.new(_test_path, false, FIRST_LESSON)
	memory_only.load()
	if not memory_only.complete_lesson(FIRST_LESSON, SECOND_LESSON):
		_fail("Memory-only lesson mutation was rejected.")
		return false
	if not memory_only.save_program("Memory Skill", CLEAR_PROGRAM):
		_fail("Memory-only program mutation was rejected.")
		return false
	if not memory_only.set_view_toggles({"grid": true, "shadows": false, "ao": false}):
		_fail("Memory-only view-toggle mutation was rejected.")
		return false
	if FileAccess.file_exists(_test_path):
		_fail("Disk-disabled progress wrote its injected path.")
		return false
	var state: Dictionary = memory_only.snapshot()
	if state.get("current_lesson", "") != SECOND_LESSON or state.get("saved_programs", {}).get("Memory Skill", "") != CLEAR_PROGRAM:
		_fail("Disk-disabled progress did not retain in-memory changes.")
		return false
	return true


func _test_mastery_gating_recovery() -> bool:
	var inconsistent_state := {
		"version": 1,
		"completed_lessons": [SECOND_LESSON],
		"current_lesson": "author_final",
		"saved_programs": {"Keep Me": CLEAR_PROGRAM},
		"view_toggles": {
			"grid": true,
			"shadows": false,
			"ambient_occlusion": false
		}
	}
	if not _write_test_file(JSON.stringify(inconsistent_state)):
		return false

	var recovered = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	recovered.load()
	if not recovered.normalize_lesson_sequence([FIRST_LESSON, SECOND_LESSON, "author_final"]):
		_fail("Inconsistent lesson sequence could not be normalized and persisted.")
		return false
	if recovered.get_completed_lessons() != [] or recovered.get_current_lesson() != FIRST_LESSON:
		_fail("Out-of-order mastery bypassed lesson 1. state=%s" % str(recovered.snapshot()))
		return false
	if recovered.get_program("Keep Me") != CLEAR_PROGRAM or recovered.get_view_toggles() != inconsistent_state["view_toggles"]:
		_fail("Lesson normalization discarded unrelated program or view state.")
		return false

	var reloaded = PlayerProgressScript.new(_test_path, true, FIRST_LESSON)
	reloaded.load()
	if reloaded.get_completed_lessons() != [] or reloaded.get_current_lesson() != FIRST_LESSON:
		_fail("Normalized mastery sequence did not survive reload. state=%s" % str(reloaded.snapshot()))
		return false
	return true


func _expected_fresh_progress() -> Dictionary:
	return {
		"version": 1,
		"completed_lessons": [],
		"current_lesson": FIRST_LESSON,
		"saved_programs": {},
		"view_toggles": {
			"grid": false,
			"shadows": true,
			"ambient_occlusion": true
		}
	}


func _contains_json_values_only(value) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for child in value:
				if not _contains_json_values_only(child):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value.keys():
				if typeof(key) != TYPE_STRING or not _contains_json_values_only(value[key]):
					return false
			return true
	return false


func _write_test_file(contents: String) -> bool:
	var file := FileAccess.open(_test_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not arrange progress recovery input.")
		return false
	file.store_string(contents)
	file = null
	return true


func _cleanup() -> void:
	if _test_path == "" or not FileAccess.file_exists(_test_path):
		return
	DirAccess.remove_absolute(_test_path)


func _fail(message: String) -> void:
	_cleanup()
	push_error(message)
	quit(1)

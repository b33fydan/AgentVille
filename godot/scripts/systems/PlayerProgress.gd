class_name PlayerProgress
extends RefCounted

signal progress_changed(progress: Dictionary)

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://agentville_progress.json"
const DEFAULT_VIEW_TOGGLES := {
	"grid": false,
	"shadows": true,
	"ambient_occlusion": true
}

var _storage_path: String
var _disk_enabled: bool
var _default_lesson_id: String
var _progress: Dictionary


func _init(
	storage_path: String = DEFAULT_PATH,
	disk_enabled: bool = true,
	default_lesson_id: String = ""
) -> void:
	_storage_path = storage_path
	_disk_enabled = disk_enabled
	_default_lesson_id = default_lesson_id.strip_edges()
	_progress = _fresh_progress()


func load() -> Dictionary:
	_progress = _fresh_progress()
	if not _disk_enabled or _storage_path.strip_edges() == "":
		return snapshot()
	if not FileAccess.file_exists(_storage_path):
		return snapshot()

	var file := FileAccess.open(_storage_path, FileAccess.READ)
	if file == null:
		return snapshot()
	var serialized := file.get_as_text()
	file = null

	var json := JSON.new()
	if json.parse(serialized) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return snapshot()

	_progress = _normalize_progress(json.data)
	return snapshot()


func save() -> bool:
	if not _disk_enabled:
		return true
	if _storage_path.strip_edges() == "":
		return false

	var file := FileAccess.open(_storage_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_progress, "\t"))
	file = null
	return true


func snapshot() -> Dictionary:
	return _progress.duplicate(true)


func reset() -> bool:
	_progress = _fresh_progress()
	return _persist_change()


func get_storage_path() -> String:
	return _storage_path


func is_disk_enabled() -> bool:
	return _disk_enabled


func get_completed_lessons() -> Array:
	return (_progress.get("completed_lessons", []) as Array).duplicate()


func is_lesson_completed(lesson_id: String) -> bool:
	return (_progress.get("completed_lessons", []) as Array).has(lesson_id.strip_edges())


func get_current_lesson() -> String:
	return str(_progress.get("current_lesson", ""))


func complete_lesson(lesson_id: String, next_lesson_id: String = "") -> bool:
	var normalized_id := lesson_id.strip_edges()
	if normalized_id == "":
		return false

	var did_change := false
	var completed: Array = _progress.get("completed_lessons", [])
	if not completed.has(normalized_id):
		completed.append(normalized_id)
		_progress["completed_lessons"] = completed
		did_change = true

	var normalized_next_id := next_lesson_id.strip_edges()
	if normalized_next_id != "" and get_current_lesson() != normalized_next_id:
		_progress["current_lesson"] = normalized_next_id
		did_change = true

	return _persist_change() if did_change else true


func set_current_lesson(lesson_id: String) -> bool:
	var normalized_id := lesson_id.strip_edges()
	if get_current_lesson() == normalized_id:
		return true
	_progress["current_lesson"] = normalized_id
	return _persist_change()


func normalize_lesson_sequence(ordered_lesson_ids: Array) -> bool:
	var ordered_ids: Array[String] = []
	for lesson_value in ordered_lesson_ids:
		if typeof(lesson_value) != TYPE_STRING:
			continue
		var lesson_id := str(lesson_value).strip_edges()
		if lesson_id != "" and not ordered_ids.has(lesson_id):
			ordered_ids.append(lesson_id)

	var stored_completed := get_completed_lessons()
	var contiguous_completed: Array[String] = []
	for lesson_id in ordered_ids:
		if not stored_completed.has(lesson_id):
			break
		contiguous_completed.append(lesson_id)

	var normalized_current := ""
	if contiguous_completed.size() < ordered_ids.size():
		normalized_current = ordered_ids[contiguous_completed.size()]
	if stored_completed == contiguous_completed and get_current_lesson() == normalized_current:
		return true

	_progress["completed_lessons"] = contiguous_completed
	_progress["current_lesson"] = normalized_current
	return _persist_change()


func get_saved_programs() -> Dictionary:
	return (_progress.get("saved_programs", {}) as Dictionary).duplicate(true)


func list_programs() -> Array[String]:
	var names: Array[String] = []
	for program_name in (_progress.get("saved_programs", {}) as Dictionary).keys():
		names.append(str(program_name))
	names.sort()
	return names


func get_program(program_name: String) -> String:
	var normalized_name := program_name.strip_edges()
	return str((_progress.get("saved_programs", {}) as Dictionary).get(normalized_name, ""))


func save_program(program_name: String, source_text: String) -> bool:
	var normalized_name := program_name.strip_edges()
	if normalized_name == "":
		return false

	var programs: Dictionary = _progress.get("saved_programs", {})
	if programs.get(normalized_name, null) == source_text:
		return true
	programs[normalized_name] = source_text
	_progress["saved_programs"] = programs
	return _persist_change()


func remove_program(program_name: String) -> bool:
	var normalized_name := program_name.strip_edges()
	var programs: Dictionary = _progress.get("saved_programs", {})
	if normalized_name == "" or not programs.has(normalized_name):
		return false
	programs.erase(normalized_name)
	_progress["saved_programs"] = programs
	return _persist_change()


func get_view_toggles() -> Dictionary:
	return (_progress.get("view_toggles", DEFAULT_VIEW_TOGGLES) as Dictionary).duplicate(true)


func get_view_toggle(toggle_id: String) -> bool:
	var normalized_id := _canonical_view_toggle_id(toggle_id)
	if normalized_id == "":
		return false
	return bool((_progress.get("view_toggles", DEFAULT_VIEW_TOGGLES) as Dictionary).get(
		normalized_id,
		DEFAULT_VIEW_TOGGLES[normalized_id]
	))


func set_view_toggle(toggle_id: String, is_enabled: bool) -> bool:
	var normalized_id := _canonical_view_toggle_id(toggle_id)
	if normalized_id == "":
		return false

	var toggles: Dictionary = _progress.get("view_toggles", DEFAULT_VIEW_TOGGLES.duplicate(true))
	if bool(toggles.get(normalized_id, DEFAULT_VIEW_TOGGLES[normalized_id])) == is_enabled:
		return true
	toggles[normalized_id] = is_enabled
	_progress["view_toggles"] = toggles
	return _persist_change()


func set_view_toggles(view_toggles: Dictionary) -> bool:
	var toggles := get_view_toggles()
	var did_change := false
	for toggle_id in view_toggles.keys():
		var normalized_id := _canonical_view_toggle_id(str(toggle_id))
		if normalized_id == "" or typeof(view_toggles[toggle_id]) != TYPE_BOOL:
			continue
		var is_enabled: bool = view_toggles[toggle_id]
		if bool(toggles.get(normalized_id, DEFAULT_VIEW_TOGGLES[normalized_id])) == is_enabled:
			continue
		toggles[normalized_id] = is_enabled
		did_change = true

	if not did_change:
		return true
	_progress["view_toggles"] = toggles
	return _persist_change()


func _fresh_progress() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"completed_lessons": [],
		"current_lesson": _default_lesson_id,
		"saved_programs": {},
		"view_toggles": DEFAULT_VIEW_TOGGLES.duplicate(true)
	}


func _normalize_progress(raw_progress: Dictionary) -> Dictionary:
	var normalized := _fresh_progress()

	var completed_lessons: Array[String] = []
	var raw_completed = raw_progress.get("completed_lessons", [])
	if typeof(raw_completed) == TYPE_ARRAY:
		for lesson_value in raw_completed:
			if typeof(lesson_value) != TYPE_STRING:
				continue
			var lesson_id := str(lesson_value).strip_edges()
			if lesson_id != "" and not completed_lessons.has(lesson_id):
				completed_lessons.append(lesson_id)
	normalized["completed_lessons"] = completed_lessons

	var raw_current_lesson = raw_progress.get("current_lesson", _default_lesson_id)
	if typeof(raw_current_lesson) == TYPE_STRING:
		normalized["current_lesson"] = str(raw_current_lesson).strip_edges()

	var normalized_programs := {}
	var raw_programs = raw_progress.get("saved_programs", {})
	if typeof(raw_programs) == TYPE_DICTIONARY:
		for program_name_value in raw_programs.keys():
			var source_value = raw_programs[program_name_value]
			if typeof(source_value) != TYPE_STRING:
				continue
			var program_name := str(program_name_value).strip_edges()
			if program_name != "":
				normalized_programs[program_name] = str(source_value)
	normalized["saved_programs"] = normalized_programs

	var normalized_toggles := DEFAULT_VIEW_TOGGLES.duplicate(true)
	var raw_toggles = raw_progress.get("view_toggles", {})
	if typeof(raw_toggles) == TYPE_DICTIONARY:
		for toggle_id in raw_toggles.keys():
			var normalized_id := _canonical_view_toggle_id(str(toggle_id))
			if normalized_id == "" or typeof(raw_toggles[toggle_id]) != TYPE_BOOL:
				continue
			normalized_toggles[normalized_id] = raw_toggles[toggle_id]
	normalized["view_toggles"] = normalized_toggles

	return normalized


func _canonical_view_toggle_id(toggle_id: String) -> String:
	match toggle_id.strip_edges().to_lower().replace(" ", "_"):
		"grid":
			return "grid"
		"shadows", "shadow":
			return "shadows"
		"ao", "ambient_occlusion":
			return "ambient_occlusion"
	return ""


func _persist_change() -> bool:
	var did_save := save()
	progress_changed.emit(snapshot())
	return did_save

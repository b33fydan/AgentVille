extends SceneTree

const SkillLessonLibraryScript := preload("res://scripts/systems/SkillLessonLibrary.gd")
const SkillTutorLibraryScript := preload("res://scripts/systems/SkillTutorLibrary.gd")

const GENERIC_PRAISE := ["good job", "great work", "well done", "excellent", "amazing", "nice work"]

var _failed := false
var _sentence_pattern := RegEx.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _sentence_pattern.compile("[.!?](\\s|$)") != OK:
		_fail("Tutor smoke could not compile its sentence-count pattern.")
		return
	_test_pipeline_registry()
	if _failed:
		return
	_test_validator_coverage()
	if _failed:
		return
	_test_lesson_escalation()
	if not _failed:
		quit()


func _test_pipeline_registry() -> void:
	var tutor = SkillTutorLibraryScript.new()
	if tutor.parse_classes() != ["lexical", "syntax", "structure", "identity"]:
		_fail("Tutor parse-class registry drifted. classes=%s" % str(tutor.parse_classes()))
		return
	for error_class in tutor.parse_classes():
		if not tutor.has_parse_copy(str(error_class)):
			_fail("Tutor is missing parse copy. class=%s" % str(error_class))
			return
		_assert_line(tutor.line_for("parse", str(error_class)), "parse.%s" % str(error_class))
		if _failed:
			return

	for drift_level in ["steady", "wobbly", "hallucinating"]:
		_assert_deterministic_line(tutor, "drift", drift_level, {})
		if _failed:
			return
	for condition in ["always", "inspect.has_brush", "crop.needs_tending", "crop.ready", "tile.empty"]:
		for allowed in [false, true]:
			_assert_deterministic_line(tutor, "guard", condition, {"allowed": allowed})
			if _failed:
				return
	for lifecycle_state in ["order", "order_blocked", "pending", "retrying", "replaced", "cancelled", "timeout"]:
		_assert_deterministic_line(tutor, "lifecycle", lifecycle_state, {})
		if _failed:
			return
	for check_type in ["tile_state", "crop_state", "inventory_delta"]:
		for passed in [false, true]:
			_assert_deterministic_line(tutor, "check", check_type, {"passed": passed})
			if _failed:
				return

	var registry: Dictionary = tutor.registry()
	if registry.get("drift_levels", []) != ["steady", "wobbly", "hallucinating"] or registry.get("lesson_escalation", []) != [1, 2, 3]:
		_fail("Tutor registry does not expose drift and lesson escalation coverage. registry=%s" % str(registry))
		return
	_assert_line(tutor.line_for("unknown_pipeline_state"), "pipeline fallback")


func _test_validator_coverage() -> void:
	var tutor = SkillTutorLibraryScript.new()
	var validator_source := FileAccess.get_file_as_string("res://scripts/systems/SkillSpecValidator.gd")
	if validator_source == "":
		_fail("Tutor smoke could not read SkillSpecValidator.gd.")
		return
	var code_pattern := RegEx.new()
	if code_pattern.compile("_add_issue\\([^,]+,\\s*\\\"([a-z_]+)\\\"") != OK:
		_fail("Tutor smoke could not compile its validator-code pattern.")
		return
	var validator_codes := {}
	for match_result in code_pattern.search_all(validator_source):
		validator_codes[match_result.get_string(1)] = true
	if validator_codes.is_empty():
		_fail("Tutor smoke found no validator issue codes.")
		return
	for code in validator_codes.keys():
		if not tutor.has_validator_copy(str(code)):
			_fail("Tutor is missing current validator copy. code=%s" % str(code))
			return
		_assert_deterministic_line(tutor, "validator", str(code), {})
		if _failed:
			return
	for registered_code in tutor.validator_codes():
		if not validator_codes.has(str(registered_code)):
			_fail("Tutor registry contains a stale validator code. code=%s" % str(registered_code))
			return
	if tutor.has_validator_copy("future_unmapped_issue"):
		_fail("Unknown validator code should use fallback rather than claim explicit coverage.")
		return
	_assert_line(tutor.line_for("validator", "future_unmapped_issue"), "validator fallback")


func _test_lesson_escalation() -> void:
	var tutor = SkillTutorLibraryScript.new()
	var lessons = SkillLessonLibraryScript.new()
	for lesson_id in lessons.get_lesson_ids():
		var lesson: Dictionary = lessons.get_lesson(str(lesson_id))
		var authored: Dictionary = lesson.get("tutor", {})
		for key in ["success", "failure", "first_hint", "targeted_hint"]:
			_assert_line(str(authored.get(key, "")), "%s.%s" % [str(lesson_id), key])
			if _failed:
				return
		for diff_line in authored.get("fix_diff", []):
			_assert_diff_line(str(diff_line), "%s.fix_diff" % str(lesson_id))
			if _failed:
				return

		var first_lines: Array[String] = tutor.lesson_hint_lines(lesson, 1, false)
		var second_lines: Array[String] = tutor.lesson_hint_lines(lesson, 2, false)
		var third_lines: Array[String] = tutor.lesson_hint_lines(lesson, 3, false)
		var success_lines: Array[String] = tutor.lesson_hint_lines(lesson, 0, true)
		if first_lines != [str(authored.get("failure", "")), str(authored.get("first_hint", ""))]:
			_fail("First lesson failure did not use the concept nudge. lesson=%s lines=%s" % [str(lesson_id), str(first_lines)])
			return
		if second_lines != [str(authored.get("failure", "")), str(authored.get("targeted_hint", ""))]:
			_fail("Second lesson failure did not use the targeted hint. lesson=%s lines=%s" % [str(lesson_id), str(second_lines)])
			return
		if third_lines.slice(0, 2) != second_lines or third_lines.slice(2) != authored.get("fix_diff", []):
			_fail("Third lesson failure did not reveal the authored fix diff. lesson=%s lines=%s" % [str(lesson_id), str(third_lines)])
			return
		if success_lines != [str(authored.get("success", ""))]:
			_fail("Lesson success did not use its authored concept line. lesson=%s" % str(lesson_id))
			return
		if tutor.lesson_hint(lesson, 3, false) != tutor.lesson_hint(lesson, 3, false):
			_fail("Lesson tutor escalation is not deterministic. lesson=%s" % str(lesson_id))
			return


func _assert_deterministic_line(tutor, state_key: String, detail_key: String, context: Dictionary) -> void:
	var first: String = tutor.line_for(state_key, detail_key, context)
	var second: String = tutor.line_for(state_key, detail_key, context)
	if first != second:
		_fail("Tutor lookup is not deterministic. key=%s.%s" % [state_key, detail_key])
		return
	_assert_line(first, "%s.%s" % [state_key, detail_key])


func _assert_line(line: String, key: String) -> void:
	line = line.strip_edges()
	if line == "":
		_fail("Tutor copy is blank. key=%s" % key)
		return
	if line.contains("!"):
		_fail("Tutor copy uses an exclamation mark. key=%s line=%s" % [key, line])
		return
	if line.length() > 220:
		_fail("Tutor copy is not short enough for the trace. key=%s length=%s" % [key, line.length()])
		return
	if _sentence_pattern.search_all(line).size() > 2:
		_fail("Tutor copy exceeds two sentences. key=%s line=%s" % [key, line])
		return
	var lower := line.to_lower()
	for phrase in GENERIC_PRAISE:
		if lower.contains(phrase):
			_fail("Tutor copy uses generic praise. key=%s phrase=%s" % [key, phrase])
			return


func _assert_diff_line(line: String, key: String) -> void:
	line = line.strip_edges()
	if line == "" or (not line.begins_with("-") and not line.begins_with("+")):
		_fail("Tutor fix diff needs an added or removed line. key=%s line=%s" % [key, line])
		return
	if line.contains("!"):
		_fail("Tutor fix diff uses an exclamation mark. key=%s line=%s" % [key, line])


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)

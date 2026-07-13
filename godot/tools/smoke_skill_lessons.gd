extends SceneTree

const SkillLessonLibraryScript := preload("res://scripts/systems/SkillLessonLibrary.gd")
const SkillScriptParserScript := preload("res://scripts/systems/SkillScriptParser.gd")
const SkillSpecValidatorScript := preload("res://scripts/systems/SkillSpecValidator.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_ladder_integrity()
	if _failed:
		return
	_test_starting_sources()
	if _failed:
		return
	_test_completion_conditions()
	if not _failed:
		quit()


func _test_ladder_integrity() -> void:
	var library = SkillLessonLibraryScript.new()
	var ids: Array = library.get_lesson_ids()
	if ids.size() != 10:
		_fail("Lesson ladder must contain exactly 10 lessons. ids=%s" % str(ids))
		return
	var unique := {}
	var previous_tier_index := -1
	for index in range(ids.size()):
		var lesson_id := str(ids[index])
		if lesson_id == "" or unique.has(lesson_id):
			_fail("Lesson ids must be non-empty and unique. id=%s" % lesson_id)
			return
		unique[lesson_id] = true
		var lesson: Dictionary = library.get_lesson(lesson_id)
		if lesson.is_empty() or int(lesson.get("order", 0)) != index + 1:
			_fail("Lesson order does not match the stable id order. lesson=%s" % str(lesson))
			return
		for field in ["title", "concept", "goal", "starting_editor_text", "completion_condition", "tutor"]:
			if not lesson.has(field):
				_fail("Lesson is missing required field %s. lesson=%s" % [field, lesson_id])
				return
		for text_field in ["title", "concept", "goal"]:
			if str(lesson.get(text_field, "")).strip_edges() == "":
				_fail("Lesson has blank %s copy. lesson=%s" % [text_field, lesson_id])
				return
		var tier_index: int = SkillLessonLibraryScript.TIER_ORDER.find(str(lesson.get("tier", "")))
		if tier_index < previous_tier_index or tier_index < 0:
			_fail("Lesson tiers are not ordered run_read -> modify -> debug -> author. lesson=%s" % lesson_id)
			return
		previous_tier_index = tier_index
		var expected_requires := [] if index == 0 else [str(ids[index - 1])]
		if lesson.get("requires", []) != expected_requires:
			_fail("Lesson gating must require the immediately previous lesson. lesson=%s requires=%s" % [lesson_id, str(lesson.get("requires", []))])
			return
		if not library.completion_condition_evaluable(lesson.get("completion_condition", {})):
			_fail("Lesson completion condition is not declaratively evaluable. lesson=%s" % lesson_id)
			return
		var tutor: Dictionary = lesson.get("tutor", {})
		for tutor_key in ["success", "failure", "first_hint", "targeted_hint", "fix_diff"]:
			if not tutor.has(tutor_key):
				_fail("Lesson tutor copy is missing %s. lesson=%s" % [tutor_key, lesson_id])
				return
		if typeof(tutor.get("fix_diff", [])) != TYPE_ARRAY or tutor.get("fix_diff", []).is_empty():
			_fail("Lesson third hint needs a non-empty fix diff. lesson=%s" % lesson_id)
			return

	if library.first_lesson_id() != str(ids[0]) or library.next_lesson_id(str(ids[0])) != str(ids[1]) or library.next_lesson_id(str(ids[-1])) != "":
		_fail("Lesson first/next navigation drifted from the stable order.")
		return
	if not library.is_unlocked(str(ids[0]), []) or library.is_unlocked(str(ids[1]), []):
		_fail("Fresh progression did not unlock only the first lesson.")
		return
	if not library.is_unlocked(str(ids[1]), [str(ids[0])]):
		_fail("Completing lesson 1 did not unlock lesson 2.")
		return
	var snapshots: Array = library.list_lessons([str(ids[0])])
	if str(snapshots[0].get("state", "")) != "completed" or str(snapshots[1].get("state", "")) != "unlocked" or str(snapshots[2].get("state", "")) != "locked":
		_fail("Lesson list did not expose completed/unlocked/locked states. snapshots=%s" % str(snapshots))


func _test_starting_sources() -> void:
	var library = SkillLessonLibraryScript.new()
	var parser = SkillScriptParserScript.new()
	var validator = SkillSpecValidatorScript.new()
	var ids: Array = library.get_lesson_ids()
	for index in range(5):
		var lesson: Dictionary = library.get_lesson(str(ids[index]))
		var parsed: Dictionary = parser.parse(str(lesson.get("starting_editor_text", "")))
		if not bool(parsed.get("ok", false)):
			_fail("Non-debug lesson starting source did not parse. lesson=%s result=%s" % [str(ids[index]), str(parsed)])
			return
		var validation: Dictionary = validator.validate(parsed.get("spec", {}))
		if not bool(validation.get("valid", false)):
			_fail("Non-debug lesson starting source did not validate. lesson=%s validation=%s" % [str(ids[index]), str(validation)])
			return

	var unknown_tool: Dictionary = parser.parse(str(library.get_lesson("repair_unknown_tool").get("starting_editor_text", "")))
	if not bool(unknown_tool.get("ok", false)) or not _validation_has_code(validator.validate(unknown_tool.get("spec", {})), "unknown_tool"):
		_fail("Unknown-tool lesson did not reach the intended validator failure.")
		return
	var wrong_check: Dictionary = parser.parse(str(library.get_lesson("repair_verification").get("starting_editor_text", "")))
	if not bool(wrong_check.get("ok", false)) or not _validation_has_code(validator.validate(wrong_check.get("spec", {})), "unsupported_success_check"):
		_fail("Verification lesson did not reach the intended validator failure.")
		return
	for lesson_id in ["repair_syntax", "decompose_two_jobs"]:
		var parsed: Dictionary = parser.parse(str(library.get_lesson(lesson_id).get("starting_editor_text", "")))
		if bool(parsed.get("ok", true)):
			_fail("Parser-debug lesson unexpectedly started valid. lesson=%s" % lesson_id)
			return
	if str(library.get_lesson("author_plant_skill").get("starting_editor_text", "not blank")) != "":
		_fail("Author lesson must start from a blank editor.")
		return

	var first: Dictionary = library.get_lesson("run_brush_starter").get("completion_condition", {})
	var second: Dictionary = library.get_lesson("name_brush_receipt").get("completion_condition", {})
	var third: Dictionary = library.get_lesson("reassign_brush_agent").get("completion_condition", {})
	if str(first.get("action", "")) != "clear_brush" or str(second.get("action", "")) != "clear_brush" or str(third.get("action", "")) != "clear_brush":
		_fail("The first three lessons must remain distinct clear-brush runs.")
		return
	if str(first.get("receipt_label", "")) != "Clear Patch run" or str(second.get("receipt_label", "")) != "Brush Proof run" or str(third.get("agent_id", "")) != "bert":
		_fail("The first three clear-brush modifications drifted from starter -> receipt -> Bert.")
		return
	if first.get("allowed_origins", []) != ["workbench"]:
		_fail("Lesson 1 mastery must come from the real Workbench compile path.")


func _test_completion_conditions() -> void:
	var library = SkillLessonLibraryScript.new()
	for lesson_id_value in library.get_lesson_ids():
		var lesson_id := str(lesson_id_value)
		var lesson: Dictionary = library.get_lesson(lesson_id)
		var evidence := _matching_evidence(lesson)
		var evaluation: Dictionary = library.evaluate_completion(lesson_id, evidence)
		if not bool(evaluation.get("evaluable", false)) or not bool(evaluation.get("complete", false)):
			_fail("Matching real-run evidence did not complete lesson. lesson=%s evaluation=%s" % [lesson_id, str(evaluation)])
			return
		var wrong_origin: Dictionary = evidence.duplicate(true)
		wrong_origin["origin"] = "skill_forge"
		if bool(library.evaluate_completion(lesson_id, wrong_origin).get("complete", true)):
			_fail("Legacy Skill Forge origin incorrectly granted lesson mastery. lesson=%s" % lesson_id)
			return

		var failed_evidence: Dictionary = evidence.duplicate(true)
		failed_evidence["run"]["status"] = "failed"
		var failed_evaluation: Dictionary = library.evaluate_completion(lesson_id, failed_evidence)
		if bool(failed_evaluation.get("complete", true)) or not failed_evaluation.get("mismatches", []).has("status"):
			_fail("A failed run incorrectly satisfied a lesson. lesson=%s evaluation=%s" % [lesson_id, str(failed_evaluation)])
			return

		var required_failures: Array = lesson.get("completion_condition", {}).get("required_failure_keys", [])
		if not required_failures.is_empty():
			var skipped_debug: Dictionary = evidence.duplicate(true)
			skipped_debug["failure_keys"] = []
			if bool(library.evaluate_completion(lesson_id, skipped_debug).get("complete", true)):
				_fail("Debug lesson completed without first observing its intended failure. lesson=%s" % lesson_id)
				return


func _matching_evidence(lesson: Dictionary) -> Dictionary:
	var condition: Dictionary = lesson.get("completion_condition", {})
	var origins: Array = condition.get("allowed_origins", [])
	var source_text := str(lesson.get("starting_editor_text", ""))
	if bool(condition.get("requires_source_change", false)):
		source_text += "\n"
		if source_text.strip_edges() == str(lesson.get("starting_editor_text", "")).strip_edges():
			source_text += "# revised"
	if bool(condition.get("requires_nonempty_source", false)) and source_text.strip_edges() == "":
		source_text = "agent program"
	return {
		"player_initiated": true,
		"origin": str(origins[0]),
		"guard_condition": str(condition.get("guard_condition", "")),
		"target_source": str(condition.get("target_source", "")),
		"source_text": source_text,
		"failure_keys": condition.get("required_failure_keys", []).duplicate(),
		"run": {
			"status": str(condition.get("status", "")),
			"action": str(condition.get("action", "")),
			"agent_id": str(condition.get("agent_id", "")),
			"success_check_type": str(condition.get("check_type", "")),
			"receipt_label": str(condition.get("receipt_label", ""))
		},
		"check_verdict": {
			"passed": bool(condition.get("check_passed", true)),
			"check_type": str(condition.get("check_type", ""))
		}
	}


func _validation_has_code(validation: Dictionary, code: String) -> bool:
	for issue_list in [validation.get("errors", []), validation.get("warnings", [])]:
		if typeof(issue_list) != TYPE_ARRAY:
			continue
		for issue in issue_list:
			if typeof(issue) == TYPE_DICTIONARY and str(issue.get("code", "")) == code:
				return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)

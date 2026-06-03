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
		"## Skill Spec v0",
		"## Existing System Mapping",
		"## Safety Model",
		"## Implementation Plan",
		"## Questionnaire For The Big PRD Session",
		"## Recommended First Implementation Slice"
	]
	for section in required_sections:
		if not text.contains(section):
			_fail("Skill Forge PRD missing required section: %s" % section)
			return

	if not text.contains("SkillSpecValidator.gd"):
		_fail("Skill Forge PRD did not name the recommended validator slice.")
		return
	if not text.contains("What should a player say after their first successful Forge run?"):
		_fail("Skill Forge PRD questionnaire did not include the north-star prompt.")
		return


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)

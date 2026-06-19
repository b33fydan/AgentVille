extends SceneTree

const SkillForgeTemplateLibraryScript := preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")
const SkillSpecValidatorScript := preload("res://scripts/systems/SkillSpecValidator.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_starter_template_ids_are_deterministic()
	_test_templates_validate_cleanly()
	_test_template_previews_are_compact()
	_test_template_specs_are_returned_as_copies()
	if not _failed:
		quit()


func _test_starter_template_ids_are_deterministic() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var ids: Array = library.get_template_ids()
	if ids != ["tend_crops_starter", "clear_patch_starter", "harvest_crops_starter", "build_fence_starter"]:
		_fail("Starter template ids were not deterministic. ids=%s" % str(ids))
		return

	if not library.has_template("tend_crops_starter"):
		_fail("Tend Crops starter template was not registered.")
		return
	if not library.has_template("harvest_crops_starter"):
		_fail("Harvest Crops starter template was not registered.")
		return
	if not library.has_template("build_fence_starter"):
		_fail("Build Fence starter template was not registered.")
		return
	if library.has_template("summon_rain_starter"):
		_fail("Unknown starter template was reported as registered.")
		return


func _test_templates_validate_cleanly() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var validator = SkillSpecValidatorScript.new()

	for template_id in library.get_template_ids():
		var spec: Dictionary = library.get_template_spec(template_id)
		var result: Dictionary = validator.validate(spec)
		if not bool(result.get("valid", false)):
			_fail("Template %s did not validate. result=%s" % [template_id, str(result)])
			return
		if not result.get("warnings", []).is_empty():
			_fail("Template %s emitted warnings. result=%s" % [template_id, str(result)])
			return
		if str(spec.get("trigger", {}).get("type", "")) != "manual":
			_fail("Template %s was not manual-triggered." % template_id)
			return
		if str(spec.get("context", {}).get("target", "")) != "selected_tile":
			_fail("Template %s did not use selected tile context." % template_id)
			return
		if str(result.get("drift", {}).get("level", "")) != "steady":
			_fail("Template %s did not start steady. result=%s" % [template_id, str(result)])
			return


func _test_template_previews_are_compact() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var previews: Array = library.list_template_previews()
	if previews.size() != 4:
		_fail("Template preview count was wrong. previews=%s" % str(previews))
		return

	var tend_preview: Dictionary = library.get_template_preview("tend_crops_starter")
	if str(tend_preview.get("name", "")) != "Tend Crops":
		_fail("Tend Crops preview did not expose the readable name. preview=%s" % str(tend_preview))
		return
	if not str(tend_preview.get("lesson", "")).contains("success check"):
		_fail("Tend Crops preview did not name the lesson. preview=%s" % str(tend_preview))
		return
	var harvest_preview: Dictionary = library.get_template_preview("harvest_crops_starter")
	if str(harvest_preview.get("tools_label", "")) != "inspect_tile -> harvest_crop":
		_fail("Harvest Crops preview did not expose ordered harvest tools. preview=%s" % str(harvest_preview))
		return
	if str(harvest_preview.get("check_label", "")) != "inventory_delta on selected_tile":
		_fail("Harvest Crops preview did not expose the inventory success check. preview=%s" % str(harvest_preview))
		return
	if str(harvest_preview.get("receipt_label", "")) != "Harvest Crops run":
		_fail("Harvest Crops preview did not expose its receipt label. preview=%s" % str(harvest_preview))
		return
	var build_preview: Dictionary = library.get_template_preview("build_fence_starter")
	if str(build_preview.get("tools_label", "")) != "inspect_tile -> build_fence":
		_fail("Build Fence preview did not expose ordered fence tools. preview=%s" % str(build_preview))
		return
	if str(build_preview.get("check_label", "")) != "tile_state on selected_tile":
		_fail("Build Fence preview did not expose the tile-state success check. preview=%s" % str(build_preview))
		return
	if str(build_preview.get("receipt_label", "")) != "Build Fence run":
		_fail("Build Fence preview did not expose its receipt label. preview=%s" % str(build_preview))
		return

	for preview in previews:
		if typeof(preview) != TYPE_DICTIONARY:
			_fail("Template preview was not a dictionary. preview=%s" % str(preview))
			return
		if preview.has("steps"):
			_fail("Template previews should not expose full step data. preview=%s" % str(preview))
			return
		if int(preview.get("step_count", 0)) <= 0:
			_fail("Template preview did not include a step count. preview=%s" % str(preview))
			return


func _test_template_specs_are_returned_as_copies() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var spec: Dictionary = library.get_template_spec("clear_patch_starter")
	spec["tools"].append("summon_rain")
	spec["receipt"]["label"] = "Mutated"

	var fresh_spec: Dictionary = library.get_template_spec("clear_patch_starter")
	if fresh_spec.get("tools", []).has("summon_rain"):
		_fail("Template spec mutation leaked into the library. spec=%s" % str(fresh_spec))
		return
	if str(fresh_spec.get("receipt", {}).get("label", "")) == "Mutated":
		_fail("Nested template mutation leaked into the library. spec=%s" % str(fresh_spec))
		return

	var missing_spec: Dictionary = library.get_template_spec("missing_template")
	if not missing_spec.is_empty():
		_fail("Missing template did not return an empty spec. spec=%s" % str(missing_spec))
		return


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)

extends SceneTree

const SkillScriptParserScript := preload("res://scripts/systems/SkillScriptParser.gd")
const SkillSpecValidatorScript := preload("res://scripts/systems/SkillSpecValidator.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_canonical_program_compiles_cleanly()
	if _failed:
		return
	_test_each_starter_action_gets_matching_defaults()
	if _failed:
		return
	_test_optional_semicolons_and_case_insensitive_agent()
	if _failed:
		return
	_test_unknown_tool_and_condition_reach_validator()
	if _failed:
		return
	_test_parse_errors_are_positional_and_teaching_ready()
	if not _failed:
		quit()


func _test_canonical_program_compiles_cleanly() -> void:
	var parser = SkillScriptParserScript.new()
	var result: Dictionary = parser.parse(_canonical_program())
	if not bool(result.get("ok", false)):
		_fail("Canonical program did not parse. result=%s" % str(result))
		return
	var request: Dictionary = result.get("request", {})
	if request != {"agent_id": "marigold", "agent_name": "Marigold"}:
		_fail("Canonical agent identity was not normalized. request=%s" % str(request))
		return
	var spec: Dictionary = result.get("spec", {})
	if str(spec.get("id", "")) != "marigold_harvest_crops" or str(spec.get("name", "")) != "Harvest Crops":
		_fail("Canonical id/name synthesis drifted. spec=%s" % str(spec))
		return
	if spec.get("trigger", {}) != {"type": "manual"}:
		_fail("Canonical program did not synthesize a manual trigger. spec=%s" % str(spec))
		return
	if str(spec.get("context", {}).get("target", "")) != "selected_tile":
		_fail("Canonical observe statement did not map to selected_tile context. spec=%s" % str(spec))
		return
	if spec.get("tools", []) != ["harvest_crop"]:
		_fail("Canonical use statement did not build the tool allowlist. spec=%s" % str(spec))
		return
	var steps: Array = spec.get("steps", [])
	if steps.size() != 1:
		_fail("Canonical program should compile to one Session 1 step. spec=%s" % str(spec))
		return
	var step: Dictionary = steps[0]
	if str(step.get("id", "")) != "harvest" or str(step.get("tool", "")) != "harvest_crop" or str(step.get("target", "")) != "context.target" or str(step.get("when", "")) != "crop.ready":
		_fail("Canonical when/use mapping was wrong. step=%s" % str(step))
		return
	var check: Dictionary = spec.get("success_check", {})
	if str(check.get("type", "")) != "inventory_delta" or str(check.get("target", "")) != "context.target" or str(check.get("item", "")) != "grain" or int(check.get("min_delta", 0)) != 1:
		_fail("Canonical inventory defaults did not match the harvest starter. check=%s" % str(check))
		return
	if str(spec.get("failure_handling", {}).get("on_blocked", "")) != "record_receipt" or not str(spec.get("failure_handling", {}).get("suggestion", "")).contains("ready crop"):
		_fail("Canonical guard did not synthesize harvest failure handling. spec=%s" % str(spec))
		return
	if str(spec.get("receipt", {}).get("label", "")) != "Harvest Crops run":
		_fail("Canonical receipt label was not preserved. spec=%s" % str(spec))
		return

	var validation: Dictionary = SkillSpecValidatorScript.new().validate(spec)
	if not bool(validation.get("valid", false)) or not validation.get("warnings", []).is_empty():
		_fail("Canonical compiled spec did not validate cleanly. validation=%s" % str(validation))
		return


func _test_each_starter_action_gets_matching_defaults() -> void:
	var cases := [
		{"tool": "tend_crop", "guard": "crop.needs_tending", "check": "crop_state", "field": "state", "expected": "growth_advanced"},
		{"tool": "plant_seed", "guard": "tile.empty", "check": "crop_state", "field": "state", "expected": "planted"},
		{"tool": "clear_brush", "guard": "inspect.has_brush", "check": "tile_state", "field": "decor_id", "expected": ""},
		{"tool": "harvest_crop", "guard": "crop.ready", "check": "inventory_delta", "field": "item", "expected": "grain"},
		{"tool": "build_fence", "guard": "tile.empty", "check": "tile_state", "field": "decor_id", "expected": "fence"}
	]
	for case_value in cases:
		var case: Dictionary = case_value
		var program := _program_for("Bert", str(case.get("guard", "always")), str(case.get("tool", "")), str(case.get("check", "")), "Starter Check run")
		var result: Dictionary = SkillScriptParserScript.new().parse(program)
		if not bool(result.get("ok", false)):
			_fail("Starter action did not parse. case=%s result=%s" % [str(case), str(result)])
			return
		var spec: Dictionary = result.get("spec", {})
		var check: Dictionary = spec.get("success_check", {})
		if not check.has(str(case.get("field", ""))) or str(check.get(str(case.get("field", "")), "")) != str(case.get("expected", "")):
			_fail("Starter check defaults drifted. case=%s check=%s" % [str(case), str(check)])
			return
		if str(case.get("tool", "")) == "harvest_crop" and int(check.get("min_delta", 0)) != 1:
			_fail("Harvest starter did not synthesize min_delta=1. check=%s" % str(check))
			return
		var validation: Dictionary = SkillSpecValidatorScript.new().validate(spec)
		if not bool(validation.get("valid", false)):
			_fail("Starter-aligned parsed spec did not validate. case=%s validation=%s" % [str(case), str(validation)])
			return


func _test_optional_semicolons_and_case_insensitive_agent() -> void:
	var source := "agent \"bErT\" { observe selected_tile; when tile.empty { use build_fence(selected_tile); }; verify tile_state; receipt \"Fence run\"; };\n"
	var result: Dictionary = SkillScriptParserScript.new().parse(source)
	if not bool(result.get("ok", false)):
		_fail("Optional semicolon form did not parse. result=%s" % str(result))
		return
	if result.get("request", {}) != {"agent_id": "bert", "agent_name": "Bert"}:
		_fail("Case-insensitive crew resolution did not canonicalize Bert. result=%s" % str(result))
		return
	if str(result.get("spec", {}).get("id", "")) != "bert_fence":
		_fail("Semicolon program id synthesis was wrong. result=%s" % str(result))
		return


func _test_unknown_tool_and_condition_reach_validator() -> void:
	var unknown_tool_result: Dictionary = SkillScriptParserScript.new().parse(_program_for("Chuck", "always", "summon_rain", "tile_state", "Rain run"))
	if not bool(unknown_tool_result.get("ok", false)):
		_fail("Unknown tool should parse before validation. result=%s" % str(unknown_tool_result))
		return
	var tool_validation: Dictionary = SkillSpecValidatorScript.new().validate(unknown_tool_result.get("spec", {}))
	if not _issue_exists(tool_validation, "unknown_tool"):
		_fail("Unknown tool did not reach validator teaching copy. validation=%s" % str(tool_validation))
		return

	var unknown_condition_result: Dictionary = SkillScriptParserScript.new().parse(_program_for("Marigold", "weather.is_perfect", "harvest_crop", "inventory_delta", "Weather Harvest run"))
	if not bool(unknown_condition_result.get("ok", false)):
		_fail("Unknown condition should parse before validation. result=%s" % str(unknown_condition_result))
		return
	var condition_validation: Dictionary = SkillSpecValidatorScript.new().validate(unknown_condition_result.get("spec", {}))
	if not _issue_exists(condition_validation, "unsupported_condition"):
		_fail("Unknown condition did not reach validator teaching copy. validation=%s" % str(condition_validation))
		return


func _test_parse_errors_are_positional_and_teaching_ready() -> void:
	_expect_error("agent \"Rose\" {\n observe selected_tile\n use clear_brush(selected_tile)\n verify tile_state\n receipt \"Clear run\"\n}", 1, "Unknown agent")
	_expect_error("agent \"Bert\" {\n observe selected_tile\n use clear_brush(selected_tile)\n verify tile_state\n receipt \"Clear run\n}", 5, "Unterminated string")
	_expect_error("agent \"Bert\" {\n observe selected_tile\n dance selected_tile\n verify tile_state\n receipt \"Clear run\"\n}", 3, "Unknown statement")
	_expect_error("agent \"Bert\" {\n observe selected_tile\n when inspect.has_brush {\n  use clear_brush(selected_tile\n }\n verify tile_state\n receipt \"Clear run\"\n}", 4, "Expected ')'")
	_expect_error("agent \"Bert\" {\n observe selected_tile\n use clear_brush(selected_tile)\n use harvest_crop(selected_tile)\n verify tile_state\n receipt \"Clear run\"\n}", 4, "exactly one use")
	_expect_error("agent \"Bert\" {\n observe selected_tile\n use clear_brush(selected_tile)\n receipt \"Clear run\"\n}", 5, "missing a verify")
	_expect_error("agent \"Bert\" {\n observe selected_tile use clear_brush(selected_tile)\n verify tile_state\n receipt \"Clear run\"\n}", 2, "newline or semicolon")
	_expect_error("agent \"Bert\" {\n observe selected_tile\n use clear_brush(@)\n verify tile_state\n receipt \"Clear run\"\n}", 3, "Unexpected character")


func _expect_error(source: String, expected_line: int, message_fragment: String) -> void:
	var result: Dictionary = SkillScriptParserScript.new().parse(source)
	if bool(result.get("ok", true)):
		_fail("Malformed program unexpectedly parsed. source=%s" % source)
		return
	var error: Dictionary = result.get("error", {})
	if int(error.get("line", 0)) != expected_line:
		_fail("Parse error line was wrong. expected=%s error=%s" % [expected_line, str(error)])
		return
	if int(error.get("col", 0)) < 1:
		_fail("Parse error did not include a 1-based column. error=%s" % str(error))
		return
	if not str(error.get("message", "")).contains(message_fragment):
		_fail("Parse error message was not specific. expected=%s error=%s" % [message_fragment, str(error)])
		return
	if str(error.get("suggestion", "")).strip_edges() == "":
		_fail("Parse error did not include a fix suggestion. error=%s" % str(error))
		return


func _issue_exists(validation: Dictionary, code: String) -> bool:
	for issue_list in [validation.get("errors", []), validation.get("warnings", [])]:
		if typeof(issue_list) != TYPE_ARRAY:
			continue
		for issue in issue_list:
			if typeof(issue) == TYPE_DICTIONARY and str(issue.get("code", "")) == code:
				return true
	return false


func _canonical_program() -> String:
	return "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Harvest Crops run\"\n}"


func _program_for(agent_name: String, guard: String, tool_name: String, check_type: String, receipt_label: String) -> String:
	return "agent \"%s\" {\n  observe selected_tile\n  when %s {\n    use %s(selected_tile)\n  }\n  verify %s\n  receipt \"%s\"\n}" % [agent_name, guard, tool_name, check_type, receipt_label]


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)

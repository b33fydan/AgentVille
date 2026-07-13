extends SceneTree

const SkillScriptParserScript := preload("res://scripts/systems/SkillScriptParser.gd")

const REQUIRED_ERROR_CODES := [
	"blank_receipt",
	"duplicate_statement",
	"expected_token",
	"invalid_when_body",
	"missing_separator",
	"missing_statement",
	"multiple_use",
	"trailing_text",
	"unexpected_character",
	"unknown_agent",
	"unknown_statement",
	"unsupported_escape",
	"unterminated_escape",
	"unterminated_string"
]
const REQUIRED_ERROR_CLASSES := ["identity", "lexical", "structure", "syntax"]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_malformed_program_battery()
	if _failed:
		return
	_test_success_source_map()
	if _failed:
		return
	_test_validator_field_source_map()
	if _failed:
		return
	_test_unguarded_use_source_map()
	if _failed:
		return
	await _test_live_workbench_diagnostics()
	if not _failed:
		quit()


func _test_live_workbench_diagnostics() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var game_ui = scene.get_node_or_null("GameUI")
	var editor = game_ui.get("_code_editor") as CodeEdit if game_ui else null
	var compile_button = game_ui.get("_workbench_compile_button") as Button if game_ui else null
	var output = game_ui.get("_compiler_output") as RichTextLabel if game_ui else null
	if editor == null or compile_button == null or output == null:
		_fail("Malformed-program battery could not reach the live Workbench controls.")
		return

	var live_cases := [
		{
			"name": "parser",
			"source": "agnt \"Chuck\" {}",
			"stage": "PARSE ERROR",
			"location": "line 1:1",
			"token": "token agnt",
			"cause": "Expected an agent declaration"
		},
		{
			"name": "tool validator",
			"source": "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use summon_rain(selected_tile)\n  }\n  verify tile_state\n  receipt \"Rain run\"\n}",
			"stage": "VALIDATION BLOCKED",
			"location": "line 4:9",
			"token": "token summon_rain",
			"cause": "not allowlisted"
		},
		{
			"name": "condition validator",
			"source": "agent \"Chuck\" {\n  observe selected_tile\n  when weather.sunny {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Weather run\"\n}",
			"stage": "VALIDATION BLOCKED",
			"location": "line 3:8",
			"token": "token weather.sunny",
			"cause": "supported condition"
		},
		{
			"name": "check validator",
			"source": "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify weather_state\n  receipt \"Weather proof\"\n}",
			"stage": "VALIDATION BLOCKED",
			"location": "line 6:10",
			"token": "token weather_state",
			"cause": "Unsupported success checks"
		}
	]
	for case_value in live_cases:
		var case: Dictionary = case_value
		editor.text = str(case.get("source", ""))
		compile_button.pressed.emit()
		await process_frame
		var trace: String = str(output.text)
		for expected in [case.get("stage", ""), case.get("location", ""), case.get("token", ""), "cause     ", case.get("cause", ""), "fix       "]:
			if not trace.contains(str(expected)):
				_fail("Live %s diagnostic lost '%s'. trace=%s" % [case.get("name", "error"), expected, trace])
				return

	scene.queue_free()
	await process_frame
	await process_frame


func _test_malformed_program_battery() -> void:
	var cases := [
		_case("unexpected character", _program("  observe selected_tile\n  use clear_brush(@)\n  verify tile_state\n  receipt \"Clear run\""), "lexical", "unexpected_character", "@", "Unexpected character"),
		_case("unterminated string before newline", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run"), "lexical", "unterminated_string", "\"Clear run", "Unterminated string"),
		_case("unterminated string at eof", "agent \"Bert", "lexical", "unterminated_string", "\"Bert", "Unterminated string"),
		_case("unterminated escape", "agent \"Bert\\", "lexical", "unterminated_escape", "\\", "Unterminated string escape"),
		_case("unsupported escape", "agent \"B\\q\" {}", "lexical", "unsupported_escape", "\\q", "Unsupported string escape"),

		_case("empty source", "", "syntax", "expected_token", "<end of file>", "Expected an agent declaration"),
		_case("misspelled declaration", "agnt \"Bert\" {}", "syntax", "expected_token", "agnt", "Expected an agent declaration"),
		_case("unquoted agent", "agent Bert {}", "syntax", "expected_token", "Bert", "Expected a quoted crew name"),
		_case("missing agent brace", "agent \"Bert\"\n", "syntax", "expected_token", "<newline>", "Expected '{'"),
		_case("non-statement token", _program("  \"oops\""), "syntax", "expected_token", "\"oops\"", "Expected an agent statement"),
		_case("missing outer brace", _valid_program().substr(0, _valid_program().length() - 1), "syntax", "expected_token", "<end of file>", "Expected '}' to close the agent program"),
		_case("trailing text", "%s\ntrailing" % _valid_program(), "syntax", "trailing_text", "trailing", "Unexpected text after"),

		_case("observe target", _program("  observe\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "expected_token", "<newline>", "Expected a context target"),
		_case("when condition", _program("  observe selected_tile\n  when {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "expected_token", "{", "Expected a condition"),
		_case("when opening brace", _program("  observe selected_tile\n  when tile.empty\n  use plant_seed(selected_tile)\n  verify crop_state\n  receipt \"Plant run\""), "syntax", "expected_token", "<newline>", "Expected '{' after the when condition"),
		_case("invalid when body", _program("  observe selected_tile\n  when tile.empty {\n    verify crop_state\n  }\n  use plant_seed(selected_tile)\n  receipt \"Plant run\""), "structure", "invalid_when_body", "verify", "when block can only contain"),
		_case("empty when body", _program("  observe selected_tile\n  when tile.empty {}\n  use plant_seed(selected_tile)\n  verify crop_state\n  receipt \"Plant run\""), "structure", "invalid_when_body", "tile.empty", "when block has no use"),
		_case("missing when brace", "agent \"Bert\" {\n  observe selected_tile\n  when tile.empty {\n    use plant_seed(selected_tile)", "syntax", "expected_token", "<end of file>", "Expected '}' to close the when block"),
		_case("use tool", _program("  observe selected_tile\n  use (selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "expected_token", "(", "Expected a tool name"),
		_case("use opening parenthesis", _program("  observe selected_tile\n  use clear_brush selected_tile\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "expected_token", "selected_tile", "Expected '('"),
		_case("use target", _program("  observe selected_tile\n  use clear_brush()\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "expected_token", ")", "Expected a target"),
		_case("use closing parenthesis", _program("  observe selected_tile\n  use clear_brush(selected_tile\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "expected_token", "<newline>", "Expected ')'"),
		_case("verify type", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify\n  receipt \"Clear run\""), "syntax", "expected_token", "<newline>", "Expected a check type"),
		_case("receipt label", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt Clear"), "syntax", "expected_token", "Clear", "Expected a quoted label"),
		_case("missing separator", _program("  observe selected_tile use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "missing_separator", "use", "newline or semicolon"),
		_case("unknown statement", _program("  observe selected_tile\n  dance selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "syntax", "unknown_statement", "dance", "Unknown statement"),

		_case("duplicate observe", _program("  observe selected_tile\n  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "structure", "duplicate_statement", "observe", "more than one observe"),
		_case("multiple use", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  use harvest_crop(selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "structure", "multiple_use", "use", "exactly one use"),
		_case("duplicate verify", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  verify tile_state\n  receipt \"Clear run\""), "structure", "duplicate_statement", "verify", "more than one verify"),
		_case("duplicate receipt", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\"\n  receipt \"Second run\""), "structure", "duplicate_statement", "receipt", "more than one receipt"),
		_case("missing observe", _program("  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\""), "structure", "missing_statement", "}", "missing an observe"),
		_case("missing use", _program("  observe selected_tile\n  verify tile_state\n  receipt \"Clear run\""), "structure", "missing_statement", "}", "missing a use"),
		_case("missing verify", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  receipt \"Clear run\""), "structure", "missing_statement", "}", "missing a verify"),
		_case("missing receipt", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state"), "structure", "missing_statement", "}", "missing a receipt"),

		_case("blank receipt", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"   \""), "identity", "blank_receipt", "\"   \"", "Receipt labels cannot be blank"),
		_case("unknown agent", _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\"", "Rose"), "identity", "unknown_agent", "\"Rose\"", "Unknown agent")
	]

	var seen_codes := {}
	var seen_classes := {}
	for case_value in cases:
		var case: Dictionary = case_value
		var result: Dictionary = SkillScriptParserScript.new().parse(str(case.get("source", "")))
		if bool(result.get("ok", true)):
			_fail("Malformed program unexpectedly parsed. case=%s" % str(case.get("name", "unknown")))
			return
		var error_value = result.get("error", {})
		if typeof(error_value) != TYPE_DICTIONARY:
			_fail("Malformed program did not return one structured error. case=%s result=%s" % [case.get("name", "unknown"), str(result)])
			return
		var error: Dictionary = error_value
		if int(error.get("line", 0)) < 1 or int(error.get("col", 0)) < 1:
			_fail("Diagnostic location was not 1-based. case=%s error=%s" % [case.get("name", "unknown"), str(error)])
			return
		if str(error.get("class", "")) != str(case.get("class", "")) or str(error.get("code", "")) != str(case.get("code", "")):
			_fail("Diagnostic classification drifted. case=%s error=%s" % [case.get("name", "unknown"), str(error)])
			return
		if str(error.get("token", "")) != str(case.get("token", "")):
			_fail("Diagnostic lost its human offending token. case=%s expected=%s error=%s" % [case.get("name", "unknown"), case.get("token", ""), str(error)])
			return
		if not str(error.get("message", "")).contains(str(case.get("message", ""))):
			_fail("Diagnostic cause was not specific. case=%s error=%s" % [case.get("name", "unknown"), str(error)])
			return
		var suggestion := str(error.get("suggestion", "")).strip_edges()
		if suggestion == "" or suggestion.contains("\n"):
			_fail("Diagnostic did not return one plain suggestion. case=%s error=%s" % [case.get("name", "unknown"), str(error)])
			return
		seen_codes[str(error.get("code", ""))] = true
		seen_classes[str(error.get("class", ""))] = true

	var observed_codes: Array = seen_codes.keys()
	observed_codes.sort()
	var expected_codes: Array = REQUIRED_ERROR_CODES.duplicate()
	expected_codes.sort()
	if observed_codes != expected_codes:
		_fail("Malformed battery does not cover every parser error code. observed=%s expected=%s" % [str(observed_codes), str(expected_codes)])
		return
	var observed_classes: Array = seen_classes.keys()
	observed_classes.sort()
	var expected_classes: Array = REQUIRED_ERROR_CLASSES.duplicate()
	expected_classes.sort()
	if observed_classes != expected_classes:
		_fail("Malformed battery does not cover every parser error class. observed=%s expected=%s" % [str(observed_classes), str(expected_classes)])


func _test_success_source_map() -> void:
	var result: Dictionary = SkillScriptParserScript.new().parse(_valid_program())
	if not bool(result.get("ok", false)):
		_fail("Canonical program did not parse for source-map coverage. result=%s" % str(result))
		return
	var source_map_value = result.get("source_map", {})
	if typeof(source_map_value) != TYPE_DICTIONARY:
		_fail("Successful parse did not return a source map.")
		return
	var source_map: Dictionary = source_map_value
	var expected := {
		"agent.name": {"line": 1, "col": 7, "token": "\"Marigold\""},
		"trigger.type": {"line": 1, "col": 1, "token": "agent"},
		"context.target": {"line": 2, "col": 11, "token": "selected_tile"},
		"tools": {"line": 4, "col": 9, "token": "harvest_crop"},
		"steps[0].tool": {"line": 4, "col": 9, "token": "harvest_crop"},
		"steps[0].target": {"line": 4, "col": 22, "token": "selected_tile"},
		"steps[0].when": {"line": 3, "col": 8, "token": "crop.ready"},
		"success_check.type": {"line": 6, "col": 10, "token": "inventory_delta"},
		"success_check.item": {"line": 6, "col": 10, "token": "inventory_delta"},
		"name": {"line": 7, "col": 11, "token": "\"Harvest Crops run\""},
		"receipt.label": {"line": 7, "col": 11, "token": "\"Harvest Crops run\""}
	}
	for field in expected.keys():
		if source_map.get(field, {}) != expected[field]:
			_fail("Source-map provenance drifted. field=%s observed=%s expected=%s" % [field, str(source_map.get(field, {})), str(expected[field])])
			return


func _test_unguarded_use_source_map() -> void:
	var source := _program("  observe selected_tile\n  use clear_brush(selected_tile)\n  verify tile_state\n  receipt \"Clear run\"")
	var result: Dictionary = SkillScriptParserScript.new().parse(source)
	if not bool(result.get("ok", false)):
		_fail("Unguarded use did not parse for source-map fallback coverage. result=%s" % str(result))
		return
	var condition_location: Dictionary = result.get("source_map", {}).get("steps[0].when", {})
	if condition_location != {"line": 3, "col": 3, "token": "use"}:
		_fail("Implicit always condition did not point back to its use statement. location=%s" % str(condition_location))


func _test_validator_field_source_map() -> void:
	var source := "agent \"Chuck\" {\n  observe farm_tile\n  when weather.sunny {\n    use summon_rain(other_tile)\n  }\n  verify weather_state\n  receipt \"X\"\n}"
	var result: Dictionary = SkillScriptParserScript.new().parse(source)
	if not bool(result.get("ok", false)):
		_fail("Validator-bound identifiers did not parse for provenance coverage. result=%s" % str(result))
		return
	var source_map: Dictionary = result.get("source_map", {})
	var expected := {
		"context.target": {"line": 2, "col": 11, "token": "farm_tile"},
		"tools": {"line": 4, "col": 9, "token": "summon_rain"},
		"steps[0].tool": {"line": 4, "col": 9, "token": "summon_rain"},
		"steps[0].target": {"line": 4, "col": 21, "token": "other_tile"},
		"steps[0].when": {"line": 3, "col": 8, "token": "weather.sunny"},
		"success_check.type": {"line": 6, "col": 10, "token": "weather_state"},
		"success_check.state": {"line": 6, "col": 10, "token": "weather_state"},
		"success_check.item": {"line": 6, "col": 10, "token": "weather_state"},
		"receipt.label": {"line": 7, "col": 11, "token": "\"X\""},
		"name": {"line": 7, "col": 11, "token": "\"X\""}
	}
	for field in expected.keys():
		if source_map.get(field, {}) != expected[field]:
			_fail("Validator field did not retain its authored token provenance. field=%s observed=%s expected=%s" % [field, str(source_map.get(field, {})), str(expected[field])])
			return


func _case(name: String, source: String, error_class: String, code: String, token: String, message: String) -> Dictionary:
	return {
		"name": name,
		"source": source,
		"class": error_class,
		"code": code,
		"token": token,
		"message": message
	}


func _program(body: String, agent_name: String = "Bert") -> String:
	return "agent \"%s\" {\n%s\n}" % [agent_name, body]


func _valid_program() -> String:
	return "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Harvest Crops run\"\n}"


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)

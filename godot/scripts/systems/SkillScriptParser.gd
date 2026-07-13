class_name SkillScriptParser
extends RefCounted

const SkillForgeTemplateLibraryScript := preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")

const TOKEN_IDENTIFIER := "identifier"
const TOKEN_STRING := "string"
const TOKEN_LEFT_BRACE := "left_brace"
const TOKEN_RIGHT_BRACE := "right_brace"
const TOKEN_LEFT_PAREN := "left_paren"
const TOKEN_RIGHT_PAREN := "right_paren"
const TOKEN_SEMICOLON := "semicolon"
const TOKEN_NEWLINE := "newline"
const TOKEN_EOF := "eof"

const KNOWN_AGENTS := {
	"bert": {"agent_id": "bert", "agent_name": "Bert"},
	"marigold": {"agent_id": "marigold", "agent_name": "Marigold"},
	"chuck": {"agent_id": "chuck", "agent_name": "Chuck"}
}

const TEMPLATE_BY_TOOL := {
	"tend_crop": "tend_crops_starter",
	"plant_seed": "plant_seed_starter",
	"clear_brush": "clear_patch_starter",
	"harvest_crop": "harvest_crops_starter",
	"build_fence": "build_fence_starter"
}

const STEP_ID_BY_TOOL := {
	"inspect_tile": "inspect",
	"tend_crop": "tend",
	"plant_seed": "plant",
	"clear_brush": "clear",
	"harvest_crop": "harvest",
	"build_fence": "build"
}

var _tokens: Array = []
var _token_index: int = 0
var _parse_error: Dictionary = {}
var _templates = SkillForgeTemplateLibraryScript.new()


func parse(source: String) -> Dictionary:
	_tokens.clear()
	_token_index = 0
	_parse_error.clear()

	_tokenize(source)
	if not _parse_error.is_empty():
		return _failure_result()

	var program := _parse_program()
	if not _parse_error.is_empty():
		return _failure_result()

	var compiled := _compile_program(program)
	if not _parse_error.is_empty():
		return _failure_result()

	return {
		"ok": true,
		"spec": compiled.get("spec", {}),
		"request": compiled.get("request", {}),
		"source_map": _source_map_for_program(program)
	}


func _tokenize(source: String) -> void:
	var offset := 0
	var line := 1
	var column := 1
	while offset < source.length():
		var character := source.substr(offset, 1)
		if character == " " or character == "\t":
			offset += 1
			column += 1
			continue
		if character == "\r" or character == "\n":
			_tokens.append(_token(TOKEN_NEWLINE, "\n", line, column))
			if character == "\r" and offset + 1 < source.length() and source.substr(offset + 1, 1) == "\n":
				offset += 1
			offset += 1
			line += 1
			column = 1
			continue
		if character == "\"":
			var string_result := _scan_string(source, offset, line, column)
			if not _parse_error.is_empty():
				return
			_tokens.append(string_result.get("token", {}))
			offset = int(string_result.get("next_offset", offset + 1))
			column = int(string_result.get("next_column", column + 1))
			continue
		if _is_identifier_start(character):
			var start_offset := offset
			var start_column := column
			while offset < source.length() and _is_identifier_part(source.substr(offset, 1)):
				offset += 1
				column += 1
			_tokens.append(_token(TOKEN_IDENTIFIER, source.substr(start_offset, offset - start_offset), line, start_column))
			continue

		var punctuation_kind := ""
		match character:
			"{":
				punctuation_kind = TOKEN_LEFT_BRACE
			"}":
				punctuation_kind = TOKEN_RIGHT_BRACE
			"(":
				punctuation_kind = TOKEN_LEFT_PAREN
			")":
				punctuation_kind = TOKEN_RIGHT_PAREN
			";":
				punctuation_kind = TOKEN_SEMICOLON
		if punctuation_kind != "":
			_tokens.append(_token(punctuation_kind, character, line, column))
			offset += 1
			column += 1
			continue

		_set_error(line, column, character, "Unexpected character '%s'." % character, "Use agent keywords, names, braces, parentheses, or an optional semicolon.")
		return

	_tokens.append(_token(TOKEN_EOF, "", line, column))


func _scan_string(source: String, start_offset: int, line: int, start_column: int) -> Dictionary:
	var offset := start_offset + 1
	var column := start_column + 1
	var value := ""
	while offset < source.length():
		var character := source.substr(offset, 1)
		if character == "\"":
			return {
				"token": _token(TOKEN_STRING, value, line, start_column),
				"next_offset": offset + 1,
				"next_column": column + 1
			}
		if character == "\r" or character == "\n":
			_set_error(line, start_column, _unterminated_string_token(value), "Unterminated string.", "Close the string with a double quote before the end of the line.")
			return {}
		if character == "\\":
			if offset + 1 >= source.length():
				_set_error(line, column, "\\", "Unterminated string escape.", "Add a quote or backslash after the escape character.")
				return {}
			var escaped := source.substr(offset + 1, 1)
			if escaped != "\"" and escaped != "\\":
				_set_error(line, column, "\\%s" % escaped, "Unsupported string escape '\\%s'." % escaped, "Only escaped quotes and backslashes are supported.")
				return {}
			value += escaped
			offset += 2
			column += 2
			continue
		value += character
		offset += 1
		column += 1

	_set_error(line, start_column, _unterminated_string_token(value), "Unterminated string.", "Close the string with a double quote before the end of the file.")
	return {}


func _parse_program() -> Dictionary:
	_skip_separators()
	var agent_keyword := _consume_word("agent", "Expected an agent declaration.", "Start the program with agent \"Bert\", agent \"Marigold\", or agent \"Chuck\".")
	if agent_keyword.is_empty():
		return {}
	var agent_token := _consume(TOKEN_STRING, "Expected a quoted crew name after agent.", "Write agent \"Bert\", agent \"Marigold\", or agent \"Chuck\".")
	if agent_token.is_empty():
		return {}
	if _consume(TOKEN_LEFT_BRACE, "Expected '{' after the agent name.", "Open the agent program with a left brace.").is_empty():
		return {}

	var program := {
		"agent_keyword": agent_keyword,
		"agent_token": agent_token,
		"observe": {},
		"uses": [],
		"verify": {},
		"receipt": {}
	}
	_skip_separators()
	while not _check(TOKEN_RIGHT_BRACE) and not _check(TOKEN_EOF):
		_parse_statement(program)
		if not _parse_error.is_empty():
			return {}
		_skip_separators()

	var closing_token := _consume(TOKEN_RIGHT_BRACE, "Expected '}' to close the agent program.", "Add a right brace after the final receipt statement.")
	if closing_token.is_empty():
		return {}
	if not _require_program_fields(program, closing_token):
		return {}

	_skip_separators()
	if not _check(TOKEN_EOF):
		var trailing := _peek()
		_set_error_from_token(trailing, "Unexpected text after the agent program.", "Remove the extra text after the closing brace.")
		return {}
	return program


func _parse_statement(program: Dictionary) -> void:
	var statement_token := _peek()
	if str(statement_token.get("kind", "")) != TOKEN_IDENTIFIER:
		_set_error_from_token(statement_token, "Expected an agent statement.", "Use observe, when, use, verify, or receipt.")
		return
	match str(statement_token.get("lexeme", "")):
		"observe":
			_parse_observe(program)
		"when":
			_parse_when(program)
		"use":
			_parse_use(program, "always")
		"verify":
			_parse_verify(program)
		"receipt":
			_parse_receipt(program)
		_:
			_set_error_from_token(statement_token, "Unknown statement '%s'." % str(statement_token.get("lexeme", "")), "Use observe, when, use, verify, or receipt.")


func _parse_observe(program: Dictionary) -> void:
	var keyword := _advance()
	if not program.get("observe", {}).is_empty():
		_set_error_from_token(keyword, "The program has more than one observe statement.", "Keep one observe statement for selected_tile.")
		return
	var target := _consume(TOKEN_IDENTIFIER, "Expected a context target after observe.", "Write observe selected_tile.")
	if target.is_empty():
		return
	program["observe"] = target
	_finish_statement()


func _parse_when(program: Dictionary) -> void:
	_advance()
	var condition := _consume(TOKEN_IDENTIFIER, "Expected a condition after when.", "Use a condition such as crop.ready or tile.empty.")
	if condition.is_empty():
		return
	if _consume(TOKEN_LEFT_BRACE, "Expected '{' after the when condition.", "Open the guarded use statement with a left brace.").is_empty():
		return
	_skip_separators()
	var use_count := 0
	while not _check(TOKEN_RIGHT_BRACE) and not _check(TOKEN_EOF):
		var token := _peek()
		if str(token.get("kind", "")) != TOKEN_IDENTIFIER or str(token.get("lexeme", "")) != "use":
			_set_error_from_token(token, "A when block can only contain a use statement.", "Put one use tool_name(selected_tile) statement inside the when block.")
			return
		_parse_use(program, str(condition.get("lexeme", "")), condition)
		if not _parse_error.is_empty():
			return
		use_count += 1
		_skip_separators()
	if _consume(TOKEN_RIGHT_BRACE, "Expected '}' to close the when block.", "Add a right brace after the guarded use statement.").is_empty():
		return
	if use_count == 0:
		_set_error_from_token(condition, "The when block has no use statement.", "Add one use tool_name(selected_tile) statement inside the when block.")
		return
	_finish_statement()


func _parse_use(program: Dictionary, condition: String, condition_token: Dictionary = {}) -> void:
	var keyword := _advance()
	var uses: Array = program.get("uses", [])
	if not uses.is_empty():
		_set_error_from_token(keyword, "Session 1 supports exactly one use statement.", "Keep one tool call in this program and move other work into a separate run.")
		return
	var tool := _consume(TOKEN_IDENTIFIER, "Expected a tool name after use.", "Write a tool call such as harvest_crop(selected_tile).")
	if tool.is_empty():
		return
	if _consume(TOKEN_LEFT_PAREN, "Expected '(' after the tool name.", "Put the selected target inside parentheses.").is_empty():
		return
	var target := _consume(TOKEN_IDENTIFIER, "Expected a target inside the tool call.", "Use selected_tile as the tool target.")
	if target.is_empty():
		return
	if _consume(TOKEN_RIGHT_PAREN, "Expected ')' after the tool target.", "Close the tool call with a right parenthesis.").is_empty():
		return
	uses.append({
		"keyword": keyword,
		"tool": tool,
		"target": target,
		"condition": condition,
		"condition_token": condition_token.duplicate(true)
	})
	program["uses"] = uses
	_finish_statement()


func _parse_verify(program: Dictionary) -> void:
	var keyword := _advance()
	if not program.get("verify", {}).is_empty():
		_set_error_from_token(keyword, "The program has more than one verify statement.", "Keep one concrete success check per run.")
		return
	var check_type := _consume(TOKEN_IDENTIFIER, "Expected a check type after verify.", "Use tile_state, crop_state, or inventory_delta.")
	if check_type.is_empty():
		return
	program["verify"] = check_type
	_finish_statement()


func _parse_receipt(program: Dictionary) -> void:
	var keyword := _advance()
	if not program.get("receipt", {}).is_empty():
		_set_error_from_token(keyword, "The program has more than one receipt statement.", "Keep one quoted receipt label per run.")
		return
	var receipt := _consume(TOKEN_STRING, "Expected a quoted label after receipt.", "Write a receipt such as receipt \"Harvest Crops run\".")
	if receipt.is_empty():
		return
	program["receipt"] = receipt
	_finish_statement()


func _finish_statement() -> void:
	if _check(TOKEN_NEWLINE) or _check(TOKEN_SEMICOLON):
		_skip_separators()
		return
	if _check(TOKEN_RIGHT_BRACE) or _check(TOKEN_EOF):
		return
	var token := _peek()
	_set_error_from_token(token, "Expected a newline or semicolon after the statement.", "Put each statement on its own line, or add a trailing semicolon.")


func _require_program_fields(program: Dictionary, closing_token: Dictionary) -> bool:
	if program.get("observe", {}).is_empty():
		_set_error_from_token(closing_token, "The program is missing an observe statement.", "Add observe selected_tile before the tool call.")
		return false
	var uses: Array = program.get("uses", [])
	if uses.is_empty():
		_set_error_from_token(closing_token, "The program is missing a use statement.", "Add one use tool_name(selected_tile) statement.")
		return false
	if program.get("verify", {}).is_empty():
		_set_error_from_token(closing_token, "The program is missing a verify statement.", "Add one concrete verify statement before the receipt.")
		return false
	if program.get("receipt", {}).is_empty():
		_set_error_from_token(closing_token, "The program is missing a receipt statement.", "Add one quoted receipt label before the closing brace.")
		return false
	return true


func _compile_program(program: Dictionary) -> Dictionary:
	var agent_token: Dictionary = program.get("agent_token", {})
	var requested_name := str(agent_token.get("lexeme", "")).strip_edges()
	var agent_key := requested_name.to_lower()
	if not KNOWN_AGENTS.has(agent_key):
		_set_error_from_token(agent_token, "Unknown agent '%s'." % requested_name, "Use Bert, Marigold, or Chuck.")
		return {}
	var request: Dictionary = KNOWN_AGENTS[agent_key].duplicate(true)

	var receipt_token: Dictionary = program.get("receipt", {})
	var receipt_label := str(receipt_token.get("lexeme", "")).strip_edges()
	if receipt_label == "":
		_set_error_from_token(receipt_token, "Receipt labels cannot be blank.", "Give the run a short result label such as Harvest Crops run.")
		return {}
	var skill_name := _display_name_from_receipt(receipt_label)
	var skill_id := _snake_case_id("%s_%s" % [str(request.get("agent_id", "agent")), skill_name])

	var observe_token: Dictionary = program.get("observe", {})
	var context_target := str(observe_token.get("lexeme", ""))
	var uses: Array = program.get("uses", [])
	var use_statement: Dictionary = uses[0]
	var tool_token: Dictionary = use_statement.get("tool", {})
	var target_token: Dictionary = use_statement.get("target", {})
	var tool_name := str(tool_token.get("lexeme", ""))
	var tool_target := str(target_token.get("lexeme", ""))
	var condition := str(use_statement.get("condition", "always"))
	var verify_token: Dictionary = program.get("verify", {})
	var check_type := str(verify_token.get("lexeme", ""))

	var template_spec: Dictionary = {}
	var template_id := str(TEMPLATE_BY_TOOL.get(tool_name, ""))
	if template_id != "":
		template_spec = _templates.get_template_spec(template_id)

	var context := {"target": context_target}
	if not template_spec.is_empty():
		var template_context = template_spec.get("context", {})
		if typeof(template_context) == TYPE_DICTIONARY:
			context = template_context.duplicate(true)
			context["target"] = context_target

	var step_target := tool_target
	if tool_target == context_target:
		step_target = "context.target"
	var step := {
		"id": str(STEP_ID_BY_TOOL.get(tool_name, _snake_case_id(tool_name))),
		"tool": tool_name,
		"target": step_target,
		"when": condition
	}

	var success_check := {
		"type": check_type,
		"target": "context.target"
	}
	if not template_spec.is_empty():
		var template_check = template_spec.get("success_check", {})
		if typeof(template_check) == TYPE_DICTIONARY and str(template_check.get("type", "")) == check_type:
			success_check = template_check.duplicate(true)
			success_check["target"] = "context.target"

	var receipt := {
		"label": receipt_label,
		"template": "{agent} completed %s at {target} and checked {result}." % skill_name,
		"include_source_context": false
	}
	if not template_spec.is_empty():
		var template_receipt = template_spec.get("receipt", {})
		if typeof(template_receipt) == TYPE_DICTIONARY:
			receipt = template_receipt.duplicate(true)
			receipt["label"] = receipt_label

	var spec := {
		"id": skill_id,
		"name": skill_name,
		"trigger": {"type": "manual"},
		"context": context,
		"tools": [tool_name],
		"steps": [step],
		"success_check": success_check,
		"failure_handling": {
			"on_blocked": "record_receipt",
			"suggestion": _failure_suggestion(condition, tool_name, template_spec)
		},
		"receipt": receipt
	}
	return {
		"spec": spec,
		"request": request
	}


func _source_map_for_program(program: Dictionary) -> Dictionary:
	var source_map := {}
	var agent_keyword: Dictionary = program.get("agent_keyword", {})
	var agent_token: Dictionary = program.get("agent_token", {})
	var observe_token: Dictionary = program.get("observe", {})
	var verify_token: Dictionary = program.get("verify", {})
	var receipt_token: Dictionary = program.get("receipt", {})
	var uses: Array = program.get("uses", [])
	var use_statement: Dictionary = uses[0] if not uses.is_empty() and typeof(uses[0]) == TYPE_DICTIONARY else {}
	var use_keyword: Dictionary = use_statement.get("keyword", {})
	var tool_token: Dictionary = use_statement.get("tool", {})
	var target_token: Dictionary = use_statement.get("target", {})
	var condition_token: Dictionary = use_statement.get("condition_token", {})
	if condition_token.is_empty():
		condition_token = use_keyword

	_map_source_fields(source_map, ["agent", "agent.name"], agent_token)
	_map_source_fields(source_map, ["trigger", "trigger.type"], agent_keyword)
	_map_source_fields(source_map, ["id", "name"], receipt_token)
	_map_source_fields(source_map, ["context", "context.target", "context.allowed_sources"], observe_token)
	_map_source_fields(source_map, ["tools", "tools[0]", "steps", "steps[0]", "steps[0].id", "steps[0].tool"], tool_token)
	_map_source_fields(source_map, ["steps[0].target"], target_token)
	_map_source_fields(source_map, ["steps[0].when"], condition_token)
	_map_source_fields(source_map, [
		"success_check",
		"success_check.type",
		"success_check.target",
		"success_check.state",
		"success_check.decor_id",
		"success_check.item",
		"success_check.min_delta"
	], verify_token)
	_map_source_fields(source_map, [
		"failure_handling",
		"failure_handling.on_blocked",
		"failure_handling.suggestion"
	], condition_token)
	_map_source_fields(source_map, [
		"receipt",
		"receipt.label",
		"receipt.template",
		"receipt_template"
	], receipt_token)
	return source_map


func _map_source_fields(source_map: Dictionary, fields: Array, token: Dictionary) -> void:
	if token.is_empty():
		return
	var location := _source_location(token)
	for field_value in fields:
		var field := str(field_value).strip_edges()
		if field != "":
			source_map[field] = location.duplicate(true)


func _source_location(token: Dictionary) -> Dictionary:
	return {
		"line": max(int(token.get("line", 1)), 1),
		"col": max(int(token.get("col", 1)), 1),
		"token": _human_token(token)
	}


func _failure_suggestion(condition: String, tool_name: String, template_spec: Dictionary) -> String:
	if not template_spec.is_empty():
		var steps = template_spec.get("steps", [])
		if typeof(steps) == TYPE_ARRAY:
			for step in steps:
				if typeof(step) != TYPE_DICTIONARY:
					continue
				if str(step.get("tool", "")) == tool_name and str(step.get("when", "always")) == condition:
					return str(template_spec.get("failure_handling", {}).get("suggestion", "Revise the target or condition, then run again."))
	if condition == "always":
		return "Pick a compatible target for %s before running again." % tool_name
	return "Pick a tile where %s is true, or revise that condition." % condition


func _display_name_from_receipt(receipt_label: String) -> String:
	var display_name := receipt_label.strip_edges()
	if display_name.to_lower().ends_with(" run") and display_name.length() > 4:
		display_name = display_name.substr(0, display_name.length() - 4).strip_edges()
	return display_name


func _snake_case_id(value: String) -> String:
	var normalized := ""
	var previous_was_separator := false
	for index in range(value.length()):
		var character := value.substr(index, 1).to_lower()
		var is_letter := character >= "a" and character <= "z"
		var is_number := character >= "0" and character <= "9"
		if is_letter or is_number:
			normalized += character
			previous_was_separator = false
		elif not previous_was_separator and normalized != "":
			normalized += "_"
			previous_was_separator = true
	while normalized.ends_with("_"):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


func _consume_word(word: String, message: String, suggestion: String) -> Dictionary:
	var token := _peek()
	if str(token.get("kind", "")) == TOKEN_IDENTIFIER and str(token.get("lexeme", "")) == word:
		return _advance()
	_set_error_from_token(token, message, suggestion)
	return {}


func _consume(kind: String, message: String, suggestion: String) -> Dictionary:
	if _check(kind):
		return _advance()
	_set_error_from_token(_peek(), message, suggestion)
	return {}


func _skip_separators() -> void:
	while _check(TOKEN_NEWLINE) or _check(TOKEN_SEMICOLON):
		_advance()


func _check(kind: String) -> bool:
	return str(_peek().get("kind", "")) == kind


func _advance() -> Dictionary:
	var token := _peek()
	if _token_index < _tokens.size() - 1:
		_token_index += 1
	return token


func _peek() -> Dictionary:
	if _tokens.is_empty():
		return _token(TOKEN_EOF, "", 1, 1)
	return _tokens[min(_token_index, _tokens.size() - 1)]


func _token(kind: String, lexeme: String, line: int, column: int) -> Dictionary:
	return {
		"kind": kind,
		"lexeme": lexeme,
		"line": line,
		"col": column
	}


func _is_identifier_start(character: String) -> bool:
	return (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or character == "_"


func _is_identifier_part(character: String) -> bool:
	return _is_identifier_start(character) or (character >= "0" and character <= "9") or character == "."


func _set_error_from_token(token: Dictionary, message: String, suggestion: String) -> void:
	_set_error(
		int(token.get("line", 1)),
		int(token.get("col", 1)),
		_human_token(token),
		message,
		suggestion
	)


func _set_error(line: int, column: int, token: String, message: String, suggestion: String) -> void:
	if not _parse_error.is_empty():
		return
	var classification := _classify_parse_error(message)
	_parse_error = {
		"line": max(line, 1),
		"col": max(column, 1),
		"token": token if token.strip_edges() != "" else "<unknown>",
		"code": str(classification.get("code", "syntax_error")),
		"class": str(classification.get("class", "syntax")),
		"message": message,
		"suggestion": suggestion
	}


func _human_token(token: Dictionary) -> String:
	var kind := str(token.get("kind", ""))
	var lexeme := str(token.get("lexeme", ""))
	match kind:
		TOKEN_EOF:
			return "<end of file>"
		TOKEN_NEWLINE:
			return "<newline>"
		TOKEN_STRING:
			return "\"%s\"" % lexeme.replace("\\", "\\\\").replace("\"", "\\\"")
	if lexeme != "":
		return lexeme
	return "<unknown>"


func _unterminated_string_token(value: String) -> String:
	return "\"%s" % value.replace("\\", "\\\\").replace("\"", "\\\"")


func _classify_parse_error(message: String) -> Dictionary:
	var normalized := message.to_lower()
	if normalized.contains("unexpected character"):
		return {"code": "unexpected_character", "class": "lexical"}
	if normalized.contains("unterminated string escape"):
		return {"code": "unterminated_escape", "class": "lexical"}
	if normalized.contains("unterminated string"):
		return {"code": "unterminated_string", "class": "lexical"}
	if normalized.contains("unsupported string escape"):
		return {"code": "unsupported_escape", "class": "lexical"}
	if normalized.contains("unknown agent"):
		return {"code": "unknown_agent", "class": "identity"}
	if normalized.contains("receipt labels cannot be blank"):
		return {"code": "blank_receipt", "class": "identity"}
	if normalized.contains("more than one"):
		return {"code": "duplicate_statement", "class": "structure"}
	if normalized.contains("supports exactly one use"):
		return {"code": "multiple_use", "class": "structure"}
	if normalized.contains("missing an observe") or normalized.contains("missing a use") or normalized.contains("missing a verify") or normalized.contains("missing a receipt"):
		return {"code": "missing_statement", "class": "structure"}
	if normalized.contains("when block has no use") or normalized.contains("when block can only contain"):
		return {"code": "invalid_when_body", "class": "structure"}
	if normalized.contains("unknown statement"):
		return {"code": "unknown_statement", "class": "syntax"}
	if normalized.contains("unexpected text after"):
		return {"code": "trailing_text", "class": "syntax"}
	if normalized.contains("newline or semicolon"):
		return {"code": "missing_separator", "class": "syntax"}
	return {"code": "expected_token", "class": "syntax"}


func _failure_result() -> Dictionary:
	return {
		"ok": false,
		"error": _parse_error.duplicate(true)
	}

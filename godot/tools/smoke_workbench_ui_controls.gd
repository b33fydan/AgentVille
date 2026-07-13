extends SceneTree

const GameUIScript := preload("res://scripts/ui/GameUI.gd")


func _initialize() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	var game_ui = GameUIScript.new()
	root.add_child(game_ui)
	await process_frame
	await process_frame

	var editor := game_ui.get("_code_editor") as CodeEdit
	var compile_button := game_ui.get("_workbench_compile_button") as Button
	var runtime_label := game_ui.get("_workbench_runtime_label") as Label
	var compiler_output := game_ui.get("_compiler_output") as RichTextLabel
	if editor == null or compile_button == null or runtime_label == null or compiler_output == null:
		_fail("Workbench UI controls were not constructed.")
		return
	if runtime_label.text != "READY  ·  LOCAL COMPILER":
		_fail("Workbench did not start in the live local-compiler state.")
		return
	if compiler_output.bbcode_enabled or not compiler_output.text.contains("local deterministic compiler ready"):
		_fail("Workbench did not start with a safe live compiler trace.")
		return

	var compile_requests: Array[String] = []
	game_ui.workbench_compile_requested.connect(func(source_text: String) -> void:
		compile_requests.append(source_text)
	)
	compile_button.pressed.emit()
	if compile_requests != [editor.text]:
		_fail("Compile button did not emit the current editor source exactly once.")
		return

	var source_before_shortcut := editor.text
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_ENTER
	shortcut.meta_pressed = true
	shortcut.pressed = true
	editor.gui_input.emit(shortcut)
	if compile_requests.size() != 2 or compile_requests[1] != source_before_shortcut:
		_fail("Cmd+Enter did not share the single Workbench compile path.")
		return
	if editor.text != source_before_shortcut:
		_fail("Cmd+Enter inserted text into the agent source.")
		return

	game_ui.set_workbench_trace({
		"stage": "parse",
		"status": "blocked",
		"agent_name": "Marigold",
		"target_tile": Vector2i(3, 4),
		"target_source": "selected tile",
		"issues": [{
			"line": 3,
			"col": 8,
			"message": "[color=red]literal parser message[/color]",
			"suggestion": "Use an allowlisted farm tool."
		}],
		"drift": {"level": "hallucinating"},
		"runtime_status": "BLOCKED  ·  FIX LINE 3",
		"runtime_color": Color("#e7785b")
	})
	var trace_text := compiler_output.text
	if not trace_text.contains("stage     parse") or not trace_text.contains("target    (3, 4) · selected tile"):
		_fail("Structured Workbench trace lost its real pipeline stage or resolved coordinates.")
		return
	if not trace_text.contains("line 3:8") or not trace_text.contains("Use an allowlisted farm tool."):
		_fail("Structured Workbench trace lost its teaching error or suggestion.")
		return
	if not trace_text.contains("[color=red]literal parser message[/color]") or compiler_output.bbcode_enabled:
		_fail("Workbench trace did not preserve player-derived text as safe plain text.")
		return
	if runtime_label.text != "BLOCKED  ·  FIX LINE 3":
		_fail("Structured Workbench trace did not update the runtime status.")
		return

	game_ui.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

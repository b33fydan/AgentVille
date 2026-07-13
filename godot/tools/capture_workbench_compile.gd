extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-workbench-compile.png"
const CAPTURE_SIZE := Vector2i(1600, 900)
const CANONICAL_PROGRAM := "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Harvest Crops run\"\n}"


func _initialize() -> void:
	root.size = CAPTURE_SIZE
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Workbench compile capture needs a normal renderer; run without --headless.")
		return
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var ready_tile = null
	for tile in grid.tiles.values():
		if tile.crop != null and tile.crop.is_ready():
			ready_tile = tile
			break
	if ready_tile == null:
		_fail("Could not capture Workbench compile: starter map has no ready crop.")
		return

	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", ready_tile)
	var game_ui = scene.get_node("GameUI")
	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if editor == null or compile_button == null:
		_fail("Could not capture Workbench compile: integrated controls are unavailable.")
		return
	editor.text = CANONICAL_PROGRAM
	compile_button.pressed.emit()
	await create_timer(0.45).timeout

	var image := root.get_texture().get_image()
	if image == null:
		_fail("Could not capture Workbench compile: viewport image is unavailable.")
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Could not save Workbench compile capture to %s." % OUTPUT_PATH)
		return
	print("Captured Workbench compile review to %s." % OUTPUT_PATH)
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

extends SceneTree

const PlacementToolScript := preload("res://scripts/tools/PlacementTool.gd")
const TileScene := preload("res://scenes/world/Tile.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var first_tile = TileScene.instantiate()
	first_tile.setup(Vector2i(2, 3), 1.0)
	world.add_child(first_tile)
	var second_tile = TileScene.instantiate()
	second_tile.setup(Vector2i(4, 5), 1.0)
	world.add_child(second_tile)

	var placement_tool = PlacementToolScript.new()
	root.add_child(placement_tool)
	placement_tool.set_tool("select")
	var selection_events: Array[Vector2i] = []
	placement_tool.selected_tile_changed.connect(func(grid_pos: Vector2i) -> void:
		selection_events.append(grid_pos)
	)

	placement_tool.call("_apply_to_tile", first_tile)
	if not placement_tool.has_selected_tile() or placement_tool.get_selected_tile() != first_tile:
		_fail("SELECT did not store the selected Tile instance.")
		return
	if placement_tool.get_selected_grid_pos() != Vector2i(2, 3) or selection_events != [Vector2i(2, 3)]:
		_fail("SELECT did not expose or signal the selected grid coordinates.")
		return
	var first_frame := first_tile.get_node_or_null("SelectedFrame") as Node3D
	if first_frame == null or not first_frame.visible:
		_fail("Selected tile did not show its persistent voxel frame.")
		return

	first_tile.set_hovered(true)
	first_tile.set_hovered(false)
	first_tile.refresh()
	placement_tool.set_tool("pan")
	if not first_frame.visible or placement_tool.get_selected_grid_pos() != Vector2i(2, 3):
		_fail("Hover clearing, tile refresh, or tool switching cleared persistent selection.")
		return

	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", second_tile)
	var second_frame := second_tile.get_node_or_null("SelectedFrame") as Node3D
	if first_frame.visible or second_frame == null or not second_frame.visible:
		_fail("Selecting a new tile did not move the persistent frame cleanly.")
		return
	if selection_events != [Vector2i(2, 3), Vector2i(4, 5)]:
		_fail("Selecting a replacement tile emitted an incorrect selection history.")
		return

	placement_tool.clear_selected_tile()
	if placement_tool.has_selected_tile() or placement_tool.get_selected_grid_pos() != Vector2i(-1, -1):
		_fail("Clearing selection did not restore the no-selection API state.")
		return
	if second_frame.visible or selection_events.back() != Vector2i(-1, -1):
		_fail("Clearing selection did not hide or signal the selected frame.")
		return

	placement_tool.queue_free()
	world.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)

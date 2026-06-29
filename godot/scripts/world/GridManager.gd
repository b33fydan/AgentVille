class_name GridManager
extends Node3D

signal day_advanced(day: int)

const TileScene := preload("res://scenes/world/Tile.tscn")
const VoxelFactory := preload("res://scripts/core/Voxel.gd")
const STARTER_DECOR_CLUSTER_ORDER := [
	"homestead_edge",
	"north_field_edge",
	"south_meadow_edge",
	"east_grove_edge"
]
const STARTER_DECOR_CLUSTERS := {
	"homestead_edge": [
		{"grid_pos": Vector2i(6, 0), "decor_id": "tall_grass"},
		{"grid_pos": Vector2i(8, 0), "decor_id": "tree"},
		{"grid_pos": Vector2i(9, 0), "decor_id": "flower_patch"},
		{"grid_pos": Vector2i(10, 1), "decor_id": "tall_grass"},
		{"grid_pos": Vector2i(10, 3), "decor_id": "rock"}
	],
	"north_field_edge": [
		{"grid_pos": Vector2i(2, 0), "decor_id": "tall_grass"},
		{"grid_pos": Vector2i(3, 0), "decor_id": "flower_patch"},
		{"grid_pos": Vector2i(4, 0), "decor_id": "rock"}
	],
	"south_meadow_edge": [
		{"grid_pos": Vector2i(0, 8), "decor_id": "flower_patch"},
		{"grid_pos": Vector2i(2, 8), "decor_id": "tall_grass"},
		{"grid_pos": Vector2i(3, 8), "decor_id": "rock"},
		{"grid_pos": Vector2i(4, 8), "decor_id": "flower_patch"},
		{"grid_pos": Vector2i(9, 8), "decor_id": "tall_grass"},
		{"grid_pos": Vector2i(10, 7), "decor_id": "flower_patch"}
	],
	"east_grove_edge": [
		{"grid_pos": Vector2i(7, 8), "decor_id": "flower_patch"},
		{"grid_pos": Vector2i(8, 7), "decor_id": "tall_grass"},
		{"grid_pos": Vector2i(9, 5), "decor_id": "flower_patch"},
		{"grid_pos": Vector2i(9, 6), "decor_id": "rock"},
		{"grid_pos": Vector2i(10, 5), "decor_id": "tree"}
	]
}

@export var width: int = 11
@export var height: int = 9
@export var tile_size: float = 1.0

var day: int = 1
var show_grid: bool = true
var tiles: Dictionary = {}

var _origin_x: float
var _origin_z: float


func _ready() -> void:
	generate()


func generate() -> void:
	_clear_children(self)
	tiles.clear()

	_origin_x = -float(width - 1) * tile_size * 0.5
	_origin_z = -float(height - 1) * tile_size * 0.5

	for x in range(width):
		for z in range(height):
			var tile = TileScene.instantiate()
			var grid_pos := Vector2i(x, z)
			tile.name = "Tile_%s_%s" % [x, z]
			tile.position = grid_to_world(grid_pos)
			tile.setup(grid_pos, tile_size)
			tile.set_grid_visible(show_grid)
			add_child(tile)
			tiles[grid_pos] = tile

	_build_initial_farm()
	_build_shadow_card()


func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(_origin_x + grid_pos.x * tile_size, 0.0, _origin_z + grid_pos.y * tile_size)


func get_tile(grid_pos: Vector2i):
	return tiles.get(grid_pos)


func get_tile_from_world(world_position: Vector3):
	var gx := int(round((world_position.x - _origin_x) / tile_size))
	var gz := int(round((world_position.z - _origin_z) / tile_size))
	if gx < 0 or gz < 0 or gx >= width or gz >= height:
		return null
	return get_tile(Vector2i(gx, gz))


func starter_decor_clusters() -> Dictionary:
	return STARTER_DECOR_CLUSTERS.duplicate(true)


func set_grid_visible(is_visible: bool) -> void:
	show_grid = is_visible
	for tile in tiles.values():
		tile.set_grid_visible(is_visible)


func advance_day() -> void:
	day += 1
	for tile in tiles.values():
		tile.grow_crop()
	day_advanced.emit(day)


func _build_initial_farm() -> void:
	for x in range(width):
		get_tile(Vector2i(x, 4)).set_terrain("dirt_path")
	for z in range(1, height - 1):
		get_tile(Vector2i(5, z)).set_terrain("dirt_path")
	for grid_pos in [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3)]:
		get_tile(grid_pos).set_terrain("dirt_path")

	get_tile(Vector2i(7, 1)).place_item("barn")
	get_tile(Vector2i(9, 1)).place_item("silo")
	get_tile(Vector2i(4, 3)).place_item("well")
	get_tile(Vector2i(8, 2)).place_item("wooden_sign")
	get_tile(Vector2i(8, 1)).place_item("fence")
	get_tile(Vector2i(6, 1)).place_item("fence")
	get_tile(Vector2i(7, 2)).place_item("flower_patch")
	get_tile(Vector2i(4, 1)).place_item("tree")
	get_tile(Vector2i(0, 6)).place_item("rock")
	_build_starter_decor_clusters()

	var corn_tiles := [
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
		Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
		Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 6)
	]
	var stage := 0
	for grid_pos in corn_tiles:
		var tile = get_tile(grid_pos)
		tile.till()
		tile.plant_corn()
		if tile.crop:
			tile.crop.setup("corn", stage % 4)
		stage += 1

	var wheat_tiles := [
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)
	]
	stage = 1
	for grid_pos in wheat_tiles:
		var tile = get_tile(grid_pos)
		tile.till()
		tile.plant_wheat()
		if tile.crop:
			tile.crop.setup("wheat", stage % 4)
		stage += 1

	for grid_pos in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 7), Vector2i(2, 7), Vector2i(9, 7), Vector2i(10, 2), Vector2i(10, 6)]:
		get_tile(grid_pos).place_item("tall_grass")


func _build_starter_decor_clusters() -> void:
	for cluster_id in STARTER_DECOR_CLUSTER_ORDER:
		_place_decor_entries(STARTER_DECOR_CLUSTERS.get(cluster_id, []))


func _place_decor_entries(decor_entries: Array) -> void:
	for entry in decor_entries:
		var grid_pos: Vector2i = entry.get("grid_pos", Vector2i(-1, -1))
		var tile = get_tile(grid_pos)
		if tile != null:
			tile.place_item(str(entry.get("decor_id", "")))


func _build_shadow_card() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width + 3.5, height + 3.0)

	var plane := MeshInstance3D.new()
	plane.name = "SoftBackgroundPlane"
	plane.mesh = mesh
	plane.position = Vector3(0.0, -0.58, 0.0)
	plane.material_override = VoxelFactory.material(Color("#fbf8ef"))
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	move_child(plane, 0)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

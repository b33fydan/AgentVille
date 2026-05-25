class_name Crop
extends Node3D

const VoxelFactory := preload("res://scripts/core/Voxel.gd")

var crop_id: String = "corn"
var stage: int = 0
var max_stage: int = 3
var wind_enabled: bool = true
var wind_strength: float = 0.026
var wind_speed: float = 1.8

var _wind_phase: float = 0.0


func setup(new_crop_id: String = "corn", initial_stage: int = 0) -> void:
	crop_id = new_crop_id
	max_stage = 3
	stage = clampi(initial_stage, 0, max_stage)
	_wind_phase = float(abs(hash("%s_%s" % [name, crop_id])) % 1000) / 100.0
	refresh()


func _process(delta: float) -> void:
	if not wind_enabled:
		return

	var pulse := sin(Time.get_ticks_msec() * 0.001 * wind_speed + _wind_phase)
	var lift := cos(Time.get_ticks_msec() * 0.001 * (wind_speed * 0.74) + _wind_phase * 0.7)
	rotation.x = pulse * wind_strength * (0.45 + stage * 0.16)
	rotation.z = lift * wind_strength * 0.62


func grow() -> bool:
	if stage >= max_stage:
		return false

	stage += 1
	refresh()
	_pop()
	return true


func is_ready() -> bool:
	return stage >= max_stage


func harvest_value() -> int:
	if crop_id == "wheat":
		return 9 + stage * 5
	return 12 + stage * 4


func refresh() -> void:
	for child in get_children():
		child.queue_free()

	match crop_id:
		"corn":
			_build_corn()
		"wheat":
			_build_wheat()
		_:
			_build_corn()


func _build_corn() -> void:
	var green := Color("#5f9f45")
	var dark_green := Color("#3f7937")
	var yellow := Color("#f4c84a")
	var gold := Color("#dfa737")

	if stage == 0:
		add_child(VoxelFactory.cube("SproutStem", Vector3(0.12, 0.18, 0.12), green, Vector3(0.0, 0.18, 0.0)))
		add_child(VoxelFactory.cube("SproutLeafA", Vector3(0.22, 0.08, 0.08), dark_green, Vector3(-0.08, 0.24, 0.0)))
		add_child(VoxelFactory.cube("SproutLeafB", Vector3(0.08, 0.08, 0.22), dark_green, Vector3(0.08, 0.28, 0.04)))
		return

	var stalk_count := stage + 1
	var offsets := [
		Vector3(-0.18, 0.0, -0.12),
		Vector3(0.16, 0.0, 0.10),
		Vector3(-0.05, 0.0, 0.18),
		Vector3(0.20, 0.0, -0.18)
	]

	for i in range(stalk_count):
		var offset: Vector3 = offsets[i]
		var height := 0.34 + stage * 0.22
		add_child(VoxelFactory.cube("CornStalk%s" % i, Vector3(0.11, height, 0.11), green, Vector3(offset.x, 0.12 + height * 0.5, offset.z)))
		add_child(VoxelFactory.cube("LeafA%s" % i, Vector3(0.34, 0.08, 0.08), dark_green, Vector3(offset.x - 0.10, 0.28 + stage * 0.12, offset.z)))
		add_child(VoxelFactory.cube("LeafB%s" % i, Vector3(0.08, 0.08, 0.34), dark_green, Vector3(offset.x + 0.08, 0.34 + stage * 0.12, offset.z + 0.08)))

		if stage >= 2:
			add_child(VoxelFactory.cube("CornCob%s" % i, Vector3(0.13, 0.25, 0.13), yellow, Vector3(offset.x + 0.11, 0.42 + stage * 0.16, offset.z)))
		if stage >= 3:
			add_child(VoxelFactory.cube("CornTop%s" % i, Vector3(0.12, 0.12, 0.12), gold, Vector3(offset.x, 0.88, offset.z)))


func _build_wheat() -> void:
	var stem := Color("#c99a37")
	var stem_dark := Color("#9d7632")
	var wheat_gold := Color("#f0c85a")
	var wheat_light := Color("#ffe07b")

	if stage == 0:
		for i in range(3):
			var offset := Vector3(-0.14 + i * 0.14, 0.0, -0.06 + i * 0.05)
			add_child(VoxelFactory.cube("WheatShoot%s" % i, Vector3(0.055, 0.20, 0.055), Color("#8fb653"), Vector3(offset.x, 0.20, offset.z)))
		return

	var offsets := [
		Vector3(-0.26, 0.0, -0.18),
		Vector3(-0.10, 0.0, -0.04),
		Vector3(0.08, 0.0, -0.18),
		Vector3(0.24, 0.0, 0.02),
		Vector3(-0.22, 0.0, 0.18),
		Vector3(0.02, 0.0, 0.18),
		Vector3(0.24, 0.0, 0.20)
	]
	var count := 3 + stage * 2
	var stalk_height := 0.30 + stage * 0.17

	for i in range(min(count, offsets.size())):
		var offset: Vector3 = offsets[i]
		var color := stem if i % 2 == 0 else stem_dark
		add_child(VoxelFactory.cube("WheatStem%s" % i, Vector3(0.055, stalk_height, 0.055), color, Vector3(offset.x, 0.18 + stalk_height * 0.5, offset.z)))
		add_child(VoxelFactory.cube("WheatHead%s" % i, Vector3(0.11, 0.18 + stage * 0.045, 0.09), wheat_gold if stage >= 2 else wheat_light, Vector3(offset.x, 0.35 + stalk_height, offset.z)))
		if stage >= 2:
			add_child(VoxelFactory.cube("WheatBeardA%s" % i, Vector3(0.18, 0.035, 0.035), wheat_light, Vector3(offset.x - 0.035, 0.46 + stalk_height, offset.z)))
			add_child(VoxelFactory.cube("WheatBeardB%s" % i, Vector3(0.035, 0.035, 0.18), wheat_light, Vector3(offset.x + 0.035, 0.50 + stalk_height, offset.z)))


func _pop() -> void:
	var tween := create_tween()
	scale = Vector3.ONE * 0.92
	tween.tween_property(self, "scale", Vector3.ONE * 1.08, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

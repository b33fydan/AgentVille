class_name SoundManager
extends Node

@export var enabled: bool = true
@export var use_placeholder_tones: bool = true
@export_range(-48.0, 0.0, 0.5) var placeholder_volume_db: float = -20.0

var asset_paths := {
	"ui_click": "res://audio/sfx/ui_click.ogg",
	"tool_select": "res://audio/sfx/tool_select.ogg",
	"till_soft": "res://audio/sfx/till_soft.ogg",
	"plant_pop": "res://audio/sfx/plant_pop.ogg",
	"place_soft": "res://audio/sfx/place_soft.ogg",
	"erase_puff": "res://audio/sfx/erase_puff.ogg",
	"harvest_chime": "res://audio/sfx/harvest_chime.ogg",
	"coin_burst": "res://audio/sfx/coin_burst.ogg",
	"day_advance": "res://audio/sfx/day_advance.ogg",
	"error_soft": "res://audio/sfx/error_soft.ogg",
	"compile_success": "res://audio/sfx/compile_success.ogg",
	"run_dispatch": "res://audio/sfx/run_dispatch.ogg",
	"receipt_pass": "res://audio/sfx/receipt_pass.ogg",
	"lesson_complete": "res://audio/sfx/lesson_complete.ogg"
}

var placeholder_shapes := {
	"ui_click": {"freq": 680.0, "duration": 0.055, "wave": "sine"},
	"tool_select": {"freq": 520.0, "duration": 0.075, "wave": "sine"},
	"till_soft": {"freq": 145.0, "duration": 0.11, "wave": "noise"},
	"plant_pop": {"freq": 610.0, "duration": 0.09, "wave": "pop"},
	"place_soft": {"freq": 360.0, "duration": 0.10, "wave": "sine"},
	"erase_puff": {"freq": 190.0, "duration": 0.12, "wave": "noise"},
	"harvest_chime": {"freq": 880.0, "duration": 0.16, "wave": "sine"},
	"coin_burst": {"freq": 1180.0, "duration": 0.12, "wave": "sine"},
	"day_advance": {"freq": 420.0, "duration": 0.22, "wave": "sine"},
	"error_soft": {"freq": 150.0, "duration": 0.14, "wave": "sine"},
	# The Workbench stamps intentionally differ in pitch, length, and contour so
	# compile, dispatch, proof, and mastery remain legible without visual focus.
	"compile_success": {"freq": 720.0, "duration": 0.09, "wave": "pop"},
	"run_dispatch": {"freq": 405.0, "duration": 0.13, "wave": "sine"},
	"receipt_pass": {"freq": 960.0, "duration": 0.18, "wave": "sine"},
	"lesson_complete": {"freq": 1240.0, "duration": 0.26, "wave": "pop"}
}

var _loaded_streams: Dictionary = {}


func get_placeholder_profile(stamp_name: String) -> Dictionary:
	var profile = placeholder_shapes.get(stamp_name, {})
	if typeof(profile) != TYPE_DICTIONARY:
		return {}
	return (profile as Dictionary).duplicate(true)


func play_stamp(stamp_name: String) -> void:
	if not enabled:
		return

	var stream := _get_stream(stamp_name)
	if stream == null and use_placeholder_tones:
		stream = _make_placeholder_stream(stamp_name)

	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "SFX_%s" % stamp_name
	player.stream = stream
	player.volume_db = placeholder_volume_db if use_placeholder_tones else 0.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _get_stream(stamp_name: String) -> AudioStream:
	if _loaded_streams.has(stamp_name):
		return _loaded_streams[stamp_name]

	if not asset_paths.has(stamp_name):
		return null

	var path: String = asset_paths[stamp_name]
	if not ResourceLoader.exists(path):
		return null

	var stream := load(path) as AudioStream
	_loaded_streams[stamp_name] = stream
	return stream


func _make_placeholder_stream(stamp_name: String) -> AudioStreamWAV:
	var shape: Dictionary = placeholder_shapes.get(stamp_name, placeholder_shapes["ui_click"])
	var sample_rate := 22050
	var duration: float = shape["duration"]
	var sample_count := int(sample_rate * duration)
	var freq: float = shape["freq"]
	var wave: String = shape["wave"]
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / float(sample_rate)
		var fade_in := minf(1.0, t / 0.01)
		var fade_out := minf(1.0, (duration - t) / 0.035)
		var envelope := fade_in * fade_out
		var value := _sample_wave(wave, freq, t, i) * envelope * 0.42
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream


func _sample_wave(wave: String, freq: float, t: float, sample_index: int) -> float:
	match wave:
		"noise":
			var rough := sin(float(sample_index) * 12.9898) * 43758.5453
			return (fposmod(rough, 1.0) * 2.0 - 1.0) * sin(TAU * freq * t * 0.25)
		"pop":
			var pitch := freq + 140.0 * (1.0 - minf(1.0, t * 12.0))
			return sin(TAU * pitch * t)
		_:
			return sin(TAU * freq * t)

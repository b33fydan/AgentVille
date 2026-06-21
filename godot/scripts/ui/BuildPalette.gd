class_name BuildPalette
extends Control

signal item_selected(item_id: String)

var _category_names := ["Terrain", "Crops", "Nature", "Decor", "Structures", "Tools"]
var _items_by_category := {
	"Terrain": [
		{"id": "grass_block", "icon": "GRS", "label": "Grass"},
		{"id": "dirt_road", "icon": "RD", "label": "Road"},
		{"id": "soil", "icon": "SOIL", "label": "Tilled"}
	],
	"Crops": [
		{"id": "corn_seed", "icon": "CRN", "label": "Corn"},
		{"id": "wheat_seed", "icon": "WHT", "label": "Wheat"}
	],
	"Nature": [
		{"id": "tall_grass", "icon": "TGR", "label": "Tall Grass"},
		{"id": "tree", "icon": "TRE", "label": "Tree"},
		{"id": "flower_patch", "icon": "FLR", "label": "Flowers"},
		{"id": "rock", "icon": "RCK", "label": "Rock"}
	],
	"Decor": [
		{"id": "fence", "icon": "FNC", "label": "Fence"},
		{"id": "wooden_sign", "icon": "SGN", "label": "Sign"}
	],
	"Structures": [
		{"id": "barn", "icon": "BRN", "label": "Barn"},
		{"id": "silo", "icon": "SLO", "label": "Silo"},
		{"id": "well", "icon": "WEL", "label": "Well"}
	],
	"Tools": [
		{"id": "pickaxe", "icon": "PCK", "label": "Pickaxe"},
		{"id": "sickle", "icon": "SCK", "label": "Sickle"}
	]
}

var _active_category: String = "Terrain"
var _selected_item: String = "grass_block"
var _tab_buttons: Dictionary = {}
var _item_buttons: Dictionary = {}
var _items_row: HBoxContainer


func _ready() -> void:
	_build()
	_select_category("Terrain")
	set_selected_item("grass_block")


func set_selected_item(item_id: String) -> void:
	_selected_item = item_id
	for key in _item_buttons.keys():
		var button := _item_buttons[key] as Button
		var active: bool = str(key) == _selected_item
		button.add_theme_color_override("font_color", Color("#2d3b1d") if active else Color("#4b4337"))
		button.add_theme_stylebox_override("normal", _button_style(active))


func _build() -> void:
	var panel := PanelContainer.new()
	panel.name = "PalettePanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	stack.add_child(top_row)

	var build_label := Label.new()
	build_label.text = "BUILD"
	build_label.custom_minimum_size = Vector2(54, 32)
	build_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	build_label.add_theme_font_size_override("font_size", 12)
	build_label.add_theme_color_override("font_color", Color("#8a806f"))
	top_row.add_child(build_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	top_row.add_child(tabs)

	for category in _category_names:
		var button := Button.new()
		button.text = category
		button.custom_minimum_size = Vector2(96, 32)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color("#4b4337"))
		button.pressed.connect(_select_category.bind(category))
		tabs.add_child(button)
		_tab_buttons[category] = button

	_items_row = HBoxContainer.new()
	_items_row.add_theme_constant_override("separation", 10)
	stack.add_child(_items_row)


func _select_category(category: String) -> void:
	_active_category = category
	for key in _tab_buttons.keys():
		var button := _tab_buttons[key] as Button
		var active: bool = str(key) == category
		button.add_theme_color_override("font_color", Color("#2d3b1d") if active else Color("#6e665a"))
		button.add_theme_stylebox_override("normal", _tab_style(active))
		button.add_theme_stylebox_override("hover", _tab_style(true))
		button.add_theme_stylebox_override("pressed", _tab_style(true))
	_rebuild_items()


func _rebuild_items() -> void:
	for child in _items_row.get_children():
		child.queue_free()
	_item_buttons.clear()

	for data in _items_by_category[_active_category]:
		var button := Button.new()
		button.text = "%s\n%s" % [data["icon"], data["label"]]
		button.tooltip_text = data["label"]
		button.custom_minimum_size = Vector2(116, 70)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color("#191816"))
		var active: bool = data["id"] == _selected_item
		button.add_theme_color_override("font_color", Color("#2d3b1d") if active else Color("#4b4337"))
		button.add_theme_stylebox_override("normal", _button_style(active))
		button.add_theme_stylebox_override("hover", _button_style(true))
		button.add_theme_stylebox_override("pressed", _button_style(true))
		button.pressed.connect(_select_item.bind(data["id"]))
		_items_row.add_child(button)
		_item_buttons[data["id"]] = button


func _select_item(item_id: String) -> void:
	set_selected_item(item_id)
	item_selected.emit(item_id)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.992, 0.965, 0.94)
	style.border_color = Color("#6e5b3e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.15)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style


func _tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#eef4e4") if active else Color(1, 1, 1, 0)
	style.border_color = Color("#7b914d") if active else Color(0, 0, 0, 0)
	style.set_border_width_all(1 if active else 0)
	style.set_corner_radius_all(10)
	return style


func _button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#eef4e4") if active else Color("#fffaf0")
	style.border_color = Color("#7b914d") if active else Color("#d3c4aa")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	if active:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.10)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
	return style

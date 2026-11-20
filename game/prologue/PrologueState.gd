extends Node

# Persistent state shared across standalone PoE 2-style prologue zones
var has_started := false
var has_sword := false
var has_spring_saddle := false
var slime_buff_active := false
var timber_broken := false
var gate_opened := false
var boss_retired := false
var waypoint_road_unlocked := false
var mounted := false
var player_hp := 5

var spawn_tag := "default"
var is_transitioning := false

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _zone_banner: Label

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	# Warm storybook parchment-mist transition veil instead of harsh pure black
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.11, 0.14, 0.24, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

	_zone_banner = Label.new()
	_zone_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_zone_banner.position = Vector2(-260, -28)
	_zone_banner.custom_minimum_size = Vector2(520, 56)
	_zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zone_banner.add_theme_font_size_override("font_size", 28)
	_zone_banner.add_theme_color_override("font_color", Color("#fff2cc"))
	_zone_banner.add_theme_color_override("font_outline_color", Color("#171b2b"))
	_zone_banner.add_theme_constant_override("outline_size", 8)
	_zone_banner.modulate.a = 0.0
	_zone_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_zone_banner)

func reset_all() -> void:
	has_started = false
	has_sword = false
	has_spring_saddle = false
	slime_buff_active = false
	timber_broken = false
	gate_opened = false
	boss_retired = false
	waypoint_road_unlocked = false
	mounted = false
	player_hp = 5
	spawn_tag = "default"
	transition_to("res://prologue/CampfireClearing.tscn", "default", "林間營火空地")

func transition_to(scene_path: String, target_spawn := "default", destination_title := "") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	spawn_tag = target_spawn
	_zone_banner.text = ("正在前往：" + destination_title) if not destination_title.is_empty() else ""

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_fade_rect, "color:a", 0.96, 0.24)
	if not destination_title.is_empty():
		tw.tween_property(_zone_banner, "modulate:a", 1.0, 0.20)
	tw.chain().tween_callback(func() -> void:
		get_tree().change_scene_to_file(scene_path)
		var tw_in := create_tween().set_parallel(true)
		tw_in.tween_property(_fade_rect, "color:a", 0.0, 0.34)
		tw_in.tween_property(_zone_banner, "modulate:a", 0.0, 0.22)
		tw_in.chain().tween_callback(func() -> void:
			is_transitioning = false
		)
	)

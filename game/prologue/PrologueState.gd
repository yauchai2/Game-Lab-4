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

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.05, 0.07, 0.14, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

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
	transition_to("res://prologue/CampfireClearing.tscn", "default")

func transition_to(scene_path: String, target_spawn := "default") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	spawn_tag = target_spawn
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(scene_path)
		var tw_in := create_tween()
		tw_in.tween_property(_fade_rect, "color:a", 0.0, 0.30)
		tw_in.tween_callback(func() -> void:
			is_transitioning = false
		)
	)

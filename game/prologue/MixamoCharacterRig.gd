extends Node3D

# Plug-and-play Mixamo / Humanoid FBX & GLB Character Rig Loader for Godot 4.7
# Drop any Mixamo character ("With Skin") as `character.fbx` or `character.glb`
# and animations ("Without Skin", In Place) as `idle.fbx`, `run.fbx`, `slash.fbx`,
# `spin.fbx`, `dodge.fbx`, `fall.fbx` into `res://assets/animations/mixamo/`.

const MIXAMO_DIR := "res://assets/animations/mixamo"
const GOUACHE_SHADER := preload("res://shaders/amelicart_gouache.gdshader")

var loaded := false
var anim_player: AnimationPlayer
var current_state := ""
var state_map: Dictionary = {}

func try_load_mixamo_character(shadow_tint: Color) -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(MIXAMO_DIR)):
		return false

	var char_path := _find_character_file()
	if char_path.is_empty():
		return false

	var packed := ResourceLoader.load(char_path) as PackedScene
	if packed == null:
		return false

	var inst := packed.instantiate()
	if inst == null:
		return false
	add_child(inst)
	# Normalize Mixamo default scale (~1.75m) to storybook chibi-adventure proportion (~1.25m)
	inst.scale = Vector3.ONE * 0.72
	_apply_gouache_style_recursive(inst, shadow_tint)

	anim_player = _find_animation_player(inst)
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		inst.add_child(anim_player)

	_register_embedded_animations()
	_load_external_clip("idle", ["idle.fbx", "Idle.fbx", "idle.glb"])
	_load_external_clip("run", ["run.fbx", "Running.fbx", "run.glb"])
	_load_external_clip("slash", ["slash.fbx", "Sword And Shield Slash.fbx", "slash.glb"])
	_load_external_clip("spin", ["spin.fbx", "Sword And Shield Spin.fbx", "spin.glb"])
	_load_external_clip("dodge", ["dodge.fbx", "Stand To Roll.fbx", "dodge.glb"])
	_load_external_clip("fall", ["fall.fbx", "Falling Idle.fbx", "fall.glb"])

	loaded = true
	play_state("idle")
	return true

func play_state(state_name: String, force_restart := false) -> void:
	if not loaded or anim_player == null:
		return
	var target_anim := String(state_map.get(state_name, ""))
	if target_anim.is_empty():
		target_anim = String(state_map.get("idle", ""))
	if target_anim.is_empty():
		return
	if current_state == state_name and not force_restart and anim_player.is_playing():
		return
	current_state = state_name
	anim_player.play(target_anim, 0.14)

func _find_character_file() -> String:
	for fname: String in ["character.glb", "character.fbx", "Character.fbx", "ybot.fbx", "xbot.fbx"]:
		var p: String = MIXAMO_DIR + "/" + fname
		if ResourceLoader.exists(p):
			return p
	var dir := DirAccess.open(MIXAMO_DIR)
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while not f.is_empty():
			if not dir.current_is_dir() and (f.ends_with(".glb") or f.ends_with(".fbx")):
				var low := f.to_lower()
				if not low.begins_with("idle") and not low.begins_with("run") and not low.begins_with("slash") and not low.begins_with("spin") and not low.begins_with("dodge") and not low.begins_with("fall"):
					dir.list_dir_end()
					return MIXAMO_DIR + "/" + f
			f = dir.get_next()
		dir.list_dir_end()
	return ""

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var found := _find_animation_player(c)
		if found:
			return found
	return null

func _register_embedded_animations() -> void:
	for anim_name in anim_player.get_animation_list():
		var low := String(anim_name).to_lower()
		if low.contains("idle") and not state_map.has("idle"):
			state_map["idle"] = anim_name
		elif (low.contains("run") or low.contains("walk")) and not state_map.has("run"):
			state_map["run"] = anim_name
		elif (low.contains("slash") or low.contains("attack")) and not state_map.has("slash"):
			state_map["slash"] = anim_name
		elif (low.contains("spin") or low.contains("whirl")) and not state_map.has("spin"):
			state_map["spin"] = anim_name
		elif (low.contains("roll") or low.contains("dodge")) and not state_map.has("dodge"):
			state_map["dodge"] = anim_name
		elif (low.contains("fall") or low.contains("jump")) and not state_map.has("fall"):
			state_map["fall"] = anim_name

func _load_external_clip(state_key: String, candidates: Array[String]) -> void:
	for fname in candidates:
		var path := MIXAMO_DIR + "/" + fname
		if not ResourceLoader.exists(path):
			continue
		var clip_scene := ResourceLoader.load(path) as PackedScene
		if clip_scene == null:
			continue
		var clip_inst := clip_scene.instantiate()
		var clip_ap := _find_animation_player(clip_inst)
		if clip_ap:
			var list := clip_ap.get_animation_list()
			if not list.is_empty():
				var src_anim := clip_ap.get_animation(list[0]).duplicate() as Animation
				if state_key in ["idle", "run", "fall"]:
					src_anim.loop_mode = Animation.LOOP_LINEAR
				var lib_name := &"mixamo"
				var lib: AnimationLibrary
				if anim_player.has_animation_library(lib_name):
					lib = anim_player.get_animation_library(lib_name)
				else:
					lib = AnimationLibrary.new()
					anim_player.add_animation_library(lib_name, lib)
				if not lib.has_animation(state_key):
					lib.add_animation(state_key, src_anim)
				state_map[state_key] = "mixamo/" + state_key
		clip_inst.queue_free()
		return

func _apply_gouache_style_recursive(node: Node, shadow_tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var col := Color("#4da1e8")
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var surf_mat := mi.get_active_material(0)
			if surf_mat is StandardMaterial3D:
				col = (surf_mat as StandardMaterial3D).albedo_color
		var sm := ShaderMaterial.new()
		sm.shader = GOUACHE_SHADER
		sm.set_shader_parameter("albedo_color", col)
		sm.set_shader_parameter("shadow_tint", shadow_tint)
		mi.material_override = sm
	for c in node.get_children():
		_apply_gouache_style_recursive(c, shadow_tint)

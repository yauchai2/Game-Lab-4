extends Node3D

# Shared @amelicart-inspired matte gouache palette (warm-vs-cool contrast)
const NIGHT_GRASS := Color("#2c4357")
const NIGHT_GRASS_LIGHT := Color("#39586e")
const DAY_GRASS := Color("#dc9648")
const DAY_GRASS_WARM := Color("#e8a856")
const MEADOW_GREEN := Color("#88b655")
const MEADOW_LIGHT := Color("#a1c96b")
const TRAIL := Color("#e8c38e")
const TRAIL_STONE := Color("#d8b68c")
const BOARDWALK := Color("#c97e49")
const STONE := Color("#888596")
const STONE_LIGHT := Color("#bab6c8")
const TIMBER := Color("#78523d")
const TIMBER_LIGHT := Color("#ac7b56")
const WHITE_WALL := Color("#f9f3e8")
const CORAL_ROOF := Color("#db776b")
const BLUE_CURTAIN := Color("#1e6fa8")
const BUNTING_BLUE := Color("#5d96d8")
const PINE_DARK := Color("#1e3148")
const PINE_ORANGE := Color("#d95732")
const PINE_TEAL := Color("#2e6b6b")
const MIST_CYAN := Color("#66eae6")
const FIRE_ORANGE := Color("#ff9838")
const GOLD := Color("#f5c65b")
const GOBLIN_GREEN := Color("#6ec25a")
const PINK_PEAK := Color("#da97ca")
const PURPLE_PEAK := Color("#988ad6")
const CLOUD_WHITE := Color("#f8ecf3")
const STAMP_RED := Color("#e03c3c")

# Minimalist Storybook UI Palette
const UI_PARCHMENT := Color("#fbf2df")
const UI_WOOD_BORDER := Color("#6b4a35")
const UI_INK := Color("#2e211b")
const UI_DARK_BG := Color(0.09, 0.12, 0.21, 0.80)
const UI_ACCENT_GOLD := Color("#f5c65b")
const UI_HP_RED := Color("#e0534f")
const UI_HP_BG := Color("#3d2d29")

const PLAYER_RADIUS := 0.30
const WOLF_RADIUS := 0.82

const GOUACHE_SHADER := preload("res://shaders/amelicart_gouache.gdshader")
const GRASS_SHADER := preload("res://shaders/stylized_grass.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/painterly_foliage.gdshader")
const WATER_SEA_SHADER := preload("res://shaders/living_water_sea.gdshader")
const MIXAMO_RIG_SCRIPT := preload("res://prologue/MixamoCharacterRig.gd")
const MINIMAP_SCRIPT := preload("res://prologue/MinimapOverlay.gd")
const WORLD_MAP_SCRIPT := preload("res://prologue/WorldMapOverlay.gd")
var scene_shadow_tint := Color("#464d7a")
var scene_world_key := "clearing"
var mixamo_rig: Node3D
var minimap_overlay: Control
var world_map_overlay: Control

# 60 FPS integer frame counter hitstop (never mutates Engine.time_scale)
var hitstop_frames := 0
var attack_cooldown := 0.0
var wolf_charge_cooldown := 0.0
var wolf_charge_max := 1.4
var wolf_charge_timer := 0.0
var shake_time := 0.0
var shake_strength := 0.18
var air_slam_active := false
var vertical_vel := 0.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var dodge_max_cd := 0.75
var dodge_dir := Vector3.ZERO
var invuln_timer := 0.0
var combo_step := 0
var combo_reset_timer := 0.0
var hit_combo_count := 0
var hit_combo_timer := 0.0
var emote_timer := 0.0
var subtitle_timer := 0.0
var input_locked := false
var can_attack := true
var inv_open := false
var selected_inv_idx := -1

var player := CharacterBody3D.new()
var player_visual := Node3D.new()
var wolf := CharacterBody3D.new()
var wolf_visual := Node3D.new()
var wolf_tail: Node3D
var bird := Node3D.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()

var player_sword: MeshInstance3D
var wolf_spring_pad: MeshInstance3D
var player_emote: Label3D
var wolf_emote: Label3D

# Organic world animation & juicy VFX pools
var sway_items: Array[Dictionary] = []
var float_motes: Array[Dictionary] = []
var living_npcs: Array[Dictionary] = []
var bouncing_coins: Array[Dictionary] = []
var water_ripples: Array[Dictionary] = []
var cloud_puffs: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var destructibles: Array[Dictionary] = []
var flying_birds: Array[Dictionary] = []
var bird_alert_target := Vector3.INF
var _walk_phase := 0.0
var _wolf_phase := 0.0

# Cinematic Camera Director (allows breaking 2.5D ortho for story & dramatic moments)
var default_cam_size := 16.0
var cinematic_active := false
var cinematic_timer := 0.0
var cinematic_cam_pos := Vector3.ZERO
var cinematic_look_at := Vector3.ZERO
var letterbox_top: ColorRect
var letterbox_bottom: ColorRect

# Minimalist Storybook HUD nodes
var hud_layer: CanvasLayer
var hud_root: Control
var zone_badge_label: Label
var objective_label: Label
var quest_log_label: Label
var hp_hearts_label: Label
var gear_tags_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label

# Boss HP Bar (Top-Center) & Combo Counter Badge
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_hp_bar: ProgressBar
var boss_state_badge: Label
var combo_badge_panel: PanelContainer
var combo_badge_label: Label

# Compact Bottom Hotbar Pills
var slot_attack: PanelContainer
var slot_attack_cd: ColorRect
var slot_attack_sub: Label
var slot_dodge: PanelContainer
var slot_dodge_cd: ColorRect
var slot_mount: PanelContainer
var slot_mount_sub: Label
var slot_wolf: PanelContainer
var slot_wolf_cd: ColorRect
var slot_flask: PanelContainer
var slot_flask_sub: Label
var slot_bag: PanelContainer
var slot_coop: PanelContainer
var slot_reset: PanelContainer

# PoE 2 Inventory, Support Seals & Currency Crafting Modal (press I)
var inv_panel: PanelContainer
var inv_stats_label: Label
var inv_equipped_label: Label
var inv_currency_label: Label
var inv_seal_row: HBoxContainer
var inv_list_box: VBoxContainer
var inv_feedback_label: Label

# --- Procedural matte gouache & organic storybook builders ---
func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false, unshaded := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var mesh := mesh_at(parent, pos, shape, color, unshaded)
	if solid:
		var collider_shape := BoxShape3D.new()
		collider_shape.size = size
		var body := StaticBody3D.new()
		mesh.add_child(body)
		add_shape(body, collider_shape, Vector3.ZERO)
	return mesh

func add_shape(body: CollisionObject3D, shape: Shape3D, offset: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = offset
	body.add_child(collider)

func set_wind_profile(dir: Vector2, speed: float, strength: float, scale_val := 0.14) -> void:
	RenderingServer.global_shader_parameter_set("wind_direction", dir)
	RenderingServer.global_shader_parameter_set("wind_speed", speed)
	RenderingServer.global_shader_parameter_set("wind_strength", strength)
	RenderingServer.global_shader_parameter_set("wind_scale", scale_val)

func make_foliage_material(col: Color) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = FOLIAGE_SHADER
	sm.set_shader_parameter("foliage_color", col)
	sm.set_shader_parameter("highlight_color", col.lightened(0.22))
	sm.set_shader_parameter("shadow_tint", scene_shadow_tint)
	return sm

func mesh_at(parent: Node3D, pos: Vector3, mesh: Mesh, color: Color, unshaded := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	if unshaded:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		material.metallic = 0.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		instance.material_override = material
	else:
		var sm := ShaderMaterial.new()
		sm.shader = GOUACHE_SHADER
		sm.set_shader_parameter("albedo_color", color)
		sm.set_shader_parameter("shadow_tint", scene_shadow_tint)
		instance.material_override = sm
	instance.mesh = mesh
	parent.add_child(instance)
	instance.position = pos
	return instance

func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 14
	mesh.rings = 7
	var instance := mesh_at(parent, pos, mesh, color, unshaded)
	instance.scale = size
	return instance

func cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, h: float, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 14
	return mesh_at(parent, pos, mesh, color, unshaded)

func organic_mound(parent: Node3D, pos: Vector3, rx: float, rz: float, h: float, color: Color, rot_deg := 0.0, unshaded := false) -> MeshInstance3D:
	var m := cylinder(parent, pos, rx * 0.94, rx, h, color, unshaded)
	m.scale = Vector3(1.0, 1.0, rz / maxf(rx, 0.01))
	m.rotation_degrees.y = rot_deg
	return m

func curved_path(points: Array[Vector3], width: float, color: Color, stone_accent := Color.TRANSPARENT) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var dist := a.distance_to(b)
		var steps := maxi(3, int(ceil(dist / (width * 0.42))))
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var p := a.lerp(b, t)
			var jitter := Vector3(sin(float(i * 11 + s * 7)) * 0.12, 0.0, cos(float(i * 5 + s * 9)) * 0.12)
			var r := width * (0.48 + sin(float(i * 3 + s * 5)) * 0.07)
			var disc := cylinder(self, Vector3(p.x + jitter.x, 0.016, p.z + jitter.z), r, r * 1.06, 0.032, color)
			disc.scale.z = 0.82 + absf(sin(float(i * 7 + s * 3))) * 0.34
			disc.rotation_degrees.y = fmod(float(i * 37 + s * 23), 180.0)
			if stone_accent != Color.TRANSPARENT and (s % 2 == 0):
				var st := cylinder(self, Vector3(p.x - jitter.x * 1.4, 0.025, p.z + jitter.z * 1.2), r * 0.34, r * 0.38, 0.03, stone_accent)
				st.scale.z = 0.75
				st.rotation_degrees.y = float(s * 41)

func boulder_cluster(pos: Vector3, scl := 1.0, col := STONE, with_moss := true, solid := true, rot_deg := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	sphere(root, Vector3(0.0, 0.55 * scl, 0.0), Vector3(1.55, 1.05, 1.32) * scl, col)
	sphere(root, Vector3(0.75 * scl, 0.38 * scl, 0.42 * scl), Vector3(0.92, 0.72, 0.85) * scl, col.darkened(0.08))
	sphere(root, Vector3(-0.68 * scl, 0.32 * scl, -0.35 * scl), Vector3(0.85, 0.62, 0.78) * scl, col.lightened(0.06))
	if with_moss:
		sphere(root, Vector3(0.05 * scl, 0.96 * scl, -0.05 * scl), Vector3(1.18, 0.38, 0.98) * scl, Color("#4e7c48"))
	if solid:
		var body := StaticBody3D.new()
		root.add_child(body)
		var sh := SphereShape3D.new()
		sh.radius = 0.95 * scl
		add_shape(body, sh, Vector3(0.0, 0.65 * scl, 0.0))
	return root

func cozy_tree(pos: Vector3, scale_val := 1.0, foliage_col := MEADOW_GREEN, lean_deg := 0.0, solid := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_val
	root.rotation_degrees.y = fmod(absf(pos.x * 37.0 + pos.z * 53.0), 360.0)
	add_child(root)
	var trunk := cylinder(root, Vector3(0, 1.15, 0), 0.22, 0.36, 2.3, TIMBER)
	trunk.rotation_degrees.z = lean_deg
	var crown := Node3D.new()
	crown.position = Vector3(-sin(deg_to_rad(lean_deg)) * 1.1, 2.55, 0)
	root.add_child(crown)
	var fmat := make_foliage_material(foliage_col)
	for part in [
		[Vector3(0.0, 0.0, 0.0), Vector3(2.35, 1.85, 2.15)],
		[Vector3(0.85, -0.25, 0.45), Vector3(1.55, 1.35, 1.50)],
		[Vector3(-0.78, -0.18, -0.42), Vector3(1.48, 1.28, 1.42)],
		[Vector3(0.15, 0.68, -0.15), Vector3(1.32, 1.05, 1.25)]
	]:
		var s := sphere(crown, part[0], part[1], foliage_col)
		s.material_override = fmat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Non-flickering static shadow proxy (matches Stylized Trees video technique)
	var shadow_proxy := sphere(root, crown.position, Vector3(2.1, 1.65, 2.0), foliage_col)
	shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sway_items.append({"node": crown, "base_rot": crown.rotation, "amp": 0.025, "speed": 1.6, "phase": pos.x * 0.7 + pos.z * 0.5})
	if solid:
		var body := StaticBody3D.new()
		root.add_child(body)
		var sh := CylinderShape3D.new()
		sh.radius = 0.55 * scale_val
		sh.height = 2.4 * scale_val
		add_shape(body, sh, Vector3(0, 1.2 * scale_val, 0))
	return root

func pine_tree(pos: Vector3, scale_val := 1.0, tint := PINE_DARK, solid := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_val
	root.rotation_degrees = Vector3(sin(pos.x) * 3.0, fmod(absf(pos.x * 41.0 + pos.z * 29.0), 360.0), cos(pos.z) * 4.0)
	add_child(root)
	cylinder(root, Vector3(0, 1.05, 0), 0.22, 0.34, 2.1, TIMBER)
	var foliage := Node3D.new()
	foliage.position = Vector3(0, 1.8, 0)
	root.add_child(foliage)
	var fmat := make_foliage_material(tint)
	var c1 := cylinder(foliage, Vector3(0.06, 0.65, 0), 0.25, 1.55, 2.0, tint)
	var c2 := cylinder(foliage, Vector3(-0.08, 1.95, 0.05), 0.16, 1.18, 1.8, tint)
	var c3 := sphere(foliage, Vector3(0.0, 2.85, 0.0), Vector3(0.85, 0.95, 0.85), tint)
	for n in [c1, c2, c3]:
		n.material_override = fmat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow_proxy := cylinder(root, Vector3(0, 2.6, 0), 0.3, 1.45, 3.2, tint)
	shadow_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sway_items.append({"node": foliage, "base_rot": foliage.rotation, "amp": 0.022, "speed": 1.4, "phase": pos.x * 0.6 + pos.z * 0.4})
	if solid:
		var body := StaticBody3D.new()
		root.add_child(body)
		var sh := CylinderShape3D.new()
		sh.radius = 0.65 * scale_val
		sh.height = 2.4 * scale_val
		add_shape(body, sh, Vector3(0, 1.2 * scale_val, 0))
	return root

func spawn_wind_grass_meadow(center: Vector3, rx: float, rz: float, count: int, base_col: Color, tip_col: Color, flower_col := Color("#ff8ab0"), flower_ratio := 0.16, height_scale := 1.0) -> MultiMeshInstance3D:
	# High-performance MultiMeshInstance3D wind-blown @amelicart grass tufts (bottom-aligned pivot!)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.76, 0.64 * height_scale)
	quad.center_offset = Vector3(0.0, 0.32 * height_scale, 0.0)
	var gmat := ShaderMaterial.new()
	gmat.shader = GRASS_SHADER
	gmat.set_shader_parameter("base_color", base_col)
	gmat.set_shader_parameter("tip_color", tip_col)
	gmat.set_shader_parameter("flower_color", flower_col)
	gmat.set_shader_parameter("shadow_tint", scene_shadow_tint)
	quad.material = gmat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = count
	for i in range(count):
		var ang := float(i) * 2.39996 + center.x * 0.17
		var rad := sqrt((float(i) + 0.5) / float(maxi(1, count)))
		var px := center.x + cos(ang) * rad * rx
		var pz := center.z + sin(ang) * rad * rz
		var s := 0.78 + fmod(absf(sin(float(i) * 12.9898) * 43758.5453), 0.56)
		var xform := Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(px, 0.01, pz))
		mm.set_instance_transform(i, xform)
		var is_fl := 1.0 if fmod(absf(sin(float(i) * 78.233) * 19341.1), 1.0) < flower_ratio else 0.0
		mm.set_instance_custom_data(i, Color(is_fl, 0.0, 0.0, 1.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

func flower_patch(pos: Vector3, count: int, colors: Array[Color], spread := 1.6) -> void:
	for i in range(count):
		var ang := float(i) * 2.399 + pos.x * 0.3
		var dist := sqrt(float(i + 1) / float(count)) * spread
		var fp := pos + Vector3(cos(ang) * dist, 0.06, sin(ang) * dist)
		var col := colors[i % colors.size()]
		sphere(self, fp, Vector3(0.18, 0.14, 0.18), col, true)
		if i % 2 == 0:
			cylinder(self, fp + Vector3(0.12, 0.06, -0.08), 0.02, 0.05, 0.24, Color("#497542"))

func lantern_post(pos: Vector3, height := 2.6, glow_col := FIRE_ORANGE, rot_deg := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	var pole := cylinder(root, Vector3(0, height * 0.5, 0), 0.08, 0.11, height, TIMBER)
	pole.rotation_degrees.z = 4.0
	var arm := box(root, Vector3(0.32, height - 0.18, 0), Vector3(0.75, 0.10, 0.10), TIMBER_LIGHT)
	arm.rotation_degrees.z = -8.0
	var lamp := sphere(root, Vector3(0.62, height - 0.52, 0), Vector3(0.42, 0.48, 0.42), glow_col, true)
	sway_items.append({"node": lamp, "base_rot": lamp.rotation, "amp": 0.08, "speed": 2.2, "phase": pos.x + pos.z})
	return root

func bunting_line(a: Vector3, b: Vector3, sag: float, colors: Array[Color], flag_count := 7) -> void:
	for i in range(flag_count):
		var t := float(i + 1) / float(flag_count + 1)
		var p := a.lerp(b, t)
		p.y -= sin(t * PI) * sag
		var flag := cylinder(self, p, 0.22, 0.02, 0.42, colors[i % colors.size()], true)
		flag.scale.z = 0.25
		flag.rotation.y = atan2(b.x - a.x, b.z - a.z) + PI * 0.5
		sway_items.append({"node": flag, "base_rot": flag.rotation, "amp": 0.11, "speed": 2.6, "phase": float(i) * 0.6})

func spawn_ambient_motes(center: Vector3, span: Vector3, count: int, col: Color, size := 0.11) -> void:
	for i in range(count):
		var base_p := center + Vector3(
			randf_range(-span.x * 0.5, span.x * 0.5),
			randf_range(0.5, span.y),
			randf_range(-span.z * 0.5, span.z * 0.5)
		)
		var mote := sphere(self, base_p, Vector3.ONE * size, col, true)
		float_motes.append({"node": mote, "base": base_p, "phase": randf_range(0.0, TAU), "speed": randf_range(0.9, 1.9), "amp": randf_range(0.25, 0.55)})

# --- @shoejaat (Little Joy) Style Nature, Water, Cliff & Light Builders ---
func curved_stream(points: Array[Vector3], width: float, water_col := Color("#3496e8"), foam_col := Color("#d8f6ff"), y_level := -0.18) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var dist := a.distance_to(b)
		var steps := maxi(4, int(ceil(dist / (width * 0.35))))
		for s in range(steps + 1):
			var t := float(s) / float(steps)
			var p := a.lerp(b, t)
			var r := width * (0.52 + sin(float(i * 5 + s * 3)) * 0.08)
			var rim := cylinder(self, Vector3(p.x, y_level - 0.03, p.z), r * 1.18, r * 1.22, 0.04, foam_col, true)
			rim.scale.z = 0.88
			var wat := cylinder(self, Vector3(p.x, y_level, p.z), r, r * 1.04, 0.05, water_col, true)
			wat.scale.z = 0.86
			if s % 3 == 0:
				var rip := cylinder(self, Vector3(p.x, y_level + 0.035, p.z), r * 0.38, r * 0.38, 0.012, foam_col, true)
				water_ripples.append({"node": rip, "phase": float(i * 7 + s) * 0.65})

func waterfall_cascade(pos: Vector3, width := 2.0, height := 3.2, rot_deg := 0.0, water_col := Color("#52b8ff"), foam_col := Color("#eefbff")) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	boulder_cluster(pos + Vector3(-width * 0.72, 0.0, -0.3), 1.15, STONE, true, true, 18.0)
	boulder_cluster(pos + Vector3(width * 0.72, 0.0, -0.3), 1.15, STONE_LIGHT, true, true, -24.0)
	for ri in range(3):
		var ox := (-0.32 + float(ri) * 0.32) * width
		var rib := box(root, Vector3(ox, height * 0.45, 0.0), Vector3(width * 0.32, height, 0.24), water_col if ri != 1 else foam_col, false, true)
		rib.rotation_degrees.x = 12.0
		sway_items.append({"node": rib, "base_rot": rib.rotation, "amp": 0.03, "speed": 4.2, "phase": float(ri)})
	var splash := cylinder(root, Vector3(0, 0.06, 0.65), width * 0.62, width * 0.72, 0.14, foam_col, true)
	water_ripples.append({"node": splash, "phase": pos.x})
	return root

func wooden_footbridge(pos: Vector3, length := 3.6, width := 1.8, rot_deg := 0.0, arch_h := 0.38) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	var planks := 7
	for i in range(planks):
		var t := (float(i) / float(planks - 1)) - 0.5
		var px := t * length
		var py := cos(t * PI) * arch_h + 0.16
		var pl := box(root, Vector3(px, py, 0.0), Vector3(length / float(planks) * 0.86, 0.14, width), TIMBER_LIGHT if i % 2 == 0 else BOARDWALK)
		pl.rotation_degrees.z = -sin(t * PI) * 14.0
	for sx in [-length * 0.44, 0.0, length * 0.44]:
		var py_p := cos((sx / length) * PI) * arch_h + 0.55
		for sz in [-width * 0.48, width * 0.48]:
			cylinder(root, Vector3(sx, py_p, sz), 0.08, 0.10, 0.95, TIMBER)
	for sz in [-width * 0.48, width * 0.48]:
		box(root, Vector3(0, arch_h + 0.82, sz), Vector3(length * 0.92, 0.09, 0.09), TIMBER_LIGHT)
	return root

func cliff_outcrop(pos: Vector3, rx := 2.6, ry := 2.2, rz := 2.4, rock_col := STONE_LIGHT, top_col := MEADOW_GREEN, rot_deg := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	cylinder(root, Vector3(0, ry * 0.5, 0), rx * 0.92, rx, ry, rock_col)
	sphere(root, Vector3(rx * 0.45, ry * 0.42, rz * 0.35), Vector3(rx * 0.85, ry * 0.92, rz * 0.85), rock_col.darkened(0.08))
	organic_mound(root, Vector3(0, ry + 0.08, 0), rx * 0.98, rz * 0.98, 0.36, top_col, 8.0)
	var body := StaticBody3D.new()
	root.add_child(body)
	var sh := CylinderShape3D.new()
	sh.radius = maxf(rx, rz) * 0.88
	sh.height = ry
	add_shape(body, sh, Vector3(0, ry * 0.5, 0))
	return root

func sunbeam_shaft(pos: Vector3, width := 2.8, length := 18.0, tint := Color(1.0, 0.94, 0.68, 0.11)) -> void:
	var beam := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(width, length, 0.25)
	beam.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = mat
	beam.position = pos + Vector3(0, length * 0.35, 0)
	beam.rotation_degrees = Vector3(18.0, -18.0, 28.0)
	add_child(beam)

func fluffy_cloud(pos: Vector3, scl := 1.0, drift_amp := 1.6, col := CLOUD_WHITE) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scl
	add_child(root)
	sphere(root, Vector3(0.0, 0.0, 0.0), Vector3(3.4, 1.7, 2.6), col, true)
	sphere(root, Vector3(-1.3, -0.2, 0.3), Vector3(2.2, 1.3, 2.0), col, true)
	sphere(root, Vector3(1.4, -0.15, -0.2), Vector3(2.4, 1.35, 2.1), col, true)
	cloud_puffs.append({"node": root, "base": pos, "amp": drift_amp, "phase": pos.x * 0.3 + pos.z * 0.2})
	return root

# --- Expanded Exploration & Zero-Void 360 Panorama Builders ---
func stone_archway(pos: Vector3, rot_deg := 0.0, scl := 1.0, with_steps := true) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	root.scale = Vector3.ONE * scl
	add_child(root)
	box(root, Vector3(-1.65, 1.55, 0.0), Vector3(0.85, 3.1, 0.95), STONE_LIGHT, true)
	box(root, Vector3(1.65, 1.55, 0.0), Vector3(0.85, 3.1, 0.95), STONE_LIGHT, true)
	box(root, Vector3(0.0, 3.35, 0.0), Vector3(4.5, 0.78, 1.08), STONE)
	sphere(root, Vector3(-1.55, 3.68, 0.1), Vector3(1.15, 0.45, 0.95), Color("#4e7c48"))
	sphere(root, Vector3(1.45, 3.65, -0.1), Vector3(1.05, 0.42, 0.90), Color("#5d8f52"))
	if with_steps:
		for si in range(4):
			box(root, Vector3(0.0, 0.08 + float(si) * 0.06, 0.9 + float(si) * 0.65), Vector3(2.8 - float(si) * 0.12, 0.16, 0.58), STONE_LIGHT if si % 2 == 0 else STONE)
	return root

func cozy_cabin(pos: Vector3, rot_deg := 0.0, roof_col := Color("#d6583a"), wall_col := TIMBER_LIGHT) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	box(root, Vector3(0, 1.35, 0), Vector3(3.8, 2.7, 3.2), wall_col, true)
	var roof := cylinder(root, Vector3(0, 3.35, 0), 0.25, 2.85, 1.75, roof_col)
	roof.scale = Vector3(1.05, 1.0, 0.92)
	box(root, Vector3(0, 0.95, 1.65), Vector3(0.95, 1.85, 0.16), TIMBER)
	box(root, Vector3(-1.1, 1.55, 1.65), Vector3(0.65, 0.65, 0.12), Color("#ffe394"), false, true)
	box(root, Vector3(1.1, 1.55, 1.65), Vector3(0.65, 0.65, 0.12), Color("#ffe394"), false, true)
	cylinder(root, Vector3(1.0, 3.9, -0.6), 0.24, 0.28, 1.35, STONE)
	for si in range(3):
		var puff := sphere(root, Vector3(1.0 + float(si) * 0.18, 4.8 + float(si) * 0.65, -0.6), Vector3(0.42 + float(si) * 0.14, 0.36 + float(si) * 0.10, 0.42 + float(si) * 0.14), CLOUD_WHITE, true)
		float_motes.append({"node": puff, "base": puff.position, "phase": float(si) * 1.4, "speed": 1.6, "amp": 0.22})
	return root

func lighthouse_islet(pos: Vector3, rot_deg := 0.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	organic_mound(root, Vector3(0, -0.35, 0), 4.6, 4.2, 0.85, Color("#f2d594"), 12.0)
	organic_mound(root, Vector3(0, 0.05, 0), 3.2, 2.9, 0.28, MEADOW_GREEN, -8.0)
	# Red & white striped lighthouse (@shoejaat c09084c9)
	for bi in range(5):
		var col := Color("#e34b3b") if bi % 2 == 0 else WHITE_WALL
		var r_bot := 1.02 - float(bi) * 0.11
		var r_top := 0.91 - float(bi) * 0.11
		cylinder(root, Vector3(0, 0.65 + float(bi) * 1.05, 0), r_top, r_bot, 1.06, col)
	cylinder(root, Vector3(0, 6.0, 0), 0.68, 0.68, 0.55, Color("#fff5b8"), true)
	cylinder(root, Vector3(0, 6.6, 0), 0.12, 0.78, 0.72, Color("#e34b3b"))
	# Tiny moored wooden boat + orange lifebuoy on the water
	var boat := box(root, Vector3(3.8, -0.05, 2.2), Vector3(2.2, 0.36, 0.85), Color("#e67347"))
	boat.rotation_degrees.y = 28.0
	sway_items.append({"node": boat, "base_rot": boat.rotation, "amp": 0.04, "speed": 1.8, "phase": 0.5})
	cylinder(root, Vector3(5.2, -0.08, -1.8), 0.48, 0.48, 0.14, Color("#ff6b3d"), true)
	return root

func build_horizon_panorama(center: Vector3, inner_rx: float, inner_rz: float, theme: String) -> void:
	# 1. Animated living water / starry lake / rolling sunset cloud-sea (ZERO flat single-color void!)
	var deep_c := Color("#122645")
	var shallow_c := Color("#1f416e")
	var foam_c := Color("#8cd4f5")
	var hill_cols: Array[Color] = [Color("#1c3352"), Color("#223f63"), Color("#2b4c73")]
	var tree_cols: Array[Color] = [PINE_DARK, PINE_TEAL, Color("#254a5c")]
	var cloud_col := Color("#98b4d9")
	var w_scale := 0.14
	var w_speed := 0.28
	if theme == "day_island":
		deep_c = Color("#1264c4")
		shallow_c = Color("#2ca2f0")
		foam_c = Color("#e8faff")
		hill_cols = [Color("#6fb362"), Color("#84c26b"), Color("#5aa06e")]
		tree_cols = [MEADOW_GREEN, MEADOW_LIGHT, PINE_TEAL]
		cloud_col = CLOUD_WHITE
		w_scale = 0.16
		w_speed = 0.42
	elif theme == "sunset_clouds":
		deep_c = Color("#b297d6")
		shallow_c = Color("#f0c4de")
		foam_c = Color("#fff4e6")
		hill_cols = [PINK_PEAK, PURPLE_PEAK, Color("#b29ce0")]
		tree_cols = [PINE_ORANGE, Color("#d97836"), Color("#4a6b8a")]
		cloud_col = Color("#fff1f6")
		w_scale = 0.09
		w_speed = 0.24

	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2((inner_rx + 120.0) * 2.0, (inner_rz + 120.0) * 2.0)
	var sea_inst := MeshInstance3D.new()
	sea_inst.mesh = sea_mesh
	var smat := ShaderMaterial.new()
	smat.shader = WATER_SEA_SHADER
	smat.set_shader_parameter("deep_color", deep_c)
	smat.set_shader_parameter("shallow_color", shallow_c)
	smat.set_shader_parameter("foam_color", foam_c)
	smat.set_shader_parameter("wave_scale", w_scale)
	smat.set_shader_parameter("wave_speed", w_speed)
	sea_inst.material_override = smat
	sea_inst.position = Vector3(center.x, -1.25, center.z)
	add_child(sea_inst)

	# 2. ZERO-GAP INNER BORDER RING (tightly hugs playable terrain so no flat void ever shows!)
	if theme == "night_forest":
		# Dense Little Joy 360-degree forest ring hugging the walkable boundary
		for i in range(28):
			var ang := float(i) * TAU / 28.0
			var p := center + Vector3(cos(ang) * (inner_rx + 2.5 + float(i % 3) * 2.8), -0.45, sin(ang) * (inner_rz + 2.0 + float(i % 3) * 2.4))
			organic_mound(self, p, 7.8 + float(i % 3) * 1.8, 6.8 + float(i % 2) * 1.6, 1.35, hill_cols[i % hill_cols.size()], float(i) * 19.0)
			pine_tree(p + Vector3(0.0, 0.55, 0.0), 1.35 + float(i % 3) * 0.22, tree_cols[i % tree_cols.size()], false)
			cozy_tree(p + Vector3(cos(ang + 0.5) * 3.0, 0.55, sin(ang + 0.5) * 2.6), 1.15 + float(i % 2) * 0.22, tree_cols[(i + 1) % tree_cols.size()], float((i % 3) - 1) * 6.0, false)
	elif theme == "day_island":
		# Golden sandy shoreline + double white coastal foam rings (@shoejaat e986e55c!)
		organic_mound(self, Vector3(center.x, -0.78, center.z), inner_rx + 3.2, inner_rz + 2.8, 0.62, Color("#f2d694"), 4.0)
		var foam_outer := organic_mound(self, Vector3(center.x, -1.10, center.z), inner_rx + 5.6, inner_rz + 5.0, 0.14, Color("#d8f6ff"), -6.0, true)
		water_ripples.append({"node": foam_outer, "phase": 0.4})
		for i in range(10):
			var ang := float(i) * TAU / 10.0 + 0.35
			var ip := center + Vector3(cos(ang) * (inner_rx + 12.5 + float(i % 3) * 4.5), -0.65, sin(ang) * (inner_rz + 10.5 + float(i % 3) * 3.8))
			organic_mound(self, ip, 6.2 + float(i % 3) * 1.6, 5.4 + float(i % 2) * 1.4, 0.85, Color("#f2d694"), float(i) * 29.0)
			organic_mound(self, ip + Vector3(0, 0.45, 0), 4.6 + float(i % 3) * 1.2, 4.0 + float(i % 2) * 1.1, 0.55, hill_cols[i % hill_cols.size()], float(i) * 15.0)
			cozy_tree(ip + Vector3(0, 0.72, 0), 1.15 + float(i % 2) * 0.25, tree_cols[i % tree_cols.size()], 4.0, false)
			boulder_cluster(ip + Vector3(2.2, 0.25, -1.4), 0.9, STONE_LIGHT, true, false, float(i) * 30.0)
	elif theme == "sunset_clouds":
		# Dense billowing low cloud-sea pillows + autumn tree ridge tightly hugging the canyon edges
		for i in range(28):
			var ang := float(i) * TAU / 28.0
			var cp := center + Vector3(cos(ang) * (inner_rx + 3.5 + float(i % 3) * 3.5), -0.95 + float(i % 2) * 0.7, sin(ang) * (inner_rz + 3.0 + float(i % 3) * 2.8))
			fluffy_cloud(cp, 1.85 + float(i % 3) * 0.45, 2.0, cloud_col)
			if i % 2 == 0:
				var hp := center + Vector3(cos(ang) * (inner_rx + 12.0), -0.55, sin(ang) * (inner_rz + 10.5))
				organic_mound(self, hp, 9.2, 7.6, 1.8, hill_cols[i % hill_cols.size()], float(i) * 17.0)
				cozy_tree(hp + Vector3(0, 0.9, 0), 1.35, tree_cols[i % tree_cols.size()], 5.0, false)

	# 3. Outer ring of lush distant hills & trees (360 degrees)
	for i in range(18):
		var ang := float(i) * TAU / 18.0 + 0.18
		var dist_x := inner_rx + 22.0 + fmod(float(i * 7), 12.0)
		var dist_z := inner_rz + 18.0 + fmod(float(i * 5), 10.0)
		var pos := center + Vector3(cos(ang) * dist_x, -0.65, sin(ang) * dist_z)
		organic_mound(self, pos, 10.5 + float(i % 4) * 2.4, 8.8 + float(i % 3) * 2.2, 2.2, hill_cols[i % hill_cols.size()], float(i) * 23.0)
		for ti in range(2):
			var tp := pos + Vector3(cos(ang + float(ti) * 0.9) * 3.8, 1.05, sin(ang + float(ti) * 0.9) * 3.2)
			if (i + ti) % 2 == 0:
				pine_tree(tp, 1.55 + float(ti) * 0.25, tree_cols[(i + ti) % tree_cols.size()], false)
			else:
				cozy_tree(tp, 1.35 + float(ti) * 0.2, tree_cols[(i + ti) % tree_cols.size()], float((i % 3) - 1) * 6.0, false)

	# 4. Far horizon stylized @amelicart rounded mountain peaks
	for mi in range(16):
		var mang := float(mi) * TAU / 16.0 + 0.2
		var mpos := center + Vector3(cos(mang) * (inner_rx + 56.0), 4.5 + float(mi % 3) * 3.2, sin(mang) * (inner_rz + 50.0))
		sphere(self, mpos, Vector3(19.0 + float(mi % 4) * 4.0, 24.0 + float(mi % 3) * 7.5, 17.0 + float(mi % 3) * 3.5), hill_cols[mi % hill_cols.size()].lightened(0.08), true)

	# 5. Sky layer of drifting volumetric clouds all around the horizon
	for ci in range(14):
		var cang := float(ci) * TAU / 14.0
		var cpos := center + Vector3(cos(cang) * (inner_rx + 30.0), 8.2 + float(ci % 3) * 3.0, sin(cang) * (inner_rz + 25.0))
		fluffy_cloud(cpos, 1.85 + float(ci % 3) * 0.4, 2.8, cloud_col)

	# 6. Theme sky landmarks (crescent moon + stars for night; buoys & lifebuoys for day; skyship for sunset)
	if theme == "night_forest":
		sphere(self, center + Vector3(-16.0, 22.0, -48.0), Vector3(4.2, 4.2, 1.2), Color("#fff3b0"), true)
		sphere(self, center + Vector3(-14.6, 22.6, -47.2), Vector3(3.6, 3.6, 1.2), Color("#122242"), true)
		for si in range(28):
			var sang := float(si) * 2.399
			var spos := center + Vector3(cos(sang) * (inner_rx + 40.0), 14.0 + fmod(float(si * 7), 14.0), sin(sang) * (inner_rz + 38.0))
			sphere(self, spos, Vector3.ONE * (0.28 + float(si % 3) * 0.12), Color("#fff8d6"), true)
	elif theme == "day_island":
		for bi in range(6):
			var bang := float(bi) * TAU / 6.0 + 0.55
			var bpos := center + Vector3(cos(bang) * (inner_rx + 8.5), -1.05, sin(bang) * (inner_rz + 7.5))
			var buoy := Node3D.new()
			buoy.position = bpos
			add_child(buoy)
			cylinder(buoy, Vector3(0, 0.3, 0), 0.55, 0.68, 0.55, Color("#e34b3b"), true)
			cylinder(buoy, Vector3(0, 0.72, 0), 0.28, 0.35, 0.35, WHITE_WALL, true)
			sway_items.append({"node": buoy, "base_rot": buoy.rotation, "amp": 0.09, "speed": 2.1, "phase": float(bi)})
	elif theme == "sunset_clouds":
		sphere(self, center + Vector3(58.0, 22.0, -36.0), Vector3(7.6, 7.6, 2.0), Color("#ffe39e"), true)
		var ship := Node3D.new()
		ship.position = center + Vector3(34.0, 13.5, -24.0)
		add_child(ship)
		sphere(ship, Vector3(0, 0, 0), Vector3(2.8, 1.2, 1.4), TIMBER_LIGHT, true)
		box(ship, Vector3(0, 1.5, 0), Vector3(0.18, 2.6, 2.2), Color("#3b6fb6"), false, true)
		cloud_puffs.append({"node": ship, "base": ship.position, "amp": 4.5, "phase": 0.4})

func register_living_npc(node: Node3D, base_y := 0.0, bob_amp := 0.06, speed := 3.2) -> void:
	living_npcs.append({"node": node, "base_y": base_y, "amp": bob_amp, "speed": speed, "phase": randf_range(0.0, TAU)})

func build_fellow_rider(pos: Vector3, rider_tunic: Color, beast_col: Color, beast_scale: Vector3, title_txt: String, badge_col := Color("#d6f0ff")) -> Dictionary:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	sphere(root, Vector3(0, 0.72, 0), beast_scale, beast_col)
	sphere(root, Vector3(0, 1.05, beast_scale.z * 0.48), Vector3(0.66, 0.60, 0.66), beast_col.lightened(0.08))
	cylinder(root, Vector3(0, 1.48, 0), 0.22, 0.25, 0.45, rider_tunic)
	sphere(root, Vector3(0, 1.88, 0), Vector3(0.46, 0.44, 0.44), Color("#f4c9a8"))
	cylinder(root, Vector3(0, 2.12, 0), 0.07, 0.30, 0.26, rider_tunic.darkened(0.18))
	sphere(root, Vector3(0.28, 2.38, 0.1), Vector3(0.26, 0.22, 0.26), Color("#ffbf3c"))
	var name_lbl := label_at(root, Vector3(0, 2.68, 0), title_txt, badge_col, 22)
	var bubble_lbl := label_at(root, Vector3(0, 3.16, 0), "", Color("#fff7c2"), 26)
	return {"node": root, "name_lbl": name_lbl, "bubble": bubble_lbl, "bubble_t": 0.0}

# --- Juicy ARPG Combat & 3-Second Visual Hook VFX ---
func spawn_damage_pop(pos: Vector3, text_val: String, col := Color.WHITE, big := false) -> void:
	var lbl := label_at(self, pos + Vector3(randf_range(-0.35, 0.35), 1.65, randf_range(-0.25, 0.25)), text_val, col, 48 if big else 34)
	lbl.scale = Vector3.ONE * (1.35 if big else 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + (1.35 if big else 0.95), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.18)
	tw.chain().tween_callback(lbl.queue_free)

func spawn_slash_arc(origin: Vector3, yaw: float, col := Color("#fff5cc")) -> void:
	var arc := Node3D.new()
	arc.position = origin + Vector3(0, 0.65, 0)
	arc.rotation.y = yaw
	add_child(arc)
	for i in range(4):
		var ang := -0.95 + float(i) * 0.62
		var seg := box(arc, Vector3(sin(ang) * 1.15, 0.0, cos(ang) * 1.15), Vector3(0.55, 0.07, 0.18), col, false, true)
		seg.rotation.y = ang
	var tw := create_tween().set_parallel(true)
	tw.tween_property(arc, "scale", Vector3(1.35, 1.0, 1.35), 0.16)
	tw.tween_property(arc, "rotation:y", yaw - 0.85, 0.16)
	tw.chain().tween_callback(arc.queue_free)

func flash_hit(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var orig_s := node.scale
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(orig_s.x * 1.24, orig_s.y * 0.78, orig_s.z * 1.24), 0.06)
	tw.tween_property(node, "scale", orig_s, 0.12)

func pop_in_node(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	node.show()
	node.scale = Vector3(0.1, 0.1, 0.1)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(1.18, 1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector3.ONE, 0.12)

func spawn_bouncing_coins(origin: Vector3, count: int, coin_val := 5) -> void:
	for i in range(count):
		var c := cylinder(self, origin + Vector3(0, 0.55, 0), 0.18, 0.18, 0.06, GOLD, true)
		c.rotation_degrees.x = 75.0
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(2.2, 4.4)
		bouncing_coins.append({
			"node": c,
			"vel": Vector3(cos(ang) * spd, randf_range(4.2, 6.4), sin(ang) * spd),
			"val": coin_val,
			"age": 0.0,
		})

func spawn_wood_burst(origin: Vector3, col := TIMBER_LIGHT, pieces := 8) -> void:
	PrologueState.play_sfx("wood")
	for i in range(pieces):
		var p := box(self, origin + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-1.8, 1.8)), Vector3(0.42, 0.22, 0.22), col)
		var dest := p.position + Vector3(randf_range(1.6, 4.2), randf_range(0.8, 2.2), randf_range(-2.2, 2.2))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position", dest, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation_degrees", Vector3(randf_range(-240, 240), randf_range(-240, 240), randf_range(-240, 240)), 0.42)
		tw.tween_property(p, "scale", Vector3(0.05, 0.05, 0.05), 0.42)
		tw.chain().tween_callback(p.queue_free)

func spawn_destructible_crate(pos: Vector3, coin_count := 3) -> void:
	var crate := Node3D.new()
	crate.position = pos
	crate.rotation_degrees.y = randf_range(-22.0, 22.0)
	add_child(crate)
	box(crate, Vector3(0, 0.46, 0), Vector3(0.92, 0.92, 0.92), TIMBER_LIGHT)
	box(crate, Vector3(0, 0.46, 0), Vector3(0.96, 0.16, 0.96), TIMBER)
	destructibles.append({"node": crate, "pos": pos, "coins": coin_count, "broken": false})

func _damage_destructibles(origin: Vector3, radius := 2.6) -> bool:
	var hit_any := false
	for d in destructibles:
		if bool(d["broken"]):
			continue
		var dn: Node3D = d["node"]
		if not is_instance_valid(dn):
			continue
		if flat(origin - dn.position).length() <= radius:
			d["broken"] = true
			hit_any = true
			var p := dn.position
			dn.queue_free()
			spawn_wood_burst(p, TIMBER_LIGHT, 7)
			spawn_bouncing_coins(p, int(d["coins"]), 5)
			spawn_damage_pop(p, "+%d¢" % (int(d["coins"]) * 5), GOLD, false)
	return hit_any

func play_giant_retirement_stamp(target_pos: Vector3) -> void:
	# The signature 3-Second Visual Hook: Break 2.5D into a dramatic low-angle close-up!
	play_cinematic_shot(target_pos + Vector3(-2.6, 2.35, 5.2), target_pos + Vector3(0, 1.05, 0), 1.25, true, 44.0, true)
	var stamp := Node3D.new()
	stamp.position = target_pos + Vector3(0, 6.2, 0)
	add_child(stamp)
	cylinder(stamp, Vector3(0, 0.85, 0), 0.34, 0.42, 1.35, TIMBER)
	sphere(stamp, Vector3(0, 1.55, 0), Vector3(0.62, 0.56, 0.62), TIMBER_LIGHT)
	cylinder(stamp, Vector3(0, 0.15, 0), 1.18, 1.24, 0.35, STAMP_RED, true)
	label_at(stamp, Vector3(0, 0.45, 0.9), "【正式退休！】", Color("#fff6d1"), 52)

	var tw := create_tween()
	tw.tween_property(stamp, "position:y", 0.35, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		PrologueState.play_sfx("stamp")
		hitstop_frames = 6
		shake_time = 0.28
		shake_strength = 0.26
		var ring := marker(target_pos, STAMP_RED, 2.6)
		var rtw := create_tween()
		rtw.tween_property(ring, "scale", Vector3(2.2, 1.0, 2.2), 0.36)
		rtw.tween_callback(ring.queue_free)
		spawn_bouncing_coins(target_pos, 5, 5)
	)
	tw.tween_interval(0.75)
	tw.tween_property(stamp, "position:y", 6.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(stamp.queue_free)

func invisible_boundary_wall(pos: Vector3, size: Vector3, rot_deg := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = rot_deg
	add_child(body)
	var sh := BoxShape3D.new()
	sh.size = size
	add_shape(body, sh, Vector3.ZERO)

func label_at(parent: Node3D, pos: Vector3, words: String, color := Color.WHITE, font_size := 34) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 9
	label.pixel_size = 0.0082
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.position = pos
	return label

func marker(pos: Vector3, color: Color, radius := 0.58) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	return mesh_at(self, pos + Vector3.UP * 0.035, mesh, color, true)

func transition_signpost(pos: Vector3, icon_title: String, color := GOLD, rot_deg := -12.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = rot_deg
	add_child(root)
	var post := cylinder(root, Vector3(0, 0.85, 0), 0.09, 0.12, 1.75, TIMBER)
	post.rotation_degrees.z = 3.5
	var board := box(root, Vector3(0.28, 1.42, 0), Vector3(1.18, 0.36, 0.12), TIMBER_LIGHT)
	board.rotation_degrees.z = -5.0
	marker(pos + Vector3(0, 0, 0.5), color, 0.78)
	label_at(self, pos + Vector3(0, 2.28, 0), icon_title, color, 28)

# --- Core Trio Builders (with lively organic animations) ---
func setup_core_trio(spawn_pos: Vector3) -> void:
	_make_body(player, spawn_pos, PLAYER_RADIUS)
	player.add_child(player_visual)
	var proc_parts: Array[Node3D] = []
	proc_parts.append(cylinder(player_visual, Vector3(0, 0.34, 0), 0.24, 0.28, 0.52, Color("#4da1e8")))
	proc_parts.append(sphere(player_visual, Vector3(0, 0.60, 0.02), Vector3(0.42, 0.18, 0.38), Color("#d96b43")))
	proc_parts.append(sphere(player_visual, Vector3(0, 0.85, 0.02), Vector3(0.52, 0.50, 0.48), Color("#f4c9a8")))
	proc_parts.append(cylinder(player_visual, Vector3(0, 1.13, 0), 0.08, 0.33, 0.32, Color("#498e62")))
	var feather := box(player_visual, Vector3(-0.22, 1.25, -0.05), Vector3(0.08, 0.32, 0.14), Color("#d7e4ff"))
	feather.rotation_degrees.z = 16.0
	proc_parts.append(feather)
	proc_parts.append(sphere(player_visual, Vector3(0, 0.44, -0.26), Vector3(0.38, 0.38, 0.24), Color("#8c5234")))
	player_sword = box(player_visual, Vector3(0.38, 0.48, 0.28), Vector3(0.11, 0.11, 0.88), Color("#e6f4ff"))
	# Always give the traveler a starter stick/sword feel so combat works from second 1!
	player_sword.visible = true
	mixamo_rig = MIXAMO_RIG_SCRIPT.new()
	player_visual.add_child(mixamo_rig)
	if mixamo_rig.try_load_mixamo_character(scene_shadow_tint):
		for pp in proc_parts:
			pp.hide()
	player_emote = label_at(player, Vector3(0, 1.82, 0), "", Color("#fff59d"), 46)

	_make_body(wolf, spawn_pos + Vector3(-1.45, 0, -0.55), WOLF_RADIUS)
	wolf.add_child(wolf_visual)
	var fur := Color("#464b59")
	var fur_light := Color("#788196")
	sphere(wolf_visual, Vector3(0, 0.78, 0.0), Vector3(1.18, 0.90, 1.88), fur)
	sphere(wolf_visual, Vector3(0, 0.92, 0.68), Vector3(0.95, 0.78, 0.78), fur_light)
	sphere(wolf_visual, Vector3(0, 1.08, 0.95), Vector3(0.76, 0.66, 0.76), fur)
	sphere(wolf_visual, Vector3(0, 0.88, 1.38), Vector3(0.42, 0.32, 0.52), fur_light)
	for sx in [-0.36, 0.36]:
		for sz in [-0.62, 0.62]:
			cylinder(wolf_visual, Vector3(sx, 0.30, sz), 0.13, 0.11, 0.62, fur)
		cylinder(wolf_visual, Vector3(sx * 0.60, 1.56, 0.96), 0.03, 0.17, 0.44, fur)
	wolf_tail = Node3D.new()
	wolf_tail.position = Vector3(0, 0.92, -0.88)
	wolf_visual.add_child(wolf_tail)
	var tail_mesh := sphere(wolf_tail, Vector3(0, 0.08, -0.42), Vector3(0.34, 0.30, 0.86), fur)
	tail_mesh.rotation_degrees.x = 24.0
	sphere(wolf_visual, Vector3(0, 1.24, -0.08), Vector3(0.96, 0.22, 0.76), Color("#a87b54"))
	wolf_spring_pad = cylinder(wolf_visual, Vector3(0, 1.42, -0.08), 0.38, 0.38, 0.22, GOLD)
	wolf_spring_pad.visible = PrologueState.has_spring_saddle
	wolf_emote = label_at(wolf, Vector3(0, 2.28, 0.5), "", Color("#d0ecff"), 40)

	if PrologueState.mounted:
		wolf.position = spawn_pos
		player.position = wolf.position + Vector3.UP * 1.38

	add_child(bird)
	sphere(bird, Vector3.ZERO, Vector3(0.34, 0.30, 0.36), Color("#ffbf3c"))
	box(bird, Vector3(0, 0.0, 0.20), Vector3(0.10, 0.08, 0.12), Color("#e8632c"))
	bird.position = player.position + Vector3(0, 1.45, 0)

func _make_body(body: CharacterBody3D, pos: Vector3, radius: float) -> void:
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 1
	add_child(body)
	var shape := SphereShape3D.new()
	shape.radius = radius
	add_shape(body, shape, Vector3.UP * radius)
	body.position = pos

# --- 2.5D Perspective Fixed Oblique Top-Down Camera (3D Pseudo-Isometric, Subtle Foreshortening) ---
const DEFAULT_CAM_FOV := 26.0

func setup_camera_and_lighting(cam_size: float, bg_col: Color, amb_col: Color, amb_energy: float, sun_col: Color, sun_energy: float, sky_top_col := Color.TRANSPARENT, sky_horizon_col := Color.TRANSPARENT, ground_col := Color.TRANSPARENT) -> void:
	default_cam_size = cam_size
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = DEFAULT_CAM_FOV
	camera.near = 0.5
	camera.far = 280.0
	camera.current = true
	position_camera(feet(), 1.0)

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top_col if sky_top_col != Color.TRANSPARENT else bg_col.darkened(0.22)
	sky_mat.sky_horizon_color = sky_horizon_col if sky_horizon_col != Color.TRANSPARENT else bg_col.lightened(0.18)
	sky_mat.ground_bottom_color = ground_col if ground_col != Color.TRANSPARENT else bg_col.darkened(0.18)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb_col
	env.ambient_light_energy = amb_energy
	camera.environment = env

	add_child(sun)
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.shadow_enabled = true

func set_cinematic_pose(cam_pos: Vector3, look_target: Vector3, use_perspective := true, fov_or_size := 46.0, with_letterbox := true) -> void:
	cinematic_active = true
	cinematic_timer = -1.0
	cinematic_cam_pos = cam_pos
	cinematic_look_at = look_target
	if use_perspective:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov_or_size
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = fov_or_size
	camera.position = cam_pos
	camera.look_at(look_target)
	_set_letterbox(with_letterbox)

func play_cinematic_shot(cam_pos: Vector3, look_target: Vector3, duration := 1.6, use_perspective := true, fov_or_size := 46.0, with_letterbox := true) -> void:
	cinematic_active = true
	cinematic_timer = duration
	cinematic_cam_pos = cam_pos
	cinematic_look_at = look_target
	if use_perspective:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov_or_size
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = fov_or_size
	_set_letterbox(with_letterbox)

func exit_cinematic_shot() -> void:
	if not cinematic_active:
		return
	cinematic_active = false
	cinematic_timer = 0.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = DEFAULT_CAM_FOV
	_set_letterbox(false)
	position_camera(feet(), 1.0)

func _set_letterbox(enabled: bool) -> void:
	if not letterbox_top or not letterbox_bottom:
		return
	var h := 44.0 if enabled else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(letterbox_top, "custom_minimum_size:y", h, 0.28)
	tw.tween_property(letterbox_top, "offset_bottom", h, 0.28)
	tw.tween_property(letterbox_bottom, "offset_top", -h, 0.28)

func spawn_flying_bird_flock(start_pos: Vector3, vel: Vector3, count := 5, col := Color("#f7f9ff")) -> void:
	for i in range(count):
		var b := Node3D.new()
		b.position = start_pos + Vector3(randf_range(-1.8, 1.8), randf_range(-0.6, 1.2), randf_range(-1.5, 1.5))
		add_child(b)
		var lw := box(b, Vector3(-0.22, 0, 0), Vector3(0.42, 0.05, 0.14), col, false, true)
		var rw := box(b, Vector3(0.22, 0, 0), Vector3(0.42, 0.05, 0.14), col, false, true)
		flying_birds.append({"node": b, "lw": lw, "rw": rw, "vel": vel, "age": 0.0, "phase": float(i) * 1.1})

func position_camera(target: Vector3, lerp_weight: float) -> void:
	if cinematic_active:
		camera.position = camera.position.lerp(cinematic_cam_pos, clampf(lerp_weight * 1.4, 0.0, 1.0)) if lerp_weight < 1.0 else cinematic_cam_pos
		camera.look_at(cinematic_look_at)
		return
	var oblique_dir := Vector3(3.2, 14.2, 16.5).normalized()
	var dist := default_cam_size / (2.0 * tan(deg_to_rad(DEFAULT_CAM_FOV * 0.5)))
	var offset := oblique_dir * dist
	var desired := target + offset
	camera.position = camera.position.lerp(desired, lerp_weight) if lerp_weight < 1.0 else desired
	camera.look_at(camera.position - offset)

# --- Minimalist Storybook UI/UX ---
func make_panel_style(bg: Color, border: Color, radius := 14, border_w := 2, pad_x := 14, pad_y := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0.05, 0.06, 0.12, 0.22)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 2)
	return sb

func setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# Cinematic Letterbox Bars (slide in softly when breaking 2.5D for story shots)
	letterbox_top = ColorRect.new()
	letterbox_top.color = Color(0.05, 0.06, 0.11, 0.94)
	letterbox_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	letterbox_top.offset_bottom = 0.0
	letterbox_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(letterbox_top)

	letterbox_bottom = ColorRect.new()
	letterbox_bottom.color = Color(0.05, 0.06, 0.11, 0.94)
	letterbox_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	letterbox_bottom.offset_top = 0.0
	letterbox_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(letterbox_bottom)

	# 1. Top-Left: Ultra-clean Vitals Pill (hearts + compact stat icons)
	var vitals_card := PanelContainer.new()
	vitals_card.position = Vector2(18, 16)
	vitals_card.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_WOOD_BORDER, 18, 2, 14, 7))
	vitals_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(vitals_card)

	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 3)
	vitals_card.add_child(v_box)
	hp_hearts_label = _styled_label("♥ ♥ ♥ ♥ ♥", 16, UI_HP_RED, false)
	v_box.add_child(hp_hearts_label)
	gear_tags_label = _styled_label("", 13, UI_INK, false)
	v_box.add_child(gear_tags_label)

	# 2. Top-Right: Ultra-clean Zone + PoE 2 Minimalist Quest Tracker Pill
	var obj_card := PanelContainer.new()
	obj_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	obj_card.offset_left = -330
	obj_card.offset_right = -18
	obj_card.offset_top = 16
	obj_card.offset_bottom = 112
	obj_card.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, UI_ACCENT_GOLD, 16, 2, 14, 7))
	obj_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(obj_card)

	var o_box := VBoxContainer.new()
	o_box.add_theme_constant_override("separation", 2)
	obj_card.add_child(o_box)
	zone_badge_label = _styled_label("", 12, UI_ACCENT_GOLD, false)
	o_box.add_child(zone_badge_label)
	objective_label = _styled_label("", 14, Color("#fff9eb"), false)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o_box.add_child(objective_label)
	quest_log_label = _styled_label("", 11, Color("#d5e6ff"), false)
	o_box.add_child(quest_log_label)

	combo_badge_panel = PanelContainer.new()
	combo_badge_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	combo_badge_panel.offset_left = -168
	combo_badge_panel.offset_right = -18
	combo_badge_panel.offset_top = 274
	combo_badge_panel.offset_bottom = 312
	combo_badge_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.24, 0.11, 0.08, 0.88), FIRE_ORANGE, 14, 2, 12, 4))
	combo_badge_panel.hide()
	hud_root.add_child(combo_badge_panel)
	combo_badge_label = _styled_label("", 17, GOLD, false)
	combo_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_badge_panel.add_child(combo_badge_label)

	# PoE 2-style Fog-of-War Exploration Minimap (press [Tab] to toggle Corner / Center)
	minimap_overlay = MINIMAP_SCRIPT.new()
	hud_root.add_child(minimap_overlay)

	# PoE 2-style Interactive World Map Overlay (press [U] or interact with Waypoint)
	world_map_overlay = WORLD_MAP_SCRIPT.new()
	hud_layer.add_child(world_map_overlay)

	# 3. Top-Center: Boss HP Bar (only shown during Boss encounter)
	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -210
	boss_panel.offset_right = 210
	boss_panel.offset_top = 16
	boss_panel.offset_bottom = 84
	boss_panel.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, STAMP_RED, 16, 2, 16, 8))
	boss_panel.hide()
	hud_root.add_child(boss_panel)

	var b_box := VBoxContainer.new()
	b_box.add_theme_constant_override("separation", 4)
	boss_panel.add_child(b_box)
	var b_top := HBoxContainer.new()
	b_box.add_child(b_top)
	boss_name_label = _styled_label("稻草人哨長", 15, Color("#fff2cc"), false)
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_top.add_child(boss_name_label)
	boss_state_badge = _styled_label("", 13, GOLD, false)
	b_top.add_child(boss_state_badge)
	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.min_value = 0
	boss_hp_bar.max_value = 10
	boss_hp_bar.value = 10
	boss_hp_bar.show_percentage = false
	boss_hp_bar.custom_minimum_size = Vector2(370, 14)
	boss_hp_bar.add_theme_stylebox_override("background", make_panel_style(UI_HP_BG, UI_WOOD_BORDER, 7, 1, 0, 0))
	boss_hp_bar.add_theme_stylebox_override("fill", make_panel_style(Color("#f06b4f"), Color.TRANSPARENT, 7, 0, 0, 0))
	b_box.add_child(boss_hp_bar)

	# 4. Bottom-Center: Compact Floating Prompt & Clean Action Pills
	var bottom_stack := VBoxContainer.new()
	bottom_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_stack.offset_left = -420
	bottom_stack.offset_right = 420
	bottom_stack.offset_top = -178
	bottom_stack.offset_bottom = -14
	bottom_stack.alignment = BoxContainer.ALIGNMENT_END
	bottom_stack.add_theme_constant_override("separation", 6)
	bottom_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_stack)

	subtitle_panel = PanelContainer.new()
	subtitle_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	subtitle_panel.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, Color("#7382a6"), 14, 1, 16, 6))
	subtitle_panel.hide()
	bottom_stack.add_child(subtitle_panel)
	subtitle_label = _styled_label("", 15, Color("#ffe8a3"), false)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_panel.add_child(subtitle_label)

	prompt_panel = PanelContainer.new()
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_panel.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_ACCENT_GOLD, 20, 2, 16, 6))
	prompt_panel.hide()
	bottom_stack.add_child(prompt_panel)
	prompt_label = _styled_label("", 15, UI_INK, false)
	prompt_panel.add_child(prompt_label)

	var hotbar := HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 7)
	bottom_stack.add_child(hotbar)

	var atk_pair := _make_hotbar_slot(hotbar, "J / 左鍵", "揮劍", Color("#4da1e8"))
	slot_attack = atk_pair[0]
	slot_attack_cd = atk_pair[1]
	slot_attack_sub = atk_pair[2]
	var ddg_pair := _make_hotbar_slot(hotbar, "Space", "翻滾", MIST_CYAN)
	slot_dodge = ddg_pair[0]
	slot_dodge_cd = ddg_pair[1]
	var mnt_pair := _make_hotbar_slot(hotbar, "F", "上鞍", Color("#498e62"))
	slot_mount = mnt_pair[0]
	slot_mount_sub = mnt_pair[2]
	var wlf_pair := _make_hotbar_slot(hotbar, "Q", "巨狼撞", Color("#d97836"))
	slot_wolf = wlf_pair[0]
	slot_wolf_cd = wlf_pair[1]
	var flk_pair := _make_hotbar_slot(hotbar, "1", "水壺 x2", Color("#e0534f"))
	slot_flask = flk_pair[0]
	slot_flask_sub = flk_pair[2]
	var bag_pair := _make_hotbar_slot(hotbar, "I", "造裝", Color("#c99438"))
	slot_bag = bag_pair[0]
	_make_hotbar_slot(hotbar, "U", "世界圖", Color("#4ecdc4"))
	var coop_pair := _make_hotbar_slot(hotbar, "C", "拉隊友", Color("#58b9ff"))
	slot_coop = coop_pair[0]
	var rst_pair := _make_hotbar_slot(hotbar, "R", "重置", Color("#7d8597"))
	slot_reset = rst_pair[0]

	_build_inventory_modal()

func _build_inventory_modal() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inv_panel.offset_left = -350
	inv_panel.offset_right = 350
	inv_panel.offset_top = -225
	inv_panel.offset_bottom = 215
	inv_panel.add_theme_stylebox_override("panel", make_panel_style(Color("#f7f1df"), Color("#b89b72"), 20, 3, 22, 14))
	inv_panel.hide()
	hud_layer.add_child(inv_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 7)
	inv_panel.add_child(root_v)

	# @amelicart Picnic Blanket Fringe Header
	var top_fringe := _styled_label("╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷  ╷", 11, Color("#cbbca0"), false)
	top_fringe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(top_fringe)

	var header := HBoxContainer.new()
	root_v.add_child(header)
	var h_title := _styled_label("🧺 旅人裝備毯 × 造裝工坊  🐥 綠羽帽 · 藍旅衣 · 四葉草 · 水壺", 16, UI_INK, false)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)
	var close_btn := Button.new()
	close_btn.text = "關閉 [I]"
	close_btn.pressed.connect(toggle_inventory)
	header.add_child(close_btn)

	inv_stats_label = _styled_label("", 14, Color("#5a3b28"), false)
	root_v.add_child(inv_stats_label)
	inv_equipped_label = _styled_label("", 13, Color("#244a75"), false)
	root_v.add_child(inv_equipped_label)
	inv_currency_label = _styled_label("", 14, Color("#8a4b16"), false)
	root_v.add_child(inv_currency_label)

	inv_seal_row = HBoxContainer.new()
	inv_seal_row.add_theme_constant_override("separation", 6)
	root_v.add_child(inv_seal_row)

	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 6)
	root_v.add_child(craft_row)

	var btn_equip := Button.new()
	btn_equip.text = "穿戴"
	btn_equip.pressed.connect(func() -> void:
		var msg := PrologueState.equip_from_inventory(selected_inv_idx)
		if not msg.is_empty():
			selected_inv_idx = -1
			player_sword.visible = true
			wolf_spring_pad.visible = PrologueState.has_spring_saddle
			_refresh_inventory_ui(msg)
	)
	craft_row.add_child(btn_equip)

	var btn_blue := Button.new()
	btn_blue.text = "藍印章 (白→藍)"
	btn_blue.pressed.connect(func() -> void:
		_refresh_inventory_ui(PrologueState.craft_blue(selected_inv_idx))
	)
	craft_row.add_child(btn_blue)

	var btn_gold := Button.new()
	btn_gold.text = "金漆罐 (升黃/加詞)"
	btn_gold.pressed.connect(func() -> void:
		_refresh_inventory_ui(PrologueState.craft_gold(selected_inv_idx))
	)
	craft_row.add_child(btn_gold)

	var btn_chaos := Button.new()
	btn_chaos.text = "洗白劑 (重洗黃裝)"
	btn_chaos.pressed.connect(func() -> void:
		_refresh_inventory_ui(PrologueState.craft_chaos(selected_inv_idx))
	)
	craft_row.add_child(btn_chaos)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(650, 180)
	root_v.add_child(scroll)
	inv_list_box = VBoxContainer.new()
	inv_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_list_box.add_theme_constant_override("separation", 5)
	scroll.add_child(inv_list_box)

	inv_feedback_label = _styled_label("選取一件裝備後，即可穿戴或點擊通貨造裝。", 13, Color("#8a2f2f"), false)
	root_v.add_child(inv_feedback_label)

func toggle_inventory() -> void:
	if input_locked and not inv_open:
		return
	inv_open = not inv_open
	inv_panel.visible = inv_open
	if inv_open:
		_refresh_inventory_ui("選取下方裝備即可穿戴或使用造裝通貨！")

func _refresh_inventory_ui(msg := "") -> void:
	if not msg.is_empty():
		inv_feedback_label.text = msg
	inv_stats_label.text = "攻 %d ｜ 暴擊 %d%% ｜ 破防+%d ｜ 移速 %d%% ｜ %d¢" % [
		PrologueState.get_total_atk(),
		PrologueState.get_total_crit(),
		PrologueState.get_stagger_bonus(),
		int(round(PrologueState.get_speed_multiplier() * 100.0)),
		PrologueState.coins
	]
	var w_txt := PrologueState.format_item_details(PrologueState.equipped_weapon) if not PrologueState.equipped_weapon.is_empty() else "木劍（起手）"
	var s_txt := PrologueState.format_item_details(PrologueState.equipped_saddle) if not PrologueState.equipped_saddle.is_empty() else "標準皮鞍"
	inv_equipped_label.text = "武器：%s\n狼鞍：%s" % [w_txt, s_txt]
	inv_currency_label.text = "藍印章 x%d ｜ 金漆罐 x%d ｜ 洗白劑 x%d" % [
		PrologueState.orb_blue, PrologueState.orb_gold, PrologueState.orb_chaos
	]

	if inv_seal_row:
		for sc in inv_seal_row.get_children():
			sc.queue_free()
		inv_seal_row.add_child(_styled_label("輔助印章：", 13, UI_INK, false))
		if PrologueState.unlocked_seals.is_empty():
			inv_seal_row.add_child(_styled_label("尚未取得（探索或擊退敵人解鎖）", 13, Color("#7a634b"), false))
		else:
			for sid in PrologueState.unlocked_seals:
				var sbtn := Button.new()
				var is_on := (PrologueState.active_seal == sid)
				sbtn.text = ("★ " if is_on else "○ ") + PrologueState.get_seal_title(sid)
				var cap_sid := sid
				sbtn.pressed.connect(func() -> void:
					var next_id := "" if PrologueState.active_seal == cap_sid else cap_sid
					_refresh_inventory_ui(PrologueState.set_active_seal(next_id))
				)
				inv_seal_row.add_child(sbtn)

	for c in inv_list_box.get_children():
		c.queue_free()
	if PrologueState.inventory.is_empty():
		inv_list_box.add_child(_styled_label("背包為空，去擊退加班小兵或精英即可噴出光柱裝備！", 13, Color("#6b4a35"), false))
	else:
		for i in range(PrologueState.inventory.size()):
			var item: Dictionary = PrologueState.inventory[i]
			var btn := Button.new()
			var prefix := "▶ " if i == selected_inv_idx else "   "
			btn.text = prefix + PrologueState.format_item_details(item)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_color_override("font_color", PrologueState.rarity_color(item["rarity"]))
			var cap_idx := i
			btn.pressed.connect(func() -> void:
				selected_inv_idx = cap_idx
				_refresh_inventory_ui("已選取：" + PrologueState.format_item_title(item))
			)
			inv_list_box.add_child(btn)
	update_status_line()

func _make_hotbar_slot(parent: HBoxContainer, key_txt: String, title_txt: String, accent: Color) -> Array:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(88, 48)
	slot.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, accent, 14, 2, 6, 4))
	parent.add_child(slot)

	var overlay_host := Control.new()
	overlay_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay_host)

	var cd_rect := ColorRect.new()
	cd_rect.color = Color(0.05, 0.06, 0.12, 0.65)
	cd_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_rect.visible = false
	overlay_host.add_child(cd_rect)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	slot.add_child(vbox)
	var k := _styled_label(key_txt, 11, accent.lightened(0.25), false)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(k)
	var t := _styled_label(title_txt, 13, Color("#fff8e8"), false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	return [slot, cd_rect, t]

func _styled_label(words: String, size: int, color: Color, with_outline := true) -> Label:
	var l := Label.new()
	l.text = words
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if with_outline:
		l.add_theme_color_override("font_outline_color", Color("#181b26"))
		l.add_theme_constant_override("outline_size", 6)
	return l

func set_zone_objective(zone_name: String, goal: String) -> void:
	zone_badge_label.text = zone_name
	objective_label.text = goal
	if quest_log_label:
		quest_log_label.text = PrologueState.get_quest_tracker_text()

func is_world_map_open() -> bool:
	return world_map_overlay != null and world_map_overlay.visible

func open_world_map() -> void:
	if world_map_overlay:
		world_map_overlay.open_map(scene_world_key)

func toggle_world_map() -> void:
	if world_map_overlay:
		world_map_overlay.toggle_map(scene_world_key)

func set_prompt(text_val: String) -> void:
	prompt_label.text = text_val
	prompt_panel.visible = not text_val.is_empty()

func update_boss_bar(visible_flag: bool, boss_title: String, hp_val: int, max_hp_val: int, state_txt := "", badge_col := GOLD) -> void:
	boss_panel.visible = visible_flag
	if not visible_flag:
		return
	boss_name_label.text = boss_title
	boss_hp_bar.max_value = max_hp_val
	boss_hp_bar.value = hp_val
	boss_state_badge.text = state_txt
	boss_state_badge.add_theme_color_override("font_color", badge_col)

func set_hud_visible(flag: bool) -> void:
	if hud_root:
		hud_root.visible = flag

func feet() -> Vector3:
	return wolf.position if PrologueState.mounted else player.position

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func near(pos: Vector3, dist := 2.2) -> bool:
	return flat(feet() - pos).length() < dist

func show_player_emote(icon: String, duration := 1.4) -> void:
	player_emote.text = icon
	emote_timer = duration
	player_emote.scale = Vector3.ONE * 0.4
	create_tween().tween_property(player_emote, "scale", Vector3.ONE, 0.16)

func show_subtitle(words: String, duration := 3.2) -> void:
	subtitle_label.text = words
	subtitle_panel.visible = not words.is_empty()
	subtitle_timer = duration

func move_body(body: CharacterBody3D, dir: Vector3, speed: float) -> void:
	body.velocity = dir * speed
	if dir.length_squared() > 0.002:
		body.rotation.y = atan2(dir.x, dir.z)
	body.move_and_slide()

func _animate_living_world(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for item in sway_items:
		if is_instance_valid(item["node"]):
			var n: Node3D = item["node"]
			var base_r: Vector3 = item["base_rot"]
			n.rotation.z = base_r.z + sin(t * float(item["speed"]) + float(item["phase"])) * float(item["amp"])
	for m in float_motes:
		if is_instance_valid(m["node"]):
			var mn: Node3D = m["node"]
			var bp: Vector3 = m["base"]
			var ph := float(m["phase"])
			var sp := float(m["speed"])
			var am := float(m["amp"])
			mn.position = bp + Vector3(sin(t * sp * 0.7 + ph) * am, sin(t * sp + ph) * am * 0.8, cos(t * sp * 0.6 + ph) * am)
	for npc in living_npcs:
		if is_instance_valid(npc["node"]):
			var nn: Node3D = npc["node"]
			nn.position.y = float(npc["base_y"]) + absf(sin(t * float(npc["speed"]) + float(npc["phase"]))) * float(npc["amp"])
	for r in water_ripples:
		if is_instance_valid(r["node"]):
			var rn: Node3D = r["node"]
			var s := 0.85 + absf(sin(t * 1.9 + float(r["phase"]))) * 0.45
			rn.scale = Vector3(s, 1.0, s)
	for cp in cloud_puffs:
		if is_instance_valid(cp["node"]):
			var cn: Node3D = cp["node"]
			var bp: Vector3 = cp["base"]
			cn.position.x = bp.x + sin(t * 0.28 + float(cp["phase"])) * float(cp["amp"])

	# Magnetic bouncing coins physics (super satisfying ARPG pickup!)
	for i in range(bouncing_coins.size() - 1, -1, -1):
		var c: Dictionary = bouncing_coins[i]
		if not is_instance_valid(c["node"]):
			bouncing_coins.remove_at(i)
			continue
		var cn: Node3D = c["node"]
		c["age"] = float(c["age"]) + delta
		var vel: Vector3 = c["vel"]
		vel.y -= 16.0 * delta
		cn.position += vel * delta
		cn.rotation.y += delta * 6.0
		if cn.position.y < 0.22:
			cn.position.y = 0.22
			vel.y = absf(vel.y) * 0.42
			vel.x *= 0.65
			vel.z *= 0.65
		c["vel"] = vel
		var to_p := feet() + Vector3(0, 0.7, 0) - cn.position
		if float(c["age"]) > 0.35 and to_p.length() < 4.5:
			cn.position += to_p.normalized() * 11.5 * delta
			if to_p.length() < 0.75:
				PrologueState.coins += int(c["val"])
				PrologueState.play_sfx("coin")
				cn.queue_free()
				bouncing_coins.remove_at(i)

	# Slingshot projectile physics
	for i in range(projectiles.size() - 1, -1, -1):
		var pr: Dictionary = projectiles[i]
		if not is_instance_valid(pr["node"]):
			projectiles.remove_at(i)
			continue
		var pn: Node3D = pr["node"]
		pr["age"] = float(pr["age"]) + delta
		pn.position += (pr["vel"] as Vector3) * delta
		pn.rotation.y += delta * 14.0
		var hit := _damage_destructibles(pn.position, 1.3)
		if not hit:
			hit = on_projectile_hit(pn.position)
		if hit or float(pr["age"]) > 0.72:
			pn.queue_free()
			projectiles.remove_at(i)

	# Flying bird flock animation (@amelicart horizon silhouettes)
	for i in range(flying_birds.size() - 1, -1, -1):
		var fb: Dictionary = flying_birds[i]
		if not is_instance_valid(fb["node"]):
			flying_birds.remove_at(i)
			continue
		var bn: Node3D = fb["node"]
		fb["age"] = float(fb["age"]) + delta
		bn.position += (fb["vel"] as Vector3) * delta
		var flap := sin(t * 11.0 + float(fb["phase"])) * 0.55
		(fb["lw"] as Node3D).rotation.z = flap
		(fb["rw"] as Node3D).rotation.z = -flap
		if float(fb["age"]) > 6.5:
			bn.queue_free()
			flying_birds.remove_at(i)

	var p_speed := flat(player.velocity).length()
	if p_speed > 0.4 and not PrologueState.mounted and not air_slam_active:
		_walk_phase += delta * 12.5
		player_visual.position.y = absf(sin(_walk_phase)) * 0.11
		player_visual.rotation.z = sin(_walk_phase) * 0.07
	else:
		player_visual.position.y = sin(t * 2.8) * 0.02
		player_visual.rotation.z = lerpf(player_visual.rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))

	var w_speed := flat(wolf.velocity).length()
	if w_speed > 0.4:
		_wolf_phase += delta * 10.5
		wolf_visual.position.y = absf(sin(_wolf_phase)) * 0.12
		wolf_visual.rotation.x = sin(_wolf_phase) * 0.05
	else:
		wolf_visual.position.y = sin(t * 2.1) * 0.025
		wolf_visual.rotation.x = lerpf(wolf_visual.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	if wolf_tail and is_instance_valid(wolf_tail):
		wolf_tail.rotation.y = sin(t * (7.5 if w_speed > 0.4 else 3.6)) * 0.32

func step_shared_physics(delta: float, cam_override_target := Vector3.INF) -> bool:
	_animate_living_world(delta)
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return false

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	wolf_charge_cooldown = maxf(0.0, wolf_charge_cooldown - delta)
	wolf_charge_timer = maxf(0.0, wolf_charge_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	shake_time = maxf(0.0, shake_time - delta)
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_step = 0
	if hit_combo_timer > 0.0:
		hit_combo_timer -= delta
		if hit_combo_timer <= 0.0:
			hit_combo_count = 0
			if combo_badge_panel:
				combo_badge_panel.hide()

	if emote_timer > 0.0:
		emote_timer -= delta
		if emote_timer <= 0.0:
			player_emote.text = ""
	if subtitle_timer > 0.0:
		subtitle_timer -= delta
		if subtitle_timer <= 0.0:
			subtitle_label.text = ""
			subtitle_panel.hide()

	_update_hotbar_visuals()

	if cinematic_active and cinematic_timer > 0.0:
		cinematic_timer -= delta
		if cinematic_timer <= 0.0:
			exit_cinematic_shot()

	if input_locked or inv_open or is_world_map_open() or PrologueState.is_transitioning:
		bird.position = player.position + Vector3(0.0, 1.48 + sin(Time.get_ticks_msec() * 0.007) * 0.07, 0.0)
		position_camera(cam_override_target if cam_override_target != Vector3.INF else feet(), clampf(delta * 4.5, 0.0, 1.0))
		return true

	var h := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := flat(camera.transform.basis.x).normalized()
	var fwd := flat(camera.transform.basis.z).normalized()
	var dir := (right * h + fwd * v).limit_length()
	var spd_mult := PrologueState.get_speed_multiplier()

	if air_slam_active:
		vertical_vel -= 28.0 * delta
		player.position.y += vertical_vel * delta
		move_body(player, dir, 5.6 * spd_mult)
		if mixamo_rig:
			mixamo_rig.play_state("fall")
		if player.position.y <= 0.0:
			player.position.y = 0.0
			_finish_air_slam()
	elif dodge_timer > 0.0:
		if PrologueState.mounted:
			move_body(wolf, dodge_dir, 14.2 * spd_mult)
			player.position = wolf.position + Vector3.UP * 1.38
			player.rotation.y = wolf.rotation.y
		else:
			move_body(player, dodge_dir, 12.6 * spd_mult)
			update_wolf_follow(delta)
	elif PrologueState.mounted:
		var spd := (12.5 if wolf_charge_timer > 0.0 else 7.8) * spd_mult
		move_body(wolf, dir if dir.length() > 0.05 else (Vector3.RIGHT if wolf_charge_timer > 0.0 else Vector3.ZERO), spd)
		player.position = wolf.position + Vector3.UP * 1.38
		player.rotation.y = wolf.rotation.y
		if mixamo_rig:
			mixamo_rig.play_state("idle")
	else:
		move_body(player, dir, 5.4 * spd_mult)
		update_wolf_follow(delta)
		if mixamo_rig and attack_cooldown <= 0.0:
			mixamo_rig.play_state("run" if dir.length() > 0.08 else "idle")

	var t_bird := Time.get_ticks_msec() * 0.007
	var bird_speed := 10.0
	var bird_target := Vector3.ZERO
	if bird_alert_target != Vector3.INF and flat(feet() - bird_alert_target).length() < 9.5:
		var to_alert := flat(bird_alert_target - feet()).normalized()
		bird_target = feet() + to_alert * 1.45 + Vector3(0, 1.95 + absf(sin(t_bird * 2.2)) * 0.25, 0)
		bird_speed = 7.0
	else:
		var bird_hover := Vector3(sin(t_bird * 0.6) * 0.16, 1.48 + absf(sin(t_bird)) * 0.10, cos(t_bird * 0.6) * 0.12)
		bird_target = (wolf.position + Vector3(0, 1.60 + absf(sin(t_bird)) * 0.06, 0.85)) if PrologueState.mounted else (player.position + bird_hover)
	bird.position = bird.position.lerp(bird_target, clampf(delta * bird_speed, 0.0, 1.0))

	if minimap_overlay:
		minimap_overlay.update_state(feet(), wolf.position, get_minimap_markers())
	var target := cam_override_target if cam_override_target != Vector3.INF else feet()
	position_camera(target, clampf(delta * 4.8, 0.0, 1.0))
	if shake_time > 0.0:
		camera.position += Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength * 0.7, shake_strength * 0.7), 0.0)
	return true

func get_minimap_markers() -> Array[Dictionary]:
	return []

func _update_hotbar_visuals() -> void:
	if not slot_attack:
		return
	var can_use_atk := can_attack and (not PrologueState.mounted or PrologueState.is_slingshot())
	slot_attack.modulate = Color.WHITE if can_use_atk else Color(0.55, 0.55, 0.62, 0.85)
	if slot_attack_sub:
		slot_attack_sub.text = "彈弓" if PrologueState.is_slingshot() else ("旋風!" if combo_step == 2 else "揮劍")
	slot_attack_cd.visible = attack_cooldown > 0.0
	if slot_dodge_cd:
		slot_dodge_cd.visible = dodge_cooldown > 0.0
		if dodge_cooldown > 0.0:
			slot_dodge_cd.scale.y = clampf(dodge_cooldown / dodge_max_cd, 0.0, 1.0)
	if PrologueState.mounted:
		slot_mount_sub.text = "彈飛劈!" if PrologueState.has_spring_saddle else "下鞍"
	else:
		slot_mount_sub.text = "上鞍"
	slot_wolf_cd.visible = wolf_charge_cooldown > 0.0
	if wolf_charge_cooldown > 0.0:
		slot_wolf_cd.scale.y = clampf(wolf_charge_cooldown / wolf_charge_max, 0.0, 1.0)
	if slot_flask and slot_flask_sub:
		slot_flask_sub.text = "水壺 x%d" % PrologueState.flask_charges
		slot_flask.modulate = Color.WHITE if PrologueState.flask_charges > 0 else Color(0.55, 0.55, 0.62, 0.85)

func update_wolf_follow(_delta: float) -> void:
	var diff := flat(player.position - wolf.position)
	move_body(wolf, diff.normalized() if diff.length() > 1.85 else Vector3.ZERO, 6.2)

func _unhandled_input(event: InputEvent) -> void:
	if PrologueState.is_transitioning:
		return
	if on_map_input(event):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_U:
		toggle_world_map()
		return
	if is_world_map_open():
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			world_map_overlay.close_map()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		toggle_inventory()
		return
	if input_locked or inv_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: drink_flask()
			KEY_SPACE: perform_dodge()
			KEY_E: on_interact()
			KEY_F: toggle_mount()
			KEY_Q: on_wolf_action()
			KEY_J: perform_sword_attack()
			KEY_C: on_coop_summon()
			KEY_TAB:
				if minimap_overlay:
					minimap_overlay.toggle_expanded()
			KEY_M:
				var muted := PrologueState.toggle_bgm_mute()
				show_player_emote("🔇" if muted else "🎵", 1.1)
			KEY_R: PrologueState.reset_all()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		perform_sword_attack()

func is_invulnerable() -> bool:
	return invuln_timer > 0.0 or air_slam_active

func perform_dodge() -> void:
	if dodge_cooldown > 0.0 or air_slam_active:
		return
	var h := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := flat(camera.transform.basis.x).normalized()
	var fwd := flat(camera.transform.basis.z).normalized()
	var input_dir := (right * h + fwd * v).limit_length()
	var yaw := wolf.rotation.y if PrologueState.mounted else player.rotation.y
	dodge_dir = input_dir.normalized() if input_dir.length() > 0.08 else Vector3(sin(yaw), 0.0, cos(yaw)).normalized()
	dodge_timer = 0.26
	invuln_timer = 0.30
	dodge_cooldown = dodge_max_cd
	PrologueState.play_sfx("dodge")
	if mixamo_rig:
		mixamo_rig.play_state("dodge", true)
	var dust := marker(feet(), Color("#f2e9d8"), 1.05)
	var dtw := create_tween()
	dtw.tween_property(dust, "scale", Vector3(2.0, 1.0, 2.0), 0.24)
	dtw.tween_callback(dust.queue_free)
	if PrologueState.mounted:
		flash_hit(wolf_visual)
	else:
		var rtw := create_tween()
		rtw.tween_property(player_visual, "rotation:x", TAU, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw.tween_callback(func() -> void:
			player_visual.rotation.x = 0.0
		)

func take_player_damage(amount := 1) -> bool:
	if is_invulnerable():
		PrologueState.play_sfx("dodge")
		spawn_damage_pop(feet(), "閃避!", MIST_CYAN, true)
		show_player_emote("💨", 0.7)
		return false
	PrologueState.player_hp = maxi(1, PrologueState.player_hp - amount)
	shake_time = 0.22
	shake_strength = 0.20
	flash_hit(wolf_visual if PrologueState.mounted else player_visual)
	spawn_damage_pop(feet(), "-%d ♥" % amount, STAMP_RED, true)
	update_status_line()
	return true

func register_combat_hit(pos: Vector3, is_crit := false) -> void:
	hit_combo_count += 1
	hit_combo_timer = 3.2
	if combo_badge_panel and combo_badge_label:
		combo_badge_label.text = "🔥 %d HIT!" % hit_combo_count
		combo_badge_panel.show()
		combo_badge_panel.scale = Vector2(1.18, 1.18)
		create_tween().tween_property(combo_badge_panel, "scale", Vector2.ONE, 0.14)
	if is_crit and PrologueState.active_seal == "paycheck":
		spawn_bouncing_coins(pos, 2, 5)

func get_attack_multiplier() -> float:
	return 1.6 if combo_step == 3 else 1.0

func drink_flask() -> void:
	if PrologueState.flask_charges <= 0:
		show_player_emote("?", 0.9)
		show_subtitle("隨身水壺空了，回到營火即可免費補滿！", 2.6)
		return
	if PrologueState.player_hp >= 5:
		show_player_emote("♥", 0.9)
		show_subtitle("目前滿血中，水壺還剩 %d 口！" % PrologueState.flask_charges, 2.2)
		return
	PrologueState.flask_charges -= 1
	PrologueState.player_hp = mini(5, PrologueState.player_hp + 2)
	PrologueState.play_sfx("heal")
	var ring := marker(feet(), FIRE_ORANGE, 1.8)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.35)
	tw.tween_callback(ring.queue_free)
	spawn_damage_pop(feet(), "+2 ♥", Color("#98ffbd"), true)
	show_player_emote("🍵", 1.2)
	update_status_line()

func on_map_input(_event: InputEvent) -> bool:
	return false

func on_interact() -> void:
	pass

func on_coop_summon() -> void:
	show_player_emote("✉️", 1.2)
	show_subtitle("在「雲海石橋」按 [C] 即可拉隊友空降助拳！", 3.0)

func on_vortex_pull(_origin: Vector3, _radius: float) -> void:
	pass

func on_wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = wolf_charge_max
	wolf_charge_timer = 0.45
	_damage_destructibles(feet(), 3.0)
	if PrologueState.active_seal == "vortex":
		var vring := marker(feet(), MIST_CYAN, 2.6)
		var vtw := create_tween()
		vtw.tween_property(vring, "scale", Vector3(2.4, 1.0, 2.4), 0.32)
		vtw.tween_callback(vring.queue_free)
		spawn_damage_pop(feet(), "引力聚怪!", MIST_CYAN, true)
		on_vortex_pull(feet(), 6.8)
	show_player_emote("!", 0.7)

func on_sword_hit() -> void:
	pass

func on_projectile_hit(_pos: Vector3) -> bool:
	return false

func on_air_slam_land() -> void:
	pass

func perform_sword_attack() -> void:
	if not can_attack or attack_cooldown > 0.0:
		return
	if PrologueState.is_slingshot():
		attack_cooldown = 0.24
		PrologueState.play_sfx("slingshot")
		var origin := feet() + Vector3(0, 1.05 if PrologueState.mounted else 0.75, 0)
		var yaw := wolf.rotation.y if PrologueState.mounted else player.rotation.y
		var angles: Array[float] = [-0.24, 0.0, 0.24]
		if PrologueState.active_seal != "split":
			angles = [0.0]
		for a in angles:
			var forward := Vector3(sin(yaw + a), 0.0, cos(yaw + a)).normalized()
			var shot := sphere(self, origin + forward * 0.65, Vector3(0.28, 0.28, 0.28), MIST_CYAN if PrologueState.active_seal == "split" else GOLD, true)
			projectiles.append({"node": shot, "vel": forward * 21.0, "age": 0.0})
		return
	if PrologueState.mounted:
		return
	combo_step = (combo_step % 3) + 1
	combo_reset_timer = 0.95
	if combo_step == 3:
		attack_cooldown = 0.36
		PrologueState.play_sfx("whirl")
		if mixamo_rig:
			mixamo_rig.play_state("spin", true)
		var wring := marker(player.position, GOLD, 2.4)
		var wtw := create_tween()
		wtw.tween_property(wring, "scale", Vector3(1.65, 1.0, 1.65), 0.24)
		wtw.tween_callback(wring.queue_free)
		spawn_slash_arc(player.position, player.rotation.y, GOLD)
		spawn_slash_arc(player.position, player.rotation.y + PI, FIRE_ORANGE)
		spawn_damage_pop(player.position, "旋風斬!", GOLD, false)
		var spin_tw := create_tween()
		spin_tw.tween_property(player_visual, "rotation:y", TAU, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		spin_tw.tween_callback(func() -> void:
			player_visual.rotation.y = 0.0
		)
		_damage_destructibles(player.position, 3.4)
	else:
		attack_cooldown = 0.26
		PrologueState.play_sfx("slash")
		if mixamo_rig:
			mixamo_rig.play_state("slash", true)
		spawn_slash_arc(player.position, player.rotation.y + (0.35 if combo_step == 2 else 0.0), GOLD if PrologueState.has_sword else Color("#e6f4ff"))
		var lunge_dir := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y)).normalized()
		move_body(player, lunge_dir, 4.2)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(player_sword, "rotation:y", -1.55 if combo_step == 1 else 1.45, 0.09)
		tw.tween_property(player_visual, "rotation:x", 0.22, 0.09)
		tw.chain().tween_property(player_sword, "rotation:y", 0.0, 0.14)
		tw.parallel().tween_property(player_visual, "rotation:x", 0.0, 0.14)
		_damage_destructibles(player.position, 2.6)
	if PrologueState.active_seal == "split":
		var sw_fwd := Vector3(sin(player.rotation.y), 0.0, cos(player.rotation.y)).normalized()
		var wave := box(self, player.position + sw_fwd * 0.9 + Vector3(0, 0.65, 0), Vector3(1.15, 0.12, 0.32), GOLD, false, true)
		wave.rotation.y = player.rotation.y
		projectiles.append({"node": wave, "vel": sw_fwd * 16.5, "age": 0.0})
	on_sword_hit()

func toggle_mount() -> void:
	if air_slam_active:
		return
	if PrologueState.mounted:
		PrologueState.mounted = false
		if PrologueState.has_spring_saddle:
			player.position = wolf.position + Vector3(0, 1.55, 0)
			air_slam_active = true
			vertical_vel = 11.4
			show_player_emote("✨", 1.2)
			return
		var shape := SphereShape3D.new()
		shape.radius = PLAYER_RADIUS
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = 1
		for off in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
			var cand: Vector3 = wolf.position + off * 1.18
			params.transform.origin = cand + Vector3.UP * PLAYER_RADIUS
			if get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
				player.position = cand
				return
		player.position = wolf.position + Vector3(0, 0, 1.15)
	elif near(wolf.position, 2.7):
		PrologueState.mounted = true
		player.position = wolf.position + Vector3.UP * 1.38
		# Cute parabolic hop onto wolf saddle + wolf spring-squish animation
		player_visual.position.y = 0.65
		var hop_tw := create_tween()
		hop_tw.tween_property(player_visual, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flash_hit(wolf_visual)
		show_player_emote("✨", 0.8)

func _finish_air_slam() -> void:
	air_slam_active = false
	shake_time = 0.24
	shake_strength = 0.22
	var ring := marker(player.position, GOLD, 2.8)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(1.8, 1.0, 1.8), 0.28)
	tw.tween_callback(ring.queue_free)
	spawn_damage_pop(player.position, "彈飛重劈! 200%", GOLD, true)
	if PrologueState.active_seal == "vortex":
		on_vortex_pull(player.position, 6.8)
	show_player_emote("✨", 1.2)
	on_air_slam_land()

func update_status_line() -> void:
	var hearts := ""
	for i in range(5):
		hearts += "♥ " if i < PrologueState.player_hp else "♡ "
	hp_hearts_label.text = hearts.strip_edges()

	var tags: Array[String] = ["⚔%d" % PrologueState.get_total_atk(), "💰%d¢" % PrologueState.coins, "🎒%d" % PrologueState.inventory.size()]
	if not PrologueState.campfire_dish.is_empty():
		tags.append("🍲+1")
	if PrologueState.has_spring_saddle:
		tags.append("🌀彈簧")
	if not PrologueState.active_seal.is_empty():
		tags.append("💠%s" % PrologueState.get_seal_title(PrologueState.active_seal))
	gear_tags_label.text = "  ".join(tags)

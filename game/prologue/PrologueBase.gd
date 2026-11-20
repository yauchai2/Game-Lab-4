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
var _walk_phase := 0.0
var _wolf_phase := 0.0

# Minimalist Storybook HUD nodes
var hud_layer: CanvasLayer
var hud_root: Control
var zone_badge_label: Label
var objective_label: Label
var hp_hearts_label: Label
var gear_tags_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label

# Boss HP Bar (Top-Center)
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_hp_bar: ProgressBar
var boss_state_badge: Label

# Compact Bottom Hotbar Pills
var slot_attack: PanelContainer
var slot_attack_cd: ColorRect
var slot_mount: PanelContainer
var slot_mount_sub: Label
var slot_wolf: PanelContainer
var slot_wolf_cd: ColorRect
var slot_bag: PanelContainer
var slot_coop: PanelContainer
var slot_reset: PanelContainer

# PoE 2 Inventory & Currency Crafting Modal (press I)
var inv_panel: PanelContainer
var inv_stats_label: Label
var inv_equipped_label: Label
var inv_currency_label: Label
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

func mesh_at(parent: Node3D, pos: Vector3, mesh: Mesh, color: Color, unshaded := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.mesh = mesh
	instance.material_override = material
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
	sphere(crown, Vector3(0.0, 0.0, 0.0), Vector3(2.35, 1.85, 2.15), foliage_col)
	sphere(crown, Vector3(0.85, -0.25, 0.45), Vector3(1.55, 1.35, 1.50), foliage_col.lightened(0.08))
	sphere(crown, Vector3(-0.78, -0.18, -0.42), Vector3(1.48, 1.28, 1.42), foliage_col.darkened(0.08))
	sphere(crown, Vector3(0.15, 0.68, -0.15), Vector3(1.32, 1.05, 1.25), foliage_col.lightened(0.12))
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
	cylinder(foliage, Vector3(0.06, 0.65, 0), 0.25, 1.55, 2.0, tint)
	cylinder(foliage, Vector3(-0.08, 1.95, 0.05), 0.16, 1.18, 1.8, tint.lightened(0.07))
	sphere(foliage, Vector3(0.0, 2.85, 0.0), Vector3(0.85, 0.95, 0.85), tint.lightened(0.13))
	sway_items.append({"node": foliage, "base_rot": foliage.rotation, "amp": 0.022, "speed": 1.4, "phase": pos.x * 0.6 + pos.z * 0.4})
	if solid:
		var body := StaticBody3D.new()
		root.add_child(body)
		var sh := CylinderShape3D.new()
		sh.radius = 0.65 * scale_val
		sh.height = 2.4 * scale_val
		add_shape(body, sh, Vector3(0, 1.2 * scale_val, 0))
	return root

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
	for i in range(pieces):
		var p := box(self, origin + Vector3(randf_range(-0.6, 0.6), 0.8, randf_range(-1.8, 1.8)), Vector3(0.42, 0.22, 0.22), col)
		var dest := p.position + Vector3(randf_range(1.6, 4.2), randf_range(0.8, 2.2), randf_range(-2.2, 2.2))
		var tw := create_tween().set_parallel(true)
		tw.tween_property(p, "position", dest, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "rotation_degrees", Vector3(randf_range(-240, 240), randf_range(-240, 240), randf_range(-240, 240)), 0.42)
		tw.tween_property(p, "scale", Vector3(0.05, 0.05, 0.05), 0.42)
		tw.chain().tween_callback(p.queue_free)

func play_giant_retirement_stamp(target_pos: Vector3) -> void:
	# The signature 3-Second Visual Hook: Giant 3D Red Stamp slams from the sky!
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
	cylinder(player_visual, Vector3(0, 0.34, 0), 0.24, 0.28, 0.52, Color("#4da1e8"))
	sphere(player_visual, Vector3(0, 0.60, 0.02), Vector3(0.42, 0.18, 0.38), Color("#d96b43"))
	sphere(player_visual, Vector3(0, 0.85, 0.02), Vector3(0.52, 0.50, 0.48), Color("#f4c9a8"))
	cylinder(player_visual, Vector3(0, 1.13, 0), 0.08, 0.33, 0.32, Color("#498e62"))
	var feather := box(player_visual, Vector3(-0.22, 1.25, -0.05), Vector3(0.08, 0.32, 0.14), Color("#d7e4ff"))
	feather.rotation_degrees.z = 16.0
	sphere(player_visual, Vector3(0, 0.44, -0.26), Vector3(0.38, 0.38, 0.24), Color("#8c5234"))
	player_sword = box(player_visual, Vector3(0.38, 0.48, 0.28), Vector3(0.11, 0.11, 0.88), Color("#e6f4ff"))
	# Always give the traveler a starter stick/sword feel so combat works from second 1!
	player_sword.visible = true
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

# --- 2.5D Orthographic Oblique Top-Down Camera ---
func setup_camera_and_lighting(cam_size: float, bg_col: Color, amb_col: Color, amb_energy: float, sun_col: Color, sun_energy: float) -> void:
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.current = true
	position_camera(feet(), 1.0)

	env.background_mode = Environment.BG_COLOR
	env.background_color = bg_col
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb_col
	env.ambient_light_energy = amb_energy
	camera.environment = env

	add_child(sun)
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.shadow_enabled = true

func position_camera(target: Vector3, lerp_weight: float) -> void:
	var offset := Vector3(3.2, 14.2, 16.5)
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

	# 2. Top-Right: Ultra-clean 2-line Zone + Crisp Objective Pill
	var obj_card := PanelContainer.new()
	obj_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	obj_card.offset_left = -310
	obj_card.offset_right = -18
	obj_card.offset_top = 16
	obj_card.offset_bottom = 78
	obj_card.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, UI_ACCENT_GOLD, 16, 2, 14, 7))
	obj_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(obj_card)

	var o_box := VBoxContainer.new()
	o_box.add_theme_constant_override("separation", 2)
	obj_card.add_child(o_box)
	zone_badge_label = _styled_label("", 12, UI_ACCENT_GOLD, false)
	o_box.add_child(zone_badge_label)
	objective_label = _styled_label("", 15, Color("#fff9eb"), false)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o_box.add_child(objective_label)

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
	bottom_stack.offset_left = -360
	bottom_stack.offset_right = 360
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
	hotbar.add_theme_constant_override("separation", 8)
	bottom_stack.add_child(hotbar)

	var atk_pair := _make_hotbar_slot(hotbar, "J / 左鍵", "揮劍", Color("#4da1e8"))
	slot_attack = atk_pair[0]
	slot_attack_cd = atk_pair[1]
	var mnt_pair := _make_hotbar_slot(hotbar, "F", "上鞍", Color("#498e62"))
	slot_mount = mnt_pair[0]
	slot_mount_sub = mnt_pair[2]
	var wlf_pair := _make_hotbar_slot(hotbar, "Q", "巨狼撞", Color("#d97836"))
	slot_wolf = wlf_pair[0]
	slot_wolf_cd = wlf_pair[1]
	var bag_pair := _make_hotbar_slot(hotbar, "I", "造裝", Color("#c99438"))
	slot_bag = bag_pair[0]
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
	inv_panel.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_WOOD_BORDER, 20, 3, 20, 14))
	inv_panel.hide()
	hud_layer.add_child(inv_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	inv_panel.add_child(root_v)

	var header := HBoxContainer.new()
	root_v.add_child(header)
	var h_title := _styled_label("🎒 旅人背包 × 造裝工坊", 19, UI_INK, false)
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
				cn.queue_free()
				bouncing_coins.remove_at(i)

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
	shake_time = maxf(0.0, shake_time - delta)

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

	if input_locked or inv_open or PrologueState.is_transitioning:
		bird.position = player.position + Vector3(0.0, 1.48 + sin(Time.get_ticks_msec() * 0.007) * 0.07, 0.0)
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
		if player.position.y <= 0.0:
			player.position.y = 0.0
			_finish_air_slam()
	elif PrologueState.mounted:
		var spd := (12.5 if wolf_charge_timer > 0.0 else 7.8) * spd_mult
		move_body(wolf, dir if dir.length() > 0.05 else (Vector3.RIGHT if wolf_charge_timer > 0.0 else Vector3.ZERO), spd)
		player.position = wolf.position + Vector3.UP * 1.38
		player.rotation.y = wolf.rotation.y
	else:
		move_body(player, dir, 5.4 * spd_mult)
		update_wolf_follow(delta)

	var t_bird := Time.get_ticks_msec() * 0.007
	var bird_hover := Vector3(sin(t_bird * 0.6) * 0.16, 1.48 + absf(sin(t_bird)) * 0.10, cos(t_bird * 0.6) * 0.12)
	var bird_target := (wolf.position + Vector3(0, 1.60 + absf(sin(t_bird)) * 0.06, 0.85)) if PrologueState.mounted else (player.position + bird_hover)
	bird.position = bird.position.lerp(bird_target, clampf(delta * 10.0, 0.0, 1.0))

	var target := cam_override_target if cam_override_target != Vector3.INF else feet()
	position_camera(target, clampf(delta * 4.8, 0.0, 1.0))
	if shake_time > 0.0:
		camera.position += Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength * 0.7, shake_strength * 0.7), 0.0)
	return true

func _update_hotbar_visuals() -> void:
	if not slot_attack:
		return
	slot_attack.modulate = Color.WHITE if (can_attack and not PrologueState.mounted) else Color(0.55, 0.55, 0.62, 0.85)
	slot_attack_cd.visible = attack_cooldown > 0.0
	if PrologueState.mounted:
		slot_mount_sub.text = "彈飛劈!" if PrologueState.has_spring_saddle else "下鞍"
	else:
		slot_mount_sub.text = "上鞍"
	slot_wolf_cd.visible = wolf_charge_cooldown > 0.0
	if wolf_charge_cooldown > 0.0:
		slot_wolf_cd.scale.y = clampf(wolf_charge_cooldown / wolf_charge_max, 0.0, 1.0)

func update_wolf_follow(_delta: float) -> void:
	var diff := flat(player.position - wolf.position)
	move_body(wolf, diff.normalized() if diff.length() > 1.85 else Vector3.ZERO, 6.2)

func _unhandled_input(event: InputEvent) -> void:
	if PrologueState.is_transitioning:
		return
	if on_map_input(event):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		toggle_inventory()
		return
	if input_locked or inv_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: on_interact()
			KEY_F: toggle_mount()
			KEY_Q: on_wolf_action()
			KEY_J: perform_sword_attack()
			KEY_C: on_coop_summon()
			KEY_R: PrologueState.reset_all()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		perform_sword_attack()

func on_map_input(_event: InputEvent) -> bool:
	return false

func on_interact() -> void:
	pass

func on_coop_summon() -> void:
	show_player_emote("✉️", 1.2)
	show_subtitle("在「雲海石橋」按 [C] 即可拉隊友空降助拳！", 3.0)

func on_wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = wolf_charge_max
	wolf_charge_timer = 0.45
	show_player_emote("!", 0.7)

func on_sword_hit() -> void:
	pass

func on_air_slam_land() -> void:
	pass

func perform_sword_attack() -> void:
	if not can_attack or PrologueState.mounted or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.28
	spawn_slash_arc(player.position, player.rotation.y, GOLD if PrologueState.has_sword else Color("#e6f4ff"))
	var tw := create_tween()
	tw.tween_property(player_sword, "rotation:y", -1.55, 0.09)
	tw.tween_property(player_sword, "rotation:y", 0.0, 0.14)
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
	gear_tags_label.text = "  ".join(tags)

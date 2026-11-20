extends Node3D

# Shared Amelicart-inspired matte gouache palette
const NIGHT_GRASS := Color("#2f4659")
const DAY_GRASS := Color("#d89448")
const MEADOW_GREEN := Color("#8db858")
const TRAIL := Color("#e5be8a")
const BOARDWALK := Color("#c97e49")
const STONE := Color("#8a8796")
const STONE_LIGHT := Color("#b7b3c4")
const TIMBER := Color("#78523d")
const TIMBER_LIGHT := Color("#a87854")
const WHITE_WALL := Color("#f7f3ea")
const CORAL_ROOF := Color("#d9786c")
const BLUE_CURTAIN := Color("#1e6fa8")
const BUNTING_BLUE := Color("#5d96d8")
const PINE_DARK := Color("#1e3148")
const PINE_ORANGE := Color("#d9532f")
const PINE_TEAL := Color("#2e6b6b")
const MIST_CYAN := Color("#5ae8e5")
const FIRE_ORANGE := Color("#ff9838")
const GOLD := Color("#f5c65b")
const GOBLIN_GREEN := Color("#6ec25a")
const PINK_PEAK := Color("#d896c8")
const PURPLE_PEAK := Color("#9688d4")
const CLOUD_WHITE := Color("#f7eaf2")
const STAMP_RED := Color("#e03c3c")

const PLAYER_RADIUS := 0.30
const WOLF_RADIUS := 0.82

# 60 FPS integer frame counter hitstop (never mutates Engine.time_scale)
var hitstop_frames := 0
var attack_cooldown := 0.0
var wolf_charge_cooldown := 0.0
var wolf_charge_timer := 0.0
var shake_time := 0.0
var air_slam_active := false
var vertical_vel := 0.0
var emote_timer := 0.0
var subtitle_timer := 0.0
var input_locked := false
var can_attack := true

var player := CharacterBody3D.new()
var wolf := CharacterBody3D.new()
var bird := Node3D.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()

var player_sword: MeshInstance3D
var wolf_spring_pad: MeshInstance3D
var player_emote: Label3D
var wolf_emote: Label3D

var hud_layer: CanvasLayer
var objective_label: Label
var status_label: Label
var subtitle_label: Label
var prompt_label: Label
var controls_label: Label

# --- Procedural matte gouache geometry helpers ---
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
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := mesh_at(parent, pos, mesh, color, unshaded)
	instance.scale = size
	return instance

func cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, h: float, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 10
	return mesh_at(parent, pos, mesh, color, unshaded)

func label_at(parent: Node3D, pos: Vector3, words: String, color := Color.WHITE, font_size := 36) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 10
	label.pixel_size = 0.0085
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
	return mesh_at(self, pos + Vector3.UP * 0.03, mesh, color, true)

func pine_tree(pos: Vector3, scale_val := 1.0, tint := PINE_DARK) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_val
	add_child(root)
	cylinder(root, Vector3(0, 1.1, 0), 0.24, 0.34, 2.2, TIMBER)
	cylinder(root, Vector3(0, 2.5, 0), 0.12, 1.45, 2.2, tint)
	cylinder(root, Vector3(0, 3.9, 0), 0.06, 1.10, 1.9, tint.lightened(0.08))

func transition_signpost(pos: Vector3, title: String, color := GOLD) -> void:
	cylinder(self, pos + Vector3(0, 0.85, 0), 0.09, 0.11, 1.7, TIMBER)
	box(self, pos + Vector3(0.25, 1.45, 0), Vector3(1.1, 0.36, 0.12), TIMBER_LIGHT)
	marker(pos + Vector3(0, 0, 0.8), color, 0.85)
	label_at(self, pos + Vector3(0, 2.35, 0), title, color, 34)

# --- Core Trio Builders ---
func setup_core_trio(spawn_pos: Vector3) -> void:
	# 1. Silent Small Traveler
	_make_body(player, spawn_pos, PLAYER_RADIUS)
	box(player, Vector3(0, 0.36, 0), Vector3(0.46, 0.56, 0.34), Color("#4da1e8"))
	sphere(player, Vector3(0, 0.84, 0.02), Vector3(0.50, 0.50, 0.48), Color("#f4c9a8"))
	cylinder(player, Vector3(0, 1.12, 0), 0.08, 0.32, 0.32, Color("#498e62"))
	box(player, Vector3(-0.22, 1.24, -0.05), Vector3(0.08, 0.30, 0.14), Color("#d7e4ff"))
	box(player, Vector3(0, 0.44, -0.25), Vector3(0.36, 0.36, 0.18), Color("#8c5234"))
	player_sword = box(player, Vector3(0.38, 0.48, 0.25), Vector3(0.11, 0.11, 0.85), Color("#e6f4ff"))
	player_sword.visible = PrologueState.has_sword
	player_emote = label_at(player, Vector3(0, 1.75, 0), "", Color("#fff59d"), 46)

	# 2. Calm Retired Scout Giant Wolf
	_make_body(wolf, spawn_pos + Vector3(-1.45, 0, -0.55), WOLF_RADIUS)
	var fur := Color("#464b59")
	var fur_light := Color("#747d91")
	box(wolf, Vector3(0, 0.78, 0), Vector3(1.12, 0.86, 1.82), fur)
	box(wolf, Vector3(0, 1.05, 0.88), Vector3(0.72, 0.65, 0.72), fur)
	box(wolf, Vector3(0, 0.85, 1.32), Vector3(0.42, 0.32, 0.48), fur_light)
	for sx in [-0.36, 0.36]:
		for sz in [-0.62, 0.62]:
			box(wolf, Vector3(sx, 0.30, sz), Vector3(0.24, 0.60, 0.26), fur)
		cylinder(wolf, Vector3(sx * 0.62, 1.54, 0.92), 0.03, 0.16, 0.42, fur)
	var tail := box(wolf, Vector3(0, 0.95, -1.18), Vector3(0.28, 0.28, 0.78), fur)
	tail.rotation_degrees.x = 24.0
	box(wolf, Vector3(0, 1.24, -0.10), Vector3(0.92, 0.16, 0.72), Color("#a87b54"))
	wolf_spring_pad = cylinder(wolf, Vector3(0, 1.42, -0.10), 0.38, 0.38, 0.22, GOLD)
	wolf_spring_pad.visible = PrologueState.has_spring_saddle
	wolf_emote = label_at(wolf, Vector3(0, 2.25, 0.5), "", Color("#d0ecff"), 40)

	if PrologueState.mounted:
		wolf.position = spawn_pos
		player.position = wolf.position + Vector3.UP * 1.38

	# 3. Chubby Yellow Messenger Bird
	add_child(bird)
	sphere(bird, Vector3.ZERO, Vector3(0.32, 0.28, 0.34), Color("#ffbf3c"))
	box(bird, Vector3(0, 0.0, 0.19), Vector3(0.10, 0.08, 0.12), Color("#e8632c"))
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

# --- 2.5D Orthographic Oblique Top-Down Camera & HUD ---
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

func setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	hud_layer.add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	objective_label = _ui_line(col, 22, Color("#fff7dc"))
	status_label = _ui_line(col, 17, Color("#cfe8ff"))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	subtitle_label = _ui_line(col, 21, Color("#ffe394"))
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label = _ui_line(col, 20, Color("#98ffbd"))
	controls_label = _ui_line(col, 15, Color("#e4eaf2"))
	controls_label.text = "WASD / 方向鍵 移動　 E 互動／傳送　 F 上下騎　 Q 巨狼衝撞／破防　 左鍵 / J 揮劍　 R 重置整段序章"

func _ui_line(parent: VBoxContainer, size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#181b26"))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l

func feet() -> Vector3:
	return wolf.position if PrologueState.mounted else player.position

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func near(pos: Vector3, dist := 2.2) -> bool:
	return flat(feet() - pos).length() < dist

func show_player_emote(icon: String, duration := 1.5) -> void:
	player_emote.text = icon
	emote_timer = duration
	player_emote.scale = Vector3.ONE * 0.4
	create_tween().tween_property(player_emote, "scale", Vector3.ONE, 0.18)

func show_subtitle(words: String, duration := 3.5) -> void:
	subtitle_label.text = words
	subtitle_timer = duration

func move_body(body: CharacterBody3D, dir: Vector3, speed: float) -> void:
	body.velocity = dir * speed
	if dir.length_squared() > 0.002:
		body.rotation.y = atan2(dir.x, dir.z)
	body.move_and_slide()

func step_shared_physics(delta: float, cam_override_target := Vector3.INF) -> bool:
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

	if input_locked or PrologueState.is_transitioning:
		bird.position = player.position + Vector3(0.0, 1.45 + sin(Time.get_ticks_msec() * 0.006) * 0.05, 0.0)
		return true

	var h := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := flat(camera.transform.basis.x).normalized()
	var fwd := flat(camera.transform.basis.z).normalized()
	var dir := (right * h + fwd * v).limit_length()
	var buff_mult := 1.15 if PrologueState.slime_buff_active else 1.0

	if air_slam_active:
		vertical_vel -= 28.0 * delta
		player.position.y += vertical_vel * delta
		move_body(player, dir, 5.4 * buff_mult)
		if player.position.y <= 0.0:
			player.position.y = 0.0
			_finish_air_slam()
	elif PrologueState.mounted:
		var spd := (12.0 if wolf_charge_timer > 0.0 else 7.6) * buff_mult
		move_body(wolf, dir if dir.length() > 0.05 else (Vector3.RIGHT if wolf_charge_timer > 0.0 else Vector3.ZERO), spd)
		player.position = wolf.position + Vector3.UP * 1.38
		player.rotation.y = wolf.rotation.y
	else:
		move_body(player, dir, 5.2 * buff_mult)
		update_wolf_follow(delta)

	var bird_target := (wolf.position + Vector3(0, 1.56, 0.85)) if PrologueState.mounted else (player.position + Vector3(0, 1.45, 0))
	bird.position = bird.position.lerp(bird_target, clampf(delta * 10.0, 0.0, 1.0))

	var target := cam_override_target if cam_override_target != Vector3.INF else feet()
	position_camera(target, clampf(delta * 4.8, 0.0, 1.0))
	if shake_time > 0.0:
		camera.position += Vector3(randf_range(-0.18, 0.18), randf_range(-0.12, 0.12), 0.0)
	return true

func update_wolf_follow(_delta: float) -> void:
	var diff := flat(player.position - wolf.position)
	move_body(wolf, diff.normalized() if diff.length() > 1.85 else Vector3.ZERO, 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if PrologueState.is_transitioning:
		return
	if on_map_input(event):
		return
	if input_locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: on_interact()
			KEY_F: toggle_mount()
			KEY_Q: on_wolf_action()
			KEY_J: perform_sword_attack()
			KEY_R: PrologueState.reset_all()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		perform_sword_attack()

func on_map_input(_event: InputEvent) -> bool:
	return false

func on_interact() -> void:
	pass

func on_wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = 1.4
	wolf_charge_timer = 0.45
	show_player_emote("!", 0.7)

func on_sword_hit() -> void:
	pass

func perform_sword_attack() -> void:
	if not can_attack or not PrologueState.has_sword or PrologueState.mounted or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.30
	var tw := create_tween()
	tw.tween_property(player_sword, "rotation:y", -1.45, 0.10)
	tw.tween_property(player_sword, "rotation:y", 0.0, 0.16)
	on_sword_hit()

func toggle_mount() -> void:
	if air_slam_active:
		return
	if PrologueState.mounted:
		PrologueState.mounted = false
		if PrologueState.has_spring_saddle:
			player.position = wolf.position + Vector3(0, 1.55, 0)
			air_slam_active = true
			vertical_vel = 11.2
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
	shake_time = 0.22
	var ring := marker(player.position, GOLD, 2.5)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.25)
	tw.tween_callback(ring.queue_free)
	show_player_emote("✨", 1.3)
	show_subtitle("彈簧試驗鞍座・飛天暴擊下劈！(200% CRIT)", 2.2)

func update_status_line() -> void:
	var st := "旅人 HP %d/5" % PrologueState.player_hp
	if PrologueState.has_sword:
		st += "　｜　武器：五折庫存短劍"
	if PrologueState.has_spring_saddle:
		st += "　｜　鞍座：彈簧試驗鞍座"
	if PrologueState.slime_buff_active:
		st += "　｜　Buff：鞋底閃亮 (+15% 移速)"
	if PrologueState.mounted:
		st += "　｜　騎乘巨狼中"
	status_label.text = st

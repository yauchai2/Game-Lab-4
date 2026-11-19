extends "res://prologue/PrologueBlockout.gd"

enum Beat { TITLE, WAKE_TO_SHOP, SHOP_DONE, TIMBER_SMASHED, GATE_OPENED, BOSS_FIGHT, BOSS_KNEELED, BOSS_RETIRED, VISTA_DONE }
enum BossState { IDLE, SWING, WINDUP, STAGGERED, KNEELED, RETIRED }

const PLAYER_RADIUS := 0.30
const WOLF_RADIUS := 0.82
const MAX_BOSS_HP := 6
const HITSTOP_FRAMES_BREAK := 6

var beat := Beat.TITLE
var boss_state := BossState.IDLE
var boss_hp := MAX_BOSS_HP
var player_hp := 5

var mounted := false
var has_sword := false
var has_spring_saddle := false
var timber_broken := false
var gate_opened := false
var vista_zoomed := false

# 60 FPS integer frame counter for hitstop (never touches Engine.time_scale)
var hitstop_frames := 0
var attack_cooldown := 0.0
var wolf_charge_cooldown := 0.0
var wolf_charge_timer := 0.0
var boss_timer := 1.0
var shake_time := 0.0
var air_slam_active := false
var vertical_vel := 0.0
var emote_timer := 0.0
var subtitle_timer := 0.0
var goblin_talk_timer := 0.0
var boss_talk_timer := 0.0

var player := CharacterBody3D.new()
var wolf := CharacterBody3D.new()
var bird := Node3D.new()
var boss := Node3D.new()
var chest := Node3D.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()

var player_sword: MeshInstance3D
var wolf_spring_pad: MeshInstance3D
var boss_helmet: MeshInstance3D
var boss_straw_hat: MeshInstance3D
var boss_hammer: MeshInstance3D
var boss_stamp: Label3D
var boss_bubble: Label3D
var boss_cue: Label3D
var player_emote: Label3D
var wolf_emote: Label3D
var attack_ring: MeshInstance3D

# HUD
var title_overlay: ColorRect
var title_label: Label
var subtitle_label: Label
var objective_label: Label
var status_label: Label
var prompt_label: Label
var controls_label: Label

func _ready() -> void:
	build_world()
	_build_actors()
	_build_camera_and_lighting()
	_build_hud()
	_update_ui()

func _build_actors() -> void:
	# 1. Silent Small Traveler (Green feathered cap, blue tunic, backpack)
	_make_body(player, CAMPFIRE_POS + Vector3(0.45, 0, -0.35), PLAYER_RADIUS)
	box(player, Vector3(0, 0.36, 0), Vector3(0.46, 0.56, 0.34), Color("#4da1e8"))
	sphere(player, Vector3(0, 0.84, 0.02), Vector3(0.50, 0.50, 0.48), Color("#f4c9a8"))
	# Green feathered cap
	cylinder(player, Vector3(0, 1.12, 0), 0.08, 0.32, 0.32, Color("#498e62"))
	box(player, Vector3(-0.22, 1.24, -0.05), Vector3(0.08, 0.30, 0.14), Color("#d7e4ff"))
	# Leather satchel
	box(player, Vector3(0, 0.44, -0.25), Vector3(0.36, 0.36, 0.18), Color("#8c5234"))
	# Short sword (hidden until bought for -50¢!)
	player_sword = box(player, Vector3(0.38, 0.48, 0.25), Vector3(0.11, 0.11, 0.85), Color("#e6f4ff"), false)
	player_sword.hide()
	player_emote = label_at(player, Vector3(0, 1.72, 0), "", Color("#fff59d"), 46)

	# 2. Calm Retired Scout Giant Wolf
	_make_body(wolf, CAMPFIRE_POS + Vector3(-0.95, 0, -0.55), WOLF_RADIUS)
	var fur := Color("#464b59")
	var fur_light := Color("#747d91")
	box(wolf, Vector3(0, 0.78, 0), Vector3(1.12, 0.86, 1.82), fur)
	box(wolf, Vector3(0, 1.05, 0.88), Vector3(0.72, 0.65, 0.72), fur)
	box(wolf, Vector3(0, 0.85, 1.32), Vector3(0.42, 0.32, 0.48), fur_light)
	for sx in [-0.36, 0.36]:
		for sz in [-0.62, 0.62]:
			box(wolf, Vector3(sx, 0.30, sz), Vector3(0.24, 0.60, 0.26), fur)
		cylinder(wolf, Vector3(sx * 0.62, 1.54, 0.92), 0.03, 0.16, 0.42, fur)
	# Tail
	var tail := box(wolf, Vector3(0, 0.95, -1.18), Vector3(0.28, 0.28, 0.78), fur)
	tail.rotation_degrees.x = 24.0
	# Base leather saddle + unlockable Spring Test Saddle pad
	box(wolf, Vector3(0, 1.24, -0.10), Vector3(0.92, 0.16, 0.72), Color("#a87b54"))
	wolf_spring_pad = cylinder(wolf, Vector3(0, 1.42, -0.10), 0.38, 0.38, 0.22, GOLD)
	wolf_spring_pad.hide()
	wolf_emote = label_at(wolf, Vector3(0, 2.25, 0.5), "", Color("#d0ecff"), 40)

	# 3. Chubby Yellow Messenger Bird
	add_child(bird)
	sphere(bird, Vector3.ZERO, Vector3(0.32, 0.28, 0.34), Color("#ffbf3c"))
	box(bird, Vector3(0, 0.0, 0.19), Vector3(0.10, 0.08, 0.12), Color("#e8632c"))
	bird.position = player.position + Vector3(0, 1.42, 0)

	# 4. Scarecrow Captain Boss (Zone D Stone Bridge)
	add_child(boss)
	boss.position = BOSS_HOME
	cylinder(boss, Vector3(0, 1.15, 0), 0.12, 0.14, 2.3, TIMBER)
	box(boss, Vector3(0, 1.35, 0), Vector3(1.9, 0.32, 0.32), TIMBER_LIGHT)
	box(boss, Vector3(0, 1.1, 0), Vector3(1.1, 1.2, 0.8), Color("#b58d52"))
	sphere(boss, Vector3(0, 2.0, 0), Vector3(0.75, 0.78, 0.75), Color("#e8c882"))
	boss_helmet = cylinder(boss, Vector3(0, 2.42, 0), 0.42, 0.48, 0.45, Color("#606a7a"))
	boss_straw_hat = cylinder(boss, Vector3(0, 2.42, 0), 0.28, 0.82, 0.26, GOLD)
	boss_straw_hat.hide()
	boss_hammer = box(boss, Vector3(-1.05, 1.35, 0.55), Vector3(0.45, 0.45, 1.45), TIMBER)
	boss_bubble = label_at(boss, Vector3(0, 3.35, 0), "", Color("#fff2cc"), 34)
	boss_cue = label_at(boss, Vector3(0, 2.88, 0), "稻草人哨長", Color("#ffd59e"), 30)
	boss_stamp = label_at(boss, Vector3(0, 2.05, 0.55), "【正式退休】", STAMP_RED, 48)
	boss_stamp.hide()

	attack_ring = marker(BOSS_HOME, STAMP_RED, 2.6)
	attack_ring.hide()

	# 5. Treasure Chest for Spring Test Saddle (spawns on retirement)
	add_child(chest)
	chest.position = BOSS_HOME + Vector3(-1.8, 0.0, 1.4)
	box(chest, Vector3(0, 0.35, 0), Vector3(0.95, 0.65, 0.65), GOLD)
	box(chest, Vector3(0, 0.68, 0), Vector3(1.0, 0.18, 0.7), TIMBER)
	label_at(chest, Vector3(0, 1.28, 0), "軍需寶箱（按 E 開啟）", GOLD, 30)
	chest.hide()

func _make_body(body: CharacterBody3D, pos: Vector3, radius: float) -> void:
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 1
	add_child(body)
	var shape := SphereShape3D.new()
	shape.radius = radius
	add_shape(body, shape, Vector3.UP * radius)
	body.position = pos

func _build_camera_and_lighting() -> void:
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	camera.current = true
	_position_camera(CAMPFIRE_POS, 1.0)

	# Starts in deep midnight-blue night for the Title Screen!
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#131c33")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#395588")
	env.ambient_light_energy = 0.55
	camera.environment = env

	add_child(sun)
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("#5f82c2")
	sun.light_energy = 0.35
	sun.shadow_enabled = true

func _position_camera(target: Vector3, lerp_weight: float) -> void:
	var desired := target + Vector3(3.0, 13.5, 16.5)
	camera.position = camera.position.lerp(desired, lerp_weight) if lerp_weight < 1.0 else desired
	camera.look_at(camera.position - Vector3(3.0, 13.5, 16.5))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Minimal Title Screen Overlay (live 3D campfire visible behind)
	title_overlay = ColorRect.new()
	title_overlay.color = Color(0.05, 0.08, 0.16, 0.25)
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(title_overlay)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.position = Vector2(-280, -180)
	center.custom_minimum_size = Vector2(560, 220)
	title_overlay.add_child(center)

	title_label = Label.new()
	title_label.text = "《補簽遠行》\n頭五分鐘灰盒原型"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_outline_color", Color("#101726"))
	title_label.add_theme_constant_override("outline_size", 10)
	center.add_child(title_label)

	var start_hint := Label.new()
	start_hint.text = "\n[ 按 空白鍵 / Enter / 點擊畫面 開始旅程 ]"
	start_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_hint.add_theme_font_size_override("font_size", 22)
	start_hint.add_theme_color_override("font_color", Color("#ffd88a"))
	start_hint.add_theme_color_override("font_outline_color", Color("#101726"))
	start_hint.add_theme_constant_override("outline_size", 8)
	center.add_child(start_hint)

	# Gameplay HUD
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	layer.add_child(margin)

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
	controls_label.text = "WASD / 方向鍵 移動　 E 互動　 F 上下騎（裝彈簧鞍可彈飛）　 Q 巨狼衝撞／破防　 左鍵 / J 揮劍　 R 重來"

func _ui_line(parent: VBoxContainer, size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#181b26"))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l

func _start_prologue() -> void:
	if beat != Beat.TITLE:
		return
	beat = Beat.WAKE_TO_SHOP
	# Seamless 2.0s night-to-morning lighting transition (no loading screen!)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(title_overlay, "modulate:a", 0.0, 0.7)
	tw.tween_property(env, "background_color", Color("#f2c1df"), 2.0)
	tw.tween_property(env, "ambient_light_color", Color("#ffe0bd"), 2.0)
	tw.tween_property(env, "ambient_light_energy", 0.85, 2.0)
	tw.tween_property(sun, "light_color", Color("#ffdfb0"), 2.0)
	tw.tween_property(sun, "light_energy", 1.15, 2.0)
	tw.tween_property(campfire_light, "light_energy", 0.0, 1.8)
	tw.tween_property(campfire_flame, "scale", Vector3(0.05, 0.05, 0.05), 1.2)
	tw.tween_property(camera, "size", 14.5, 1.8)
	for m in mist_pillars:
		tw.tween_property(m, "scale:y", 0.01, 1.8)
	get_tree().create_timer(0.75).timeout.connect(title_overlay.hide)

	# Fake epic intro -> immediately broken by Goblin shopkeeper!
	_show_subtitle("「一百年前，魔王軍與王國聯軍爆發世紀大戰，大陸陷入無盡戰火……」", 2.6)
	_show_player_emote("!", 1.4)
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if beat == Beat.WAKE_TO_SHOP:
			_show_goblin_bubble("早安早安！百年戰爭早打完了，魔王軍滯銷武器全場五折！", 5.5)
			_show_subtitle("（前方傳來清脆敲鑼聲，史詩配樂突然卡帶……）", 2.5)
	)

func _feet() -> Vector3:
	return wolf.position if mounted else player.position

func _near(pos: Vector3, dist := 2.0) -> bool:
	return _flat(_feet() - pos).length() < dist

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _physics_process(delta: float) -> void:
	# 60 FPS integer frame hitstop (no Engine.time_scale mutation)
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return

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
	if goblin_talk_timer > 0.0:
		goblin_talk_timer -= delta
		if goblin_talk_timer <= 0.0:
			goblin_bubble.text = ""
	if boss_talk_timer > 0.0:
		boss_talk_timer -= delta
		if boss_talk_timer <= 0.0:
			boss_bubble.text = ""

	# Animate distant MMORPG riders
	for i in range(distant_riders.size()):
		var r := distant_riders[i]
		r.position.x = 34.0 + fmod(Time.get_ticks_msec() * 0.0018 * (1.0 + i * 0.25) + i * 5.0, 14.0)

	if beat == Beat.TITLE:
		campfire_flame.scale.y = 0.9 + sin(Time.get_ticks_msec() * 0.012) * 0.14
		bird.position = player.position + Vector3(0.0, 1.42 + sin(Time.get_ticks_msec() * 0.006) * 0.05, 0.0)
		return

	# Movement input
	var h := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := _flat(camera.transform.basis.x).normalized()
	var fwd := _flat(camera.transform.basis.z).normalized()
	var dir := (right * h + fwd * v).limit_length()

	if air_slam_active:
		vertical_vel -= 28.0 * delta
		player.position.y += vertical_vel * delta
		_move_body(player, dir, 5.2)
		if player.position.y <= 0.0:
			player.position.y = 0.0
			_finish_air_slam()
	elif mounted:
		var spd := 11.5 if wolf_charge_timer > 0.0 else 7.2
		_move_body(wolf, dir if dir.length() > 0.05 else (Vector3.RIGHT if wolf_charge_timer > 0.0 else Vector3.ZERO), spd)
		player.position = wolf.position + Vector3.UP * 1.38
		player.rotation.y = wolf.rotation.y
	else:
		_move_body(player, dir, 5.0)
		_update_wolf_follow(delta)

	# Keep Yellow Bird perched on traveler's cap or between wolf ears
	var bird_target := (wolf.position + Vector3(0, 1.56, 0.85)) if mounted else (player.position + Vector3(0, 1.45, 0))
	bird.position = bird.position.lerp(bird_target, clampf(delta * 10.0, 0.0, 1.0))

	# Auto-trigger Zone D boss encounter upon stepping onto Stone Bridge
	if beat == Beat.GATE_OPENED and _feet().x > BRIDGE_START_X + 1.2:
		_start_boss_encounter()

	# Update Boss AI
	if beat == Beat.BOSS_FIGHT:
		_update_boss(delta)

	# Auto-trigger Vista Moment on reaching Lookout
	if beat == Beat.BOSS_RETIRED and not vista_zoomed and _feet().x > 25.2:
		vista_zoomed = true
		beat = Beat.VISTA_DONE
		create_tween().tween_property(camera, "size", 23.5, 2.2)
		_show_player_emote("✨", 3.0)
		_show_subtitle("雲海瞭望台｜遠方仍有四位老古董 Boss 還沒收到通知——第一章：翡翠天梯古林！", 6.0)

	# Smooth camera follow + optional shake
	var cam_target := _feet()
	if vista_zoomed:
		cam_target = VISTA_POS + Vector3(3.5, 0.0, -1.5)
	_position_camera(cam_target, clampf(delta * 4.5, 0.0, 1.0))
	if shake_time > 0.0:
		camera.position += Vector3(randf_range(-0.18, 0.18), randf_range(-0.12, 0.12), 0.0)

	_update_ui()

func _move_body(body: CharacterBody3D, dir: Vector3, speed: float) -> void:
	body.velocity = dir * speed
	if dir.length_squared() > 0.002:
		body.rotation.y = atan2(dir.x, dir.z)
	body.move_and_slide()

func _update_wolf_follow(_delta: float) -> void:
	var target := player.position
	var stop_dist := 1.75
	if wolf_charge_timer > 0.0 and beat == Beat.BOSS_FIGHT:
		target = boss.position + Vector3(-1.3, 0, 0)
		stop_dist = 0.25
		if _flat(wolf.position - boss.position).length() < 2.2 and boss_state == BossState.WINDUP:
			_interrupt_boss_with_wolf()
	elif not gate_opened and player.position.x > WALL_X - 0.3 and wolf.position.x < WALL_X:
		# Wolf sits outside the narrow slit and tilts head with ?
		target = Vector3(WALL_X - 1.8, 0, NARROW_SLIT_Z)
		stop_dist = 0.4
		wolf_emote.text = "?"
	else:
		wolf_emote.text = ""
		if gate_opened and absf(player.position.x - WALL_X) > 1.2 and (player.position.x - WALL_X) * (wolf.position.x - WALL_X) < 0.0:
			var side := -1.0 if player.position.x > WALL_X else 1.0
			var aligned := absf(wolf.position.z - GATE_Z) < 0.65
			target = Vector3(WALL_X + (-side * 1.6 if aligned else side * 1.6), 0, GATE_Z)
			stop_dist = 0.2

	var diff := _flat(target - wolf.position)
	var spd := 12.5 if wolf_charge_timer > 0.0 else 5.8
	_move_body(wolf, diff.normalized() if diff.length() > stop_dist else Vector3.ZERO, spd)

func _unhandled_input(event: InputEvent) -> void:
	if beat == Beat.TITLE:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_start_prologue()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: _interact()
			KEY_F: _toggle_mount()
			KEY_Q: _wolf_action()
			KEY_J: _sword_attack()
			KEY_R: get_tree().reload_current_scene()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_sword_attack()

func _interact() -> void:
	# 1. Buy -50¢ Sword at Goblin Shop
	if beat == Beat.WAKE_TO_SHOP and _near(SHOP_INTERACT, 2.4):
		has_sword = true
		player_sword.show()
		beat = Beat.SHOP_DONE
		_show_player_emote("💰", 1.5)
		_show_goblin_bubble("好爽快！前面石橋那位稻草人哨長還沒收到停戰通知，快騎上你的導遊狼去幫牠辦退休吧！", 6.0)
		var tw := create_tween()
		tw.tween_property(player, "rotation:y", player.rotation.y + TAU, 0.45)
		return

	# 2. Pull inner lever to open Wide Wolf Gate
	if not gate_opened and not mounted and _near(LEVER_POS, 2.0):
		gate_opened = true
		beat = Beat.GATE_OPENED
		_show_player_emote("!", 1.2)
		create_tween().tween_property(stone_gate, "position:y", 4.0, 0.45)
		create_tween().tween_property(lever_handle, "rotation:z", -0.7, 0.25)
		_show_subtitle("石門已開啟！巨狼立刻跑過來與你會合。", 2.8)
		return

	# 3. Stamp defeated Scarecrow Captain as Officially Retired
	if beat == Beat.BOSS_KNEELED and _near(boss.position, 3.0):
		_retire_boss()
		return

	# 4. Open Treasure Chest -> Equip Spring Test Saddle!
	if chest.visible and _near(chest.position, 2.2):
		chest.hide()
		has_spring_saddle = true
		wolf_spring_pad.show()
		_show_player_emote("✨", 2.2)
		_show_subtitle("獲得首件神裝《彈簧試驗鞍座》！騎上巨狼後按 F 下騎，即可彈飛高空施展 200% 暴擊下劈！", 5.5)
		return

	# 5. Inspect Guild Bounty Board at Vista
	if _near(BOUNTY_POS + Vector3(0, 0, 1.0), 2.4):
		_show_player_emote("!", 1.5)
		_show_subtitle("懸賞板：翡翠樹王／河神巨蟹／沙暴騎士長／霜龍大將軍——右側還釘著一封「最高機密未寄出信件」。", 5.5)

func _toggle_mount() -> void:
	if air_slam_active:
		return
	if mounted:
		mounted = false
		if has_spring_saddle:
			# Spring Test Saddle Launch!
			player.position = wolf.position + Vector3(0, 1.55, 0)
			air_slam_active = true
			vertical_vel = 11.2
			_show_player_emote("✨", 1.2)
			return
		# Standard safe dismount
		var shape := SphereShape3D.new()
		shape.radius = PLAYER_RADIUS
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = 1
		for off in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
			var cand: Vector3 = wolf.position + off * 1.15
			params.transform.origin = cand + Vector3.UP * PLAYER_RADIUS
			if get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
				player.position = cand
				return
		player.position = wolf.position + Vector3(0, 0, 1.1)
	elif _near(wolf.position, 2.6):
		mounted = true
		player.position = wolf.position + Vector3.UP * 1.38
		_show_player_emote("✨", 0.9)

func _finish_air_slam() -> void:
	air_slam_active = false
	shake_time = 0.22
	var ring := marker(player.position, GOLD, 2.4)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.25)
	tw.tween_callback(ring.queue_free)
	_show_player_emote("✨", 1.4)
	_show_subtitle("彈簧鞍座・飛天暴擊下劈！(200% CRIT)", 2.2)

func _wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = 1.6
	wolf_charge_timer = 0.55

	# Smash timber barricade in Zone C!
	if not timber_broken and mounted and _flat(wolf.position - TIMBER_POS).length() < 4.5:
		timber_broken = true
		beat = Beat.TIMBER_SMASHED
		timber_barricade.queue_free()
		shake_time = 0.22
		hitstop_frames = 4
		_show_player_emote("✨", 1.2)
		_show_subtitle("巨狼一舉撞碎枯木路障！前方出現狹窄石門，下騎鑽縫開閘吧。", 3.8)
		return

	# Command wolf to interrupt boss heavy windup
	if beat == Beat.BOSS_FIGHT:
		if mounted:
			_toggle_mount()
		_show_player_emote("!", 0.8)

func _start_boss_encounter() -> void:
	beat = Beat.BOSS_FIGHT
	boss_state = BossState.IDLE
	boss_timer = 1.2
	_show_boss_bubble("站住！前方乃魔王軍第三防線！報上通關密語！", 3.5)
	_show_player_emote("✉️", 2.2)
	get_tree().create_timer(2.3).timeout.connect(func() -> void:
		if beat == Beat.BOSS_FIGHT:
			_show_boss_bubble("休想拿假停戰信騙我！大軍明天就會開戰，接招吧！", 3.5)
	)

func _update_boss(delta: float) -> void:
	boss_timer -= delta
	match boss_state:
		BossState.IDLE:
			var toward := _flat(_feet() - boss.position)
			boss.rotation.y = atan2(toward.x, toward.z)
			boss_cue.text = "稻草人哨長 (%d/%d)" % [boss_hp, MAX_BOSS_HP]
			if boss_timer <= 0.0:
				boss_state = BossState.WINDUP
				boss_timer = 2.0
				attack_ring.position = boss.position + Vector3(0, 0.05, 0)
				attack_ring.show()
				boss_hammer.rotation_degrees.x = -75.0
				boss_cue.text = "紅光蓄力中！快按 [Q] 巨狼撞斷！"
				boss_cue.modulate = STAMP_RED
		BossState.WINDUP:
			if boss_timer <= 0.0:
				attack_ring.hide()
				boss_hammer.rotation_degrees.x = 25.0
				shake_time = 0.16
				if _flat(_feet() - boss.position).length() < 2.8:
					player_hp = maxi(1, player_hp - 1)
					_show_player_emote("💦", 1.0)
				boss_state = BossState.IDLE
				boss_timer = 1.3
				boss_cue.modulate = Color("#ffd59e")
		BossState.STAGGERED:
			boss.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.22
			boss_cue.text = "破防踉蹌！趁現在連斬！"
			boss_cue.modulate = GOLD
			if boss_timer <= 0.0:
				boss.rotation.z = 0.0
				boss_state = BossState.IDLE
				boss_timer = 1.1
				boss_cue.modulate = Color("#ffd59e")

func _interrupt_boss_with_wolf() -> void:
	attack_ring.hide()
	boss_hammer.rotation_degrees.x = 0.0
	boss_state = BossState.STAGGERED
	boss_timer = 3.2
	hitstop_frames = HITSTOP_FRAMES_BREAK
	shake_time = 0.25
	_show_boss_bubble("嗚哇！哪來的退休斥候狼！", 2.4)
	_show_subtitle("破防成功（Stagger）！趁哨長踉蹌時靠近按左鍵／J 爆發連斬！", 3.0)

func _sword_attack() -> void:
	if not has_sword or mounted or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.32
	# Quick sword slash animation
	var tw := create_tween()
	tw.tween_property(player_sword, "rotation:y", -1.4, 0.1)
	tw.tween_property(player_sword, "rotation:y", 0.0, 0.16)

	if beat == Beat.BOSS_FIGHT and _flat(player.position - boss.position).length() < 2.7:
		var dmg := 2 if boss_state == BossState.STAGGERED else 1
		boss_hp = maxi(0, boss_hp - dmg)
		hitstop_frames = 3
		if boss_hp <= 0:
			boss_state = BossState.KNEELED
			beat = Beat.BOSS_KNEELED
			attack_ring.hide()
			boss.rotation.z = 0.0
			boss.position.y = -0.35
			boss_cue.text = "體力耗盡 — 靠近按 [E] 辦理退休！"
			boss_cue.modulate = GOLD
			_show_boss_bubble("好強的小傢伙……等等，那封信是真的？", 4.0)

func _retire_boss() -> void:
	beat = Beat.BOSS_RETIRED
	boss_state = BossState.RETIRED
	# Yellow Bird dive-bomb stamp!
	boss_stamp.show()
	hitstop_frames = 5
	shake_time = 0.2
	_show_player_emote("✨", 2.0)
	_show_boss_bubble("什麼？！停戰一百年了？！那我這段時間到底在加班給誰看啊！", 5.5)

	# Instant World Payoff: swap helmet to straw hat, dash to bridgehead tea stall, drop chest!
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		boss_helmet.hide()
		boss_straw_hat.show()
		boss_hammer.hide()
		boss_stamp.hide()
		boss.position = TEA_STALL_POS + Vector3(0, 0, -0.75)
		boss.rotation.y = 0.0
		boss_cue.text = "茶攤老闆（原哨長）"
		boss_cue.modulate = Color("#b8f5c8")
		tea_stall.show()
		chest.show()
		_show_boss_bubble("百年庫存裝備送你了！我要去泡茶看風景囉！", 5.0)
	)

func _show_player_emote(icon: String, duration := 1.5) -> void:
	player_emote.text = icon
	emote_timer = duration
	player_emote.scale = Vector3.ONE * 0.4
	create_tween().tween_property(player_emote, "scale", Vector3.ONE, 0.18)

func _show_subtitle(words: String, duration := 3.5) -> void:
	subtitle_label.text = words
	subtitle_timer = duration

func _show_goblin_bubble(words: String, duration := 4.5) -> void:
	goblin_bubble.text = words
	goblin_talk_timer = duration

func _show_boss_bubble(words: String, duration := 3.5) -> void:
	boss_bubble.text = words
	boss_talk_timer = duration

func _update_ui() -> void:
	var titles := {
		Beat.TITLE: "林間營火空地（標題畫面）",
		Beat.WAKE_TO_SHOP: "前往 B 區「骨盔哥布林清倉行」購入五折短劍",
		Beat.SHOP_DONE: "按 [F] 騎上巨狼，按 [Q] 撞碎前方枯木路障",
		Beat.TIMBER_SMASHED: "下騎鑽入右側石門窄縫，拉下內側拉桿開閘",
		Beat.GATE_OPENED: "跨上雲海石橋，勸退稻草人哨長",
		Beat.BOSS_FIGHT: "等哨長紅光蓄力時按 [Q] 巨狼撞斷，再近身連斬！",
		Beat.BOSS_KNEELED: "靠近哨長按 [E] 蓋下「正式退休」紅章",
		Beat.BOSS_RETIRED: "開啟軍需寶箱裝備《彈簧試驗鞍座》，再前往右側雲海瞭望台",
		Beat.VISTA_DONE: "序章完成！可試跳彈簧鞍座下劈，或檢視公會懸賞板",
	}
	objective_label.text = "《補簽遠行》序章　／　" + titles[beat]
	var st := "旅人 HP %d/5" % player_hp
	if has_sword:
		st += "　｜　武器：五折庫存短劍"
	if has_spring_saddle:
		st += "　｜　鞍座：彈簧試驗鞍座"
	if mounted:
		st += "　｜　騎乘巨狼中"
	status_label.text = st

	prompt_label.text = ""
	if beat == Beat.WAKE_TO_SHOP and _near(SHOP_INTERACT, 2.4):
		prompt_label.text = "[E] 以 50¢ 購入發光短劍"
	elif not gate_opened and not mounted and _near(LEVER_POS, 2.0):
		prompt_label.text = "[E] 拉下開閘拉桿"
	elif beat == Beat.BOSS_KNEELED and _near(boss.position, 3.0):
		prompt_label.text = "[E] 召喚胖黃鳥蓋下「正式退休」紅章"
	elif chest.visible and _near(chest.position, 2.2):
		prompt_label.text = "[E] 開啟百年軍需寶箱（取得《彈簧試驗鞍座》）"
	elif _near(BOUNTY_POS + Vector3(0, 0, 1.0), 2.4):
		prompt_label.text = "[E] 檢視公會懸賞板"
	elif beat != Beat.TITLE and not mounted and _near(wolf.position, 2.6):
		prompt_label.text = "[F] 騎上巨狼拍檔"

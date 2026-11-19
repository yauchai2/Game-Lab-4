extends "res://harbor/Blockout.gd"

enum Journey { ARRIVAL, SIDE_DOOR, REJOIN, HUNT, RETURN, DONE }
enum Attack { READY, WINDUP, RECOVER }

const BODY_RADIUS := 0.30
const BEAST_RADIUS := 0.82
const MAX_CRAB_HP := 6
const HOLD_RANGE := 5.6
const SHOT_RANGE := 10.0

var journey := Journey.ARRIVAL
var attack := Attack.READY
var crab_hp := MAX_CRAB_HP
var player_hp := 3
var beast_hp := 3
var mounted := false
var gate_open := false
var shield_dropped := false
var has_shield := false
var equipped := false
var active_hunt := false
var defending := false
var engaged_beast := false
var crab_timer := 0.6
var hold_time := 0.0
var fire_cooldown := 0.0
var message_time := 0.0
var loot_position := Vector3.ZERO
var attack_target := Vector3.ZERO
var player := CharacterBody3D.new()
var beast := CharacterBody3D.new()
var crab := Node3D.new()
var camera := Camera3D.new()
var objective := Label.new()
var prompt := Label.new()
var vitals := Label.new()
var feedback := Label.new()
var player_shield: MeshInstance3D
var crab_shield: MeshInstance3D
var weak_point: MeshInstance3D
var attack_mark: MeshInstance3D
var loot: MeshInstance3D
var crab_cue: Label3D

func _ready() -> void:
	build()
	make_actors()
	make_view()
	var stop := marker(ARENA, BLUE)
	stop.scale = Vector3(1.5, 1.0, 1.5)
	loot = box(self, Vector3.ZERO, Vector3(0.62, 0.11, 0.82), GOLD)
	loot.hide()
	attack_mark = marker(Vector3.ZERO, Color("#ea725c"))
	attack_mark.scale = Vector3(2.85, 1.0, 2.85)
	attack_mark.hide()
	update_ui()

func make_actors() -> void:
	make_body(player, SHIP + Vector3(0.1, 0, 0), BODY_RADIUS)
	box(player, Vector3(0, 0.43, 0), Vector3(0.52, 0.65, 0.38), BLUE)
	sphere(player, Vector3(0, 0.93, 0.02), Vector3(0.52, 0.55, 0.51), Color("#e9cbad"))
	box(player, Vector3(-0.32, 0.50, -0.05), Vector3(0.11, 0.60, 0.13), TIMBER)
	player_shield = box(player, Vector3(0.36, 0.53, 0), Vector3(0.15, 0.66, 0.51), GOLD)
	player_shield.hide()
	make_body(beast, SHIP + Vector3(-0.8, 0, 0), BEAST_RADIUS)
	var dark := Color("#4d5361")
	box(beast, Vector3(0, 0.79, 0), Vector3(1.09, 0.83, 1.76), dark)
	box(beast, Vector3(0, 1.02, 0.83), Vector3(0.68, 0.64, 0.65), dark)
	for x in [-0.35, 0.35]:
		for z in [-0.58, 0.62]:
			box(beast, Vector3(x, 0.30, z), Vector3(0.24, 0.60, 0.27), dark)
		box(beast, Vector3(x * 0.62, 1.43, 0.93), Vector3(0.16, 0.30, 0.19), dark)
	box(beast, Vector3(0, 1.20, -0.15), Vector3(0.87, 0.17, 0.64), Color("#b49574"))
	add_child(crab)
	crab.position = CRAB_HOME
	sphere(crab, Vector3(0, 0.7, 0), Vector3(1.95, 1.05, 1.48), Color("#ad7166"))
	for x in [-1.05, 1.05]:
		box(crab, Vector3(x, 0.42, 0.36), Vector3(0.65, 0.34, 0.91), Color("#b97966"))
	crab_shield = box(crab, Vector3(0, 0.91, 0.77), Vector3(1.00, 1.16, 0.19), Color("#7e98a5"))
	weak_point = sphere(crab, Vector3(0.76, 1.37, 0.48), Vector3.ONE * 0.39, GOLD)
	weak_point.hide()
	crab_cue = label_at(crab, Vector3(0.0, 1.88, 0.0), "巨蟹")

func make_body(body: CharacterBody3D, pos: Vector3, radius: float) -> void:
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 1
	add_child(body)
	var shape := SphereShape3D.new()
	shape.radius = radius
	add_shape(body, shape, Vector3.UP * radius)
	body.position = pos

func make_view() -> void:
	var focus := Vector3(-2.4, 0, 0.15)
	add_child(camera)
	camera.position = focus + Vector3(6, 22, 25.5)
	camera.look_at(focus)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.0
	camera.current = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#272d34")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d2d9e0")
	env.ambient_light_energy = 0.62
	camera.environment = env
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("#ffe2bf")
	sun.light_energy = 0.72
	sun.shadow_enabled = true

	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	layer.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	add_ui_line(column, objective, 23)
	add_ui_line(column, vitals, 17)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	add_ui_line(column, feedback, 19)
	add_ui_line(column, prompt, 19)
	var controls := Label.new()
	controls.text = "WASD / 方向鍵 移動　 E 互動　 F 上下騎　 Q 頂住　 左鍵 射箭　 R 重來"
	add_ui_line(column, controls, 16)

func add_ui_line(parent: VBoxContainer, label: Label, size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color("#252730"))
	label.add_theme_constant_override("outline_size", 8)
	parent.add_child(label)

func feet() -> Vector3:
	return beast.position if mounted else player.position

func _physics_process(delta: float) -> void:
	message_time = maxf(0, message_time - delta)
	fire_cooldown = maxf(0, fire_cooldown - delta)
	hold_time = maxf(0, hold_time - delta)
	var horizontal := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := flat(camera.transform.basis.x).normalized()
	var toward_camera := flat(camera.transform.basis.z).normalized()
	var direction := (right * horizontal + toward_camera * vertical).limit_length()
	if player_hp <= 0:
		direction = Vector3.ZERO
	defending = equipped and not mounted and Input.is_physical_key_pressed(KEY_SPACE)
	player_shield.position = Vector3(0.06, 0.68, 0.30) if defending else Vector3(0.36, 0.53, 0)
	player_shield.rotation.y = PI / 2.0 if defending else 0.0
	if mounted:
		move_body(beast, direction, 6.4)
		player.position = beast.position + Vector3.UP * 1.25
		player.rotation.y = beast.rotation.y
	else:
		move_body(player, direction, 2.1 if defending else 4.5)
		follow_beast()
	if journey == Journey.REJOIN and player.position.x > 2.1 and beast.position.x > 1.05:
		journey = Journey.HUNT
	if journey == Journey.HUNT and not active_hunt and feet().x > 4.1:
		active_hunt = true
		notify_player("巨蟹在前面。下騎後，等牠舉盾再按 Q。")
	if active_hunt:
		update_crab(delta)
	update_ui()

func flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0, p.z)

func move_body(body: CharacterBody3D, direction: Vector3, speed: float) -> void:
	body.velocity = direction * speed
	if direction.length_squared() > 0.001:
		body.rotation.y = atan2(direction.x, direction.z)
	body.move_and_slide()

func follow_beast() -> void:
	var target := player.position
	var stop_distance := 1.45
	if hold_time > 0.0 and active_hunt:
		target = crab.position + Vector3(-1.55, 0, 0.6)
		stop_distance = 0.15
	elif not gate_open and player.position.x > 0.0:
		target = Vector3(-1.6, 0, SMALL_GAP)
		stop_distance = 0.4
	elif gate_open and absf(player.position.x) > 1.05 and player.position.x * beast.position.x <= 0.0:
		# Cross via the wide gate even if the rider took the narrow shortcut.
		var side := -1.0 if player.position.x > 0 else 1.0
		var aligned := absf(beast.position.z - BIG_GAP) < 0.48
		target = Vector3(-side * 1.35 if aligned else side * 1.35, 0, BIG_GAP)
		stop_distance = 0.17
	elif gate_open and absf(beast.position.x) < 1.1 and absf(beast.position.z - BIG_GAP) < 0.85:
		target = Vector3(1.4 if player.position.x > 0.0 else -1.4, 0, BIG_GAP)
		stop_distance = 0.17
	# On the pier keep the larger body centred until it clears the gangplank.
	if minf(beast.position.x, player.position.x) < -14.55:
		target.z = SHIP.z
	var offset := flat(target - beast.position)
	move_body(beast, offset.normalized() if offset.length() > stop_distance else Vector3.ZERO, 5.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: interact()
			KEY_F: toggle_mount()
			KEY_Q: command_hold()
			KEY_R: get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		shoot(event.position)

func near(pos: Vector3, radius := 1.6) -> bool:
	return flat(feet() - pos).length() < radius

func interact() -> void:
	if player_hp <= 0:
		return
	if near(GUILD):
		match journey:
			Journey.ARRIVAL:
				journey = Journey.SIDE_DOOR
				notify_player("榆姐：側門太窄，先請你從裡面開大閘。我把弓借你。")
			Journey.RETURN:
				if loot.visible:
					notify_player("盾還在潮灘，拾起後再回來。")
					return
				journey = Journey.DONE
				equipped = has_shield
				player_shield.visible = equipped
				notify_player("已裝備船錨盾。按住空白鍵可防禦。" if equipped else "狩獵完成。想取得盾牌，下次先射斷扣環。")
			Journey.DONE:
				start_rematch()
		return
	if journey == Journey.SIDE_DOOR and player.position.x > 0.68 and near(LEVER) and not mounted:
		gate_open = true
		journey = Journey.REJOIN
		create_tween().tween_property(gate, "position:y", 3.5, 0.40)
		notify_player("大閘已開。沿路回到閘口和獸伴會合。")
	elif journey == Journey.RETURN and loot.visible and near(loot_position):
		loot.hide()
		has_shield = true
		notify_player("拾得船錨盾。帶回公會登記並裝備。")

func start_rematch() -> void:
	journey = Journey.HUNT
	player_hp = 3
	beast_hp = 3
	crab_hp = MAX_CRAB_HP
	attack = Attack.READY
	crab_timer = 0.6
	shield_dropped = false
	engaged_beast = false
	crab.position = CRAB_HOME
	crab_shield.rotation.x = 0.0
	crab_shield.show()
	crab_cue.text = "巨蟹"
	crab.show()
	notify_player("潮灘已可再次狩獵。已裝備的盾牌可用空白鍵測試。")

func toggle_mount() -> void:
	if player_hp <= 0:
		return
	if mounted:
		var shape := SphereShape3D.new()
		shape.radius = BODY_RADIUS
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = 1
		for offset in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
			var candidate: Vector3 = beast.position + offset * 1.05
			# The mooring is open toward water on the two sides of the gangplank.
			if candidate.x < -14.60 and (candidate.z < 4.25 or candidate.z > 5.95):
				continue
			params.transform.origin = candidate + Vector3.UP * BODY_RADIUS
			if get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
				player.position = candidate
				mounted = false
				return
		notify_player("旁邊沒空位，先騎到開闊處。")
	elif hold_time <= 0.0 and near(beast.position, 2.2):
		mounted = true
		player.position = beast.position + Vector3.UP * 1.25
	elif hold_time > 0.0:
		notify_player("獸伴正在頂住巨蟹。")
	else:
		notify_player("靠近獸伴後按 F 上騎。")

func command_hold() -> void:
	if not active_hunt or mounted:
		notify_player("到潮灘並下騎後，就能指揮獸伴。")
		return
	if beast_hp <= 0:
		notify_player("獸伴力竭。按 R 重試。")
		return
	if beast.position.distance_to(crab.position) > HOLD_RANGE:
		notify_player("獸伴離巨蟹太遠。")
		return
	if hold_time <= 0.0:
		hold_time = 2.25
		notify_player("獸伴上前頂住。")

func update_crab(delta: float) -> void:
	if player_hp <= 0:
		return
	engaged_beast = hold_time > 0.0 and beast.position.distance_to(crab.position) <= 2.30 and beast_hp > 0
	crab_timer -= delta
	match attack:
		Attack.READY:
			var target := beast.position if engaged_beast else feet()
			var toward_target := flat(target - crab.position)
			if toward_target.length() > 1.95:
				crab.position += toward_target.normalized() * delta * 1.7
				crab.position.x = maxf(crab.position.x, 2.1)
			crab.rotation.y = atan2(toward_target.x, toward_target.z)
			if crab_timer <= 0.0 and toward_target.length() < 4.1:
				attack = Attack.WINDUP
				crab_timer = 1.6
				attack_target = target
				attack_mark.position = target + Vector3.UP * 0.04
				attack_mark.show()
		Attack.WINDUP:
			if engaged_beast:
				attack_target = beast.position
				attack_mark.position = attack_target + Vector3.UP * 0.04
			if crab_timer <= 0.0:
				resolve_crab_attack()
		Attack.RECOVER:
			if crab_timer <= 0.0:
				attack = Attack.READY
				crab_timer = 0.5
	weak_point.visible = attack == Attack.WINDUP and engaged_beast and not shield_dropped
	crab_shield.rotation.x = -0.6 if weak_point.visible else 0.0
	crab_cue.text = "扣環露出" if weak_point.visible else ("巨蟹蓄勢" if attack == Attack.WINDUP else "巨蟹")

func resolve_crab_attack() -> void:
	attack_mark.hide()
	attack = Attack.RECOVER
	for ally in [player, beast]:
		if ally == player and mounted:
			continue
		if flat(ally.position - attack_target).length() > 1.32:
			continue
		if ally == beast and engaged_beast:
			notify_player("獸伴扛住巨蟹的攻擊。")
		elif ally == beast:
			beast_hp = maxi(0, beast_hp - 1)
		elif defending:
			notify_player("船錨盾擋住了攻擊。")
		else:
			player_hp = maxi(0, player_hp - 1)
	crab_timer = 0.85

func shoot(screen_pos: Vector2) -> void:
	if not active_hunt or player_hp <= 0 or fire_cooldown > 0.0:
		return
	if mounted:
		notify_player("先下騎，再射箭。")
		return
	if player.position.distance_to(crab.position) > SHOT_RANGE:
		notify_player("離巨蟹太遠，往前靠近一些。")
		return
	fire_cooldown = 0.38
	var center := crab.position + Vector3.UP * 0.82
	var aim_scale := get_viewport().get_visible_rect().size.y / 720.0
	var eye := player.position + Vector3.UP * 0.8
	var camera_ray := camera.project_ray_normal(screen_pos)
	var origin := camera.project_ray_origin(screen_pos)
	var hit_point := origin + camera_ray * ((center.y - origin.y) / camera_ray.y)
	if weak_point.visible and camera.unproject_position(weak_point.global_position).distance_to(screen_pos) <= 19.0 * aim_scale:
		if has_wall_between(eye, weak_point.global_position):
			return
		draw_shot(eye, weak_point.global_position)
		shield_dropped = true
		crab_shield.hide()
		weak_point.hide()
		notify_player("扣環斷了。擊倒巨蟹後可拾起盾牌。")
		return
	var hit := camera.unproject_position(center).distance_to(screen_pos) <= 40.0 * aim_scale
	var end := center if hit else hit_point
	if has_wall_between(eye, end):
		return
	draw_shot(eye, end)
	if hit:
		crab_hp -= 2 if attack == Attack.RECOVER or shield_dropped else 1
		if crab_hp <= 0:
			finish_hunt()

func has_wall_between(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func draw_shot(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	if distance < 0.01:
		return
	var line := box(self, (from + to) / 2.0, Vector3(0.035, 0.035, distance), GOLD)
	if absf((to - from).normalized().dot(Vector3.UP)) < 0.999:
		line.look_at(to)
	get_tree().create_timer(0.16).timeout.connect(line.queue_free)

func finish_hunt() -> void:
	active_hunt = false
	hold_time = 0.0
	journey = Journey.RETURN
	crab.hide()
	attack_mark.hide()
	loot_position = crab.position
	loot.position = loot_position + Vector3.UP * 0.15
	loot.visible = shield_dropped
	notify_player("巨蟹倒下了。靠近盾牌按 E 拾取。" if shield_dropped else "巨蟹倒下了。回公會交回委託。")

func notify_player(words: String) -> void:
	feedback.text = words
	message_time = 3.5

func update_ui() -> void:
	var steps := [
		"過跳板，到藍旗公會報到",
		"下騎走側門，替獸伴打開大閘",
		"到大閘東側與獸伴會合",
		"到潮灘擊倒巨蟹，可先合力拆盾",
		"拾取掉落的盾牌，再回公會" if loot.visible else "回公會交回委託",
		"報到與狩獵完成",
	]
	objective.text = "西岸港城　／　" + steps[journey]
	var hp_line := "旅人 %d / 3　獸伴 %d / 3" % [player_hp, beast_hp]
	if active_hunt:
		hp_line += "　巨蟹 %d / %d" % [maxi(0, crab_hp), MAX_CRAB_HP]
	if mounted:
		hp_line += "　騎乘中"
	if engaged_beast and active_hunt:
		hp_line += "　獸伴守位中"
	vitals.text = hp_line
	feedback.visible = message_time > 0.0
	prompt.text = ""
	if player_hp <= 0:
		prompt.text = "旅人倒下了　[R] 重新開始"
	elif journey == Journey.ARRIVAL and near(GUILD):
		prompt.text = "[E] 向榆姐報到"
	elif journey == Journey.SIDE_DOOR and feet().x > 0.68 and near(LEVER):
		prompt.text = "[E] 拉開獸伴閘門"
	elif active_hunt and weak_point.visible:
		prompt.text = "瞄準金色扣環並點擊，取得船錨盾"
	elif journey == Journey.RETURN and loot.visible and near(loot_position):
		prompt.text = "[E] 拾取船錨盾"
	elif journey == Journey.RETURN and near(GUILD):
		prompt.text = "[E] 交回委託"
	elif journey == Journey.DONE:
		prompt.text = ("[空白鍵] 舉盾　" if equipped else "") + "[E] 再接狩獵　[R] 重走序章"

extends Node3D

const CAMP := Vector2i(-7, -1)
const TAKEOFF := Vector2i(-2, -2)
const DECK := Vector2i(2, -2)
const TRACK := Vector2i(0, 3)
const FINISH := Vector2i(7, 0)
const SAGE := Color("#889e88")
const BASALT := Color("#546466")
const PINE := Color("#415f58")
const TIMBER := Color("#aa8660")
const FIRE := Color("#ffac56")

var player := CharacterBody3D.new()
var wolf := Node3D.new()
var grid := AStarGrid2D.new()
var camera := Camera3D.new()
var prompt := Label.new()
var status := Label.new()
var message := Label.new()
var panel := VBoxContainer.new()
var borrowed := false
var lowered := false
var separated := false
var waiting := false
var observed := false
var finished := false
var leaping := false
var message_time := 0.0
var travel_time := 0.0
var jump_start := Vector3.ZERO
var last_safe := Vector3.ZERO
var wolf_path: Array[Vector2i] = []
var path_clock := 0.0
var shadow: MeshInstance3D
var flap := Node3D.new()
var flames: Array[Node3D] = []
var clock := 0.0

func altitude(z: float, east: bool) -> float:
	return clampf((2.5 - z) / 2.0, 0, 1) * (1.6 if east else 1.0)

func point(cell: Vector2i) -> Vector3:
	var east := cell.x >= 2
	var h := altitude(cell.y, east)
	if absi(cell.x) < 2 and cell.y == DECK.y:
		h = lerpf(1.0, 1.6, (cell.x + 2.0) / 4.0)
	return Vector3(cell.x, h, cell.y)

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.z))

func mesh_at(parent: Node3D, shape: Mesh, p: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1
	m.mesh = shape
	m.material_override = mat
	parent.add_child(m)
	m.position = p
	return m

func box(parent: Node3D, p: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := mesh_at(parent, mesh, p, color)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		m.add_child(body)
		body.add_child(collider)
	return m

func cone(parent: Node3D, p: Vector3, radius: float, height: float, color: Color, sides := 6) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return mesh_at(parent, mesh, p, color)

func _ready() -> void:
	for key in [[&"north", KEY_W, KEY_UP], [&"south", KEY_S, KEY_DOWN], [&"west", KEY_A, KEY_LEFT], [&"east", KEY_D, KEY_RIGHT]]:
		if not InputMap.has_action(key[0]):
			InputMap.add_action(key[0])
		for code in [key[1], key[2]]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			if not InputMap.action_has_event(key[0], ev):
				InputMap.action_add_event(key[0], ev)
	make_land()
	make_actors()
	make_ui()
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-58, -35, 0)
	light.light_color = Color("#ffe4bb")
	light.light_energy = 0.65
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 38
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b4c6cf")
	env.ambient_light_energy = 0.5
	camera.environment = env
	add_child(camera)
	camera.position = Vector3(6, 21, 18)
	camera.look_at(Vector3(0, 0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.5
	camera.current = true
	say("帶幼狼到對岸吃晚餐。牠在火旁，把影子伸了過來。", 6)

func make_land() -> void:
	grid.region = Rect2i(-9, -4, 19, 10)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in range(-9, 10):
		for z in range(-4, 6):
			var cell := Vector2i(x, z)
			var land := absi(x) >= 2 or z in [3, 4]
			grid.set_point_solid(cell, not land)
	# Continuous sloping banks lead down to the shallow crossing.
	for east in [false, true]:
		var x := 5.5 if east else -5.5
		var high := altitude(0, east)
		box(self, Vector3(x, high - 1.5, -2), Vector3(8, 3, 5), SAGE, true)
		var slope := box(self, Vector3(x, high / 2, 1.5), Vector3(8, 0.24, sqrt(4 + high * high)), SAGE, true)
		slope.rotation.x = atan(high / 2)
		slope.position -= slope.transform.basis.y * 0.12
		box(self, Vector3(x, -0.75, 4), Vector3(8, 1.5, 3), SAGE, true)
	box(self, Vector3(0, -0.43, 3.5), Vector3(3, 0.86, 2), Color("#aab2a0"), true)
	var water := box(self, Vector3(0, -0.96, 0), Vector3(44, 0.12, 32), Color("#648d96"))
	var water_material := ShaderMaterial.new()
	water_material.shader = preload("res://Creek.gdshader")
	water.material_override = water_material
	for i in range(12):
		var side := -1 if i < 6 else 1
		var x := side * (2.55 + (i % 6) * 1.21)
		var z := -4.03 + absf(sin(i * 2.3)) * 0.44
		var height := 0.9 + absf(sin(i * 8.4)) * 0.62
		var p := Vector3(x, altitude(z, side > 0), z)
		box(self, p + Vector3.UP * height * 0.55, Vector3(0.21, height * 1.1, 0.21), TIMBER.darkened(0.36))
		for j in range(3):
			var canopy := SphereMesh.new()
			canopy.radial_segments = 8
			canopy.rings = 4
			var crown := mesh_at(self, canopy, p + Vector3((j - 1) * 0.38, height + 0.38 - absf(j - 1) * 0.25, 0), PINE.lightened(0.06 + 0.05 * j))
			crown.scale = Vector3(1.45, 1.15, 1.35)
	for side in [-1, 1]:
		for i in range(8):
			var z := -4.2 + i * 0.73
			if absf(z - TAKEOFF.y) < 0.72:
				continue
			var rock_mesh := SphereMesh.new()
			rock_mesh.radial_segments = 6
			rock_mesh.rings = 3
			var rock := mesh_at(self, rock_mesh, Vector3(side * 1.58, -0.16, z), BASALT.lightened(0.24))
			rock.scale = Vector3(0.77, 1.9 + sin(i * 2.7) * 0.46, 0.97)
			rock.rotation.y = i * 1.2
	for c in [CAMP, FINISH]:
		var p := point(c)
		box(self, p + Vector3.UP * 0.12, Vector3(0.8, 0.24, 0.43), BASALT)
		flames.append(cone(self, p + Vector3.UP * 0.52, 0.32, 0.84, FIRE))
	for c in [TAKEOFF, DECK]:
		box(self, point(c) + Vector3.UP * 0.035, Vector3(0.85, 0.07, 1), TIMBER)
	for i in range(4):
		box(self, point(TRACK) + Vector3((i - 1.5) * 0.28, 0.025, sin(i * 3.7) * 0.2), Vector3(0.16, 0.05, 0.2), BASALT)
	add_child(flap)
	flap.position = point(DECK) + Vector3(-0.4, 0.4, 0)
	box(flap, Vector3.UP * 0.53, Vector3(0.13, 1.45, 0.85), TIMBER)

	var rng := RandomNumberGenerator.new()
	rng.seed = 218
	for i in range(76):
		var east := i % 2 == 0
		var x := rng.randf_range(2.2, 9.1) * (1 if east else -1)
		var z := rng.randf_range(-4.1, 5.2)
		if absf(z + 2) < 0.55 or absf(z - 3) < 0.52:
			continue
		var p := Vector3(x, altitude(z, east), z)
		for j in range(3):
			var blade := cone(self, p + Vector3(j * 0.085, 0.09, 0), 0.055, rng.randf_range(0.16, 0.32), PINE.lightened(0.17), 3)
			blade.rotation.z = (j - 1) * 0.25
	for x in [-8.7, -5.4, 4.0, 8.6]:
		var p := Vector3(x, altitude(-3.9, x > 0), -3.9)
		var rock := box(self, p + Vector3.UP * 0.27, Vector3(0.9, 0.56, 0.64), BASALT)
		rock.rotation = Vector3(0.1, x, 0.09)
	for c in [CAMP, FINISH]:
		var p := point(c) + Vector3(0.6, 0, -0.65)
		box(self, p + Vector3.UP * 0.66, Vector3(0.08, 1.32, 0.08), TIMBER)
		box(self, p + Vector3(0.22, 1.1, 0), Vector3(0.45, 0.31, 0.05), Color("#bf775c"))

func make_actors() -> void:
	add_child(player)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 0.95
	collider.shape = shape
	collider.position.y = 0.48
	player.add_child(collider)
	player.floor_snap_length = 0.3
	box(player, Vector3.UP * 0.49, Vector3(0.42, 0.61, 0.32), Color("#b65e44"))
	box(player, Vector3.UP * 0.91, Vector3(0.38, 0.35, 0.35), Color("#efc896"))
	cone(player, Vector3.UP * 1.18, 0.32, 0.32, PINE)
	player.position = point(CAMP) + Vector3(0.9, 0.05, 0.4)
	last_safe = player.position
	add_child(wolf)
	box(wolf, Vector3.UP * 0.35, Vector3(0.36, 0.44, 0.7), BASALT)
	box(wolf, Vector3(0, 0.58, -0.28), Vector3(0.39, 0.34, 0.36), BASALT)
	box(wolf, Vector3(0, 0.53, -0.5), Vector3(0.24, 0.15, 0.2), Color("#c0c4ad"))
	for x in [-0.13, 0.13]:
		cone(wolf, Vector3(x, 0.85, -0.24), 0.11, 0.29, BASALT, 4)
	var tail := box(wolf, Vector3(0, 0.36, 0.42), Vector3(0.17, 0.2, 0.48), BASALT)
	tail.rotation.x = -0.4
	wolf.position = point(CAMP) + Vector3(-0.1, 0, 0.8)
	var oval := SphereMesh.new()
	oval.radius = 0.5
	oval.height = 1
	shadow = mesh_at(self, oval, wolf.position, Color("#303d43"))
	shadow.scale = Vector3(0.84, 0.035, 1.6)

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(panel)
	panel.position = Vector2(24, 16)
	var title := Label.new()
	title.text = "借影之森　／　青眠林"
	panel.add_child(title)
	panel.add_child(status)
	var bottom := VBoxContainer.new()
	layer.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = 24
	bottom.offset_bottom = -16
	bottom.add_child(message)
	bottom.add_child(prompt)
	var help := Label.new()
	help.text = "WASD／方向鍵 移動　 E 互動　 空白鍵 縱躍　 Q 呼喚／等候　 R 重新出發"
	bottom.add_child(help)
	for label: Label in [title, status, message, prompt, help]:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC", "PingFang TC"])
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 18 if label != title else 26)
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", Color("#293939"))

func say(line: String, seconds := 4.0) -> void:
	message.text = line
	message_time = seconds

func near(c: Vector2i, radius := 1.45) -> bool:
	return player.position.distance_to(point(c)) < radius

func wolf_near() -> bool:
	return wolf.position.distance_to(player.position) < 2.4

func hint() -> String:
	if finished:
		return "晚餐在對岸　·　旅程完成　　R 再走一次"
	if near(FINISH):
		return "E　圍火吃晚餐" if wolf_near() else "等狼來到火旁"
	if near(CAMP):
		return "E　歸還狼影" if borrowed else "E　接受狼影　／　可直接沿溪同行"
	if near(DECK) and not lowered:
		return "E　放下斜踏板"
	if near(TAKEOFF) and not lowered:
		return "空白鍵　躍上對岸木臺" if borrowed else "溪路在下游　／　可回營火借影"
	if near(TRACK) and not observed:
		return "E　察看足印"
	return "前往右岸營火"

func interact() -> void:
	if near(FINISH):
		if wolf_near():
			borrowed = false
			finished = true
			finish_time = clock
			say("幼狼躍起，叼回了乾糧。  " + ("旅行簿記下了溪底的足模。" if observed else "火邊多了一雙濕漉漉的腳印。"), 60)
		else:
			say("幼狼還在路上。沿路回去接牠吧。")
	elif near(CAMP):
		if wolf_near():
			borrowed = not borrowed
			say("影子落在你腳下。狼留住了自己的步伐。" if borrowed else "狼抖了抖耳朵，收回影子。")
		else:
			say("等幼狼走回火旁。")
	elif near(DECK) and not lowered:
		lower_bridge()
	elif near(TRACK) and not observed:
		observed = true
		say("溪泥留下分岔的蹄印。你把它記進旅行簿。")

func lower_bridge() -> void:
	lowered = true
	separated = false
	flap.hide()
	var plank := box(self, Vector3(0, 1.24, -2), Vector3(3.75, 0.16, 0.96), TIMBER, true)
	plank.rotation.z = atan(0.6 / 4)
	for x in range(-1, 2):
		grid.set_point_solid(Vector2i(x, -2), false)
	path_clock = 0
	say("踏板落穩了。幼狼可以沿木板走來。")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		get_tree().reload_current_scene()
		return
	if finished or leaping:
		return
	match event.keycode:
		KEY_E: interact()
		KEY_Q:
			waiting = not waiting
			path_clock = 0
			say("幼狼坐下等候。" if waiting else "你輕聲呼喚幼狼。")
		KEY_SPACE:
			if near(TAKEOFF) and borrowed and not lowered:
				jump_start = player.position
				travel_time = 0
				leaping = true
				separated = wolf.position.x < 0

func update_wolf(dt: float) -> void:
	var goal := cell_of(player.position)
	if separated and not lowered:
		if not leaping and player.position.x < -1.5:
			separated = false
		else:
			goal = TAKEOFF
	if waiting or (wolf_near() and not separated):
		wolf_path.clear()
		return
	path_clock -= dt
	var start := cell_of(wolf.position)
	if path_clock <= 0:
		path_clock = 0.45
		if grid.is_in_boundsv(goal) and not grid.is_point_solid(goal) and grid.is_in_boundsv(start):
			wolf_path = grid.get_id_path(start, goal)
			if wolf_path.size() > 1:
				wolf_path.pop_front()
	if wolf_path.is_empty():
		return
	var next := point(wolf_path[0])
	var delta := next - wolf.position
	if delta.length() < 0.1:
		wolf_path.pop_front()
		return
	wolf.rotation.y = atan2(-delta.x, -delta.z)
	wolf.position = wolf.position.move_toward(next, 3.9 * dt)

func _physics_process(dt: float) -> void:
	clock += dt
	if leaping:
		travel_time = minf(1, travel_time + dt / 0.68)
		player.position = jump_start.lerp(point(DECK) + Vector3.UP * 0.09, travel_time)
		player.position.y += sin(PI * travel_time) * 1.5
		if travel_time >= 1:
			leaping = false
			player.velocity = Vector3.ZERO
			say("你落在木臺上。回頭看看狼。")
	elif not finished:
		var direction := Input.get_vector("west", "east", "north", "south")
		var screen_right := camera.transform.basis.x
		var toward_camera := screen_right.cross(Vector3.UP)
		var motion := screen_right * direction.x + toward_camera * direction.y
		player.velocity.x = motion.x * 3.8
		player.velocity.z = motion.z * 3.8
		player.velocity.y -= 18 * dt
		player.move_and_slide()
		if player.is_on_floor():
			last_safe = player.position
		if player.position.y < -2.6:
			player.position = point(DECK) + Vector3.UP * 0.15 if last_safe.x >= 1.5 else point(CAMP) + Vector3.RIGHT
			player.velocity = Vector3.ZERO
			say("你回到了岸上。沿溪走，或從起跳石縱躍。")
	if not finished:
		update_wolf(dt)
	shadow.position = (player.position if borrowed else wolf.position) + Vector3.UP * 0.055
	for f in flames:
		f.scale.y = 1 + sin(clock * 6 + f.position.x) * 0.12
	if finished:
		wolf.position.y = altitude(wolf.position.z, wolf.position.x >= 2) + maxf(0, sin(minf(clock - finish_time, 0.7) * PI / 0.7)) * 0.65
	status.text = ("縱躍　旅人持有" if borrowed else "縱躍　幼狼持有") + ("　·　已記錄足模" if observed else "")
	prompt.text = hint()
	message_time -= dt
	if message_time <= 0:
		message.text = ""

var finish_time := -1.0

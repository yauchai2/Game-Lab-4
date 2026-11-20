extends "res://prologue/PrologueBase.gd"

enum BossState { IDLE, WINDUP, STAGGERED, KNEELED, RETIRED }

const MAX_BOSS_HP := 10
const WEST_EXIT := Vector3(-25.5, 0.0, 0.4)
const TIMBER_POS := Vector3(-14.5, 0.0, 0.0)
const WALL_X := -4.5
const NARROW_SLIT_Z := -4.2
const GATE_Z := 1.6
const LEVER_POS := Vector3(-2.6, 0.0, -4.2)
const BRIDGE_START_X := 2.0
const BOSS_HOME := Vector3(11.5, 0.0, 0.0)
const TEA_STALL_POS := Vector3(6.4, 0.0, -3.5)
const VISTA_POS := Vector3(28.0, 0.0, 0.0)
const BOUNTY_POS := Vector3(26.2, 0.0, -4.2)
const WAYPOINT_POS := Vector3(27.0, 0.0, 2.8)
const HIGH_LEDGE_POS := Vector3(25.5, 1.3, 6.2)
const CHAPTER_1_EXIT := Vector3(33.2, 0.0, 0.5)

var boss_state := BossState.IDLE
var boss_hp := MAX_BOSS_HP
var boss_active := false
var boss_timer := 1.2
var boss_talk_timer := 0.0
var vista_zoomed := false
var intro_playing := false

var timber_barricade: Node3D
var stone_gate: MeshInstance3D
var lever_handle: MeshInstance3D
var fog_bridge: Node3D
var fog_vista: Node3D
var tea_stall: Node3D
var high_chest: Node3D
var boss := Node3D.new()
var chest := Node3D.new()
var boss_helmet: MeshInstance3D
var boss_straw_hat: MeshInstance3D
var boss_hammer: MeshInstance3D
var boss_bubble: Label3D
var boss_cue: Label3D
var attack_ring: MeshInstance3D
var distant_riders: Array[Node3D] = []

var mobs: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []
var public_travelers: Array[Dictionary] = []
var coop_ally: Dictionary = {}
var coop_attack_cd := 0.0

func _ready() -> void:
	can_attack = true
	scene_shadow_tint = Color("#5c4578")
	set_wind_profile(Vector2(0.96, -0.26), 1.65, 0.42, 0.12)
	_build_road_map()
	_build_boss_and_chest()
	_spawn_poe_mobs()
	_spawn_public_travelers()

	var spawn := Vector3(-23.0, 0.0, 0.4)
	if PrologueState.spawn_tag == "from_waypoint":
		spawn = WAYPOINT_POS + Vector3(-1.5, 0.0, -0.5)
		vista_zoomed = true
	setup_core_trio(spawn)
	setup_camera_and_lighting(24.0 if vista_zoomed else 16.5, Color("#f2c3e0"), Color("#ffe2c2"), 0.88, Color("#ffe0b2"), 1.15, Color("#667bd4"), Color("#ffd1a6"), Color("#c9a8e0"))
	setup_hud()
	_apply_persisted_state()

	if not PrologueState.road_intro_played and PrologueState.spawn_tag != "from_waypoint":
		_play_arrival_intro()
	_update_ui()

func _play_arrival_intro() -> void:
	PrologueState.road_intro_played = true
	intro_playing = true
	input_locked = true
	# Break 2.5D: Low-angle panoramic sweep across the autumn highland & bridge
	play_cinematic_shot(Vector3(-25.5, 3.2, 6.2), Vector3(-6.0, 1.4, -0.5), 2.1, true, 50.0, true)
	spawn_flying_bird_flock(Vector3(-18.0, 5.2, -4.0), Vector3(5.2, 0.25, 0.4), 5)
	show_player_emote("!", 2.0)
	show_subtitle("《雲海古道》── 雲霧深處，舊軍哨長還在拼命加班……", 2.4)
	get_tree().create_timer(2.1).timeout.connect(func() -> void:
		if intro_playing:
			intro_playing = false
			input_locked = false
			exit_cinematic_shot()
	)

func on_map_input(event: InputEvent) -> bool:
	if intro_playing:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			intro_playing = false
			input_locked = false
			exit_cinematic_shot()
			return true
	return false

func _build_road_map() -> void:
	# Expanded 68m x 28m Autumn Highland + Waterfall Canyon + Long Stone Bridge + Crescent Vista!
	organic_mound(self, Vector3(-16.5, -0.54, 0.4), 13.8, 10.6, 1.08, DAY_GRASS, -8.0)
	organic_mound(self, Vector3(-6.2, -0.50, -0.5), 9.6, 9.2, 1.0, DAY_GRASS_WARM, 14.0)
	organic_mound(self, Vector3(0.8, -0.50, 0.2), 5.2, 7.2, 1.0, DAY_GRASS, -12.0)

	# Canyon Stream & Waterfall flowing beneath the Long Arched Stone Bridge!
	curved_stream([
		Vector3(7.5, -0.6, -12.5),
		Vector3(9.5, -0.6, -3.5),
		Vector3(11.5, -0.6, 5.5),
		Vector3(14.5, -0.6, 13.5)
	], 4.2, Color("#3496e8"), Color("#e0f8ff"), -1.05)
	waterfall_cascade(Vector3(7.4, -0.9, -9.8), 3.0, 4.4, 15.0, Color("#52b8ff"), Color("#eefbff"))

	# Long Arched Cobblestone Bridge (X: 2.2 to 20.4)
	for bi in range(10):
		var bx := 3.0 + float(bi) * 1.92
		var arch_y := sin(float(bi) / 9.0 * PI) * 0.16
		var seg := box(self, Vector3(bx, -0.45 + arch_y, 0.0), Vector3(2.15, 0.92, 9.2), STONE_LIGHT if bi % 2 == 0 else Color("#c4c0d2"))
		seg.rotation_degrees.y = sin(float(bi) * 1.4) * 1.6
		for bz in [-4.5, 4.5]:
			var post := cylinder(self, Vector3(bx, 0.35 + arch_y, bz), 0.36, 0.44, 0.95, STONE)
			post.rotation_degrees.z = sin(float(bi) + bz) * 4.0
	invisible_boundary_wall(Vector3(11.5, 0.8, -4.7), Vector3(18.5, 1.6, 0.6))
	invisible_boundary_wall(Vector3(11.5, 0.8, 4.7), Vector3(18.5, 1.6, 0.6))
	lantern_post(Vector3(3.8, 0.0, -4.1), 2.4, FIRE_ORANGE, 12.0)
	lantern_post(Vector3(18.8, 0.0, 4.0), 2.4, FIRE_ORANGE, -165.0)

	# Expanded Crescent Vista Cliff Meadow (East)
	organic_mound(self, Vector3(28.0, -0.52, 0.2), 9.2, 9.6, 1.04, DAY_GRASS_WARM, 16.0)
	organic_mound(self, Vector3(32.5, -0.50, 0.5), 5.6, 6.0, 1.0, Color("#84b868"), -10.0)

	# Winding S-curve trail across the expanded autumn highland
	curved_path([
		WEST_EXIT, Vector3(-20.2, 0.0, 1.6), Vector3(-16.2, 0.0, -0.4),
		Vector3(-11.2, 0.0, 1.4), Vector3(-6.2, 0.0, -0.8), Vector3(2.4, 0.0, 0.2)
	], 2.4, TRAIL, TRAIL_STONE)
	curved_path([Vector3(-8.2, 0.0, -2.0), Vector3(-5.8, 0.0, -4.2), LEVER_POS], 1.5, GOLD, TRAIL_STONE)
	curved_path([Vector3(21.0, 0.0, 0.0), Vector3(26.5, 0.0, -0.6), CHAPTER_1_EXIT], 2.3, TRAIL, TRAIL_STONE)

	# Expanded 88m x 44m Walkable Highland Side-Glades + Old-Army Ruins + Eastern Vista Plateau + 360 Sunset Cloud Panorama!
	organic_mound(self, Vector3(-20.5, -0.52, -11.5), 11.2, 7.6, 1.04, DAY_GRASS_WARM, 12.0)
	organic_mound(self, Vector3(-16.5, -0.52, 11.8), 11.6, 7.8, 1.04, DAY_GRASS, -10.0)
	organic_mound(self, Vector3(36.8, -0.50, 0.6), 9.6, 9.8, 1.02, Color("#7bb666"), 8.0)
	curved_path([Vector3(-20.2, 0, -2.5), Vector3(-21.2, 0, -8.5), Vector3(-22.0, 0, -12.5)], 1.9, TRAIL_STONE)
	curved_path([Vector3(-18.2, 0, 3.5), Vector3(-17.0, 0, 9.2), Vector3(-16.2, 0, 12.8)], 2.0, TRAIL)
	stone_archway(Vector3(-21.5, 0.0, -12.2), 14.0, 1.05, true)
	cozy_cabin(Vector3(-26.8, 0.0, -11.2), 38.0, CORAL_ROOF, TIMBER_LIGHT)
	stone_archway(Vector3(36.8, 0.0, 0.5), 90.0, 1.25, true)
	flower_patch(Vector3(-16.5, 0, 12.2), 16, [Color("#ff5c8d"), Color("#ff9eb5"), Color("#ffe066"), Color("#f2796b")], 3.8)
	spawn_destructible_crate(Vector3(-20.5, 0.0, -14.0), 4)
	spawn_destructible_crate(Vector3(-15.0, 0.0, 13.5), 4)
	spawn_destructible_crate(Vector3(35.0, 0.0, -4.5), 5)
	build_horizon_panorama(Vector3(6.0, 0.0, 0.0), 44.0, 22.0, "sunset_clouds")
	# Wind-blown autumn highland grass & sweeping @amelicart pink flower sea (980 tufts!)
	spawn_wind_grass_meadow(Vector3(-17.0, 0, 0.5), 11.5, 8.2, 240, Color("#c9833c"), Color("#f2c166"), Color("#ff6f9c"), 0.34, 1.1)
	spawn_wind_grass_meadow(Vector3(-16.5, 0, 11.8), 10.2, 6.2, 220, Color("#6ca652"), Color("#a3d96c"), Color("#ff5c8d"), 0.52, 1.25)
	spawn_wind_grass_meadow(Vector3(-20.5, 0, -11.5), 9.5, 5.8, 170, DAY_GRASS, Color("#f5c96e"), Color("#ff8ab0"), 0.30, 1.05)
	spawn_wind_grass_meadow(Vector3(-6.2, 0, -0.5), 7.8, 7.2, 170, DAY_GRASS_WARM, Color("#f7d07a"), Color("#ff7aa8"), 0.28, 1.05)
	spawn_wind_grass_meadow(Vector3(31.5, 0, 0.4), 10.5, 8.2, 180, Color("#75b35e"), Color("#b8e372"), Color("#ff8ab0"), 0.26, 1.1)

	invisible_boundary_wall(Vector3(-34.0, 0.8, 0.0), Vector3(0.8, 1.8, 38.0))
	invisible_boundary_wall(Vector3(44.0, 0.8, 0.0), Vector3(0.8, 1.8, 38.0))
	for z in [-17.2, 17.2]:
		invisible_boundary_wall(Vector3(-14.5, 0.8, z), Vector3(40.0, 1.8, 0.8))
		invisible_boundary_wall(Vector3(32.5, 0.8, z), Vector3(24.0, 1.8, 0.8))

	# Cliff outcrops, dense autumn trees, flowers & diagonal sunbeams
	cliff_outcrop(Vector3(-23.5, 0.0, -7.8), 3.4, 2.8, 2.8, STONE_LIGHT, DAY_GRASS, 15.0)
	cliff_outcrop(Vector3(-10.5, 0.0, 8.6), 3.2, 2.5, 2.8, STONE, DAY_GRASS_WARM, -22.0)
	cliff_outcrop(Vector3(29.8, 0.0, -8.2), 3.4, 2.8, 2.8, STONE_LIGHT, DAY_GRASS, -18.0)
	for tp in [
		[Vector3(-23.8, 0, -5.0), 1.3, PINE_ORANGE], [Vector3(-19.5, 0, -8.2), 1.25, Color("#4a6b8a")],
		[Vector3(-22.5, 0, 7.6), 1.2, PINE_ORANGE], [Vector3(-16.2, 0, 8.2), 1.3, Color("#d96b38")],
		[Vector3(-8.8, 0, -8.0), 1.2, Color("#4a6b8a")], [Vector3(24.5, 0, -8.4), 1.25, PINE_ORANGE],
		[Vector3(31.5, 0, 7.2), 1.2, PINE_TEAL]
	]:
		cozy_tree(tp[0], float(tp[1]), tp[2], randf_range(-7.0, 7.0))
	flower_patch(Vector3(-19.2, 0, -3.5), 14, [Color("#ff6f9c"), Color("#ff9eb5"), Color("#fff2b2"), Color("#f2796b")], 3.4)
	flower_patch(Vector3(-15.8, 0, 4.6), 14, [Color("#ff5c8d"), Color("#ff9eb5"), Color("#ffe066")], 3.2)
	flower_patch(Vector3(-10.8, 0, 5.2), 10, [Color("#ff9eb5"), Color("#ffe066")], 2.4)
	flower_patch(Vector3(27.8, 0, -2.5), 9, [Color("#7cb8ff"), Color("#fff0a6"), Color("#f28ca8")], 2.3)

	sunbeam_shaft(Vector3(-17.0, 0.0, -1.0), 3.4, 20.0, Color(1.0, 0.90, 0.65, 0.11))
	sunbeam_shaft(Vector3(-7.0, 0.0, 1.0), 3.2, 20.0, Color(1.0, 0.90, 0.65, 0.10))
	sunbeam_shaft(Vector3(12.0, 0.0, 0.0), 3.6, 20.0, Color(1.0, 0.90, 0.65, 0.11))

	# Organic fallen mossy log barricade
	timber_barricade = Node3D.new()
	timber_barricade.position = TIMBER_POS
	add_child(timber_barricade)
	var log_a := cylinder(timber_barricade, Vector3(0, 0.72, 0), 0.56, 0.68, 17.5, TIMBER)
	log_a.rotation_degrees = Vector3(90, 0, 5)
	var log_b := cylinder(timber_barricade, Vector3(-0.42, 1.28, -0.8), 0.34, 0.42, 8.2, TIMBER_LIGHT)
	log_b.rotation_degrees = Vector3(84, 14, -8)
	sphere(timber_barricade, Vector3(0.1, 1.25, 1.8), Vector3(1.1, 0.55, 1.4), Color("#4e7c48"))
	var bar_body := StaticBody3D.new()
	timber_barricade.add_child(bar_body)
	var bar_sh := BoxShape3D.new()
	bar_sh.size = Vector3(1.1, 1.7, 18.0)
	add_shape(bar_body, bar_sh, Vector3(0, 0.85, 0))
	label_at(timber_barricade, Vector3(0, 2.45, 0), "[ Q ] 撞碎", FIRE_ORANGE, 30)

	# Organic mossy ruin archway wall at WALL_X (-4.5)
	for span: Vector2 in [Vector2(-9.6, -5.0), Vector2(-3.4, -0.2), Vector2(3.4, 9.6)]:
		var mid_z: float = (span.x + span.y) * 0.5
		var len_z: float = span.y - span.x
		invisible_boundary_wall(Vector3(WALL_X, 1.35, mid_z), Vector3(0.9, 2.7, len_z))
		boulder_cluster(Vector3(WALL_X, 0.0, mid_z), 1.25, STONE, true, false, mid_z * 12.0)
		sphere(self, Vector3(WALL_X, 1.7, mid_z), Vector3(1.2, 1.9, len_z * 0.9), STONE_LIGHT)
		sphere(self, Vector3(WALL_X, 2.5, mid_z), Vector3(1.05, 0.55, len_z * 0.75), Color("#4e7c48"))
	sphere(self, Vector3(WALL_X, 1.95, NARROW_SLIT_Z), Vector3(1.05, 0.45, 1.75), STONE_LIGHT)
	sphere(self, Vector3(WALL_X, 2.85, GATE_Z), Vector3(1.1, 0.55, 3.8), STONE_LIGHT)
	stone_gate = box(self, Vector3(WALL_X, 1.25, GATE_Z), Vector3(0.45, 2.45, 3.5), TIMBER, true)

	cylinder(self, LEVER_POS + Vector3(0, 0.36, 0), 0.28, 0.36, 0.72, STONE)
	lever_handle = cylinder(self, LEVER_POS + Vector3(0, 0.92, 0), 0.07, 0.09, 0.52, GOLD)
	marker(LEVER_POS, GOLD, 0.55)
	label_at(self, Vector3(WALL_X, 2.40, NARROW_SLIT_Z), "鑽入 ↘", GOLD, 28)

	fog_bridge = Node3D.new()
	add_child(fog_bridge)
	for fp in [Vector3(5.5, 2.0, -2.4), Vector3(9.5, 2.4, 0.0), Vector3(13.5, 2.2, 2.4), Vector3(16.5, 2.0, -1.2)]:
		sphere(fog_bridge, fp, Vector3(5.8, 4.4, 5.4), CLOUD_WHITE, true)

	fog_vista = Node3D.new()
	add_child(fog_vista)
	for vp in [Vector3(26.0, 2.6, -2.5), Vector3(29.5, 2.8, 1.5), Vector3(32.0, 2.5, -0.5)]:
		sphere(fog_vista, vp, Vector3(6.4, 4.8, 5.8), Color("#f5d9ef"), true)

	tea_stall = Node3D.new()
	tea_stall.position = TEA_STALL_POS
	tea_stall.rotation_degrees.y = 14.0
	add_child(tea_stall)
	box(tea_stall, Vector3(0, 0.48, 0), Vector3(2.2, 0.96, 1.1), TIMBER_LIGHT)
	cylinder(tea_stall, Vector3(-0.9, 1.2, -0.4), 0.07, 0.08, 1.8, TIMBER)
	cylinder(tea_stall, Vector3(0.9, 1.2, -0.4), 0.07, 0.08, 1.8, TIMBER)
	var stall_roof := box(tea_stall, Vector3(0, 2.08, 0), Vector3(2.7, 0.24, 1.7), CORAL_ROOF)
	stall_roof.rotation_degrees.x = 8.0
	sphere(tea_stall, Vector3(0.4, 1.1, 0.1), Vector3(0.32, 0.26, 0.32), Color("#6ec25a"))
	label_at(tea_stall, Vector3(0, 2.80, 0), "免費茶攤 🍵", GOLD, 30)
	tea_stall.hide()

	organic_mound(self, Vector3(HIGH_LEDGE_POS.x, 0.65, HIGH_LEDGE_POS.z), 1.85, 1.55, 1.3, STONE_LIGHT, 22.0)
	var ledge_body := StaticBody3D.new()
	ledge_body.position = Vector3(HIGH_LEDGE_POS.x, 0.65, HIGH_LEDGE_POS.z)
	add_child(ledge_body)
	var lsh := CylinderShape3D.new()
	lsh.radius = 1.65
	lsh.height = 1.3
	add_shape(ledge_body, lsh, Vector3.ZERO)
	high_chest = Node3D.new()
	high_chest.position = HIGH_LEDGE_POS
	high_chest.rotation_degrees.y = -24.0
	add_child(high_chest)
	box(high_chest, Vector3(0, 0.35, 0), Vector3(0.9, 0.62, 0.62), GOLD)
	label_at(high_chest, Vector3(0, 1.20, 0), "✨ 秘寶", GOLD, 26)

	var b_root := Node3D.new()
	b_root.position = BOUNTY_POS
	b_root.rotation_degrees.y = -20.0
	add_child(b_root)
	box(b_root, Vector3(0, 1.25, 0), Vector3(2.6, 1.7, 0.2), TIMBER_LIGHT, true)
	for i in range(4):
		var poster := box(b_root, Vector3(-0.85 + i * 0.56, 1.35, 0.14), Vector3(0.42, 0.55, 0.04), Color("#fff5dc"))
		poster.rotation_degrees.z = sin(float(i) * 2.1) * 6.0
	box(b_root, Vector3(0.85, 0.78, 0.15), Vector3(0.5, 0.36, 0.04), STAMP_RED)
	marker(BOUNTY_POS + Vector3(0, 0, 1.0), GOLD, 0.55)

	transition_signpost(WEST_EXIT, "← 雲丘市集", GOLD, 15.0)
	transition_signpost(WAYPOINT_POS, "驛站", Color("#98ffbd"), -22.0)

	for s in range(4):
		organic_mound(self, CHAPTER_1_EXIT + Vector3(s * 0.55, -0.14 * s, sin(float(s)) * 0.2), 0.75, 1.15, 0.22, Color("#6ca874"), float(s) * 14.0)
	cozy_tree(CHAPTER_1_EXIT + Vector3(0.6, 0, -2.6), 1.1, Color("#2f9e66"), 6.0)
	cozy_tree(CHAPTER_1_EXIT + Vector3(0.6, 0, 2.8), 1.15, Color("#2f9e66"), -5.0)
	marker(CHAPTER_1_EXIT + Vector3(-0.6, 0, 0), Color("#49c674"), 0.75)
	label_at(self, CHAPTER_1_EXIT + Vector3(-0.2, 2.35, 0), "→ 翡翠古林", Color("#b8ffd0"), 30)

	# Volumetric drifting clouds + distant @amelicart peaks
	for ci in range(6):
		var c_pos := Vector3(5.0 + float(ci) * 6.2, -1.6 if ci % 2 == 0 else 4.2, -11.5 if ci % 2 == 0 else 10.5)
		fluffy_cloud(c_pos, 1.35, 2.2, CLOUD_WHITE)
	sphere(self, Vector3(44, 4.5, -14), Vector3(14.0, 24.0, 12.0), PINK_PEAK, true)
	sphere(self, Vector3(52, 6.0, -2), Vector3(15.0, 28.0, 13.0), PURPLE_PEAK, true)
	sphere(self, Vector3(48, 2.5, 10), Vector3(12.0, 18.0, 11.0), Color("#c29ae0"), true)
	for i in range(2):
		var rider := Node3D.new()
		rider.position = Vector3(36.0 + i * 3.5, 0.4, -7.2 + i * 2.0)
		add_child(rider)
		sphere(rider, Vector3(0, 0.65, 0), Vector3(1.6, 0.9, 0.95), Color("#464d5c") if i == 0 else Color("#8a6852"), true)
		sphere(rider, Vector3(0, 1.45, 0), Vector3(0.5, 0.55, 0.5), Color("#58b9ff"), true)
		distant_riders.append(rider)

	spawn_ambient_motes(Vector3(4.0, 2.0, 0.0), Vector3(52.0, 3.4, 18.0), 30, Color("#fff5dc"), 0.10)
	spawn_ambient_motes(Vector3(11.5, 1.8, 0.0), Vector3(16.0, 2.4, 7.5), 18, Color("#ffb085"), 0.11)
	spawn_destructible_crate(Vector3(-19.0, 0.0, -1.8), 3)
	spawn_destructible_crate(Vector3(-9.5, 0.0, 4.2), 3)
	spawn_destructible_crate(Vector3(22.5, 0.0, -3.2), 4)

func _spawn_public_travelers() -> void:
	lantern_post(Vector3(3.8, 0.0, 3.6), 2.2, Color("#69c5ed"), -20.0)
	label_at(self, Vector3(3.8, 2.95, 3.6), "[ C ] 拉隊友", Color("#a8e6ff"), 26)

	var p1 := build_fellow_rider(Vector3(-19.5, 0, -2.8), Color("#58b9ff"), Color("#464b59"), Vector3(1.15, 0.90, 1.75), "阿狼")
	p1["waypoints"] = [Vector3(-19.5, 0, -2.8), Vector3(-17.8, 0, 2.8), Vector3(-21.0, 0, 3.2)]
	p1["wp_idx"] = 0
	p1["chat_t"] = 1.6
	p1["lines"] = ["共享光柱，一起刷！✨", "我幫你摸這隻！", "按 C 一起打哨長！"]
	public_travelers.append(p1)

	var p2 := build_fellow_rider(Vector3(-10.4, 0, -3.8), Color("#f28c5a"), Color("#7a5440"), Vector3(1.42, 1.12, 1.72), "蜜熊")
	p2["waypoints"] = [Vector3(-10.4, 0, -3.8), Vector3(-8.2, 0, 1.8), Vector3(-10.8, 0, 4.2)]
	p2["wp_idx"] = 0
	p2["chat_t"] = 2.8
	p2["lines"] = ["金色班長在這！", "噴金光柱了！✨", "重甲熊坦住！🛡️"]
	public_travelers.append(p2)

func on_coop_summon() -> void:
	if not coop_ally.is_empty():
		(coop_ally["bubble"] as Label3D).text = "交給我扛！🛡️"
		return
	var spawn_p := feet() + Vector3(-1.8, 0.0, 1.4)
	var puff := sphere(self, spawn_p + Vector3(0, 1.0, 0), Vector3(2.8, 2.2, 2.8), CLOUD_WHITE, true)
	var tw := create_tween()
	tw.tween_property(puff, "scale", Vector3(0.1, 0.1, 0.1), 0.50)
	tw.tween_callback(puff.queue_free)
	coop_ally = build_fellow_rider(spawn_p, Color("#ffd659"), Color("#8a5a3c"), Vector3(1.48, 1.18, 1.80), "★ 阿熊（助拳）", GOLD)
	(coop_ally["bubble"] as Label3D).text = "收到求救！我來扛！🛡️"
	show_player_emote("✉️", 1.4)

func _update_fellow_travelers(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for tr in public_travelers:
		var n: Node3D = tr["node"]
		var wps: Array = tr["waypoints"]
		var idx: int = int(tr["wp_idx"])
		var tgt: Vector3 = wps[idx]
		var diff := flat(tgt - n.position)
		if diff.length() < 0.6:
			tr["wp_idx"] = (idx + 1) % wps.size()
		else:
			n.position += diff.normalized() * 2.5 * delta
			n.rotation.y = atan2(diff.x, diff.z)
			n.position.y = absf(sin(t * 7.5 + float(idx))) * 0.10
		tr["chat_t"] = float(tr["chat_t"]) - delta
		if float(tr["chat_t"]) <= 0.0:
			tr["chat_t"] = 4.8
			var lines: Array = tr["lines"]
			(tr["bubble"] as Label3D).text = String(lines[randi() % lines.size()])

	if not coop_ally.is_empty():
		var an: Node3D = coop_ally["node"]
		var target_p := (boss.position + Vector3(-2.1, 0, 1.6)) if boss_active else (feet() + Vector3(-2.2, 0, 1.6))
		var d := flat(target_p - an.position)
		if d.length() > 0.7:
			an.position += d.normalized() * 6.2 * delta
			an.rotation.y = atan2(d.x, d.z)
			an.position.y = absf(sin(t * 9.0)) * 0.12
		else:
			an.position.y = sin(t * 2.5) * 0.03
		if boss_active:
			coop_attack_cd -= delta
			if coop_attack_cd <= 0.0 and flat(an.position - boss.position).length() < 3.5:
				coop_attack_cd = 2.1
				boss_hp = maxi(1, boss_hp - 1)
				flash_hit(boss)
				spawn_damage_pop(boss.position, "-1", Color("#a8e6ff"), false)
				(coop_ally["bubble"] as Label3D).text = "巨熊拍擊！🛡️"

func _spawn_poe_mobs() -> void:
	var spawns := [
		{"pos": Vector3(-18.5, 0.0, 2.8), "name": "發條巡邏兵", "hp": 3, "rare": false},
		{"pos": Vector3(-11.2, 0.0, -3.5), "name": "發條巡邏兵", "hp": 3, "rare": false},
		{"pos": Vector3(-8.2, 0.0, 2.8), "name": "★ 加班班長", "hp": 7, "rare": true},
		{"pos": Vector3(-17.8, 0.0, -4.2), "name": "發條巡邏兵", "hp": 3, "rare": false},
	]
	for sp in spawns:
		var node := Node3D.new()
		node.position = sp["pos"]
		add_child(node)
		var is_rare: bool = sp["rare"]
		var col := Color("#f5b82e") if is_rare else Color("#76879c")
		var scl := 1.35 if is_rare else 0.95
		node.scale = Vector3.ONE * scl
		cylinder(node, Vector3(0, 0.62, 0), 0.36, 0.44, 1.05, col)
		sphere(node, Vector3(0, 1.40, 0), Vector3(0.60, 0.58, 0.58), col.lightened(0.15))
		register_living_npc(node, 0.0, 0.06, 3.8)
		var lbl := label_at(node, Vector3(0, 2.12, 0), String(sp["name"]), GOLD if is_rare else Color("#e0ecff"), 26)
		mobs.append({
			"node": node, "label": lbl, "name": String(sp["name"]),
			"hp": int(sp["hp"]), "max_hp": int(sp["hp"]), "rare": is_rare, "alive": true,
		})

func _drop_loot(pos: Vector3, is_rare: bool) -> void:
	spawn_bouncing_coins(pos, 6 if is_rare else 3, 5)
	var item: Dictionary
	if is_rare:
		item = PrologueState.make_item("精銳斥候長劍", "weapon", "rare", 2)
		PrologueState.orb_gold += 1
	else:
		var r := "magic" if randi() % 2 == 0 else "normal"
		item = PrologueState.make_item("百年步兵短劍" if r == "normal" else "改裝巡邏短劍", "weapon", r, 1)
		PrologueState.orb_blue += 1
	var drop_node := Node3D.new()
	drop_node.position = pos + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	add_child(drop_node)
	var col := PrologueState.rarity_color(item["rarity"])
	cylinder(drop_node, Vector3(0, 1.9, 0), 0.08, 0.14, 3.8, col, true)
	sphere(drop_node, Vector3(0, 0.25, 0), Vector3(0.45, 0.32, 0.45), col, true)
	label_at(drop_node, Vector3(0, 1.15, 0), PrologueState.format_item_title(item), col, 26)
	pop_in_node(drop_node)
	loot_drops.append({"node": drop_node, "item": item, "pos": drop_node.position})

func _build_boss_and_chest() -> void:
	add_child(boss)
	boss.position = BOSS_HOME
	cylinder(boss, Vector3(0, 1.15, 0), 0.12, 0.14, 2.3, TIMBER)
	box(boss, Vector3(0, 1.35, 0), Vector3(1.9, 0.30, 0.30), TIMBER_LIGHT)
	sphere(boss, Vector3(0, 1.12, 0), Vector3(1.12, 1.22, 0.86), Color("#b58d52"))
	sphere(boss, Vector3(0, 2.0, 0), Vector3(0.78, 0.78, 0.78), Color("#e8c882"))
	boss_helmet = cylinder(boss, Vector3(0, 2.42, 0), 0.42, 0.48, 0.45, Color("#606a7a"))
	boss_straw_hat = cylinder(boss, Vector3(0, 2.42, 0), 0.28, 0.84, 0.26, GOLD)
	boss_straw_hat.hide()
	boss_hammer = box(boss, Vector3(-1.05, 1.35, 0.55), Vector3(0.45, 0.45, 1.45), TIMBER)
	boss_bubble = label_at(boss, Vector3(0, 3.35, 0), "", Color("#fff2cc"), 34)
	boss_cue = label_at(boss, Vector3(0, 2.88, 0), "稻草人哨長", Color("#ffd59e"), 28)
	attack_ring = marker(BOSS_HOME, STAMP_RED, 2.6)
	attack_ring.hide()

	add_child(chest)
	chest.position = BOSS_HOME + Vector3(-1.8, 0.0, 1.4)
	chest.rotation_degrees.y = 18.0
	box(chest, Vector3(0, 0.35, 0), Vector3(0.95, 0.65, 0.65), GOLD)
	box(chest, Vector3(0, 0.68, 0), Vector3(1.0, 0.18, 0.7), TIMBER)
	label_at(chest, Vector3(0, 1.25, 0), "軍需寶箱", GOLD, 28)
	chest.hide()

func _apply_persisted_state() -> void:
	if PrologueState.timber_broken and is_instance_valid(timber_barricade):
		timber_barricade.queue_free()
	if PrologueState.gate_opened:
		stone_gate.position.y = 4.0
		lever_handle.rotation.z = -0.7
		fog_bridge.hide()
	if PrologueState.boss_retired:
		boss_state = BossState.RETIRED
		boss_helmet.hide()
		boss_straw_hat.show()
		boss_hammer.hide()
		boss.position = TEA_STALL_POS + Vector3(0, 0, -0.75)
		boss_cue.text = "茶攤老闆"
		boss_cue.modulate = Color("#b8f5c8")
		tea_stall.show()
		chest.visible = not PrologueState.has_spring_saddle
	if PrologueState.high_chest_claimed:
		high_chest.hide()
	if vista_zoomed:
		fog_vista.hide()

func _clear_fog(fog_node: Node3D) -> void:
	if not fog_node.visible:
		return
	var tw := create_tween()
	tw.tween_property(fog_node, "scale", Vector3(2.4, 0.05, 2.4), 1.1)
	tw.tween_callback(fog_node.hide)

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_update_fellow_travelers(delta)
	if boss_talk_timer > 0.0:
		boss_talk_timer -= delta
		if boss_talk_timer <= 0.0:
			boss_bubble.text = ""
	for i in range(distant_riders.size()):
		var r := distant_riders[i]
		r.position.x = 34.0 + fmod(t * 1.8 * (1.0 + i * 0.25) + i * 5.0, 14.0)

	var cam_override := (VISTA_POS + Vector3(3.5, 0.0, -1.2)) if vista_zoomed else Vector3.INF
	if not step_shared_physics(delta, cam_override):
		return

	if not boss_active and boss_state == BossState.IDLE and not PrologueState.boss_retired and PrologueState.gate_opened and feet().x > BRIDGE_START_X + 1.2:
		_start_boss_encounter()
	if boss_active:
		_update_boss(delta)
	if PrologueState.boss_retired and not vista_zoomed and feet().x > 24.0:
		vista_zoomed = true
		default_cam_size = 24.0
		PrologueState.waypoint_road_unlocked = true
		_clear_fog(fog_vista)
		# Break 2.5D: Over-the-shoulder perspective scenic vista looking toward the pink/purple peaks & Emerald Stairway!
		play_cinematic_shot(Vector3(21.2, 3.2, 3.4), Vector3(44.0, 4.0, -3.0), 2.3, true, 52.0, true)
		spawn_flying_bird_flock(Vector3(31.0, 6.2, -5.0), Vector3(4.5, 0.3, 1.2), 6, Color("#fff7d6"))
		show_player_emote("✨", 2.5)
		show_subtitle("雲海散開了！遠方就是第一章《翡翠天梯古林》！", 3.5)
	if PrologueState.boss_retired and high_chest.visible:
		bird_alert_target = high_chest.position
	elif chest.visible:
		bird_alert_target = chest.position
	else:
		bird_alert_target = Vector3.INF
	_update_ui()

func update_wolf_follow(_delta: float) -> void:
	var target := player.position
	var stop_dist := 1.75
	if not PrologueState.gate_opened and player.position.x > WALL_X - 0.2 and wolf.position.x < WALL_X:
		target = Vector3(WALL_X - 1.8, 0, NARROW_SLIT_Z)
		stop_dist = 0.4
		wolf_emote.text = "?"
	elif PrologueState.gate_opened and absf(player.position.x - WALL_X) > 1.2 and (player.position.x - WALL_X) * (wolf.position.x - WALL_X) < 0.0:
		wolf_emote.text = ""
		var side := -1.0 if player.position.x > WALL_X else 1.0
		var aligned := absf(wolf.position.z - GATE_Z) < 0.65
		target = Vector3(WALL_X + (-side * 1.6 if aligned else side * 1.6), 0, GATE_Z)
		stop_dist = 0.2
	elif wolf_charge_timer > 0.0 and boss_active:
		wolf_emote.text = ""
		target = boss.position + Vector3(-1.3, 0, 0)
		stop_dist = 0.25
		if flat(wolf.position - boss.position).length() < 2.5 and boss_state == BossState.WINDUP:
			_interrupt_boss_with_wolf()
	else:
		wolf_emote.text = ""

	var diff := flat(target - wolf.position)
	var spd := 12.5 if wolf_charge_timer > 0.0 else 6.2
	move_body(wolf, diff.normalized() if diff.length() > stop_dist else Vector3.ZERO, spd)

func on_wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = wolf_charge_max
	wolf_charge_timer = 0.55
	if not PrologueState.timber_broken and PrologueState.mounted and flat(wolf.position - TIMBER_POS).length() < 5.2:
		PrologueState.timber_broken = true
		# Break 2.5D: Side-angle dynamic leap shot as Giant Wolf smashes the barricade (@amelicart This Way.jpg)!
		play_cinematic_shot(TIMBER_POS + Vector3(-1.5, 2.1, 7.6), TIMBER_POS + Vector3(0.5, 1.2, 0.0), 1.05, true, 44.0, true)
		wolf_visual.position.y = 0.85
		create_tween().tween_property(wolf_visual, "position:y", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		spawn_flying_bird_flock(TIMBER_POS + Vector3(0.5, 2.4, -2.0), Vector3(4.8, 1.4, -1.2), 4)
		spawn_wood_burst(TIMBER_POS, TIMBER_LIGHT, 10)
		if is_instance_valid(timber_barricade):
			timber_barricade.queue_free()
		hitstop_frames = 5
		shake_time = 0.24
		shake_strength = 0.24
		show_player_emote("✨", 1.2)
		return
	if boss_active:
		if PrologueState.mounted:
			toggle_mount()
		show_player_emote("!", 0.8)

func on_air_slam_land() -> void:
	_damage_nearby_mobs(PrologueState.get_total_atk() * 2, true)
	if high_chest.visible and flat(player.position - HIGH_LEDGE_POS).length() < 3.6:
		_claim_high_chest()

func _claim_high_chest() -> void:
	PrologueState.high_chest_claimed = true
	high_chest.hide()
	PrologueState.orb_gold += 2
	spawn_bouncing_coins(HIGH_LEDGE_POS, 6, 5)
	PrologueState.add_item_to_inventory(PrologueState.make_item("高台密藏戰術鞍", "saddle", "rare", 0))
	show_player_emote("✨", 1.8)
	show_subtitle("秘寶箱開啟！獲【黃裝】戰術鞍＋金漆罐 x2！", 4.0)

func on_interact() -> void:
	for i in range(loot_drops.size()):
		var d: Dictionary = loot_drops[i]
		if near(d["pos"], 2.3):
			PrologueState.add_item_to_inventory(d["item"])
			(d["node"] as Node3D).queue_free()
			loot_drops.remove_at(i)
			show_player_emote("✨", 1.1)
			show_subtitle("拾取：" + PrologueState.format_item_title(d["item"]), 2.8)
			return

	if near(WEST_EXIT, 2.8):
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_road", "雲丘市集")
		return
	if not PrologueState.gate_opened and not PrologueState.mounted and near(LEVER_POS, 2.1):
		PrologueState.gate_opened = true
		show_player_emote("!", 1.1)
		create_tween().tween_property(stone_gate, "position:y", 4.0, 0.45)
		create_tween().tween_property(lever_handle, "rotation:z", -0.7, 0.25)
		_clear_fog(fog_bridge)
		return
	if boss_state == BossState.KNEELED and near(boss.position, 3.0):
		_retire_boss()
		return
	if chest.visible and near(chest.position, 2.3):
		chest.hide()
		var spring := PrologueState.make_item("彈簧試驗鞍座", "saddle", "unique", 0, "spring_slam")
		PrologueState.equipped_saddle = spring
		PrologueState.has_spring_saddle = true
		wolf_spring_pad.show()
		show_player_emote("✨", 2.0)
		show_subtitle("裝備傳奇《彈簧試驗鞍座》！騎狼按 F 彈飛 200% 重劈！", 4.5)
		return
	if high_chest.visible and near(HIGH_LEDGE_POS, 2.6):
		_claim_high_chest()
		return
	if near(WAYPOINT_POS, 2.6):
		PrologueState.waypoint_road_unlocked = true
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_waypoint", "雲丘市集")
		return
	if near(BOUNTY_POS + Vector3(0, 0, 1.0), 2.5):
		show_player_emote("!", 1.4)
		show_subtitle("懸賞板：翡翠樹王／河神巨蟹／沙暴騎士長／霜龍大將軍", 4.2)
		return
	if near(CHAPTER_1_EXIT, 2.5):
		show_player_emote("✨", 1.4)
		show_subtitle("第一章《翡翠天梯古林》入口（序章通關！）", 3.5)

func _start_boss_encounter() -> void:
	boss_active = true
	boss_state = BossState.IDLE
	boss_timer = 1.2
	_boss_say("站住！前方魔王軍第三防線！", 2.8)
	show_player_emote("✉️", 1.8)

func _update_boss(delta: float) -> void:
	boss_timer -= delta
	match boss_state:
		BossState.IDLE:
			var toward := flat(feet() - boss.position)
			boss.rotation.y = atan2(toward.x, toward.z)
			boss_cue.text = "稻草人哨長"
			if boss_timer <= 0.0:
				boss_state = BossState.WINDUP
				boss_timer = 2.0
				attack_ring.position = boss.position + Vector3(0, 0.05, 0)
				attack_ring.show()
				boss_hammer.rotation_degrees.x = -75.0
				boss_cue.text = "紅光蓄力！按 [Q]"
				boss_cue.modulate = STAMP_RED
		BossState.WINDUP:
			if boss_timer <= 0.0:
				attack_ring.hide()
				boss_hammer.rotation_degrees.x = 25.0
				shake_time = 0.16
				shake_strength = 0.20
				if flat(feet() - boss.position).length() < 2.8:
					PrologueState.player_hp = maxi(1, PrologueState.player_hp - 1)
					show_player_emote("💦", 1.0)
				boss_state = BossState.IDLE
				boss_timer = 1.3
				boss_cue.modulate = Color("#ffd59e")
		BossState.STAGGERED:
			boss.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.24
			boss_cue.text = "破防踉蹌！"
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
	hitstop_frames = 6
	shake_time = 0.26
	shake_strength = 0.25
	flash_hit(boss)
	spawn_damage_pop(boss.position, "破防 STAGGER!", GOLD, true)
	_boss_say("嗚哇！哪來的斥候狼！", 2.2)

func _damage_nearby_mobs(base_dmg: int, is_crit: bool) -> void:
	for m in mobs:
		if not m["alive"]:
			continue
		var m_node: Node3D = m["node"]
		if flat(player.position - m_node.position).length() < 2.8:
			m["hp"] = maxi(0, int(m["hp"]) - base_dmg)
			hitstop_frames = 3
			shake_time = 0.08
			shake_strength = 0.14
			flash_hit(m_node)
			var push := flat(m_node.position - player.position).normalized() * 0.42
			m_node.position += push
			spawn_damage_pop(m_node.position, ("CRIT! %d" % base_dmg) if is_crit else "-%d" % base_dmg, GOLD if is_crit else Color.WHITE, is_crit)
			var lbl: Label3D = m["label"]
			lbl.text = "%s (%d/%d)" % [String(m["name"]), int(m["hp"]), int(m["max_hp"])]
			if int(m["hp"]) <= 0:
				m["alive"] = false
				var drop_pos := m_node.position
				m_node.queue_free()
				_drop_loot(drop_pos, bool(m["rare"]))

func on_sword_hit() -> void:
	var is_crit := randi() % 100 < PrologueState.get_total_crit()
	var dmg := PrologueState.get_total_atk() * (2 if is_crit else 1)
	_damage_nearby_mobs(dmg, is_crit)

	if boss_active and flat(player.position - boss.position).length() < 2.8:
		var total_dmg := dmg + (PrologueState.get_stagger_bonus() if boss_state == BossState.STAGGERED else 0)
		boss_hp = maxi(0, boss_hp - total_dmg)
		hitstop_frames = 3
		shake_time = 0.09
		shake_strength = 0.16
		flash_hit(boss)
		spawn_damage_pop(boss.position, ("CRIT! %d" % total_dmg) if is_crit else "-%d" % total_dmg, GOLD if (is_crit or boss_state == BossState.STAGGERED) else Color.WHITE, is_crit)
		if boss_hp <= 0:
			boss_active = false
			boss_state = BossState.KNEELED
			attack_ring.hide()
			boss.rotation.z = 0.0
			boss.position.y = -0.35
			boss_cue.text = "[ E ] 蓋退休章！"
			boss_cue.modulate = GOLD
			_boss_say("等等……那封停戰信是真的？", 3.5)

func on_projectile_hit(pos: Vector3) -> bool:
	var is_crit := randi() % 100 < PrologueState.get_total_crit()
	var dmg := PrologueState.get_total_atk() * (2 if is_crit else 1)
	for m in mobs:
		if not m["alive"]:
			continue
		var m_node: Node3D = m["node"]
		if flat(pos - m_node.position).length() < 1.35:
			m["hp"] = maxi(0, int(m["hp"]) - dmg)
			PrologueState.play_sfx("hit")
			flash_hit(m_node)
			spawn_damage_pop(m_node.position, ("CRIT! %d" % dmg) if is_crit else "-%d" % dmg, GOLD if is_crit else Color.WHITE, is_crit)
			var lbl: Label3D = m["label"]
			lbl.text = "%s (%d/%d)" % [String(m["name"]), int(m["hp"]), int(m["max_hp"])]
			if int(m["hp"]) <= 0:
				m["alive"] = false
				var drop_pos := m_node.position
				m_node.queue_free()
				_drop_loot(drop_pos, bool(m["rare"]))
			return true
	if boss_active and flat(pos - boss.position).length() < 1.65:
		var total_dmg := dmg + (PrologueState.get_stagger_bonus() if boss_state == BossState.STAGGERED else 0)
		boss_hp = maxi(0, boss_hp - total_dmg)
		PrologueState.play_sfx("hit")
		flash_hit(boss)
		spawn_damage_pop(boss.position, ("CRIT! %d" % total_dmg) if is_crit else "-%d" % total_dmg, GOLD if (is_crit or boss_state == BossState.STAGGERED) else Color.WHITE, is_crit)
		if boss_hp <= 0:
			boss_active = false
			boss_state = BossState.KNEELED
			attack_ring.hide()
			boss.rotation.z = 0.0
			boss.position.y = -0.35
			boss_cue.text = "[ E ] 蓋退休章！"
			boss_cue.modulate = GOLD
			_boss_say("等等……那封停戰信是真的？", 3.5)
		return true
	return false

func _retire_boss() -> void:
	PrologueState.boss_retired = true
	boss_state = BossState.RETIRED
	play_giant_retirement_stamp(boss.position)
	if not coop_ally.is_empty():
		PrologueState.coins += 30
		(coop_ally["bubble"] as Label3D).text = "恭喜勸退！+30¢ 🎉"
	show_player_emote("✨", 2.0)
	_boss_say("停戰百年了？！那我加班給誰看啊！", 4.5)
	var helm_tw := create_tween().set_parallel(true)
	helm_tw.tween_property(boss_helmet, "position:y", 6.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	helm_tw.tween_property(boss_helmet, "rotation_degrees:z", 540.0, 0.55)
	get_tree().create_timer(1.15).timeout.connect(func() -> void:
		boss_helmet.hide()
		boss_straw_hat.show()
		boss_hammer.hide()
		boss.position = TEA_STALL_POS + Vector3(0, 0, -0.75)
		boss.rotation.y = 0.0
		boss_cue.text = "茶攤老闆"
		boss_cue.modulate = Color("#b8f5c8")
		pop_in_node(tea_stall)
		pop_in_node(chest)
		_boss_say("軍需箱送你！我去泡茶囉！", 4.2)
	)

func _boss_say(words: String, duration := 3.2) -> void:
	boss_bubble.text = words
	boss_talk_timer = duration

func _update_ui() -> void:
	var step := "刷怪噴光柱 → 騎狼按 [Q] 撞碎巨木"
	if PrologueState.timber_broken and not PrologueState.gate_opened:
		step = "斬精英班長 → 鑽岩縫拉桿散霧"
	elif PrologueState.gate_opened and not PrologueState.boss_retired:
		step = "跨石橋勸退哨長（可按 [C] 拉隊友）"
	elif PrologueState.boss_retired and not PrologueState.has_spring_saddle:
		step = "開寶箱領《彈簧鞍》→ 去瞭望台"
	elif PrologueState.boss_retired:
		step = "騎狼按 [F] 彈飛奪高台秘寶！"
	set_zone_objective("雲海古道與石橋", step)
	update_status_line()

	if boss_active or boss_state == BossState.KNEELED:
		var badge := "警戒中"
		var bcol := Color("#ffd59e")
		if boss_state == BossState.WINDUP:
			badge = "紅光蓄力！按 [Q]"
			bcol = STAMP_RED
		elif boss_state == BossState.STAGGERED:
			badge = "破防踉蹌！"
			bcol = GOLD
		elif boss_state == BossState.KNEELED:
			badge = "按 [E] 蓋退休章"
			bcol = Color("#98ffbd")
		update_boss_bar(true, "稻草人哨長", boss_hp, MAX_BOSS_HP, badge, bcol)
	else:
		update_boss_bar(false, "", 0, MAX_BOSS_HP)

	for d in loot_drops:
		if near(d["pos"], 2.3):
			set_prompt("[ E ] 拾取：" + PrologueState.format_item_title(d["item"]))
			return

	if near(WEST_EXIT, 2.8):
		set_prompt("[ E ] 返回：雲丘市集")
	elif not PrologueState.gate_opened and not PrologueState.mounted and near(LEVER_POS, 2.1):
		set_prompt("[ E ] 拉桿開門散霧")
	elif boss_state == BossState.KNEELED and near(boss.position, 3.0):
		set_prompt("[ E ] 砸下【正式退休】紅章！")
	elif chest.visible and near(chest.position, 2.3):
		set_prompt("[ E ] 領取《彈簧試驗鞍座》")
	elif high_chest.visible and near(HIGH_LEDGE_POS, 2.6):
		set_prompt("[ E ] 開啟高台秘寶箱")
	elif near(WAYPOINT_POS, 2.6):
		set_prompt("[ E ] 驛站快傳回市集")
	elif near(BOUNTY_POS + Vector3(0, 0, 1.0), 2.5):
		set_prompt("[ E ] 檢視公會懸賞板")
	elif near(CHAPTER_1_EXIT, 2.5):
		set_prompt("[ E ] 第一章入口")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼")
	else:
		set_prompt("")

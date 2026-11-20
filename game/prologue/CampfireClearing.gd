extends "res://prologue/PrologueBase.gd"

const CAMPFIRE_POS := Vector3(0.0, 0.0, 0.0)
const LOG_JOURNAL_POS := Vector3(2.2, 0.0, -0.5)
const SKULL_CAVE_POS := Vector3(-7.6, 0.0, -4.4)
const EXIT_TO_TOWN := Vector3(16.5, 0.0, -1.2)

var campfire_flame: MeshInstance3D
var campfire_smoke: MeshInstance3D
var skull_lantern: MeshInstance3D
var title_overlay: Control
var start_pill: PanelContainer

# 10-Second Visual Hook: Lost Overtime Clockwork Grunt right next to camp!
var lost_grunt: Node3D
var grunt_helmet: MeshInstance3D
var grunt_hat: MeshInstance3D
var grunt_bubble: Label3D
var grunt_hp := 2
var grunt_retired := false
var camp_loot_node: Node3D
var camp_loot_item: Dictionary = {}

func _ready() -> void:
	can_attack = true
	scene_shadow_tint = Color("#243359")
	set_wind_profile(Vector2(0.88, 0.45), 0.95, 0.24, 0.14)
	_build_map()
	var spawn := Vector3(14.0, 0.0, -1.2) if PrologueState.spawn_tag == "from_town" else Vector3(0.8, 0.0, 0.5)
	setup_core_trio(spawn)
	setup_camera_and_lighting(15.2, Color("#0e172a"), Color("#3e5d94"), 0.64, Color("#6e94d4"), 0.42, Color("#08122b"), Color("#244970"), Color("#0e1b33"))
	setup_hud()

	if not PrologueState.has_started:
		input_locked = true
		set_hud_visible(false)
		# Break 2.5D ortho into @amelicart low-angle lakeside campfire storybook cover!
		wolf_visual.scale = Vector3(1.06, 0.72, 1.06)
		player.rotation.y = deg_to_rad(-28.0)
		set_cinematic_pose(Vector3(0.4, 2.35, 8.8), Vector3(-0.6, 1.35, -1.6), true, 48.0, true)
		_build_title_overlay()
	_update_ui()

func _build_map() -> void:
	# Expanded 38m x 24m Forest Camp Diorama (Little Joy x @amelicart)
	organic_mound(self, Vector3(-1.0, -0.54, -0.8), 18.5, 11.8, 1.08, NIGHT_GRASS, -5.0)
	organic_mound(self, Vector3(11.8, -0.50, -1.2), 9.2, 7.2, 1.0, NIGHT_GRASS_LIGHT, 14.0)
	organic_mound(self, Vector3(-9.5, -0.48, -3.5), 8.8, 6.8, 1.0, NIGHT_GRASS_LIGHT, -16.0)
	organic_mound(self, Vector3(6.5, -0.49, 6.2), 7.8, 5.4, 1.0, NIGHT_GRASS, 10.0)

	# Warm campfire clearing & picnic rug
	organic_mound(self, Vector3(0.1, 0.008, -0.05), 4.8, 4.1, 0.03, Color("#c98f55"), 10.0)
	organic_mound(self, Vector3(0.0, 0.016, 0.0), 2.9, 2.5, 0.025, Color("#db9e5d"), -14.0)
	var rug := box(self, Vector3(1.55, 0.025, 0.65), Vector3(1.55, 0.03, 1.05), Color("#c95a4b"))
	rug.rotation_degrees.y = -24.0
	var rug_trim := box(self, Vector3(1.55, 0.028, 0.65), Vector3(1.25, 0.03, 0.78), Color("#f5d69b"))
	rug_trim.rotation_degrees.y = -24.0

	# Winding trail crossing wooden footbridge over the forest stream to Town!
	curved_path([
		Vector3(2.2, 0.0, -0.2),
		Vector3(5.6, 0.0, 0.6),
		Vector3(9.4, 0.0, -0.4),
		Vector3(13.2, 0.0, -1.0),
		EXIT_TO_TOWN
	], 2.2, TRAIL, TRAIL_STONE)
	curved_path([Vector3(-2.5, 0.0, -1.4), Vector3(-5.2, 0.0, -3.0), SKULL_CAVE_POS], 1.7, TRAIL_STONE)

	# Winding turquoise forest stream with white ripple rings + waterfall + wooden footbridge!
	curved_stream([
		Vector3(-15.5, 0.0, 4.2),
		Vector3(-9.5, 0.0, 6.8),
		Vector3(-2.0, 0.0, 8.0),
		Vector3(5.5, 0.0, 6.4),
		Vector3(9.2, 0.0, 1.2),
		Vector3(11.4, 0.0, -6.5)
	], 3.1, Color("#296bb0"), Color("#b8ecff"), -0.14)
	waterfall_cascade(Vector3(-12.5, 0.0, 4.6), 2.4, 3.6, 35.0, Color("#4ea4f5"), Color("#dcf6ff"))
	wooden_footbridge(Vector3(9.0, 0.0, -0.2), 4.2, 2.2, 12.0, 0.44)
	wooden_footbridge(Vector3(3.2, 0.0, 7.1), 3.6, 1.9, 95.0, 0.36)

	# Cozy lakeside fishing pier + rod & bucket
	var pier := Node3D.new()
	pier.position = Vector3(-2.6, 0.16, 4.9)
	pier.rotation_degrees.y = -12.0
	add_child(pier)
	box(pier, Vector3(0, 0, 0.55), Vector3(1.5, 0.14, 2.2), BOARDWALK)
	cylinder(pier, Vector3(-0.6, -0.2, 1.4), 0.08, 0.09, 0.7, TIMBER)
	cylinder(pier, Vector3(0.6, -0.2, 1.4), 0.08, 0.09, 0.7, TIMBER)
	var rod := cylinder(pier, Vector3(0.35, 0.65, 1.35), 0.02, 0.04, 1.85, TIMBER_LIGHT)
	rod.rotation_degrees = Vector3(52.0, 0.0, -8.0)
	cylinder(pier, Vector3(-0.35, 0.22, 0.9), 0.18, 0.15, 0.34, STONE_LIGHT)
	spawn_destructible_crate(Vector3(-3.8, 0.0, 2.2), 3)
	spawn_destructible_crate(Vector3(6.2, 0.0, 3.8), 3)

	# Cliff outcrops & dense perimeter pine/rounded tree grove
	cliff_outcrop(Vector3(-14.5, 0.0, 3.2), 2.8, 2.4, 2.6, STONE, NIGHT_GRASS_LIGHT, 20.0)
	cliff_outcrop(Vector3(-13.8, 0.0, -7.2), 3.2, 2.6, 2.8, STONE_LIGHT, NIGHT_GRASS, -15.0)
	cliff_outcrop(Vector3(14.5, 0.0, -6.8), 2.9, 2.2, 2.4, STONE, NIGHT_GRASS_LIGHT, 25.0)

	# Expanded 54m x 38m Walkable Forest Camp & Exploration Glades + 360 Night Panorama!
	organic_mound(self, Vector3(-16.5, -0.52, 2.5), 11.5, 9.8, 1.04, NIGHT_GRASS, -12.0)
	organic_mound(self, Vector3(-3.5, -0.52, 13.0), 11.2, 7.6, 1.04, NIGHT_GRASS_LIGHT, 8.0)
	organic_mound(self, Vector3(17.2, -0.52, -8.5), 9.6, 7.8, 1.04, NIGHT_GRASS_LIGHT, -10.0)
	curved_path([Vector3(-6.2, 0, -2.5), Vector3(-13.5, 0, 0.4), Vector3(-19.5, 0, 1.8)], 1.8, TRAIL_STONE)
	curved_path([Vector3(3.2, 0, 7.1), Vector3(0.5, 0, 11.4), Vector3(-4.2, 0, 13.0)], 1.8, TRAIL)
	curved_path([Vector3(12.2, 0, -2.2), Vector3(15.5, 0, -6.2), Vector3(18.5, 0, -10.2)], 1.7, TRAIL_STONE)
	stone_archway(Vector3(-18.8, 0.0, 1.8), 78.0, 1.05, true)
	cozy_cabin(Vector3(-5.8, 0.0, 13.2), 26.0, Color("#c9583e"), TIMBER_LIGHT)
	lantern_post(Vector3(-17.0, 0.0, 3.6), 2.3, MIST_CYAN, 18.0)
	lantern_post(Vector3(-1.5, 0.0, 11.5), 2.3, FIRE_ORANGE, -14.0)
	spawn_destructible_crate(Vector3(-20.5, 0.0, 4.2), 4)
	spawn_destructible_crate(Vector3(-1.2, 0.0, 14.5), 4)
	spawn_destructible_crate(Vector3(18.0, 0.0, -9.8), 4)
	build_horizon_panorama(Vector3(0.0, 0.0, 0.0), 27.0, 19.0, "night_forest")
	# Wind-blown @amelicart night grass & glowing wildflowers (580 tufts via MultiMesh)
	spawn_wind_grass_meadow(Vector3(-4.0, 0, -2.5), 11.5, 6.2, 200, NIGHT_GRASS, Color("#4f8091"), Color("#8ad6f5"), 0.16, 0.95)
	spawn_wind_grass_meadow(Vector3(-16.5, 0, 2.5), 9.5, 7.5, 140, NIGHT_GRASS, Color("#48788a"), Color("#f2d085"), 0.18, 1.0)
	spawn_wind_grass_meadow(Vector3(-3.5, 0, 13.0), 9.2, 5.6, 120, NIGHT_GRASS_LIGHT, Color("#5c9499"), Color("#e88ba7"), 0.20, 1.0)
	spawn_wind_grass_meadow(Vector3(14.5, 0, -5.5), 8.2, 6.4, 120, NIGHT_GRASS_LIGHT, Color("#568c94"), Color("#ffe38a"), 0.18, 0.95)

	invisible_boundary_wall(Vector3(-26.5, 0.8, 0.0), Vector3(0.8, 1.8, 38.0))
	invisible_boundary_wall(Vector3(26.5, 0.8, 0.0), Vector3(0.8, 1.8, 38.0))
	invisible_boundary_wall(Vector3(0.0, 0.8, -18.2), Vector3(54.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(0.0, 0.8, 18.4), Vector3(54.0, 1.8, 0.8))

	for i in range(9):
		var ang := i * TAU / 9.0 + 0.15
		var rad := 0.72 + sin(float(i) * 2.1) * 0.08
		sphere(self, CAMPFIRE_POS + Vector3(cos(ang) * rad, 0.14, sin(ang) * rad), Vector3(0.30, 0.22, 0.28), STONE_LIGHT if i % 2 == 0 else STONE)
	campfire_flame = cylinder(self, CAMPFIRE_POS + Vector3(0, 0.38, 0), 0.05, 0.34, 0.78, FIRE_ORANGE, true)
	campfire_smoke = sphere(self, CAMPFIRE_POS + Vector3(0.05, 1.55, 0), Vector3(0.38, 0.65, 0.38), Color("#d4ecf0"), true)
	for a_deg in [-28.0, 92.0, 212.0]:
		var rad_a := deg_to_rad(a_deg)
		var stick := cylinder(self, CAMPFIRE_POS + Vector3(cos(rad_a) * 0.45, 0.72, sin(rad_a) * 0.45), 0.04, 0.05, 1.65, TIMBER)
		stick.rotation_degrees = Vector3(sin(rad_a) * 22.0, 0.0, -cos(rad_a) * 22.0)
	sphere(self, CAMPFIRE_POS + Vector3(0, 0.92, 0), Vector3(0.42, 0.34, 0.42), Color("#3b4454"))
	# Shimmering orange campfire reflection strips on the southern lake water (@amelicart Image 1)
	for ri in range(4):
		var refl := box(self, Vector3(0.1, -0.10, 6.2 + float(ri) * 0.65), Vector3(0.85 - float(ri) * 0.12, 0.03, 0.32), FIRE_ORANGE if ri % 2 == 0 else GOLD, false, true)
		water_ripples.append({"node": refl, "phase": float(ri) * 1.1})
	var light := OmniLight3D.new()
	light.light_color = Color("#ffa047")
	light.light_energy = 5.4
	light.omni_range = 14.0
	light.position = CAMPFIRE_POS + Vector3(0, 1.35, 0)
	add_child(light)

	var sit_log := cylinder(self, CAMPFIRE_POS + Vector3(1.95, 0.27, -0.45), 0.27, 0.31, 2.0, TIMBER)
	sit_log.rotation_degrees = Vector3(0, 28, 90)
	var journal := box(self, LOG_JOURNAL_POS + Vector3(-0.05, 0.56, -0.05), Vector3(0.46, 0.12, 0.34), Color("#e67ca8"))
	journal.rotation_degrees.y = -18.0
	lantern_post(Vector3(-2.1, 0.0, 1.4), 2.3, FIRE_ORANGE, 22.0)
	lantern_post(Vector3(12.8, 0.0, -2.5), 2.4, FIRE_ORANGE, -15.0)

	# Mossy Ancient Skull Cavern nestled into NW cliff glade
	var skull := Node3D.new()
	skull.position = SKULL_CAVE_POS + Vector3(-0.6, 0.0, -1.6)
	skull.rotation_degrees.y = 26.0
	add_child(skull)
	sphere(skull, Vector3(0, 1.85, 0), Vector3(3.5, 2.9, 2.7), STONE_LIGHT)
	sphere(skull, Vector3(0, 2.85, -0.1), Vector3(3.2, 1.25, 2.6), Color("#466e40"))
	sphere(skull, Vector3(-0.75, 1.75, 1.18), Vector3(0.75, 0.85, 0.5), Color("#151926"), true)
	sphere(skull, Vector3(0.75, 1.75, 1.18), Vector3(0.75, 0.85, 0.5), Color("#151926"), true)
	box(skull, Vector3(0, 0.65, 1.08), Vector3(1.5, 1.3, 0.6), Color("#151926"), false, true)
	skull_lantern = sphere(skull, Vector3(1.05, 1.15, 1.28), Vector3(0.38, 0.38, 0.38), FIRE_ORANGE, true)
	skull_lantern.visible = PrologueState.boss_retired
	marker(SKULL_CAVE_POS, Color("#88d4ff") if not PrologueState.boss_retired else GOLD, 0.58)

	if PrologueState.boss_retired:
		cylinder(self, LOG_JOURNAL_POS + Vector3(-0.45, 0.25, 0.65), 0.2, 0.24, 0.35, Color("#6ec25a"))

	# 10-Second Visual Hook: Lost Overtime Grunt right beside campfire!
	lost_grunt = Node3D.new()
	lost_grunt.position = Vector3(3.6, 0.0, 0.8)
	add_child(lost_grunt)
	cylinder(lost_grunt, Vector3(0, 0.55, 0), 0.34, 0.42, 0.95, Color("#76879c"))
	sphere(lost_grunt, Vector3(0, 1.28, 0), Vector3(0.56, 0.54, 0.56), Color("#a6b6c9"))
	grunt_helmet = cylinder(lost_grunt, Vector3(0, 1.62, 0), 0.32, 0.38, 0.32, Color("#4c5666"))
	grunt_hat = cylinder(lost_grunt, Vector3(0, 1.64, 0), 0.20, 0.62, 0.22, GOLD)
	grunt_hat.hide()
	grunt_bubble = label_at(lost_grunt, Vector3(0, 2.25, 0), "加班巡邏中！💢", Color("#ffd59e"), 30)
	register_living_npc(lost_grunt, 0.0, 0.08, 5.2)

	if not PrologueState.campfire_dish.is_empty():
		grunt_retired = true
		grunt_hp = 0
		grunt_helmet.hide()
		grunt_hat.show()
		lost_grunt.position = Vector3(-1.35, 0.0, -0.55)
		grunt_bubble.text = "烤魚香噴噴♪"
		grunt_bubble.modulate = Color("#b8ffd0")

	for bp in [
		[Vector3(-12.5, 0, -2.5), 1.3, 18.0], [Vector3(-10.8, 0, 1.8), 1.1, -24.0],
		[Vector3(-2.4, 0, -7.2), 1.2, 35.0], [Vector3(4.6, 0, -6.4), 1.1, -15.0],
		[Vector3(13.8, 0, 4.2), 1.2, 42.0]
	]:
		boulder_cluster(bp[0], float(bp[1]), STONE, true, true, float(bp[2]))

	for tp in [
		[Vector3(-15.8, 0, -5.2), 1.4, PINE_DARK], [Vector3(-11.4, 0, -8.5), 1.3, PINE_DARK],
		[Vector3(-4.2, 0, -8.8), 1.25, PINE_TEAL], [Vector3(2.2, 0, -7.8), 1.2, PINE_DARK],
		[Vector3(7.6, 0, -7.4), 1.35, PINE_TEAL], [Vector3(15.2, 0, -5.8), 1.25, PINE_DARK],
		[Vector3(-15.2, 0, 8.5), 1.3, PINE_DARK], [Vector3(-6.2, 0, 9.2), 1.2, PINE_TEAL],
		[Vector3(6.8, 0, 8.8), 1.3, PINE_DARK], [Vector3(15.6, 0, 6.2), 1.25, PINE_TEAL]
	]:
		pine_tree(tp[0], float(tp[1]), tp[2])
	for cp in [
		[Vector3(-6.2, 0, 3.1), 0.9, Color("#2b4d5e"), 7.0],
		[Vector3(4.8, 0, 3.2), 0.85, Color("#355c6e"), -6.0],
		[Vector3(12.2, 0, 2.8), 0.95, Color("#2f596b"), 5.0]
	]:
		cozy_tree(cp[0], float(cp[1]), cp[2], float(cp[3]))

	flower_patch(Vector3(-3.0, 0, 2.2), 8, [Color("#77b8e8"), Color("#f2d085"), Color("#e88ba7")], 2.0)
	flower_patch(Vector3(4.2, 0, -3.2), 7, [Color("#8ad6f5"), Color("#f7d97e")], 1.8)
	flower_patch(Vector3(12.8, 0, 0.8), 7, [Color("#f5c65b"), Color("#e88ba7")], 1.8)

	# Soft diagonal moonlight/aurora sunbeams & glowing mist
	sunbeam_shaft(Vector3(-3.5, 0.0, -2.5), 2.8, 18.0, Color(0.45, 0.88, 1.0, 0.08))
	sunbeam_shaft(Vector3(6.0, 0.0, -1.0), 3.2, 18.0, Color(1.0, 0.84, 0.55, 0.08))
	for mx in [-11.0, -2.0, 5.5]:
		sphere(self, Vector3(mx, 3.0, -11.5), Vector3(3.2, 5.8, 2.4), MIST_CYAN, true)
	sphere(self, Vector3(19.5, 2.4, -1.2), Vector3(3.6, 5.2, 3.8), Color("#ffd299"), true)

	spawn_ambient_motes(Vector3(1.0, 1.6, -0.5), Vector3(28.0, 3.0, 14.0), 26, Color("#ffe38a"), 0.09)
	transition_signpost(EXIT_TO_TOWN, "→ 雲丘市集", GOLD, -18.0)

func _build_title_overlay() -> void:
	title_overlay = Control.new()
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(title_overlay)

	var title_card := PanelContainer.new()
	title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_card.offset_left = -210
	title_card.offset_right = 210
	title_card.offset_top = 46
	title_card.offset_bottom = 148
	title_card.add_theme_stylebox_override("panel", make_panel_style(Color(0.08, 0.12, 0.24, 0.72), UI_ACCENT_GOLD, 22, 2, 22, 12))
	title_overlay.add_child(title_card)

	var tb := VBoxContainer.new()
	tb.alignment = BoxContainer.ALIGNMENT_CENTER
	tb.add_theme_constant_override("separation", 4)
	title_card.add_child(tb)

	var main_t := _styled_label("《補簽遠行》", 38, Color("#fff5d6"), true)
	main_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(main_t)
	var sub_t := _styled_label("After the Ceasefire", 14, Color("#b8dcf5"), false)
	sub_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(sub_t)

	start_pill = PanelContainer.new()
	start_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	start_pill.offset_left = -150
	start_pill.offset_right = 150
	start_pill.offset_top = -98
	start_pill.offset_bottom = -50
	start_pill.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_ACCENT_GOLD, 24, 2, 18, 8))
	title_overlay.add_child(start_pill)

	var hint := _styled_label("[ Space / 點擊 ] 醒來出發", 17, UI_INK, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_pill.add_child(hint)

func on_map_input(event: InputEvent) -> bool:
	if not PrologueState.has_started:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			PrologueState.has_started = true
			input_locked = false
			set_hud_visible(true)
			# Wake-up animation: wolf stretches upright, birds fly past, camera returns to 2.5D!
			create_tween().tween_property(wolf_visual, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			player_visual.position.y = 0.45
			create_tween().tween_property(player_visual, "position:y", 0.0, 0.25)
			spawn_flying_bird_flock(Vector3(-8.0, 4.8, -5.0), Vector3(4.2, 0.35, -0.8), 5)
			exit_cinematic_shot()
			if title_overlay:
				var tw := create_tween()
				tw.tween_property(title_overlay, "modulate:a", 0.0, 0.35)
				tw.tween_callback(title_overlay.queue_free)
			show_player_emote("!", 1.3)
			return true
	return false

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	campfire_flame.scale.y = 0.92 + sin(t * 11.0) * 0.14
	campfire_smoke.position.y = 1.45 + fmod(t * 0.55, 1.2)
	campfire_smoke.position.x = sin(t * 2.2) * 0.22
	if start_pill and is_instance_valid(start_pill):
		start_pill.modulate.a = 0.78 + sin(t * 4.5) * 0.22
	if not PrologueState.has_started and cinematic_active:
		cinematic_cam_pos = Vector3(0.4 + sin(t * 0.45) * 0.55, 2.35 + sin(t * 0.7) * 0.08, 8.8)
	if not step_shared_physics(delta):
		return
	if camp_loot_node and is_instance_valid(camp_loot_node):
		bird_alert_target = camp_loot_node.position
	elif PrologueState.boss_retired and not PrologueState.skull_gift_claimed:
		bird_alert_target = SKULL_CAVE_POS
	else:
		bird_alert_target = Vector3.INF
	_update_ui()

func _retire_camp_grunt() -> void:
	if grunt_retired:
		return
	grunt_retired = true
	grunt_hp = 0
	var g_pos := lost_grunt.position
	play_giant_retirement_stamp(g_pos)
	camp_loot_item = PrologueState.make_item("迷路兵的備用短劍", "weapon", "magic", 1)
	camp_loot_node = Node3D.new()
	camp_loot_node.position = g_pos + Vector3(0.6, 0.0, 0.5)
	add_child(camp_loot_node)
	var col := PrologueState.rarity_color("magic")
	cylinder(camp_loot_node, Vector3(0, 1.9, 0), 0.08, 0.14, 3.8, col, true)
	sphere(camp_loot_node, Vector3(0, 0.25, 0), Vector3(0.45, 0.32, 0.45), col, true)
	label_at(camp_loot_node, Vector3(0, 1.15, 0), "[藍] 迷路兵短劍", col, 26)
	pop_in_node(camp_loot_node)

	grunt_bubble.text = "停戰百年了?! 我去烤魚！"
	grunt_bubble.modulate = Color("#b8ffd0")
	PrologueState.campfire_dish = "烤魚"
	PrologueState.player_hp = 5
	PrologueState.flask_charges = 2
	get_tree().create_timer(0.65).timeout.connect(func() -> void:
		if is_instance_valid(grunt_helmet):
			grunt_helmet.hide()
		if is_instance_valid(grunt_hat):
			grunt_hat.show()
		if is_instance_valid(lost_grunt):
			create_tween().tween_property(lost_grunt, "position", Vector3(-1.35, 0.0, -0.55), 0.55)
	)
	show_subtitle("迷路小兵原地退休幫你烤魚（攻擊 +1）並噴出第一道藍光柱！", 3.6)

func on_sword_hit() -> void:
	if not grunt_retired and is_instance_valid(lost_grunt) and flat(player.position - lost_grunt.position).length() < 2.8:
		grunt_hp = maxi(0, grunt_hp - PrologueState.get_total_atk())
		hitstop_frames = 3
		shake_time = 0.09
		shake_strength = 0.14
		PrologueState.play_sfx("hit")
		flash_hit(lost_grunt)
		spawn_damage_pop(lost_grunt.position, "-%d" % PrologueState.get_total_atk(), GOLD, grunt_hp <= 0)
		var push := flat(lost_grunt.position - player.position).normalized() * 0.45
		lost_grunt.position += push
		if grunt_hp <= 0:
			_retire_camp_grunt()

func on_projectile_hit(pos: Vector3) -> bool:
	if not grunt_retired and is_instance_valid(lost_grunt) and flat(pos - lost_grunt.position).length() < 1.3:
		grunt_hp = maxi(0, grunt_hp - PrologueState.get_total_atk())
		PrologueState.play_sfx("hit")
		flash_hit(lost_grunt)
		spawn_damage_pop(lost_grunt.position, "-%d" % PrologueState.get_total_atk(), GOLD, grunt_hp <= 0)
		if grunt_hp <= 0:
			_retire_camp_grunt()
		return true
	return false

func on_wolf_action() -> void:
	super.on_wolf_action()
	if not grunt_retired and is_instance_valid(lost_grunt) and flat(feet() - lost_grunt.position).length() < 4.5:
		spawn_damage_pop(lost_grunt.position, "撞飛退休!", GOLD, true)
		_retire_camp_grunt()

func on_interact() -> void:
	if camp_loot_node and is_instance_valid(camp_loot_node) and near(camp_loot_node.position, 2.3):
		PrologueState.add_item_to_inventory(camp_loot_item)
		camp_loot_node.queue_free()
		camp_loot_node = null
		show_player_emote("✨", 1.2)
		show_subtitle("拾取 [藍] 迷路兵的備用短劍！（按 [I] 穿戴或造裝）", 3.2)
		return
	if near(EXIT_TO_TOWN, 2.8):
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_campfire", "雲丘市集")
	elif near(CAMPFIRE_POS, 2.1):
		PrologueState.player_hp = 5
		PrologueState.flask_charges = 2
		PrologueState.campfire_dish = "烤魚"
		PrologueState.play_sfx("heal")
		show_player_emote("✨", 1.4)
		show_subtitle("烤魚水壺已裝滿！（滿血＋水壺 x2＋攻擊 +1）", 2.8)
	elif near(LOG_JOURNAL_POS, 2.0):
		show_player_emote("✨", 1.2)
		show_subtitle("繪本旅記：已勸退 1 名迷路小兵" + ("、稻草人哨長" if PrologueState.boss_retired else ""), 3.2)
	elif near(SKULL_CAVE_POS, 2.8):
		if not PrologueState.boss_retired:
			show_player_emote("?", 1.4)
			show_subtitle("骷髏洞內傳來「呼嚕……」（退休亡靈午睡中）", 3.0)
		elif not PrologueState.skull_gift_claimed:
			PrologueState.skull_gift_claimed = true
			PrologueState.orb_gold += 2
			spawn_bouncing_coins(SKULL_CAVE_POS, 4, 5)
			show_player_emote("✨", 1.8)
			show_subtitle("亡靈謝卡：「外面安靜多啦！」獲《百年金漆罐》x2！", 4.0)
		else:
			show_player_emote("✨", 1.2)
			show_subtitle("骷髏洞字條：「勸退四大 Boss 後再來找我！」", 3.0)

func _update_ui() -> void:
	var goal := "左鍵/J 或 Q 勸退迷路加班兵！" if not grunt_retired else "撿起藍光柱，過木橋往東去雲丘市集"
	set_zone_objective("湖畔營火窩", goal)
	update_status_line()
	if not PrologueState.has_started:
		set_prompt("")
		return
	if camp_loot_node and is_instance_valid(camp_loot_node) and near(camp_loot_node.position, 2.3):
		set_prompt("[ E ] 拾取藍光柱裝備")
	elif near(EXIT_TO_TOWN, 2.8):
		set_prompt("[ E ] 前往：雲丘市集")
	elif near(CAMPFIRE_POS, 2.1):
		set_prompt("[ E ] 烤魚水壺（滿血 +1攻）")
	elif near(LOG_JOURNAL_POS, 2.0):
		set_prompt("[ E ] 翻閱繪本旅記")
	elif near(SKULL_CAVE_POS, 2.8):
		set_prompt("[ E ] 查看骷髏洞")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼")
	else:
		set_prompt("")

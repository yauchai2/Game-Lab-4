extends "res://prologue/PrologueBase.gd"

const CAMPFIRE_POS := Vector3(0.0, 0.0, 0.0)
const LOG_JOURNAL_POS := Vector3(2.1, 0.0, -0.4)
const SKULL_CAVE_POS := Vector3(-4.6, 0.0, -2.0)
const EXIT_TO_TOWN := Vector3(9.4, 0.0, -0.6)

var campfire_flame: MeshInstance3D
var campfire_smoke: MeshInstance3D
var skull_lantern: MeshInstance3D
var title_overlay: Control
var start_pill: PanelContainer

func _ready() -> void:
	can_attack = false
	_build_map()
	var spawn := Vector3(7.4, 0.0, -0.6) if PrologueState.spawn_tag == "from_town" else Vector3(0.75, 0.0, 0.45)
	setup_core_trio(spawn)
	setup_camera_and_lighting(13.8, Color("#0f182c"), Color("#3e5d94"), 0.62, Color("#6e94d4"), 0.40)
	setup_hud()

	if not PrologueState.has_started:
		input_locked = true
		set_hud_visible(false)
		_build_title_overlay()
	else:
		show_subtitle("深藍夜林營火窩｜可烹煮烤魚灌入水壺、翻閱繪本旅記，或探查西北角骷髏洞。", 4.0)
	_update_ui()

func _build_map() -> void:
	# Organic layered crescent lakeside glade (zero rectangular floor!)
	organic_mound(self, Vector3(-0.5, -0.52, -0.4), 12.2, 7.6, 1.04, NIGHT_GRASS, -6.0)
	organic_mound(self, Vector3(6.8, -0.50, -0.7), 6.2, 4.4, 1.0, NIGHT_GRASS_LIGHT, 12.0)
	organic_mound(self, Vector3(-5.2, -0.48, -2.2), 5.6, 4.2, 1.0, NIGHT_GRASS_LIGHT, -18.0)
	# Warm glowing earth circle & hand-woven picnic rug around campfire
	organic_mound(self, Vector3(0.1, 0.008, -0.05), 4.4, 3.8, 0.03, Color("#c98f55"), 10.0)
	organic_mound(self, Vector3(0.0, 0.016, 0.0), 2.7, 2.4, 0.025, Color("#db9e5d"), -14.0)
	var rug := box(self, Vector3(1.55, 0.025, 0.65), Vector3(1.55, 0.03, 1.05), Color("#c95a4b"))
	rug.rotation_degrees.y = -24.0
	var rug_trim := box(self, Vector3(1.55, 0.028, 0.65), Vector3(1.25, 0.03, 0.78), Color("#f5d69b"))
	rug_trim.rotation_degrees.y = -24.0

	# Curved winding forest trail to Cloudhill Town
	curved_path([
		Vector3(2.2, 0.0, -0.2),
		Vector3(4.5, 0.0, 0.55),
		Vector3(7.0, 0.0, -0.25),
		Vector3(9.8, 0.0, -0.65)
	], 2.1, TRAIL, TRAIL_STONE)

	# Curved dark-indigo lake along the south shore with warm fire reflection
	organic_mound(self, Vector3(0.0, -0.32, 6.2), 14.5, 4.2, 0.45, Color("#212046"), 4.0, true)
	organic_mound(self, Vector3(-0.1, -0.09, 5.1), 1.3, 2.2, 0.02, Color("#de783a"), -5.0, true)
	organic_mound(self, Vector3(0.15, -0.08, 6.4), 0.85, 1.1, 0.02, Color("#f29d4b"), 8.0, true)

	# Soft invisible perimeter backed by organic mossy boulders & leaning pines (no visible straight walls!)
	invisible_boundary_wall(Vector3(-10.8, 0.8, 0.0), Vector3(0.8, 1.8, 14.0))
	invisible_boundary_wall(Vector3(11.4, 0.8, 0.0), Vector3(0.8, 1.8, 14.0))
	invisible_boundary_wall(Vector3(0.0, 0.8, -6.2), Vector3(23.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(0.0, 0.8, 4.2), Vector3(23.0, 1.8, 0.8))

	# Campfire ring + wooden cooking tripod & kettle
	for i in range(9):
		var ang := i * TAU / 9.0 + 0.15
		var rad := 0.72 + sin(float(i) * 2.1) * 0.08
		sphere(self, CAMPFIRE_POS + Vector3(cos(ang) * rad, 0.14, sin(ang) * rad), Vector3(0.30, 0.22, 0.28), STONE_LIGHT if i % 2 == 0 else STONE)
	campfire_flame = cylinder(self, CAMPFIRE_POS + Vector3(0, 0.38, 0), 0.05, 0.34, 0.78, FIRE_ORANGE, true)
	campfire_smoke = sphere(self, CAMPFIRE_POS + Vector3(0.05, 1.55, 0), Vector3(0.38, 0.65, 0.38), Color("#d4ecf0"), true)
	# Tripod sticks + suspended iron kettle
	for a_deg in [-28.0, 92.0, 212.0]:
		var rad_a := deg_to_rad(a_deg)
		var stick := cylinder(self, CAMPFIRE_POS + Vector3(cos(rad_a) * 0.45, 0.72, sin(rad_a) * 0.45), 0.04, 0.05, 1.65, TIMBER)
		stick.rotation_degrees = Vector3(sin(rad_a) * 22.0, 0.0, -cos(rad_a) * 22.0)
	sphere(self, CAMPFIRE_POS + Vector3(0, 0.92, 0), Vector3(0.42, 0.34, 0.42), Color("#3b4454"))
	var light := OmniLight3D.new()
	light.light_color = Color("#ffa047")
	light.light_energy = 5.2
	light.omni_range = 12.5
	light.position = CAMPFIRE_POS + Vector3(0, 1.35, 0)
	add_child(light)

	# Cozy mossy sitting log + pink storybook travel journal + lantern post
	var sit_log := cylinder(self, CAMPFIRE_POS + Vector3(1.95, 0.27, -0.45), 0.27, 0.31, 2.0, TIMBER)
	sit_log.rotation_degrees = Vector3(0, 28, 90)
	var journal := box(self, LOG_JOURNAL_POS + Vector3(-0.05, 0.56, -0.05), Vector3(0.46, 0.12, 0.34), Color("#e67ca8"))
	journal.rotation_degrees.y = -18.0
	label_at(self, LOG_JOURNAL_POS + Vector3(0, 1.35, 0), "繪本旅記（按 E）", Color("#ffd1e6"), 28)
	lantern_post(Vector3(-2.1, 0.0, 1.4), 2.3, FIRE_ORANGE, 22.0)

	# Mossy Ancient Skull Cavern nestled into NW boulders (angled 26° toward campfire!)
	var skull := Node3D.new()
	skull.position = Vector3(-5.0, 0.0, -3.5)
	skull.rotation_degrees.y = 26.0
	add_child(skull)
	sphere(skull, Vector3(0, 1.85, 0), Vector3(3.5, 2.9, 2.7), STONE_LIGHT)
	sphere(skull, Vector3(0, 2.85, -0.1), Vector3(3.2, 1.25, 2.6), Color("#466e40"))
	sphere(skull, Vector3(-0.75, 1.75, 1.18), Vector3(0.75, 0.85, 0.5), Color("#151926"), true)
	sphere(skull, Vector3(0.75, 1.75, 1.18), Vector3(0.75, 0.85, 0.5), Color("#151926"), true)
	box(skull, Vector3(0, 0.65, 1.08), Vector3(1.5, 1.3, 0.6), Color("#151926"), false, true)
	skull_lantern = sphere(skull, Vector3(1.05, 1.15, 1.28), Vector3(0.38, 0.38, 0.38), FIRE_ORANGE, true)
	skull_lantern.visible = PrologueState.boss_retired
	marker(SKULL_CAVE_POS, Color("#88d4ff") if not PrologueState.boss_retired else GOLD, 0.65)
	label_at(self, SKULL_CAVE_POS + Vector3(0, 2.95, -0.9), "青苔骷髏洞（階段 2 亮燈！）" if PrologueState.boss_retired else "青苔骷髏洞", GOLD if PrologueState.boss_retired else Color("#b8dcf5"), 30)

	if PrologueState.boss_retired:
		cylinder(self, LOG_JOURNAL_POS + Vector3(-0.45, 0.25, 0.65), 0.2, 0.24, 0.35, Color("#6ec25a"))
		label_at(self, LOG_JOURNAL_POS + Vector3(-0.45, 0.85, 0.65), "哨長送的茶壺", Color("#b8ffd0"), 24)

	# Organic boulder clusters, wildflowers, leaning forest groves & cyan night mist
	for bp in [
		[Vector3(-8.4, 0, -2.5), 1.3, 18.0], [Vector3(-8.8, 0, 1.8), 1.1, -24.0],
		[Vector3(-2.4, 0, -5.2), 1.2, 35.0], [Vector3(4.2, 0, -4.6), 1.0, -15.0],
		[Vector3(6.8, 0, 3.2), 1.05, 42.0]
	]:
		boulder_cluster(bp[0], float(bp[1]), STONE, true, true, float(bp[2]))

	for tp in [
		[Vector3(-9.6, 0, -4.6), 1.35, PINE_DARK], [Vector3(-1.4, 0, -5.6), 1.2, PINE_DARK],
		[Vector3(2.8, 0, -5.0), 1.15, PINE_DARK], [Vector3(6.6, 0, -4.5), 1.25, PINE_TEAL],
		[Vector3(-9.4, 0, 3.1), 1.15, PINE_DARK], [Vector3(8.4, 0, 2.9), 1.2, PINE_DARK]
	]:
		pine_tree(tp[0], float(tp[1]), tp[2])
	cozy_tree(Vector3(-6.2, 0, 2.7), 0.85, Color("#2b4d5e"), 7.0)
	cozy_tree(Vector3(4.8, 0, 3.0), 0.78, Color("#355c6e"), -6.0)

	flower_patch(Vector3(-3.0, 0, 2.2), 7, [Color("#77b8e8"), Color("#f2d085"), Color("#e88ba7")], 1.8)
	flower_patch(Vector3(4.2, 0, -2.2), 6, [Color("#8ad6f5"), Color("#f7d97e")], 1.6)
	flower_patch(Vector3(7.2, 0, 1.5), 6, [Color("#f5c65b"), Color("#e88ba7")], 1.5)

	# Glowing cyan aurora/mist shafts behind north forest & warm dawn glow toward town
	for mx in [-7.6, -1.2, 2.4]:
		sphere(self, Vector3(mx, 2.8, -7.8), Vector3(2.6, 5.2, 2.2), MIST_CYAN, true)
	sphere(self, Vector3(12.2, 2.1, -0.6), Vector3(3.0, 4.4, 3.2), Color("#ffd299"), true)

	# Gentle drifting fireflies
	spawn_ambient_motes(Vector3(0.5, 1.5, -0.5), Vector3(16.0, 2.6, 8.0), 18, Color("#ffe38a"), 0.09)

	transition_signpost(EXIT_TO_TOWN, "前往：雲丘小鎮（按 E）", GOLD, -18.0)

func _build_title_overlay() -> void:
	title_overlay = Control.new()
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(title_overlay)

	var title_card := PanelContainer.new()
	title_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title_card.offset_left = -250
	title_card.offset_right = 250
	title_card.offset_top = 48
	title_card.offset_bottom = 176
	title_card.add_theme_stylebox_override("panel", make_panel_style(Color(0.08, 0.12, 0.24, 0.78), UI_ACCENT_GOLD, 20, 2, 24, 16))
	title_overlay.add_child(title_card)

	var tb := VBoxContainer.new()
	tb.alignment = BoxContainer.ALIGNMENT_CENTER
	tb.add_theme_constant_override("separation", 6)
	title_card.add_child(tb)

	var main_t := _styled_label("《補簽遠行》", 40, Color("#fff5d6"), true)
	main_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(main_t)
	var sub_t := _styled_label("After the Ceasefire  ·  2.5D 有機手繪繪本 × PoE 2 刷裝原型", 15, Color("#b8dcf5"), false)
	sub_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(sub_t)

	start_pill = PanelContainer.new()
	start_pill.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	start_pill.offset_left = -210
	start_pill.offset_right = 210
	start_pill.offset_top = -108
	start_pill.offset_bottom = -56
	start_pill.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_ACCENT_GOLD, 26, 3, 22, 10))
	title_overlay.add_child(start_pill)

	var hint := _styled_label("按 空白鍵 / Enter / 點擊畫面 醒來出發", 18, UI_INK, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_pill.add_child(hint)

func on_map_input(event: InputEvent) -> bool:
	if not PrologueState.has_started:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			PrologueState.has_started = true
			input_locked = false
			set_hud_visible(true)
			if title_overlay:
				var tw := create_tween()
				tw.tween_property(title_overlay, "modulate:a", 0.0, 0.42)
				tw.tween_callback(title_overlay.queue_free)
			show_player_emote("!", 1.5)
			show_subtitle("「一百年前，魔王軍與王國聯軍爆發世紀大戰……」── 烤條魚灌滿水壺，沿著林間小徑去雲丘小鎮吧！", 5.5)
			return true
	return false

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	campfire_flame.scale.y = 0.92 + sin(t * 11.0) * 0.14
	campfire_smoke.position.y = 1.45 + fmod(t * 0.55, 1.2)
	campfire_smoke.position.x = sin(t * 2.2) * 0.22
	if start_pill and is_instance_valid(start_pill):
		start_pill.modulate.a = 0.78 + sin(t * 4.5) * 0.22
	if not step_shared_physics(delta):
		return
	_update_ui()

func on_interact() -> void:
	if near(EXIT_TO_TOWN, 2.6):
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_campfire", "雲丘小鎮 Hub")
	elif near(CAMPFIRE_POS, 2.1):
		PrologueState.player_hp = 5
		PrologueState.campfire_dish = "烤魚"
		show_player_emote("✨", 1.6)
		show_subtitle("營火料理《百年停戰烤魚》已灌入隨身水壺！體力全滿，並獲得常駐攻擊 +1！", 4.0)
	elif near(LOG_JOURNAL_POS, 2.0):
		show_player_emote("✨", 1.4)
		var retired_txt := "已勸退：稻草人哨長（現於雲海橋頭開免費茶攤）" if PrologueState.boss_retired else "尚無已勸退 Boss（稻草人哨長仍在雲海石橋加班中）"
		show_subtitle("繪本旅記｜" + retired_txt + "。按 [I] 可隨時開啟背包與通貨造裝。", 4.8)
	elif near(SKULL_CAVE_POS, 2.6):
		if not PrologueState.boss_retired:
			show_player_emote("?", 1.6)
			show_subtitle("青苔骷髏洞內傳來輕微的「呼嚕……」（似乎有位退休亡靈正在睡午覺）。", 4.0)
		elif not PrologueState.skull_gift_claimed:
			PrologueState.skull_gift_claimed = true
			PrologueState.orb_gold += 2
			show_player_emote("✨", 2.0)
			show_subtitle("洞口亮起小橘燈與亡靈謝卡：「感謝你讓外面變安靜了！」獲得《百年金漆罐》x2！", 5.0)
		else:
			show_player_emote("✨", 1.4)
			show_subtitle("骷髏洞字條：「等勸退四位大 Boss 後，再來找我開《亡靈露營管理處》！」", 4.0)

func _update_ui() -> void:
	set_zone_objective("地圖一：湖畔私人營火窩", "可於營火煮烤魚、翻閱旅記或探查骷髏洞，準備好後沿蜿蜒林徑前往雲丘小鎮")
	update_status_line()
	if not PrologueState.has_started:
		set_prompt("")
		return
	if near(EXIT_TO_TOWN, 2.6):
		set_prompt("[ E ] 沿蜿蜒林徑前往：雲丘小鎮（地圖二）")
	elif near(CAMPFIRE_POS, 2.1):
		set_prompt("[ E ] 營火休息並烹煮《百年停戰烤魚》（攻擊 +1）")
	elif near(LOG_JOURNAL_POS, 2.0):
		set_prompt("[ E ] 坐上青苔坐木翻閱繪本旅記")
	elif near(SKULL_CAVE_POS, 2.6):
		set_prompt("[ E ] 檢視亮燈的骷髏洞匿名謝卡" if (PrologueState.boss_retired and not PrologueState.skull_gift_claimed) else "[ E ] 探頭查看青苔骷髏洞")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼拍檔")
	else:
		set_prompt("")

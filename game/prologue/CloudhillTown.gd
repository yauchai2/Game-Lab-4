extends "res://prologue/PrologueBase.gd"

const WEST_EXIT := Vector3(-15.5, 0.0, 1.4)
const EAST_EXIT := Vector3(15.6, 0.0, 1.0)
const SHOP_POS := Vector3(-7.4, 0.0, -5.8)
const SHOP_INTERACT := Vector3(-6.8, 0.0, -2.8)
const TAVERN_POS := Vector3(6.2, 0.0, -6.8)
const TAVERN_DOOR := Vector3(5.4, 0.0, -3.5)
const WAYPOINT_POS := Vector3(-0.2, 0.0, 0.4)
const STASH_POS := Vector3(9.4, 0.0, 6.2)
const SLIME_HOME := Vector3(-3.0, 0.0, 4.6)
const DUMMY_1_POS := Vector3(2.8, 0.0, 7.2)
const DUMMY_2_POS := Vector3(5.6, 0.0, 6.8)

var goblin_bubble: Label3D
var goblin_talk_timer := 0.0
var slime_node: Node3D
var slime_bubble: Label3D
var dummies: Array[Node3D] = []
var ambient_chatter_timer := 3.5
var patron_bubble: Label3D

func _ready() -> void:
	can_attack = true
	_build_town()
	var spawn := Vector3(-12.8, 0.0, 1.5)
	if PrologueState.spawn_tag == "from_road":
		spawn = Vector3(12.8, 0.0, 1.0)
	elif PrologueState.spawn_tag == "from_waypoint":
		spawn = Vector3(-0.2, 0.0, 2.8)
	setup_core_trio(spawn)
	setup_camera_and_lighting(19.0, Color("#73e4f5"), Color("#eef3fc"), 0.88, Color("#ffe4ba"), 1.15)
	setup_hud()

	if not PrologueState.has_sword:
		_goblin_say("早安早安！百年戰爭早打完了，魔王軍滯銷武器全場五折！快來拿把短劍！", 6.5)
		show_subtitle("（史詩配樂瞬間卡帶，迎面是微風徐徐、熱鬧又溫馨的雲丘山丘市集！）", 3.8)
	elif PrologueState.boss_retired:
		_goblin_say("聽說你幫稻草人哨長辦完退休了？按 [I] 可以用通貨洗詞綴，或找波波吞廢裝！", 5.5)
	_update_ui()

func _build_town() -> void:
	# Organic layered hilltop meadow islands (zero giant rectangular slab!)
	organic_mound(self, Vector3(0.0, -0.52, 0.5), 18.8, 12.6, 1.04, MEADOW_GREEN, -4.0)
	organic_mound(self, Vector3(-9.5, -0.49, 2.2), 9.6, 8.2, 1.0, MEADOW_LIGHT, 14.0)
	organic_mound(self, Vector3(8.8, -0.49, -1.5), 10.4, 8.8, 1.0, MEADOW_LIGHT, -16.0)
	organic_mound(self, Vector3(2.2, -0.50, 6.2), 9.5, 6.4, 1.0, Color("#7fb050"), 8.0)

	# Central warm circular cobble plaza
	organic_mound(self, Vector3(0.0, 0.01, 0.4), 6.8, 5.4, 0.03, Color("#f5d9a1"), -8.0)
	organic_mound(self, Vector3(0.2, 0.018, 0.5), 4.6, 3.8, 0.025, Color("#ebd098"), 18.0)

	# Winding organic cobblestone paths radiating from central plaza
	curved_path([WEST_EXIT, Vector3(-10.5, 0, 2.2), Vector3(-5.2, 0, 1.4), Vector3(-1.5, 0, 0.6)], 2.4, TRAIL, TRAIL_STONE)
	curved_path([Vector3(1.8, 0, 0.5), Vector3(6.8, 0, 1.8), Vector3(11.5, 0, 1.3), EAST_EXIT], 2.4, TRAIL, TRAIL_STONE)
	curved_path([Vector3(-2.5, 0, -0.5), Vector3(-5.0, 0, -1.8), SHOP_INTERACT], 2.1, TRAIL, TRAIL_STONE)
	curved_path([Vector3(2.0, 0, -0.8), Vector3(4.0, 0, -2.1), TAVERN_DOOR], 2.1, TRAIL, TRAIL_STONE)
	curved_path([Vector3(0.2, 0, 2.6), Vector3(-1.4, 0, 3.9), SLIME_HOME], 1.8, TRAIL, TRAIL_STONE)
	curved_path([Vector3(2.0, 0, 2.8), Vector3(4.8, 0, 5.2), Vector3(8.2, 0, 5.8)], 1.8, TRAIL, TRAIL_STONE)

	# Soft invisible perimeter framed by cozy trees, boulders & fluffy clouds (zero visible straight walls!)
	invisible_boundary_wall(Vector3(0.0, 0.8, -11.4), Vector3(35.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(0.0, 0.8, 11.4), Vector3(35.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(-17.4, 0.8, 0.0), Vector3(0.8, 1.8, 23.0))
	invisible_boundary_wall(Vector3(17.4, 0.8, 0.0), Vector3(0.8, 1.8, 23.0))

	# Distant storybook hilltop cottages & drifting cloud banks
	for h in [
		[Vector3(-12.8, 0.0, -9.8), 18.0],
		[Vector3(-1.4, 0.0, -10.8), -12.0],
		[Vector3(13.2, 0.0, -8.8), -26.0]
	]:
		var cot := Node3D.new()
		cot.position = h[0]
		cot.rotation_degrees.y = float(h[1])
		add_child(cot)
		box(cot, Vector3(0, 2.0, 0), Vector3(3.2, 4.0, 2.8), WHITE_WALL, true)
		var roof := cylinder(cot, Vector3(0, 4.5, 0), 0.25, 2.5, 1.6, CORAL_ROOF)
		roof.scale.z = 0.88
	for c in [
		[Vector3(20.5, -0.6, -6.5), Vector3(6.2, 3.0, 5.4)],
		[Vector3(22.2, -0.8, 1.8), Vector3(5.8, 2.8, 5.2)],
		[Vector3(20.0, -0.7, 8.8), Vector3(6.0, 3.0, 5.0)],
		[Vector3(11.5, -0.9, 13.8), Vector3(5.8, 2.5, 4.6)]
	]:
		sphere(self, c[0], c[1], CLOUD_WHITE, true)

	# --- 1. Angled Bone-Helmet Goblin Clearance Stall (rotated +20° toward plaza!) ---
	var shop_root := Node3D.new()
	shop_root.position = SHOP_POS
	shop_root.rotation_degrees.y = 20.0
	add_child(shop_root)
	box(shop_root, Vector3(0, 1.5, -1.5), Vector3(6.6, 3.0, 0.35), TIMBER, true)
	for px in [-3.1, 3.1]:
		cylinder(shop_root, Vector3(px, 1.6, 1.2), 0.14, 0.16, 3.2, TIMBER)
	var awning := box(shop_root, Vector3(0, 3.2, 0.0), Vector3(7.4, 0.32, 3.8), Color("#f6ebd2"))
	awning.rotation_degrees.x = 9.0
	var stripe := box(shop_root, Vector3(0, 3.38, 0.05), Vector3(7.42, 0.10, 1.4), CORAL_ROOF)
	stripe.rotation_degrees.x = 9.0
	box(shop_root, Vector3(0, 0.55, 1.35), Vector3(5.6, 1.1, 0.9), TIMBER_LIGHT, true)
	box(shop_root, Vector3(0, 1.22, 1.35), Vector3(5.2, 0.32, 0.68), Color("#a8e6f5"))
	# Cozy crates & barrels beside stall
	cylinder(shop_root, Vector3(-3.8, 0.42, 1.1), 0.38, 0.42, 0.84, TIMBER_LIGHT)
	box(shop_root, Vector3(3.6, 0.38, 0.9), Vector3(0.8, 0.76, 0.8), TIMBER)
	label_at(shop_root, Vector3(2.6, 2.4, 1.8), "-50¢ 五折清倉", STAMP_RED, 34)
	label_at(shop_root, Vector3(0, 4.25, 0.5), "骨盔哥布林清倉行", GOLD, 34)
	marker(SHOP_INTERACT, GOLD, 0.72)

	var gob := Node3D.new()
	gob.position = Vector3(0, 0.0, 0.35)
	shop_root.add_child(gob)
	sphere(gob, Vector3(0, 0.95, 0), Vector3(1.25, 1.15, 0.95), GOBLIN_GREEN)
	sphere(gob, Vector3(0, 1.78, 0.06), Vector3(0.96, 0.84, 0.86), GOBLIN_GREEN)
	sphere(gob, Vector3(0, 2.18, 0.08), Vector3(1.04, 0.56, 0.96), Color("#f7f4ef"))
	goblin_bubble = label_at(gob, Vector3(0, 3.35, 0), "", Color("#fff7c2"), 34)
	register_living_npc(gob, 0.0, 0.07, 3.0)

	# --- 2. Angled Retired Monsters Tavern & Lived-in Outdoor Patio (rotated -18°!) ---
	var tav := Node3D.new()
	tav.position = TAVERN_POS
	tav.rotation_degrees.y = -18.0
	add_child(tav)
	box(tav, Vector3(0, 2.4, 0), Vector3(7.6, 4.8, 4.8), WHITE_WALL, true)
	var tav_roof := box(tav, Vector3(0, 5.15, 0), Vector3(8.4, 0.85, 5.5), CORAL_ROOF)
	tav_roof.rotation_degrees.x = 6.0
	box(tav, Vector3(0, 1.35, 2.45), Vector3(2.4, 2.7, 0.25), BLUE_CURTAIN)
	for lx in [-2.2, 0.0, 2.2]:
		var lmp := sphere(tav, Vector3(lx, 2.85, 2.85), Vector3(0.48, 0.52, 0.48), FIRE_ORANGE, true)
		sway_items.append({"node": lmp, "base_rot": lmp.rotation, "amp": 0.08, "speed": 2.3, "phase": lx})
	# Cozy outdoor round tables with steaming ramen & retired monster neighbors!
	organic_mound(tav, Vector3(4.8, 0.14, 1.8), 3.4, 2.8, 0.28, BOARDWALK, 12.0)
	cylinder(tav, Vector3(4.4, 0.62, 1.7), 0.72, 0.68, 0.14, TIMBER_LIGHT)
	cylinder(tav, Vector3(4.4, 0.34, 1.7), 0.14, 0.18, 0.56, TIMBER)
	# Ramen bowl on table
	sphere(tav, Vector3(4.4, 0.76, 1.7), Vector3(0.36, 0.22, 0.36), Color("#fff2d6"))
	# Happy pink Pig Uncle sitting at table!
	var pig := Node3D.new()
	pig.position = Vector3(5.35, 0.28, 1.75)
	tav.add_child(pig)
	sphere(pig, Vector3(0, 0.52, 0), Vector3(0.82, 0.76, 0.76), Color("#f29cb0"))
	sphere(pig, Vector3(0, 1.08, 0.05), Vector3(0.62, 0.56, 0.58), Color("#f5a9ba"))
	register_living_npc(pig, 0.28, 0.05, 2.6)
	# Chubby blue Penguin Waiter carrying a silver cloche!
	var peng := Node3D.new()
	peng.position = Vector3(3.15, 0.28, 2.15)
	tav.add_child(peng)
	sphere(peng, Vector3(0, 0.42, 0), Vector3(0.55, 0.68, 0.52), Color("#3b64a8"))
	sphere(peng, Vector3(0.36, 0.56, 0.15), Vector3(0.32, 0.24, 0.32), Color("#d4d8e2"))
	register_living_npc(peng, 0.28, 0.08, 4.4)
	patron_bubble = label_at(pig, Vector3(-0.3, 2.05, 0), "這碗豚骨麵比打仗幸福多了♪", Color("#ffe4b5"), 26)
	label_at(tav, Vector3(0, 6.2, 1.2), "退休魔物大酒館／勸退公會", Color("#ffe099"), 34)
	marker(TAVERN_DOOR, Color("#69c5ed"), 0.72)

	# Overhead festive bunting connecting Goblin Stall → Plaza Waypoint → Tavern!
	bunting_line(SHOP_POS + Vector3(2.8, 3.6, 1.5), WAYPOINT_POS + Vector3(0, 2.8, 0), 0.75, [CORAL_ROOF, GOLD, BUNTING_BLUE, WHITE_WALL], 7)
	bunting_line(WAYPOINT_POS + Vector3(0, 2.8, 0), TAVERN_POS + Vector3(-2.6, 3.8, 2.2), 0.75, [GOLD, BUNTING_BLUE, CORAL_ROOF, WHITE_WALL], 7)

	# --- 3. Central Waypoint Perch (slightly tilted handcrafted charm) ---
	var wp := Node3D.new()
	wp.position = WAYPOINT_POS
	wp.rotation_degrees.y = 14.0
	add_child(wp)
	var wp_post := cylinder(wp, Vector3(0, 1.25, 0), 0.34, 0.44, 2.5, TIMBER_LIGHT)
	wp_post.rotation_degrees.z = -3.0
	box(wp, Vector3(0, 1.88, 0), Vector3(1.65, 0.32, 0.32), TIMBER_LIGHT)
	sphere(wp, Vector3(0, 2.68, 0), Vector3(0.54, 0.46, 0.54), GOLD)
	for bx in [-1.15, 1.15]:
		cylinder(wp, Vector3(bx, 0.36, 0.72), 0.34, 0.32, 0.72, TIMBER)
		sphere(wp, Vector3(bx, 0.82, 0.72), Vector3(0.66, 0.48, 0.66), Color("#a67ee8"))
	label_at(self, WAYPOINT_POS + Vector3(0, 3.55, 0), "信使鳥驛站（Waypoint／重置刷圖）", GOLD, 32)
	marker(WAYPOINT_POS + Vector3(0, 0, 1.5), GOLD, 0.72)

	# --- 4. Organic Curved Beast Drinking Cove (Southwest) ---
	organic_mound(self, Vector3(-8.8, 0.04, 6.8), 3.6, 2.5, 0.12, Color("#62c4ed"), -22.0, true)
	boulder_cluster(Vector3(-11.4, 0, 6.2), 1.15, STONE_LIGHT, true, true, 16.0)
	boulder_cluster(Vector3(-6.4, 0, 8.2), 0.85, STONE, true, true, -30.0)
	label_at(self, Vector3(-8.8, 1.45, 6.8), "巨獸飲水小池", Color("#d6ffd9"), 30)

	# --- 5. Training Dummies (angled naturally) & Stash Chest ---
	for idx in range(2):
		var dp := DUMMY_1_POS if idx == 0 else DUMMY_2_POS
		var d := Node3D.new()
		d.position = dp
		d.rotation_degrees.y = -18.0 if idx == 0 else 12.0
		add_child(d)
		cylinder(d, Vector3(0, 0.85, 0), 0.14, 0.16, 1.7, TIMBER)
		box(d, Vector3(0, 1.15, 0), Vector3(1.3, 0.24, 0.24), TIMBER_LIGHT)
		sphere(d, Vector3(0, 1.65, 0), Vector3(0.48, 0.48, 0.48), Color("#e5c285"))
		dummies.append(d)
	label_at(self, Vector3(4.2, 2.35, 7.0), "試刀木樁（實測配裝傷害）", Color("#fff2b2"), 30)

	var stash_root := Node3D.new()
	stash_root.position = STASH_POS
	stash_root.rotation_degrees.y = -28.0
	add_child(stash_root)
	box(stash_root, Vector3(0, 0.48, 0), Vector3(1.3, 0.96, 0.9), GOLD, true)
	cylinder(stash_root, Vector3(1.45, 0.45, 0.25), 0.42, 0.46, 0.9, TIMBER_LIGHT)
	label_at(self, STASH_POS + Vector3(0, 1.75, 0), "百年軍需儲物箱（Stash）", GOLD, 30)
	marker(STASH_POS + Vector3(0, 0, -1.2), GOLD, 0.65)

	# --- 6. Clean Slime Bobo Auto-Salvage Meadow ---
	slime_node = Node3D.new()
	slime_node.position = SLIME_HOME
	add_child(slime_node)
	sphere(slime_node, Vector3(0, 0.40, 0), Vector3(0.92, 0.72, 0.92), Color("#58d6d6"))
	sphere(slime_node, Vector3(-0.2, 0.48, 0.36), Vector3(0.14, 0.14, 0.12), Color("#1e2636"), true)
	sphere(slime_node, Vector3(0.2, 0.48, 0.36), Vector3(0.14, 0.14, 0.12), Color("#1e2636"), true)
	slime_bubble = label_at(slime_node, Vector3(0, 1.35, 0), "回收史萊姆・波波（一鍵吞白裝換通貨）", Color("#b8ffff"), 28)

	# --- 7. Organic Trees, Lanterns, Wildflowers & Floating Pollen ---
	for tp in [
		[Vector3(-14.6, 0, -5.2), 1.15, PINE_DARK],
		[Vector3(-15.2, 0, 5.4), 1.1, PINE_TEAL],
		[Vector3(-12.6, 0, 9.0), 1.05, MEADOW_GREEN],
		[Vector3(12.8, 0, 7.6), 1.1, MEADOW_LIGHT],
		[Vector3(14.0, 0, -4.4), 1.05, Color("#d88662")]
	]:
		cozy_tree(tp[0], float(tp[1]), tp[2], randf_range(-6.0, 6.0), true)
	lantern_post(Vector3(-9.5, 0, 0.0), 2.5, FIRE_ORANGE, -15.0)
	lantern_post(Vector3(11.4, 0, 3.2), 2.5, FIRE_ORANGE, 24.0)
	flower_patch(Vector3(-4.8, 0, 6.2), 8, [Color("#ff9eb5"), Color("#ffe066"), Color("#87c8ff")], 2.1)
	flower_patch(Vector3(7.6, 0, 2.8), 7, [Color("#ffd966"), Color("#f28c7e"), WHITE_WALL], 1.8)
	flower_patch(Vector3(-11.2, 0, -1.8), 6, [Color("#ffe066"), Color("#a67ee8")], 1.6)
	spawn_ambient_motes(Vector3(0.0, 2.0, 0.0), Vector3(28.0, 3.2, 16.0), 20, Color("#fff8d6"), 0.09)

	# West Signpost & Cozy Curved East Departure Arch
	transition_signpost(WEST_EXIT, "返回：湖畔私人營火窩（按 E）", Color("#b8f5ff"), 14.0)
	var arch := Node3D.new()
	arch.position = EAST_EXIT
	arch.rotation_degrees.y = -10.0
	add_child(arch)
	cylinder(arch, Vector3(0, 2.1, -2.3), 0.22, 0.28, 4.2, TIMBER)
	cylinder(arch, Vector3(0, 2.1, 2.3), 0.22, 0.28, 4.2, TIMBER)
	var beam := box(arch, Vector3(0, 4.0, 0.0), Vector3(0.52, 0.48, 5.4), TIMBER_LIGHT)
	beam.rotation_degrees.x = 2.0
	bunting_line(EAST_EXIT + Vector3(0, 3.8, -2.2), EAST_EXIT + Vector3(0, 3.8, 2.2), 0.55, [BUNTING_BLUE, GOLD, CORAL_ROOF], 5)
	marker(EAST_EXIT, GOLD, 1.0)
	label_at(self, EAST_EXIT + Vector3(0, 4.85, 0), "出發拱門 → 前往：雲海古道與石橋（按 E）", GOLD, 34)

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	if goblin_talk_timer > 0.0:
		goblin_talk_timer -= delta
		if goblin_talk_timer <= 0.0:
			goblin_bubble.text = ""
	ambient_chatter_timer -= delta
	if ambient_chatter_timer <= 0.0:
		ambient_chatter_timer = 5.5
		var lines := ["這碗豚骨麵比打仗幸福多了♪", "企鵝老闆，再來一盤煎餃！", "聽說橋那頭的稻草人還在加班？", "陽光真暖和，等會睡午覺去～"]
		patron_bubble.text = lines[randi() % lines.size()]

	slime_node.position.y = absf(sin(t * 4.8)) * 0.18
	slime_node.scale = Vector3(1.0 + sin(t * 9.6) * 0.06, 1.0 - sin(t * 9.6) * 0.06, 1.0 + sin(t * 9.6) * 0.06)
	if not step_shared_physics(delta):
		return
	_update_ui()

func on_interact() -> void:
	if near(SHOP_INTERACT, 2.8):
		if not PrologueState.has_sword:
			PrologueState.coins = maxi(0, PrologueState.coins - 50)
			var starter := PrologueState.make_item("五折庫存短劍", "weapon", "magic", 1)
			PrologueState.equipped_weapon = starter
			PrologueState.has_sword = true
			player_sword.show()
			PrologueState.add_item_to_inventory(PrologueState.make_item("生鏽步兵短劍", "weapon", "normal", 1))
			show_player_emote("💰", 1.5)
			_goblin_say("爽快！額外送你一把生鏽白裝胚子，按 [I] 可以點藍印章造裝，或餵給波波換通貨！", 6.5)
			create_tween().tween_property(player, "rotation:y", player.rotation.y + TAU, 0.45)
		else:
			show_player_emote("?", 1.3)
			_goblin_say("玻璃櫃裡的骷髏王冠改裝成小夜燈特價 30¢！按 [I] 打開背包點裝造裝吧！", 4.5)
		return

	if near(TAVERN_DOOR, 2.8):
		show_player_emote("✨", 1.5)
		show_subtitle("退休魔物大酒館（企鵝侍應生正端著熱呼呼的拉麵穿梭在退休魔王軍之間！）", 4.5)
		return

	if near(SLIME_HOME, 2.3):
		var res := PrologueState.salvage_normal_items()
		if int(res["count"]) > 0:
			show_player_emote("✨", 1.5)
			slime_bubble.text = "咕嚕！吞掉 %d 件白裝 → +%d¢、藍印章+%d" % [int(res["count"]), int(res["coins"]), int(res["blue"])]
			show_subtitle("波波一口吞掉 %d 件白裝！獲得 %d¢、改裝藍印章 x%d、洗白劑 x%d。" % [int(res["count"]), int(res["coins"]), int(res["blue"]), int(res["chaos"])], 4.5)
		else:
			show_player_emote("?", 1.2)
			slime_bubble.text = "咕啾？（背包裡沒有多餘的白裝喔）"
			show_subtitle("背包目前沒有低階白裝可回收；去地圖三刷怪噴裝再來餵波波吧！", 3.5)
		return

	if near(STASH_POS + Vector3(0, 0, -1.2), 2.6):
		toggle_inventory()
		return

	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.7):
		if PrologueState.waypoint_road_unlocked:
			PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_waypoint", "雲海瞭望台（重置刷怪）")
		else:
			show_player_emote("?", 1.2)
			show_subtitle("信使鳥驛站：先由東側出發拱門前往「雲海古道與石橋」解鎖傳送點！", 4.0)
		return

	if near(WEST_EXIT, 2.8):
		PrologueState.transition_to("res://prologue/CampfireClearing.tscn", "from_town", "湖畔私人營火窩")
		return

	if near(EAST_EXIT, 2.8):
		if not PrologueState.has_sword:
			show_player_emote("💦", 1.5)
			_goblin_say("喂！空手出去會被小兵和哨長敲暈的，先來買把五折短劍吧！", 4.5)
			return
		PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_town", "雲海古道與石橋")

func on_sword_hit() -> void:
	for d in dummies:
		if flat(player.position - d.position).length() < 2.3:
			var is_crit := randi() % 100 < PrologueState.get_total_crit()
			var dmg := PrologueState.get_total_atk() * (2 if is_crit else 1)
			hitstop_frames = 3
			shake_time = 0.08
			var tw := create_tween()
			tw.tween_property(d, "rotation:z", 0.35, 0.07)
			tw.tween_property(d, "rotation:z", 0.0, 0.16)
			show_player_emote("✨", 0.9)
			show_subtitle("命中木樁：造成 %d 傷害%s！" % [dmg, "（暴擊 CRIT!）" if is_crit else ""], 2.0)

func _goblin_say(words: String, duration := 4.5) -> void:
	goblin_bubble.text = words
	goblin_talk_timer = duration

func _update_ui() -> void:
	var step := "向西北側骨盔哥布林購入五折短劍" if not PrologueState.has_sword else "按 [I] 體驗造裝，或由東側出發拱門前往「雲海古道與石橋」刷怪！"
	if PrologueState.boss_retired:
		step = "可找波波一鍵吞白裝換通貨，或從東側出發拱門／驛站重刷地圖三精英怪"
	set_zone_objective("地圖二：雲丘環形市集 Hub", step)
	update_status_line()

	if near(SHOP_INTERACT, 2.8):
		set_prompt("[ E ] 以 50¢ 購入五折短劍（附贈造裝白裝胚子）" if not PrologueState.has_sword else "[ E ] 偷看玻璃櫃奇葩文創品")
	elif near(TAVERN_DOOR, 2.8):
		set_prompt("[ E ] 探看退休魔物大酒館熱鬧餐桌")
	elif near(SLIME_HOME, 2.3):
		set_prompt("[ E ] 一鍵餵波波吞白裝 → 換銅幣與造裝通貨")
	elif near(STASH_POS + Vector3(0, 0, -1.2), 2.6):
		set_prompt("[ E ] 開啟背包與造裝工坊 [I]")
	elif near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.7):
		set_prompt("[ E ] 信使鳥驛站：重置並快傳至「雲海古道」" if PrologueState.waypoint_road_unlocked else "[ E ] 檢視信使鳥驛站（Waypoint）")
	elif near(WEST_EXIT, 2.8):
		set_prompt("[ E ] 返回：湖畔私人營火窩（地圖一）")
	elif near(EAST_EXIT, 2.8):
		set_prompt("[ E ] 出城前往：雲海古道與石橋（地圖三・刷怪區）")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼拍檔")
	else:
		set_prompt("")

extends "res://prologue/PrologueBase.gd"

const WEST_EXIT := Vector3(-16.0, 0.0, 1.5)
const EAST_EXIT := Vector3(16.0, 0.0, 1.5)
const SHOP_POS := Vector3(-7.2, 0.0, -6.2)
const SHOP_INTERACT := Vector3(-7.2, 0.0, -2.8)
const TAVERN_DOOR := Vector3(5.6, 0.0, -4.6)
const WAYPOINT_POS := Vector3(0.0, 0.0, 0.5)
const STASH_POS := Vector3(10.0, 0.0, 7.6)
const SLIME_HOME := Vector3(-3.2, 0.0, 4.8)
const DUMMY_1_POS := Vector3(2.8, 0.0, 8.0)
const DUMMY_2_POS := Vector3(6.0, 0.0, 8.0)

var goblin_bubble: Label3D
var goblin_talk_timer := 0.0
var slime_node: Node3D
var slime_bubble: Label3D
var dummies: Array[Node3D] = []

func _ready() -> void:
	can_attack = true
	_build_town()
	var spawn := Vector3(-13.2, 0.0, 1.5)
	if PrologueState.spawn_tag == "from_road":
		spawn = Vector3(13.2, 0.0, 1.5)
	elif PrologueState.spawn_tag == "from_waypoint":
		spawn = Vector3(0.0, 0.0, 2.8)
	setup_core_trio(spawn)
	setup_camera_and_lighting(18.5, Color("#6be6f7"), Color("#e8effa"), 0.85, Color("#ffe3b8"), 1.12)
	setup_hud()

	if not PrologueState.has_sword:
		_goblin_say("早安早安！百年戰爭早打完了，魔王軍滯銷武器全場五折！快來拿把短劍！", 6.5)
		show_subtitle("（史詩配樂瞬間卡帶，迎面是熱鬧非凡的雲丘小鎮清倉大特賣！）", 3.5)
	elif PrologueState.boss_retired:
		_goblin_say("聽說你幫稻草人哨長辦完退休了？歡迎隨時回來逛清倉行！", 5.0)
	_update_ui()

func _build_town() -> void:
	# Expansive 36m x 24m MMORPG-scale plateau
	box(self, Vector3(0.0, -0.5, 0.0), Vector3(36.0, 1.0, 24.0), MEADOW_GREEN)
	# Central sunlit stone square + wooden boardwalk avenues
	box(self, Vector3(0.0, 0.015, 0.5), Vector3(14.5, 0.03, 9.5), Color("#f5d79b"))
	box(self, Vector3(0.0, 0.02, 1.5), Vector3(34.0, 0.04, 3.2), BOARDWALK)
	box(self, Vector3(-7.2, 0.02, -1.8), Vector3(6.5, 0.04, 5.2), BOARDWALK)
	box(self, Vector3(5.6, 0.02, -2.0), Vector3(7.0, 0.04, 5.5), BOARDWALK)

	# Perimeter curbs
	box(self, Vector3(0.0, 0.8, -11.8), Vector3(36.5, 1.6, 0.6), STONE, true)
	box(self, Vector3(0.0, 0.8, 11.8), Vector3(36.5, 1.6, 0.6), MEADOW_GREEN, true)
	box(self, Vector3(-17.8, 0.8, 0.0), Vector3(0.6, 1.6, 24.0), PINE_DARK, true)
	box(self, Vector3(17.8, 0.8, 0.0), Vector3(0.6, 1.6, 24.0), CLOUD_WHITE, true)

	# Background decorative white-plaster coral-roof hillside houses
	for h in [
		Vector3(-12.5, 0.0, -10.5), Vector3(-2.0, 0.0, -11.2), Vector3(1.5, 0.0, -10.2)
	]:
		box(self, h + Vector3(0, 2.2, 0), Vector3(3.4, 4.4, 3.0), WHITE_WALL, true)
		box(self, h + Vector3(0, 4.6, 0), Vector3(3.9, 0.6, 3.5), CORAL_ROOF)
	# Fluffy pastel clouds along east horizon
	for c in [Vector3(21.5, -0.5, -7.0), Vector3(22.5, -0.8, 1.5), Vector3(21.0, -0.6, 9.0)]:
		sphere(self, c, Vector3(5.5, 2.8, 5.2), CLOUD_WHITE, true)
	# West pine forest edge
	for p in [Vector3(-16.2, 0, -6.5), Vector3(-16.5, 0, -3.0), Vector3(-16.2, 0, 6.2), Vector3(-14.5, 0, 9.0)]:
		pine_tree(p, 1.15, PINE_DARK)

	# 1. NW: Open-Front Goblin Weapon Clearance Pavilion (cream canvas awning)
	box(self, SHOP_POS + Vector3(0, 1.6, -1.6), Vector3(7.4, 3.2, 0.35), TIMBER, true)
	box(self, SHOP_POS + Vector3(-3.5, 1.6, 0.0), Vector3(0.35, 3.2, 3.2), TIMBER, true)
	box(self, SHOP_POS + Vector3(3.5, 1.6, 0.0), Vector3(0.35, 3.2, 3.2), TIMBER, true)
	box(self, SHOP_POS + Vector3(0, 3.4, 0.1), Vector3(8.0, 0.38, 4.2), Color("#f6ebd2"))
	# Long glass display counter
	box(self, SHOP_POS + Vector3(0, 0.55, 1.45), Vector3(6.2, 1.1, 0.9), TIMBER_LIGHT, true)
	box(self, SHOP_POS + Vector3(0, 1.25, 1.45), Vector3(5.8, 0.35, 0.7), Color("#a8e6f5"))
	label_at(self, SHOP_POS + Vector3(2.8, 2.35, 1.8), "-50¢ 五折清倉", STAMP_RED, 34)
	label_at(self, SHOP_POS + Vector3(0, 4.2, 0.6), "骨盔哥布林清倉行", GOLD, 34)
	marker(SHOP_INTERACT, GOLD, 0.72)

	# Green Goblin Shopkeeper (GeBu) with horned white skull helmet
	var gob := Node3D.new()
	gob.position = SHOP_POS + Vector3(0, 0.0, 0.4)
	add_child(gob)
	box(gob, Vector3(0, 0.95, 0), Vector3(1.3, 1.2, 0.9), GOBLIN_GREEN)
	sphere(gob, Vector3(0, 1.78, 0.05), Vector3(0.95, 0.85, 0.85), GOBLIN_GREEN)
	sphere(gob, Vector3(0, 2.18, 0.08), Vector3(1.02, 0.58, 0.95), Color("#f6f4ef"))
	goblin_bubble = label_at(gob, Vector3(0, 3.35, 0), "", Color("#fff7c2"), 34)

	# 2. North-Center: Enterable Monster Tavern & Guild Hall (wide 2.4m blue-curtain doorway + lanterns)
	var tav := Vector3(5.6, 0.0, -8.0)
	box(self, tav + Vector3(0, 2.5, 0), Vector3(8.2, 5.0, 5.2), WHITE_WALL, true)
	box(self, tav + Vector3(0, 5.4, 0), Vector3(8.8, 0.85, 5.8), CORAL_ROOF)
	# Wide enterable blue-curtain doorway (2.4m wide x 2.8m tall)
	box(self, tav + Vector3(0, 1.4, 2.65), Vector3(2.5, 2.8, 0.25), BLUE_CURTAIN)
	# Warm glowing orange paper lanterns
	for lx in [-2.2, 2.2, 5.0, 7.2]:
		sphere(self, tav + Vector3(lx, 2.6, 3.1), Vector3(0.55, 0.55, 0.55), FIRE_ORANGE, true)
	# Outdoor wooden dining terrace on east side of tavern
	box(self, tav + Vector3(6.2, 0.22, 1.2), Vector3(4.4, 0.44, 4.2), BOARDWALK, true)
	label_at(self, tav + Vector3(0, 6.4, 1.5), "退休魔物大酒館／勸退公會（可進大廳）", Color("#ffe099"), 34)
	marker(TAVERN_DOOR, Color("#69c5ed"), 0.72)

	# 3. Center: Messenger-Bird Waypoint Totem + Flower Barrels
	cylinder(self, WAYPOINT_POS + Vector3(0, 1.25, 0), 0.38, 0.46, 2.5, TIMBER_LIGHT, false)
	box(self, WAYPOINT_POS + Vector3(0, 1.85, 0), Vector3(1.6, 0.35, 0.35), TIMBER_LIGHT)
	sphere(self, WAYPOINT_POS + Vector3(0, 2.65, 0), Vector3(0.52, 0.45, 0.52), GOLD)
	for bx in [-1.05, 1.05]:
		cylinder(self, WAYPOINT_POS + Vector3(bx, 0.38, 0.75), 0.35, 0.32, 0.76, TIMBER)
		sphere(self, WAYPOINT_POS + Vector3(bx, 0.85, 0.75), Vector3(0.62, 0.45, 0.62), Color("#9d7ae8"))
	label_at(self, WAYPOINT_POS + Vector3(0, 3.45, 0), "信使鳥驛站（Waypoint）", GOLD, 32)
	marker(WAYPOINT_POS + Vector3(0, 0, 1.5), GOLD, 0.72)

	# 4. South Giant Beast Resting Lawn: 2 Long Water Troughs, 2 Training Dummies, Stash Chest, Clean Slime Bobo
	for tz in [6.4, 8.6]:
		box(self, Vector3(-8.5, 0.38, tz), Vector3(3.4, 0.76, 1.0), TIMBER, true)
		box(self, Vector3(-8.5, 0.72, tz), Vector3(3.0, 0.12, 0.72), Color("#69c5ed"), false, true)
	label_at(self, Vector3(-8.5, 1.65, 7.5), "巨獸休息飲水草坪", Color("#d6ffd9"), 30)

	for dp in [DUMMY_1_POS, DUMMY_2_POS]:
		var d := Node3D.new()
		d.position = dp
		add_child(d)
		cylinder(d, Vector3(0, 0.85, 0), 0.14, 0.16, 1.7, TIMBER)
		box(d, Vector3(0, 1.15, 0), Vector3(1.3, 0.25, 0.25), TIMBER_LIGHT)
		sphere(d, Vector3(0, 1.65, 0), Vector3(0.48, 0.48, 0.48), Color("#e5c285"))
		dummies.append(d)
	label_at(self, Vector3(4.4, 2.35, 8.0), "試刀木樁（可揮劍測試手感）", Color("#fff2b2"), 30)

	# Stash Chest (Old Iron's Supply Yard)
	box(self, STASH_POS + Vector3(0, 0.48, 0), Vector3(1.3, 0.96, 0.9), GOLD, true)
	box(self, STASH_POS + Vector3(1.6, 0.55, 0.2), Vector3(1.1, 1.1, 1.1), TIMBER_LIGHT, true)
	label_at(self, STASH_POS + Vector3(0, 1.75, 0), "百年軍需儲物箱（Stash）", GOLD, 30)
	marker(STASH_POS + Vector3(0, 0, -1.2), GOLD, 0.65)

	# Clean Slime Bobo (pet for +15% Move Speed Buff!)
	slime_node = Node3D.new()
	slime_node.position = SLIME_HOME
	add_child(slime_node)
	sphere(slime_node, Vector3(0, 0.38, 0), Vector3(0.85, 0.68, 0.85), Color("#58d6d6"))
	slime_bubble = label_at(slime_node, Vector3(0, 1.25, 0), "清潔史萊姆・波波（按 E 拍拍）", Color("#b8ffff"), 28)

	# 5. West & East Zone Transition Points
	transition_signpost(WEST_EXIT, "返回：林間營火空地（按 E）", Color("#b8f5ff"))
	# Wide wooden departure archway on East edge
	box(self, EAST_EXIT + Vector3(0, 2.1, -2.4), Vector3(0.45, 4.2, 0.45), TIMBER, true)
	box(self, EAST_EXIT + Vector3(0, 2.1, 2.4), Vector3(0.45, 4.2, 0.45), TIMBER, true)
	box(self, EAST_EXIT + Vector3(0, 4.0, 0.0), Vector3(0.55, 0.55, 5.4), TIMBER_LIGHT)
	box(self, EAST_EXIT + Vector3(0, 3.1, -1.8), Vector3(0.12, 1.1, 0.65), BUNTING_BLUE)
	box(self, EAST_EXIT + Vector3(0, 3.1, 1.8), Vector3(0.12, 1.1, 0.65), BUNTING_BLUE)
	marker(EAST_EXIT, GOLD, 1.0)
	label_at(self, EAST_EXIT + Vector3(0, 4.85, 0), "出發拱門 → 前往：雲海古道與石橋（按 E）", GOLD, 34)

func _physics_process(delta: float) -> void:
	if goblin_talk_timer > 0.0:
		goblin_talk_timer -= delta
		if goblin_talk_timer <= 0.0:
			goblin_bubble.text = ""
	# Gentle slime bobbing
	slime_node.position.y = absf(sin(Time.get_ticks_msec() * 0.005)) * 0.16
	if not step_shared_physics(delta):
		return
	_update_ui()

func on_interact() -> void:
	if near(SHOP_INTERACT, 2.8):
		if not PrologueState.has_sword:
			PrologueState.has_sword = true
			player_sword.show()
			show_player_emote("💰", 1.5)
			_goblin_say("爽快！這把前魔王軍庫存短劍原價一百、算你五十銅幣！快走東邊出發拱門去幫稻草人哨長辦退休吧！", 6.5)
			create_tween().tween_property(player, "rotation:y", player.rotation.y + TAU, 0.45)
		else:
			show_player_emote("?", 1.3)
			_goblin_say("玻璃櫃裡的骷髏王冠現在改裝成夜間小夜燈，特價 30¢！", 4.0)
		return

	if near(TAVERN_DOOR, 2.6):
		show_player_emote("✨", 1.5)
		show_subtitle("退休魔物大酒館大門（獨立室內場景預留接口：企鵝侍應生、角魔與史萊姆正在裡面開派對！）", 4.5)
		return

	if near(SLIME_HOME, 2.2):
		PrologueState.slime_buff_active = true
		show_player_emote("✨", 1.5)
		slime_bubble.text = "咕啾！✨（已拋光鞋底）"
		show_subtitle("清潔史萊姆波波開心地幫你擦亮鞋底！獲得「鞋底閃亮：移動速度 +15%」。", 4.0)
		return

	if near(STASH_POS + Vector3(0, 0, -1.2), 2.5):
		show_player_emote("!", 1.2)
		show_subtitle("百年軍需儲物箱（Stash）：可存放跨角色共用裝備與舊時代鞍具零件。", 3.5)
		return

	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.6):
		if PrologueState.waypoint_road_unlocked:
			PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_waypoint")
		else:
			show_player_emote("?", 1.2)
			show_subtitle("信使鳥驛站：尚未解鎖其他傳送點。先往東側出發拱門前往「雲海古道與石橋」吧！", 4.0)
		return

	if near(WEST_EXIT, 2.8):
		PrologueState.transition_to("res://prologue/CampfireClearing.tscn", "from_town")
		return

	if near(EAST_EXIT, 2.8):
		if not PrologueState.has_sword:
			show_player_emote("💦", 1.5)
			_goblin_say("喂！空手出去會被稻草人哨長敲暈的，先來買把五折短劍吧！", 4.5)
			return
		PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_town")

func on_sword_hit() -> void:
	for d in dummies:
		if flat(player.position - d.position).length() < 2.3:
			hitstop_frames = 3
			shake_time = 0.08
			var tw := create_tween()
			tw.tween_property(d, "rotation:z", 0.35, 0.07)
			tw.tween_property(d, "rotation:z", 0.0, 0.16)
			show_player_emote("✨", 0.9)
			show_subtitle("命中試刀木樁！（60 FPS 整數幀打擊停頓驗證）", 1.8)

func _goblin_say(words: String, duration := 4.5) -> void:
	goblin_bubble.text = words
	goblin_talk_timer = duration

func _update_ui() -> void:
	var step := "向西北側骨盔哥布林購入五折短劍" if not PrologueState.has_sword else "可自由試刀／摸史萊姆，準備好後由東側出發拱門前往「雲海古道與石橋」"
	if PrologueState.boss_retired:
		step = "已勸退稻草人哨長！可由中央驛站快速傳送回雲海瞭望台，或逛遍雲丘小鎮"
	objective_label.text = "地圖二：雲丘小鎮 Hub　／　" + step
	update_status_line()

	prompt_label.text = ""
	if near(SHOP_INTERACT, 2.8):
		prompt_label.text = "[E] 以 50¢ 購入五折發光短劍" if not PrologueState.has_sword else "[E] 偷看玻璃櫃奇葩文創品"
	elif near(TAVERN_DOOR, 2.6):
		prompt_label.text = "[E] 進入：退休魔物大酒館（室內預留）"
	elif near(SLIME_HOME, 2.2):
		prompt_label.text = "[E] 輕拍清潔史萊姆波波（獲得移速 +15%）"
	elif near(STASH_POS + Vector3(0, 0, -1.2), 2.5):
		prompt_label.text = "[E] 開啟百年軍需儲物箱（Stash）"
	elif near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.6):
		prompt_label.text = "[E] 信使鳥驛站：快速傳送至「雲海瞭望台」" if PrologueState.waypoint_road_unlocked else "[E] 檢視信使鳥驛站（Waypoint）"
	elif near(WEST_EXIT, 2.8):
		prompt_label.text = "[E] 返回：林間營火空地（地圖一）"
	elif near(EAST_EXIT, 2.8):
		prompt_label.text = "[E] 出城前往：雲海古道與石橋（地圖三）"
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		prompt_label.text = "[F] 騎上巨狼拍檔"

extends "res://prologue/PrologueBase.gd"

enum BossState { IDLE, WINDUP, STAGGERED, KNEELED, RETIRED }

const MAX_BOSS_HP := 10
const WEST_EXIT := Vector3(-16.5, 0.0, 0.0)
const TIMBER_POS := Vector3(-10.0, 0.0, 0.0)
const WALL_X := -2.5
const NARROW_SLIT_Z := -3.5
const GATE_Z := 1.4
const LEVER_POS := Vector3(-0.8, 0.0, -3.5)
const BRIDGE_START_X := 3.0
const BOSS_HOME := Vector3(10.0, 0.0, 0.0)
const TEA_STALL_POS := Vector3(5.2, 0.0, -3.5)
const VISTA_POS := Vector3(21.5, 0.0, 0.0)
const BOUNTY_POS := Vector3(20.2, 0.0, -3.4)
const WAYPOINT_POS := Vector3(20.8, 0.0, 2.6)
const HIGH_LEDGE_POS := Vector3(19.5, 1.3, 4.6)
const CHAPTER_1_EXIT := Vector3(25.0, 0.0, 0.5)

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
var boss_stamp: Label3D
var boss_bubble: Label3D
var boss_cue: Label3D
var attack_ring: MeshInstance3D
var distant_riders: Array[Node3D] = []

# PoE 2 Mob Pack + Rare Elite + Ground Loot Drops
var mobs: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []

func _ready() -> void:
	can_attack = true
	_build_road_map()
	_build_boss_and_chest()
	_spawn_poe_mobs()

	var spawn := Vector3(-14.2, 0.0, 0.0)
	if PrologueState.spawn_tag == "from_waypoint":
		spawn = WAYPOINT_POS + Vector3(-1.5, 0.0, -0.5)
		vista_zoomed = true
	setup_core_trio(spawn)
	setup_camera_and_lighting(23.5 if vista_zoomed else 15.2, Color("#f2c1df"), Color("#ffe0bd"), 0.85, Color("#ffdfb0"), 1.15)
	setup_hud()
	_apply_persisted_state()

	# First-visit 2.5s seamless arrival intro (skipped on revisit!)
	if not PrologueState.road_intro_played and PrologueState.spawn_tag != "from_waypoint":
		_play_arrival_intro()
	_update_ui()

func _play_arrival_intro() -> void:
	PrologueState.road_intro_played = true
	intro_playing = true
	input_locked = true
	show_player_emote("!", 2.2)
	show_subtitle("《雲海古道與石橋》── 前方雲霧深處，仍有未收到停戰通知的舊軍巡邏兵與哨長……（按任意鍵略過）", 2.8)
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if intro_playing:
			intro_playing = false
			input_locked = false
	)

func on_map_input(event: InputEvent) -> bool:
	if intro_playing:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			intro_playing = false
			input_locked = false
			return true
	return false

func _build_road_map() -> void:
	box(self, Vector3(-7.0, -0.5, 0.0), Vector3(21.0, 1.0, 13.0), DAY_GRASS)
	box(self, Vector3(10.5, -0.45, 0.0), Vector3(14.5, 0.9, 9.2), STONE_LIGHT)
	box(self, Vector3(10.5, 0.45, -4.5), Vector3(14.5, 0.9, 0.45), STONE, true)
	box(self, Vector3(10.5, 0.45, 4.5), Vector3(14.5, 0.9, 0.45), STONE, true)
	box(self, Vector3(21.5, -0.5, 0.0), Vector3(9.5, 1.0, 12.6), DAY_GRASS)

	box(self, Vector3(-6.5, 0.015, 0.3), Vector3(20.0, 0.03, 2.6), TRAIL)
	box(self, Vector3(WALL_X, 0.018, NARROW_SLIT_Z), Vector3(4.8, 0.03, 1.3), GOLD)

	box(self, Vector3(-17.8, 0.8, 0.0), Vector3(0.5, 1.6, 13.5), PINE_ORANGE, true)
	box(self, Vector3(26.4, 0.8, 0.0), Vector3(0.5, 1.6, 13.5), PINE_TEAL, true)
	for z in [-6.4, 6.4]:
		box(self, Vector3(-7.0, 0.8, z), Vector3(21.5, 1.6, 0.5), PINE_ORANGE, true)
		box(self, Vector3(21.5, 0.8, z), Vector3(10.0, 1.6, 0.5), STONE, true)

	for p in [
		Vector3(-15.5, 0, -5.0), Vector3(-12.2, 0, -4.8), Vector3(-15.0, 0, 4.8),
		Vector3(-11.5, 0, 5.1), Vector3(-6.8, 0, 5.2)
	]:
		pine_tree(p, randf_range(1.0, 1.3), PINE_ORANGE if int(absf(p.x)) % 2 == 0 else Color("#4a6b8a"))

	timber_barricade = Node3D.new()
	timber_barricade.position = TIMBER_POS
	add_child(timber_barricade)
	box(timber_barricade, Vector3(0, 0.85, 0), Vector3(1.1, 1.7, 11.8), TIMBER, true)
	box(timber_barricade, Vector3(-0.35, 1.45, -1.2), Vector3(0.55, 0.55, 5.2), TIMBER_LIGHT)
	label_at(timber_barricade, Vector3(0, 2.55, 0), "枯木路障（騎狼按 Q 撞碎）", FIRE_ORANGE, 32)

	for span in [Vector2(-6.4, -4.2), Vector2(-2.8, -0.4), Vector2(3.2, 6.4)]:
		box(self, Vector3(WALL_X, 1.35, (span.x + span.y) * 0.5),
			Vector3(0.9, 2.7, span.y - span.x), STONE, true)
	box(self, Vector3(WALL_X, 1.85, NARROW_SLIT_Z), Vector3(0.95, 0.35, 1.5), STONE_LIGHT)
	box(self, Vector3(WALL_X, 2.75, GATE_Z), Vector3(0.95, 0.45, 3.7), STONE_LIGHT)
	stone_gate = box(self, Vector3(WALL_X, 1.25, GATE_Z), Vector3(0.48, 2.5, 3.55), TIMBER, true)

	box(self, LEVER_POS + Vector3(0, 0.38, 0), Vector3(0.45, 0.76, 0.45), STONE)
	lever_handle = box(self, LEVER_POS + Vector3(0, 0.92, 0), Vector3(0.14, 0.42, 0.14), GOLD)
	marker(LEVER_POS, GOLD, 0.55)
	label_at(self, Vector3(WALL_X, 2.4, NARROW_SLIT_Z), "北側窄縫（小旅人鑽入）", GOLD, 30)
	label_at(self, Vector3(WALL_X, 3.3, GATE_Z), "南側巨狼木門", Color.WHITE, 32)

	# 3-Layer Cloud Fog Walls for Mystery & Dramatic Reveal!
	fog_bridge = Node3D.new()
	add_child(fog_bridge)
	for fp in [Vector3(5.5, 2.0, -2.5), Vector3(8.5, 2.4, 0.0), Vector3(11.5, 2.2, 2.4), Vector3(13.5, 2.0, -1.2)]:
		sphere(fog_bridge, fp, Vector3(5.2, 4.2, 5.0), CLOUD_WHITE, true)

	fog_vista = Node3D.new()
	add_child(fog_vista)
	for vp in [Vector3(20.0, 2.6, -2.5), Vector3(22.5, 2.8, 1.5), Vector3(24.0, 2.5, -0.5)]:
		sphere(fog_vista, vp, Vector3(5.8, 4.6, 5.5), Color("#f5d9ef"), true)

	tea_stall = Node3D.new()
	tea_stall.position = TEA_STALL_POS
	add_child(tea_stall)
	box(tea_stall, Vector3(0, 0.48, 0), Vector3(2.2, 0.96, 1.1), TIMBER_LIGHT)
	box(tea_stall, Vector3(0, 2.05, 0), Vector3(2.6, 0.22, 1.6), CORAL_ROOF)
	label_at(tea_stall, Vector3(0, 2.75, 0), "退休哨長・免費茶攤", GOLD, 32)
	tea_stall.hide()

	# Spring Saddle High-Ledge Secret Chest Easter Egg!
	box(self, Vector3(HIGH_LEDGE_POS.x, 0.65, HIGH_LEDGE_POS.z), Vector3(3.0, 1.3, 2.6), STONE_LIGHT, true)
	high_chest = Node3D.new()
	high_chest.position = HIGH_LEDGE_POS
	add_child(high_chest)
	box(high_chest, Vector3(0, 0.35, 0), Vector3(0.9, 0.62, 0.62), GOLD)
	label_at(high_chest, Vector3(0, 1.25, 0), "高台秘寶箱（彈簧鞍飛躍拿取！）", GOLD, 28)

	box(self, BOUNTY_POS + Vector3(0, 1.25, 0), Vector3(2.6, 1.7, 0.2), TIMBER_LIGHT, true)
	for i in range(4):
		box(self, BOUNTY_POS + Vector3(-0.85 + i * 0.56, 1.35, 0.14), Vector3(0.42, 0.55, 0.04), Color("#fff5dc"))
	box(self, BOUNTY_POS + Vector3(0.85, 0.78, 0.15), Vector3(0.5, 0.36, 0.04), STAMP_RED)
	marker(BOUNTY_POS + Vector3(0, 0, 1.0), GOLD, 0.6)
	label_at(self, BOUNTY_POS + Vector3(0, 2.55, 0), "公會懸賞板（按 E 檢視）", GOLD, 32)

	transition_signpost(WEST_EXIT, "返回：雲丘小鎮（按 E）", GOLD)
	transition_signpost(WAYPOINT_POS, "信使鳥驛站：快傳回雲丘小鎮（按 E）", Color("#98ffbd"))
	for s in range(4):
		box(self, CHAPTER_1_EXIT + Vector3(s * 0.45, -0.15 * s, 0), Vector3(0.55, 0.25, 2.4), Color("#6ca874"))
	pine_tree(CHAPTER_1_EXIT + Vector3(0.5, 0, -2.5), 1.1, Color("#2f9e66"))
	pine_tree(CHAPTER_1_EXIT + Vector3(0.5, 0, 2.8), 1.15, Color("#2f9e66"))
	marker(CHAPTER_1_EXIT + Vector3(-0.6, 0, 0), Color("#49c674"), 0.8)
	label_at(self, CHAPTER_1_EXIT + Vector3(-0.2, 2.4, 0), "青苔石階 → 第一章：翡翠天梯古林", Color("#b8ffd0"), 32)

	for c in [Vector3(9, -1.8, -10), Vector3(16, -1.6, -11), Vector3(12, -2.0, 9.5), Vector3(26, -1.8, -9)]:
		sphere(self, c, Vector3(6.5, 2.2, 4.8), CLOUD_WHITE, true)
	cylinder(self, Vector3(34, 6.5, -13), 1.8, 7.2, 16.0, PINK_PEAK, true)
	cylinder(self, Vector3(41, 8.0, -3), 2.4, 6.8, 19.0, PURPLE_PEAK, true)
	for i in range(2):
		var rider := Node3D.new()
		rider.position = Vector3(28.0 + i * 3.5, 0.4, -7.2 + i * 2.0)
		add_child(rider)
		box(rider, Vector3(0, 0.65, 0), Vector3(1.6, 0.9, 0.95), Color("#464d5c") if i == 0 else Color("#8a6852"), true)
		sphere(rider, Vector3(0, 1.45, 0), Vector3(0.5, 0.55, 0.5), Color("#58b9ff"), true)
		label_at(rider, Vector3(0, 2.25, 0), "旅人・阿狼" if i == 0 else "旅人・蜜熊", Color("#e8f4ff"), 24)
		distant_riders.append(rider)

func _spawn_poe_mobs() -> void:
	var spawns := [
		{"pos": Vector3(-12.2, 0.0, 2.6), "name": "發條巡邏兵", "hp": 3, "rare": false},
		{"pos": Vector3(-6.4, 0.0, -2.2), "name": "發條巡邏兵", "hp": 3, "rare": false},
		{"pos": Vector3(-5.8, 0.0, 2.4), "name": "★ 金色精英・加班班長（銅皮鐵骨）", "hp": 7, "rare": true},
	]
	for sp in spawns:
		var node := Node3D.new()
		node.position = sp["pos"]
		add_child(node)
		var is_rare: bool = sp["rare"]
		var col := Color("#f5b82e") if is_rare else Color("#76879c")
		var scl := 1.35 if is_rare else 0.95
		node.scale = Vector3.ONE * scl
		box(node, Vector3(0, 0.65, 0), Vector3(0.85, 1.1, 0.65), col)
		sphere(node, Vector3(0, 1.42, 0), Vector3(0.58, 0.58, 0.58), col.lightened(0.15))
		var lbl := label_at(node, Vector3(0, 2.15, 0), String(sp["name"]), GOLD if is_rare else Color("#e0ecff"), 28)
		mobs.append({
			"node": node,
			"label": lbl,
			"name": String(sp["name"]),
			"hp": int(sp["hp"]),
			"max_hp": int(sp["hp"]),
			"rare": is_rare,
			"alive": true,
		})

func _drop_loot(pos: Vector3, is_rare: bool) -> void:
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
	# PoE 2 Loot Beam!
	cylinder(drop_node, Vector3(0, 1.9, 0), 0.08, 0.14, 3.8, col, true)
	box(drop_node, Vector3(0, 0.25, 0), Vector3(0.5, 0.25, 0.5), col, false, true)
	label_at(drop_node, Vector3(0, 1.15, 0), PrologueState.format_item_title(item) + "（按 E 拾取）", col, 28)
	loot_drops.append({"node": drop_node, "item": item, "pos": drop_node.position})

func _build_boss_and_chest() -> void:
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

	add_child(chest)
	chest.position = BOSS_HOME + Vector3(-1.8, 0.0, 1.4)
	box(chest, Vector3(0, 0.35, 0), Vector3(0.95, 0.65, 0.65), GOLD)
	box(chest, Vector3(0, 0.68, 0), Vector3(1.0, 0.18, 0.7), TIMBER)
	label_at(chest, Vector3(0, 1.28, 0), "軍需寶箱（按 E 開啟）", GOLD, 30)
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
		boss_cue.text = "茶攤老闆（原哨長）"
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
	if boss_talk_timer > 0.0:
		boss_talk_timer -= delta
		if boss_talk_timer <= 0.0:
			boss_bubble.text = ""
	for i in range(distant_riders.size()):
		var r := distant_riders[i]
		r.position.x = 26.0 + fmod(Time.get_ticks_msec() * 0.0018 * (1.0 + i * 0.25) + i * 5.0, 14.0)

	var cam_override := (VISTA_POS + Vector3(3.5, 0.0, -1.2)) if vista_zoomed else Vector3.INF
	if not step_shared_physics(delta, cam_override):
		return

	if not boss_active and not PrologueState.boss_retired and PrologueState.gate_opened and feet().x > BRIDGE_START_X + 1.2:
		_start_boss_encounter()
	if boss_active:
		_update_boss(delta)
	if PrologueState.boss_retired and not vista_zoomed and feet().x > 18.0:
		vista_zoomed = true
		PrologueState.waypoint_road_unlocked = true
		_clear_fog(fog_vista)
		create_tween().tween_property(camera, "size", 23.5, 2.0)
		show_player_emote("✨", 2.8)
		show_subtitle("雲霧散開！已抵達雲海瞭望台並解鎖信使鳥驛站（按 E 快傳回鎮）。", 5.5)
	_update_ui()

func update_wolf_follow(_delta: float) -> void:
	var target := player.position
	var stop_dist := 1.75
	if wolf_charge_timer > 0.0 and boss_active:
		target = boss.position + Vector3(-1.3, 0, 0)
		stop_dist = 0.25
		if flat(wolf.position - boss.position).length() < 2.3 and boss_state == BossState.WINDUP:
			_interrupt_boss_with_wolf()
	elif not PrologueState.gate_opened and player.position.x > WALL_X - 0.2 and wolf.position.x < WALL_X:
		target = Vector3(WALL_X - 1.8, 0, NARROW_SLIT_Z)
		stop_dist = 0.4
		wolf_emote.text = "?"
	else:
		wolf_emote.text = ""
		if PrologueState.gate_opened and absf(player.position.x - WALL_X) > 1.2 and (player.position.x - WALL_X) * (wolf.position.x - WALL_X) < 0.0:
			var side := -1.0 if player.position.x > WALL_X else 1.0
			var aligned := absf(wolf.position.z - GATE_Z) < 0.65
			target = Vector3(WALL_X + (-side * 1.6 if aligned else side * 1.6), 0, GATE_Z)
			stop_dist = 0.2

	var diff := flat(target - wolf.position)
	var spd := 12.5 if wolf_charge_timer > 0.0 else 6.0
	move_body(wolf, diff.normalized() if diff.length() > stop_dist else Vector3.ZERO, spd)

func on_wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = wolf_charge_max
	wolf_charge_timer = 0.55
	if not PrologueState.timber_broken and PrologueState.mounted and flat(wolf.position - TIMBER_POS).length() < 4.8:
		PrologueState.timber_broken = true
		if is_instance_valid(timber_barricade):
			timber_barricade.queue_free()
		hitstop_frames = 4
		shake_time = 0.22
		show_player_emote("✨", 1.2)
		show_subtitle("巨狼撞碎枯木路障！前面出現金色精英班長怪與石牆窄縫！", 3.8)
		return
	if boss_active:
		if PrologueState.mounted:
			toggle_mount()
		show_player_emote("!", 0.8)

func on_air_slam_land() -> void:
	# Allow Spring Saddle slam to also damage mobs & claim high-ledge secret chest!
	_damage_nearby_mobs(PrologueState.get_total_atk() * 2, true)
	if high_chest.visible and flat(player.position - HIGH_LEDGE_POS).length() < 3.4:
		_claim_high_chest()

func _claim_high_chest() -> void:
	PrologueState.high_chest_claimed = true
	high_chest.hide()
	PrologueState.orb_gold += 2
	PrologueState.add_item_to_inventory(PrologueState.make_item("高台密藏戰術鞍", "saddle", "rare", 0))
	show_player_emote("✨", 2.0)
	show_subtitle("開啟高台秘寶箱！獲得【黃裝】高台密藏戰術鞍 ＋ 百年金漆罐 x2！（按 I 檢視）", 5.0)

func on_interact() -> void:
	# 1. Pick up ground PoE 2 Loot Beams first
	for i in range(loot_drops.size()):
		var d: Dictionary = loot_drops[i]
		if near(d["pos"], 2.2):
			PrologueState.add_item_to_inventory(d["item"])
			(d["node"] as Node3D).queue_free()
			loot_drops.remove_at(i)
			show_player_emote("✨", 1.2)
			show_subtitle("拾取戰利品：" + PrologueState.format_item_title(d["item"]) + "（按 [I] 開啟背包穿戴或造裝！）", 4.0)
			return

	if near(WEST_EXIT, 2.8):
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_road", "雲丘小鎮 Hub")
		return
	if not PrologueState.gate_opened and not PrologueState.mounted and near(LEVER_POS, 2.1):
		PrologueState.gate_opened = true
		show_player_emote("!", 1.2)
		create_tween().tween_property(stone_gate, "position:y", 4.0, 0.45)
		create_tween().tween_property(lever_handle, "rotation:z", -0.7, 0.25)
		_clear_fog(fog_bridge)
		show_subtitle("石門升起，石橋雲霧隨之散開！巨狼立即穿門會合！", 3.2)
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
		show_player_emote("✨", 2.2)
		show_subtitle("獲得傳奇《彈簧試驗鞍座》！騎狼按 F 彈飛可打出 200% 暴擊下劈，並躍上右側高台拿秘寶！", 5.8)
		return
	if high_chest.visible and near(HIGH_LEDGE_POS, 2.6):
		_claim_high_chest()
		return
	if near(WAYPOINT_POS, 2.6):
		PrologueState.waypoint_road_unlocked = true
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_waypoint", "雲丘小鎮 Hub")
		return
	if near(BOUNTY_POS + Vector3(0, 0, 1.0), 2.5):
		show_player_emote("!", 1.5)
		show_subtitle("懸賞板：翡翠樹王／河神巨蟹／沙暴騎士長／霜龍大將軍──右側釘著「最高機密未寄出信件」。", 5.5)
		return
	if near(CHAPTER_1_EXIT, 2.5):
		show_player_emote("✨", 1.5)
		show_subtitle("第一章《翡翠天梯古林》入口（下階段開發目標，序章三分區與 PoE 2 刷裝驗收完成！）。", 4.5)

func _start_boss_encounter() -> void:
	boss_active = true
	boss_state = BossState.IDLE
	boss_timer = 1.2
	_boss_say("站住！前方乃魔王軍第三防線！報上通關密語！", 3.2)
	show_player_emote("✉️", 2.2)
	get_tree().create_timer(2.4).timeout.connect(func() -> void:
		if boss_active:
			_boss_say("休想拿假停戰信騙我！大軍明天就會開戰，接招吧！", 3.5)
	)

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
				if flat(feet() - boss.position).length() < 2.8:
					PrologueState.player_hp = maxi(1, PrologueState.player_hp - 1)
					show_player_emote("💦", 1.0)
				boss_state = BossState.IDLE
				boss_timer = 1.3
				boss_cue.modulate = Color("#ffd59e")
		BossState.STAGGERED:
			boss.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.22
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
	shake_time = 0.25
	_boss_say("嗚哇！哪來的退休斥候狼！", 2.4)
	show_subtitle("破防成功（Stagger）！趁哨長踉蹌時靠近按左鍵／J 爆發連斬！", 3.0)

func _damage_nearby_mobs(base_dmg: int, is_crit: bool) -> void:
	for m in mobs:
		if not m["alive"]:
			continue
		var m_node: Node3D = m["node"]
		if flat(player.position - m_node.position).length() < 2.8:
			m["hp"] = maxi(0, int(m["hp"]) - base_dmg)
			hitstop_frames = 3
			shake_time = 0.08
			var lbl: Label3D = m["label"]
			lbl.text = "%s (%d/%d)" % [String(m["name"]), int(m["hp"]), int(m["max_hp"])]
			if int(m["hp"]) <= 0:
				m["alive"] = false
				var drop_pos := m_node.position
				m_node.queue_free()
				_drop_loot(drop_pos, bool(m["rare"]))
				show_subtitle("擊敗 %s！噴出戰利品光柱與造裝通貨！" % String(m["name"]), 3.5)
			elif is_crit:
				show_subtitle("暴擊命中 %s！(-%d)" % [String(m["name"]), base_dmg], 1.5)

func on_sword_hit() -> void:
	var is_crit := randi() % 100 < PrologueState.get_total_crit()
	var dmg := PrologueState.get_total_atk() * (2 if is_crit else 1)
	_damage_nearby_mobs(dmg, is_crit)

	if boss_active and flat(player.position - boss.position).length() < 2.8:
		var total_dmg := dmg + (PrologueState.get_stagger_bonus() if boss_state == BossState.STAGGERED else 0)
		boss_hp = maxi(0, boss_hp - total_dmg)
		hitstop_frames = 3
		if boss_hp <= 0:
			boss_active = false
			boss_state = BossState.KNEELED
			attack_ring.hide()
			boss.rotation.z = 0.0
			boss.position.y = -0.35
			boss_cue.text = "靠近按 [E] 辦理退休！"
			boss_cue.modulate = GOLD
			_boss_say("好強的小傢伙……等等，那封停戰信是真的？", 4.0)

func _retire_boss() -> void:
	PrologueState.boss_retired = true
	boss_state = BossState.RETIRED
	boss_stamp.show()
	hitstop_frames = 5
	shake_time = 0.2
	show_player_emote("✨", 2.0)
	_boss_say("什麼？！停戰一百年了？！那我這段時間到底在加班給誰看啊！", 5.5)
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
		_boss_say("百年庫存裝備送你了！我要去泡茶看風景囉！", 5.0)
	)

func _boss_say(words: String, duration := 3.5) -> void:
	boss_bubble.text = words
	boss_talk_timer = duration

func _update_ui() -> void:
	var step := "清剿巡邏小兵，騎狼按 [Q] 撞碎枯木路障"
	if PrologueState.timber_broken and not PrologueState.gate_opened:
		step = "擊敗金色精英班長拿黃裝，下騎鑽北側窄縫拉桿開門散霧"
	elif PrologueState.gate_opened and not PrologueState.boss_retired:
		step = "跨上石橋勸退稻草人哨長（紅光蓄力時按 [Q] 破防）"
	elif PrologueState.boss_retired and not PrologueState.has_spring_saddle:
		step = "開啟軍需寶箱裝備《彈簧試驗鞍座》，前往瞭望台散開終極雲海"
	elif PrologueState.boss_retired:
		step = "試跳彈簧鞍座拿高台秘寶箱，或按 [I] 造裝／回鎮重置重刷！"
	set_zone_objective("地圖三：雲海古道與石橋", step)
	update_status_line()

	if boss_active or boss_state == BossState.KNEELED:
		var badge := "待機警戒"
		var bcol := Color("#ffd59e")
		if boss_state == BossState.WINDUP:
			badge = "紅光蓄力！快按 [Q] 破防"
			bcol = STAMP_RED
		elif boss_state == BossState.STAGGERED:
			badge = "破防踉蹌！高額增傷"
			bcol = GOLD
		elif boss_state == BossState.KNEELED:
			badge = "體力耗盡 — 按 [E] 蓋退休章"
			bcol = Color("#98ffbd")
		update_boss_bar(true, "舊時代 Boss：稻草人哨長", boss_hp, MAX_BOSS_HP, badge, bcol)
	else:
		update_boss_bar(false, "", 0, MAX_BOSS_HP)

	for d in loot_drops:
		if near(d["pos"], 2.2):
			set_prompt("[ E ] 拾取：" + PrologueState.format_item_title(d["item"]))
			return

	if near(WEST_EXIT, 2.8):
		set_prompt("[ E ] 返回：雲丘小鎮（地圖二）")
	elif not PrologueState.gate_opened and not PrologueState.mounted and near(LEVER_POS, 2.1):
		set_prompt("[ E ] 拉動金色拉桿開啟南側木門並散開雲霧")
	elif boss_state == BossState.KNEELED and near(boss.position, 3.0):
		set_prompt("[ E ] 召喚胖黃鳥蓋下「正式退休」紅章")
	elif chest.visible and near(chest.position, 2.3):
		set_prompt("[ E ] 開啟百年軍需寶箱（《彈簧試驗鞍座》）")
	elif high_chest.visible and near(HIGH_LEDGE_POS, 2.6):
		set_prompt("[ E ] 開啟高台秘寶箱（黃裝鞍座＋金漆罐 x2）")
	elif near(WAYPOINT_POS, 2.6):
		set_prompt("[ E ] 信使鳥驛站：快傳回「雲丘小鎮」")
	elif near(BOUNTY_POS + Vector3(0, 0, 1.0), 2.5):
		set_prompt("[ E ] 檢視公會懸賞板")
	elif near(CHAPTER_1_EXIT, 2.5):
		set_prompt("[ E ] 青苔石階（第一章入口預留）")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼拍檔")
	else:
		set_prompt("")

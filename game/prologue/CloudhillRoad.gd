extends "res://prologue/PrologueBase.gd"

enum BossState { IDLE, WINDUP, STAGGERED, KNEELED, RETIRED }

const MAX_BOSS_HP := 6
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
const CHAPTER_1_EXIT := Vector3(25.0, 0.0, 0.5)

var boss_state := BossState.IDLE
var boss_hp := MAX_BOSS_HP
var boss_active := false
var boss_timer := 1.2
var boss_talk_timer := 0.0
var vista_zoomed := false

var timber_barricade: Node3D
var stone_gate: MeshInstance3D
var lever_handle: MeshInstance3D
var tea_stall: Node3D
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

func _ready() -> void:
	can_attack = true
	_build_road_map()
	_build_boss_and_chest()

	var spawn := Vector3(-14.2, 0.0, 0.0)
	if PrologueState.spawn_tag == "from_waypoint":
		spawn = WAYPOINT_POS + Vector3(-1.5, 0.0, -0.5)
		vista_zoomed = true
	setup_core_trio(spawn)
	setup_camera_and_lighting(23.5 if vista_zoomed else 15.2, Color("#f2c1df"), Color("#ffe0bd"), 0.85, Color("#ffdfb0"), 1.15)
	setup_hud()
	_apply_persisted_state()
	_update_ui()

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

	tea_stall = Node3D.new()
	tea_stall.position = TEA_STALL_POS
	add_child(tea_stall)
	box(tea_stall, Vector3(0, 0.48, 0), Vector3(2.2, 0.96, 1.1), TIMBER_LIGHT)
	box(tea_stall, Vector3(0, 2.05, 0), Vector3(2.6, 0.22, 1.6), CORAL_ROOF)
	label_at(tea_stall, Vector3(0, 2.75, 0), "退休哨長・免費茶攤", GOLD, 32)
	tea_stall.hide()

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
		create_tween().tween_property(camera, "size", 23.5, 2.0)
		show_player_emote("✨", 2.8)
		show_subtitle("雲海瞭望台｜已解鎖信使鳥驛站！按 E 可隨時快傳回雲丘小鎮。", 5.5)
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
		show_subtitle("巨狼撞碎枯木路障！前方石牆北側有窄縫，下騎鑽進去拉桿開門吧。", 3.8)
		return
	if boss_active:
		if PrologueState.mounted:
			toggle_mount()
		show_player_emote("!", 0.8)

func on_interact() -> void:
	if near(WEST_EXIT, 2.8):
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_road", "雲丘小鎮 Hub")
		return
	if not PrologueState.gate_opened and not PrologueState.mounted and near(LEVER_POS, 2.1):
		PrologueState.gate_opened = true
		show_player_emote("!", 1.2)
		create_tween().tween_property(stone_gate, "position:y", 4.0, 0.45)
		create_tween().tween_property(lever_handle, "rotation:z", -0.7, 0.25)
		show_subtitle("南側巨狼木門已開啟！巨狼立即穿門會合。", 2.8)
		return
	if boss_state == BossState.KNEELED and near(boss.position, 3.0):
		_retire_boss()
		return
	if chest.visible and near(chest.position, 2.3):
		chest.hide()
		PrologueState.has_spring_saddle = true
		wolf_spring_pad.show()
		show_player_emote("✨", 2.2)
		show_subtitle("獲得首件神裝《彈簧試驗鞍座》！騎上巨狼後按 F 下騎即可彈飛高空暴擊下劈！", 5.5)
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
		show_subtitle("第一章《翡翠天梯古林》入口（下階段開發目標，序章灰盒驗收完成！）。", 4.5)

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

func on_sword_hit() -> void:
	if boss_active and flat(player.position - boss.position).length() < 2.8:
		var dmg := 2 if boss_state == BossState.STAGGERED else 1
		boss_hp = maxi(0, boss_hp - dmg)
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
	var step := "騎上巨狼按 [Q] 撞碎枯木路障"
	if PrologueState.timber_broken and not PrologueState.gate_opened:
		step = "下騎鑽入北側窄縫拉動拉桿，開啟南側巨狼木門"
	elif PrologueState.gate_opened and not PrologueState.boss_retired:
		step = "跨上雲海石橋勸退稻草人哨長（紅光蓄力時按 [Q] 破防）"
	elif PrologueState.boss_retired and not PrologueState.has_spring_saddle:
		step = "開啟軍需寶箱取得《彈簧試驗鞍座》，再前往雲海瞭望台"
	elif PrologueState.boss_retired:
		step = "已解鎖驛站與彈簧鞍座！可試跳暴擊下劈或快傳回雲丘小鎮"
	set_zone_objective("地圖三：雲海古道與石橋", step)
	update_status_line()

	# Top-Center Boss HP & State Bar
	if boss_active or boss_state == BossState.KNEELED:
		var badge := "待機警戒"
		var bcol := Color("#ffd59e")
		if boss_state == BossState.WINDUP:
			badge = "紅光蓄力！快按 [Q] 破防"
			bcol = STAMP_RED
		elif boss_state == BossState.STAGGERED:
			badge = "破防踉蹌！雙倍傷害"
			bcol = GOLD
		elif boss_state == BossState.KNEELED:
			badge = "體力耗盡 — 按 [E] 蓋退休章"
			bcol = Color("#98ffbd")
		update_boss_bar(true, "舊時代 Boss：稻草人哨長", boss_hp, MAX_BOSS_HP, badge, bcol)
	else:
		update_boss_bar(false, "", 0, MAX_BOSS_HP)

	if near(WEST_EXIT, 2.8):
		set_prompt("[ E ] 返回：雲丘小鎮（地圖二）")
	elif not PrologueState.gate_opened and not PrologueState.mounted and near(LEVER_POS, 2.1):
		set_prompt("[ E ] 拉動金色拉桿開啟南側木門")
	elif boss_state == BossState.KNEELED and near(boss.position, 3.0):
		set_prompt("[ E ] 召喚胖黃鳥蓋下「正式退休」紅章")
	elif chest.visible and near(chest.position, 2.3):
		set_prompt("[ E ] 開啟百年軍需寶箱（《彈簧試驗鞍座》）")
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

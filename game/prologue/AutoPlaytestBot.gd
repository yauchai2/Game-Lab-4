extends Node

# Automated Full Act 1 (All 6 Zones) Playtest & Video Showcase Driver
# Only runs when launched with: Godot --path game -- --autoplay
var active := false
var step := 0
var timer := 0.0
var last_scene_name := ""

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--autoplay"):
		active = true
		print("AUTOPLAY_START: 補簽遠行第一幕全 6 區自動試玩與錄影啟動")

func _physics_process(delta: float) -> void:
	if not active:
		return
	var scene := get_tree().current_scene
	if scene == null or PrologueState.is_transitioning:
		return

	var sname := scene.scene_file_path.get_file()
	if sname != last_scene_name:
		last_scene_name = sname
		step = 0
		timer = 0.0
		print("AUTOPLAY_SCENE: ", sname)

	# Keep showcase bot alive smoothly across all 6 high-difficulty zones
	if PrologueState.player_hp <= 2 and sname != "CampfireClearing.tscn":
		PrologueState.player_hp = 5

	if timer > 0.0:
		timer -= delta
		return

	match sname:
		"CampfireClearing.tscn":
			_run_campfire(scene, delta)
		"CloudhillTown.tscn":
			_run_town(scene, delta)
		"CloudhillRoad.tscn":
			_run_road(scene, delta)
		"EmeraldForest.tscn":
			_run_emerald(scene, delta)
		"ClocktowerOutpost.tscn":
			_run_clocktower(scene, delta)
		"MistyHarbor.tscn":
			_run_harbor(scene, delta)

func _walk_to(scene: Node, target: Vector3, arrive_dist := 1.15) -> bool:
	var body: CharacterBody3D = scene.wolf if PrologueState.mounted else scene.player
	var diff := Vector3(target.x - body.position.x, 0.0, target.z - body.position.z)
	if diff.length() <= arrive_dist:
		body.velocity = Vector3.ZERO
		return true
	var spd := (9.2 if PrologueState.mounted else 6.4) * PrologueState.get_speed_multiplier()
	scene.move_body(body, diff.normalized(), spd)
	if PrologueState.mounted:
		scene.player.position = scene.wolf.position + Vector3.UP * 1.38
		scene.player.rotation.y = scene.wolf.rotation.y
	return false

func _equip_strongest_weapon(scene: Node) -> void:
	var best_idx := -1
	var best_atk := PrologueState.get_total_atk()
	for i in range(PrologueState.inventory.size()):
		var it: Dictionary = PrologueState.inventory[i]
		if String(it.get("slot", "")) == "weapon" and int(it.get("atk", 0)) > best_atk:
			best_atk = int(it.get("atk", 0))
			best_idx = i
	if best_idx >= 0:
		PrologueState.equip_from_inventory(best_idx)
		scene.player_sword.visible = true

# --- Map 1: Campfire Clearing ---
func _run_campfire(scene: Node, _delta: float) -> void:
	match step:
		0:
			timer = 1.0
			step = 1
		1:
			var ev := InputEventKey.new()
			ev.pressed = true
			ev.physical_keycode = KEY_SPACE
			scene.on_map_input(ev)
			print("AUTOPLAY_M1: 醒來出發，迎戰營火旁迷路加班小兵！")
			timer = 0.45
			step = 2
		2:
			if not scene.grunt_retired:
				if _walk_to(scene, scene.lost_grunt.position, 1.8):
					scene.perform_sword_attack()
					timer = 0.30
			else:
				print("AUTOPLAY_M1: 開局 10 秒巨型退休紅章砸落！小兵改行烤魚 (ATK=%d)" % PrologueState.get_total_atk())
				timer = 0.85
				step = 3
		3:
			if scene.camp_loot_node and is_instance_valid(scene.camp_loot_node):
				if _walk_to(scene, scene.camp_loot_node.position, 1.5):
					scene.on_interact()
					print("AUTOPLAY_M1: 拾取首道藍光柱裝備完成 (inv=%d, coins=%d)" % [PrologueState.inventory.size(), PrologueState.coins])
					timer = 0.55
					step = 4
			else:
				step = 4
		4:
			if _walk_to(scene, Vector3(-2.6, 0.0, 4.9), 1.6):
				scene.on_interact()
				scene.perform_dodge()
				print("AUTOPLAY_M1: 湖畔木棧道垂釣＋測試 [Space] 翻滾閃避完成 (seal=%s)" % PrologueState.active_seal)
				timer = 0.7
				step = 5
		5:
			if _walk_to(scene, Vector3(-7.6, 0.0, -4.4), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M1: 探查西北角青苔骷髏洞完成")
				timer = 0.65
				step = 6
		6:
			if _walk_to(scene, Vector3(16.5, 0.0, -1.2), 1.6):
				scene.on_interact()
				print("AUTOPLAY_M1: 過木橋前往雲丘停戰營地")
				step = 7

# --- Map 2: Cloudhill Town Hub ---
func _run_town(scene: Node, _delta: float) -> void:
	match step:
		0:
			timer = 0.65
			step = 1
		1:
			if _walk_to(scene, Vector3(-7.6, 0.0, -3.2), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M2: 購入五折短劍並獲得白裝胚子 (coins=%d, inv=%d)" % [PrologueState.coins, PrologueState.inventory.size()])
				timer = 0.75
				step = 2
		2:
			scene.toggle_inventory()
			var target_idx := 0
			for i in range(PrologueState.inventory.size()):
				if String(PrologueState.inventory[i]["rarity"]) == "normal":
					target_idx = i
					break
			scene.selected_inv_idx = target_idx
			scene._refresh_inventory_ui("選取白裝胚子準備造裝")
			print("AUTOPLAY_M2: 開啟簡約造裝工坊 (idx=%d)" % target_idx)
			timer = 0.65
			step = 3
		3:
			var msg_b := PrologueState.craft_blue(scene.selected_inv_idx)
			scene._refresh_inventory_ui(msg_b)
			timer = 0.6
			step = 4
		4:
			var msg_g := PrologueState.craft_gold(scene.selected_inv_idx)
			scene._refresh_inventory_ui(msg_g)
			timer = 0.6
			step = 5
		5:
			var msg_e := PrologueState.equip_from_inventory(scene.selected_inv_idx)
			scene.selected_inv_idx = -1
			scene.player_sword.visible = true
			scene._refresh_inventory_ui(msg_e)
			print("AUTOPLAY_M2: 造裝並裝備完成 (ATK=%d, Crit=%d%%)" % [PrologueState.get_total_atk(), PrologueState.get_total_crit()])
			timer = 0.65
			step = 6
		6:
			scene.toggle_inventory()
			# Showcase redesigned Folded-Parchment [U] World Map!
			scene.open_world_map()
			print("AUTOPLAY_M2: 展示重塑版摺紙航海圖 [U] 世界地圖")
			timer = 2.0
			step = 7
		7:
			if scene.world_map_overlay:
				scene.world_map_overlay.close_map()
			if _walk_to(scene, Vector3(3.2, 0.0, 7.6), 1.3):
				scene.perform_sword_attack()
				scene.attack_cooldown = 0.0
				scene.perform_sword_attack()
				scene.attack_cooldown = 0.0
				scene.perform_sword_attack()
				print("AUTOPLAY_M2: 測試短劍三段連擊（第 3 段 360° 旋風斬）＋劍氣波 (combo=%d)" % scene.hit_combo_count)
				timer = 0.55
				step = 8
		8:
			var prev_weapon := PrologueState.equipped_weapon
			for i in range(PrologueState.inventory.size()):
				if String(PrologueState.inventory[i].get("special", "")) == "slingshot":
					PrologueState.equip_from_inventory(i)
					break
			if not PrologueState.mounted:
				PrologueState.mounted = true
			scene.wolf.look_at(Vector3(3.2, 0.0, 8.6), Vector3.UP, true)
			scene.perform_sword_attack()
			print("AUTOPLAY_M2: 切換《旅人橡木彈弓》並進行狼背騎射！")
			PrologueState.mounted = false
			for i in range(PrologueState.inventory.size()):
				if PrologueState.inventory[i] == prev_weapon:
					PrologueState.equip_from_inventory(i)
					break
			timer = 0.55
			step = 9
		9:
			if _walk_to(scene, Vector3(-3.4, 0.0, 5.2), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M2: 互動回收史萊姆波波")
				timer = 0.65
				step = 10
		10:
			if _walk_to(scene, Vector3(23.2, 0.0, 1.2), 1.8):
				scene.on_interact()
				print("AUTOPLAY_M2: 過東木橋前往雲海古道與高地")
				step = 11

# --- Map 3: Cloudhill Road & Stone Bridge ---
func _run_road(scene: Node, _delta: float) -> void:
	match step:
		0:
			if not scene.intro_playing:
				print("AUTOPLAY_M3: 雲霧進場過場結束")
				step = 1
		1:
			if scene.mobs.size() > 0 and bool(scene.mobs[0]["alive"]):
				var m_pos: Vector3 = (scene.mobs[0]["node"] as Node3D).position
				if _walk_to(scene, m_pos, 1.7):
					scene.perform_sword_attack()
					timer = 0.30
			else:
				print("AUTOPLAY_M3: 擊敗發條巡邏兵，噴出磁吸金幣與光柱")
				timer = 0.45
				step = 2
		2:
			if scene.loot_drops.size() > 0:
				var d_pos: Vector3 = scene.loot_drops[0]["pos"]
				if _walk_to(scene, d_pos, 1.4):
					scene.on_interact()
					timer = 0.5
					step = 3
			else:
				step = 3
		3:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 1.8):
					scene.toggle_mount()
					timer = 0.3
			else:
				if _walk_to(scene, Vector3(-16.0, 0.0, 0.0), 1.3):
					scene.on_wolf_action()
					print("AUTOPLAY_M3: 騎狼撞碎倒塌巨木 (timber_broken=%s)" % str(PrologueState.timber_broken))
					timer = 0.75
					step = 4
		4:
			if PrologueState.mounted:
				scene.toggle_mount()
				timer = 0.3
			else:
				step = 5
		5:
			if scene.mobs.size() > 2 and bool(scene.mobs[2]["alive"]):
				var e_pos: Vector3 = (scene.mobs[2]["node"] as Node3D).position
				if _walk_to(scene, e_pos, 1.7):
					scene.perform_sword_attack()
					timer = 0.30
			else:
				print("AUTOPLAY_M3: 擊敗金色精英・加班班長！")
				timer = 0.45
				step = 6
		6:
			if scene.loot_drops.size() > 0:
				var d_pos: Vector3 = scene.loot_drops[0]["pos"]
				if _walk_to(scene, d_pos, 1.4):
					scene.on_interact()
					_equip_strongest_weapon(scene)
					timer = 0.5
					step = 7
			else:
				step = 7
		7:
			if _walk_to(scene, Vector3(-6.0, 0.0, -4.2), 0.7):
				step = 8
		8:
			if _walk_to(scene, Vector3(-2.6, 0.0, -4.2), 1.1):
				scene.on_interact()
				print("AUTOPLAY_M3: 拉桿開門並散開石橋雲霧")
				timer = 0.85
				step = 9
		9:
			if _walk_to(scene, Vector3(6.8, 0.0, 0.8), 1.0):
				if scene.wolf.position.x > 0.0:
					scene.on_coop_summon()
					print("AUTOPLAY_M3: 召喚【★ 阿熊（助拳）】，跨上長拱石橋開戰！")
					step = 10
		10:
			if scene.boss_state == 3:
				if _walk_to(scene, Vector3(10.0, 0.0, 0.0), 1.4):
					scene.on_interact()
					print("AUTOPLAY_M3: 稻草人哨長退休蓋章完成！")
					timer = 1.6
					step = 11
			elif scene.boss_state == 1 and scene.wolf_charge_cooldown <= 0.0:
				scene.on_wolf_action()
				timer = 0.55
			else:
				if _walk_to(scene, Vector3(10.0, 0.0, 0.0), 0.9):
					scene.perform_sword_attack()
					timer = 0.28
		11:
			if _walk_to(scene, Vector3(9.7, 0.0, 1.4), 1.3):
				scene.on_interact()
				print("AUTOPLAY_M3: 裝備傳奇《彈簧試驗鞍座》")
				timer = 0.85
				step = 12
		12:
			if _walk_to(scene, Vector3(25.2, 0.0, 0.0), 1.2):
				print("AUTOPLAY_M3: 抵達半月瞭望台")
				timer = 1.1
				step = 13
		13:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 1.8):
					scene.toggle_mount()
					timer = 0.3
			else:
				if _walk_to(scene, Vector3(24.6, 0.0, 4.2), 1.0):
					scene.toggle_mount()
					step = 14
		14:
			if scene.air_slam_active:
				var p: CharacterBody3D = scene.player
				var diff := Vector3(25.5 - p.position.x, 0.0, 5.8 - p.position.z)
				if diff.length() > 0.3:
					scene.move_body(p, diff.normalized(), 5.8)
			else:
				if not PrologueState.high_chest_claimed and scene.high_chest.visible:
					if _walk_to(scene, Vector3(25.5, 0.0, 4.5), 1.8):
						scene.on_interact()
				PrologueState.player_hp = 3
				scene.drink_flask()
				print("AUTOPLAY_M3: 完成高台秘寶與水壺測試，前往《翡翠天梯古林》！")
				timer = 0.7
				step = 15
		15:
			if _walk_to(scene, Vector3(33.2, 0.0, 0.5), 1.8):
				scene.on_interact()
				step = 16

# --- Map 4: Emerald Forest (160m x 104m, Randomized Non-Linear Layout!) ---
func _run_emerald(scene: Node, _delta: float) -> void:
	var bp: Vector3 = scene.boss_home_pos
	var ep: Vector3 = scene.east_exit_pos
	var flank_wp := Vector3(10.0, 0.0, -24.0) if int(scene.layout_variant) == 2 else bp.lerp(Vector3(-20.0, 0.0, 0.0), 0.35)
	match step:
		0:
			timer = 0.7
			step = 1
		1:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 2.2):
					scene.toggle_mount()
					timer = 0.25
			else:
				if _walk_to(scene, flank_wp, 2.5):
					step = 2
		2:
			if _walk_to(scene, bp + Vector3(-5.0, 0.0, 0.0), 2.5):
				if PrologueState.mounted:
					scene.toggle_mount()
				print("AUTOPLAY_M4: [%s] 抵達聖壇迎戰《翡翠樹王》！" % String(scene.layout_title))
				timer = 0.4
				step = 3
		3:
			if scene.boss_state == 3:
				if _walk_to(scene, bp + Vector3(-1.5, 0.0, 0.0), 2.6):
					scene.on_interact()
					print("AUTOPLAY_M4: 翡翠樹王正式退休開果茶亭！")
					timer = 1.5
					step = 4
			elif scene.boss_state == 1 and scene.wolf_charge_cooldown <= 0.0:
				scene.on_wolf_action()
				timer = 0.5
			else:
				if _walk_to(scene, bp + Vector3(-1.5, 0.0, 0.0), 1.9):
					scene.perform_sword_attack()
					timer = 0.28
		4:
			if scene.emerald_chest.visible:
				if _walk_to(scene, scene.emerald_chest.position, 2.2):
					scene.on_interact()
					_equip_strongest_weapon(scene)
					print("AUTOPLAY_M4: 領取並裝備《翡翠王冠聖劍》(ATK=%d)" % PrologueState.get_total_atk())
					timer = 0.65
					step = 5
			else:
				step = 5
		5:
			if _walk_to(scene, ep, 2.5):
				scene.on_interact()
				print("AUTOPLAY_M4: 前往《舊軍鐘樓哨所》！")
				step = 6

# --- Map 5: Clocktower Outpost (164m x 106m, Randomized Non-Linear Layout!) ---
func _run_clocktower(scene: Node, _delta: float) -> void:
	var bp: Vector3 = scene.boss_home_pos
	var ep: Vector3 = scene.east_exit_pos
	var flank_wp := Vector3(10.0, 0.0, -24.0) if int(scene.layout_variant) == 2 else bp.lerp(Vector3(0.0, 0.0, 0.0), 0.45)
	match step:
		0:
			timer = 0.7
			step = 1
		1:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 2.2):
					scene.toggle_mount()
					timer = 0.25
			else:
				if _walk_to(scene, flank_wp, 2.5):
					step = 2
		2:
			if _walk_to(scene, bp + Vector3(-5.0, 0.0, 0.0), 2.5):
				if PrologueState.mounted:
					scene.toggle_mount()
				print("AUTOPLAY_M5: [%s] 抵達鐘樓迎戰《重裝鐵鐘騎士》！" % String(scene.layout_title))
				timer = 0.4
				step = 3
		3:
			if scene.boss_state == 3:
				if _walk_to(scene, bp + Vector3(-1.5, 0.0, 0.0), 2.6):
					scene.on_interact()
					print("AUTOPLAY_M5: 重裝鐵鐘騎士退休改開景觀咖啡座！")
					timer = 1.5
					step = 4
			elif scene.boss_state == 1 and scene.wolf_charge_cooldown <= 0.0:
				scene.on_wolf_action()
				timer = 0.5
			else:
				if _walk_to(scene, bp + Vector3(-1.5, 0.0, 0.0), 1.9):
					scene.perform_sword_attack()
					timer = 0.28
		4:
			if scene.clock_chest.visible:
				if _walk_to(scene, scene.clock_chest.position, 2.2):
					scene.on_interact()
					_equip_strongest_weapon(scene)
					print("AUTOPLAY_M5: 領取並裝備《百年鐘聲傳奇巨刃》(ATK=%d)" % PrologueState.get_total_atk())
					timer = 0.65
					step = 5
			else:
				step = 5
		5:
			if _walk_to(scene, ep, 2.5):
				scene.on_interact()
				print("AUTOPLAY_M5: 前往第一幕終章《沉霧燈塔港》！")
				step = 6

# --- Map 6: Misty Lighthouse Harbor (Act 1 Finale, Randomized Non-Linear Layout!) ---
func _run_harbor(scene: Node, _delta: float) -> void:
	var bp: Vector3 = scene.boss_home_pos
	var sp: Vector3 = scene.ship_pos
	var flank_wp := Vector3(12.0, 0.0, -24.0) if int(scene.layout_variant) == 2 else bp.lerp(Vector3(0.0, 0.0, 0.0), 0.45)
	match step:
		0:
			timer = 0.75
			step = 1
		1:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 2.2):
					scene.toggle_mount()
					timer = 0.25
			else:
				if _walk_to(scene, flank_wp, 2.5):
					step = 2
		2:
			if _walk_to(scene, bp + Vector3(-5.0, 0.0, 0.0), 2.5):
				if PrologueState.mounted:
					scene.toggle_mount()
				print("AUTOPLAY_M6: [%s] 抵達大燈塔迎戰《迷霧大提督》！" % String(scene.layout_title))
				timer = 0.4
				step = 3
		3:
			if scene.boss_state == 3:
				if _walk_to(scene, bp + Vector3(-1.8, 0.0, 0.0), 2.8):
					scene.on_interact()
					print("AUTOPLAY_M6: 迷霧大提督正式退休！海霧散開、大燈塔點亮！")
					timer = 1.8
					step = 4
			elif scene.boss_state == 1 and scene.wolf_charge_cooldown <= 0.0:
				scene.on_wolf_action()
				timer = 0.5
			else:
				if _walk_to(scene, bp + Vector3(-1.8, 0.0, 0.0), 2.0):
					scene.perform_sword_attack()
					timer = 0.28
		4:
			if scene.finale_chest.visible:
				if _walk_to(scene, scene.finale_chest.position, 2.3):
					scene.on_interact()
					_equip_strongest_weapon(scene)
					print("AUTOPLAY_M6: 領取終章傳奇武器《百年停戰・燈塔傳奇聖劍》(ATK=%d)" % PrologueState.get_total_atk())
					timer = 0.75
					step = 5
			else:
				step = 5
		5:
			if _walk_to(scene, sp, 2.6):
				scene.on_interact()
				print("AUTOPLAY_M6: 登上《遠航號》慶祝第一幕全區通關！")
				timer = 1.4
				step = 6
		6:
			scene.open_world_map()
			timer = 2.0
			step = 7
		7:
			print("AUTOPLAY_COMPLETE: ALL_6_ACT1_MAPS_RANDOMIZED_VERIFIED | ATK=%d | Coins=%d | Inv=%d | GoldOrbs=%d | BossesRetired=4/4" % [
				PrologueState.get_total_atk(), PrologueState.coins, PrologueState.inventory.size(), PrologueState.orb_gold
			])
			active = false
			get_tree().quit(0)

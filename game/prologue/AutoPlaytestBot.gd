extends Node

# Automated 3-map playtest & showcase driver (updated for expanded Little Joy-scale maps).
# Only runs when launched with: Godot --path game -- --autoplay
var active := false
var step := 0
var timer := 0.0
var last_scene_name := ""

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--autoplay"):
		active = true
		print("AUTOPLAY_START: 補簽遠行擴展大地圖自動試玩啟動")

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

func _walk_to(scene: Node, target: Vector3, arrive_dist := 1.15) -> bool:
	var body: CharacterBody3D = scene.wolf if PrologueState.mounted else scene.player
	var diff := Vector3(target.x - body.position.x, 0.0, target.z - body.position.z)
	if diff.length() <= arrive_dist:
		body.velocity = Vector3.ZERO
		return true
	var spd := (8.4 if PrologueState.mounted else 5.8) * PrologueState.get_speed_multiplier()
	scene.move_body(body, diff.normalized(), spd)
	if PrologueState.mounted:
		scene.player.position = scene.wolf.position + Vector3.UP * 1.38
		scene.player.rotation.y = scene.wolf.rotation.y
	return false

# --- Map 1: Expanded 38m x 24m Campfire Clearing ---
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
					timer = 0.32
			else:
				print("AUTOPLAY_M1: 開局 10 秒巨型退休紅章砸落！小兵改行烤魚 (ATK=%d)" % PrologueState.get_total_atk())
				timer = 0.9
				step = 3
		3:
			if scene.camp_loot_node and is_instance_valid(scene.camp_loot_node):
				if _walk_to(scene, scene.camp_loot_node.position, 1.5):
					scene.on_interact()
					print("AUTOPLAY_M1: 拾取首道藍光柱裝備完成 (inv=%d, coins=%d)" % [PrologueState.inventory.size(), PrologueState.coins])
					timer = 0.6
					step = 4
			else:
				step = 4
		4:
			if _walk_to(scene, Vector3(-2.6, 0.0, 4.9), 1.6):
				scene.on_interact()
				scene.perform_dodge()
				print("AUTOPLAY_M1: 湖畔木棧道垂釣＋測試 [Space] 翻滾閃避完成 (seal=%s)" % PrologueState.active_seal)
				timer = 0.75
				step = 5
		5:
			if _walk_to(scene, Vector3(-7.6, 0.0, -4.4), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M1: 探查西北角青苔骷髏洞完成")
				timer = 0.7
				step = 6
		6:
			if _walk_to(scene, Vector3(16.5, 0.0, -1.2), 1.6):
				scene.on_interact()
				print("AUTOPLAY_M1: 過木橋前往雲丘市集")
				step = 7

# --- Map 2: Expanded 52m x 34m Cloudhill Town Hub ---
func _run_town(scene: Node, _delta: float) -> void:
	match step:
		0:
			timer = 0.7
			step = 1
		1:
			if _walk_to(scene, Vector3(-7.6, 0.0, -3.2), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M2: 購入五折短劍並獲得白裝胚子 (coins=%d, inv=%d)" % [PrologueState.coins, PrologueState.inventory.size()])
				timer = 0.85
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
			timer = 0.75
			step = 3
		3:
			var msg_b := PrologueState.craft_blue(scene.selected_inv_idx)
			scene._refresh_inventory_ui(msg_b)
			print("AUTOPLAY_M2: ", msg_b)
			timer = 0.75
			step = 4
		4:
			var msg_g := PrologueState.craft_gold(scene.selected_inv_idx)
			scene._refresh_inventory_ui(msg_g)
			print("AUTOPLAY_M2: ", msg_g)
			timer = 0.75
			step = 5
		5:
			var msg_e := PrologueState.equip_from_inventory(scene.selected_inv_idx)
			scene.selected_inv_idx = -1
			scene.player_sword.visible = true
			scene._refresh_inventory_ui(msg_e)
			print("AUTOPLAY_M2: ", msg_e, " (ATK=%d, Crit=%d%%)" % [PrologueState.get_total_atk(), PrologueState.get_total_crit()])
			timer = 0.75
			step = 6
		6:
			scene.toggle_inventory()
			step = 7
		7:
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
			# Test Slingshot mounted ranged combat on training dummy!
			var prev_weapon := PrologueState.equipped_weapon
			for i in range(PrologueState.inventory.size()):
				if String(PrologueState.inventory[i].get("special", "")) == "slingshot":
					PrologueState.equip_from_inventory(i)
					break
			if not PrologueState.mounted:
				PrologueState.mounted = true
			scene.wolf.look_at(Vector3(3.2, 0.0, 8.6), Vector3.UP, true)
			scene.perform_sword_attack()
			print("AUTOPLAY_M2: 切換《旅人橡木彈弓》並進行狼背騎射！(is_slingshot=%s)" % str(PrologueState.is_slingshot()))
			PrologueState.mounted = false
			for i in range(PrologueState.inventory.size()):
				if PrologueState.inventory[i] == prev_weapon:
					PrologueState.equip_from_inventory(i)
					break
			timer = 0.6
			step = 9
		9:
			if _walk_to(scene, Vector3(-3.4, 0.0, 5.2), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M2: 互動回收史萊姆波波")
				timer = 0.75
				step = 10
		10:
			if _walk_to(scene, Vector3(23.2, 0.0, 1.2), 1.8):
				scene.on_interact()
				print("AUTOPLAY_M2: 過東木橋前往雲海古道與石橋")
				step = 11

# --- Map 3: Expanded 68m x 28m Cloudhill Road & Stone Bridge ---
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
					timer = 0.32
			else:
				print("AUTOPLAY_M3: 擊敗發條巡邏兵，噴出磁吸金幣與光柱")
				timer = 0.5
				step = 2
		2:
			if scene.loot_drops.size() > 0:
				var d_pos: Vector3 = scene.loot_drops[0]["pos"]
				if _walk_to(scene, d_pos, 1.4):
					scene.on_interact()
					print("AUTOPLAY_M3: 拾取戰利品光柱完成 (inv=%d)" % PrologueState.inventory.size())
					timer = 0.6
					step = 3
			else:
				step = 3
		3:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 1.8):
					scene.toggle_mount()
					timer = 0.35
			else:
				if _walk_to(scene, Vector3(-16.0, 0.0, 0.0), 1.3):
					scene.on_wolf_action()
					print("AUTOPLAY_M3: 騎狼撞碎倒塌巨木，炸出木屑 (timber_broken=%s)" % str(PrologueState.timber_broken))
					timer = 0.8
					step = 4
		4:
			if PrologueState.mounted:
				scene.toggle_mount()
				timer = 0.35
			else:
				step = 5
		5:
			if scene.mobs.size() > 2 and bool(scene.mobs[2]["alive"]):
				var e_pos: Vector3 = (scene.mobs[2]["node"] as Node3D).position
				if _walk_to(scene, e_pos, 1.7):
					scene.perform_sword_attack()
					timer = 0.32
			else:
				print("AUTOPLAY_M3: 擊敗金色精英・加班班長！")
				timer = 0.5
				step = 6
		6:
			if scene.loot_drops.size() > 0:
				var d_pos: Vector3 = scene.loot_drops[0]["pos"]
				if _walk_to(scene, d_pos, 1.4):
					scene.on_interact()
					print("AUTOPLAY_M3: 拾取金色精英黃裝光柱完成")
					timer = 0.6
					step = 7
			else:
				step = 7
		7:
			if _walk_to(scene, Vector3(-6.0, 0.0, -4.2), 0.7):
				step = 8
		8:
			if _walk_to(scene, Vector3(-2.6, 0.0, -4.2), 1.1):
				scene.on_interact()
				print("AUTOPLAY_M3: 拉桿開門並散開石橋雲霧 (gate_opened=%s)" % str(PrologueState.gate_opened))
				timer = 1.0
				step = 9
		9:
			if _walk_to(scene, Vector3(6.8, 0.0, 0.8), 1.0):
				if scene.wolf.position.x > 0.0:
					scene.on_coop_summon()
					print("AUTOPLAY_M3: 巨狼會合並召喚【★ 阿熊（助拳）】，跨上長拱石橋開戰！")
					step = 10
		10:
			if scene.boss_state == 3:
				if _walk_to(scene, Vector3(10.0, 0.0, 0.0), 1.4):
					scene.on_interact()
					print("AUTOPLAY_M3: 巨型 3D【正式退休】紅章從天而降砸飛鐵盔！(boss_retired=%s)" % str(PrologueState.boss_retired))
					timer = 1.8
					step = 11
			elif scene.boss_state == 1 and scene.wolf_charge_cooldown <= 0.0:
				scene.on_wolf_action()
				print("AUTOPLAY_M3: 觸發巨狼破防打斷紅光蓄力")
				timer = 0.65
			else:
				if _walk_to(scene, Vector3(10.0, 0.0, 0.0), 0.9):
					scene.perform_sword_attack()
					timer = 0.32
		11:
			if _walk_to(scene, Vector3(9.7, 0.0, 1.4), 1.3):
				scene.on_interact()
				print("AUTOPLAY_M3: 裝備傳奇《彈簧試驗鞍座》(has_spring_saddle=%s)" % str(PrologueState.has_spring_saddle))
				timer = 1.0
				step = 12
		12:
			if _walk_to(scene, Vector3(25.2, 0.0, 0.0), 1.2):
				print("AUTOPLAY_M3: 抵達半月瞭望台，遠景雲霧散開且鏡頭拉遠 (vista_zoomed=%s)" % str(scene.vista_zoomed))
				timer = 1.4
				step = 13
		13:
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 1.8):
					scene.toggle_mount()
					timer = 0.35
			else:
				if _walk_to(scene, Vector3(24.6, 0.0, 4.2), 1.0):
					scene.toggle_mount()
					print("AUTOPLAY_M3: 觸發彈簧鞍座飛天暴擊下劈")
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
				# Verify [1] Flask healing & destructible crate smashing
				PrologueState.player_hp = 3
				scene.drink_flask()
				scene._damage_destructibles(Vector3(-19.0, 0.0, -1.8), 3.0)
				print("AUTOPLAY_M3: 高台秘寶箱領取狀態 (high_chest_claimed=%s, HP=%d, Flask=%d)" % [str(PrologueState.high_chest_claimed), PrologueState.player_hp, PrologueState.flask_charges])
				timer = 1.5
				step = 15
		15:
			print("AUTOPLAY_COMPLETE: ALL_3_EXPANDED_MAPS_VERIFIED | ATK=%d | Coins=%d | Inv=%d | GoldOrbs=%d | Seal=%s | Combo=%d" % [
				PrologueState.get_total_atk(), PrologueState.coins, PrologueState.inventory.size(), PrologueState.orb_gold, PrologueState.active_seal, scene.hit_combo_count
			])
			active = false
			get_tree().quit(0)

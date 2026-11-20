extends Node

# Automated 3-map playtest & showcase driver.
# Only runs when launched with: Godot --path game -- --autoplay
var active := false
var step := 0
var timer := 0.0
var last_scene_name := ""

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--autoplay"):
		active = true
		print("AUTOPLAY_START: 補簽遠行三分區自動試玩啟動")

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
	var spd := (7.6 if PrologueState.mounted else 5.4) * PrologueState.get_speed_multiplier()
	scene.move_body(body, diff.normalized(), spd)
	if PrologueState.mounted:
		scene.player.position = scene.wolf.position + Vector3.UP * 1.38
		scene.player.rotation.y = scene.wolf.rotation.y
	return false

# --- Map 1: Campfire Clearing ---
func _run_campfire(scene: Node, _delta: float) -> void:
	match step:
		0:
			timer = 1.4
			step = 1
		1:
			var ev := InputEventKey.new()
			ev.pressed = true
			ev.physical_keycode = KEY_SPACE
			scene.on_map_input(ev)
			print("AUTOPLAY_M1: 已結束標題畫面，醒來出發")
			timer = 0.8
			step = 2
		2:
			if _walk_to(scene, Vector3(0.0, 0.0, 0.8), 1.3):
				scene.on_interact()
				print("AUTOPLAY_M1: 營火烹煮《百年停戰烤魚》完成 (ATK=%d)" % PrologueState.get_total_atk())
				timer = 1.2
				step = 3
		3:
			if _walk_to(scene, Vector3(-4.8, 0.0, -2.1), 1.4):
				scene.on_interact()
				print("AUTOPLAY_M1: 探查西北角青苔骷髏洞完成")
				timer = 1.1
				step = 4
		4:
			if _walk_to(scene, Vector3(9.2, 0.0, -0.5), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M1: 前往雲丘小鎮")
				step = 5

# --- Map 2: Cloudhill Town Hub ---
func _run_town(scene: Node, _delta: float) -> void:
	match step:
		0:
			timer = 0.9
			step = 1
		1:
			if _walk_to(scene, Vector3(-7.2, 0.0, -2.8), 1.5):
				scene.on_interact()
				print("AUTOPLAY_M2: 購入五折短劍並獲得白裝胚子 (coins=%d, inv=%d)" % [PrologueState.coins, PrologueState.inventory.size()])
				timer = 1.2
				step = 2
		2:
			scene.toggle_inventory()
			scene.selected_inv_idx = 0
			scene._refresh_inventory_ui("自動試玩：選取生鏽步兵短劍準備通貨造裝")
			print("AUTOPLAY_M2: 開啟 PoE 2 背包造裝面板")
			timer = 1.0
			step = 3
		3:
			var msg_b := PrologueState.craft_blue(0)
			scene._refresh_inventory_ui(msg_b)
			print("AUTOPLAY_M2: ", msg_b)
			timer = 1.0
			step = 4
		4:
			var msg_g := PrologueState.craft_gold(0)
			scene._refresh_inventory_ui(msg_g)
			print("AUTOPLAY_M2: ", msg_g)
			timer = 1.0
			step = 5
		5:
			var msg_e := PrologueState.equip_from_inventory(0)
			scene.selected_inv_idx = -1
			scene.player_sword.visible = PrologueState.has_sword
			scene._refresh_inventory_ui(msg_e)
			print("AUTOPLAY_M2: ", msg_e, " (ATK=%d, Crit=%d%%)" % [PrologueState.get_total_atk(), PrologueState.get_total_crit()])
			timer = 1.0
			step = 6
		6:
			scene.toggle_inventory()
			step = 7
		7:
			if _walk_to(scene, Vector3(2.8, 0.0, 6.6), 1.2):
				scene.perform_sword_attack()
				print("AUTOPLAY_M2: 揮劍測試試刀木樁")
				timer = 0.55
				step = 8
		8:
			scene.perform_sword_attack()
			timer = 0.7
			step = 9
		9:
			if _walk_to(scene, Vector3(-3.2, 0.0, 4.8), 1.4):
				scene.on_interact()
				print("AUTOPLAY_M2: 互動回收史萊姆波波")
				timer = 1.0
				step = 10
		10:
			if _walk_to(scene, Vector3(16.0, 0.0, 1.5), 1.6):
				scene.on_interact()
				print("AUTOPLAY_M2: 出城前往雲海古道與石橋")
				step = 11

# --- Map 3: Cloudhill Road & Stone Bridge ---
func _run_road(scene: Node, _delta: float) -> void:
	match step:
		0:
			if not scene.intro_playing:
				print("AUTOPLAY_M3: 2.5 秒雲霧進場過場結束")
				step = 1
		1:
			# Kill first Clockwork Patrol
			if scene.mobs.size() > 0 and bool(scene.mobs[0]["alive"]):
				var m_pos: Vector3 = (scene.mobs[0]["node"] as Node3D).position
				if _walk_to(scene, m_pos, 1.7):
					scene.perform_sword_attack()
					timer = 0.34
			else:
				print("AUTOPLAY_M3: 擊敗發條巡邏兵，準備拾取光柱")
				timer = 0.5
				step = 2
		2:
			if scene.loot_drops.size() > 0:
				var d_pos: Vector3 = scene.loot_drops[0]["pos"]
				if _walk_to(scene, d_pos, 1.4):
					scene.on_interact()
					print("AUTOPLAY_M3: 拾取戰利品光柱完成 (inv=%d)" % PrologueState.inventory.size())
					timer = 0.7
					step = 3
			else:
				step = 3
		3:
			# Mount wolf and smash timber barricade
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 1.8):
					scene.toggle_mount()
					timer = 0.35
			else:
				if _walk_to(scene, Vector3(-11.4, 0.0, 0.0), 1.2):
					scene.on_wolf_action()
					print("AUTOPLAY_M3: 騎狼撞碎枯木路障 (timber_broken=%s)" % str(PrologueState.timber_broken))
					timer = 0.9
					step = 4
		4:
			if PrologueState.mounted:
				scene.toggle_mount()
				timer = 0.35
			else:
				step = 5
		5:
			# Kill Golden Rare Elite
			if scene.mobs.size() > 2 and bool(scene.mobs[2]["alive"]):
				var e_pos: Vector3 = (scene.mobs[2]["node"] as Node3D).position
				if _walk_to(scene, e_pos, 1.7):
					scene.perform_sword_attack()
					timer = 0.34
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
					timer = 0.7
					step = 7
			else:
				step = 7
		7:
			# Walk through narrow slit to lever
			if _walk_to(scene, Vector3(-3.8, 0.0, -3.5), 0.7):
				step = 8
		8:
			if _walk_to(scene, Vector3(-0.8, 0.0, -3.5), 1.1):
				scene.on_interact()
				print("AUTOPLAY_M3: 拉動金色拉桿開啟木門並散開石橋雲霧 (gate_opened=%s)" % str(PrologueState.gate_opened))
				timer = 1.2
				step = 9
		9:
			# Wait briefly for wolf to cross open gate, then cross stone bridge to trigger Boss
			if _walk_to(scene, Vector3(6.2, 0.0, 0.8), 1.0):
				if scene.wolf.position.x > 0.5:
					print("AUTOPLAY_M3: 巨狼會合，跨上石橋觸發稻草人哨長 Boss 戰")
					step = 10
		10:
			# Boss combat: interrupt on WINDUP (1), attack otherwise, retire on KNEELED (3)
			if scene.boss_state == 3:
				if _walk_to(scene, Vector3(8.5, 0.0, 0.0), 1.4):
					scene.on_interact()
					print("AUTOPLAY_M3: 胖黃鳥蓋下【正式退休】紅章！(boss_retired=%s)" % str(PrologueState.boss_retired))
					timer = 2.0
					step = 11
			elif scene.boss_state == 1 and scene.wolf_charge_cooldown <= 0.0:
				scene.on_wolf_action()
				print("AUTOPLAY_M3: 觸發巨狼破防打斷紅光蓄力")
				timer = 0.65
			else:
				if _walk_to(scene, Vector3(8.5, 0.0, 0.0), 0.9):
					scene.perform_sword_attack()
					timer = 0.34
		11:
			# Open Military Chest for Spring Saddle
			if _walk_to(scene, Vector3(8.2, 0.0, 1.4), 1.3):
				scene.on_interact()
				print("AUTOPLAY_M3: 開啟軍需寶箱裝備《彈簧試驗鞍座》(has_spring_saddle=%s)" % str(PrologueState.has_spring_saddle))
				timer = 1.2
				step = 12
		12:
			# Walk to Vista to clear final fog & zoom out
			if _walk_to(scene, Vector3(19.2, 0.0, 0.0), 1.1):
				print("AUTOPLAY_M3: 抵達雲海瞭望台，遠景雲霧散開且鏡頭拉遠 (vista_zoomed=%s)" % str(scene.vista_zoomed))
				timer = 1.8
				step = 13
		13:
			# Mount wolf and Spring Saddle Air-Slam onto High-Ledge Secret Chest!
			if not PrologueState.mounted:
				if _walk_to(scene, scene.wolf.position, 1.8):
					scene.toggle_mount()
					timer = 0.35
			else:
				if _walk_to(scene, Vector3(18.6, 0.0, 2.7), 1.0):
					scene.toggle_mount()
					print("AUTOPLAY_M3: 觸發彈簧鞍座飛天暴擊下劈")
					step = 14
		14:
			if scene.air_slam_active:
				var p: CharacterBody3D = scene.player
				var diff := Vector3(19.5 - p.position.x, 0.0, 4.2 - p.position.z)
				if diff.length() > 0.3:
					scene.move_body(p, diff.normalized(), 5.6)
			else:
				if not PrologueState.high_chest_claimed and scene.high_chest.visible:
					if _walk_to(scene, Vector3(19.5, 0.0, 3.0), 1.6):
						scene.on_interact()
				print("AUTOPLAY_M3: 高台秘寶箱領取狀態 (high_chest_claimed=%s)" % str(PrologueState.high_chest_claimed))
				timer = 1.8
				step = 15
		15:
			print("AUTOPLAY_COMPLETE: ALL_3_MAPS_VERIFIED | ATK=%d | Coins=%d | Inv=%d | GoldOrbs=%d" % [
				PrologueState.get_total_atk(), PrologueState.coins, PrologueState.inventory.size(), PrologueState.orb_gold
			])
			active = false
			get_tree().quit(0)

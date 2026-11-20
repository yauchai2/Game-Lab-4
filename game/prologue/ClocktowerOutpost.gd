extends "res://prologue/PrologueBase.gd"

# PoE 2-Scale Act 1 Chapter 3 Wilderness: 《舊軍鐘樓哨所》 (164m x 106m)
# 5 Interconnected Sub-Regions, Brass Gear Courtyards, Fog-of-War Minimap, 3 Checkpoints,
# Waypoint, Normal Packs, 3 Golden Rares, 2 Hidden Orange Uniques & Zone Boss 《重裝鐵鐘騎士》!

enum ClockBossState { IDLE, WINDUP, STAGGERED, KNEELED, RETIRED }

const MAX_BOSS_HP := 32
const WEST_EXIT := Vector3(-68.0, 0.0, 0.0)
const WAYPOINT_POS := Vector3(-58.0, 0.0, -4.5)

var layout_variant := 0
var layout_title := ""
var entry_spawn_pos := Vector3(-64.0, 0.0, 0.0)
var boss_home_pos := Vector3(62.0, 0.0, 0.0)
var cafe_pos := Vector3(55.0, 0.0, -7.5)
var east_exit_pos := Vector3(80.0, 0.0, 0.0)

var boss_state := ClockBossState.IDLE
var boss_hp := MAX_BOSS_HP
var boss_active := false
var boss_timer := 1.35
var boss_talk_timer := 0.0

var boss := Node3D.new()
var boss_bell_helm: MeshInstance3D
var boss_chef_hat: MeshInstance3D
var boss_mace: MeshInstance3D
var boss_bubble: Label3D
var boss_cue: Label3D
var attack_ring: MeshInstance3D
var clock_cafe: Node3D
var clock_chest := Node3D.new()
var spinning_gears: Array[Dictionary] = []

var mobs: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []

func _configure_random_layout() -> void:
	layout_variant = randi() % 3
	if layout_variant == 0:
		layout_title = "西南登城 → 東北鐘樓"
		entry_spawn_pos = Vector3(-56.0, 0.0, 26.0)
		boss_home_pos = Vector3(52.0, 0.0, -28.0)
		cafe_pos = Vector3(44.0, 0.0, -34.0)
		east_exit_pos = Vector3(68.0, 0.0, -34.0)
	elif layout_variant == 1:
		layout_title = "西北登城 → 東南鐘樓"
		entry_spawn_pos = Vector3(-56.0, 0.0, -26.0)
		boss_home_pos = Vector3(52.0, 0.0, 28.0)
		cafe_pos = Vector3(44.0, 0.0, 34.0)
		east_exit_pos = Vector3(68.0, 0.0, 34.0)
	else:
		layout_title = "雙翼包抄（中路封鎖）"
		entry_spawn_pos = Vector3(-64.0, 0.0, 0.0)
		boss_home_pos = Vector3(62.0, 0.0, 0.0)
		cafe_pos = Vector3(55.0, 0.0, -7.5)
		east_exit_pos = Vector3(80.0, 0.0, 0.0)

func _ready() -> void:
	can_attack = true
	scene_world_key = "clocktower"
	scene_shadow_tint = Color("#4a416e")
	set_wind_profile(Vector2(0.92, -0.38), 1.5, 0.38, 0.12)
	_configure_random_layout()
	var mod_txt := roll_zone_modifier()
	_build_clocktower_outpost()
	_build_bell_knight_boss()
	_spawn_clocktower_mobs()

	var spawn := entry_spawn_pos
	if PrologueState.spawn_tag == "from_waypoint":
		spawn = WAYPOINT_POS + Vector3(0.0, 0.0, 2.8)
	setup_core_trio(spawn)
	setup_camera_and_lighting(18.5, Color("#e8c4a6"), Color("#f2e4d8"), 0.88, Color("#ffdca8"), 1.18, Color("#565e9e"), Color("#f5c8a8"), Color("#70648f"))
	setup_hud()
	if minimap_overlay:
		minimap_overlay.configure_bounds(Rect2(-76.0, -53.0, 164.0, 106.0))
	PrologueState.play_bgm("road")
	_apply_persisted_state()
	show_subtitle("《舊軍鐘樓哨所・%s》｜%s" % [layout_title, mod_txt], 4.0)
	_update_ui()

func _spawn_brass_gear(pos: Vector3, radius := 3.2, speed := 0.45) -> void:
	var g := Node3D.new()
	g.position = pos
	add_child(g)
	cylinder(g, Vector3(0, 0.08, 0), radius, radius, 0.16, Color("#c99b42"))
	cylinder(g, Vector3(0, 0.14, 0), radius * 0.45, radius * 0.45, 0.18, STONE)
	for ti in range(8):
		var ang := float(ti) * TAU / 8.0
		var tooth := box(g, Vector3(cos(ang) * radius, 0.08, sin(ang) * radius), Vector3(0.55, 0.16, 0.55), Color("#e0b252"))
		tooth.rotation.y = -ang
	spinning_gears.append({"node": g, "speed": speed})

func _build_clocktower_outpost() -> void:
	# Massive 164m x 106m Ruined Stone Fortress Plateau
	organic_mound(self, Vector3(4.0, -0.62, 0.0), 84.0, 53.0, 1.20, Color("#b89d72"), 2.0)

	# Sub-region 1: West Rampart Entry (-68..-34, -14..+14) + Waypoint Stone Platform
	organic_mound(self, Vector3(-54.0, -0.52, 0.0), 20.0, 16.0, 1.06, Color("#c7ae82"), -4.0)
	stone_archway(Vector3(-62.5, 0.0, 0.0), 90.0, 1.35, true)
	transition_signpost(WEST_EXIT, "← 翡翠天梯古林", GOLD, 12.0)
	var wp := Node3D.new()
	wp.position = WAYPOINT_POS
	add_child(wp)
	cylinder(wp, Vector3(0, 0.12, 0), 2.0, 2.2, 0.24, STONE_LIGHT)
	cylinder(wp, Vector3(0, 0.25, 0), 1.5, 1.56, 0.08, MIST_CYAN, true)
	var wp_orb := sphere(wp, Vector3(0, 1.35, 0), Vector3(0.52, 0.72, 0.52), MIST_CYAN, true)
	float_motes.append({"node": wp_orb, "base": wp_orb.position, "phase": 0.3, "speed": 2.2, "amp": 0.16})
	label_at(wp, Vector3(0, 2.5, 0), "✦ 鐘樓傳送石陣 [世界地圖]", MIST_CYAN, 26)
	marker(WAYPOINT_POS + Vector3(0, 0, 1.5), MIST_CYAN, 0.68)

	# Sub-region 2: North Brass Gear Workshop (-36..+14, -45..-16) -> Hidden Unique #1
	organic_mound(self, Vector3(-14.0, -0.52, -32.0), 28.0, 16.0, 1.08, Color("#a89378"), 8.0)
	curved_path([Vector3(-50.0, 0, -4.0), Vector3(-36.0, 0, -18.0), Vector3(-20.0, 0, -28.0), Vector3(-34.0, 0, -40.0)], 2.2, TRAIL_STONE)
	curved_path([Vector3(-20.0, 0, -28.0), Vector3(-2.0, 0, -30.0), Vector3(14.0, 0, -16.0)], 2.1, TRAIL, TRAIL_STONE)
	_spawn_brass_gear(Vector3(-20.0, 0.0, -32.0), 3.6, 0.45)
	_spawn_brass_gear(Vector3(-34.0, 0.0, -40.0), 4.2, -0.35)
	stone_archway(Vector3(-27.0, 0.0, -35.0), 40.0, 1.3, true)
	lantern_post(Vector3(-30.5, 0.0, -37.0), 2.9, Color("#ff7b3b"), 20.0)
	_add_checkpoint(Vector3(-20.0, 0.0, -25.0), "齒輪工坊廢墟")

	# Sub-region 3: South Artillery Trenches (-36..+18, +16..+45) -> Hidden Unique #2
	organic_mound(self, Vector3(-10.0, -0.52, 31.0), 28.0, 16.0, 1.08, Color("#9e8b76"), -6.0)
	curved_path([Vector3(-50.0, 0, 4.0), Vector3(-34.0, 0, 18.0), Vector3(-16.0, 0, 30.0), Vector3(14.0, 0, 40.5)], 2.2, TRAIL_STONE)
	curved_path([Vector3(-16.0, 0, 30.0), Vector3(6.0, 0, 22.0), Vector3(24.0, 0, 10.0)], 2.1, TRAIL)
	stone_archway(Vector3(6.0, 0.0, 36.0), -28.0, 1.25, true)
	cliff_outcrop(Vector3(24.0, 0.0, 42.0), 5.0, 4.2, 4.0, STONE_LIGHT, DAY_GRASS_WARM, -18.0)
	lantern_post(Vector3(10.5, 0.0, 37.5), 2.9, Color("#ff7b3b"), -24.0)
	_add_checkpoint(Vector3(-14.0, 0.0, 25.0), "舊軍砲壘壕溝")

	# Sub-region 4: Central Bell-Chime Plaza (-12..+34, -15..+15)
	organic_mound(self, Vector3(10.0, -0.50, 0.0), 24.0, 16.0, 1.06, Color("#d4bc94"), 0.0)
	curved_path([entry_spawn_pos, Vector3(-14.0, 0, 1.5), Vector3(14.0, 0, -1.5), boss_home_pos, east_exit_pos], 2.6, TRAIL_STONE, STONE_LIGHT)
	_spawn_brass_gear(Vector3(10.0, 0.0, 0.0), 4.8, 0.30)
	if layout_variant == 2:
		box(self, Vector3(10.0, 1.6, 0.0), Vector3(1.6, 3.2, 11.0), Color("#c99b42"), true)
		label_at(self, Vector3(10.0, 3.8, 0.0), "⚠ 巨齒輪封道（請由北／南側繞道）", GOLD, 26)
	_add_checkpoint(boss_home_pos.lerp(Vector3(0.0, 0.0, 0.0), 0.36), "鐘樓大門前")

	# Dynamic Ruined Clocktower Sanctum (NE, SE, or East!)
	organic_mound(self, boss_home_pos + Vector3(0.0, -0.46, 0.0), 19.5, 19.5, 1.12, Color("#c9b69e"), 0.0)
	organic_mound(self, boss_home_pos + Vector3(0.0, 0.02, 0.0), 12.0, 12.0, 0.04, Color("#e8dcc4"), 0.0)
	var tower := Node3D.new()
	tower.position = boss_home_pos + Vector3(6.0, 0.0, -14.5)
	tower.rotation_degrees.y = -24.0
	add_child(tower)
	box(tower, Vector3(0, 4.5, 0), Vector3(5.6, 9.0, 5.6), STONE_LIGHT, true)
	box(tower, Vector3(0, 9.8, 0), Vector3(6.2, 1.8, 6.2), STONE)
	cylinder(tower, Vector3(0, 7.2, 2.9), 1.65, 1.65, 0.18, Color("#fff5dc"), true)
	box(tower, Vector3(0, 7.6, 3.05), Vector3(0.18, 1.1, 0.08), Color("#2b3648"), false, true)
	box(tower, Vector3(0.45, 7.2, 3.05), Vector3(0.95, 0.16, 0.08), Color("#2b3648"), false, true)
	cylinder(tower, Vector3(0, 12.2, 0), 0.35, 3.6, 3.4, CORAL_ROOF)
	for ai in range(8):
		var ang := float(ai) * TAU / 8.0
		var lp := boss_home_pos + Vector3(cos(ang) * 14.8, 0.0, sin(ang) * 14.8)
		if flat(lp - east_exit_pos).length() > 4.5:
			lantern_post(lp, 3.0, GOLD, rad_to_deg(ang))
	transition_signpost(east_exit_pos, "→ 沉霧燈塔港", Color("#a8e6ff"), -14.0)

	# Trees, Sunbeams, Crates & Wind-Blown Autumn Grass (~1,600 tufts)
	for tp in [
		[Vector3(-56.0, 0, -14.0), 1.45, PINE_ORANGE], [Vector3(-54.0, 0, 15.0), 1.4, PINE_TEAL],
		[Vector3(-34.0, 0, -14.0), 1.5, Color("#d96b38")], [Vector3(-12.0, 0, -40.0), 1.55, Color("#4a6b8a")],
		[Vector3(-42.0, 0, 34.0), 1.5, PINE_ORANGE], [Vector3(0.0, 0, 42.0), 1.5, PINE_TEAL],
		[Vector3(50.0, 0, -21.0), 1.55, PINE_ORANGE], [Vector3(52.0, 0, 21.0), 1.5, Color("#4a6b8a")],
	]:
		cozy_tree(tp[0], float(tp[1]), tp[2], randf_range(-7.0, 7.0))

	sunbeam_shaft(Vector3(-40.0, 0.0, 0.0), 3.6, 22.0, Color(1.0, 0.90, 0.65, 0.12))
	sunbeam_shaft(Vector3(10.0, 0.0, 0.0), 4.4, 22.0, Color(1.0, 0.90, 0.65, 0.13))
	sunbeam_shaft(Vector3(62.0, 0.0, 0.0), 4.6, 22.0, Color(1.0, 0.88, 0.62, 0.14))

	for cp_pos in [
		Vector3(-46.0, 0, -6.5), Vector3(-24.0, 0, -34.0), Vector3(-30.0, 0, -37.0),
		Vector3(-22.0, 0, 28.0), Vector3(10.0, 0, 36.0), Vector3(14.0, 0, 8.5), Vector3(42.0, 0, -6.5)
	]:
		spawn_destructible_crate(cp_pos, 7)

	build_horizon_panorama(Vector3(4.0, 0.0, 0.0), 84.0, 53.0, "sunset_clouds")
	spawn_wind_grass_meadow(Vector3(-54.0, 0, 0.0), 16.0, 12.0, 220, Color("#c98a42"), Color("#f5c96e"), Color("#ffe066"), 0.25, 1.1)
	spawn_wind_grass_meadow(Vector3(-14.0, 0, -32.0), 22.0, 12.0, 240, Color("#b88648"), Color("#e8be6b"), Color("#ff9eb5"), 0.24, 1.1)
	spawn_wind_grass_meadow(Vector3(-10.0, 0, 31.0), 22.0, 12.0, 240, Color("#b88648"), Color("#e8be6b"), Color("#ffe066"), 0.28, 1.1)
	spawn_wind_grass_meadow(Vector3(10.0, 0, 0.0), 20.0, 12.0, 220, Color("#c98a42"), Color("#f5c96e"), Color("#ff7b3b"), 0.22, 1.1)
	spawn_ambient_motes(Vector3(4.0, 2.2, 0.0), Vector3(124.0, 3.8, 72.0), 44, Color("#ffe8a3"), 0.11)

	# Perimeter Boundary Walls (automatically lined with physical stone/timber/boulder blockers!)
	invisible_boundary_wall(Vector3(-74.0, 0.8, 0.0), Vector3(0.8, 1.8, 104.0))
	invisible_boundary_wall(Vector3(86.0, 0.8, 0.0), Vector3(0.8, 1.8, 104.0))
	invisible_boundary_wall(Vector3(6.0, 0.8, -52.0), Vector3(162.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(6.0, 0.8, 52.0), Vector3(162.0, 1.8, 0.8))

func _add_checkpoint(pos: Vector3, title: String) -> void:
	var cp := Node3D.new()
	cp.position = pos
	add_child(cp)
	cylinder(cp, Vector3(0, 0.75, 0), 0.26, 0.36, 1.5, STONE_LIGHT)
	var orb := sphere(cp, Vector3(0, 1.85, 0), Vector3(0.55, 0.55, 0.55), Color("#4f6d82"), true)
	var ring := marker(pos, Color("#66eae6"), 1.65)
	var lbl := label_at(cp, Vector3(0, 2.55, 0), "◆ " + title, Color("#a8e6ff"), 26)
	checkpoints.append({"node": cp, "pos": pos, "title": title, "orb": orb, "ring": ring, "label": lbl, "activated": false})

func _update_checkpoints() -> void:
	for cp in checkpoints:
		if bool(cp["activated"]):
			continue
		if flat(feet() - (cp["pos"] as Vector3)).length() < 3.4:
			cp["activated"] = true
			var orb: MeshInstance3D = cp["orb"]
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color("#66eae6")
			orb.material_override = glow
			(cp["label"] as Label3D).text = "✦ " + String(cp["title"]) + "（已啟動）"
			(cp["label"] as Label3D).modulate = GOLD
			last_checkpoint_pos = cp["pos"]
			PrologueState.player_hp = 5
			PrologueState.flask_charges = 3
			PrologueState.play_sfx("checkpoint")
			show_player_emote("✦", 1.4)
			show_subtitle("已啟動哨所檢查點：《%s》（體力與茶壺全滿）" % String(cp["title"]), 3.0)

func get_minimap_markers() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for m in mobs:
		if not m["alive"]:
			continue
		var mn: Node3D = m["node"]
		var tier := String(m["tier"])
		var kind := "unique" if tier == "unique" else ("rare" if tier == "rare" else "mob")
		list.append({"pos": mn.position, "kind": kind, "label": String(m["name"])})
	if not PrologueState.clocktower_boss_retired:
		list.append({"pos": boss.position, "kind": "boss", "label": "重裝鐵鐘騎士"})
	list.append({"pos": WAYPOINT_POS, "kind": "checkpoint", "label": "鐘樓傳送石陣"})
	for cp in checkpoints:
		list.append({"pos": cp["pos"], "kind": "checkpoint", "label": String(cp["title"])})
	list.append({"pos": WEST_EXIT, "kind": "exit", "label": "翡翠天梯古林"})
	list.append({"pos": east_exit_pos, "kind": "exit", "label": "沉霧燈塔港"})
	return list

func _spawn_clocktower_mobs() -> void:
	var raw_pool: Array[Vector3] = [
		Vector3(-34.0, 0.0, -40.0),
		Vector3(-6.0, 0.0, -28.0),
		Vector3(14.0, 0.0, 40.5),
		Vector3(-32.0, 0.0, 34.0),
		Vector3(54.0, 0.0, -26.0),
		Vector3(54.0, 0.0, 26.0),
		Vector3(62.0, 0.0, 0.0),
		Vector3(26.0, 0.0, -18.0),
		Vector3(26.0, 0.0, 18.0),
	]
	var valid_pool: Array[Vector3] = []
	for p in raw_pool:
		if flat(p - boss_home_pos).length() > 16.0 and flat(p - entry_spawn_pos).length() > 14.0:
			valid_pool.append(p)
	var chosen := pick_shuffled_positions(valid_pool, 8)
	var spawns := [
		{"pos": Vector3(-40.0, 0.0, -5.0), "name": "鐘樓發條兵", "hp": 8, "tier": "normal"},
		{"pos": Vector3(-32.0, 0.0, -23.0), "name": "齒輪技工兵", "hp": 9, "tier": "normal"},
		{"pos": Vector3(-28.0, 0.0, 23.0), "name": "舊軍砲手", "hp": 9, "tier": "normal"},
		{"pos": Vector3(4.0, 0.0, -6.5), "name": "鐘樓禁衛", "hp": 9, "tier": "normal"},
		{"pos": Vector3(12.0, 0.0, 6.5), "name": "鐘樓禁衛", "hp": 9, "tier": "normal"},
		{"pos": chosen[0], "name": "❖【傳奇】發條報時官", "hp": 36, "tier": "unique", "uid": "clockwork_herald"},
		{"pos": chosen[1], "name": "❖【傳奇】失控重型攻城機兵", "hp": 38, "tier": "unique", "uid": "siege_automaton"},
		{"pos": chosen[2], "name": "★ 齒輪維修長", "hp": 18, "tier": "rare"},
		{"pos": chosen[3], "name": "★ 鐵甲砲兵長", "hp": 18, "tier": "rare"},
		{"pos": chosen[4], "name": "★ 鐘樓禁衛隊長", "hp": 20, "tier": "rare"},
	]
	lantern_post(chosen[0] + Vector3(2.4, 0.0, 2.0), 2.9, Color("#ff7b3b"), 20.0)
	lantern_post(chosen[1] + Vector3(-2.4, 0.0, 2.0), 2.9, Color("#ff7b3b"), -20.0)
	var ev_spots: Array[Vector3] = []
	for ei in range(5, chosen.size()):
		ev_spots.append(chosen[ei])
	ev_spots.append(Vector3(-22.0, 0.0, 0.0))
	spawn_random_wilderness_events(ev_spots)
	for sp in spawns:
		var node := Node3D.new()
		node.position = sp["pos"]
		add_child(node)
		var tier: String = String(sp["tier"])
		var is_unique := tier == "unique"
		var is_rare := tier == "rare" or is_unique
		var col := Color("#ff7b3b") if is_unique else (Color("#f5b82e") if tier == "rare" else Color("#7a8aa6"))
		var scl := 1.95 if is_unique else (1.40 if tier == "rare" else 1.0)
		node.scale = Vector3.ONE * scl
		cylinder(node, Vector3(0, 0.65, 0), 0.36, 0.48, 1.15, col)
		sphere(node, Vector3(0, 1.48, 0), Vector3(0.62, 0.60, 0.62), col.lightened(0.16))
		if is_unique:
			cylinder(node, Vector3(0, 1.92, 0), 0.25, 0.45, 0.26, GOLD, true)
			var aura_mi := cylinder(node, Vector3(0, 0.06, 0), 1.18, 1.18, 0.06, Color("#ff7b3b"), true)
			var aura_mat := StandardMaterial3D.new()
			aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			aura_mat.albedo_color = Color(1.0, 0.48, 0.23, 0.55)
			aura_mi.material_override = aura_mat
		register_living_npc(node, 0.0, 0.06, 3.6)
		var lbl_col := Color("#ff9f5a") if is_unique else (GOLD if tier == "rare" else Color("#e6eeff"))
		var lbl := label_at(node, Vector3(0, 2.30 if is_unique else 2.15, 0), String(sp["name"]), lbl_col, 30 if is_unique else 26)
		var m_ring := marker(sp["pos"], STAMP_RED, 2.5 if is_unique else (1.85 if tier == "rare" else 1.4))
		m_ring.hide()
		mobs.append({
			"node": node, "label": lbl, "name": String(sp["name"]), "home": sp["pos"],
			"ring": m_ring, "state": "idle", "timer": 0.0, "cd": 0.5, "stun": 0.0, "stun_cd": 0.0, "ranged_cd": 1.6,
			"hp": int(sp["hp"]), "max_hp": int(sp["hp"]), "rare": is_rare, "tier": tier,
			"uid": String(sp.get("uid", "")), "alive": true,
		})

func _drop_loot(pos: Vector3, is_rare: bool, tier := "normal", uid := "") -> void:
	var is_unique := tier == "unique"
	spawn_bouncing_coins(pos, 14 if is_unique else (7 if is_rare else 4), 6 if is_unique else 5)
	var item: Dictionary
	if is_unique:
		if not uid.is_empty():
			PrologueState.record_clocktower_unique_defeated(uid)
		item = PrologueState.make_item("黃銅齒輪傳奇戰刃", "weapon", "unique", 6)
		PrologueState.orb_gold += 2
		show_subtitle("❖ 擊敗鐘樓隱藏傳奇怪（%d/2）！掉落【傳奇】武器與金漆罐 x2！" % PrologueState.clocktower_uniques_defeated.size(), 4.2)
	elif is_rare:
		item = PrologueState.make_item("鐘樓禁衛精銳長劍", "weapon", "rare", 4)
		PrologueState.orb_gold += 1
	else:
		var r := "magic" if randi() % 2 == 0 else "normal"
		item = PrologueState.make_item("舊軍齒輪短劍" if r == "normal" else "黃銅鍍金長劍", "weapon", r, 2)
		PrologueState.orb_blue += 1
	var drop_node := Node3D.new()
	drop_node.position = pos + Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
	add_child(drop_node)
	var col := PrologueState.rarity_color(item["rarity"])
	cylinder(drop_node, Vector3(0, 2.4 if is_unique else 1.9, 0), 0.11 if is_unique else 0.08, 0.18 if is_unique else 0.14, 4.8 if is_unique else 3.8, col, true)
	sphere(drop_node, Vector3(0, 0.25, 0), Vector3(0.45, 0.32, 0.45), col, true)
	label_at(drop_node, Vector3(0, 1.15, 0), PrologueState.format_item_title(item), col, 28 if is_unique else 26)
	pop_in_node(drop_node)
	loot_drops.append({"node": drop_node, "item": item, "pos": drop_node.position})

func _build_bell_knight_boss() -> void:
	add_child(boss)
	boss.position = boss_home_pos
	cylinder(boss, Vector3(0, 1.45, 0), 0.72, 1.05, 2.9, Color("#606c82"))
	sphere(boss, Vector3(0, 2.45, 0), Vector3(1.55, 1.25, 1.45), Color("#7d899e"))
	boss_bell_helm = cylinder(boss, Vector3(0, 3.35, 0), 0.42, 0.92, 1.05, GOLD)
	boss_chef_hat = cylinder(boss, Vector3(0, 3.55, 0), 0.65, 0.55, 0.95, WHITE_WALL)
	boss_chef_hat.hide()
	boss_mace = cylinder(boss, Vector3(-1.35, 1.85, 0.65), 0.22, 0.16, 2.7, Color("#c99b42"))
	boss_bubble = label_at(boss, Vector3(0, 4.85, 0), "", Color("#fff2cc"), 34)
	boss_cue = label_at(boss, Vector3(0, 4.30, 0), "重裝鐵鐘騎士", GOLD, 30)
	attack_ring = marker(boss_home_pos, STAMP_RED, 3.6)
	attack_ring.hide()

	clock_cafe = Node3D.new()
	clock_cafe.position = cafe_pos
	add_child(clock_cafe)
	box(clock_cafe, Vector3(0, 0.52, 0), Vector3(2.8, 1.0, 1.25), TIMBER_LIGHT)
	box(clock_cafe, Vector3(0, 2.25, 0), Vector3(3.3, 0.25, 2.0), CORAL_ROOF)
	label_at(clock_cafe, Vector3(0, 2.95, 0), "鐘樓景觀咖啡座 ☕", GOLD, 30)
	clock_cafe.hide()

	add_child(clock_chest)
	clock_chest.position = boss_home_pos + Vector3(-2.5, 0.0, 2.0)
	box(clock_chest, Vector3(0, 0.42, 0), Vector3(1.15, 0.80, 0.80), GOLD)
	box(clock_chest, Vector3(0, 0.84, 0), Vector3(1.22, 0.18, 0.86), CORAL_ROOF)
	label_at(clock_chest, Vector3(0, 1.42, 0), "鐘樓金庫寶箱", GOLD, 28)
	clock_chest.hide()

func _apply_persisted_state() -> void:
	if PrologueState.clocktower_boss_retired:
		boss_state = ClockBossState.RETIRED
		boss_bell_helm.hide()
		boss_chef_hat.show()
		boss_mace.hide()
		boss.position = cafe_pos + Vector3(0, 0, -1.2)
		boss_cue.text = "鐵鐘咖啡師"
		clock_cafe.show()
		clock_chest.visible = not PrologueState.clocktower_chest_claimed

func _physics_process(delta: float) -> void:
	for sg in spinning_gears:
		var gn: Node3D = sg["node"]
		if is_instance_valid(gn):
			gn.rotation.y += float(sg["speed"]) * delta
	_update_mobs_ai(delta)
	_update_checkpoints()
	if boss_talk_timer > 0.0:
		boss_talk_timer -= delta
		if boss_talk_timer <= 0.0:
			boss_bubble.text = ""
	if not step_shared_physics(delta):
		return
	if not boss_active and boss_state == ClockBossState.IDLE and not PrologueState.clocktower_boss_retired and flat(feet() - boss_home_pos).length() < 14.5:
		boss_active = true
		boss_timer = 1.25
		PrologueState.play_bgm("boss")
		_boss_say("噹──！整點報時！誰敢闖入舊軍鐘樓防線！", 3.4)
	if boss_active:
		_update_boss(delta)
	_update_ui()

func _update_mobs_ai(delta: float) -> void:
	if input_locked or is_modal_open():
		return
	var p_pos := feet()
	for m in mobs:
		if not m["alive"]:
			continue
		var mn: Node3D = m["node"]
		var m_ring: MeshInstance3D = m["ring"]
		m["cd"] = maxf(0.0, float(m["cd"]) - delta)
		m["stun_cd"] = maxf(0.0, float(m["stun_cd"]) - delta)
		m["ranged_cd"] = maxf(0.0, float(m["ranged_cd"]) - delta)
		if float(m["stun"]) > 0.0:
			m["stun"] = float(m["stun"]) - delta
			mn.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.22
			m_ring.hide()
			continue
		mn.rotation.z = 0.0
		var to_p := flat(p_pos - mn.position)
		var dist := to_p.length()
		var tier := String(m["tier"])
		if String(m["state"]) == "windup":
			m["timer"] = float(m["timer"]) - delta
			m_ring.position = Vector3(mn.position.x, 0.04, mn.position.z)
			m_ring.show()
			if float(m["timer"]) <= 0.0:
				m_ring.hide()
				m["state"] = "idle"
				m["cd"] = 1.0 if tier == "unique" else (1.15 if tier == "rare" else 1.3)
				flash_hit(mn)
				var hit_r := 3.5 if tier == "unique" else (2.7 if tier == "rare" else 2.15)
				if dist < hit_r:
					take_player_damage(3 if tier == "unique" else (2 if tier == "rare" else 1))
		else:
			m_ring.hide()
			if dist < 11.5 and flat(mn.position - (m["home"] as Vector3)).length() < 13.5:
				mn.rotation.y = atan2(to_p.x, to_p.z)
				if (tier == "rare" or tier == "unique") and dist > 4.0 and float(m["ranged_cd"]) <= 0.0:
					m["ranged_cd"] = 2.4 if tier == "unique" else 2.8
					var base_yaw := atan2(to_p.x, to_p.z)
					var spread: Array = [-0.46, -0.23, 0.0, 0.23, 0.46] if tier == "unique" else [-0.28, 0.0, 0.28]
					for sa: float in spread:
						var dir := Vector3(sin(base_yaw + sa), 0.0, cos(base_yaw + sa)).normalized()
						spawn_enemy_projectile(mn.position, dir * 12.0, 2 if tier == "unique" else 1, Color("#ff7b3b") if tier == "unique" else GOLD)
				if dist <= (2.9 if tier == "unique" else 2.3) and float(m["cd"]) <= 0.0:
					m["state"] = "windup"
					m["timer"] = 0.62 if bool(m["rare"]) else 0.70
					m_ring.position = Vector3(mn.position.x, 0.04, mn.position.z)
					m_ring.show()
				elif dist > 1.8:
					mn.position += to_p.normalized() * (3.5 if bool(m["rare"]) else 3.2) * delta
			else:
				var to_home := flat((m["home"] as Vector3) - mn.position)
				if to_home.length() > 0.5:
					mn.position += to_home.normalized() * 2.2 * delta
					mn.rotation.y = atan2(to_home.x, to_home.z)

func _update_boss(delta: float) -> void:
	boss_timer -= delta
	var enraged := boss_hp <= int(MAX_BOSS_HP / 2)
	match boss_state:
		ClockBossState.IDLE:
			var toward := flat(feet() - boss.position)
			boss.rotation.y = atan2(toward.x, toward.z)
			boss_cue.text = "重裝鐵鐘騎士（整點狂暴！）" if enraged else "重裝鐵鐘騎士"
			if boss_timer <= 0.0:
				boss_state = ClockBossState.WINDUP
				boss_timer = 1.10 if enraged else 1.40
				attack_ring.position = boss.position + Vector3(0, 0.05, 0)
				attack_ring.show()
				boss_mace.rotation_degrees.x = -75.0
				boss_cue.text = "紅光蓄力！按 [Q/RMB] 破防或 [Space] 閃避"
				boss_cue.modulate = STAMP_RED
		ClockBossState.WINDUP:
			if boss_timer <= 0.0:
				attack_ring.hide()
				boss_mace.rotation_degrees.x = 24.0
				shake_time = 0.24
				shake_strength = 0.25
				if flat(feet() - boss.position).length() < 3.9:
					take_player_damage(2)
				var base_y := atan2(feet().x - boss.position.x, feet().z - boss.position.z)
				var rays := 8 if enraged else 6
				for ri in range(rays):
					var ang := base_y + (float(ri) - float(rays - 1) * 0.5) * 0.25
					spawn_enemy_projectile(boss.position, Vector3(sin(ang), 0.0, cos(ang)) * (13.5 if enraged else 11.5), 1, GOLD, 0.42)
				boss_state = ClockBossState.IDLE
				boss_timer = 0.90 if enraged else 1.20
				boss_cue.modulate = GOLD
		ClockBossState.STAGGERED:
			boss.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.22
			boss_cue.text = "破防踉蹌！"
			boss_cue.modulate = GOLD
			if boss_timer <= 0.0:
				boss.rotation.z = 0.0
				boss_state = ClockBossState.IDLE
				boss_timer = 1.15
				boss_cue.modulate = GOLD

func on_wolf_action() -> void:
	super.on_wolf_action()
	if boss_active and boss_state == ClockBossState.WINDUP and flat(feet() - boss.position).length() < 5.2:
		attack_ring.hide()
		boss_mace.rotation_degrees.x = 0.0
		boss_state = ClockBossState.STAGGERED
		boss_timer = 3.0
		hitstop_frames = 6
		shake_time = 0.26
		shake_strength = 0.25
		flash_hit(boss)
		spawn_damage_pop(boss.position, "破防 STAGGER!", GOLD, true)
		_boss_say("噹嗚──！鐘盔震得我頭暈！", 2.4)

func _damage_nearby_mobs(base_dmg: int, is_crit: bool, radius := 2.9) -> void:
	for m in mobs:
		if not m["alive"]:
			continue
		var mn: Node3D = m["node"]
		if flat(player.position - mn.position).length() < radius:
			m["hp"] = maxi(0, int(m["hp"]) - base_dmg)
			hitstop_frames = 3
			flash_hit(mn)
			register_combat_hit(mn.position, is_crit)
			spawn_damage_pop(mn.position, ("CRIT! %d" % base_dmg) if is_crit else "-%d" % base_dmg, GOLD if is_crit else Color.WHITE, is_crit)
			(m["label"] as Label3D).text = "%s (%d/%d)" % [String(m["name"]), int(m["hp"]), int(m["max_hp"])]
			if int(m["hp"]) <= 0:
				m["alive"] = false
				(m["ring"] as Node3D).queue_free()
				var dp := mn.position
				mn.queue_free()
				_drop_loot(dp, bool(m["rare"]), String(m["tier"]), String(m["uid"]))

func on_sword_hit() -> void:
	var is_crit := randi() % 100 < PrologueState.get_total_crit()
	var dmg := maxi(1, int(round(float(PrologueState.get_total_atk()) * get_attack_multiplier())) * (2 if is_crit else 1))
	var reach := 3.6 if combo_step == 3 else 2.9
	_damage_nearby_mobs(dmg, is_crit, reach)
	if boss_active and flat(player.position - boss.position).length() < reach + 0.9:
		_apply_boss_damage(dmg, is_crit)

func on_projectile_hit(pos: Vector3) -> bool:
	var is_crit := randi() % 100 < PrologueState.get_total_crit()
	var dmg := PrologueState.get_total_atk() * (2 if is_crit else 1)
	for m in mobs:
		if not m["alive"]:
			continue
		var mn: Node3D = m["node"]
		if flat(pos - mn.position).length() < 1.4:
			m["hp"] = maxi(0, int(m["hp"]) - dmg)
			PrologueState.play_sfx("hit")
			flash_hit(mn)
			register_combat_hit(mn.position, is_crit)
			spawn_damage_pop(mn.position, ("CRIT! %d" % dmg) if is_crit else "-%d" % dmg, GOLD if is_crit else Color.WHITE, is_crit)
			(m["label"] as Label3D).text = "%s (%d/%d)" % [String(m["name"]), int(m["hp"]), int(m["max_hp"])]
			if int(m["hp"]) <= 0:
				m["alive"] = false
				(m["ring"] as Node3D).queue_free()
				var dp := mn.position
				mn.queue_free()
				_drop_loot(dp, bool(m["rare"]), String(m["tier"]), String(m["uid"]))
			return true
	if boss_active and flat(pos - boss.position).length() < 2.2:
		PrologueState.play_sfx("hit")
		_apply_boss_damage(dmg, is_crit)
		return true
	return false

func _apply_boss_damage(dmg: int, is_crit: bool) -> void:
	var total := dmg + (PrologueState.get_stagger_bonus() if boss_state == ClockBossState.STAGGERED else 0)
	boss_hp = maxi(0, boss_hp - total)
	hitstop_frames = 3
	flash_hit(boss)
	register_combat_hit(boss.position, is_crit)
	spawn_damage_pop(boss.position, ("CRIT! %d" % total) if is_crit else "-%d" % total, GOLD if (is_crit or boss_state == ClockBossState.STAGGERED) else Color.WHITE, is_crit)
	if boss_hp <= 0:
		boss_active = false
		boss_state = ClockBossState.KNEELED
		attack_ring.hide()
		boss.rotation.z = 0.0
		boss.position.y = -0.45
		boss_cue.text = "[ E ] 蓋退休章！"
		boss_cue.modulate = GOLD
		_boss_say("等等……停戰令已經過了一百年？！", 3.6)

func on_interact() -> void:
	for i in range(loot_drops.size()):
		var d: Dictionary = loot_drops[i]
		if near(d["pos"], 2.4):
			PrologueState.add_item_to_inventory(d["item"])
			(d["node"] as Node3D).queue_free()
			loot_drops.remove_at(i)
			show_player_emote("✨", 1.1)
			show_subtitle("拾取：" + PrologueState.format_item_title(d["item"]), 2.8)
			return
	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.8):
		open_world_map()
		return
	if near(WEST_EXIT, 3.0):
		PrologueState.transition_to("res://prologue/EmeraldForest.tscn", "from_waypoint", "翡翠天梯古林")
		return
	if boss_state == ClockBossState.KNEELED and near(boss.position, 3.6):
		PrologueState.clocktower_boss_retired = true
		boss_state = ClockBossState.RETIRED
		PrologueState.play_bgm("road")
		play_giant_retirement_stamp(boss.position)
		_boss_say("百年都過了？難怪沒人來換班！這鐘樓就改開景觀咖啡座吧！", 4.6)
		get_tree().create_timer(1.15).timeout.connect(func() -> void:
			boss_bell_helm.hide()
			boss_chef_hat.show()
			boss_mace.hide()
			boss.position = cafe_pos + Vector3(0, 0, -1.2)
			boss_cue.text = "鐵鐘咖啡師"
			pop_in_node(clock_cafe)
			pop_in_node(clock_chest)
		)
		return
	if clock_chest.visible and near(clock_chest.position, 2.8):
		PrologueState.clocktower_chest_claimed = true
		clock_chest.hide()
		PrologueState.orb_gold += 3
		PrologueState.coins += 60
		PrologueState.add_item_to_inventory(PrologueState.make_item("百年鐘聲傳奇巨刃", "weapon", "unique", 7))
		show_player_emote("✨", 2.0)
		show_subtitle("開啟鐘樓金庫寶箱！獲【傳奇】百年鐘聲傳奇巨刃＋金漆罐 x3＋60¢！", 4.5)
		return
	if near(east_exit_pos, 3.2):
		PrologueState.transition_to("res://prologue/MistyHarbor.tscn", "default", "沉霧燈塔港")

func _boss_say(words: String, duration := 3.2) -> void:
	boss_bubble.text = words
	boss_talk_timer = duration

func _update_ui() -> void:
	var step := "探索齒輪廢墟與砲壘尋找傳奇怪，並勸退東境重裝鐵鐘騎士"
	if PrologueState.clocktower_boss_retired:
		step = "重裝鐵鐘騎士已退休！可繼續清剿隱藏傳奇怪或按 [U] 傳送"
	set_zone_objective("舊軍鐘樓哨所", step)
	update_status_line()
	if boss_active or boss_state == ClockBossState.KNEELED:
		var badge := "警戒中"
		var bcol := GOLD
		if boss_state == ClockBossState.WINDUP:
			badge = "紅光蓄力！按 [Q/RMB]"
			bcol = STAMP_RED
		elif boss_state == ClockBossState.STAGGERED:
			badge = "破防踉蹌！"
			bcol = GOLD
		elif boss_state == ClockBossState.KNEELED:
			badge = "按 [E] 蓋退休章"
			bcol = Color("#98ffbd")
		update_boss_bar(true, "重裝鐵鐘騎士", boss_hp, MAX_BOSS_HP, badge, bcol)
	else:
		update_boss_bar(false, "", 0, MAX_BOSS_HP)

	for d in loot_drops:
		if near(d["pos"], 2.4):
			set_prompt("[ E ] 拾取：" + PrologueState.format_item_title(d["item"]))
			return
	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.8):
		set_prompt("[ E ] 鐘樓傳送石陣（開啟世界地圖 [U]）")
	elif near(WEST_EXIT, 3.0):
		set_prompt("[ E ] 返回：翡翠天梯古林")
	elif boss_state == ClockBossState.KNEELED and near(boss.position, 3.6):
		set_prompt("[ E ] 砸下【正式退休】紅章！")
	elif clock_chest.visible and near(clock_chest.position, 2.8):
		set_prompt("[ E ] 開啟鐘樓金庫寶箱")
	elif near(east_exit_pos, 3.2):
		set_prompt("[ E ] 前往：沉霧燈塔港")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼")
	else:
		set_prompt("")

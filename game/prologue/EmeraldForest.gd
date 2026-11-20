extends "res://prologue/PrologueBase.gd"

# PoE 2-Scale Act 1 Chapter 2 Wilderness: 《翡翠天梯古林》 (160m x 104m)
# 5 Interconnected Sub-Regions, Fog-of-War Minimap, 3 Checkpoints, Waypoint,
# Normal Packs, 3 Golden Rares, 2 Hidden Orange Uniques & Zone Boss 《翡翠樹王》!

enum ForestBossState { IDLE, WINDUP, STAGGERED, KNEELED, RETIRED }

const MAX_BOSS_HP := 28
const WEST_EXIT := Vector3(-66.0, 0.0, 0.0)
const WAYPOINT_POS := Vector3(-56.0, 0.0, -4.0)

var layout_variant := 0
var layout_title := ""
var boss_home_pos := Vector3(60.0, 0.0, 0.0)
var lounge_pos := Vector3(54.0, 0.0, -7.0)
var east_exit_pos := Vector3(78.0, 0.0, 0.0)

var boss_state := ForestBossState.IDLE
var boss_hp := MAX_BOSS_HP
var boss_active := false
var boss_timer := 1.4
var boss_talk_timer := 0.0

var boss := Node3D.new()
var boss_crown: MeshInstance3D
var boss_flower_hat: MeshInstance3D
var boss_staff: MeshInstance3D
var boss_bubble: Label3D
var boss_cue: Label3D
var attack_ring: MeshInstance3D
var fruit_lounge: Node3D
var emerald_chest := Node3D.new()

var mobs: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []

func _configure_random_layout() -> void:
	layout_variant = randi() % 3
	if layout_variant == 0:
		layout_title = "北行秘林"
		boss_home_pos = Vector3(12.0, 0.0, -34.0)
		lounge_pos = Vector3(4.0, 0.0, -39.0)
		east_exit_pos = Vector3(12.0, 0.0, -45.0)
	elif layout_variant == 1:
		layout_title = "南灣古樹"
		boss_home_pos = Vector3(12.0, 0.0, 34.0)
		lounge_pos = Vector3(4.0, 0.0, 39.0)
		east_exit_pos = Vector3(12.0, 0.0, 45.0)
	else:
		layout_title = "東境環道"
		boss_home_pos = Vector3(60.0, 0.0, 0.0)
		lounge_pos = Vector3(54.0, 0.0, -7.0)
		east_exit_pos = Vector3(78.0, 0.0, 0.0)

func _ready() -> void:
	can_attack = true
	scene_world_key = "forest"
	scene_shadow_tint = Color("#3d4f6e")
	set_wind_profile(Vector2(0.82, 0.57), 1.35, 0.36, 0.13)
	_configure_random_layout()
	var mod_txt := roll_zone_modifier()
	_build_emerald_forest()
	_build_tree_king_boss()
	_spawn_forest_mobs()

	var spawn := Vector3(-62.5, 0.0, 0.0)
	if PrologueState.spawn_tag == "from_waypoint":
		spawn = WAYPOINT_POS + Vector3(0.0, 0.0, 2.8)
	setup_core_trio(spawn)
	setup_camera_and_lighting(18.0, Color("#8ce0c4"), Color("#e8f8e8"), 0.88, Color("#fff0c4"), 1.15, Color("#3a9e8c"), Color("#c8f5df"), Color("#2c6e58"))
	setup_hud()
	if minimap_overlay:
		minimap_overlay.configure_bounds(Rect2(-74.0, -52.0, 160.0, 104.0))
	PrologueState.play_bgm("road")
	_apply_persisted_state()
	show_subtitle("《翡翠天梯古林・%s》｜%s" % [layout_title, mod_txt], 4.0)
	_update_ui()

func _build_emerald_forest() -> void:
	# Massive 160m x 104m Seamless Emerald Highland & Forest Plateaus
	organic_mound(self, Vector3(4.0, -0.62, 0.0), 82.0, 52.0, 1.20, Color("#569c56"), -2.0)

	# Sub-region 1: West Stairway Entry (-66..-32, -14..+14) + Waypoint Stone Platform
	organic_mound(self, Vector3(-52.0, -0.52, 0.0), 20.0, 16.0, 1.06, Color("#6ab360"), 6.0)
	stone_archway(Vector3(-61.0, 0.0, 0.0), 90.0, 1.3, true)
	transition_signpost(WEST_EXIT, "← 雲海古道", GOLD, 12.0)
	var wp := Node3D.new()
	wp.position = WAYPOINT_POS
	add_child(wp)
	cylinder(wp, Vector3(0, 0.12, 0), 2.0, 2.2, 0.24, STONE_LIGHT)
	cylinder(wp, Vector3(0, 0.25, 0), 1.5, 1.56, 0.08, MIST_CYAN, true)
	var wp_orb := sphere(wp, Vector3(0, 1.35, 0), Vector3(0.52, 0.72, 0.52), MIST_CYAN, true)
	float_motes.append({"node": wp_orb, "base": wp_orb.position, "phase": 0.2, "speed": 2.2, "amp": 0.16})
	label_at(wp, Vector3(0, 2.5, 0), "✦ 古林傳送石陣 [世界地圖]", MIST_CYAN, 26)
	marker(WAYPOINT_POS + Vector3(0, 0, 1.5), MIST_CYAN, 0.68)

	# Sub-region 2: North Mossy Root Labyrinth (-38..+12, -44..-16) -> Hidden Unique #1
	organic_mound(self, Vector3(-16.0, -0.52, -31.0), 28.0, 16.0, 1.08, Color("#498c52"), 10.0)
	curved_path([Vector3(-48.0, 0, -4.0), Vector3(-36.0, 0, -18.0), Vector3(-22.0, 0, -28.0), Vector3(-34.0, 0, -39.0)], 2.2, TRAIL_STONE)
	curved_path([Vector3(-22.0, 0, -28.0), Vector3(-4.0, 0, -30.0), Vector3(12.0, 0, -16.0)], 2.1, TRAIL, TRAIL_STONE)
	stone_archway(Vector3(-26.0, 0.0, -34.0), 42.0, 1.25, true)
	cliff_outcrop(Vector3(-44.0, 0.0, -40.0), 5.2, 4.4, 4.2, STONE_LIGHT, Color("#498c52"), 18.0)
	lantern_post(Vector3(-30.5, 0.0, -36.5), 2.8, Color("#ff7b3b"), 22.0)
	_add_checkpoint(Vector3(-22.0, 0.0, -25.0), "青苔巨根迷宮")

	# Sub-region 3: South Firefly Stream Basin (-36..+18, +16..+44) -> Hidden Unique #2
	organic_mound(self, Vector3(-10.0, -0.52, 30.0), 28.0, 16.0, 1.08, Color("#5da85e"), -8.0)
	curved_stream([
		Vector3(-38.0, -0.18, 24.0),
		Vector3(-18.0, -0.18, 30.0),
		Vector3(0.0, -0.18, 34.0),
		Vector3(20.0, -0.18, 28.0),
	], 3.8, Color("#34b8d6"), Color("#dcfaff"), -0.14)
	waterfall_cascade(Vector3(-36.0, -0.2, 22.0), 2.8, 4.2, 32.0, Color("#52d4ff"), Color("#eefbff"))
	wooden_footbridge(Vector3(-18.0, 0.0, 30.0), 5.2, 2.3, 12.0, 0.42)
	wooden_footbridge(Vector3(4.0, 0.0, 33.0), 5.0, 2.3, -10.0, 0.40)
	curved_path([Vector3(-48.0, 0, 4.0), Vector3(-34.0, 0, 18.0), Vector3(-18.0, 0, 30.0), Vector3(12.5, 0, 39.5)], 2.2, TRAIL)
	curved_path([Vector3(-18.0, 0, 30.0), Vector3(4.0, 0, 22.0), Vector3(22.0, 0, 10.0)], 2.0, TRAIL, TRAIL_STONE)
	lantern_post(Vector3(9.5, 0.0, 36.5), 2.8, Color("#ff7b3b"), -25.0)
	_add_checkpoint(Vector3(-14.0, 0.0, 25.0), "螢火溪谷")

	# Sub-region 4: Central Sunlit Canopy Terrace (-12..+32, -14..+14)
	organic_mound(self, Vector3(10.0, -0.50, 0.0), 24.0, 16.0, 1.06, Color("#76bf62"), 4.0)
	curved_path([WEST_EXIT, Vector3(-42.0, 0, 0.0), Vector3(-16.0, 0, 2.0), Vector3(12.0, 0, -2.0), boss_home_pos, east_exit_pos], 2.6, TRAIL, TRAIL_STONE)
	if layout_variant == 2:
		# Block the straight center road to force a North or South flanking route!
		boulder_cluster(Vector3(10.0, 0.0, 0.0), 2.4, STONE, true, true, 15.0)
		label_at(self, Vector3(10.0, 2.8, 0.0), "⚠ 巨根封路（請由北／南側繞道）", GOLD, 26)
	_add_checkpoint(boss_home_pos.lerp(Vector3(0.0, 0.0, 0.0), 0.36), "樹王聖壇前")

	# Dynamic Emerald Tree-King Sanctum (North, South, or East!)
	organic_mound(self, boss_home_pos + Vector3(0.0, -0.46, 0.0), 19.0, 19.0, 1.10, Color("#88cc6c"), 0.0)
	organic_mound(self, boss_home_pos + Vector3(0.0, 0.02, 0.0), 11.5, 11.5, 0.04, Color("#e8d49c"), 0.0)
	for ai in range(8):
		var ang := float(ai) * TAU / 8.0
		var lp := boss_home_pos + Vector3(cos(ang) * 14.5, 0.0, sin(ang) * 14.5)
		if flat(lp - east_exit_pos).length() > 4.5:
			lantern_post(lp, 3.0, Color("#98ffbd"), rad_to_deg(ang))
	transition_signpost(east_exit_pos, "→ 舊軍鐘樓哨所", Color("#a8e6ff"), -14.0)

	# Lush emerald pines, golden sunbeams, wildflowers & crates
	for tp in [
		[Vector3(-56.0, 0, -14.0), 1.45, Color("#2f9e66")], [Vector3(-54.0, 0, 15.0), 1.4, PINE_TEAL],
		[Vector3(-36.0, 0, -12.0), 1.5, Color("#2f9e66")], [Vector3(-28.0, 0, -40.0), 1.6, PINE_DARK],
		[Vector3(-8.0, 0, -38.0), 1.5, PINE_TEAL], [Vector3(16.0, 0, -26.0), 1.45, Color("#2f9e66")],
		[Vector3(-42.0, 0, 34.0), 1.5, PINE_TEAL], [Vector3(-4.0, 0, 42.0), 1.55, Color("#2f9e66")],
		[Vector3(24.0, 0, 36.0), 1.45, PINE_DARK], [Vector3(48.0, 0, -20.0), 1.65, Color("#2f9e66")],
		[Vector3(72.0, 0, -18.0), 1.6, PINE_TEAL], [Vector3(52.0, 0, 20.0), 1.6, Color("#2f9e66")],
		[Vector3(72.0, 0, 18.0), 1.55, PINE_TEAL],
	]:
		cozy_tree(tp[0], float(tp[1]), tp[2], randf_range(-7.0, 7.0))

	sunbeam_shaft(Vector3(-40.0, 0.0, 0.0), 3.6, 22.0, Color(1.0, 0.96, 0.72, 0.12))
	sunbeam_shaft(Vector3(10.0, 0.0, -2.0), 4.2, 22.0, Color(1.0, 0.96, 0.72, 0.13))
	sunbeam_shaft(Vector3(60.0, 0.0, 0.0), 4.6, 22.0, Color(0.85, 1.0, 0.80, 0.14))

	flower_patch(Vector3(-46.0, 0, 8.0), 16, [Color("#98ffbd"), Color("#ffe066"), Color("#ff9eb5")], 4.2)
	flower_patch(Vector3(10.0, 0, 6.0), 18, [Color("#ffe066"), Color("#87c8ff"), Color("#98ffbd")], 4.8)
	flower_patch(Vector3(-16.0, 0, -31.0), 16, [Color("#98ffbd"), Color("#7cb8ff"), Color("#fff0a6")], 4.6)

	for cp_pos in [
		Vector3(-44.0, 0, -6.5), Vector3(-24.0, 0, -32.0), Vector3(-32.0, 0, -36.0),
		Vector3(-22.0, 0, 28.0), Vector3(10.0, 0, 36.0), Vector3(12.0, 0, 8.0), Vector3(40.0, 0, -6.0)
	]:
		spawn_destructible_crate(cp_pos, 6)

	# 360-degree Horizon Panorama & ~2,100 Wind-Blown Emerald Wildflower Grass Tufts
	build_horizon_panorama(Vector3(4.0, 0.0, 0.0), 82.0, 52.0, "day_island")
	spawn_wind_grass_meadow(Vector3(-52.0, 0, 0.0), 16.0, 13.0, 240, Color("#569c56"), Color("#a8e878"), Color("#ffe066"), 0.28, 1.15)
	spawn_wind_grass_meadow(Vector3(-16.0, 0, -31.0), 22.0, 12.0, 280, Color("#498c52"), Color("#8cd978"), Color("#98ffbd"), 0.32, 1.2)
	spawn_wind_grass_meadow(Vector3(-10.0, 0, 30.0), 22.0, 12.0, 280, Color("#569c56"), Color("#9fe37c"), Color("#87c8ff"), 0.36, 1.2)
	spawn_wind_grass_meadow(Vector3(10.0, 0, 0.0), 20.0, 13.0, 280, Color("#6ab360"), Color("#c4f082"), Color("#ff9eb5"), 0.30, 1.15)
	spawn_wind_grass_meadow(Vector3(60.0, 0, 0.0), 18.0, 16.0, 240, Color("#6ab360"), Color("#b8f086"), Color("#ffe066"), 0.25, 1.15)
	spawn_ambient_motes(Vector3(4.0, 2.2, 0.0), Vector3(120.0, 3.8, 70.0), 42, Color("#d8ffcf"), 0.11)

	# Seamless Boundary Walls
	invisible_boundary_wall(Vector3(-72.0, 0.8, 0.0), Vector3(0.8, 1.8, 102.0))
	invisible_boundary_wall(Vector3(84.0, 0.8, 0.0), Vector3(0.8, 1.8, 102.0))
	invisible_boundary_wall(Vector3(6.0, 0.8, -50.0), Vector3(158.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(6.0, 0.8, 50.0), Vector3(158.0, 1.8, 0.8))

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
			show_subtitle("已啟動古林檢查點：《%s》（體力與茶壺全滿）" % String(cp["title"]), 3.0)

func get_minimap_markers() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for m in mobs:
		if not m["alive"]:
			continue
		var mn: Node3D = m["node"]
		var tier := String(m["tier"])
		var kind := "unique" if tier == "unique" else ("rare" if tier == "rare" else "mob")
		list.append({"pos": mn.position, "kind": kind, "label": String(m["name"])})
	if not PrologueState.emerald_boss_retired:
		list.append({"pos": boss.position, "kind": "boss", "label": "翡翠樹王"})
	list.append({"pos": WAYPOINT_POS, "kind": "checkpoint", "label": "古林傳送石陣"})
	for cp in checkpoints:
		list.append({"pos": cp["pos"], "kind": "checkpoint", "label": String(cp["title"])})
	list.append({"pos": WEST_EXIT, "kind": "exit", "label": "雲海古道"})
	list.append({"pos": east_exit_pos, "kind": "exit", "label": "舊軍鐘樓哨所"})
	return list

func _spawn_forest_mobs() -> void:
	var raw_pool: Array[Vector3] = [
		Vector3(-34.0, 0.0, -39.0),
		Vector3(-8.0, 0.0, -28.0),
		Vector3(12.5, 0.0, 39.5),
		Vector3(-32.0, 0.0, 34.0),
		Vector3(56.0, 0.0, -22.0),
		Vector3(58.0, 0.0, 22.0),
		Vector3(62.0, 0.0, 0.0),
		Vector3(28.0, 0.0, -18.0),
		Vector3(28.0, 0.0, 18.0),
	]
	var valid_pool: Array[Vector3] = []
	for p in raw_pool:
		if flat(p - boss_home_pos).length() > 16.0:
			valid_pool.append(p)
	var chosen := pick_shuffled_positions(valid_pool, 8)
	var spawns := [
		{"pos": Vector3(-42.0, 0.0, 4.0), "name": "樹精巡邏兵", "hp": 7, "tier": "normal"},
		{"pos": Vector3(-38.5, 0.0, -4.5), "name": "樹精巡邏兵", "hp": 7, "tier": "normal"},
		{"pos": Vector3(-32.0, 0.0, -22.0), "name": "巨根守衛", "hp": 8, "tier": "normal"},
		{"pos": Vector3(-28.0, 0.0, 22.0), "name": "螢火林衛", "hp": 8, "tier": "normal"},
		{"pos": Vector3(4.0, 0.0, -6.0), "name": "翡翠林衛", "hp": 8, "tier": "normal"},
		{"pos": Vector3(10.0, 0.0, 6.0), "name": "翡翠林衛", "hp": 8, "tier": "normal"},
		{"pos": chosen[0], "name": "❖【傳奇】苔蘚發條園丁", "hp": 32, "tier": "unique", "uid": "moss_gardener"},
		{"pos": chosen[1], "name": "❖【傳奇】沉睡琥珀巨偶", "hp": 36, "tier": "unique", "uid": "amber_golem"},
		{"pos": chosen[2], "name": "★ 百年樹根隊長", "hp": 16, "tier": "rare"},
		{"pos": chosen[3], "name": "★ 溪谷翡翠射手", "hp": 16, "tier": "rare"},
		{"pos": chosen[4], "name": "★ 樹冠巡林長", "hp": 18, "tier": "rare"},
	]
	lantern_post(chosen[0] + Vector3(2.4, 0.0, 2.0), 2.9, Color("#ff7b3b"), 20.0)
	lantern_post(chosen[1] + Vector3(-2.4, 0.0, 2.0), 2.9, Color("#ff7b3b"), -20.0)
	var ev_spots: Array[Vector3] = []
	for ei in range(5, chosen.size()):
		ev_spots.append(chosen[ei])
	ev_spots.append(Vector3(-22.0, 0.0, 12.0))
	spawn_random_wilderness_events(ev_spots)
	for sp in spawns:
		var node := Node3D.new()
		node.position = sp["pos"]
		add_child(node)
		var tier: String = String(sp["tier"])
		var is_unique := tier == "unique"
		var is_rare := tier == "rare" or is_unique
		var col := Color("#ff7b3b") if is_unique else (Color("#f5b82e") if tier == "rare" else Color("#4ea86a"))
		var scl := 1.9 if is_unique else (1.38 if tier == "rare" else 0.98)
		node.scale = Vector3.ONE * scl
		cylinder(node, Vector3(0, 0.65, 0), 0.36, 0.46, 1.1, col)
		sphere(node, Vector3(0, 1.45, 0), Vector3(0.62, 0.60, 0.62), col.lightened(0.16))
		if is_unique:
			cylinder(node, Vector3(0, 1.9, 0), 0.24, 0.44, 0.25, GOLD, true)
			var aura_mi := cylinder(node, Vector3(0, 0.06, 0), 1.15, 1.15, 0.06, Color("#ff7b3b"), true)
			var aura_mat := StandardMaterial3D.new()
			aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			aura_mat.albedo_color = Color(1.0, 0.48, 0.23, 0.55)
			aura_mi.material_override = aura_mat
		register_living_npc(node, 0.0, 0.06, 3.6)
		var lbl_col := Color("#ff9f5a") if is_unique else (GOLD if tier == "rare" else Color("#d8ffdf"))
		var lbl := label_at(node, Vector3(0, 2.28 if is_unique else 2.15, 0), String(sp["name"]), lbl_col, 30 if is_unique else 26)
		var m_ring := marker(sp["pos"], STAMP_RED, 2.4 if is_unique else (1.8 if tier == "rare" else 1.35))
		m_ring.hide()
		mobs.append({
			"node": node, "label": lbl, "name": String(sp["name"]), "home": sp["pos"],
			"ring": m_ring, "state": "idle", "timer": 0.0, "cd": 0.5, "stun": 0.0, "stun_cd": 0.0, "ranged_cd": 1.8,
			"hp": int(sp["hp"]), "max_hp": int(sp["hp"]), "rare": is_rare, "tier": tier,
			"uid": String(sp.get("uid", "")), "alive": true,
		})

func _drop_loot(pos: Vector3, is_rare: bool, tier := "normal", uid := "") -> void:
	var is_unique := tier == "unique"
	spawn_bouncing_coins(pos, 12 if is_unique else (6 if is_rare else 3), 6 if is_unique else 5)
	var item: Dictionary
	if is_unique:
		if not uid.is_empty():
			PrologueState.record_emerald_unique_defeated(uid)
		item = PrologueState.make_item("古林琥珀傳奇大劍", "weapon", "unique", 5)
		PrologueState.orb_gold += 2
		show_subtitle("❖ 擊敗古林隱藏傳奇怪（%d/2）！掉落【傳奇】武器與金漆罐 x2！" % PrologueState.emerald_uniques_defeated.size(), 4.2)
	elif is_rare:
		item = PrologueState.make_item("翡翠巡林精銳長劍", "weapon", "rare", 3)
		PrologueState.orb_gold += 1
	else:
		var r := "magic" if randi() % 2 == 0 else "normal"
		item = PrologueState.make_item("青苔林衛短劍" if r == "normal" else "日光葉紋長劍", "weapon", r, 2)
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

func _build_tree_king_boss() -> void:
	add_child(boss)
	boss.position = boss_home_pos
	cylinder(boss, Vector3(0, 1.5, 0), 0.65, 0.92, 3.0, TIMBER)
	sphere(boss, Vector3(0, 2.9, 0), Vector3(2.4, 1.9, 2.2), Color("#2f9e66"))
	sphere(boss, Vector3(0, 2.2, 0.65), Vector3(0.95, 0.88, 0.82), Color("#b58d52"))
	boss_crown = cylinder(boss, Vector3(0, 3.85, 0), 0.52, 0.68, 0.55, Color("#606a7a"))
	boss_flower_hat = cylinder(boss, Vector3(0, 3.85, 0), 0.45, 1.25, 0.32, GOLD)
	boss_flower_hat.hide()
	boss_staff = cylinder(boss, Vector3(-1.35, 1.8, 0.65), 0.14, 0.18, 2.6, TIMBER_LIGHT)
	boss_bubble = label_at(boss, Vector3(0, 4.85, 0), "", Color("#e8ffdf"), 34)
	boss_cue = label_at(boss, Vector3(0, 4.32, 0), "翡翠樹王", Color("#98ffbd"), 30)
	attack_ring = marker(boss_home_pos, STAMP_RED, 3.4)
	attack_ring.hide()

	fruit_lounge = Node3D.new()
	fruit_lounge.position = lounge_pos
	add_child(fruit_lounge)
	box(fruit_lounge, Vector3(0, 0.52, 0), Vector3(2.6, 1.0, 1.2), TIMBER_LIGHT)
	box(fruit_lounge, Vector3(0, 2.25, 0), Vector3(3.1, 0.25, 1.9), Color("#2f9e66"))
	label_at(fruit_lounge, Vector3(0, 2.95, 0), "翡翠果茶亭 🍈", GOLD, 30)
	fruit_lounge.hide()

	add_child(emerald_chest)
	emerald_chest.position = boss_home_pos + Vector3(-2.4, 0.0, 2.0)
	box(emerald_chest, Vector3(0, 0.42, 0), Vector3(1.1, 0.78, 0.78), GOLD)
	box(emerald_chest, Vector3(0, 0.82, 0), Vector3(1.16, 0.18, 0.84), Color("#2f9e66"))
	label_at(emerald_chest, Vector3(0, 1.4, 0), "翡翠王冠寶箱", GOLD, 28)
	emerald_chest.hide()

func _apply_persisted_state() -> void:
	if PrologueState.emerald_boss_retired:
		boss_state = ForestBossState.RETIRED
		boss_crown.hide()
		boss_flower_hat.show()
		boss_staff.hide()
		boss.position = lounge_pos + Vector3(0, 0, -1.2)
		boss_cue.text = "果茶樹爺爺"
		fruit_lounge.show()
		emerald_chest.visible = not PrologueState.emerald_chest_claimed

func _physics_process(delta: float) -> void:
	_update_mobs_ai(delta)
	_update_checkpoints()
	if boss_talk_timer > 0.0:
		boss_talk_timer -= delta
		if boss_talk_timer <= 0.0:
			boss_bubble.text = ""
	if not step_shared_physics(delta):
		return
	if not boss_active and boss_state == ForestBossState.IDLE and not PrologueState.emerald_boss_retired and flat(feet() - boss_home_pos).length() < 14.0:
		boss_active = true
		boss_timer = 1.3
		PrologueState.play_bgm("boss")
		_boss_say("站住！休想越過翡翠防線一步！", 3.2)
	if boss_active:
		_update_boss(delta)
	_update_ui()

func _update_mobs_ai(delta: float) -> void:
	if input_locked or inv_open or is_world_map_open():
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
				m["cd"] = 1.05 if tier == "unique" else (1.2 if tier == "rare" else 1.35)
				flash_hit(mn)
				var hit_r := 3.4 if tier == "unique" else (2.7 if tier == "rare" else 2.1)
				if dist < hit_r:
					take_player_damage(3 if tier == "unique" else (2 if tier == "rare" else 1))
		else:
			m_ring.hide()
			if dist < 11.5 and flat(mn.position - (m["home"] as Vector3)).length() < 13.0:
				mn.rotation.y = atan2(to_p.x, to_p.z)
				if (tier == "rare" or tier == "unique") and dist > 4.0 and float(m["ranged_cd"]) <= 0.0:
					m["ranged_cd"] = 2.6 if tier == "unique" else 3.0
					var base_yaw := atan2(to_p.x, to_p.z)
					var spread: Array = [-0.45, -0.22, 0.0, 0.22, 0.45] if tier == "unique" else [-0.28, 0.0, 0.28]
					for sa: float in spread:
						var dir := Vector3(sin(base_yaw + sa), 0.0, cos(base_yaw + sa)).normalized()
						spawn_enemy_projectile(mn.position, dir * 11.5, 2 if tier == "unique" else 1, Color("#ff7b3b") if tier == "unique" else STAMP_RED)
				if dist <= (2.8 if tier == "unique" else 2.3) and float(m["cd"]) <= 0.0:
					m["state"] = "windup"
					m["timer"] = 0.65 if bool(m["rare"]) else 0.72
					m_ring.position = Vector3(mn.position.x, 0.04, mn.position.z)
					m_ring.show()
				elif dist > 1.8:
					mn.position += to_p.normalized() * (3.4 if bool(m["rare"]) else 3.2) * delta
			else:
				var to_home := flat((m["home"] as Vector3) - mn.position)
				if to_home.length() > 0.5:
					mn.position += to_home.normalized() * 2.2 * delta
					mn.rotation.y = atan2(to_home.x, to_home.z)

func _update_boss(delta: float) -> void:
	boss_timer -= delta
	var enraged := boss_hp <= int(MAX_BOSS_HP / 2)
	match boss_state:
		ForestBossState.IDLE:
			var toward := flat(feet() - boss.position)
			boss.rotation.y = atan2(toward.x, toward.z)
			boss_cue.text = "翡翠樹王（狂暴！）" if enraged else "翡翠樹王"
			if boss_timer <= 0.0:
				boss_state = ForestBossState.WINDUP
				boss_timer = 1.15 if enraged else 1.45
				attack_ring.position = boss.position + Vector3(0, 0.05, 0)
				attack_ring.show()
				boss_staff.rotation_degrees.x = -70.0
				boss_cue.text = "紅光蓄力！按 [Q/RMB] 破防或 [Space] 閃避"
				boss_cue.modulate = STAMP_RED
		ForestBossState.WINDUP:
			if boss_timer <= 0.0:
				attack_ring.hide()
				boss_staff.rotation_degrees.x = 22.0
				shake_time = 0.22
				shake_strength = 0.24
				if flat(feet() - boss.position).length() < 3.8:
					take_player_damage(2)
				var base_y := atan2(feet().x - boss.position.x, feet().z - boss.position.z)
				var rays := 7 if enraged else 5
				for ri in range(rays):
					var ang := base_y + (float(ri) - float(rays - 1) * 0.5) * 0.28
					spawn_enemy_projectile(boss.position, Vector3(sin(ang), 0.0, cos(ang)) * (13.0 if enraged else 11.0), 1, Color("#98ffbd"), 0.42)
				boss_state = ForestBossState.IDLE
				boss_timer = 0.95 if enraged else 1.25
				boss_cue.modulate = Color("#98ffbd")
		ForestBossState.STAGGERED:
			boss.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.22
			boss_cue.text = "破防踉蹌！"
			boss_cue.modulate = GOLD
			if boss_timer <= 0.0:
				boss.rotation.z = 0.0
				boss_state = ForestBossState.IDLE
				boss_timer = 1.2
				boss_cue.modulate = Color("#98ffbd")

func on_wolf_action() -> void:
	super.on_wolf_action()
	if boss_active and boss_state == ForestBossState.WINDUP and flat(feet() - boss.position).length() < 5.0:
		attack_ring.hide()
		boss_staff.rotation_degrees.x = 0.0
		boss_state = ForestBossState.STAGGERED
		boss_timer = 3.2
		hitstop_frames = 6
		shake_time = 0.26
		shake_strength = 0.25
		flash_hit(boss)
		spawn_damage_pop(boss.position, "破防 STAGGER!", GOLD, true)
		_boss_say("哎呀！老樹根差點閃到腰！", 2.4)

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
	if boss_active and flat(player.position - boss.position).length() < reach + 0.8:
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
	if boss_active and flat(pos - boss.position).length() < 2.1:
		PrologueState.play_sfx("hit")
		_apply_boss_damage(dmg, is_crit)
		return true
	return false

func _apply_boss_damage(dmg: int, is_crit: bool) -> void:
	var total := dmg + (PrologueState.get_stagger_bonus() if boss_state == ForestBossState.STAGGERED else 0)
	boss_hp = maxi(0, boss_hp - total)
	hitstop_frames = 3
	flash_hit(boss)
	register_combat_hit(boss.position, is_crit)
	spawn_damage_pop(boss.position, ("CRIT! %d" % total) if is_crit else "-%d" % total, GOLD if (is_crit or boss_state == ForestBossState.STAGGERED) else Color.WHITE, is_crit)
	if boss_hp <= 0:
		boss_active = false
		boss_state = ForestBossState.KNEELED
		attack_ring.hide()
		boss.rotation.z = 0.0
		boss.position.y = -0.45
		boss_cue.text = "[ E ] 蓋退休章！"
		boss_cue.modulate = GOLD
		_boss_say("等等……你手裡拿的是停戰和約？！", 3.6)

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
		PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_waypoint", "雲海古道")
		return
	if boss_state == ForestBossState.KNEELED and near(boss.position, 3.6):
		PrologueState.emerald_boss_retired = true
		boss_state = ForestBossState.RETIRED
		PrologueState.play_bgm("road")
		play_giant_retirement_stamp(boss.position)
		_boss_say("原來早停戰百年了？我還以為掉葉子是敵軍攻城！", 4.5)
		get_tree().create_timer(1.15).timeout.connect(func() -> void:
			boss_crown.hide()
			boss_flower_hat.show()
			boss_staff.hide()
			boss.position = lounge_pos + Vector3(0, 0, -1.2)
			boss_cue.text = "果茶樹爺爺"
			pop_in_node(fruit_lounge)
			pop_in_node(emerald_chest)
		)
		return
	if emerald_chest.visible and near(emerald_chest.position, 2.8):
		PrologueState.emerald_chest_claimed = true
		emerald_chest.hide()
		PrologueState.orb_gold += 3
		PrologueState.coins += 50
		PrologueState.add_item_to_inventory(PrologueState.make_item("翡翠王冠聖劍", "weapon", "unique", 6))
		show_player_emote("✨", 2.0)
		show_subtitle("開啟翡翠王冠寶箱！獲【傳奇】翡翠王冠聖劍＋金漆罐 x3＋50¢！", 4.5)
		return
	if near(east_exit_pos, 3.2):
		PrologueState.transition_to("res://prologue/ClocktowerOutpost.tscn", "default", "舊軍鐘樓哨所")

func _boss_say(words: String, duration := 3.2) -> void:
	boss_bubble.text = words
	boss_talk_timer = duration

func _update_ui() -> void:
	var step := "深入古林探索（[Tab] 迷霧小地圖），尋找傳奇怪與東境翡翠樹王"
	if PrologueState.emerald_boss_retired:
		step = "翡翠樹王已退休！可繼續清剿隱藏傳奇怪或按 [U] 傳送"
	set_zone_objective("翡翠天梯古林", step)
	update_status_line()
	if boss_active or boss_state == ForestBossState.KNEELED:
		var badge := "警戒中"
		var bcol := Color("#98ffbd")
		if boss_state == ForestBossState.WINDUP:
			badge = "紅光蓄力！按 [Q]"
			bcol = STAMP_RED
		elif boss_state == ForestBossState.STAGGERED:
			badge = "破防踉蹌！"
			bcol = GOLD
		elif boss_state == ForestBossState.KNEELED:
			badge = "按 [E] 蓋退休章"
			bcol = Color("#98ffbd")
		update_boss_bar(true, "翡翠樹王", boss_hp, MAX_BOSS_HP, badge, bcol)
	else:
		update_boss_bar(false, "", 0, MAX_BOSS_HP)

	for d in loot_drops:
		if near(d["pos"], 2.4):
			set_prompt("[ E ] 拾取：" + PrologueState.format_item_title(d["item"]))
			return
	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.8):
		set_prompt("[ E ] 古林傳送石陣（開啟世界地圖 [U]）")
	elif near(WEST_EXIT, 3.0):
		set_prompt("[ E ] 返回：雲海古道")
	elif boss_state == ForestBossState.KNEELED and near(boss.position, 3.6):
		set_prompt("[ E ] 砸下【正式退休】紅章！")
	elif emerald_chest.visible and near(emerald_chest.position, 2.8):
		set_prompt("[ E ] 開啟翡翠王冠寶箱")
	elif near(east_exit_pos, 3.2):
		set_prompt("[ E ] 前往：舊軍鐘樓哨所")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼")
	else:
		set_prompt("")

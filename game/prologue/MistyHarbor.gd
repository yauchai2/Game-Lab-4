extends "res://prologue/PrologueBase.gd"

# PoE 2-Scale Act 1 Finale: 《沉霧燈塔港》 (170m x 110m)
# 5 Interconnected Coastal Sub-Regions, Grand Ceasefire Lighthouse, Clearing Sea-Fog,
# 3 Checkpoints, Waypoint, 3 Golden Rares, 2 Hidden Uniques & Act 1 Final Boss 《迷霧大提督・蟹甲將軍》!

enum HarborBossState { IDLE, WINDUP, STAGGERED, KNEELED, RETIRED }

const MAX_BOSS_HP := 38
const WEST_EXIT := Vector3(-70.0, 0.0, 0.0)
const WAYPOINT_POS := Vector3(-60.0, 0.0, -4.5)

var layout_variant := 0
var layout_title := ""
var entry_spawn_pos := Vector3(-66.0, 0.0, 0.0)
var boss_home_pos := Vector3(64.0, 0.0, 0.0)
var grill_pos := Vector3(56.0, 0.0, -8.0)
var ship_pos := Vector3(82.0, 0.0, 0.0)

var boss_state := HarborBossState.IDLE
var boss_hp := MAX_BOSS_HP
var boss_active := false
var boss_timer := 1.3
var boss_talk_timer := 0.0

var boss := Node3D.new()
var boss_admiral_hat: MeshInstance3D
var boss_straw_hat: MeshInstance3D
var boss_anchor: MeshInstance3D
var boss_bubble: Label3D
var boss_cue: Label3D
var attack_ring: MeshInstance3D
var fog_harbor: Node3D
var lighthouse_beam: Node3D
var seafood_grill: Node3D
var finale_chest := Node3D.new()

var mobs: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var loot_drops: Array[Dictionary] = []

func _configure_random_layout() -> void:
	layout_variant = randi() % 3
	if layout_variant == 0:
		layout_title = "南岸港門 → 北角大燈塔"
		entry_spawn_pos = Vector3(-56.0, 0.0, 26.0)
		boss_home_pos = Vector3(52.0, 0.0, -26.0)
		grill_pos = Vector3(44.0, 0.0, -32.0)
		ship_pos = Vector3(70.0, 0.0, -32.0)
	elif layout_variant == 1:
		layout_title = "北岸港門 → 南角大燈塔"
		entry_spawn_pos = Vector3(-56.0, 0.0, -26.0)
		boss_home_pos = Vector3(52.0, 0.0, 26.0)
		grill_pos = Vector3(44.0, 0.0, 32.0)
		ship_pos = Vector3(70.0, 0.0, 32.0)
	else:
		layout_title = "海峽礁岩環線（中路沉船）"
		entry_spawn_pos = Vector3(-66.0, 0.0, 0.0)
		boss_home_pos = Vector3(64.0, 0.0, 0.0)
		grill_pos = Vector3(56.0, 0.0, -8.0)
		ship_pos = Vector3(82.0, 0.0, 0.0)

func _ready() -> void:
	can_attack = true
	scene_world_key = "harbor"
	scene_shadow_tint = Color("#3b5278")
	set_wind_profile(Vector2(0.88, 0.46), 1.65, 0.44, 0.13)
	_configure_random_layout()
	var mod_txt := roll_zone_modifier()
	_build_misty_harbor()
	_build_admiral_boss()
	_spawn_harbor_mobs()

	var spawn := entry_spawn_pos
	if PrologueState.spawn_tag == "from_waypoint":
		spawn = WAYPOINT_POS + Vector3(0.0, 0.0, 2.8)
	setup_core_trio(spawn)
	setup_camera_and_lighting(19.0, Color("#8cd4e8"), Color("#e8f4fa"), 0.88, Color("#ffe8c2"), 1.18, Color("#2c7db8"), Color("#c8f0fa"), Color("#1e629c"))
	setup_hud()
	if minimap_overlay:
		minimap_overlay.configure_bounds(Rect2(-78.0, -55.0, 170.0, 110.0))
	PrologueState.play_bgm("road")
	_apply_persisted_state()
	show_subtitle("《沉霧燈塔港・%s》｜%s" % [layout_title, mod_txt], 4.2)
	_update_ui()

func _build_misty_harbor() -> void:
	# Massive 170m x 110m Coastal Peninsula & Sandbar Harbor
	organic_mound(self, Vector3(5.0, -0.64, 0.0), 86.0, 55.0, 1.24, Color("#d4c496"), -2.0)
	organic_mound(self, Vector3(0.0, -0.54, 0.0), 76.0, 46.0, 1.06, Color("#76ad62"), 2.0)

	# Sub-region 1: West Coastal Gate (-70..-36, -14..+14) + Waypoint
	organic_mound(self, Vector3(-56.0, -0.50, 0.0), 20.0, 16.0, 1.06, Color("#88b868"), 4.0)
	stone_archway(Vector3(-64.0, 0.0, 0.0), 90.0, 1.35, true)
	transition_signpost(WEST_EXIT, "← 舊軍鐘樓哨所", GOLD, 12.0)
	var wp := Node3D.new()
	wp.position = WAYPOINT_POS
	add_child(wp)
	cylinder(wp, Vector3(0, 0.12, 0), 2.0, 2.2, 0.24, STONE_LIGHT)
	cylinder(wp, Vector3(0, 0.25, 0), 1.5, 1.56, 0.08, MIST_CYAN, true)
	var wp_orb := sphere(wp, Vector3(0, 1.35, 0), Vector3(0.52, 0.72, 0.52), MIST_CYAN, true)
	float_motes.append({"node": wp_orb, "base": wp_orb.position, "phase": 0.5, "speed": 2.2, "amp": 0.16})
	label_at(wp, Vector3(0, 2.5, 0), "✦ 燈塔港傳送石陣 [世界地圖]", MIST_CYAN, 26)
	marker(WAYPOINT_POS + Vector3(0, 0, 1.5), MIST_CYAN, 0.68)

	# Sub-region 2: North Shipwreck Sandbar Cove (-36..+14, -46..-18) -> Hidden Unique #1
	organic_mound(self, Vector3(-14.0, -0.50, -33.0), 29.0, 16.0, 1.06, Color("#ebd39c"), 8.0)
	curved_path([Vector3(-52.0, 0, -4.0), Vector3(-36.0, 0, -18.0), Vector3(-20.0, 0, -29.0), Vector3(-36.0, 0, -42.0)], 2.2, BOARDWALK)
	curved_path([Vector3(-20.0, 0, -29.0), Vector3(-2.0, 0, -31.0), Vector3(14.0, 0, -17.0)], 2.1, TRAIL)
	cliff_outcrop(Vector3(-46.0, 0.0, -42.0), 5.2, 4.4, 4.2, STONE_LIGHT, Color("#76ad62"), 16.0)
	lantern_post(Vector3(-32.0, 0.0, -39.0), 2.9, Color("#ff7b3b"), 22.0)
	_add_checkpoint(Vector3(-20.0, 0.0, -26.0), "沉船沙洲灣")

	# Sub-region 3: South Old-Army Cargo Docks (-36..+18, +18..+46) -> Hidden Unique #2
	organic_mound(self, Vector3(-10.0, -0.50, 32.0), 29.0, 16.0, 1.06, Color("#c9a878"), -6.0)
	curved_path([Vector3(-52.0, 0, 4.0), Vector3(-34.0, 0, 19.0), Vector3(-16.0, 0, 31.0), Vector3(16.0, 0, 42.0)], 2.4, BOARDWALK)
	curved_path([Vector3(-16.0, 0, 31.0), Vector3(6.0, 0, 23.0), Vector3(24.0, 0, 10.0)], 2.1, TRAIL_STONE)
	cozy_cabin(Vector3(-26.0, 0.0, 38.0), 24.0, CORAL_ROOF, WHITE_WALL)
	lantern_post(Vector3(12.5, 0.0, 39.0), 2.9, Color("#ff7b3b"), -24.0)
	_add_checkpoint(Vector3(-14.0, 0.0, 26.0), "舊軍魚貨碼頭")

	# Sub-region 4: Central Sea-Breeze Promenade (-12..+36, -16..+16)
	organic_mound(self, Vector3(12.0, -0.48, 0.0), 25.0, 16.0, 1.06, Color("#88be68"), 0.0)
	curved_path([entry_spawn_pos, Vector3(-14.0, 0, 1.5), Vector3(14.0, 0, -1.5), boss_home_pos, ship_pos], 2.7, TRAIL_STONE, STONE_LIGHT)
	if layout_variant == 2:
		box(self, Vector3(12.0, 1.2, 0.0), Vector3(2.2, 2.4, 11.5), TIMBER, true)
		label_at(self, Vector3(12.0, 3.2, 0.0), "⚠ 沉船殘骸封道（請由北／南側繞道）", GOLD, 26)
	_add_checkpoint(boss_home_pos.lerp(Vector3(0.0, 0.0, 0.0), 0.36), "大燈塔前廣場")

	# Dynamic Grand Ceasefire Lighthouse Headland (NE, SE, or East!)
	organic_mound(self, boss_home_pos + Vector3(0.0, -0.44, 0.0), 20.5, 20.5, 1.12, Color("#dfd1b0"), 0.0)
	organic_mound(self, boss_home_pos + Vector3(0.0, 0.02, 0.0), 12.5, 12.5, 0.04, Color("#f2e6ca"), 0.0)

	# Towering Red-and-White Grand Ceasefire Lighthouse + Rotating Golden Light Beam!
	var lh_pos := boss_home_pos + Vector3(6.0, 0.0, -15.5)
	var lh := Node3D.new()
	lh.position = lh_pos
	add_child(lh)
	for bi in range(6):
		var col := Color("#e34b3b") if bi % 2 == 0 else WHITE_WALL
		cylinder(lh, Vector3(0, 1.0 + float(bi) * 1.9, 0), 2.4 - float(bi) * 0.22, 2.6 - float(bi) * 0.22, 1.92, col)
	cylinder(lh, Vector3(0, 12.5, 0), 1.45, 1.45, 1.2, Color("#fff5b8"), true)
	cylinder(lh, Vector3(0, 13.7, 0), 0.2, 1.75, 1.5, Color("#e34b3b"))
	lighthouse_beam = Node3D.new()
	lighthouse_beam.position = lh_pos + Vector3(0.0, 12.5, 0.0)
	add_child(lighthouse_beam)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.94, 0.62, 0.28)
	var bm := box(lighthouse_beam, Vector3(0, 0, 16.0), Vector3(3.2, 1.6, 32.0), Color("#fff5b8"), false, true)
	bm.material_override = bmat
	lighthouse_beam.visible = PrologueState.harbor_boss_retired

	# Act 2 Departure Sailing Ship 《遠航號》 at the Pier!
	var ship := Node3D.new()
	ship.position = ship_pos + Vector3(3.2, 0.0, 0.0)
	add_child(ship)
	box(ship, Vector3(0, 0.65, 0), Vector3(5.2, 1.3, 2.8), TIMBER_LIGHT, true)
	cylinder(ship, Vector3(0, 3.2, 0), 0.14, 0.18, 5.2, TIMBER)
	box(ship, Vector3(0.25, 3.6, 0), Vector3(0.18, 3.2, 3.6), WHITE_WALL)
	box(ship, Vector3(0.32, 3.6, 0), Vector3(0.22, 0.7, 3.65), CORAL_ROOF)
	sway_items.append({"node": ship, "base_rot": ship.rotation, "amp": 0.035, "speed": 1.6, "phase": 0.2})
	marker(ship_pos, GOLD, 0.95)
	label_at(self, ship_pos + Vector3(0, 2.8, 0), "⛵ 遠航號 → 第二幕：珊瑚群島", GOLD, 30)

	# Clearing Harbor Sea-Fog Clouds (dramatically dissolve when Admiral retires!)
	fog_harbor = Node3D.new()
	add_child(fog_harbor)
	for fp in [
		boss_home_pos + Vector3(-10.0, 2.4, -10.0), boss_home_pos + Vector3(0.0, 2.8, 12.0),
		boss_home_pos + Vector3(10.0, 2.6, -6.0), boss_home_pos + Vector3(14.0, 2.4, 8.0),
	]:
		sphere(fog_harbor, fp, Vector3(7.5, 4.6, 7.0), Color("#e6f2fa"), true)

	# Coastal trees, flowers, crates & horizon panorama
	for tp in [
		[Vector3(-58.0, 0, -15.0), 1.45, PINE_TEAL], [Vector3(-56.0, 0, 16.0), 1.4, MEADOW_GREEN],
		[Vector3(-34.0, 0, -15.0), 1.45, MEADOW_LIGHT], [Vector3(-12.0, 0, -41.0), 1.5, PINE_TEAL],
		[Vector3(-42.0, 0, 35.0), 1.45, MEADOW_GREEN], [Vector3(2.0, 0, 42.0), 1.45, PINE_TEAL],
		[Vector3(52.0, 0, -22.0), 1.5, PINE_TEAL], [Vector3(54.0, 0, 22.0), 1.5, MEADOW_GREEN],
	]:
		cozy_tree(tp[0], float(tp[1]), tp[2], randf_range(-7.0, 7.0))

	flower_patch(Vector3(-46.0, 0, 9.0), 16, [Color("#ffe066"), Color("#87c8ff"), Color("#ff9eb5")], 4.4)
	flower_patch(Vector3(12.0, 0, 7.0), 18, [Color("#ff9eb5"), Color("#ffe066"), Color("#98ffbd")], 4.8)
	for cp_pos in [
		Vector3(-48.0, 0, -6.5), Vector3(-24.0, 0, -35.0), Vector3(-32.0, 0, -38.0),
		Vector3(-22.0, 0, 29.0), Vector3(12.0, 0, 37.0), Vector3(16.0, 0, 8.5), Vector3(44.0, 0, -6.5)
	]:
		spawn_destructible_crate(cp_pos, 8)

	build_horizon_panorama(Vector3(5.0, 0.0, 0.0), 86.0, 55.0, "day_island")
	spawn_wind_grass_meadow(Vector3(-56.0, 0, 0.0), 16.0, 12.0, 220, MEADOW_GREEN, Color("#bfe36b"), Color("#ffe066"), 0.28, 1.1)
	spawn_wind_grass_meadow(Vector3(-14.0, 0, -33.0), 22.0, 12.0, 220, Color("#88b868"), Color("#d2f07d"), Color("#87c8ff"), 0.25, 1.1)
	spawn_wind_grass_meadow(Vector3(-10.0, 0, 32.0), 22.0, 12.0, 220, MEADOW_GREEN, Color("#c5e872"), Color("#ff9eb5"), 0.28, 1.1)
	spawn_wind_grass_meadow(Vector3(12.0, 0, 0.0), 20.0, 12.0, 220, MEADOW_LIGHT, Color("#d8f582"), Color("#ffe066"), 0.26, 1.1)
	spawn_ambient_motes(Vector3(5.0, 2.2, 0.0), Vector3(130.0, 3.8, 76.0), 46, Color("#e8fbff"), 0.11)

	# Perimeter Coastal Boundary Walls (auto-lined with physical edge blockers!)
	invisible_boundary_wall(Vector3(-76.0, 0.8, 0.0), Vector3(0.8, 1.8, 108.0))
	invisible_boundary_wall(Vector3(88.0, 0.8, 0.0), Vector3(0.8, 1.8, 108.0))
	invisible_boundary_wall(Vector3(6.0, 0.8, -54.0), Vector3(166.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(6.0, 0.8, 54.0), Vector3(166.0, 1.8, 0.8))

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
			show_subtitle("已啟動港灣檢查點：《%s》（體力與茶壺全滿）" % String(cp["title"]), 3.0)

func get_minimap_markers() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for m in mobs:
		if not m["alive"]:
			continue
		var mn: Node3D = m["node"]
		var tier := String(m["tier"])
		var kind := "unique" if tier == "unique" else ("rare" if tier == "rare" else "mob")
		list.append({"pos": mn.position, "kind": kind, "label": String(m["name"])})
	if not PrologueState.harbor_boss_retired:
		list.append({"pos": boss.position, "kind": "boss", "label": "迷霧大提督"})
	list.append({"pos": WAYPOINT_POS, "kind": "checkpoint", "label": "燈塔港傳送石陣"})
	for cp in checkpoints:
		list.append({"pos": cp["pos"], "kind": "checkpoint", "label": String(cp["title"])})
	list.append({"pos": WEST_EXIT, "kind": "exit", "label": "舊軍鐘樓哨所"})
	list.append({"pos": ship_pos, "kind": "exit", "label": "遠航號"})
	return list

func _spawn_harbor_mobs() -> void:
	var raw_pool: Array[Vector3] = [
		Vector3(-36.0, 0.0, -42.0),
		Vector3(-5.0, 0.0, -29.0),
		Vector3(16.0, 0.0, 42.0),
		Vector3(-32.0, 0.0, 34.0),
		Vector3(54.0, 0.0, -26.0),
		Vector3(54.0, 0.0, 26.0),
		Vector3(64.0, 0.0, 0.0),
		Vector3(26.0, 0.0, -18.0),
		Vector3(26.0, 0.0, 18.0),
	]
	var valid_pool: Array[Vector3] = []
	for p in raw_pool:
		if flat(p - boss_home_pos).length() > 16.0 and flat(p - entry_spawn_pos).length() > 14.0:
			valid_pool.append(p)
	var chosen := pick_shuffled_positions(valid_pool, 8)
	var spawns := [
		{"pos": Vector3(-42.0, 0.0, -5.0), "name": "霧港巡邏蟹", "hp": 9, "tier": "normal"},
		{"pos": Vector3(-32.0, 0.0, -24.0), "name": "沉船水手兵", "hp": 10, "tier": "normal"},
		{"pos": Vector3(-28.0, 0.0, 24.0), "name": "碼頭砲艇兵", "hp": 10, "tier": "normal"},
		{"pos": Vector3(5.0, 0.0, -6.5), "name": "燈塔守衛兵", "hp": 10, "tier": "normal"},
		{"pos": Vector3(13.0, 0.0, 6.5), "name": "燈塔守衛兵", "hp": 10, "tier": "normal"},
		{"pos": chosen[0], "name": "❖【傳奇】深海巨錨蟹王", "hp": 40, "tier": "unique", "uid": "anchor_crab_king"},
		{"pos": chosen[1], "name": "❖【傳奇】百年霧笛巨像", "hp": 42, "tier": "unique", "uid": "foghorn_colossus"},
		{"pos": chosen[2], "name": "★ 迷霧水手長", "hp": 20, "tier": "rare"},
		{"pos": chosen[3], "name": "★ 港灣砲艇長", "hp": 20, "tier": "rare"},
		{"pos": chosen[4], "name": "★ 燈塔禁衛長", "hp": 22, "tier": "rare"},
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
		var col := Color("#ff7b3b") if is_unique else (Color("#f5b82e") if tier == "rare" else Color("#4a9cb8"))
		var scl := 2.0 if is_unique else (1.42 if tier == "rare" else 1.02)
		node.scale = Vector3.ONE * scl
		cylinder(node, Vector3(0, 0.65, 0), 0.38, 0.50, 1.15, col)
		sphere(node, Vector3(0, 1.48, 0), Vector3(0.64, 0.60, 0.64), col.lightened(0.16))
		if is_unique:
			cylinder(node, Vector3(0, 1.94, 0), 0.26, 0.46, 0.26, GOLD, true)
			var aura_mi := cylinder(node, Vector3(0, 0.06, 0), 1.2, 1.2, 0.06, Color("#ff7b3b"), true)
			var aura_mat := StandardMaterial3D.new()
			aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			aura_mat.albedo_color = Color(1.0, 0.48, 0.23, 0.55)
			aura_mi.material_override = aura_mat
		register_living_npc(node, 0.0, 0.06, 3.6)
		var lbl_col := Color("#ff9f5a") if is_unique else (GOLD if tier == "rare" else Color("#dcf6ff"))
		var lbl := label_at(node, Vector3(0, 2.32 if is_unique else 2.18, 0), String(sp["name"]), lbl_col, 30 if is_unique else 26)
		var m_ring := marker(sp["pos"], STAMP_RED, 2.55 if is_unique else (1.9 if tier == "rare" else 1.4))
		m_ring.hide()
		mobs.append({
			"node": node, "label": lbl, "name": String(sp["name"]), "home": sp["pos"],
			"ring": m_ring, "state": "idle", "timer": 0.0, "cd": 0.5, "stun": 0.0, "stun_cd": 0.0, "ranged_cd": 1.6,
			"hp": int(sp["hp"]), "max_hp": int(sp["hp"]), "rare": is_rare, "tier": tier,
			"uid": String(sp.get("uid", "")), "alive": true,
		})

func _drop_loot(pos: Vector3, is_rare: bool, tier := "normal", uid := "") -> void:
	var is_unique := tier == "unique"
	spawn_bouncing_coins(pos, 15 if is_unique else (8 if is_rare else 4), 6 if is_unique else 5)
	var item: Dictionary
	if is_unique:
		if not uid.is_empty():
			PrologueState.record_harbor_unique_defeated(uid)
		item = PrologueState.make_item("深海巨錨傳奇戰刀", "weapon", "unique", 7)
		PrologueState.orb_gold += 2
		show_subtitle("❖ 擊敗燈塔港隱藏傳奇怪（%d/2）！掉落【傳奇】武器與金漆罐 x2！" % PrologueState.harbor_uniques_defeated.size(), 4.2)
	elif is_rare:
		item = PrologueState.make_item("霧港精銳海軍長劍", "weapon", "rare", 4)
		PrologueState.orb_gold += 1
	else:
		var r := "magic" if randi() % 2 == 0 else "normal"
		item = PrologueState.make_item("海風水手短刀" if r == "normal" else "珊瑚鑲嵌軍刀", "weapon", r, 3)
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

func _build_admiral_boss() -> void:
	add_child(boss)
	boss.position = boss_home_pos
	sphere(boss, Vector3(0, 1.5, 0), Vector3(2.3, 1.85, 2.0), Color("#d9534f"))
	sphere(boss, Vector3(0, 2.65, 0.3), Vector3(1.15, 1.0, 1.05), Color("#f28c7e"))
	boss_admiral_hat = box(boss, Vector3(0, 3.45, 0.2), Vector3(1.9, 0.65, 0.95), Color("#26344d"))
	boss_straw_hat = cylinder(boss, Vector3(0, 3.45, 0.2), 0.42, 1.35, 0.35, GOLD)
	boss_straw_hat.hide()
	boss_anchor = box(boss, Vector3(-1.45, 1.8, 0.7), Vector3(0.55, 2.5, 0.55), Color("#4f5d73"))
	boss_bubble = label_at(boss, Vector3(0, 4.9, 0), "", Color("#e8fbff"), 34)
	boss_cue = label_at(boss, Vector3(0, 4.35, 0), "迷霧大提督・蟹甲將軍", Color("#ff9f5a"), 30)
	attack_ring = marker(boss_home_pos, STAMP_RED, 3.8)
	attack_ring.hide()

	seafood_grill = Node3D.new()
	seafood_grill.position = grill_pos
	add_child(seafood_grill)
	box(seafood_grill, Vector3(0, 0.52, 0), Vector3(2.9, 1.0, 1.3), TIMBER_LIGHT)
	box(seafood_grill, Vector3(0, 2.25, 0), Vector3(3.4, 0.26, 2.0), Color("#3496e8"))
	label_at(seafood_grill, Vector3(0, 2.95, 0), "海風海鮮燒烤攤 🦐", GOLD, 30)
	seafood_grill.hide()

	add_child(finale_chest)
	finale_chest.position = boss_home_pos + Vector3(-2.6, 0.0, 2.2)
	box(finale_chest, Vector3(0, 0.45, 0), Vector3(1.25, 0.86, 0.86), GOLD)
	box(finale_chest, Vector3(0, 0.88, 0), Vector3(1.32, 0.20, 0.92), Color("#e34b3b"))
	label_at(finale_chest, Vector3(0, 1.5, 0), "第一幕終章傳奇寶箱", GOLD, 28)
	finale_chest.hide()

func _apply_persisted_state() -> void:
	if PrologueState.harbor_boss_retired:
		boss_state = HarborBossState.RETIRED
		boss_admiral_hat.hide()
		boss_straw_hat.show()
		boss_anchor.hide()
		boss.position = grill_pos + Vector3(0, 0, -1.3)
		boss_cue.text = "海鮮燒烤大廚"
		seafood_grill.show()
		fog_harbor.hide()
		lighthouse_beam.show()
		finale_chest.visible = not PrologueState.harbor_chest_claimed

func _physics_process(delta: float) -> void:
	if lighthouse_beam and lighthouse_beam.visible:
		lighthouse_beam.rotation.y += delta * 0.55
	_update_mobs_ai(delta)
	_update_checkpoints()
	if boss_talk_timer > 0.0:
		boss_talk_timer -= delta
		if boss_talk_timer <= 0.0:
			boss_bubble.text = ""
	if not step_shared_physics(delta):
		return
	if not boss_active and boss_state == HarborBossState.IDLE and not PrologueState.harbor_boss_retired and flat(feet() - boss_home_pos).length() < 15.0:
		boss_active = true
		boss_timer = 1.2
		PrologueState.play_bgm("boss")
		_boss_say("全港造霧機全開！休想搶奪百年大燈塔！", 3.5)
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
				m["cd"] = 0.95 if tier == "unique" else (1.15 if tier == "rare" else 1.3)
				flash_hit(mn)
				var hit_r := 3.6 if tier == "unique" else (2.75 if tier == "rare" else 2.2)
				if dist < hit_r:
					take_player_damage(3 if tier == "unique" else (2 if tier == "rare" else 1))
		else:
			m_ring.hide()
			if dist < 12.0 and flat(mn.position - (m["home"] as Vector3)).length() < 14.0:
				mn.rotation.y = atan2(to_p.x, to_p.z)
				if (tier == "rare" or tier == "unique") and dist > 4.0 and float(m["ranged_cd"]) <= 0.0:
					m["ranged_cd"] = 2.3 if tier == "unique" else 2.7
					var base_yaw := atan2(to_p.x, to_p.z)
					var spread: Array = [-0.46, -0.23, 0.0, 0.23, 0.46] if tier == "unique" else [-0.28, 0.0, 0.28]
					for sa: float in spread:
						var dir := Vector3(sin(base_yaw + sa), 0.0, cos(base_yaw + sa)).normalized()
						spawn_enemy_projectile(mn.position, dir * 12.5, 2 if tier == "unique" else 1, Color("#ff7b3b") if tier == "unique" else MIST_CYAN)
				if dist <= (2.9 if tier == "unique" else 2.3) and float(m["cd"]) <= 0.0:
					m["state"] = "windup"
					m["timer"] = 0.60 if bool(m["rare"]) else 0.68
					m_ring.position = Vector3(mn.position.x, 0.04, mn.position.z)
					m_ring.show()
				elif dist > 1.8:
					mn.position += to_p.normalized() * (3.6 if bool(m["rare"]) else 3.25) * delta
			else:
				var to_home := flat((m["home"] as Vector3) - mn.position)
				if to_home.length() > 0.5:
					mn.position += to_home.normalized() * 2.2 * delta
					mn.rotation.y = atan2(to_home.x, to_home.z)

func _update_boss(delta: float) -> void:
	boss_timer -= delta
	var enraged := boss_hp <= int(MAX_BOSS_HP / 2)
	match boss_state:
		HarborBossState.IDLE:
			var toward := flat(feet() - boss.position)
			boss.rotation.y = atan2(toward.x, toward.z)
			boss_cue.text = "迷霧大提督（全港霧笛大警報！）" if enraged else "迷霧大提督・蟹甲將軍"
			if boss_timer <= 0.0:
				boss_state = HarborBossState.WINDUP
				boss_timer = 1.05 if enraged else 1.35
				attack_ring.position = boss.position + Vector3(0, 0.05, 0)
				attack_ring.show()
				boss_anchor.rotation_degrees.x = -75.0
				boss_cue.text = "紅光蓄力！按 [Q/RMB] 破防或 [Space] 閃避"
				boss_cue.modulate = STAMP_RED
		HarborBossState.WINDUP:
			if boss_timer <= 0.0:
				attack_ring.hide()
				boss_anchor.rotation_degrees.x = 24.0
				shake_time = 0.25
				shake_strength = 0.26
				if flat(feet() - boss.position).length() < 4.1:
					take_player_damage(2)
				var base_y := atan2(feet().x - boss.position.x, feet().z - boss.position.z)
				var rays := 9 if enraged else 7
				for ri in range(rays):
					var ang := base_y + (float(ri) - float(rays - 1) * 0.5) * 0.23
					spawn_enemy_projectile(boss.position, Vector3(sin(ang), 0.0, cos(ang)) * (14.0 if enraged else 12.0), 1, MIST_CYAN, 0.44)
				boss_state = HarborBossState.IDLE
				boss_timer = 0.88 if enraged else 1.15
				boss_cue.modulate = Color("#ff9f5a")
		HarborBossState.STAGGERED:
			boss.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.22
			boss_cue.text = "破防踉蹌！"
			boss_cue.modulate = GOLD
			if boss_timer <= 0.0:
				boss.rotation.z = 0.0
				boss_state = HarborBossState.IDLE
				boss_timer = 1.10
				boss_cue.modulate = Color("#ff9f5a")

func on_wolf_action() -> void:
	super.on_wolf_action()
	if boss_active and boss_state == HarborBossState.WINDUP and flat(feet() - boss.position).length() < 5.4:
		attack_ring.hide()
		boss_anchor.rotation_degrees.x = 0.0
		boss_state = HarborBossState.STAGGERED
		boss_timer = 3.0
		hitstop_frames = 6
		shake_time = 0.26
		shake_strength = 0.25
		flash_hit(boss)
		spawn_damage_pop(boss.position, "破防 STAGGER!", GOLD, true)
		_boss_say("嗚哇！我的大鐵錨被撞飛啦！", 2.4)

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
	if boss_active and flat(player.position - boss.position).length() < reach + 1.0:
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
	if boss_active and flat(pos - boss.position).length() < 2.3:
		PrologueState.play_sfx("hit")
		_apply_boss_damage(dmg, is_crit)
		return true
	return false

func _apply_boss_damage(dmg: int, is_crit: bool) -> void:
	var total := dmg + (PrologueState.get_stagger_bonus() if boss_state == HarborBossState.STAGGERED else 0)
	boss_hp = maxi(0, boss_hp - total)
	hitstop_frames = 3
	flash_hit(boss)
	register_combat_hit(boss.position, is_crit)
	spawn_damage_pop(boss.position, ("CRIT! %d" % total) if is_crit else "-%d" % total, GOLD if (is_crit or boss_state == HarborBossState.STAGGERED) else Color.WHITE, is_crit)
	if boss_hp <= 0:
		boss_active = false
		boss_state = HarborBossState.KNEELED
		attack_ring.hide()
		boss.rotation.z = 0.0
		boss.position.y = -0.45
		boss_cue.text = "[ E ] 蓋退休章！"
		boss_cue.modulate = GOLD
		_boss_say("等等……你說停戰令早就簽了一百年？！", 3.8)

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
		PrologueState.transition_to("res://prologue/ClocktowerOutpost.tscn", "from_waypoint", "舊軍鐘樓哨所")
		return
	if boss_state == HarborBossState.KNEELED and near(boss.position, 3.8):
		PrologueState.harbor_boss_retired = true
		boss_state = HarborBossState.RETIRED
		PrologueState.play_bgm("town")
		play_giant_retirement_stamp(boss.position)
		_boss_say("停戰百年了？！那我天天開造霧機電費找誰報銷啊！不幹了，烤蝦去！", 5.0)
		var ftw := create_tween()
		ftw.tween_property(fog_harbor, "scale", Vector3(2.4, 0.05, 2.4), 1.2)
		ftw.tween_callback(fog_harbor.hide)
		lighthouse_beam.show()
		spawn_flying_bird_flock(Vector3(64.0, 9.0, -6.0), Vector3(5.5, 0.4, 1.2), 7, Color("#fff7d6"))
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			boss_admiral_hat.hide()
			boss_straw_hat.show()
			boss_anchor.hide()
			boss.position = grill_pos + Vector3(0, 0, -1.3)
			boss_cue.text = "海鮮燒烤大廚"
			pop_in_node(seafood_grill)
			pop_in_node(finale_chest)
		)
		return
	if finale_chest.visible and near(finale_chest.position, 2.9):
		PrologueState.harbor_chest_claimed = true
		finale_chest.hide()
		PrologueState.orb_gold += 5
		PrologueState.coins += 100
		PrologueState.add_item_to_inventory(PrologueState.make_item("百年停戰・燈塔傳奇聖劍", "weapon", "unique", 9))
		show_player_emote("✨", 2.2)
		show_subtitle("開啟第一幕終章傳奇寶箱！獲【傳奇】燈塔傳奇聖劍 (ATK+9)＋金漆罐 x5＋100¢！", 4.8)
		return
	if near(ship_pos, 3.5):
		if PrologueState.harbor_boss_retired:
			show_player_emote("⛵", 2.0)
			show_subtitle("✦ 恭喜通關第一幕《雲丘停戰邊境》！《遠航號》已整備完成，準備啟航第二幕《珊瑚群島》！", 5.0)
		else:
			show_subtitle("海霧太濃無法出航！請先勸退大燈塔下的《迷霧大提督・蟹甲將軍》！", 3.6)

func _boss_say(words: String, duration := 3.2) -> void:
	boss_bubble.text = words
	boss_talk_timer = duration

func _update_ui() -> void:
	var step := "穿越霧港尋找傳奇怪，並勸退大燈塔下的《迷霧大提督・蟹甲將軍》"
	if PrologueState.harbor_boss_retired:
		step = "✦ 第一幕全區停戰完成！可領終章寶箱或登上《遠航號》"
	set_zone_objective("沉霧燈塔港（第一幕終章）", step)
	update_status_line()
	if boss_active or boss_state == HarborBossState.KNEELED:
		var badge := "警戒中"
		var bcol := Color("#ff9f5a")
		if boss_state == HarborBossState.WINDUP:
			badge = "紅光蓄力！按 [Q/RMB]"
			bcol = STAMP_RED
		elif boss_state == HarborBossState.STAGGERED:
			badge = "破防踉蹌！"
			bcol = GOLD
		elif boss_state == HarborBossState.KNEELED:
			badge = "按 [E] 蓋退休章"
			bcol = Color("#98ffbd")
		update_boss_bar(true, "迷霧大提督・蟹甲將軍", boss_hp, MAX_BOSS_HP, badge, bcol)
	else:
		update_boss_bar(false, "", 0, MAX_BOSS_HP)

	for d in loot_drops:
		if near(d["pos"], 2.4):
			set_prompt("[ E ] 拾取：" + PrologueState.format_item_title(d["item"]))
			return
	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.8):
		set_prompt("[ E ] 燈塔港傳送石陣（開啟世界地圖 [U]）")
	elif near(WEST_EXIT, 3.0):
		set_prompt("[ E ] 返回：舊軍鐘樓哨所")
	elif boss_state == HarborBossState.KNEELED and near(boss.position, 3.8):
		set_prompt("[ E ] 砸下【正式退休】紅章！（驅散百年海霧）")
	elif finale_chest.visible and near(finale_chest.position, 2.9):
		set_prompt("[ E ] 開啟第一幕終章傳奇寶箱")
	elif near(ship_pos, 3.5):
		set_prompt("[ E ] 登上《遠航號》（啟航第二幕）" if PrologueState.harbor_boss_retired else "[ E ] 遠航號（海霧尚未散去）")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼")
	else:
		set_prompt("")

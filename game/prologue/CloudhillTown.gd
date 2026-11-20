extends "res://prologue/PrologueBase.gd"

const WEST_EXIT := Vector3(-23.0, 0.0, 1.5)
const EAST_EXIT := Vector3(23.2, 0.0, 1.2)
const SHOP_POS := Vector3(-8.4, 0.0, -6.5)
const SHOP_INTERACT := Vector3(-7.6, 0.0, -3.2)
const TAVERN_POS := Vector3(7.2, 0.0, -7.8)
const TAVERN_DOOR := Vector3(6.2, 0.0, -4.0)
const WAYPOINT_POS := Vector3(-0.2, 0.0, 0.4)
const STASH_POS := Vector3(11.4, 0.0, 7.6)
const SLIME_HOME := Vector3(-3.4, 0.0, 5.2)
const DUMMY_1_POS := Vector3(3.2, 0.0, 8.6)
const DUMMY_2_POS := Vector3(6.4, 0.0, 8.2)
const LIGHTHOUSE_VIEW_POS := Vector3(-24.0, 0.0, 14.5)
const SANDBAR_CHEST_POS := Vector3(-11.0, 0.0, 22.8)

var goblin_bubble: Label3D
var goblin_talk_timer := 0.0
var slime_node: Node3D
var slime_bubble: Label3D
var dummies: Array[Node3D] = []
var ambient_chatter_timer := 3.5
var patron_bubble: Label3D
var waterwheel_node: Node3D
var sandbar_chest_beam: MeshInstance3D
var town_travelers: Array[Dictionary] = []

func _ready() -> void:
	can_attack = true
	scene_shadow_tint = Color("#4a5a8c")
	set_wind_profile(Vector2(0.95, 0.30), 1.25, 0.30, 0.13)
	_build_town()
	var spawn := Vector3(-19.5, 0.0, 1.5)
	if PrologueState.spawn_tag == "from_road":
		spawn = Vector3(19.5, 0.0, 1.2)
	elif PrologueState.spawn_tag == "from_waypoint":
		spawn = Vector3(-0.2, 0.0, 3.0)
	setup_core_trio(spawn)
	setup_camera_and_lighting(20.5, Color("#73e4f5"), Color("#eef3fc"), 0.88, Color("#ffe4ba"), 1.15, Color("#2b9cf0"), Color("#aef2ff"), Color("#2282d6"))
	setup_hud()
	PrologueState.play_bgm("town")

	if not PrologueState.has_sword:
		_goblin_say("早安！百年戰爭結束啦，武器全場 -50¢！", 5.5)
	elif PrologueState.boss_retired:
		_goblin_say("聽說哨長退休開茶攤了？按 [I] 造裝或找波波吞白裝！", 5.0)
	_update_ui()

func _build_town() -> void:
	# Expanded 52m x 34m Cloudhill Village Diorama (Little Joy x @amelicart)
	organic_mound(self, Vector3(0.0, -0.54, 0.5), 26.5, 17.5, 1.08, MEADOW_GREEN, -4.0)
	organic_mound(self, Vector3(-14.5, -0.50, 2.2), 13.5, 11.2, 1.0, MEADOW_LIGHT, 14.0)
	organic_mound(self, Vector3(13.8, -0.50, -1.8), 14.2, 11.8, 1.0, MEADOW_LIGHT, -16.0)
	organic_mound(self, Vector3(3.2, -0.51, 8.8), 13.5, 8.8, 1.0, Color("#7fb050"), 8.0)

	organic_mound(self, Vector3(0.0, 0.01, 0.4), 7.6, 6.2, 0.03, Color("#f5d9a1"), -8.0)
	organic_mound(self, Vector3(0.2, 0.018, 0.5), 5.0, 4.2, 0.025, Color("#ebd098"), 18.0)

	# Winding creek encircling the southern & eastern hillside with wooden bridges & waterfall
	curved_stream([
		Vector3(-22.0, 0.0, 9.5),
		Vector3(-12.5, 0.0, 11.8),
		Vector3(0.0, 0.0, 12.6),
		Vector3(14.0, 0.0, 9.8),
		Vector3(18.5, 0.0, 2.2),
		Vector3(19.5, 0.0, -8.5)
	], 3.2, Color("#3496e8"), Color("#e0f8ff"), -0.15)
	waterfall_cascade(Vector3(-19.5, 0.0, 9.2), 2.6, 3.8, 42.0, Color("#52b8ff"), Color("#eefbff"))
	wooden_footbridge(Vector3(18.5, 0.0, 1.2), 4.4, 2.4, 4.0, 0.44)
	wooden_footbridge(Vector3(-1.5, 0.0, 12.4), 3.8, 2.0, 92.0, 0.36)

	# Spinning wooden waterwheel by the eastern creek (Little Joy craftsmanship)
	waterwheel_node = Node3D.new()
	waterwheel_node.position = Vector3(16.9, 0.65, -2.8)
	add_child(waterwheel_node)
	cylinder(waterwheel_node, Vector3(0, 0, 0), 1.35, 1.35, 0.36, TIMBER_LIGHT)
	for wi in range(6):
		var paddle := box(waterwheel_node, Vector3(0, 0, 0), Vector3(0.22, 3.1, 0.52), TIMBER)
		paddle.rotation_degrees.z = float(wi) * 30.0
	cylinder(self, Vector3(16.2, 0.35, -2.8), 0.14, 0.18, 1.4, TIMBER)

	curved_path([WEST_EXIT, Vector3(-16.5, 0, 2.4), Vector3(-9.5, 0, 1.8), Vector3(-2.0, 0, 0.6)], 2.6, TRAIL, TRAIL_STONE)
	curved_path([Vector3(2.2, 0, 0.5), Vector3(9.5, 0, 2.2), Vector3(16.5, 0, 1.5), EAST_EXIT], 2.6, TRAIL, TRAIL_STONE)
	curved_path([Vector3(-2.8, 0, -0.6), Vector3(-5.6, 0, -2.0), SHOP_INTERACT], 2.2, TRAIL, TRAIL_STONE)
	curved_path([Vector3(2.4, 0, -0.9), Vector3(4.6, 0, -2.4), TAVERN_DOOR], 2.2, TRAIL, TRAIL_STONE)
	curved_path([Vector3(0.2, 0, 2.8), Vector3(-1.8, 0, 4.2), SLIME_HOME], 1.9, TRAIL, TRAIL_STONE)
	curved_path([Vector3(2.4, 0, 3.2), Vector3(5.8, 0, 6.2), Vector3(9.8, 0, 7.2)], 1.9, TRAIL, TRAIL_STONE)

	# Expanded 72m x 50m Walkable Coastal Village + Lighthouse Islet + Northern Archway Promenade + 360 Ocean Panorama!
	organic_mound(self, Vector3(0.0, -0.52, -16.5), 18.5, 8.2, 1.04, MEADOW_LIGHT, 6.0)
	organic_mound(self, Vector3(24.5, -0.52, 11.5), 11.5, 9.2, 1.04, MEADOW_GREEN, -14.0)
	curved_path([Vector3(-8.0, 0, -10.0), Vector3(-2.5, 0, -16.2), Vector3(6.5, 0, -16.4), Vector3(13.5, 0, -11.5)], 2.2, TRAIL, TRAIL_STONE)
	curved_path([Vector3(14.5, 0, 6.2), Vector3(21.0, 0, 9.5), Vector3(26.2, 0, 12.2)], 2.0, TRAIL)
	curved_path([Vector3(-13.5, 0, 8.2), Vector3(-19.5, 0, 12.5), Vector3(-24.0, 0, 14.5)], 2.0, BOARDWALK)
	wooden_footbridge(Vector3(-21.2, 0.0, 13.2), 5.6, 2.2, 32.0, 0.35)
	lighthouse_islet(Vector3(-27.2, 0.0, 15.2), 24.0)
	# Lighthouse Panoramic Telescope Stand
	var scope := Node3D.new()
	scope.position = LIGHTHOUSE_VIEW_POS
	add_child(scope)
	cylinder(scope, Vector3(0, 0.65, 0), 0.08, 0.11, 1.3, TIMBER)
	var tube := cylinder(scope, Vector3(0, 1.32, 0), 0.14, 0.10, 0.72, GOLD)
	tube.rotation_degrees = Vector3(72.0, -32.0, 0.0)
	marker(LIGHTHOUSE_VIEW_POS + Vector3(0.4, 0, -0.4), Color("#7dd6ff"), 0.62)
	stone_archway(Vector3(0.5, 0.0, -16.8), 0.0, 1.15, true)
	cozy_cabin(Vector3(-11.5, 0.0, -17.5), 18.0, CORAL_ROOF, WHITE_WALL)
	cozy_cabin(Vector3(12.2, 0.0, -17.2), -22.0, Color("#d6583a"), WHITE_WALL)
	flower_patch(Vector3(24.5, 0, 11.5), 12, [Color("#ff9eb5"), Color("#ffe066"), Color("#87c8ff")], 3.2)
	spawn_destructible_crate(Vector3(26.5, 0.0, 13.0), 4)
	spawn_destructible_crate(Vector3(1.5, 0.0, -19.2), 4)
	spawn_destructible_crate(Vector3(-24.8, 0.0, 13.8), 4)
	# Seamless full-island meadow + Southern Sandbar Islet + Northern Windmill Hill (86m x 62m!)
	organic_mound(self, Vector3(0.0, -0.58, 0.0), 42.5, 30.0, 1.12, MEADOW_GREEN, 2.0)
	# Southern Sandbar Islet connected by wooden footbridge (@shoejaat e986e55c)
	organic_mound(self, Vector3(-11.0, -0.45, 22.8), 10.5, 6.2, 0.85, Color("#f2d694"), -8.0)
	organic_mound(self, Vector3(-11.0, -0.18, 22.8), 8.2, 4.8, 0.42, MEADOW_LIGHT, -6.0)
	wooden_footbridge(Vector3(-9.5, 0.0, 16.5), 4.6, 2.2, 84.0, 0.36)
	cozy_tree(Vector3(-14.5, 0.0, 23.2), 1.15, MEADOW_GREEN, 6.0)
	pine_tree(Vector3(-6.8, 0.0, 23.8), 1.15, PINE_TEAL)
	# Southern Sandbar Hidden Treasure Chest (gifts Paycheck Double Seal!)
	var schest := Node3D.new()
	schest.position = SANDBAR_CHEST_POS
	schest.rotation_degrees.y = 18.0
	add_child(schest)
	box(schest, Vector3(0, 0.42, 0), Vector3(1.15, 0.84, 0.82), GOLD, true)
	box(schest, Vector3(0, 0.84, 0), Vector3(1.22, 0.16, 0.88), CORAL_ROOF)
	sandbar_chest_beam = cylinder(schest, Vector3(0, 2.1, 0), 0.10, 0.16, 4.2, GOLD, true)
	sandbar_chest_beam.visible = not PrologueState.sandbar_chest_claimed
	marker(SANDBAR_CHEST_POS + Vector3(0, 0, -1.1), GOLD, 0.62)
	spawn_destructible_crate(Vector3(-8.8, 0.0, 21.8), 5)
	# Northern Windmill Hilltop Promenade
	curved_path([Vector3(6.5, 0, -16.4), Vector3(13.5, 0, -21.5), Vector3(20.5, 0, -22.5)], 2.1, TRAIL, TRAIL_STONE)
	cozy_cabin(Vector3(22.0, 0.0, -22.8), -32.0, CORAL_ROOF, WHITE_WALL)
	spawn_destructible_crate(Vector3(18.5, 0.0, -22.0), 4)
	build_horizon_panorama(Vector3(0.0, 0.0, 0.0), 42.0, 29.8, "day_island")
	# Wind-blown @amelicart sunny meadow grass & wildflowers (1,180 tufts via MultiMesh)
	spawn_wind_grass_meadow(Vector3(-13.5, 0, 1.8), 10.5, 8.2, 220, MEADOW_GREEN, Color("#bfe36b"), Color("#ffe066"), 0.18, 1.0)
	spawn_wind_grass_meadow(Vector3(12.5, 0, -1.2), 10.8, 8.2, 200, MEADOW_GREEN, Color("#c5e872"), Color("#ff9eb5"), 0.18, 1.0)
	spawn_wind_grass_meadow(Vector3(1.5, 0, 8.2), 10.2, 5.5, 160, Color("#7ab04d"), Color("#b8de64"), Color("#87c8ff"), 0.16, 0.95)
	spawn_wind_grass_meadow(Vector3(0.0, 0, -16.5), 14.5, 5.8, 150, MEADOW_LIGHT, Color("#d2f07d"), Color("#ff9eb5"), 0.22, 1.05)
	spawn_wind_grass_meadow(Vector3(24.5, 0, 11.5), 9.2, 6.8, 130, MEADOW_GREEN, Color("#c2e66e"), Color("#ffe066"), 0.24, 1.05)
	spawn_wind_grass_meadow(Vector3(-11.0, 0, 22.5), 7.8, 4.5, 140, MEADOW_LIGHT, Color("#d2f07d"), Color("#ff9eb5"), 0.28, 1.0)
	spawn_wind_grass_meadow(Vector3(17.5, 0, -22.0), 10.5, 5.8, 180, MEADOW_GREEN, Color("#bfe36b"), Color("#ffe066"), 0.24, 1.0)

	invisible_boundary_wall(Vector3(0.0, 0.8, -30.5), Vector3(86.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(0.0, 0.8, 30.5), Vector3(86.0, 1.8, 0.8))
	invisible_boundary_wall(Vector3(-42.5, 0.8, 0.0), Vector3(0.8, 1.8, 62.0))
	invisible_boundary_wall(Vector3(42.5, 0.8, 0.0), Vector3(0.8, 1.8, 62.0))

	# Cliff outcrops & hillside cottages
	cliff_outcrop(Vector3(-20.5, 0.0, -9.8), 3.6, 2.8, 3.2, STONE_LIGHT, MEADOW_GREEN, 16.0)
	cliff_outcrop(Vector3(20.8, 0.0, -9.5), 3.4, 2.6, 3.0, STONE, MEADOW_LIGHT, -22.0)
	for h in [
		[Vector3(-15.8, 0.0, -11.5), 18.0],
		[Vector3(-1.8, 0.0, -12.6), -12.0],
		[Vector3(16.2, 0.0, -10.8), -26.0],
		[Vector3(-18.5, 0.0, -5.2), 34.0]
	]:
		var cot := Node3D.new()
		cot.position = h[0]
		cot.rotation_degrees.y = float(h[1])
		add_child(cot)
		box(cot, Vector3(0, 2.0, 0), Vector3(3.2, 4.0, 2.8), WHITE_WALL, true)
		var roof := cylinder(cot, Vector3(0, 4.5, 0), 0.25, 2.5, 1.6, CORAL_ROOF)
		roof.scale.z = 0.88

	# Volumetric drifting clouds & diagonal sunbeams
	fluffy_cloud(Vector3(26.0, 4.2, -9.0), 1.35, 2.2, CLOUD_WHITE)
	fluffy_cloud(Vector3(28.0, 3.8, 4.5), 1.25, 1.8, CLOUD_WHITE)
	fluffy_cloud(Vector3(-24.0, 4.5, -10.0), 1.2, 1.9, CLOUD_WHITE)
	sunbeam_shaft(Vector3(-6.0, 0.0, -2.0), 3.4, 20.0, Color(1.0, 0.94, 0.68, 0.10))
	sunbeam_shaft(Vector3(8.5, 0.0, 1.0), 3.6, 20.0, Color(1.0, 0.94, 0.68, 0.10))

	# 1. Angled Bone-Helmet Goblin Clearance Stall
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
	cylinder(shop_root, Vector3(-3.8, 0.42, 1.1), 0.38, 0.42, 0.84, TIMBER_LIGHT)
	box(shop_root, Vector3(3.6, 0.38, 0.9), Vector3(0.8, 0.76, 0.8), TIMBER)
	label_at(shop_root, Vector3(2.4, 2.35, 1.8), "-50¢", STAMP_RED, 38)
	marker(SHOP_INTERACT, GOLD, 0.68)

	var gob := Node3D.new()
	gob.position = Vector3(0, 0.0, 0.35)
	shop_root.add_child(gob)
	sphere(gob, Vector3(0, 0.95, 0), Vector3(1.25, 1.15, 0.95), GOBLIN_GREEN)
	sphere(gob, Vector3(0, 1.78, 0.06), Vector3(0.96, 0.84, 0.86), GOBLIN_GREEN)
	sphere(gob, Vector3(0, 2.18, 0.08), Vector3(1.04, 0.56, 0.96), Color("#f7f4ef"))
	goblin_bubble = label_at(gob, Vector3(0, 3.30, 0), "", Color("#fff7c2"), 32)
	register_living_npc(gob, 0.0, 0.07, 3.0)

	# 2. Angled Retired Monsters Tavern & Lived-in Outdoor Patio
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
	organic_mound(tav, Vector3(4.8, 0.14, 1.8), 3.4, 2.8, 0.28, BOARDWALK, 12.0)
	cylinder(tav, Vector3(4.4, 0.62, 1.7), 0.72, 0.68, 0.14, TIMBER_LIGHT)
	cylinder(tav, Vector3(4.4, 0.34, 1.7), 0.14, 0.18, 0.56, TIMBER)
	sphere(tav, Vector3(4.4, 0.76, 1.7), Vector3(0.36, 0.22, 0.36), Color("#fff2d6"))
	var pig := Node3D.new()
	pig.position = Vector3(5.35, 0.28, 1.75)
	tav.add_child(pig)
	sphere(pig, Vector3(0, 0.52, 0), Vector3(0.82, 0.76, 0.76), Color("#f29cb0"))
	sphere(pig, Vector3(0, 1.08, 0.05), Vector3(0.62, 0.56, 0.58), Color("#f5a9ba"))
	register_living_npc(pig, 0.28, 0.05, 2.6)
	var peng := Node3D.new()
	peng.position = Vector3(3.15, 0.28, 2.15)
	tav.add_child(peng)
	sphere(peng, Vector3(0, 0.42, 0), Vector3(0.55, 0.68, 0.52), Color("#3b64a8"))
	sphere(peng, Vector3(0.36, 0.56, 0.15), Vector3(0.32, 0.24, 0.32), Color("#d4d8e2"))
	register_living_npc(peng, 0.28, 0.08, 4.4)
	# @amelicart-inspired Oni sipping from a mug & stacked tiny blue Slimes
	var oni := Node3D.new()
	oni.position = Vector3(2.55, 0.28, 2.45)
	tav.add_child(oni)
	cylinder(oni, Vector3(0, 0.55, 0), 0.38, 0.42, 0.95, Color("#d95f52"))
	sphere(oni, Vector3(0, 1.25, 0), Vector3(0.60, 0.56, 0.58), Color("#e36d5e"))
	cylinder(oni, Vector3(-0.18, 1.60, 0.10), 0.03, 0.09, 0.28, WHITE_WALL)
	cylinder(oni, Vector3(0.18, 1.60, 0.10), 0.03, 0.09, 0.28, WHITE_WALL)
	cylinder(oni, Vector3(0.42, 0.72, 0.25), 0.14, 0.14, 0.26, GOLD)
	register_living_npc(oni, 0.28, 0.04, 2.2)
	var slime_stack := Node3D.new()
	slime_stack.position = Vector3(6.15, 0.28, 1.25)
	tav.add_child(slime_stack)
	sphere(slime_stack, Vector3(0, 0.28, 0), Vector3(0.56, 0.44, 0.56), Color("#58b9ff"))
	sphere(slime_stack, Vector3(0, 0.64, 0), Vector3(0.38, 0.32, 0.38), Color("#7dd0ff"))
	register_living_npc(slime_stack, 0.28, 0.09, 5.0)
	patron_bubble = label_at(pig, Vector3(-0.3, 2.05, 0), "豚骨麵真香♪", Color("#ffe4b5"), 26)
	marker(TAVERN_DOOR, Color("#69c5ed"), 0.64)

	bunting_line(SHOP_POS + Vector3(2.8, 3.6, 1.5), WAYPOINT_POS + Vector3(0, 2.8, 0), 0.85, [CORAL_ROOF, GOLD, BUNTING_BLUE, WHITE_WALL], 8)
	bunting_line(WAYPOINT_POS + Vector3(0, 2.8, 0), TAVERN_POS + Vector3(-2.6, 3.8, 2.2), 0.85, [GOLD, BUNTING_BLUE, CORAL_ROOF, WHITE_WALL], 8)

	# 3. Central Waypoint Perch
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
	marker(WAYPOINT_POS + Vector3(0, 0, 1.5), GOLD, 0.65)

	# 4. Extended Beast Drinking Cove (Southwest)
	organic_mound(self, Vector3(-11.5, 0.04, 6.8), 4.2, 2.8, 0.12, Color("#62c4ed"), -22.0, true)
	boulder_cluster(Vector3(-14.6, 0, 6.2), 1.25, STONE_LIGHT, true, true, 16.0)
	boulder_cluster(Vector3(-8.4, 0, 8.2), 0.95, STONE, true, true, -30.0)

	# 5. Training Dummies & Stash Chest
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

	var stash_root := Node3D.new()
	stash_root.position = STASH_POS
	stash_root.rotation_degrees.y = -28.0
	add_child(stash_root)
	box(stash_root, Vector3(0, 0.48, 0), Vector3(1.3, 0.96, 0.9), GOLD, true)
	cylinder(stash_root, Vector3(1.45, 0.45, 0.25), 0.42, 0.46, 0.9, TIMBER_LIGHT)
	marker(STASH_POS + Vector3(0, 0, -1.2), GOLD, 0.58)

	# 6. Clean Slime Bobo Auto-Salvage Meadow
	slime_node = Node3D.new()
	slime_node.position = SLIME_HOME
	add_child(slime_node)
	sphere(slime_node, Vector3(0, 0.40, 0), Vector3(0.92, 0.72, 0.92), Color("#58d6d6"))
	sphere(slime_node, Vector3(-0.2, 0.48, 0.36), Vector3(0.14, 0.14, 0.12), Color("#1e2636"), true)
	sphere(slime_node, Vector3(0.2, 0.48, 0.36), Vector3(0.14, 0.14, 0.12), Color("#1e2636"), true)
	slime_bubble = label_at(slime_node, Vector3(0, 1.32, 0), "波波 ♻️", Color("#b8ffff"), 26)

	for tp in [
		[Vector3(-21.2, 0, -4.8), 1.25, PINE_DARK],
		[Vector3(-21.8, 0, 5.2), 1.2, PINE_TEAL],
		[Vector3(-16.5, 0, 12.2), 1.15, MEADOW_GREEN],
		[Vector3(14.8, 0, 12.0), 1.2, MEADOW_LIGHT],
		[Vector3(21.4, 0, -5.0), 1.15, Color("#d88662")],
		[Vector3(21.2, 0, 6.2), 1.2, PINE_TEAL]
	]:
		cozy_tree(tp[0], float(tp[1]), tp[2], randf_range(-6.0, 6.0), true)
	lantern_post(Vector3(-14.5, 0, 0.5), 2.5, FIRE_ORANGE, -15.0)
	lantern_post(Vector3(14.4, 0, 3.2), 2.5, FIRE_ORANGE, 24.0)
	flower_patch(Vector3(-5.8, 0, 7.2), 9, [Color("#ff9eb5"), Color("#ffe066"), Color("#87c8ff")], 2.3)
	flower_patch(Vector3(9.6, 0, 3.4), 8, [Color("#ffd966"), Color("#f28c7e"), WHITE_WALL], 2.0)
	flower_patch(Vector3(-14.2, 0, -1.8), 7, [Color("#ffe066"), Color("#a67ee8")], 1.8)
	spawn_ambient_motes(Vector3(0.0, 2.0, 0.0), Vector3(42.0, 3.4, 22.0), 28, Color("#fff8d6"), 0.09)

	transition_signpost(WEST_EXIT, "← 營火", Color("#b8f5ff"), 14.0)
	var arch := Node3D.new()
	arch.position = EAST_EXIT
	arch.rotation_degrees.y = -10.0
	add_child(arch)
	cylinder(arch, Vector3(0, 2.1, -2.3), 0.22, 0.28, 4.2, TIMBER)
	cylinder(arch, Vector3(0, 2.1, 2.3), 0.22, 0.28, 4.2, TIMBER)
	var beam := box(arch, Vector3(0, 4.0, 0.0), Vector3(0.52, 0.48, 5.4), TIMBER_LIGHT)
	beam.rotation_degrees.x = 2.0
	bunting_line(EAST_EXIT + Vector3(0, 3.8, -2.2), EAST_EXIT + Vector3(0, 3.8, 2.2), 0.55, [BUNTING_BLUE, GOLD, CORAL_ROOF], 5)
	marker(EAST_EXIT, GOLD, 0.95)
	label_at(self, EAST_EXIT + Vector3(0, 4.8, 0), "→ 雲海古道", GOLD, 34)
	_spawn_town_travelers()

func _spawn_town_travelers() -> void:
	var t1 := build_fellow_rider(Vector3(-5.5, 0, 2.2), Color("#e8735a"), Color("#7a5440"), Vector3(1.45, 1.15, 1.75), "蜜熊")
	t1["waypoints"] = [Vector3(-5.5, 0, 2.2), Vector3(2.2, 0, 3.2), Vector3(7.2, 0, -1.8), Vector3(-2.0, 0, -1.4)]
	t1["wp_idx"] = 0
	t1["lines"] = ["波波把我的白裝全吃光了✨", "有人要一起打哨長嗎？", "五折短劍真香！"]
	t1["chat_t"] = 2.0
	town_travelers.append(t1)

	var t2 := build_fellow_rider(Vector3(9.5, 0, 3.5), Color("#6ec29a"), Color("#e3dccf"), Vector3(1.05, 1.05, 1.65), "白鹿")
	t2["waypoints"] = [Vector3(9.5, 0, 3.5), Vector3(14.5, 0, 1.6), Vector3(4.5, 0, 0.2), Vector3(7.2, 0, 5.5)]
	t2["wp_idx"] = 0
	t2["lines"] = ["剛在古道噴出黃裝長劍！", "酒館豚骨麵超補血♪", "按 C 可以隨時拉我助拳！"]
	t2["chat_t"] = 3.8
	town_travelers.append(t2)

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for tr in town_travelers:
		var n: Node3D = tr["node"]
		var wps: Array = tr["waypoints"]
		var idx: int = int(tr["wp_idx"])
		var tgt: Vector3 = wps[idx]
		var diff := flat(tgt - n.position)
		if diff.length() < 0.5:
			tr["wp_idx"] = (idx + 1) % wps.size()
		else:
			n.position += diff.normalized() * 2.5 * delta
			n.rotation.y = atan2(diff.x, diff.z)
			n.position.y = absf(sin(t * 7.5 + float(idx))) * 0.10
		tr["chat_t"] = float(tr["chat_t"]) - delta
		if float(tr["chat_t"]) <= 0.0:
			tr["chat_t"] = 5.5
			var lines: Array = tr["lines"]
			(tr["bubble"] as Label3D).text = String(lines[randi() % lines.size()])

	if goblin_talk_timer > 0.0:
		goblin_talk_timer -= delta
		if goblin_talk_timer <= 0.0:
			goblin_bubble.text = ""
	ambient_chatter_timer -= delta
	if ambient_chatter_timer <= 0.0:
		ambient_chatter_timer = 5.5
		var lines := ["豚骨麵真香♪", "企鵝老闆，再來一盤煎餃！", "稻草人還在橋頭加班？", "陽光真暖和～"]
		patron_bubble.text = lines[randi() % lines.size()]

	slime_node.position.y = absf(sin(t * 4.8)) * 0.18
	slime_node.scale = Vector3(1.0 + sin(t * 9.6) * 0.06, 1.0 - sin(t * 9.6) * 0.06, 1.0 + sin(t * 9.6) * 0.06)
	if waterwheel_node and is_instance_valid(waterwheel_node):
		waterwheel_node.rotation.z -= delta * 1.15
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
			PrologueState.add_item_to_inventory(PrologueState.make_item("旅人橡木彈弓", "weapon", "magic", 1, "slingshot"))
			PrologueState.play_sfx("coin")
			show_player_emote("💰", 1.4)
			_goblin_say("爽快！再送你《旅人彈弓》（支援騎射！）與白裝胚子！", 5.5)
			play_cinematic_shot(SHOP_INTERACT + Vector3(2.8, 2.2, 4.4), SHOP_INTERACT + Vector3(-0.3, 1.1, -1.0), 1.15, true, 46.0, true)
			create_tween().tween_property(player, "rotation:y", player.rotation.y + TAU, 0.45)
		else:
			show_player_emote("?", 1.2)
			_goblin_say("骷髏王冠小夜燈特價 30¢！按 [I] 造裝吧！", 4.0)
		return

	if near(TAVERN_DOOR, 2.8):
		show_player_emote("✨", 1.4)
		show_subtitle("退休魔物大酒館：企鵝侍應生正端著拉麵穿梭席間！", 3.5)
		return

	if near(SLIME_HOME, 2.3):
		var res := PrologueState.salvage_normal_items()
		if int(res["count"]) > 0:
			show_player_emote("✨", 1.4)
			flash_hit(slime_node)
			spawn_bouncing_coins(SLIME_HOME, 4, 0)
			slime_bubble.text = "咕嚕！+%d¢ 藍印章+%d" % [int(res["coins"]), int(res["blue"])]
			show_subtitle("波波吞掉 %d 件白裝 → +%d¢、藍印章 x%d！" % [int(res["count"]), int(res["coins"]), int(res["blue"])], 3.8)
		else:
			show_player_emote("?", 1.1)
			slime_bubble.text = "咕啾？（沒有白裝喔）"
		return

	if near(STASH_POS + Vector3(0, 0, -1.2), 2.6):
		toggle_inventory()
		return

	if near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.7):
		if PrologueState.waypoint_road_unlocked:
			PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_waypoint", "雲海瞭望台（重置）")
		else:
			show_player_emote("?", 1.1)
			show_subtitle("先往東走進雲海古道，即可解鎖驛站快傳！", 3.2)
		return

	if near(WEST_EXIT, 2.8):
		PrologueState.transition_to("res://prologue/CampfireClearing.tscn", "from_town", "湖畔營火窩")
		return

	if near(LIGHTHOUSE_VIEW_POS, 2.8):
		play_cinematic_shot(Vector3(-34.0, 9.5, 24.5), Vector3(-6.0, 2.0, 2.0), 2.8, true, 52.0, true)
		spawn_flying_bird_flock(Vector3(-28.0, 6.2, 12.0), Vector3(4.8, 0.4, -1.4), 6)
		show_player_emote("🔭", 1.6)
		if not PrologueState.lighthouse_viewed:
			PrologueState.lighthouse_viewed = true
			spawn_bouncing_coins(LIGHTHOUSE_VIEW_POS, 4, 5)
			show_subtitle("遠眺雲丘海灣全景！發現隱藏觀景點（+20¢）", 3.6)
		else:
			show_subtitle("海風拂面，燈塔與雲丘市集盡收眼底。", 2.8)
		return

	if near(SANDBAR_CHEST_POS, 2.8):
		if not PrologueState.sandbar_chest_claimed:
			PrologueState.sandbar_chest_claimed = true
			PrologueState.unlock_seal("paycheck")
			PrologueState.orb_gold += 1
			PrologueState.play_sfx("coin")
			if sandbar_chest_beam:
				sandbar_chest_beam.hide()
			spawn_bouncing_coins(SANDBAR_CHEST_POS, 6, 5)
			spawn_damage_pop(SANDBAR_CHEST_POS, "獲得【雙薪印章】!", GOLD, true)
			show_player_emote("✨", 1.6)
			show_subtitle("開啟沙洲秘寶箱！獲《雙薪印章》（暴擊+20%兼爆金幣）與《百年金漆罐》x1！", 4.4)
		else:
			show_subtitle("沙洲秘寶箱已開啟，按 [I] 即可切換《雙薪印章》！", 2.8)
		return

	if near(EAST_EXIT, 2.8):
		if not PrologueState.has_sword:
			show_player_emote("💦", 1.4)
			_goblin_say("先來買把五折短劍再去打哨長吧！", 4.0)
			return
		PrologueState.transition_to("res://prologue/CloudhillRoad.tscn", "from_town", "雲海古道")

func on_sword_hit() -> void:
	var reach := 3.2 if combo_step == 3 else 2.3
	for d in dummies:
		if flat(player.position - d.position).length() < reach:
			_hit_dummy(d)

func on_projectile_hit(pos: Vector3) -> bool:
	for d in dummies:
		if flat(pos - d.position).length() < 1.25:
			_hit_dummy(d)
			return true
	return false

func _hit_dummy(d: Node3D) -> void:
	var is_crit := randi() % 100 < PrologueState.get_total_crit()
	var dmg := maxi(1, int(round(float(PrologueState.get_total_atk()) * get_attack_multiplier())) * (2 if is_crit else 1))
	hitstop_frames = 3
	shake_time = 0.08
	shake_strength = 0.14
	PrologueState.play_sfx("hit")
	flash_hit(d)
	register_combat_hit(d.position, is_crit)
	spawn_damage_pop(d.position, ("CRIT! %d" % dmg) if is_crit else "-%d" % dmg, GOLD if is_crit else Color.WHITE, is_crit or combo_step == 3)
	var tw := create_tween()
	tw.tween_property(d, "rotation:z", 0.38, 0.07)
	tw.tween_property(d, "rotation:z", 0.0, 0.16)

func _goblin_say(words: String, duration := 4.5) -> void:
	goblin_bubble.text = words
	goblin_talk_timer = duration

func _update_ui() -> void:
	var step := "向哥布林買五折短劍" if not PrologueState.has_sword else "按 [I] 造裝／切印章，或過東木橋出發刷怪"
	if PrologueState.boss_retired:
		step = "找波波吞白裝，或經驛站重刷古道"
	set_zone_objective("雲丘市集", step)
	update_status_line()

	if near(SHOP_INTERACT, 2.8):
		set_prompt("[ E ] 購入五折短劍 (-50¢)" if not PrologueState.has_sword else "[ E ] 逛清倉行")
	elif near(TAVERN_DOOR, 2.8):
		set_prompt("[ E ] 退休魔物大酒館")
	elif near(SLIME_HOME, 2.3):
		set_prompt("[ E ] 波波一鍵吞白裝換通貨")
	elif near(STASH_POS + Vector3(0, 0, -1.2), 2.6):
		set_prompt("[ E ] 造裝工坊 [I]")
	elif near(LIGHTHOUSE_VIEW_POS, 2.8):
		set_prompt("[ E ] 燈塔全景望遠鏡（遠眺海灣）")
	elif near(SANDBAR_CHEST_POS, 2.8):
		set_prompt("[ E ] 開啟沙洲秘寶箱" if not PrologueState.sandbar_chest_claimed else "[ E ] 沙洲秘寶箱（已開啟）")
	elif near(WAYPOINT_POS + Vector3(0, 0, 1.5), 2.7):
		set_prompt("[ E ] 快傳重置雲海古道" if PrologueState.waypoint_road_unlocked else "[ E ] 信使鳥驛站")
	elif near(WEST_EXIT, 2.8):
		set_prompt("[ E ] 返回：湖畔營火")
	elif near(EAST_EXIT, 2.8):
		set_prompt("[ E ] 前往：雲海古道")
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		set_prompt("[ F ] 騎上巨狼")
	else:
		set_prompt("")

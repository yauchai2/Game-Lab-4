extends Node3D

# Palette inspired by warm painterly storybook day/night contrast
const NIGHT_GRASS := Color("#395264")
const DAY_GRASS := Color("#d89448")
const TRAIL := Color("#e5be8a")
const STONE := Color("#8a8796")
const STONE_LIGHT := Color("#b7b3c4")
const TIMBER := Color("#78523d")
const TIMBER_LIGHT := Color("#a87854")
const PINE_DARK := Color("#233952")
const PINE_TEAL := Color("#2e6b6b")
const MIST_CYAN := Color("#5ae8e5")
const FIRE_ORANGE := Color("#ff9838")
const GOLD := Color("#f5c65b")
const GOBLIN_GREEN := Color("#6ec25a")
const PINK_PEAK := Color("#d896c8")
const PURPLE_PEAK := Color("#9688d4")
const RED_MESA := Color("#b85d48")
const CLOUD_WHITE := Color("#f7eaf2")
const STAMP_RED := Color("#e03c3c")

# Zone anchors (continuous left-to-right 2.5D flow)
const CAMPFIRE_POS := Vector3(-24.0, 0.0, 0.0)
const SHOP_POS := Vector3(-11.5, 0.0, -2.5)
const SHOP_INTERACT := Vector3(-11.5, 0.0, 0.2)
const TIMBER_POS := Vector3(-3.5, 0.0, 0.0)
const WALL_X := 5.0
const NARROW_SLIT_Z := -3.4
const GATE_Z := 1.4
const LEVER_POS := Vector3(6.6, 0.0, -3.4)
const BRIDGE_START_X := 11.0
const BOSS_HOME := Vector3(17.5, 0.0, 0.0)
const TEA_STALL_POS := Vector3(12.8, 0.0, -3.6)
const VISTA_POS := Vector3(28.5, 0.0, 0.0)
const BOUNTY_POS := Vector3(27.0, 0.0, -3.2)

var campfire_flame: MeshInstance3D
var campfire_smoke: MeshInstance3D
var campfire_light: OmniLight3D
var timber_barricade: Node3D
var stone_gate: MeshInstance3D
var lever_handle: MeshInstance3D
var tea_stall: Node3D
var goblin_npc: Node3D
var goblin_bubble: Label3D
var mist_pillars: Array[MeshInstance3D] = []
var distant_riders: Array[Node3D] = []

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var mesh := mesh_at(parent, pos, shape, color)
	if solid:
		var collider_shape := BoxShape3D.new()
		collider_shape.size = size
		var body := StaticBody3D.new()
		mesh.add_child(body)
		add_shape(body, collider_shape, Vector3.ZERO)
	return mesh

func add_shape(body: CollisionObject3D, shape: Shape3D, offset: Vector3) -> void:
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = offset
	body.add_child(collider)

func mesh_at(parent: Node3D, pos: Vector3, mesh: Mesh, color: Color, unshaded := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = pos
	return instance

func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := mesh_at(parent, pos, mesh, color, unshaded)
	instance.scale = size
	return instance

func cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, h: float, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 10
	return mesh_at(parent, pos, mesh, color, unshaded)

func label_at(parent: Node3D, pos: Vector3, words: String, color := Color.WHITE, font_size := 38) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 10
	label.pixel_size = 0.0085
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.position = pos
	return label

func marker(pos: Vector3, color: Color, radius := 0.55) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	return mesh_at(self, pos + Vector3.UP * 0.03, mesh, color, true)

func pine_tree(pos: Vector3, scale_val := 1.0, tint := PINE_DARK) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_val
	add_child(root)
	cylinder(root, Vector3(0, 1.1, 0), 0.24, 0.34, 2.2, TIMBER)
	cylinder(root, Vector3(0, 2.5, 0), 0.12, 1.45, 2.2, tint)
	cylinder(root, Vector3(0, 3.9, 0), 0.06, 1.10, 1.9, tint.lightened(0.08))

func build_world() -> void:
	# Continuous playable floor across Zones A-D
	box(self, Vector3(-22.0, -0.5, 0.0), Vector3(14.0, 1.0, 13.0), NIGHT_GRASS)
	box(self, Vector3(-5.0, -0.5, 0.0), Vector3(20.0, 1.0, 13.0), DAY_GRASS)
	# Bridge over cloud chasm
	box(self, Vector3(18.0, -0.45, 0.0), Vector3(14.0, 0.9, 9.5), STONE_LIGHT)
	box(self, Vector3(18.0, 0.45, -4.6), Vector3(14.0, 0.9, 0.45), STONE, true)
	box(self, Vector3(18.0, 0.45, 4.6), Vector3(14.0, 0.9, 0.45), STONE, true)
	# Vista plateau (Zone D end)
	box(self, Vector3(28.5, -0.5, 0.0), Vector3(9.0, 1.0, 13.0), DAY_GRASS)

	# Dirt trail connecting all zones
	box(self, Vector3(-6.0, 0.015, 0.4), Vector3(38.0, 0.03, 2.4), TRAIL)
	box(self, Vector3(5.0, 0.018, NARROW_SLIT_Z), Vector3(5.2, 0.03, 1.3), GOLD)

	# Invisible / low boundary curbs
	box(self, Vector3(-29.2, 0.7, 0.0), Vector3(0.5, 1.4, 14.0), PINE_DARK, true)
	box(self, Vector3(33.2, 0.7, 0.0), Vector3(0.5, 1.4, 14.0), STONE, true)
	for z in [-6.4, 6.4]:
		box(self, Vector3(-9.0, 0.7, z), Vector3(41.0, 1.4, 0.5), PINE_DARK, true)
	for z in [-6.4, 6.4]:
		box(self, Vector3(28.5, 0.7, z), Vector3(9.5, 1.4, 0.5), STONE, true)

	_build_zone_a_campfire()
	_build_zone_b_goblin_shop()
	_build_zone_c_obstacles()
	_build_zone_d_bridge_and_vista()

func _build_zone_a_campfire() -> void:
	# Ring of stones + campfire + mossy sitting log
	for i in range(8):
		var ang := i * TAU / 8.0
		sphere(self, CAMPFIRE_POS + Vector3(cos(ang) * 0.65, 0.14, sin(ang) * 0.65), Vector3(0.32, 0.22, 0.28), STONE)
	campfire_flame = cylinder(self, CAMPFIRE_POS + Vector3(0, 0.35, 0), 0.05, 0.32, 0.75, FIRE_ORANGE, true)
	campfire_smoke = cylinder(self, CAMPFIRE_POS + Vector3(0, 1.5, 0), 0.22, 0.08, 2.0, Color(0.88, 0.94, 0.96, 0.5), true)
	campfire_light = OmniLight3D.new()
	campfire_light.light_color = Color("#ff9f43")
	campfire_light.light_energy = 4.2
	campfire_light.omni_range = 10.5
	campfire_light.position = CAMPFIRE_POS + Vector3(0, 1.2, 0)
	add_child(campfire_light)
	# Sitting log
	var log_mesh := cylinder(self, CAMPFIRE_POS + Vector3(1.65, 0.28, -0.45), 0.28, 0.3, 1.9, TIMBER)
	log_mesh.rotation_degrees = Vector3(0, 22, 90)

	# Stylized pines & glowing cyan night mist pillars in background
	for p in [
		Vector3(-27.5, 0, -4.6), Vector3(-24.2, 0, -5.2), Vector3(-20.4, 0, -4.7),
		Vector3(-17.8, 0, -5.1), Vector3(-27.0, 0, 4.8), Vector3(-20.2, 0, 5.1)
	]:
		pine_tree(p, randf_range(0.95, 1.35), PINE_DARK if p.x < -21.0 else PINE_TEAL)
	for x in [-26.0, -23.0, -19.8]:
		var mist := cylinder(self, Vector3(x, 2.4, -7.2), 1.4, 1.8, 4.8, MIST_CYAN, true)
		mist_pillars.append(mist)
	label_at(self, CAMPFIRE_POS + Vector3(0, 2.6, -2.6), "A 區｜林間營火空地", Color("#b8f5ff"), 30)

func _build_zone_b_goblin_shop() -> void:
	# Semi-open timber clearance shop
	box(self, SHOP_POS + Vector3(0, 1.4, -1.6), Vector3(5.6, 2.8, 0.35), TIMBER, true)
	box(self, SHOP_POS + Vector3(-2.6, 1.4, -0.4), Vector3(0.35, 2.8, 2.6), TIMBER, true)
	box(self, SHOP_POS + Vector3(2.6, 1.4, -0.4), Vector3(0.35, 2.8, 2.6), TIMBER, true)
	box(self, SHOP_POS + Vector3(0, 3.0, -0.4), Vector3(6.2, 0.38, 3.4), TIMBER_LIGHT)
	# Counter + display case
	box(self, SHOP_POS + Vector3(0, 0.55, 0.75), Vector3(4.8, 1.1, 0.85), TIMBER_LIGHT, true)
	box(self, SHOP_POS + Vector3(0, 1.25, 0.75), Vector3(4.4, 0.35, 0.65), Color("#a8e6f5"))
	# Discount sign -50¢
	box(self, SHOP_POS + Vector3(2.1, 2.1, 1.05), Vector3(1.5, 0.7, 0.12), Color("#fff5d6"))
	label_at(self, SHOP_POS + Vector3(2.1, 2.1, 1.2), "-50¢ 五折清倉", STAMP_RED, 34)
	label_at(self, SHOP_POS + Vector3(0, 3.7, 0.2), "B 區｜骨盔哥布林清倉行", GOLD, 34)
	marker(SHOP_INTERACT, GOLD, 0.65)

	# Friendly Green Goblin Shopkeeper with white horned skull helmet
	goblin_npc = Node3D.new()
	goblin_npc.position = SHOP_POS + Vector3(0, 0.0, -0.1)
	add_child(goblin_npc)
	box(goblin_npc, Vector3(0, 0.95, 0), Vector3(1.3, 1.2, 0.9), GOBLIN_GREEN)
	sphere(goblin_npc, Vector3(0, 1.78, 0.05), Vector3(0.95, 0.85, 0.85), GOBLIN_GREEN)
	# White horned skull helmet
	sphere(goblin_npc, Vector3(0, 2.18, 0.08), Vector3(1.02, 0.58, 0.95), Color("#f6f4ef"))
	for sx in [-0.45, 0.45]:
		var horn := cylinder(goblin_npc, Vector3(sx, 2.52, 0.1), 0.04, 0.13, 0.45, Color("#e4eef5"))
		horn.rotation_degrees.z = -25.0 if sx < 0 else 25.0
	goblin_bubble = label_at(goblin_npc, Vector3(0, 3.25, 0), "", Color("#fff7c2"), 34)

func _build_zone_c_obstacles() -> void:
	# 1. Smashable fallen timber barricade (requires mounted wolf charge)
	timber_barricade = Node3D.new()
	timber_barricade.position = TIMBER_POS
	add_child(timber_barricade)
	box(timber_barricade, Vector3(0, 0.85, 0), Vector3(1.0, 1.7, 11.8), TIMBER, true)
	box(timber_barricade, Vector3(-0.35, 1.45, -1.2), Vector3(0.55, 0.55, 5.2), TIMBER_LIGHT)
	box(timber_barricade, Vector3(0.35, 1.3, 2.1), Vector3(0.55, 0.55, 4.6), TIMBER_LIGHT)
	label_at(timber_barricade, Vector3(0, 2.5, 0), "枯木路障（騎狼按 Q 撞碎）", FIRE_ORANGE, 32)

	# 2. Half-collapsed stone wall with 1.35m narrow slit (player fits, wolf blocked) + wide wolf gate
	# Wall segments along WALL_X = 5.0
	for span in [Vector2(-6.4, -4.1), Vector2(-2.7, -0.4), Vector2(3.2, 6.4)]:
		box(self, Vector3(WALL_X, 1.35, (span.x + span.y) * 0.5),
			Vector3(0.85, 2.7, span.y - span.x), STONE, true)
	# Lintels over narrow slit and wide gate
	box(self, Vector3(WALL_X, 1.85, NARROW_SLIT_Z), Vector3(0.9, 0.35, 1.5), STONE_LIGHT)
	box(self, Vector3(WALL_X, 2.75, GATE_Z), Vector3(0.95, 0.45, 3.7), STONE_LIGHT)
	stone_gate = box(self, Vector3(WALL_X, 1.25, GATE_Z), Vector3(0.48, 2.5, 3.55), TIMBER, true)

	# Inner gate lever (reachable only after small traveler squeezes through slit)
	box(self, LEVER_POS + Vector3(0, 0.38, 0), Vector3(0.45, 0.76, 0.45), STONE)
	lever_handle = box(self, LEVER_POS + Vector3(0, 0.92, 0), Vector3(0.14, 0.42, 0.14), GOLD)
	marker(LEVER_POS, GOLD, 0.52)
	label_at(self, Vector3(WALL_X, 2.35, NARROW_SLIT_Z), "窄縫（小旅人鑽入）", GOLD, 30)
	label_at(self, Vector3(WALL_X, 3.25, GATE_Z), "C 區｜巨狼石門", Color.WHITE, 32)

func _build_zone_d_bridge_and_vista() -> void:
	label_at(self, BOSS_HOME + Vector3(0, 3.3, -2.8), "D 區｜雲海石橋擂台", Color("#ffd8a8"), 32)

	# Bridgehead Free Tea Stall (hidden until Scarecrow retires!)
	tea_stall = Node3D.new()
	tea_stall.position = TEA_STALL_POS
	add_child(tea_stall)
	box(tea_stall, Vector3(0, 0.48, 0), Vector3(2.2, 0.96, 1.1), TIMBER_LIGHT)
	box(tea_stall, Vector3(0, 2.05, 0), Vector3(2.6, 0.22, 1.6), Color("#f27961"))
	for sx in [-0.95, 0.95]:
		cylinder(tea_stall, Vector3(sx, 1.25, -0.45), 0.07, 0.07, 1.6, TIMBER)
	cylinder(tea_stall, Vector3(-0.35, 1.12, 0.1), 0.18, 0.22, 0.32, Color("#6ec25a"))
	label_at(tea_stall, Vector3(0, 2.75, 0), "退休哨長・免費茶攤", GOLD, 34)
	tea_stall.hide()

	# Guild Bounty Board at Vista Lookout
	box(self, BOUNTY_POS + Vector3(0, 1.25, 0), Vector3(2.6, 1.7, 0.2), TIMBER_LIGHT, true)
	for i in range(4):
		box(self, BOUNTY_POS + Vector3(-0.85 + i * 0.56, 1.35, 0.14), Vector3(0.42, 0.55, 0.04), Color("#fff5dc"))
	box(self, BOUNTY_POS + Vector3(0.85, 0.78, 0.15), Vector3(0.5, 0.36, 0.04), STAMP_RED)
	marker(BOUNTY_POS + Vector3(0, 0, 1.0), GOLD, 0.6)
	label_at(self, BOUNTY_POS + Vector3(0, 2.55, 0), "公會懸賞板（按 E 檢視）", GOLD, 32)
	label_at(self, VISTA_POS + Vector3(0, 2.5, 2.6), "雲海瞭望台", Color("#ffe4fa"), 34)

	# Distant Vista Backdrop (pastel pink/purple mountains, red mesa, cloud sea, distant NPC riders)
	for c in [
		Vector3(24, -1.8, -11), Vector3(32, -1.5, -13), Vector3(40, -1.6, -9),
		Vector3(38, -2.0, 2), Vector3(36, -1.8, 10), Vector3(20, -2.2, 10)
	]:
		sphere(self, c, Vector3(6.5, 2.2, 4.5), CLOUD_WHITE, true)
	cylinder(self, Vector3(44, 6.5, -14), 1.8, 7.5, 16.0, PINK_PEAK, true)
	cylinder(self, Vector3(50, 8.0, -4), 2.5, 6.8, 19.0, PURPLE_PEAK, true)
	box(self, Vector3(46, 3.2, 9), Vector3(7.5, 7.5, 6.5), RED_MESA, true)
	# Tiny white hilltop village houses on distant peak
	for h in [Vector3(39.5, 2.1, -11.5), Vector3(40.8, 2.5, -12.0), Vector3(41.9, 1.9, -11.2)]:
		box(self, h, Vector3(0.85, 0.9, 0.85), CLOUD_WHITE, true)
		cylinder(self, h + Vector3(0, 0.72, 0), 0.04, 0.68, 0.6, Color("#576bb0"), true)

	# Distant MMORPG NPC riders (giant wolf + armored bear silhouettes trotting in background)
	for i in range(2):
		var rider := Node3D.new()
		rider.position = Vector3(36.0 + i * 3.5, 0.4, -7.5 + i * 2.2)
		add_child(rider)
		var mount_col := Color("#464d5c") if i == 0 else Color("#8a6852")
		box(rider, Vector3(0, 0.65, 0), Vector3(1.6, 0.9, 0.95), mount_col, true)
		sphere(rider, Vector3(0, 1.45, 0), Vector3(0.5, 0.55, 0.5), Color("#58b9ff"), true)
		label_at(rider, Vector3(0, 2.25, 0), "旅人・阿狼" if i == 0 else "旅人・蜜熊", Color("#e8f4ff"), 24)
		distant_riders.append(rider)

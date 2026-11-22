extends Node3D

# Handcrafted 3D Lakeside Campfire Diorama (Gouache Night x vC7OEC Miniature Edition)
# Atmosphere: ChatGPT Night Campfire Reference (06_29_51.png) — deep velvet midnight-indigo pines, warm olive-moss grass, rich honey campfire glow
# Diorama Tech: vC7OEC.mp4 — 174×174 3D terrain, 1600+ wind-swayed grass tufts, recessed water w/ shore foam, dry-brush vertical-gradient props, contact shadows, day sunbeams
# Interactive FX: Smooth Bilinear Persistent Surface State (Scorch/Snow/Wetness) + RigidBody3D Shatter Physics

const SHADER_TERRAIN := preload("res://diorama/shaders/diorama_terrain.gdshader")
const SHADER_WATER := preload("res://diorama/shaders/diorama_water.gdshader")
const SHADER_WATERFALL := preload("res://diorama/shaders/diorama_waterfall.gdshader")
const SHADER_PROP := preload("res://diorama/shaders/diorama_prop.gdshader")
const SHADER_GODRAY := preload("res://diorama/shaders/diorama_godray.gdshader")
const SHADER_CONTACT := preload("res://diorama/shaders/diorama_contact_shadow.gdshader")
const SHADER_GRASS := preload("res://diorama/shaders/diorama_grass.gdshader")
const SHADER_WIND_TRAIL := preload("res://diorama/shaders/diorama_wind_trail.gdshader")
const INK_FX_SCRIPT := preload("res://prologue/InkStudioFX.gd")
const MODEL_DIR := "res://assets/models/campfire/"

const MAP_MIN := Vector2(-32.0, -27.0)
const MAP_SIZE := Vector2(64.0, 54.0)
const SURFACE_STATE_MIN := Vector2(-24.0, -18.0)
const SURFACE_STATE_SIZE := Vector2(48.0, 36.0)
const WATER_LEVEL := -0.58
const CAMPFIRE_XZ := Vector2(0.0, 0.2)
const CABIN_XZ := Vector2(3.85, -4.15)
const CABIN_YAW := -PI / 10.0
const BRIDGE_XZ := Vector2(8.55, -1.1)
const BRIDGE_HALF_SPAN := 2.85
const BRIDGE_HALF_WIDTH := 0.82
const BRIDGE_RAIL_THICKNESS := 0.22
const ORBIT_TARGET := Vector3(1.1, 0.95, -1.0)
const RoundedBoxMesh := preload("res://diorama/RoundedBox.gd")
const Precipitation := preload("res://diorama/LakesidePrecipitation.gd")

var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var contact_mat: ShaderMaterial
var grass_mat: ShaderMaterial
var grass_mm: MultiMesh
var grass_positions: Array[Vector2] = []
var godray_nodes: Array[Node3D] = []
var godray_mats: Array[ShaderMaterial] = []
var wind_trail_mats: Array[ShaderMaterial] = []
var prop_mats: Array[ShaderMaterial] = []
var tod_foliage: Array[Dictionary] = []
var bg_trunk_mats: Array[Dictionary] = []
var ink_fx: Node3D
var precipitation: Precipitation

var world_env: WorldEnvironment
var env: Environment
var sky_mat: ProceduralSkyMaterial
var key_light: DirectionalLight3D
var campfire_light: OmniLight3D
var cabin_light: OmniLight3D
var smoke_materials: Array[ShaderMaterial] = []
var camera: Camera3D
var camera_target := ORBIT_TARGET
var lens_material: ShaderMaterial
var lens_strength := 1.0

const PLAYER_RADIUS := 0.24
const WALK_SPEED := 2.1
const WALK_CADENCE := 1.95
const FOOTSTEP_SPACING := 0.59
const PIER_XZ := Vector2(-2.6, 4.95)
const PIER_ROTATION := -PI / 30.0
const SOLID_PROPS := [
	"skull_cave.glb", "standing_stone.glb", "waterfall_rock.glb", "shore_rock.glb",
	"golem.glb", "stump.glb", "backpack.glb", "journal_log.glb", "sit_log.glb",
	"bedroll.glb", "buddy_log.glb", "palm_bush.glb", "lush_shrub.glb", "bucket.glb",
]
var player: CharacterBody3D
var occlusion: Node3D
var step_surfaces: Array[Dictionary] = []
var canopy_finishes: Array[ShaderMaterial] = []
var vegetation_wind_field: NoiseTexture2D
var footstep_distance := 0.0
var lakeside_audio: Node
var player_visual: Node3D
var player_motion: AnimationPlayer
var practice_sword: Node3D
var flower_roots: Array[Node3D] = []
var player_yaw := 0.0

var campfire_flame: Node3D
var campfire_embers: GPUParticles3D
var rain_blend := 0.0
var snow_blend := 0.0
var clear_sun_energy := 0.0
var clear_fog_density := 0.0
var fishing_bobber: Node3D
var grunt_key: Node3D
var golem_node: Node3D
var wolf_node: Node3D
var bird_node: Node3D
const MOTE_COUNT := 26
var motes: MultiMesh
var mote_origins := PackedVector3Array()
var mote_seeds := PackedVector2Array()

var is_night := false
var orbit_camera := true
var orbit_angle := -0.42
var show_hint := true
var hud_parent: Node
var hint_panel: PanelContainer
var hint_label: Label
var toast_label: Label
var toast_timer := 0.0
var attack_cd := 0.0
var strike_delay := 0.0
var strike_facing := Vector3.ZERO
var scene_time := 0.0

# --- 1. Analytical 3D Sculpted Diorama Heightfield ---
func _river_center_x(z: float) -> float:
	var bank_detail := sin(z * 0.91 + 1.2) * 0.21 + cos(z * 0.57 - 0.33) * 0.26
	return 8.3 + sin((z + 1.2) * 0.24) * 1.25 - (z + 1.8) * 0.26 + bank_detail

func _lake_shore_z(x: float) -> float:
	var base := 4.35 + sin(x * 0.26) * 0.65 + cos(x * 0.14) * 0.38 + sin(x * 0.88 + 0.4) * 0.26 + sin(x * 0.43) * 0.38
	if x > 5.2:
		# Push lake shore cleanly southward under the right cabin peninsula so cabin sits 100% dry!
		base += smoothstep(5.2, 9.2, x) * 3.85
	return base

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _trail_weight(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var pts := [
		Vector2(-8.6, -1.9), Vector2(-5.4, -0.7), Vector2(-2.2, 0.4),
		Vector2(0.0, 0.2), Vector2(2.8, -0.8), Vector2(5.8, -1.1),
		Vector2(8.5, -1.1), Vector2(12.2, -1.4), Vector2(16.5, -1.2)
	]
	var min_d := 999.0
	for i in range(pts.size() - 1):
		min_d = minf(min_d, _dist_to_segment(p, pts[i], pts[i + 1]))
	var hill_turn := _dist_to_segment(p, Vector2(-5.4, -0.7), Vector2(-3.0, -4.3))
	var hill_ascent := _dist_to_segment(p, Vector2(-3.0, -4.3), Vector2(-5.2, -8.4))
	var cabin_walk := _dist_to_segment(p, Vector2(2.8, -0.8), CABIN_XZ + Vector2(-0.5, 1.5))
	var branch := minf(cabin_walk, minf(hill_turn, hill_ascent))
	return maxf(smoothstep(1.28, 0.40, min_d), smoothstep(0.90, 0.27, branch))

func terrain_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 0.14 + sin(x * 0.16) * 0.10 + cos(z * 0.18) * 0.09

	# Upper-left Standing Stones & Golem Hill (higher & shifted slightly right so 100% unobstructed!)
	h += smoothstep(6.0, 1.2, p.distance_to(Vector2(-5.4, -8.8))) * 2.15
	# Mid-left Skull Cave Slope
	h += smoothstep(5.0, 1.4, p.distance_to(Vector2(-9.8, -2.5))) * 1.18
	# Lower-left Waterfall Cliff Ledge
	h += smoothstep(4.2, 1.1, p.distance_to(Vector2(-9.4, 3.1))) * 1.48

	# Two overlapping shelves give the stone circle a distinct profile from the lake.
	var ridge := (p - Vector2(-5.7, -8.4)) / Vector2(6.4, 4.3)
	h += 0.85 * (1.0 - smoothstep(0.76, 1.02, ridge.length()))
	var bank := (p - Vector2(-15.0, 7.4)) / Vector2(4.0, 2.7)
	h += 1.15 * (1.0 - smoothstep(0.58, 1.04, bank.length()))

	# Northern & Side Forest Ridges
	if z < -9.0:
		h += smoothstep(-9.0, -16.5, z) * 2.2
	if x < -12.5:
		h += smoothstep(-12.5, -20.0, x) * 1.6
	if x > 13.5:
		h += smoothstep(13.5, 20.0, x) * 1.5

	# Central Campfire Clearing
	h = lerpf(h, 0.15, smoothstep(5.4, 1.8, p.distance_to(CAMPFIRE_XZ)) * 0.86)

	# Broad upper garden. Keep the cabin footprint level and ease into the path.
	var garden := (p - CABIN_XZ) / Vector2(4.35, 3.8)
	var landing := 1.0 - smoothstep(0.42, 1.0, garden.length())
	h = lerpf(h, 0.96, landing)

	# Carved Right River Valley (curves gracefully around the cabin peninsula)
	var rx := _river_center_x(z)
	var d_river := absf(x - rx)
	var river_w := lerpf(1.93, 2.64, smoothstep(-3.0, 6.0, z)) + 0.18 * sin(z * 0.61)
	var valley := smoothstep(river_w + 1.25, river_w * 0.45, d_river)
	h = lerpf(h, -1.42, valley)
	# The stream curves out of sight under the upstream forest.
	var source_bank := smoothstep(-21.0, -26.0, z)
	h += source_bank * valley * 2.4

	# Carved Deep Southern Lake Basin
	var shore_z := _lake_shore_z(x)
	var lake_cut := smoothstep(shore_z - 1.15, shore_z + 1.25, z)
	var waterfall_bank := 1.0 - smoothstep(-9.0, -6.3, x)
	lake_cut *= lerpf(1.0, smoothstep(3.45, 5.10, z), waterfall_bank)
	# The far bank closes the lake and frames the reverse orbit view.
	var far_bank := 10.8 + sin(x * 0.32) * 2.1 + cos(x * 0.61) * 0.65 + sin(x * 1.08 + 0.4) * 0.25
	lake_cut *= 1.0 - smoothstep(far_bank, far_bank + 2.2, z)
	h = lerpf(h, -1.68, lake_cut)

	# Raised Dry Right Cabin Peninsula (applied AFTER river/lake carve so cabin is ALWAYS high & dry!)
	var cab_pen := smoothstep(4.6, 1.85, p.distance_to(Vector2(10.0, 5.25)))
	h = lerpf(h, 0.60, cab_pen * 0.92)
	return h

func _ready() -> void:
	var gust_noise := FastNoiseLite.new()
	gust_noise.seed = 4916
	gust_noise.frequency = 0.045
	vegetation_wind_field = NoiseTexture2D.new()
	vegetation_wind_field.width = 128
	vegetation_wind_field.height = 128
	vegetation_wind_field.seamless = true
	vegetation_wind_field.noise = gust_noise
	contact_mat = ShaderMaterial.new()
	contact_mat.shader = SHADER_CONTACT

	ink_fx = INK_FX_SCRIPT.new()
	ink_fx.render_legacy_precipitation = false
	ink_fx.scorch_on_impact = false
	add_child(ink_fx)
	var state_tex: ImageTexture = ink_fx.setup(Vector3(CAMPFIRE_XZ.x, terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y), CAMPFIRE_XZ.y))
	ink_fx.state_img.fill(Color(0.0, 0.0, 0.0, 1.0))
	ink_fx.paint_scorch(Vector3(CAMPFIRE_XZ.x, 0.0, CAMPFIRE_XZ.y), 0.95, 0.36)
	ink_fx.state_tex.update(ink_fx.state_img)

	_setup_environment_and_lights()
	var height_tex := _build_sculpted_terrain(state_tex)
	_build_painterly_grass_tufts()
	_build_meadow_flowers()
	_build_water_and_waterfall(height_tex)
	occlusion = preload("res://diorama/LakesideOcclusion.gd").new()
	add_child(occlusion)
	_build_diorama_scene()
	_setup_player_and_camera()
	lakeside_audio = preload("res://diorama/LakesideAudio.gd").new()
	add_child(lakeside_audio)
	precipitation = Precipitation.new()
	add_child(precipitation)
	_setup_minimal_ui()
	_apply_time_of_day(is_night)

# --- 2. Cozy Velvet Midnight-Indigo Night vs. Sunlit Emerald Day ---
func _setup_environment_and_lights() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 0.78
	env.ssao_intensity = 0.74
	env.ssao_power = 1.3
	env.tonemap_exposure = 0.98
	env.glow_enabled = true
	env.glow_intensity = 0.12
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.02
	env.fog_enabled = true
	env.fog_density = 0.0045

	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-61.0, -38.0, 0.0)
	key_light.shadow_enabled = true
	key_light.shadow_blur = 4.0
	key_light.directional_shadow_max_distance = 85.0
	key_light.shadow_bias = 0.055
	key_light.shadow_normal_bias = 1.1
	add_child(key_light)

	# Rich cozy honey-amber campfire glow (no harsh omni shadow seam splitting the red pine!)
	campfire_light = OmniLight3D.new()
	campfire_light.light_color = Color("#ff9933")
	campfire_light.light_energy = 3.15
	campfire_light.omni_range = 10.8
	campfire_light.omni_attenuation = 1.45
	campfire_light.shadow_enabled = false
	campfire_light.position = Vector3(CAMPFIRE_XZ.x, terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y) + 1.38, CAMPFIRE_XZ.y)
	add_child(campfire_light)

	cabin_light = OmniLight3D.new()
	cabin_light.light_color = Color("#ffba4d")
	cabin_light.light_energy = 1.75
	cabin_light.omni_range = 4.5
	cabin_light.position = Vector3(9.8, terrain_height(9.8, 5.15) + 1.25, 6.2)
	add_child(cabin_light)

func _apply_time_of_day(night: bool) -> void:
	is_night = night
	if lens_material:
		lens_material.set_shader_parameter("night_mix", 1.0 if night else 0.0)
	for material in smoke_materials:
		material.set_shader_parameter("night_mix", 1.0 if night else 0.0)
	if night:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.adjustment_saturation = 1.02
		# Exact 06_29_51.png Cozy Velvet Night Palette (Deep Indigo Forest + Luminous Moss-Olive Meadow + Honey Fire!)
		env.tonemap_exposure = 1.00
		env.fog_density = 0.0042
		sky_mat.sky_top_color = Color("#091338")
		sky_mat.sky_horizon_color = Color("#152969")
		sky_mat.ground_bottom_color = Color("#0c1842")
		sky_mat.ground_horizon_color = Color("#152969")
		# Lift the blacks with soft blue-violet ambient so tree bases NEVER crush to pitch black!
		env.ambient_light_color = Color("#7281a9")
		env.ambient_light_energy = 0.81
		env.fog_light_color = Color("#1b294d")
		key_light.light_color = Color("#8aa4d6")
		key_light.light_energy = 0.61
		campfire_light.light_energy = 2.85
		cabin_light.light_energy = 1.80
		if terrain_mat:
			terrain_mat.set_shader_parameter("grass_deep", Color("#29433d"))
			terrain_mat.set_shader_parameter("grass_mid", Color("#436444"))
			terrain_mat.set_shader_parameter("grass_hill", Color("#607d47"))
			terrain_mat.set_shader_parameter("trail_col", Color("#d4a26e"))
			terrain_mat.set_shader_parameter("campfire_dirt", Color("#e89c3c"))
			terrain_mat.set_shader_parameter("shore_sand", Color("#2c3d4f"))
			terrain_mat.set_shader_parameter("cliff_rock", Color("#343c57"))
			terrain_mat.set_shader_parameter("night_mix", 1.0)
		if water_mat:
			# Muted Slate Blue night water + soft grey-blue non-glowing foam!
			water_mat.set_shader_parameter("deep_color", Color("#263b59"))
			water_mat.set_shader_parameter("shallow_color", Color("#44627b"))
			water_mat.set_shader_parameter("foam_color", Color("#6b8cae"))
			water_mat.set_shader_parameter("daylight", 0.0)
		if grass_mat:
			grass_mat.set_shader_parameter("night_mix", 1.0)
		for gn in godray_nodes:
			gn.visible = false
		for pm in prop_mats:
			pm.set_shader_parameter("ambient_lift", 0.10)
	else:
		# Clean vC7OEC Warm Golden Sunlight vs. Soft Cool Cyan-Blue Shadows!
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = 1.12
		env.adjustment_saturation = 1.12
		env.fog_density = 0.0011
		sky_mat.sky_top_color = Color("#438cd4")
		sky_mat.sky_horizon_color = Color("#a8d4f2")
		sky_mat.ground_bottom_color = Color("#356e3b")
		sky_mat.ground_horizon_color = Color("#a8d4f2")
		env.ambient_light_color = Color("#678da9")
		env.ambient_light_energy = 0.67
		env.fog_light_color = Color("#8fc2de")
		key_light.light_color = Color("#ffdf9d")
		key_light.light_energy = 1.28
		campfire_light.light_energy = 0.70
		cabin_light.light_energy = 0.30
		if terrain_mat:
			terrain_mat.set_shader_parameter("grass_deep", Color("#356828"))
			terrain_mat.set_shader_parameter("grass_mid", Color("#6c9e36"))
			terrain_mat.set_shader_parameter("grass_hill", Color("#89ac40"))
			terrain_mat.set_shader_parameter("trail_col", Color("#cfa570"))
			terrain_mat.set_shader_parameter("campfire_dirt", Color("#c49458"))
			terrain_mat.set_shader_parameter("shore_sand", Color("#aba07c"))
			terrain_mat.set_shader_parameter("cliff_rock", Color("#6d768a"))
			terrain_mat.set_shader_parameter("night_mix", 0.0)
		if water_mat:
			# Painterly azure-slate day water (NO electric neon blue!)
			water_mat.set_shader_parameter("deep_color", Color("#174492"))
			water_mat.set_shader_parameter("shallow_color", Color("#3189aa"))
			water_mat.set_shader_parameter("foam_color", Color("#d2e6f5"))
			water_mat.set_shader_parameter("daylight", 1.0)
		if grass_mat:
			grass_mat.set_shader_parameter("night_mix", 0.0)
		for gn in godray_nodes:
			gn.visible = true
		for gm in godray_mats:
			gm.set_shader_parameter("ray_color", Color(1.0, 0.90, 0.54, 0.26))
		for pm in prop_mats:
			pm.set_shader_parameter("ambient_lift", 0.04)
	for rec in tod_foliage:
		var material: ShaderMaterial = rec["mat"]
		material.set_shader_parameter("tint_color", rec["night"] if night else rec["day"])
		if rec.has("canopy"):
			material.set_shader_parameter("night_mix", 1.0 if night else 0.0)
	for trec in bg_trunk_mats:
		(trec["mat"] as StandardMaterial3D).albedo_color = trec["night"] if night else trec["day"]
	for wm in wind_trail_mats:
		wm.set_shader_parameter("trail_color", Color(0.75, 0.88, 1.0, 0.42) if night else Color(1.0, 0.99, 0.94, 0.78))
	clear_sun_energy = key_light.light_energy
	clear_fog_density = env.fog_density
	_recolor_grass_tufts()

# --- 3. 96x96 Sculpted 3D Terrain Mesh + Heightmap Texture ---
func _build_sculpted_terrain(state_tex: ImageTexture) -> ImageTexture:
	var grid := 174
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	verts.resize((grid + 1) * (grid + 1))
	cols.resize((grid + 1) * (grid + 1))

	for iz in range(grid + 1):
		var tz := float(iz) / float(grid)
		var z := MAP_MIN.y + tz * MAP_SIZE.y
		for ix in range(grid + 1):
			var tx := float(ix) / float(grid)
			var x := MAP_MIN.x + tx * MAP_SIZE.x
			var y := terrain_height(x, z)
			var idx := iz * (grid + 1) + ix
			verts[idx] = Vector3(x, y, z)

			var trail_w := _trail_weight(x, z)
			var d_fire := Vector2(x, z).distance_to(CAMPFIRE_XZ)
			var fire_w := smoothstep(6.6, 1.4, d_fire) * smoothstep(-0.20, 0.06, y)
			var shore_w := smoothstep(-0.15, -0.68, y)
			cols[idx] = Color(trail_w, fire_w, shore_w, 1.0)

	for iz in range(grid):
		for ix in range(grid):
			var i00 := iz * (grid + 1) + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * (grid + 1) + ix
			var i11 := i01 + 1
			st.set_color(cols[i00]); st.add_vertex(verts[i00])
			st.set_color(cols[i10]); st.add_vertex(verts[i10])
			st.set_color(cols[i11]); st.add_vertex(verts[i11])
			st.set_color(cols[i00]); st.add_vertex(verts[i00])
			st.set_color(cols[i11]); st.add_vertex(verts[i11])
			st.set_color(cols[i01]); st.add_vertex(verts[i01])

	st.generate_normals()
	var mesh := st.commit()

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = SHADER_TERRAIN
	terrain_mat.set_shader_parameter("state_map", state_tex)
	terrain_mat.set_shader_parameter("map_min", SURFACE_STATE_MIN)
	terrain_mat.set_shader_parameter("map_size", SURFACE_STATE_SIZE)
	mi.material_override = terrain_mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var col_sh := CollisionShape3D.new()
	col_sh.shape = mesh.create_trimesh_shape()
	body.add_child(col_sh)

	var h_res := 256
	var himg := Image.create_empty(h_res, h_res, false, Image.FORMAT_RF)
	for py in range(h_res):
		var z := MAP_MIN.y + (float(py) / float(h_res - 1)) * MAP_SIZE.y
		for px in range(h_res):
			var x := MAP_MIN.x + (float(px) / float(h_res - 1)) * MAP_SIZE.x
			var norm_h := clampf((terrain_height(x, z) + 2.0) / 6.0, 0.0, 1.0)
			himg.set_pixel(px, py, Color(norm_h, 0.0, 0.0, 1.0))
	return ImageTexture.create_from_image(himg)

# --- 3b. 1,600+ Painterly Stylized Grass Tufts (06_29_51 x vC7OEC Signature!) ---
func _build_painterly_grass_tufts() -> void:
	# Bent, crossed blades hold their silhouette from both sides of the orbit.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var angle := blade * 2.4
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var side := outward.cross(Vector3.UP)
		var height := 0.18 + 0.025 * ((blade * 3) % 5)
		var rings: Array[PackedVector3Array] = []
		for row in 4:
			var t := float(row) / 3.0
			var center := outward * (0.025 + t * t * 0.12) + Vector3.UP * height * t
			var half_width := 0.025 * sin(lerpf(0.42, PI, t))
			rings.append(PackedVector3Array([center - side * half_width, center + side * half_width]))
		for row in 3:
			for v in [rings[row][0], rings[row][1], rings[row + 1][0],
					rings[row][1], rings[row + 1][1], rings[row + 1][0]]:
				st.set_uv(Vector2(0.0, v.y / height))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	st.index()
	var tuft_mesh := st.commit()

	var rng := RandomNumberGenerator.new()
	rng.seed = 42069
	var clusters := FastNoiseLite.new()
	clusters.seed = 6419
	clusters.frequency = 0.84
	var xforms: Array[Transform3D] = []
	grass_positions.clear()

	# Clean, Breathable Stylized Grass Tufts (2,200 tufts, cast_shadow=OFF, ZERO visual noise!)
	for _i in range(3100):
		var gx := rng.randf_range(-15.8, 15.8)
		var gz := rng.randf_range(-12.5, 7.2)
		var density := clusters.get_noise_2d(gx, gz)
		if density < -0.13 and rng.randf() < 0.84:
			continue
		var gy := terrain_height(gx, gz)
		if gy < WATER_LEVEL + 0.32:
			continue
		if _trail_weight(gx, gz) > 0.30:
			continue
		var d_fire := Vector2(gx, gz).distance_to(CAMPFIRE_XZ)
		if d_fire < 2.90:
			continue
		if Vector2(gx, gz).distance_to(Vector2(9.8, 5.15)) < 2.5:
			continue
		if Vector2(gx, gz).distance_to(Vector2(-9.8, -2.5)) < 2.5:
			continue
		var s := rng.randf_range(0.60, 1.05)
		var yaw := rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.75, 1.10), s))
		xforms.append(Transform3D(basis, Vector3(gx, gy - 0.03, gz)))
		grass_positions.append(Vector2(gx, gz))
		if xforms.size() >= 1300:
			break

	grass_mm = MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	grass_mm.use_colors = true
	grass_mm.mesh = tuft_mesh
	grass_mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		grass_mm.set_instance_transform(i, xforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = grass_mm
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = SHADER_GRASS
	grass_mat.set_shader_parameter("wind_field", vegetation_wind_field)
	mmi.material_override = grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_meadow_flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 72653
	var transforms: Array[Transform3D] = []
	for patch: Vector2 in [Vector2(-5.2, -4.6), Vector2(-2.0, -6.0), Vector2(-5.0, 1.9),
			Vector2(1.1, 3.25), Vector2(12.1, -3.1)]:
		for group in 5:
			var center := patch + Vector2(rng.randf_range(-0.96, 0.96), rng.randf_range(-0.52, 0.52))
			for sprig in rng.randi_range(2, 5):
				var at := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.05, 0.40)
				var y := terrain_height(at.x, at.y)
				if y < WATER_LEVEL + 0.30 or _trail_weight(at.x, at.y) > 0.18 or at.distance_to(CAMPFIRE_XZ) < 3.1:
					continue
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.78, 1.34))
				transforms.append(Transform3D(basis, Vector3(at.x, y - 0.014, at.y)))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = preload("res://diorama/MeadowFlowers.gd").mesh()
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
	var flowers := MultiMeshInstance3D.new()
	flowers.name = "MeadowFlowerPatches"
	flowers.multimesh = batch
	flowers.material_override = grass_mat
	flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flowers)

func _recolor_grass_tufts() -> void:
	if not grass_mm:
		return
	for i in range(grass_positions.size()):
		var p := grass_positions[i]
		var d_fire := p.distance_to(CAMPFIRE_XZ)
		var fire_w := smoothstep(6.8, 2.4, d_fire)
		var y := terrain_height(p.x, p.y)
		var hill_t := clampf((y + 0.05) * 0.50, 0.0, 1.0)
		var c: Color
		if is_night:
			c = Color("#2b4a3e").lerp(Color("#5d7d44"), clampf(hill_t * 0.72 + 0.28, 0.0, 1.0))
			c = c.lerp(Color("#e39634"), fire_w * 0.85)
		else:
			c = Color("#71913c").lerp(Color("#a6ba54"), clampf(hill_t * 0.72 + 0.28, 0.0, 1.0))
			c = c.lerp(Color("#c4964c"), fire_w * 0.28)
		grass_mm.set_instance_color(i, c)

# --- 4. Continuous Water Plane + Organic Curved Waterfall + Fluffy Foam Splash ---
func _build_water_and_waterfall(height_tex: ImageTexture) -> void:
	var w_mesh := PlaneMesh.new()
	w_mesh.size = MAP_SIZE
	w_mesh.subdivide_width = 48
	w_mesh.subdivide_depth = 36
	var w_inst := MeshInstance3D.new()
	w_inst.mesh = w_mesh
	w_inst.position = Vector3(0.0, WATER_LEVEL, 0.0)
	water_mat = ShaderMaterial.new()
	water_mat.shader = SHADER_WATER
	water_mat.set_shader_parameter("height_tex", height_tex)
	water_mat.set_shader_parameter("map_min", MAP_MIN)
	water_mat.set_shader_parameter("map_size", MAP_SIZE)
	water_mat.set_shader_parameter("water_level", WATER_LEVEL)
	water_mat.set_shader_parameter("bobber_pos", Vector3(-1.32, WATER_LEVEL, 5.75))
	w_inst.material_override = water_mat
	w_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w_inst)

	# Curved waterfall cascading out from between mossy cliff stones into fluffy foam clouds
	var wf_st := SurfaceTool.new()
	wf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wf_w := 1.95
	var segs := 18
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(1.32, WATER_LEVEL - 0.05, t0 * t0)
		var y1 := lerpf(1.32, WATER_LEVEL - 0.05, t1 * t1)
		var z0 := lerpf(3.70, 5.05, t0)
		var z1 := lerpf(3.70, 5.05, t1)
		var v00 := Vector3(-wf_w * (0.46 + t0 * 0.14), y0, z0)
		var v10 := Vector3(wf_w * (0.46 + t0 * 0.10), y0, z0)
		var v01 := Vector3(-wf_w * (0.46 + t1 * 0.14), y1, z1)
		var v11 := Vector3(wf_w * (0.46 + t1 * 0.10), y1, z1)
		wf_st.set_uv(Vector2(0, t0)); wf_st.add_vertex(v00)
		wf_st.set_uv(Vector2(1, t0)); wf_st.add_vertex(v10)
		wf_st.set_uv(Vector2(1, t1)); wf_st.add_vertex(v11)
		wf_st.set_uv(Vector2(0, t0)); wf_st.add_vertex(v00)
		wf_st.set_uv(Vector2(1, t1)); wf_st.add_vertex(v11)
		wf_st.set_uv(Vector2(0, t1)); wf_st.add_vertex(v01)
	var wf_mi := MeshInstance3D.new()
	wf_st.generate_normals()
	wf_mi.mesh = wf_st.commit()
	var wf_mat := ShaderMaterial.new()
	wf_mat.shader = SHADER_WATERFALL
	wf_mi.material_override = wf_mat
	wf_mi.position = Vector3(-8.5, 0.0, 0.0)
	wf_mi.rotation_degrees.y = 10.0
	wf_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wf_mi)

	var impact := wf_mi.to_global(Vector3(0.0, WATER_LEVEL, 5.05))
	water_mat.set_shader_parameter("waterfall_pos", impact)

	# Stylized Solid Matte 3D Sphere Splash Particles (scales smoothly to 0 — NO airbrush blur!)
	var wf_p := GPUParticles3D.new()
	wf_p.position = impact + Vector3(0.0, 0.14, 0.05)
	wf_p.amount = 20
	wf_p.lifetime = 1.10
	wf_p.preprocess = 1.2
	wf_p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wf_pm := ParticleProcessMaterial.new()
	wf_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	wf_pm.emission_box_extents = Vector3(0.75, 0.10, 0.22)
	wf_pm.direction = Vector3(0.0, 1.0, 0.35)
	wf_pm.spread = 42.0
	wf_pm.initial_velocity_min = 0.9
	wf_pm.initial_velocity_max = 1.8
	wf_pm.gravity = Vector3(0.0, -3.2, 0.0)
	wf_pm.scale_min = 0.55; wf_pm.scale_max = 1.05
	var wf_sc := Curve.new()
	wf_sc.add_point(Vector2(0.0, 0.25)); wf_sc.add_point(Vector2(0.35, 1.0)); wf_sc.add_point(Vector2(1.0, 0.0))
	var wf_scale_tex := CurveTexture.new(); wf_scale_tex.curve = wf_sc
	wf_pm.scale_curve = wf_scale_tex
	wf_p.process_material = wf_pm
	var wf_sm := SphereMesh.new(); wf_sm.radius = 0.125; wf_sm.height = 0.19; wf_sm.radial_segments = 10; wf_sm.rings = 6
	var wf_pmat := StandardMaterial3D.new()
	wf_pmat.albedo_color = Color("#9bb6cc"); wf_pmat.roughness = 1.0; wf_pmat.metallic_specular = 0.0
	wf_sm.material = wf_pmat
	wf_p.draw_pass_1 = wf_sm
	add_child(wf_p)

# --- 5. GLB Loader with Dry-Brush Gouache Shader, Contact Shadow Decal & Auto Grounding ---
func _apply_prop_shader(node: Node, aabb: AABB, tint_col: Color, tint_mix: float, brightness := 1.00, grad_str := 0.42, day_tint := Color(-1.0, 0.0, 0.0)) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for si in range(mi.mesh.get_surface_count()):
				var orig := mi.get_active_material(si)
				if orig == null:
					orig = mi.mesh.surface_get_material(si)
				var sm := ShaderMaterial.new()
				sm.shader = SHADER_PROP
				sm.set_shader_parameter("tint_color", tint_col)
				sm.set_shader_parameter("tint_mix", tint_mix)
				sm.set_shader_parameter("brightness", brightness)
				sm.set_shader_parameter("grad_strength", grad_str)
				sm.set_shader_parameter("min_y", aabb.position.y)
				sm.set_shader_parameter("max_y", aabb.position.y + aabb.size.y)
				sm.set_shader_parameter("aabb_center", aabb.get_center())
				if orig is BaseMaterial3D:
					var bm := orig as BaseMaterial3D
					sm.set_shader_parameter("base_color", bm.albedo_color)
					if bm.albedo_texture:
						sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
						sm.set_shader_parameter("has_albedo_tex", true)
					else:
						sm.set_shader_parameter("has_albedo_tex", false)
				else:
					sm.set_shader_parameter("has_albedo_tex", false)
				mi.set_surface_override_material(si, sm)
				prop_mats.append(sm)
				if day_tint.r >= 0.0:
					# Enable Spherical Normal Transfer + Vertex Wind Sway on all foliage & pines!
					sm.set_shader_parameter("spherical_normal_mix", 0.78)
					sm.set_shader_parameter("wind_strength", 0.08)
					tod_foliage.append({"mat": sm, "night": tint_col, "day": day_tint})
	for c in node.get_children():
		_apply_prop_shader(c, aabb, tint_col, tint_mix, brightness, grad_str, day_tint)

func _compute_aabb(node: Node, xf: Transform3D) -> AABB:
	var cur := xf * (node as Node3D).transform if node is Node3D else xf
	var acc := AABB()
	var has_a := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		acc = cur * (node as MeshInstance3D).mesh.get_aabb()
		has_a = true
	for c in node.get_children():
		var ca := _compute_aabb(c, cur)
		if ca.size.length_squared() > 0.00001:
			acc = acc.merge(ca) if has_a else ca
			has_a = true
	return acc

func _add_contact_shadow(parent: Node3D, radius: float, y_off := 0.03) -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(radius * 2.0, radius * 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = contact_mat
	mi.rotation_degrees.x = -90.0
	mi.position = Vector3(0.0, y_off, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

func _place_glb(parent: Node3D, fname: String, xz: Vector2, target_size: float, rot_deg := Vector3.ZERO, tint := Color.WHITE, tint_mix := 0.0, y_offset := 0.0, brightness := 1.00, use_terrain_y := true, shadow_r := 0.0, day_tint := Color(-1.0, 0.0, 0.0)) -> Node3D:
	var holder := Node3D.new()
	var y := (terrain_height(xz.x, xz.y) if use_terrain_y else 0.0) + y_offset
	holder.position = Vector3(xz.x, y, xz.y)
	holder.rotation_degrees = rot_deg
	parent.add_child(holder)

	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(MODEL_DIR + fname), st) == OK:
		var inst := doc.generate_scene(st)
		if inst:
			var aabb := _compute_aabb(inst, Transform3D.IDENTITY)
			var md := maxf(0.001, maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)))
			var s := target_size / md
			inst.scale = Vector3.ONE * s
			var cxz := Vector2(aabb.position.x + aabb.size.x * 0.5, aabb.position.z + aabb.size.z * 0.5)
			inst.position = Vector3(-cxz.x * s, -aabb.position.y * s, -cxz.y * s)
			_apply_prop_shader(inst, aabb, tint, tint_mix, brightness, 0.42, day_tint)
			holder.add_child(inst)
	if parent == self and fname in SOLID_PROPS:
		var bounds := _compute_aabb(holder, holder.transform.affine_inverse())
		if bounds.size.length_squared() > 0.01:
			_add_prop_collision(holder, bounds)
			if bounds.size.y > 0.92:
				occlusion.watch(holder, bounds)
	if shadow_r > 0.0:
		_add_contact_shadow(holder, shadow_r, 0.04 - y_offset if use_terrain_y else 0.02)
	return holder

func _flame_mesh(width: float, height: float, color: Color) -> ArrayMesh:
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	body.radial_segments = 16
	body.rings = 10
	var arrays := body.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for i in vertices.size():
		var p := vertices[i]
		var rise := clampf(p.y + 0.5, 0.0, 1.0)
		var profile := lerpf(1.40, 0.54, rise)
		vertices[i] = Vector3(p.x * width * profile + pow(rise, 2.2) * 0.093,
			p.y * height, p.z * width * profile)
		colors.append(color.lerp(Color("#fff0a9"), (1.0 - rise) * 0.61))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var flame := ArrayMesh.new()
	flame.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return flame

# --- 6. Handcrafted Scene Assembly ---
func _build_diorama_scene() -> void:
	# Central campfire and a sparse plume above the flames.
	for ang_d in [-28.0, 36.0, 102.0, 158.0]:
		var r := deg_to_rad(ang_d)
		_place_glb(self, "charred_log.glb", CAMPFIRE_XZ + Vector2(cos(r), sin(r)) * 0.26, 0.90, Vector3(0, ang_d, 0), Color("#6e4230"), 0.16, -0.04, 0.95)

	var fy := terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y)
	var fire_boundary := CylinderShape3D.new()
	fire_boundary.radius = 0.62
	fire_boundary.height = 0.56
	_add_solid(self, fire_boundary, Vector3(CAMPFIRE_XZ.x, fy + 0.21, CAMPFIRE_XZ.y))
	campfire_flame = Node3D.new()
	campfire_flame.position = Vector3(CAMPFIRE_XZ.x, fy + 0.16, CAMPFIRE_XZ.y)
	add_child(campfire_flame)
	for fp in [
		[Vector3(0.0, 0.48, 0.0), 0.42, 1.00, Color("#ff7714")],
		[Vector3(0.12, 0.36, 0.05), 0.28, 0.72, Color("#ffc629")],
		[Vector3(-0.10, 0.29, -0.04), 0.22, 0.56, Color("#fff6b0")]
	]:
		var fi := MeshInstance3D.new()
		fi.mesh = _flame_mesh(float(fp[1]) * 1.45, float(fp[2]), fp[3])
		fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var flame_finish := StandardMaterial3D.new()
		flame_finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame_finish.vertex_color_use_as_albedo = true
		fi.material_override = flame_finish
		fi.position = fp[0]
		campfire_flame.add_child(fi)

	_add_smoke(self, Vector3(CAMPFIRE_XZ.x + 0.1, fy + 0.82, CAMPFIRE_XZ.y - 0.1), false)
	_build_campfire_embers()

	# 6b. Hero Campfire Props (Balanced cozy diorama spacing & grounded proportions)
	_place_glb(self, "campfire_rug.glb", Vector2(1.85, 1.55), 1.95, Vector3(0, -14, 0), Color("#b83d35"), 0.22, 0.02, 1.00, true, 1.15)
	_place_glb(self, "journal_log.glb", Vector2(2.95, -0.25), 1.72, Vector3(0, 6, 0), Color("#8c5b38"), 0.14, -0.04, 0.98, true, 1.05)
	_place_glb(self, "journal.glb", Vector2(2.88, -0.25), 0.82, Vector3(0, -12, 0), Color("#f5e6cc"), 0.08, 0.42, 1.02)
	_place_glb(self, "backpack.glb", Vector2(4.05, -0.32), 1.18, Vector3(0, -24, 0), Color("#995f36"), 0.16, -0.02, 1.00, true, 0.78)
	_place_glb(self, "bedroll.glb", Vector2(3.45, 0.95), 0.95, Vector3(0, 26, 0), Color("#a63c35"), 0.18, -0.02, 0.98, true, 0.60)

	# 6c. Left of Campfire: Sitting Log + Clockwork Grunt FACING THE CAMPFIRE & CAMERA!
	_place_glb(self, "sit_log.glb", Vector2(-2.55, 0.30), 1.52, Vector3(0, 20, 0), Color("#7d4e31"), 0.14, -0.05, 0.98, true, 0.98)
	var grunt_root := _place_glb(self, "clockwork_grunt.glb", Vector2(-2.45, 0.28), 1.45, Vector3(0, 62, 0), Color("#c95838"), 0.18, 0.18, 1.02)
	_place_glb(grunt_root, "grunt_helmet.glb", Vector2(0.0, 0.0), 0.72, Vector3(0, 0, 0), Color("#7088ad"), 0.16, 1.21, 1.02, false)
	grunt_key = Node3D.new()
	grunt_key.position = Vector3(0.0, 0.66, -0.38)
	grunt_root.add_child(grunt_key)
	var kmat := StandardMaterial3D.new(); kmat.albedo_color = Color("#e0ad38"); kmat.roughness = 0.45
	var k_rod := MeshInstance3D.new(); var kcm := CylinderMesh.new(); kcm.top_radius = 0.035; kcm.bottom_radius = 0.035; kcm.height = 0.30
	k_rod.mesh = kcm; k_rod.material_override = kmat; k_rod.rotation_degrees.x = 90.0; k_rod.position = Vector3(0, 0, -0.14)
	grunt_key.add_child(k_rod)
	for kp in [Vector3(-0.15, 0.11, -0.26), Vector3(0.15, -0.11, -0.26)]:
		var kr := MeshInstance3D.new(); var ksm := SphereMesh.new(); ksm.radius = 0.12; ksm.height = 0.24
		kr.mesh = ksm; kr.material_override = kmat; kr.scale = Vector3(1.0, 1.0, 0.35); kr.position = kp
		grunt_key.add_child(kr)
	var sk := MeshInstance3D.new(); var skm := CylinderMesh.new(); skm.top_radius = 0.018; skm.bottom_radius = 0.022; skm.height = 0.96
	sk.mesh = skm; sk.rotation_degrees.x = 76.0; sk.position = Vector3(0.22, 0.62, 0.68)
	grunt_root.add_child(sk)
	_place_glb(grunt_root, "grilled_fish.glb", Vector2(0.22, 1.12), 0.56, Vector3(0, 88, 0), Color("#8ca8c4"), 0.18, 0.66, 1.04, false)

	# The supplied skinned wolf rests near the fire with stable ground contact.
	wolf_node = _place_glb(self, "companion_wolf.glb", Vector2(-0.23, -1.95), 2.28,
		Vector3(0, -38, 0), Color("#76677d"), 0.22, 0.012, 1.16)
	wolf_node.name = "CompanionWolf"
	var wolf_bounds := _compute_aabb(wolf_node, wolf_node.transform.affine_inverse())
	if wolf_bounds.has_volume():
		_block_box(wolf_node, Vector3(0.70, 1.28, 1.56), Vector3(0.0, 0.64, 0.04))
		var resting_silhouette := AABB(Vector3(-0.48, 0, -1.14), Vector3(0.96, 1.80, 2.28))
		occlusion.watch(wolf_node, resting_silhouette)
		_add_contact_shadow(wolf_node, 1.02, 0.032)
		for descendant in wolf_node.find_children("*", "MeshInstance3D", true, false):
			var companion_mesh := descendant as MeshInstance3D
			for surface in companion_mesh.mesh.get_surface_count():
				var finish := companion_mesh.get_active_material(surface) as ShaderMaterial
				if finish and finish.shader == SHADER_PROP:
					finish.set_shader_parameter("saturation", 0.93)
					finish.set_shader_parameter("grad_strength", 0.20)
					finish.set_shader_parameter("breath_strength", 0.013)

	bird_node = Node3D.new()
	bird_node.position = Vector3(2.15, terrain_height(2.15, -0.35) + 0.56, -0.35)
	bird_node.rotation_degrees.y = -28.0
	add_child(bird_node)
	var b_mat := StandardMaterial3D.new(); b_mat.albedo_color = Color("#ffbf38"); b_mat.roughness = 0.9
	var bm := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.21; bs.height = 0.38
	bm.mesh = bs; bm.material_override = b_mat; bird_node.add_child(bm)
	var beak := MeshInstance3D.new(); var bkm := BoxMesh.new(); bkm.size = Vector3(0.08, 0.06, 0.10)
	var bkmat := StandardMaterial3D.new(); bkmat.albedo_color = Color("#e8632c")
	beak.mesh = bkm; beak.material_override = bkmat; beak.position = Vector3(0, 0.02, 0.20); bird_node.add_child(beak)

	# 6e. Upper-Left Standing Stones & Mossy Stone Golem on Raised Unobstructed Knoll!
	for ss in [
		[Vector2(-7.8, -8.2), 1.95, 16.0],
		[Vector2(-6.9, -10.0), 2.55, 8.0],
		[Vector2(-5.4, -10.8), 3.40, -4.0],
		[Vector2(-3.7, -9.9), 2.60, -14.0],
		[Vector2(-3.1, -8.1), 1.85, -20.0]
	]:
		var sp2: Vector2 = ss[0]
		var sz: float = ss[1]
		_place_glb(self, "standing_stone.glb", sp2, sz, Vector3(0, float(ss[2]), 0), Color("#7d8bb5"), 0.32, -0.10, 0.98, true, 0.95)
		var orb := MeshInstance3D.new(); var os := SphereMesh.new(); os.radius = 0.12; os.height = 0.24
		var omat := StandardMaterial3D.new(); omat.albedo_color = Color("#ffca4f"); omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orb.mesh = os; orb.material_override = omat
		orb.position = Vector3(sp2.x, terrain_height(sp2.x, sp2.y) + sz * 0.58, sp2.y + 0.36)
		add_child(orb)

	golem_node = _place_glb(self, "golem.glb", Vector2(-5.4, -8.6), 1.95, Vector3(0, 14, 0), Color("#9bb386"), 0.14, -0.04, 1.02, true, 1.05)

	# 6f. Mid-Left Mossy Skull Cave (angled cleanly toward the campfire clearing, unobstructed!)
	_place_glb(self, "skull_cave.glb", Vector2(-9.3, -2.8), 4.6, Vector3(0, -28, 0), Color("#809475"), 0.22, -0.32, 0.96, true, 2.5)

	# 6g. Lower-Left Waterfall Rocks (tightly framing waterfall cascade) + Grounded Fishing Pier
	_place_glb(self, "waterfall_rock.glb", Vector2(-9.95, 3.85), 3.0, Vector3(0, 20, 0), Color("#5c6d99"), 0.32, -0.35, 0.96, true, 1.5)
	_place_glb(self, "waterfall_rock.glb", Vector2(-6.85, 3.75), 2.0, Vector3(0, -28, 0), Color("#5c6d99"), 0.32, -0.30, 0.96, true, 1.1)
	_place_glb(self, "waterfall_rock.glb", Vector2(-8.55, 3.10), 2.7, Vector3(0, 6, 0), Color("#63759e"), 0.30, -0.10, 0.96, true, 1.3)

	var pier_y := WATER_LEVEL + 0.16
	_build_fishing_pier(Vector3(PIER_XZ.x, pier_y, PIER_XZ.y))
	_place_glb(self, "bucket.glb", Vector2(-2.20, 4.92), 0.62, Vector3(0, 18, 0), Color("#849bb5"), 0.16, pier_y + 0.78, 1.02, false)
	_place_glb(self, "fishing_rod.glb", Vector2(-1.62, 4.98), 2.15, Vector3(14, -22, -24), Color("#ad6c3b"), 0.14, pier_y + 0.72, 1.00, false)
	var line_m := MeshInstance3D.new(); var lcm := CylinderMesh.new(); lcm.top_radius = 0.012; lcm.bottom_radius = 0.012; lcm.height = 1.60
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color("#e0ecff"); lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_m.mesh = lcm; line_m.material_override = lmat; line_m.position = Vector3(-1.32, WATER_LEVEL + 0.85, 5.75)
	add_child(line_m)
	fishing_bobber = Node3D.new(); fishing_bobber.position = Vector3(-1.32, WATER_LEVEL + 0.05, 5.75); add_child(fishing_bobber)
	var b_red := MeshInstance3D.new(); var brs := SphereMesh.new(); brs.radius = 0.15; brs.height = 0.30
	var brm := StandardMaterial3D.new(); brm.albedo_color = Color("#e04838"); brm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_red.mesh = brs; b_red.material_override = brm; fishing_bobber.add_child(b_red)
	var b_wht := MeshInstance3D.new(); var bws := SphereMesh.new(); bws.radius = 0.145; bws.height = 0.16
	var bwm := StandardMaterial3D.new(); bwm.albedo_color = Color("#fff6e8"); bwm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_wht.mesh = bws; b_wht.material_override = bwm; b_wht.position = Vector3(0, 0.08, 0); fishing_bobber.add_child(b_wht)

	_build_bridge()
	_build_bankside_rocks()

	var cab_xz := CABIN_XZ
	var cabin := preload("res://diorama/LakesideCabin.gd").new()
	cabin.position = Vector3(cab_xz.x, terrain_height(cab_xz.x, cab_xz.y) - 0.12, cab_xz.y)
	cabin.rotation.y = CABIN_YAW
	add_child(cabin)
	_block_box(cabin, Vector3(3.38, 2.50, 3.00), Vector3(0, 1.08, 0))
	occlusion.watch(cabin, AABB(Vector3(-1.95, 0, -1.70), Vector3(3.9, 3.26, 3.4)))
	_add_contact_shadow(cabin, 2.2)
	cabin_light.position = cabin.to_global(Vector3(0.65, 1.28, 1.9))
	_add_smoke(cabin, Vector3(0.99, 3.80, -0.49), true)

	_build_forest_canopy()
	_build_hill_steps()

	# Shoreline Foliage (Night: rich plum-magenta; Day: sunlit olive-lime)
	for sh in [
		["palm_bush.glb", Vector2(-11.8, -1.6), 1.9, 18.0, Color("#5e245c"), Color("#598f36")],
		["palm_bush.glb", Vector2(-10.4, 0.9), 1.65, -24.0, Color("#6e2b64"), Color("#6ca33b")],
		["palm_bush.glb", Vector2(5.0, -7.45), 1.85, 14.0, Color("#542361"), Color("#4f8533")],
		["palm_bush.glb", Vector2(5.1, 3.45), 1.55, -16.0, Color("#66285e"), Color("#659c39")]
	]:
		_place_glb(self, String(sh[0]), sh[1], float(sh[2]), Vector3(0, float(sh[3]), 0), sh[4], 0.78, -0.10, 1.00, true, 0.95, sh[5])

	# Grounded Bank Framing Shrubs (planted solidly on dry mossy shores, zero rock/water overlap!)
	for fg in [
		["lush_shrub.glb", Vector2(-11.4, 4.4), 2.4, 20.0, Color("#183075"), Color("#256630")],
		["lush_shrub.glb", Vector2(-12.4, 2.2), 2.1, -18.0, Color("#63245c"), Color("#6da63c")],
		["lush_shrub.glb", Vector2(12.2, 4.8), 2.4, -28.0, Color("#183075"), Color("#256630")],
		["lush_shrub.glb", Vector2(13.2, 2.8), 2.1, 16.0, Color("#63245c"), Color("#6da63c")]
	]:
		var at: Vector2 = fg[1]
		var edge_y := terrain_height(at.x, at.y)
		if edge_y > WATER_LEVEL + 0.33:
			_place_glb(self, String(fg[0]), at, float(fg[2]) * 0.84, Vector3(0, float(fg[3]), 0), fg[4], 0.82, -0.17, 1.00, true, 1.0, fg[5])

	# Scattered White & Blue Bobble Wildflowers (flanking stone steps & cabin lawn, zero wall clipping!)
	for wf in [
		Vector2(-5.35, -5.7), Vector2(-1.7, -5.55), Vector2(1.28, -3.18),
		Vector2(6.47, -4.35), Vector2(-5.37, 2.62), Vector2(3.65, 3.0),
		Vector2(11.9, -5.4), Vector2(-9.6, -5.55)
	]:
		if terrain_height(wf.x, wf.y) > WATER_LEVEL + 0.37 and _trail_weight(wf.x, wf.y) < 0.27 and not _inside_cabin(wf.x, wf.y):
			var size := 0.53 + 0.29 * absf(sin(wf.x * 2.1))
			flower_roots.append(_place_glb(self, "wildflowers.glb", wf, size, Vector3(0, wf.x * 41.0, 0), Color.WHITE, 0.0, -0.10, 1.02))

	# Natural Big/Medium/Small Shore Rock Clusters (grounded on mossy banks, clearing pier & bridge!)
	for sr in [
		[Vector2(-6.2, -1.4), 1.38], [Vector2(5.8, 1.4), 1.18],
		[Vector2(10.6, 1.0), 0.92], [Vector2(11.8, -4.0), 1.28],
		[Vector2(6.6, 5.4), 1.15], [Vector2(9.8, 5.2), 0.88],
		[Vector2(1.1, 4.55), 0.85], [Vector2(5.3, 4.2), 0.82]
	]:
		var s_xz: Vector2 = sr[0]
		var s_sz: float = float(sr[1])
		_place_glb(self, "shore_rock.glb", s_xz, s_sz, Vector3(0, s_xz.x * 31.0, 0), Color("#697aa6"), 0.28, -0.14, 0.96, true, s_sz * 0.68)

	# Stones break the water surface, with a small wake anchored around each base.
	var channel_stones := PackedVector2Array([Vector2(8.5,-6.0), Vector2(8.1,1.45), Vector2(3.8,7.1), Vector2(-6.4,8.3)])
	water_mat.set_shader_parameter("channel_stones", channel_stones)
	for i in channel_stones.size():
		_place_glb(self, "shore_rock.glb", channel_stones[i], 0.88 + i * 0.09, Vector3(0, i * 87.0, 0), Color("#747583"), 0.32, WATER_LEVEL - 0.26, 0.94, false)

	# 6k. Interactive Shatterable Props (RigidBody3D shards and pixel sparks)
	var wood_cols := [Color("#8c5838"), Color("#c48a58"), Color("#543525"), Color("#e0a050")]
	var rock_cols := [Color("#63749e"), Color("#8e9ec4"), Color("#56824e"), Color("#445070")]
	for sp in [
		["stump.glb", Vector2(-3.9, 2.1), 1.02, wood_cols],
		["stump.glb", Vector2(4.25, 2.55), 0.95, wood_cols],
		["stump.glb", Vector2(0.8, -5.8), 0.96, wood_cols],
		["shore_rock.glb", Vector2(-4.5, -3.8), 1.08, rock_cols],
		["shore_rock.glb", Vector2(12.0, 1.2), 1.05, rock_cols]
	]:
		var pxz: Vector2 = sp[1]
		var p_node := _place_glb(self, String(sp[0]), pxz, float(sp[2]), Vector3(0, randf() * 360.0, 0), Color.WHITE, 0.0, -0.04, 0.98, true, 0.72)
		ink_fx.register_shatter_prop(p_node, p_node.position, 0.95, sp[3], 3, 1)

	_build_sun_shafts()

	_build_stylized_wind_trails()

	_build_motes()

func _build_motes() -> void:
	var seed := RandomNumberGenerator.new()
	seed.seed = 692342
	var shape := SphereMesh.new()
	shape.radius = 0.069
	shape.height = 0.138
	shape.radial_segments = 8
	shape.rings = 4
	motes = MultiMesh.new()
	motes.transform_format = MultiMesh.TRANSFORM_3D
	motes.use_colors = true
	motes.mesh = shape
	motes.instance_count = MOTE_COUNT
	for i in MOTE_COUNT:
		var x := seed.randf_range(-11.5, 11.5)
		var z := seed.randf_range(-8.5, 6.5)
		var y := maxf(WATER_LEVEL, terrain_height(x, z)) + seed.randf_range(0.55, 1.85)
		mote_origins.append(Vector3(x, y, z))
		mote_seeds.append(Vector2(seed.randf_range(0.0, TAU), seed.randf_range(0.58, 1.14)))
	var draws := MultiMeshInstance3D.new()
	draws.multimesh = motes
	draws.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://diorama/shaders/diorama_motes.gdshader")
	draws.material_override = finish
	add_child(draws)
	_update_motes(0.0)

func _update_motes(time: float) -> void:
	var tint := Color("#ffe390") if is_night else Color("#fff0c3")
	var strength := (0.78 if is_night else 0.46) * (1.0 - 0.85 * rain_blend - 0.50 * snow_blend)
	for i in MOTE_COUNT:
		var data := mote_seeds[i]
		var phase := time * data.y + data.x
		var drift := Vector3(sin(phase) * 0.53, sin(phase * 1.37) * 0.23, cos(phase * 0.83) * 0.44)
		var pulse := smoothstep(-0.8, 0.75, sin(phase * 1.9 + data.x))
		motes.set_instance_transform(i, Transform3D(Basis.IDENTITY, mote_origins[i] + drift))
		motes.set_instance_color(i, Color(tint, strength * lerpf(0.18, 1.0, pulse)))

func _build_fishing_pier(at: Vector3) -> void:
	var pier := Node3D.new()
	pier.position = at
	pier.rotation.y = PIER_ROTATION
	add_child(pier)
	# Keep the walk surface clear and surround the exposed sides with water checks.
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("#d7a36a")
	finish.roughness = 0.69
	finish.metallic_specular = 0.19
	finish.vertex_color_use_as_albedo = true
	var timber := MultiMesh.new()
	timber.transform_format = MultiMesh.TRANSFORM_3D
	timber.use_colors = true
	timber.mesh = RoundedBoxMesh.build(Vector3(0.35, 0.21, 1.64), 0.057)
	timber.instance_count = 9
	for i in 9:
		var board_yaw := 0.023 * sin(i * 1.27)
		var origin := Vector3((i - 4) * 0.352, 0.67, sin(i * 3.49) * 0.041)
		timber.set_instance_transform(i, Transform3D(Basis(Vector3.UP, board_yaw), origin))
		timber.set_instance_color(i, Color("#c38a59").lerp(Color.WHITE, 0.64 + 0.32 * sin(i * 2.08)))
	var deck := MultiMeshInstance3D.new()
	deck.multimesh = timber
	deck.material_override = finish
	pier.add_child(deck)
	var legs := CylinderMesh.new()
	legs.top_radius = 0.098
	legs.bottom_radius = 0.13
	legs.height = 1.52
	var dark_wood := StandardMaterial3D.new()
	dark_wood.albedo_color = Color("#7e573c")
	dark_wood.roughness = 0.83
	for x in [-1.37, 1.37]:
		for z in [-0.58, 0.58]:
			var leg := MeshInstance3D.new()
			leg.mesh = legs
			leg.position = Vector3(x, 0.11, z)
			leg.material_override = dark_wood
			pier.add_child(leg)

func _build_campfire_embers() -> void:
	campfire_embers = GPUParticles3D.new()
	campfire_embers.position = campfire_flame.position + Vector3.UP * 0.32
	campfire_embers.amount = 12
	campfire_embers.lifetime = 1.8
	campfire_embers.preprocess = 1.8
	campfire_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drift := ParticleProcessMaterial.new()
	drift.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	drift.emission_sphere_radius = 0.16
	drift.direction = Vector3(0.16, 1.0, 0.07)
	drift.spread = 24.0
	drift.gravity = Vector3(0.16, 0.18, 0.08)
	drift.initial_velocity_min = 0.52
	drift.initial_velocity_max = 0.92
	var lifespan := Curve.new()
	lifespan.add_point(Vector2(0.0, 0.28))
	lifespan.add_point(Vector2(0.20, 1.0))
	lifespan.add_point(Vector2(0.63, 0.57))
	lifespan.add_point(Vector2(1.0, 0.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = lifespan
	drift.scale_curve = scale_curve
	campfire_embers.process_material = drift
	var ember := SphereMesh.new()
	ember.radius = 0.055
	ember.height = 0.11
	ember.radial_segments = 6
	ember.rings = 3
	var finish := StandardMaterial3D.new()
	finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finish.albedo_color = Color("#ffb954")
	ember.material = finish
	campfire_embers.draw_pass_1 = ember
	add_child(campfire_embers)

func _update_weather_lighting(mode: int, delta: float) -> void:
	var step := 1.0 - exp(-delta * 2.3)
	rain_blend = lerpf(rain_blend, 1.0 if mode == 2 else 0.0, step)
	snow_blend = lerpf(snow_blend, 1.0 if mode == 1 else 0.0, step)
	env.fog_density = clear_fog_density + rain_blend * 0.0029 + snow_blend * 0.0016
	key_light.light_energy = clear_sun_energy * (1.0 - 0.25 * rain_blend - 0.12 * snow_blend)
	water_mat.set_shader_parameter("rain_amount", rain_blend)
	for material in godray_mats:
		material.set_shader_parameter("clear_air", 1.0 - 0.83 * rain_blend - 0.45 * snow_blend)
	campfire_embers.amount_ratio = (1.0 if is_night else 0.60) * (1.0 - 0.56 * rain_blend)

func _add_smoke(parent: Node3D, at: Vector3, chimney: bool) -> void:
	var plume := GPUParticles3D.new()
	plume.position = at
	plume.amount = 30 if chimney else 11
	plume.lifetime = 3.4 if chimney else 2.6
	plume.preprocess = plume.lifetime
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.08 if chimney else 0.14
	motion.direction = Vector3(0.10, 1.0, 0.04)
	motion.spread = 14.0
	motion.initial_velocity_min = 0.61
	motion.initial_velocity_max = 0.87
	motion.gravity = Vector3(0.12, 0.22, 0.02)
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 0.34
	motion.turbulence_noise_scale = 2.4
	motion.scale_min = 0.75
	motion.scale_max = 1.25
	var shape := Curve.new()
	shape.add_point(Vector2(0.0, 0.25))
	shape.add_point(Vector2(0.48, 1.03))
	shape.add_point(Vector2(0.82, 0.86))
	shape.add_point(Vector2(1.0, 0.0))
	var scaling := CurveTexture.new()
	scaling.curve = shape
	motion.scale_curve = scaling
	plume.process_material = motion
	var puff := SphereMesh.new()
	puff.radius = 0.34 if chimney else 0.30
	puff.height = puff.radius * 1.92
	puff.radial_segments = 12
	puff.rings = 6
	var material := ShaderMaterial.new()
	material.shader = preload("res://diorama/shaders/diorama_smoke.gdshader")
	material.set_shader_parameter("opacity", 0.52 if chimney else 0.17)
	smoke_materials.append(material)
	puff.material = material
	plume.draw_pass_1 = puff
	parent.add_child(plume)

func _build_bankside_rocks() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	var blocks := MultiMesh.new()
	blocks.transform_format = MultiMesh.TRANSFORM_3D
	blocks.use_colors = true
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	mesh.radius = 0.5
	mesh.height = 1.0
	blocks.mesh = mesh
	var ledges: Array[Array] = [
		[Vector2(-13.0, 7.6), Vector2(-9.2, 8.65), 7],
		[Vector2(3.05, 10.6), Vector2(6.1, 9.4), 6],
		[Vector2(10.5, -8.55), Vector2(12.55, -4.3), 7],
		[Vector2(-8.05, -6.95), Vector2(-7.7, -3.6), 6],
	]
	var total := 0
	for ledge in ledges:
		total += int(ledge[2])
	blocks.instance_count = total
	var rng := RandomNumberGenerator.new()
	rng.seed = 240317
	var index := 0
	for ledge in ledges:
		var first: Vector2 = ledge[0]
		var last: Vector2 = ledge[1]
		var count: int = ledge[2]
		for i in count:
			var xz := first.lerp(last, float(i) / (count - 1))
			xz += Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.16, 0.16))
			var hill := terrain_height(xz.x, xz.y)
			if hill < WATER_LEVEL + 0.07:
				continue
			var height := rng.randf_range(0.7, 1.85)
			var scale_axes := Vector3(rng.randf_range(0.76, 1.18), height, rng.randf_range(0.65, 0.96))
			var basis := Basis(Vector3.UP, rng.randf_range(-0.65, 0.65)).scaled(scale_axes)
			var base := Vector3(xz.x, maxf(WATER_LEVEL - 0.13, hill - 0.28) + height * 0.11, xz.y)
			blocks.set_instance_transform(index, Transform3D(basis, base))
			blocks.set_instance_color(index, Color("#636977").lerp(Color("#a79b87"), rng.randf()))
			if _walkable(xz) and base.y + height * 0.5 > hill + 0.24:
				var stone := CylinderShape3D.new()
				stone.height = height * 0.72
				stone.radius = minf(scale_axes.x, scale_axes.z) * 0.43
				_add_solid(self, stone, base)
			index += 1
	blocks.visible_instance_count = index
	var cliffs := MultiMeshInstance3D.new()
	cliffs.multimesh = blocks
	cliffs.material_override = material
	add_child(cliffs)

func _block_box(parent: Node3D, size: Vector3, center: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_add_solid(parent, shape, center)

func _add_solid(parent: Node3D, shape: Shape3D, center: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)
	parent.add_child(body)

func _add_prop_collision(holder: Node3D, bounds: AABB) -> void:
	var size := bounds.size
	var center := bounds.get_center() - Vector3.UP * size.y * 0.09
	var narrow := minf(size.x, size.z)
	if maxf(size.x, size.z) > narrow * 1.5:
		_block_box(holder, Vector3(size.x * 0.86, maxf(0.25, size.y * 0.86), size.z * 0.86), center)
		return
	var shape := CylinderShape3D.new()
	shape.radius = maxf(0.12, narrow * 0.44)
	shape.height = maxf(0.25, size.y * 0.86)
	_add_solid(holder, shape, center)

func _on_bridge(at: Vector2) -> bool:
	return absf(at.x - BRIDGE_XZ.x) <= BRIDGE_HALF_SPAN and absf(at.y - BRIDGE_XZ.y) < BRIDGE_HALF_WIDTH

func _on_pier(at: Vector2) -> bool:
	var pier := (at - PIER_XZ).rotated(PIER_ROTATION)
	return absf(pier.x) < 1.56 and absf(pier.y) < 0.78

func _tread_height(at: Vector2) -> float:
	var top := -INF
	for tread in step_surfaces:
		var local: Vector2 = (at - tread["at"]).rotated(tread["yaw"])
		var half: Vector2 = tread["half"]
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
			top = maxf(top, tread["top"])
	return top

func _walk_height(at: Vector2) -> float:
	var ground := terrain_height(at.x, at.y)
	if _on_bridge(at):
		return maxf(ground, _bridge_deck_y(at.x))
	if _on_pier(at):
		return maxf(ground, WATER_LEVEL + 0.935)
	return maxf(ground, _tread_height(at))

func _walkable(at: Vector2) -> bool:
	if absf(at.x) > 16.5 or at.y < -12.5 or at.y > 9.5:
		return false
	return _on_bridge(at) or _on_pier(at) or _walk_height(at) > WATER_LEVEL + 0.14

func _move_traveler(direction: Vector3, delta: float) -> float:
	if direction.length_squared() < 0.0025:
		return 0.0
	var start := player.position
	var from := Vector2(start.x, start.z)
	var travel := Vector2(direction.x, direction.z) * WALK_SPEED * delta
	if _on_bridge(from):
		# Stay just inside the capsule contact margin while sliding along either rail.
		var clearance := BRIDGE_HALF_WIDTH - BRIDGE_RAIL_THICKNESS * 0.5 - PLAYER_RADIUS - 0.012
		travel.y = clampf(from.y + travel.y, BRIDGE_XZ.y - clearance, BRIDGE_XZ.y + clearance) - from.y
	if not _walkable(from + travel):
		if _walkable(from + Vector2(travel.x, 0.0)):
			travel.y = 0.0
		elif _walkable(from + Vector2(0.0, travel.y)):
			travel.x = 0.0
		else:
			return 0.0
	var horizontal := Vector3(travel.x, 0.0, travel.y)
	var collision := player.move_and_collide(horizontal)
	if collision:
		player.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	var end := Vector2(player.position.x, player.position.z)
	if not _walkable(end):
		player.position = start
		return 0.0
	player.position.y = _walk_height(end)
	return end.distance_to(from)

func _inside_cabin(x: float, z: float) -> bool:
	var local := (Vector2(x, z) - CABIN_XZ).rotated(CABIN_YAW)
	return absf(local.x) < 1.72 and absf(local.y) < 1.49

func _bridge_deck_y(x: float) -> float:
	var across := clampf((x - BRIDGE_XZ.x) / BRIDGE_HALF_SPAN, -1.0, 1.0)
	return 0.19 + 0.57 * (1.0 - across * across)

func _build_bridge() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("#a19788")
	stone.roughness = 1.0
	var pavement := ShaderMaterial.new()
	pavement.shader = preload("res://diorama/shaders/diorama_bridge.gdshader")
	_build_bridge_arch(pavement)
	var count := 20
	var step := 2.0 * BRIDGE_HALF_SPAN / count
	var block := RoundedBoxMesh.build(Vector3.ONE, 0.15)
	var rails := MultiMesh.new()
	rails.transform_format = MultiMesh.TRANSFORM_3D
	rails.mesh = block
	rails.instance_count = count * 2
	for side in 2:
		var edge := -1.0 if side == 0 else 1.0
		for i in count:
			var x := BRIDGE_XZ.x - BRIDGE_HALF_SPAN + (i + 0.5) * step
			var post := i == 0 or i == count - 1 or i == count / 2
			var size := Vector3(step * 0.98, 0.40 if post else 0.23, 0.29 if post else 0.20)
			var at := Vector3(x, _bridge_deck_y(x) + 0.09, BRIDGE_XZ.y + edge * BRIDGE_HALF_WIDTH)
			rails.set_instance_transform(side * count + i, Transform3D(Basis.from_scale(size), at))
	var rail_mesh := MultiMeshInstance3D.new()
	rail_mesh.multimesh = rails
	rail_mesh.material_override = stone
	rail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rail_mesh)
	for side in [-1.0, 1.0]:
		_block_box(self, Vector3(BRIDGE_HALF_SPAN * 2.0, 1.15, BRIDGE_RAIL_THICKNESS),
			Vector3(BRIDGE_XZ.x, 0.59, BRIDGE_XZ.y + side * BRIDGE_HALF_WIDTH))
	for side in [-1, 1]:
		var x := BRIDGE_XZ.x + float(side) * (BRIDGE_HALF_SPAN - 0.54)
		var pier := MeshInstance3D.new()
		var footing := BoxMesh.new()
		footing.size = Vector3(0.65, 1.45, 1.55)
		pier.mesh = footing
		pier.material_override = stone
		pier.position = Vector3(x, _bridge_deck_y(x) - 0.78, BRIDGE_XZ.y)
		add_child(pier)

func _build_bridge_arch(stone: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_section := PackedVector2Array([
		Vector2(-BRIDGE_HALF_WIDTH, -0.012),
		Vector2(BRIDGE_HALF_WIDTH, -0.012),
		Vector2(BRIDGE_HALF_WIDTH, -0.40),
		Vector2(-BRIDGE_HALF_WIDTH, -0.40),
	])
	for step in 24:
		var left := BRIDGE_XZ.x + lerpf(-BRIDGE_HALF_SPAN, BRIDGE_HALF_SPAN, float(step) / 24.0)
		var right := left + BRIDGE_HALF_SPAN / 12.0
		for side in cross_section.size():
			var edge_a := cross_section[side]
			var edge_b := cross_section[(side + 1) % cross_section.size()]
			var start_a := Vector3(left, _bridge_deck_y(left) + edge_a.y, BRIDGE_XZ.y + edge_a.x)
			var start_b := Vector3(left, _bridge_deck_y(left) + edge_b.y, BRIDGE_XZ.y + edge_b.x)
			var end_a := Vector3(right, _bridge_deck_y(right) + edge_a.y, BRIDGE_XZ.y + edge_a.x)
			var end_b := Vector3(right, _bridge_deck_y(right) + edge_b.y, BRIDGE_XZ.y + edge_b.x)
			for vertex in [start_a, end_a, end_b, start_a, end_b, start_b]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	var arch := MeshInstance3D.new()
	arch.mesh = surface.commit()
	arch.material_override = stone
	arch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(arch)

func _build_sun_shafts() -> void:
	var sun := key_light.basis.z.normalized()
	var ground_patches := PackedVector2Array([
		CABIN_XZ + Vector2(0.8, 0.6), Vector2(7.8, 3.2), Vector2(-4.8, -4.5),
	])
	terrain_mat.set_shader_parameter("sun_patches", ground_patches)
	water_mat.set_shader_parameter("sun_patches", ground_patches)
	for i in ground_patches.size():
		var ground: Vector2 = ground_patches[i]
		var base := Vector3(ground.x, maxf(terrain_height(ground.x, ground.y), WATER_LEVEL) - 0.10, ground.y)
		var height := 10.3 + i * 0.7
		var material := ShaderMaterial.new()
		material.shader = SHADER_GODRAY
		godray_mats.append(material)
		# Two thin intersecting planes hold their shape around the full orbit.
		for roll in [0.0, PI / 2.0]:
			var quad := QuadMesh.new()
			quad.size = Vector2(2.3 - i * 0.21, height)
			var shaft := MeshInstance3D.new()
			shaft.mesh = quad
			shaft.material_override = material
			shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var across := sun.cross(Vector3.RIGHT).normalized().rotated(sun, roll)
			shaft.transform = Transform3D(Basis(across, -sun, across.cross(-sun)), base + sun * height * 0.5)
			add_child(shaft)
			godray_nodes.append(shaft)

func _hill_center(t: float) -> Vector2:
	return Vector2(-3.0, -4.3).lerp(Vector2(-5.2, -8.4), t) + Vector2(sin(PI * t) * 0.48, 0.0)

func _build_hill_steps() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	for i in 10:
		var t := float(i) / 10.0
		var at := _hill_center(t)
		var path := (_hill_center(t + 0.036) - _hill_center(t - 0.036)).normalized()
		var yaw := atan2(path.x, path.y) + PI + rng.randf_range(-0.105, 0.105)
		var span := Vector2(rng.randf_range(1.03, 1.42), rng.randf_range(0.39, 0.49))
		at += path.orthogonal() * rng.randf_range(-0.095, 0.095)
		var y := terrain_height(at.x, at.y)
		var tread := MeshInstance3D.new()
		var rise := rng.randf_range(0.055, 0.11)
		var shape := RoundedBoxMesh.build(Vector3(span.x, 0.34, span.y), rng.randf_range(0.075, 0.14))
		var arrays := shape.surface_get_arrays(0)
		var stones: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var skew := rng.randf_range(-0.17, 0.17)
		var chip := rng.randf_range(-0.10, 0.11)
		for index in stones.size():
			var vertex := stones[index]
			vertex.x *= 1.0 + skew * vertex.z / span.y
			vertex.z *= 1.0 - 0.16 * pow(absf(vertex.x) * 2.0 / span.x, 2.0)
			vertex.z += chip * vertex.x / span.x
			stones[index] = vertex
		arrays[Mesh.ARRAY_VERTEX] = stones
		var masonry := ArrayMesh.new()
		masonry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		tread.mesh = masonry
		tread.position = Vector3(at.x, y + rise - 0.17, at.y)
		tread.rotation.y = yaw
		var surface := StandardMaterial3D.new()
		surface.albedo_color = Color("#817b68").lerp(Color("#b3a58d"), rng.randf_range(0.18, 0.95))
		surface.roughness = 0.88
		tread.material_override = surface
		add_child(tread)
		step_surfaces.append({"at": at, "yaw": yaw, "half": span * 0.5, "top": y + rise})

# Overlapping whorls with drooping scalloped tips and darker undersides.
func _fir_mesh() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 64
	for tier in 5:
		var width := 1.32 - tier * 0.204
		var y := 0.88 + tier * 0.71
		var rings: Array[PackedVector3Array] = []
		for profile in [Vector2(0.08, -0.06), Vector2(1.0, 0.0), Vector2(0.65, 0.30), Vector2(0.02, 1.10)]:
			var ring := PackedVector3Array()
			for i in segments:
				var angle := TAU * i / segments + tier * 0.31
				var branches := 15.0 - tier
				var tip := pow(0.5 + 0.5 * cos(angle * branches + tier), 1.42)
				var radius: float = width * profile.x * (0.91 + 0.091 * tip + 0.047 * sin(angle * 3.0 + tier * 0.32))
				var rise: float = y + profile.y - 0.11 * tip * pow(profile.x, 3.0)
				ring.append(Vector3(cos(angle) * radius, rise, sin(angle) * radius))
			rings.append(ring)
		for band in 3:
			var points := rings[band]
			var above := rings[band + 1]
			for i in segments:
				var j := (i + 1) % segments
				for v in [points[i], points[j], above[j], points[i], above[j], above[i]]:
					var normal := Vector3(v.x, -0.25 if band == 0 else 0.90, v.z).normalized()
					surface.set_normal(normal)
					var sunlight := clampf((v.y - 0.8) / 4.0, 0.0, 1.0)
					var tier_light := smoothstep(y - 0.10, y + 0.72, v.y)
					var tone := Color("#8ca890").lerp(Color("#e9efae"), sunlight * 0.67 + tier_light * 0.33)
					surface.set_color(tone.darkened(0.09) if band == 0 else tone)
					surface.add_vertex(v)
	return surface.commit()

# Shared meshes give the forest a continuous silhouette during the full orbit.
func _build_forest_canopy() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 48319
	var lobes := MultiMesh.new()
	lobes.transform_format = MultiMesh.TRANSFORM_3D
	lobes.use_colors = true
	lobes.use_custom_data = true
	var leaf := SphereMesh.new()
	leaf.radial_segments = 13
	leaf.rings = 7
	# Deform the shared lobe in model space so repeated crowns catch light in facets.
	var arrays := leaf.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var noise := FastNoiseLite.new()
	noise.frequency = 3.6
	for k in vertices.size():
		vertices[k] += normals[k] * noise.get_noise_3dv(vertices[k]) * 0.24
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var crown_mesh := ArrayMesh.new()
	crown_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	lobes.mesh = crown_mesh
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 7
	trunk.top_radius = 0.21
	trunk.bottom_radius = 0.32
	trunk.height = 3.0
	trunks.mesh = trunk
	var roots: Array[Vector3] = []
	for z in range(-26, 27, 3):
		for x in range(-31, 32, 3):
			var px := x + rng.randf_range(-0.85, 0.85)
			var pz := z + rng.randf_range(-0.85, 0.85)
			if absf(px) < 13.0 and pz > -11.8 and pz < 12.6:
				continue
			var ground := terrain_height(px, pz)
			if ground > WATER_LEVEL + 0.2:
				roots.append(Vector3(px, ground, pz))
	for pos_xz in [Vector2(-11,-7), Vector2(-13,0), Vector2(3,-10), Vector2(7,-8), Vector2(13,-6), Vector2(14,3), Vector2(-12.8,-4.8), Vector2(1.8, -7.6)]:
		roots.append(Vector3(pos_xz.x, terrain_height(pos_xz.x, pos_xz.y), pos_xz.y))
	trunks.instance_count = roots.size()
	var firs := MultiMesh.new()
	firs.transform_format = MultiMesh.TRANSFORM_3D
	firs.use_colors = true
	firs.mesh = _fir_mesh()
	var fir_count := 0
	var crown_count := 0
	var card_transforms: Array[Transform3D] = []
	var card_colors: Array[Color] = []
	var card_normals: Array[Color] = []
	var leaf_rng := RandomNumberGenerator.new()
	leaf_rng.seed = 20261122
	firs.instance_count = roots.size()
	lobes.instance_count = roots.size() * 6
	var trunk_collision := CylinderShape3D.new()
	trunk_collision.radius = 0.30
	trunk_collision.height = 2.6
	for i in roots.size():
		if _walkable(Vector2(roots[i].x, roots[i].z)):
			_add_solid(self, trunk_collision, roots[i] + Vector3.UP * 1.3)
		var center := roots[i] + Vector3.UP * rng.randf_range(2.7, 3.7)
		trunks.set_instance_transform(i, Transform3D(Basis.IDENTITY, roots[i] + Vector3.UP * 1.48))
		var feature_broadleaf := i >= roots.size() - 2
		if (rng.randf() < 0.55 or i >= roots.size() - 8) and not feature_broadleaf:
			var height_scale := rng.randf_range(0.72, 1.36)
			var crown_width := rng.randf_range(0.88, 1.19)
			var crown_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(crown_width, height_scale, crown_width))
			firs.set_instance_transform(fir_count, Transform3D(crown_basis, roots[i]))
			firs.set_instance_color(fir_count, Color("#125347").lerp(Color("#629432"), rng.randf()))
			fir_count += 1
			continue
		var spin := rng.randf() * TAU
		var shade := rng.randf_range(0.50, 1.0)
		var leaf_color := Color("#085344").lerp(Color("#aac936"), pow(rng.randf(), 1.9))
		if feature_broadleaf and i == roots.size() - 1:
			leaf_color = Color("#95b42a")
		var add_detail := Vector2(roots[i].x, roots[i].z).length_squared() < 290.0
		for j in 6:
			var angle := spin + TAU * j / 5.0
			var offset := Vector3(cos(angle), rng.randf_range(-0.25, 0.3), sin(angle)) * 1.05
			if j == 5:
				offset = Vector3.UP * 1.0
			var size := rng.randf_range(1.65, 2.25)
			var scale_axes := Vector3(size * 1.34, size * rng.randf_range(0.78, 1.16), size)
			lobes.set_instance_transform(crown_count * 6 + j, Transform3D(Basis.from_scale(scale_axes), center + offset))
			lobes.set_instance_color(crown_count * 6 + j, leaf_color.darkened((1.0 - shade) * 0.4))
			var local_shift := offset / scale_axes
			lobes.set_instance_custom_data(crown_count * 6 + j,
				Color(local_shift.x, local_shift.y, local_shift.z, 1.0))
			if add_detail:
				# World-anchored cards trace the visible outside of each solid lobe.
				for k in 17:
					var face_angle := angle + k * 2.39996
					var normal := Vector3(cos(face_angle), leaf_rng.randf_range(-0.29, 0.96), sin(face_angle)).normalized()
					if j < 5 and normal.dot(offset.normalized()) < -0.34:
						continue
					var p := center + offset + normal * scale_axes * leaf_rng.randf_range(0.47, 0.535)
					var radius := leaf_rng.randf_range(0.18, 0.35)
					card_transforms.append(Transform3D(Basis.from_scale(Vector3.ONE * radius), p))
					card_colors.append(leaf_color.darkened((1.0 - shade) * 0.4))
					card_normals.append(Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5,
						normal.z * 0.5 + 0.5, leaf_rng.randf()))
		crown_count += 1
	firs.visible_instance_count = fir_count
	lobes.visible_instance_count = crown_count * 6
	for batch in [trunks, lobes, firs]:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = batch
		if batch == trunks:
			var bark := StandardMaterial3D.new()
			bark.roughness = 1.0
			bg_trunk_mats.append({"mat": bark, "day": Color("#876445"), "night": Color("#433349")})
			mi.material_override = bark
		else:
			var needles := ShaderMaterial.new()
			needles.shader = preload("res://diorama/shaders/diorama_canopy.gdshader")
			needles.set_shader_parameter("conifer", batch == firs)
			needles.set_shader_parameter("wind_field", vegetation_wind_field)
			canopy_finishes.append(needles)
			tod_foliage.append({"mat": needles, "day": Color.WHITE, "night": Color("#7189b5"), "canopy": true})
			mi.material_override = needles
		add_child(mi)

	_add_forest_leaf_detail(card_transforms, card_colors, card_normals)

func _add_forest_leaf_detail(transforms: Array[Transform3D], colors: Array[Color], normals: Array[Color]) -> void:
	var cards := MultiMesh.new()
	cards.transform_format = MultiMesh.TRANSFORM_3D
	cards.use_colors = true
	cards.use_custom_data = true
	cards.mesh = QuadMesh.new()
	cards.instance_count = transforms.size()
	for i in transforms.size():
		cards.set_instance_transform(i, transforms[i])
		cards.set_instance_color(i, colors[i])
		cards.set_instance_custom_data(i, normals[i])
	var detail := MultiMeshInstance3D.new()
	detail.name = "ForestLeafDetail"
	detail.multimesh = cards
	detail.extra_cull_margin = 0.7
	detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://diorama/shaders/diorama_leaf_cluster.gdshader")
	finish.set_shader_parameter("wind_field", vegetation_wind_field)
	detail.material_override = finish
	canopy_finishes.append(finish)
	tod_foliage.append({"mat": finish, "day": Color.WHITE, "night": Color("#7189b5"), "canopy": true})
	add_child(detail)

func _build_stylized_wind_trails() -> void:
	var curves := [
		[Vector3(-10, 5, -8), Vector3(-6, 7, -10), Vector3(1, 4, -8), 0.031, 0.14, 0.0],
		[Vector3(2, 4.8, 2), Vector3(6, 6.2, -0.8), Vector3(12, 4.2, -2), 0.028, 0.12, 0.5],
		[Vector3(-2, 5, -6), Vector3(4, 6.2, -8), Vector3(11, 5.4, -7), 0.025, 0.15, 0.22]
	]
	for c in curves:
		var p0: Vector3 = c[0]
		var p1: Vector3 = c[1]
		var p2: Vector3 = c[2]
		var half_width: float = c[3]
		var ribbon := SurfaceTool.new()
		ribbon.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		ribbon.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
		for segment in 37:
			var t := float(segment) / 36.0
			var point := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
			var tangent := (p1 - p0).lerp(p2 - p1, t).normalized()
			for side in [0.0, 1.0]:
				ribbon.set_uv(Vector2(t, side))
				ribbon.set_custom(0, Color(tangent.x, tangent.y, tangent.z, half_width))
				ribbon.add_vertex(point)
		var mi := MeshInstance3D.new()
		mi.mesh = ribbon.commit()
		mi.custom_aabb = mi.mesh.get_aabb().grow(0.35)
		var wmat := ShaderMaterial.new()
		wmat.shader = SHADER_WIND_TRAIL
		wmat.set_shader_parameter("speed", float(c[4]))
		wmat.set_shader_parameter("phase_offset", float(c[5]))
		mi.material_override = wmat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wind_trail_mats.append(wmat)
		add_child(mi)

# --- 7. Playable Traveler & Low-FOV Telephoto Miniature Camera (vC7OEC Toybox Look!) ---
func _setup_player_and_camera() -> void:
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player.collision_layer = 0
	player.collision_mask = 2
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = 1.13
	collider.shape = capsule
	collider.position.y = 0.565
	player.add_child(collider)
	# Start nestled cozily beside the Giant Wolf & Campfire with clear hero silhouette!
	player.position = Vector3(1.38, terrain_height(1.38, -0.32), -0.32)
	add_child(player)
	player_visual = Node3D.new()
	player.add_child(player_visual)
	var traveler := _place_glb(player_visual, "traveler_c01_animated.glb", Vector2.ZERO, 1.32,
		Vector3.ZERO, Color.WHITE, 0.0, 0.0, 1.04, false, 0.50)
	var animation_players := traveler.find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		traveler.queue_free()
		_place_glb(player_visual, "traveler_c01.glb", Vector2.ZERO, 1.32, Vector3.ZERO, Color.WHITE, 0.0, 0.0, 1.04, false, 0.50)
	else:
		player_motion = animation_players[0] as AnimationPlayer
		for motion in [&"Idle", &"Walk"]:
			if player_motion.has_animation(motion):
				player_motion.get_animation(motion).loop_mode = Animation.LOOP_LINEAR
		_build_practice_sword(traveler)
		_play_traveler_motion(&"Idle")

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 22.0
	camera.near = 1.0
	camera.far = 220.0
	camera.current = true
	add_child(camera)
	_update_camera(1.0)

func _build_practice_sword(traveler: Node3D) -> void:
	var skeletons := traveler.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var hand := "mixamorig_RightHand"
	if skeleton.find_bone(hand) < 0:
		return
	var grip := BoneAttachment3D.new()
	grip.bone_name = hand
	skeleton.add_child(grip)
	practice_sword = Node3D.new()
	practice_sword.position = Vector3(0.0, 0.028, 0.018)
	practice_sword.rotation.z = -PI * 0.5
	practice_sword.visible = false
	grip.add_child(practice_sword)
	for spec in [
		[Vector3(0.052, 0.125, 0.052), -0.016, Color("#72503b")],
		[Vector3(0.157, 0.044, 0.052), 0.053, Color("#c89b63")],
		[Vector3(0.076, 0.35, 0.042), 0.233, Color("#e6bf82")],
	]:
		var part := MeshInstance3D.new()
		part.mesh = RoundedBoxMesh.build(spec[0], 0.018)
		part.position.y = spec[1]
		var finish := StandardMaterial3D.new()
		finish.albedo_color = spec[2]
		finish.roughness = 0.81
		part.material_override = finish
		practice_sword.add_child(part)

func _update_camera(lerp_w: float) -> void:
	var target: Vector3
	var desired: Vector3
	if orbit_camera:
		target = ORBIT_TARGET
		var radius := 34.0
		desired = target + Vector3(sin(orbit_angle) * radius, 43.5, cos(orbit_angle) * radius)
	else:
		target = player.position.lerp(Vector3(0.1, 0.25, -0.4), 0.37)
		desired = target + Vector3(0.0, 30.0, 34.0)
	camera.position = camera.position.lerp(desired, lerp_w)
	camera_target = camera_target.lerp(target, lerp_w)
	camera.look_at(camera_target)
	if lens_material:
		lens_strength = lerpf(lens_strength, 1.0 if orbit_camera else 0.58, lerp_w)
		lens_material.set_shader_parameter("orbit_blur", lens_strength)

# --- 8. Ultra-Clean Minimalist UI ---
func _setup_minimal_ui() -> void:
	var lens_layer := CanvasLayer.new()
	lens_layer.layer = 0
	add_child(lens_layer)
	var lens := ColorRect.new()
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens_material = ShaderMaterial.new()
	lens_material.shader = preload("res://diorama/shaders/diorama_lens.gdshader")
	lens.material = lens_material
	lens_layer.add_child(lens)
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	var overlay := hud_parent if is_instance_valid(hud_parent) else self
	overlay.add_child(cl)

	hint_panel = PanelContainer.new()
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_panel.offset_left = 18; hint_panel.offset_bottom = -16; hint_panel.offset_top = -52; hint_panel.offset_right = 680
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.24, 0.72)
	sb.border_color = Color(0.95, 0.76, 0.38, 0.45)
	sb.set_border_width_all(1); sb.set_corner_radius_all(14)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	hint_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(hint_panel)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("#f2ebd9"))
	hint_panel.add_child(hint_label)
	_refresh_hint()

	toast_label = Label.new()
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -260; toast_label.offset_right = 260; toast_label.offset_top = 20
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color("#ffe9a8"))
	toast_label.add_theme_color_override("font_outline_color", Color("#0d1326"))
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.hide()
	cl.add_child(toast_label)

func _refresh_hint() -> void:
	if not hint_label:
		return
	var tod := "🌙 深夜" if is_night else "☀️ 日光"
	var w_txt: String = String(ink_fx.get_weather_label()) if ink_fx else "✨ 星夜"
	var cam_t := "環繞" if orbit_camera else "跟隨"
	hint_label.text = "WASD 移動 · 左鍵/J 揮擊碎裂 · [V] %s · [N] %s · [R] %s鏡頭 · [H] 隱藏提示" % [w_txt, tod, cam_t]

func _show_toast(msg: String, dur := 2.8) -> void:
	if toast_label:
		toast_label.text = msg
		toast_label.show()
		toast_timer = dur

# --- 9. Input & Living Animation Loop ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_V:
				var msg: String = ink_fx.cycle_weather()
				_show_toast(msg, 3.2)
				_refresh_hint()
			KEY_N:
				_apply_time_of_day(not is_night)
				_show_toast("🌙 切換為深夜營火氛圍（06_29_51）" if is_night else "☀️ 切換為日光微縮森林（vC7OEC）", 2.8)
				_refresh_hint()
			KEY_R:
				orbit_camera = not orbit_camera
				if orbit_camera:
					var offset := camera.position - ORBIT_TARGET
					orbit_angle = atan2(offset.x, offset.z)
				_show_toast("🎥 開啟 360° 微縮盒庭環繞鑑賞" if orbit_camera else "🎥 返回跟隨鏡頭", 2.2)
				_refresh_hint()
			KEY_H:
				show_hint = not show_hint
				if hint_panel:
					hint_panel.visible = show_hint
			KEY_J:
				_perform_swing()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_perform_swing()

func _play_traveler_motion(clip: StringName, speed := 1.0, restart := false) -> bool:
	if player_motion == null or not player_motion.has_animation(clip):
		return false
	if restart and player_motion.current_animation == clip:
		player_motion.seek(0.0, true)
	elif player_motion.current_animation != clip:
		player_motion.play(clip, 0.12, speed)
	return true

func _perform_swing() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = 0.28
	if player_motion:
		player_motion.speed_scale = 1.0
	if not _play_traveler_motion(&"Swing", 1.65, true):
		var tw := create_tween()
		tw.tween_property(player_visual, "rotation:y", player_visual.rotation.y + TAU, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if lakeside_audio:
		lakeside_audio.swing()
	strike_facing = player_visual.basis.z
	strike_delay = 0.105

func flash_hit(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var orig := node.scale
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(orig.x * 1.18, orig.y * 0.84, orig.z * 1.18), 0.06)
	tw.tween_property(node, "scale", orig, 0.12)

func _physics_process(delta: float) -> void:
	scene_time += delta
	var t := scene_time
	attack_cd = maxf(0.0, attack_cd - delta)
	if strike_delay > 0.0:
		strike_delay = maxf(0.0, strike_delay - delta)
		if strike_delay == 0.0 and ink_fx.try_hit_shatter_props(player.position, 1.17, self, strike_facing):
			lakeside_audio.impact()
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_label:
			toast_label.hide()

	var h_in := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v_in := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := Vector3(camera.transform.basis.x.x, 0.0, camera.transform.basis.x.z).normalized()
	var fwd := Vector3(camera.transform.basis.z.x, 0.0, camera.transform.basis.z.z).normalized()
	var move_dir := (right * h_in + fwd * v_in).limit_length()
	var traveled := _move_traveler(move_dir, delta)
	var moving := traveled > 0.0001
	if moving:
		player_yaw = atan2(move_dir.x, move_dir.z)
		player_visual.rotation.y = lerp_angle(player_visual.rotation.y, player_yaw, 1.0 - exp(-delta * 15.0))
		footstep_distance += traveled
		if footstep_distance >= FOOTSTEP_SPACING:
			footstep_distance = fmod(footstep_distance, FOOTSTEP_SPACING)
			if lakeside_audio:
				var at := Vector2(player.position.x, player.position.z)
				lakeside_audio.step(_on_pier(at), _on_bridge(at) or is_finite(_tread_height(at)))
	else:
		footstep_distance = minf(footstep_distance, FOOTSTEP_SPACING * 0.5)

	if player_motion != null:
		var swinging := player_motion.current_animation == &"Swing"
		if practice_sword != null:
			practice_sword.visible = swinging
		if not swinging:
			_play_traveler_motion(&"Walk" if moving else &"Idle")
			var cadence := clampf(traveled / (delta * WALK_SPEED), 0.35, 1.0) * WALK_CADENCE
			player_motion.speed_scale = cadence if moving else 1.0
	for flower in flower_roots:
		var breeze := sin(t * 1.43 + flower.position.x * 0.54 + flower.position.z * 0.31)
		flower.rotation.x = breeze * 0.043
		flower.rotation.z = breeze * 0.029

	if orbit_camera:
		orbit_angle += delta * TAU / 16.0
	_update_camera(1.0 - exp(-delta * 4.5))
	var sight := player.global_position + Vector3.UP * 0.72
	occlusion.update_view(camera, sight, delta)
	for finish in canopy_finishes:
		finish.set_shader_parameter("traveler_sight", sight)
		finish.set_shader_parameter("sight_camera", camera.global_position)

	if campfire_flame:
		campfire_flame.scale = Vector3(1.0 + sin(t * 8.5) * 0.06, 0.94 + sin(t * 12.5) * 0.14, 1.0 + cos(t * 9.5) * 0.06)
	if campfire_light:
		var base_e := 2.85 if is_night else 0.70
		var flicker := sin(t * 4.3) * 0.13 + sin(t * 8.2 + 0.9) * 0.075 + sin(t * 13.1) * 0.036
		campfire_light.light_energy = base_e * (1.0 + flicker * 0.48)

	if golem_node:
		golem_node.position.y = terrain_height(-5.4, -8.6) - 0.04 + absf(sin(t * 2.2)) * 0.06
	if bird_node:
		bird_node.position.y = terrain_height(2.15, -0.35) + 0.56 + absf(sin(t * 3.4)) * 0.04

	_update_motes(t)

	if ink_fx:
		ink_fx.step(delta, player.position, moving)
		precipitation.follow_weather(ink_fx.weather_mode, player.position)
		_update_weather_lighting(ink_fx.weather_mode, delta)

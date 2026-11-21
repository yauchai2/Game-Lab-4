extends Node3D

# Brand-New Handcrafted 3D Lakeside Campfire Diorama
# Visual Atmosphere: ChatGPT Night Campfire Reference (151bb106.png)
# Diorama Tech: Sculpted 3D Heightfield + Recessed Water w/ Auto Shore Foam + Soft Shadows + Volumetric God Rays (vC7OEC.mp4)
# Interactive FX: Smooth Bilinear Persistent Surface State (Scorch/Snow/Wetness) + RigidBody3D Shatter Physics

const SHADER_TERRAIN := preload("res://diorama/shaders/diorama_terrain.gdshader")
const SHADER_WATER := preload("res://diorama/shaders/diorama_water.gdshader")
const SHADER_WATERFALL := preload("res://diorama/shaders/diorama_waterfall.gdshader")
const SHADER_PROP := preload("res://diorama/shaders/diorama_prop.gdshader")
const SHADER_GODRAY := preload("res://diorama/shaders/diorama_godray.gdshader")
const INK_FX_SCRIPT := preload("res://prologue/InkStudioFX.gd")
const MODEL_DIR := "res://assets/models/campfire/"

const MAP_MIN := Vector2(-22.0, -17.0)
const MAP_SIZE := Vector2(44.0, 34.0)
const WATER_LEVEL := -0.58
const CAMPFIRE_XZ := Vector2(0.0, 0.2)

var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var godray_mats: Array[ShaderMaterial] = []
var prop_mats: Array[ShaderMaterial] = []
var ink_fx: Node3D

var world_env: WorldEnvironment
var env: Environment
var sky_mat: ProceduralSkyMaterial
var key_light: DirectionalLight3D
var campfire_light: OmniLight3D
var cabin_light: OmniLight3D
var camera: Camera3D

var player: Node3D
var player_visual: Node3D
var player_yaw := 0.0
var _walk_phase := 0.0

var campfire_flame: Node3D
var campfire_smoke: Array[Dictionary] = []
var cabin_smoke: Array[Dictionary] = []
var waterfall_foam: Array[Dictionary] = []
var fishing_bobber: Node3D
var grunt_key: Node3D
var golem_node: Node3D
var wolf_node: Node3D
var bird_node: Node3D
var fireflies: Array[Dictionary] = []

var is_night := true
var orbit_camera := false
var orbit_angle := 0.0
var show_hint := true
var hint_panel: PanelContainer
var hint_label: Label
var toast_label: Label
var toast_timer := 0.0
var attack_cd := 0.0

# --- 1. Analytical 3D Sculpted Diorama Heightfield (Every object & water shader shares this exact truth!) ---
func _river_center_x(z: float) -> float:
	return 8.5 + sin((z + 1.2) * 0.24) * 1.35 - (z + 1.8) * 0.24

func _lake_shore_z(x: float) -> float:
	# Smooth curved southern shoreline dipping south around the right cabin peninsula
	var base := 4.35 + sin(x * 0.26) * 0.72 + cos(x * 0.14) * 0.45
	if x > 5.5:
		base += smoothstep(5.5, 10.5, x) * 3.1
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
		Vector2(-7.8, -2.6), Vector2(-4.8, -1.0), Vector2(-2.2, 0.4),
		Vector2(0.0, 0.2), Vector2(2.8, -0.3), Vector2(5.8, -1.1),
		Vector2(8.7, -1.1), Vector2(12.2, -1.4), Vector2(16.5, -1.2)
	]
	var min_d := 999.0
	for i in range(pts.size() - 1):
		min_d = minf(min_d, _dist_to_segment(p, pts[i], pts[i + 1]))
	return smoothstep(1.35, 0.42, min_d)

func terrain_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	# Gentle organic rolling meadow base
	var h := 0.12 + sin(x * 0.16) * 0.12 + cos(z * 0.18) * 0.10

	# Upper-left Standing Stones & Golem Hill (raised grassy knoll!)
	var d_hill := p.distance_to(Vector2(-7.0, -7.8))
	h += smoothstep(6.2, 1.2, d_hill) * 1.75

	# Mid-left Skull Cave Slope (hillside embracing the skull cave)
	var d_skull := p.distance_to(Vector2(-8.6, -3.4))
	h += smoothstep(5.5, 1.4, d_skull) * 1.45

	# Lower-left Waterfall Cliff Ledge (drops dramatically into the lake!)
	var d_wf_cliff := p.distance_to(Vector2(-10.2, 3.2))
	h += smoothstep(4.2, 1.1, d_wf_cliff) * 1.55

	# Northern & Far-West Forest Ridges (frame the miniature diorama like vC7OEC!)
	if z < -8.5:
		h += smoothstep(-8.5, -15.5, z) * 2.1
	if x < -12.0:
		h += smoothstep(-12.0, -19.0, x) * 1.6
	if x > 13.5:
		h += smoothstep(13.5, 19.5, x) * 1.4

	# Flatten central campfire clearing gently so camp props sit comfortably
	var d_fire := p.distance_to(CAMPFIRE_XZ)
	h = lerpf(h, 0.14, smoothstep(5.2, 1.8, d_fire) * 0.85)

	# Cabin Peninsula Promontory (right foreground between river mouth & lake)
	var d_cab := p.distance_to(Vector2(9.8, 5.2))
	h = lerpf(h, 0.42, smoothstep(4.2, 1.5, d_cab) * 0.82)

	# Carve Winding Right River Channel BELOW water level!
	var rx := _river_center_x(z)
	var d_river := absf(x - rx)
	var river_w := 2.35 if z < 4.5 else 3.2
	var river_cut := smoothstep(river_w + 1.35, river_w * 0.45, d_river)
	# Keep a narrow raised lip right at the bridge abutments? No, bridge spans cleanly across!
	h = lerpf(h, -1.42, river_cut)

	# Carve Deep Southern Lake Basin BELOW water level!
	var shore_z := _lake_shore_z(x)
	var lake_cut := smoothstep(shore_z - 1.25, shore_z + 1.35, z)
	# Keep waterfall cliff protruding at far left until z = 4.6
	if x < -7.2 and z < 4.8:
		lake_cut *= smoothstep(3.6, 4.9, z)
	h = lerpf(h, -1.68, lake_cut)

	return h

func _ready() -> void:
	ink_fx = INK_FX_SCRIPT.new()
	add_child(ink_fx)
	var state_tex: ImageTexture = ink_fx.setup(Vector3(CAMPFIRE_XZ.x, terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y), CAMPFIRE_XZ.y))
	# Clear harsh default scorch so initial clearing is warm & welcoming (only soft char right under logs)
	ink_fx.state_img.fill(Color(0.0, 0.0, 0.0, 1.0))
	ink_fx.paint_scorch(Vector3(CAMPFIRE_XZ.x, 0.0, CAMPFIRE_XZ.y), 1.15, 0.42)
	ink_fx.state_tex.update(ink_fx.state_img)

	_setup_environment_and_lights()
	var height_tex := _build_sculpted_terrain(state_tex)
	_build_water_and_waterfall(height_tex)
	_build_diorama_scene()
	_setup_player_and_camera()
	_setup_minimal_ui()
	_apply_time_of_day(true)

# --- 2. Environment, ACES Tonemapping, Soft Shadows & Three-Layer Lighting ---
func _setup_environment_and_lights() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_density = 0.0085

	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-44.0, -34.0, 0.0)
	key_light.shadow_enabled = true
	key_light.shadow_blur = 2.6
	key_light.shadow_bias = 0.03
	add_child(key_light)

	# Warm Campfire Focal Light (soft, controlled — NO neon blow-out!)
	campfire_light = OmniLight3D.new()
	campfire_light.light_color = Color("#ff9c42")
	campfire_light.light_energy = 3.1
	campfire_light.omni_range = 10.5
	campfire_light.omni_attenuation = 1.35
	campfire_light.shadow_enabled = true
	campfire_light.shadow_blur = 2.5
	campfire_light.position = Vector3(CAMPFIRE_XZ.x, terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y) + 1.25, CAMPFIRE_XZ.y)
	add_child(campfire_light)

	# Warm Cozy Cabin Window Light
	cabin_light = OmniLight3D.new()
	cabin_light.light_color = Color("#ffb852")
	cabin_light.light_energy = 1.85
	cabin_light.omni_range = 5.5
	cabin_light.position = Vector3(9.0, terrain_height(9.0, 6.2) + 1.2, 6.2)
	add_child(cabin_light)

func _apply_time_of_day(night: bool) -> void:
	is_night = night
	if night:
		# Exact 151bb106.png Midnight Indigo Forest x Warm Honey Campfire!
		sky_mat.sky_top_color = Color("#09112b")
		sky_mat.sky_horizon_color = Color("#182852")
		sky_mat.ground_bottom_color = Color("#0c1633")
		sky_mat.ground_horizon_color = Color("#182852")
		env.ambient_light_color = Color("#2c3f73")
		env.ambient_light_energy = 0.56
		env.fog_light_color = Color("#131f42")
		key_light.light_color = Color("#8fb4ff")
		key_light.light_energy = 0.68
		campfire_light.light_energy = 3.2
		cabin_light.light_energy = 1.9
		if terrain_mat:
			terrain_mat.set_shader_parameter("grass_deep", Color("#17293b"))
			terrain_mat.set_shader_parameter("grass_mid", Color("#28433b"))
			terrain_mat.set_shader_parameter("grass_hill", Color("#3a5c44"))
			terrain_mat.set_shader_parameter("campfire_dirt", Color("#c98842"))
			terrain_mat.set_shader_parameter("shadow_tint", Color("#131b40"))
			terrain_mat.set_shader_parameter("night_mix", 1.0)
		if water_mat:
			water_mat.set_shader_parameter("deep_color", Color("#14428a"))
			water_mat.set_shader_parameter("shallow_color", Color("#2a75cf"))
		for gm in godray_mats:
			gm.set_shader_parameter("ray_color", Color(0.55, 0.76, 1.0, 0.13))
		for pm in prop_mats:
			pm.set_shader_parameter("shadow_tint", Color("#151e45"))
	else:
		# Exact vC7OEC.mp4 Sunlit Emerald Miniature Forest x Golden God Rays!
		sky_mat.sky_top_color = Color("#5aa8f0")
		sky_mat.sky_horizon_color = Color("#bce3ff")
		sky_mat.ground_bottom_color = Color("#4d8a55")
		sky_mat.ground_horizon_color = Color("#bce3ff")
		env.ambient_light_color = Color("#8db8c7")
		env.ambient_light_energy = 0.62
		env.fog_light_color = Color("#9fd4e8")
		key_light.light_color = Color("#fff2cc")
		key_light.light_energy = 1.28
		campfire_light.light_energy = 1.1
		cabin_light.light_energy = 0.6
		if terrain_mat:
			terrain_mat.set_shader_parameter("grass_deep", Color("#3b733f"))
			terrain_mat.set_shader_parameter("grass_mid", Color("#5c9947"))
			terrain_mat.set_shader_parameter("grass_hill", Color("#7cb854"))
			terrain_mat.set_shader_parameter("campfire_dirt", Color("#cfa165"))
			terrain_mat.set_shader_parameter("shadow_tint", Color("#2c4f66"))
			terrain_mat.set_shader_parameter("night_mix", 0.0)
		if water_mat:
			water_mat.set_shader_parameter("deep_color", Color("#1d68c4"))
			water_mat.set_shader_parameter("shallow_color", Color("#3ea8f2"))
		for gm in godray_mats:
			gm.set_shader_parameter("ray_color", Color(1.0, 0.94, 0.66, 0.20))
		for pm in prop_mats:
			pm.set_shader_parameter("shadow_tint", Color("#2b4963"))

# --- 3. 96x96 Sculpted 3D Terrain Mesh + Baked Heightmap Texture for Auto Shore Foam ---
func _build_sculpted_terrain(state_tex: ImageTexture) -> ImageTexture:
	var grid := 96
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
			var fire_w := smoothstep(6.2, 1.6, d_fire) * smoothstep(-0.3, 0.05, y)
			var shore_w := smoothstep(-0.15, -0.68, y)
			cols[idx] = Color(trail_w, fire_w, shore_w, 1.0)

	for iz in range(grid):
		for ix in range(grid):
			var i00 := iz * (grid + 1) + ix
			var i10 := i00 + 1
			var i01 := (iz + 1) * (grid + 1) + ix
			var i11 := i01 + 1
			# Triangle 1
			st.set_color(cols[i00]); st.add_vertex(verts[i00])
			st.set_color(cols[i10]); st.add_vertex(verts[i10])
			st.set_color(cols[i11]); st.add_vertex(verts[i11])
			# Triangle 2
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
	terrain_mat.set_shader_parameter("map_min", MAP_MIN)
	terrain_mat.set_shader_parameter("map_size", MAP_SIZE)
	mi.material_override = terrain_mat
	add_child(mi)

	# Concave collision shape matching the exact 3D sculpted hills so RigidBody3D debris bounce naturally!
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var col_sh := CollisionShape3D.new()
	col_sh.shape = mesh.create_trimesh_shape()
	body.add_child(col_sh)

	# Bake 128x128 heightmap texture for automatic shoreline foam in diorama_water.gdshader
	var h_res := 128
	var himg := Image.create_empty(h_res, h_res, false, Image.FORMAT_RF)
	for py in range(h_res):
		var z := MAP_MIN.y + (float(py) / float(h_res - 1)) * MAP_SIZE.y
		for px in range(h_res):
			var x := MAP_MIN.x + (float(px) / float(h_res - 1)) * MAP_SIZE.x
			var h := terrain_height(x, z)
			var norm_h := clampf((h + 2.0) / 6.0, 0.0, 1.0)
			himg.set_pixel(px, py, Color(norm_h, 0.0, 0.0, 1.0))
	return ImageTexture.create_from_image(himg)

# --- 4. Continuous Water Plane + Curved Waterfall Ribbon + Soft Foam Puffs ---
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
	water_mat.set_shader_parameter("bobber_pos", Vector3(-1.35, WATER_LEVEL, 5.85))
	water_mat.set_shader_parameter("waterfall_pos", Vector3(-8.6, WATER_LEVEL, 5.15))
	w_inst.material_override = water_mat
	w_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w_inst)

	# Curved Cascading Waterfall Ribbon from Left Cliff (+1.55m) into Lake (-0.58m)
	var wf_st := SurfaceTool.new()
	wf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wf_w := 2.1
	var segs := 10
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(1.45, WATER_LEVEL - 0.05, t0 * t0)
		var y1 := lerpf(1.45, WATER_LEVEL - 0.05, t1 * t1)
		var z0 := lerpf(3.95, 5.15, t0)
		var z1 := lerpf(3.95, 5.15, t1)
		var v00 := Vector3(-wf_w * 0.5, y0, z0)
		var v10 := Vector3(wf_w * 0.5, y0, z0)
		var v01 := Vector3(-wf_w * 0.5, y1, z1)
		var v11 := Vector3(wf_w * 0.5, y1, z1)
		wf_st.set_uv(Vector2(0, t0)); wf_st.add_vertex(v00)
		wf_st.set_uv(Vector2(1, t0)); wf_st.add_vertex(v10)
		wf_st.set_uv(Vector2(1, t1)); wf_st.add_vertex(v11)
		wf_st.set_uv(Vector2(0, t0)); wf_st.add_vertex(v00)
		wf_st.set_uv(Vector2(1, t1)); wf_st.add_vertex(v11)
		wf_st.set_uv(Vector2(0, t1)); wf_st.add_vertex(v01)
	var wf_mi := MeshInstance3D.new()
	wf_mi.mesh = wf_st.commit()
	var wf_mat := ShaderMaterial.new()
	wf_mat.shader = SHADER_WATERFALL
	wf_mi.material_override = wf_mat
	wf_mi.position = Vector3(-8.6, 0.0, 0.0)
	wf_mi.rotation_degrees.y = 14.0
	add_child(wf_mi)

	# Soft translucent splash foam clouds at waterfall base
	for i in range(6):
		var fm := _soft_cloud_puff(Vector3(-8.6 + float(i - 2.5) * 0.48, WATER_LEVEL + 0.16, 5.18 + absf(float(i - 2.5)) * 0.12), randf_range(0.45, 0.72), Color(0.88, 0.96, 1.0, 0.78))
		waterfall_foam.append({"node": fm, "base": fm.position, "ph": float(i) * 1.1})

# --- 5. Clean GLB Loader with Restrained Velvety Shading ---
func _apply_prop_shader(node: Node, tint_col: Color, tint_mix: float, brightness := 1.02) -> void:
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
	for c in node.get_children():
		_apply_prop_shader(c, tint_col, tint_mix, brightness)

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

func _place_glb(parent: Node3D, fname: String, xz: Vector2, target_size: float, rot_deg := Vector3.ZERO, tint := Color.WHITE, tint_mix := 0.0, y_offset := 0.0, brightness := 1.02, use_terrain_y := true) -> Node3D:
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
			_apply_prop_shader(inst, tint, tint_mix, brightness)
			holder.add_child(inst)
	return holder

func _soft_cloud_puff(pos: Vector3, rad: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 1.75
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

# --- 6. Handcrafted Diorama Scene Assembly (Exact 151bb106.png Composition + vC7OEC Lushness!) ---
func _build_diorama_scene() -> void:
	# 6a. Central Campfire (Crossed charred logs + layered gouache flame + soft billowing translucent smoke)
	for ang_d in [-28.0, 36.0, 102.0, 158.0]:
		var r := deg_to_rad(ang_d)
		_place_glb(self, "charred_log.glb", CAMPFIRE_XZ + Vector2(cos(r), sin(r)) * 0.28, 0.92, Vector3(0, ang_d, 0), Color("#6e4434"), 0.15, -0.04, 0.92)

	var fy := terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y)
	campfire_flame = Node3D.new()
	campfire_flame.position = Vector3(CAMPFIRE_XZ.x, fy + 0.16, CAMPFIRE_XZ.y)
	add_child(campfire_flame)
	for fp in [
		[Vector3(0.0, 0.34, 0.0), 0.34, 0.76, Color("#ff8a2b")],
		[Vector3(0.10, 0.26, 0.05), 0.22, 0.56, Color("#ffce45")],
		[Vector3(-0.08, 0.22, -0.04), 0.18, 0.45, Color("#fff3a8")]
	]:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = float(fp[1])
		cm.height = float(fp[2])
		var fi := MeshInstance3D.new()
		fi.mesh = cm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = fp[3]
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fi.material_override = fmat
		fi.position = fp[0]
		campfire_flame.add_child(fi)

	for i in range(7):
		var sp := _soft_cloud_puff(Vector3(CAMPFIRE_XZ.x, fy + 0.8, CAMPFIRE_XZ.y), 0.30, Color(0.84, 0.88, 0.96, 0.34))
		campfire_smoke.append({"node": sp, "offset": float(i) / 7.0})

	# 6b. Hero Campfire Props (Red diamond rug, open journal on log bench, leather backpack, bedroll)
	_place_glb(self, "campfire_rug.glb", Vector2(2.05, 1.35), 2.35, Vector3(0, -14, 0), Color("#b5433a"), 0.22, 0.02, 1.04)
	_place_glb(self, "journal_log.glb", Vector2(2.65, -0.35), 1.95, Vector3(0, 6, 0), Color("#94623f"), 0.12, -0.05, 0.98)
	_place_glb(self, "journal.glb", Vector2(2.58, -0.35), 0.92, Vector3(0, -12, 0), Color("#f5ebd6"), 0.08, 0.48, 1.08)
	_place_glb(self, "backpack.glb", Vector2(3.85, -0.42), 1.32, Vector3(0, -24, 0), Color("#9c633b"), 0.12, -0.02, 1.00)
	_place_glb(self, "bedroll.glb", Vector2(3.45, 0.72), 1.05, Vector3(0, 32, 0), Color("#a8433b"), 0.18, -0.02, 0.98)

	# 6c. Left of Campfire: Sitting Log + Clockwork Grunt roasting Grilled Fish on skewer!
	_place_glb(self, "sit_log.glb", Vector2(-2.25, 0.35), 1.62, Vector3(0, 18, 0), Color("#855537"), 0.12, -0.06, 0.96)
	var grunt_root := _place_glb(self, "clockwork_grunt.glb", Vector2(-2.15, 0.32), 1.48, Vector3(0, 74, 0), Color("#c95a38"), 0.14, 0.18, 1.05)
	_place_glb(grunt_root, "grunt_helmet.glb", Vector2(0.0, 0.0), 0.74, Vector3(0, 0, 0), Color("#7d92b0"), 0.12, 1.24, 1.05, false)
	# Animated brass wind-up key on back
	grunt_key = Node3D.new()
	grunt_key.position = Vector3(0.0, 0.68, -0.38)
	grunt_root.add_child(grunt_key)
	var kmat := StandardMaterial3D.new()
	kmat.albedo_color = Color("#e3b549")
	kmat.roughness = 0.45
	var k_rod := MeshInstance3D.new()
	var kcm := CylinderMesh.new(); kcm.top_radius = 0.035; kcm.bottom_radius = 0.035; kcm.height = 0.30
	k_rod.mesh = kcm; k_rod.material_override = kmat; k_rod.rotation_degrees.x = 90.0; k_rod.position = Vector3(0, 0, -0.14)
	grunt_key.add_child(k_rod)
	for kp in [Vector3(-0.15, 0.11, -0.26), Vector3(0.15, -0.11, -0.26)]:
		var kr := MeshInstance3D.new()
		var ksm := SphereMesh.new(); ksm.radius = 0.12; ksm.height = 0.24
		kr.mesh = ksm; kr.material_override = kmat; kr.scale = Vector3(1.0, 1.0, 0.35); kr.position = kp
		grunt_key.add_child(kr)
	# Roasting skewer + grilled_fish.glb held toward the campfire!
	var sk := MeshInstance3D.new()
	var skm := CylinderMesh.new(); skm.top_radius = 0.018; skm.bottom_radius = 0.022; skm.height = 0.92
	sk.mesh = skm; sk.rotation_degrees.x = 76.0; sk.position = Vector3(0.28, 0.62, 0.68)
	grunt_root.add_child(sk)
	_place_glb(grunt_root, "grilled_fish.glb", Vector2(0.28, 1.10), 0.56, Vector3(0, 88, 0), Color("#9fb8cf"), 0.15, 0.66, 1.08, false)

	# 6d. Curled Giant Wolf & Fat Yellow Bird beside Campfire (warm storybook centerpiece!)
	wolf_node = Node3D.new()
	wolf_node.position = Vector3(0.35, terrain_height(0.35, -1.25), -1.25)
	wolf_node.rotation_degrees.y = 18.0
	add_child(wolf_node)
	var fur_d := StandardMaterial3D.new(); fur_d.albedo_color = Color("#3a394a"); fur_d.roughness = 0.95
	var fur_w := StandardMaterial3D.new(); fur_w.albedo_color = Color("#7a685e"); fur_w.roughness = 0.95
	for wp in [
		[Vector3(0.0, 0.55, 0.0), Vector3(1.65, 0.82, 1.45), fur_d],
		[Vector3(-0.78, 0.52, 0.55), Vector3(0.95, 0.62, 0.85), fur_w],
		[Vector3(-0.75, 0.95, 0.72), Vector3(0.76, 0.64, 0.88), fur_d],
		[Vector3(-0.82, 0.78, 1.15), Vector3(0.36, 0.28, 0.52), fur_w],
		[Vector3(0.72, 0.42, 0.68), Vector3(0.62, 0.42, 1.15), fur_d]
	]:
		var wm := MeshInstance3D.new()
		var ws := SphereMesh.new(); ws.radius = 0.5; ws.height = 1.0
		wm.mesh = ws; wm.scale = wp[1]; wm.position = wp[0]; wm.material_override = wp[2]
		wolf_node.add_child(wm)
	for ex in [-0.95, -0.55]:
		var ear := MeshInstance3D.new()
		var ec := CylinderMesh.new(); ec.top_radius = 0.03; ec.bottom_radius = 0.16; ec.height = 0.42
		ear.mesh = ec; ear.position = Vector3(ex, 1.38, 0.68); ear.material_override = fur_d
		wolf_node.add_child(ear)

	bird_node = Node3D.new()
	bird_node.position = Vector3(1.18, terrain_height(1.18, -0.82) + 0.32, -0.82)
	add_child(bird_node)
	var b_mat := StandardMaterial3D.new(); b_mat.albedo_color = Color("#ffbf3c"); b_mat.roughness = 0.9
	var bm := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.20; bs.height = 0.36
	bm.mesh = bs; bm.material_override = b_mat; bird_node.add_child(bm)
	var beak := MeshInstance3D.new(); var bkm := BoxMesh.new(); bkm.size = Vector3(0.08, 0.06, 0.10)
	var bkmat := StandardMaterial3D.new(); bkmat.albedo_color = Color("#e8632c")
	beak.mesh = bkm; beak.material_override = bkmat; beak.position = Vector3(0, 0.02, 0.20); bird_node.add_child(beak)

	# 6e. Upper-Left Standing Stones & Mossy Stone Golem on Raised Knoll!
	for ss in [
		[Vector2(-9.2, -7.2), 1.85, 16.0],
		[Vector2(-8.3, -9.1), 2.45, 8.0],
		[Vector2(-6.8, -9.9), 3.25, -4.0],
		[Vector2(-5.0, -9.0), 2.50, -14.0],
		[Vector2(-4.4, -7.3), 1.78, -20.0]
	]:
		var sp2: Vector2 = ss[0]
		var sz: float = ss[1]
		_place_glb(self, "standing_stone.glb", sp2, sz, Vector3(0, float(ss[2]), 0), Color("#8594b8"), 0.22, -0.12, 1.02)
		var orb := MeshInstance3D.new()
		var os := SphereMesh.new(); os.radius = 0.11; os.height = 0.22
		var omat := StandardMaterial3D.new(); omat.albedo_color = Color("#ffcf5c"); omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orb.mesh = os; orb.material_override = omat
		orb.position = Vector3(sp2.x, terrain_height(sp2.x, sp2.y) + sz * 0.58, sp2.y + 0.36)
		add_child(orb)

	golem_node = _place_glb(self, "golem.glb", Vector2(-6.9, -7.8), 1.85, Vector3(0, 14, 0), Color("#a8ba98"), 0.10, -0.05, 1.06)

	# 6f. Mid-Left Mossy Skull Cave embedded into the hillside!
	_place_glb(self, "skull_cave.glb", Vector2(-8.5, -3.5), 5.4, Vector3(0, 26, 0), Color("#8fa382"), 0.12, -0.35, 1.02)

	# 6g. Lower-Left Waterfall Rocks + Fishing Pier extending OVER the real recessed lake!
	_place_glb(self, "waterfall_rock.glb", Vector2(-10.1, 3.8), 3.2, Vector3(0, 22, 0), Color("#6d7da3"), 0.24, -0.45, 0.98)
	_place_glb(self, "waterfall_rock.glb", Vector2(-7.0, 4.3), 2.3, Vector3(0, -32, 0), Color("#6d7da3"), 0.24, -0.35, 0.98)

	# Pier sits right at the water edge extending over the lake!
	var pier_y := WATER_LEVEL + 0.12
	_place_glb(self, "pier.glb", Vector2(-2.7, 5.15), 3.3, Vector3(0, -6, 0), Color("#b07246"), 0.12, pier_y, 1.00, false)
	_place_glb(self, "bucket.glb", Vector2(-2.25, 5.10), 0.68, Vector3(0, 18, 0), Color("#8ea5bd"), 0.12, pier_y + 0.56, 1.04, false)
	_place_glb(self, "fishing_rod.glb", Vector2(-1.65, 5.15), 2.25, Vector3(14, -22, -24), Color("#b87442"), 0.12, pier_y + 0.45, 1.02, false)
	# Dangling white fishing line + red-white bobber floating on the lake!
	var line_m := MeshInstance3D.new()
	var lcm := CylinderMesh.new(); lcm.top_radius = 0.010; lcm.bottom_radius = 0.010; lcm.height = 1.48
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color("#e8f0ff"); lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_m.mesh = lcm; line_m.material_override = lmat; line_m.position = Vector3(-1.35, WATER_LEVEL + 0.78, 5.85)
	add_child(line_m)
	fishing_bobber = Node3D.new()
	fishing_bobber.position = Vector3(-1.35, WATER_LEVEL + 0.04, 5.85)
	add_child(fishing_bobber)
	var b_red := MeshInstance3D.new(); var brs := SphereMesh.new(); brs.radius = 0.14; brs.height = 0.28
	var brm := StandardMaterial3D.new(); brm.albedo_color = Color("#e84c3d"); brm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_red.mesh = brs; b_red.material_override = brm; fishing_bobber.add_child(b_red)
	var b_wht := MeshInstance3D.new(); var bws := SphereMesh.new(); bws.radius = 0.135; bws.height = 0.15
	var bwm := StandardMaterial3D.new(); bwm.albedo_color = Color("#fff8ed"); bwm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_wht.mesh = bws; b_wht.material_override = bwm; b_wht.position = Vector3(0, 0.08, 0); fishing_bobber.add_child(b_wht)

	# 6h. Right Wooden Arch Bridge spanning cleanly over the carved river valley!
	_place_glb(self, "bridge.glb", Vector2(8.65, -1.10), 4.65, Vector3(0, 6, 0), Color("#b37447"), 0.12, -0.22, 1.00, false)

	# 6i. Cozy Red-Roof Cabin on the Right Peninsula + Soft Chimney Smoke!
	var cab_xz := Vector2(9.8, 5.1)
	_place_glb(self, "cabin.glb", cab_xz, 4.45, Vector3(0, -24, 0), Color("#c96244"), 0.14, -0.08, 1.02)
	var cab_y := terrain_height(cab_xz.x, cab_xz.y)
	for i in range(6):
		var cp := _soft_cloud_puff(Vector3(10.55, cab_y + 3.4, 4.8), 0.34, Color(0.86, 0.90, 0.97, 0.42))
		cabin_smoke.append({"node": cp, "offset": float(i) / 6.0, "base_y": cab_y + 3.4})

	# 6j. Layered Forest Enclosure (Hero Crimson-Rust Pine + Deep Midnight Indigo Pines + Dense vC7OEC Framing!)
	# Center-Back Hero Autumn Crimson Pine (rich muted rust-red, NOT neon!)
	_place_glb(self, "pine_tree.glb", Vector2(0.85, -8.4), 6.2, Vector3(0, 12, 0), Color("#a83b32"), 0.58, -0.15, 1.02)
	# Deep Velvety Midnight Indigo & Twilight Teal Pines ringing the clearing
	for tp in [
		[Vector2(-12.2, -7.4), 6.6, 22.0, Color("#1f356e")],
		[Vector2(-14.6, -2.2), 5.8, -14.0, Color("#1b2e5e")],
		[Vector2(-13.8, 2.8), 5.4, 34.0, Color("#1f3866")],
		[Vector2(-9.6, -12.2), 5.8, 10.0, Color("#1a2c59")],
		[Vector2(-3.8, -12.0), 5.5, -24.0, Color("#1f3b66")],
		[Vector2(4.4, -11.8), 5.6, 18.0, Color("#1d3266")],
		[Vector2(6.6, -8.6), 6.0, -18.0, Color("#203973")],
		[Vector2(13.2, -6.2), 5.8, 28.0, Color("#1c3366")],
		[Vector2(14.8, -0.2), 5.5, -10.0, Color("#1f3b69")],
		[Vector2(13.4, 3.2), 6.2, -16.0, Color("#1b3063")],
		[Vector2(14.6, 7.6), 5.4, 24.0, Color("#182b57")],
		[Vector2(-13.6, 8.2), 5.2, -20.0, Color("#182a54")]
	]:
		_place_glb(self, "pine_tree.glb", tp[0], float(tp[1]), Vector3(0, float(tp[2]), 0), tp[3], 0.56, -0.18, 0.98)

	# Background Forest Trunk Silhouettes (bg_trunk.glb) + Stone Archway (stone_arch.glb)
	for bx in [-11.5, -6.2, -2.0, 3.2, 8.8, 12.8]:
		_place_glb(self, "bg_trunk.glb", Vector2(float(bx), -13.8), 4.8, Vector3(0, float(bx) * 23.0, 0), Color("#18264d"), 0.58, -0.15, 0.90)
	_place_glb(self, "stone_arch.glb", Vector2(-14.8, -4.8), 3.9, Vector3(0, 68, 0), Color("#7a8aad"), 0.22, -0.15, 0.98)

	# Foreground & Shoreline Plum-Violet & Deep-Indigo Foliage (151bb106.png signature framing!)
	for sh in [
		["palm_bush.glb", Vector2(-11.4, -1.8), 1.85, 18.0, Color("#5e3263")],
		["palm_bush.glb", Vector2(-10.2, 0.8), 1.55, -24.0, Color("#663661")],
		["palm_bush.glb", Vector2(3.8, -6.4), 1.75, 14.0, Color("#543166")],
		["palm_bush.glb", Vector2(4.6, 3.6), 1.75, -16.0, Color("#613566")],
		["lush_shrub.glb", Vector2(-11.8, 6.8), 3.0, 20.0, Color("#1e3163")],
		["lush_shrub.glb", Vector2(-9.6, 7.6), 2.4, -18.0, Color("#59305e")],
		["lush_shrub.glb", Vector2(12.0, 7.8), 2.9, -28.0, Color("#1d2f5e")],
		["lush_shrub.glb", Vector2(13.4, 6.6), 2.4, 16.0, Color("#5c315c")]
	]:
		_place_glb(self, String(sh[0]), sh[1], float(sh[2]), Vector3(0, float(sh[3]), 0), sh[4], 0.56, -0.10, 0.98)

	# Scattered White & Blue Bobble Wildflowers & Mossy Shoreline Rocks
	for wf in [
		Vector2(-4.4, -5.8), Vector2(-2.8, -5.4), Vector2(4.6, -5.0),
		Vector2(6.0, -4.4), Vector2(-5.4, 2.8), Vector2(-4.0, 3.4),
		Vector2(3.2, 2.9), Vector2(11.4, -5.2), Vector2(-9.8, -5.4)
	]:
		_place_glb(self, "wildflowers.glb", wf, 1.15, Vector3(0, wf.x * 41.0, 0), Color.WHITE, 0.0, -0.04, 1.18)

	for sr in [
		[Vector2(-6.2, -1.4), 1.25], [Vector2(6.6, 1.8), 1.35],
		[Vector2(10.6, 1.0), 1.18], [Vector2(11.8, -4.0), 1.22],
		[Vector2(7.6, 6.2), 1.28], [Vector2(-0.8, 4.5), 1.05],
		[Vector2(6.2, 4.2), 1.15]
	]:
		var s_xz: Vector2 = sr[0]
		_place_glb(self, "shore_rock.glb", s_xz, float(sr[1]), Vector3(0, s_xz.x * 31.0, 0), Color("#7d8eb5"), 0.18, -0.14, 0.98)

	# 6k. Tasteful Interactive Shatterable Props (RigidBody3D Physics Shards + Pixel Sparks + Smooth Scorch!)
	var wood_cols := [Color("#7a4a2e"), Color("#b57c4b"), Color("#452b1e"), Color("#d99848")]
	var rock_cols := [Color("#6e7c9c"), Color("#99a8c7"), Color("#4c7545"), Color("#4d5873")]
	for sp in [
		["stump.glb", Vector2(-3.9, 2.1), 1.08, wood_cols],
		["stump.glb", Vector2(5.4, 2.0), 1.05, wood_cols],
		["stump.glb", Vector2(4.6, -3.5), 1.02, wood_cols],
		["shore_rock.glb", Vector2(-4.5, -3.8), 1.15, rock_cols],
		["shore_rock.glb", Vector2(12.0, 1.2), 1.12, rock_cols]
	]:
		var pxz: Vector2 = sp[1]
		var p_node := _place_glb(self, String(sp[0]), pxz, float(sp[2]), Vector3(0, randf() * 360.0, 0), Color.WHITE, 0.0, -0.04, 1.00)
		ink_fx.register_shatter_prop(p_node, p_node.position, 0.95, sp[3], 3, 1)

	# 6l. Soft Diagonal Volumetric God Rays (vC7OEC signature!)
	for gr in [
		[Vector3(-5.8, 6.2, -3.5), 3.4, 15.0],
		[Vector3(-1.2, 6.8, -2.0), 4.0, 16.0],
		[Vector3(4.2, 6.4, -2.8), 3.6, 15.5],
		[Vector3(8.8, 6.2, 1.5), 3.2, 14.5]
	]:
		var qm := QuadMesh.new()
		qm.size = Vector2(float(gr[1]), float(gr[2]))
		var gi := MeshInstance3D.new()
		gi.mesh = qm
		var gmat := ShaderMaterial.new()
		gmat.shader = SHADER_GODRAY
		gi.material_override = gmat
		godray_mats.append(gmat)
		gi.position = gr[0]
		gi.rotation_degrees = Vector3(14.0, -18.0, 26.0)
		add_child(gi)

	# 6m. Gentle Floating Golden Fireflies (soft glowing specks drifting over clearing & lake)
	for _i in range(22):
		var fx := randf_range(-11.0, 11.0)
		var fz := randf_range(-8.0, 6.5)
		var fy_base := maxf(WATER_LEVEL + 0.6, terrain_height(fx, fz) + randf_range(0.6, 2.4))
		var fm := _soft_cloud_puff(Vector3(fx, fy_base, fz), 0.055, Color("#ffe38a"))
		fireflies.append({"node": fm, "base": fm.position, "ph": randf() * TAU, "spd": randf_range(0.8, 1.7)})

# --- 7. Playable Traveler (C01 GLB) & vC7OEC-Style Perspective Oblique / Orbit Camera ---
func _setup_player_and_camera() -> void:
	player = Node3D.new()
	player.position = Vector3(1.1, terrain_height(1.1, -0.35), -0.35)
	add_child(player)
	player_visual = Node3D.new()
	player.add_child(player_visual)
	_place_glb(player_visual, "traveler_c01.glb", Vector2.ZERO, 1.18, Vector3.ZERO, Color.WHITE, 0.0, 0.0, 1.08, false)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 28.0
	camera.near = 0.5
	camera.far = 160.0
	camera.current = true
	add_child(camera)
	_update_camera(1.0)

func _update_camera(lerp_w: float) -> void:
	var target: Vector3
	var desired: Vector3
	if orbit_camera:
		target = Vector3(0.0, 0.4, -0.4)
		var radius := 24.5
		desired = target + Vector3(sin(orbit_angle) * radius, 15.8, cos(orbit_angle) * radius)
	else:
		# Classic 151bb106.png Diorama Framing gently following the traveler
		target = player.position.lerp(Vector3(0.2, 0.35, -0.6), 0.48)
		desired = target + Vector3(0.0, 14.2, 20.5)
	camera.position = camera.position.lerp(desired, lerp_w) if lerp_w < 1.0 else desired
	camera.look_at(target)

# --- 8. Ultra-Clean Minimalist UI (Zero Screen Clutter!) ---
func _setup_minimal_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	hint_panel = PanelContainer.new()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_panel.offset_left = 18
	hint_panel.offset_bottom = -16
	hint_panel.offset_top = -52
	hint_panel.offset_right = 680
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.20, 0.68)
	sb.border_color = Color(0.95, 0.78, 0.42, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	hint_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(hint_panel)

	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("#f2ebd9"))
	hint_panel.add_child(hint_label)
	_refresh_hint()

	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -260
	toast_label.offset_right = 260
	toast_label.offset_top = 20
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
				_show_toast("🌙 切換為深夜營火氛圍（151bb106）" if is_night else "☀️ 切換為日光微縮森林（vC7OEC）", 2.8)
				_refresh_hint()
			KEY_R:
				orbit_camera = not orbit_camera
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

func _perform_swing() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = 0.28
	PrologueState.play_sfx("slash")
	var tw := create_tween()
	tw.tween_property(player_visual, "rotation:y", player_visual.rotation.y + TAU, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if ink_fx:
		ink_fx.try_hit_shatter_props(player.position, 2.8, self)
		ink_fx.paint_scorch(player.position, 1.35, 0.24)
		ink_fx.spawn_pixel_burst(player.position + Vector3(0, 0.5, 0), [Color("#ff9c42"), Color("#ffe38a"), Color("#ffffff")], 10, 0.75)

func flash_hit(node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var orig := node.scale
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(orig.x * 1.18, orig.y * 0.84, orig.z * 1.18), 0.06)
	tw.tween_property(node, "scale", orig, 0.12)

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	attack_cd = maxf(0.0, attack_cd - delta)
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0 and toast_label:
			toast_label.hide()

	# Character WASD movement smoothly hugging the 3D sculpted terrain (stops gently at deep water)
	var h_in := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v_in := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := Vector3(camera.transform.basis.x.x, 0.0, camera.transform.basis.x.z).normalized()
	var fwd := Vector3(camera.transform.basis.z.x, 0.0, camera.transform.basis.z.z).normalized()
	var move_dir := (right * h_in + fwd * v_in).limit_length()
	var moving := move_dir.length() > 0.05
	if moving:
		var cand_x := clampf(player.position.x + move_dir.x * 5.2 * delta, -16.5, 16.5)
		var cand_z := clampf(player.position.z + move_dir.z * 5.2 * delta, -12.5, 9.5)
		var cand_y := terrain_height(cand_x, cand_z)
		# Allow walking on dry land, shallow bank, or cleanly across the wooden bridge!
		var on_bridge := absf(cand_z + 1.10) < 1.35 and cand_x > 6.2 and cand_x < 11.2
		if on_bridge:
			player.position = Vector3(cand_x, maxf(cand_y, 0.28), cand_z)
		elif cand_y > WATER_LEVEL - 0.12:
			player.position = Vector3(cand_x, cand_y, cand_z)
		player_yaw = atan2(move_dir.x, move_dir.z)
		player_visual.rotation.y = lerp_angle(player_visual.rotation.y, player_yaw, clampf(delta * 12.0, 0.0, 1.0))
		_walk_phase += delta * 12.0
		player_visual.position.y = absf(sin(_walk_phase)) * 0.10
	else:
		player_visual.position.y = lerpf(player_visual.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))

	if orbit_camera:
		orbit_angle += delta * 0.28
	_update_camera(clampf(delta * 4.5, 0.0, 1.0))

	# Living Campfire, Soft Billowing Smoke, Waterfall Foam, Bobber, Clockwork Key, Golem & Fireflies
	if campfire_flame:
		campfire_flame.scale = Vector3(1.0 + sin(t * 8.5) * 0.06, 0.94 + sin(t * 12.5) * 0.14, 1.0 + cos(t * 9.5) * 0.06)
	if campfire_light:
		var base_e := 3.2 if is_night else 1.1
		campfire_light.light_energy = base_e + sin(t * 10.5) * 0.28

	var fy := terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y)
	for rec in campfire_smoke:
		var sn: MeshInstance3D = rec["node"]
		var cyc := fmod(t * 0.30 + float(rec["offset"]), 1.0)
		sn.position = Vector3(CAMPFIRE_XZ.x + sin(cyc * TAU) * 0.32 + cyc * 0.65, fy + 0.85 + cyc * 3.4, CAMPFIRE_XZ.y - cyc * 0.25)
		var sc := 0.55 + cyc * 1.45
		sn.scale = Vector3(sc, sc * 1.1, sc)
		(sn.material_override as StandardMaterial3D).albedo_color.a = sin(cyc * PI) * 0.32

	for rec in cabin_smoke:
		var cn: MeshInstance3D = rec["node"]
		var cyc := fmod(t * 0.28 + float(rec["offset"]), 1.0)
		cn.position = Vector3(10.45 + cyc * 1.25, float(rec["base_y"]) + cyc * 2.4, 4.75 + sin(cyc * PI) * 0.25)
		var sc := 0.65 + cyc * 1.55
		cn.scale = Vector3(sc, sc * 0.95, sc)
		(cn.material_override as StandardMaterial3D).albedo_color.a = sin(cyc * PI) * 0.42

	for rec in waterfall_foam:
		var fn: Node3D = rec["node"]
		var bp: Vector3 = rec["base"]
		var ph := float(rec["ph"])
		var s := 0.82 + sin(t * 4.2 + ph) * 0.22
		fn.scale = Vector3(s, s * 0.85, s)
		fn.position.y = bp.y + sin(t * 5.0 + ph) * 0.06

	if fishing_bobber:
		fishing_bobber.position.y = WATER_LEVEL + 0.04 + sin(t * 3.0) * 0.05
	if grunt_key:
		grunt_key.rotation.z += delta * 1.8
	if golem_node:
		golem_node.position.y = terrain_height(-6.9, -7.8) - 0.05 + absf(sin(t * 2.2)) * 0.06
	if bird_node:
		bird_node.position.y = terrain_height(1.18, -0.82) + 0.32 + absf(sin(t * 3.4)) * 0.05

	for rec in fireflies:
		var fl: Node3D = rec["node"]
		var bp: Vector3 = rec["base"]
		var ph := float(rec["ph"])
		var sp := float(rec["spd"])
		fl.position = bp + Vector3(sin(t * sp + ph) * 0.65, sin(t * sp * 1.3 + ph) * 0.35, cos(t * sp * 0.8 + ph) * 0.65)
		fl.visible = is_night

	if ink_fx:
		ink_fx.step(delta, player.position, moving)

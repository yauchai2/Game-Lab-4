extends Node3D

# Handcrafted 3D Lakeside Campfire Diorama (Refined Visual Edition)
# Atmosphere: ChatGPT Night Campfire Reference (06_29_51.png) — luminous sage-teal grass, cobalt-indigo pines, warm honey campfire
# Diorama Tech: vC7OEC.mp4 — 96x96 3D terrain, recessed water w/ auto shore foam, vertical gradient props, contact shadows, god rays
# Interactive FX: Smooth Bilinear Persistent Surface State (Scorch/Snow/Wetness) + RigidBody3D Shatter Physics

const SHADER_TERRAIN := preload("res://diorama/shaders/diorama_terrain.gdshader")
const SHADER_WATER := preload("res://diorama/shaders/diorama_water.gdshader")
const SHADER_WATERFALL := preload("res://diorama/shaders/diorama_waterfall.gdshader")
const SHADER_PROP := preload("res://diorama/shaders/diorama_prop.gdshader")
const SHADER_GODRAY := preload("res://diorama/shaders/diorama_godray.gdshader")
const SHADER_CONTACT := preload("res://diorama/shaders/diorama_contact_shadow.gdshader")
const INK_FX_SCRIPT := preload("res://prologue/InkStudioFX.gd")
const MODEL_DIR := "res://assets/models/campfire/"

const MAP_MIN := Vector2(-24.0, -18.0)
const MAP_SIZE := Vector2(48.0, 36.0)
const WATER_LEVEL := -0.58
const CAMPFIRE_XZ := Vector2(0.0, 0.2)

var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var contact_mat: ShaderMaterial
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
var campfire_smoke_ribbon: MeshInstance3D
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

# --- 1. Analytical 3D Sculpted Diorama Heightfield ---
func _river_center_x(z: float) -> float:
	return 8.4 + sin((z + 1.2) * 0.24) * 1.30 - (z + 1.8) * 0.24

func _lake_shore_z(x: float) -> float:
	var base := 4.25 + sin(x * 0.26) * 0.68 + cos(x * 0.14) * 0.42
	if x > 5.4:
		base += smoothstep(5.4, 10.2, x) * 2.95
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
		Vector2(-7.8, -2.5), Vector2(-4.8, -0.9), Vector2(-2.2, 0.4),
		Vector2(0.0, 0.2), Vector2(2.8, -0.3), Vector2(5.8, -1.1),
		Vector2(8.6, -1.1), Vector2(12.2, -1.4), Vector2(16.5, -1.2)
	]
	var min_d := 999.0
	for i in range(pts.size() - 1):
		min_d = minf(min_d, _dist_to_segment(p, pts[i], pts[i + 1]))
	return smoothstep(1.30, 0.42, min_d)

func terrain_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := 0.12 + sin(x * 0.16) * 0.11 + cos(z * 0.18) * 0.09

	# Upper-left Standing Stones & Golem Hill
	h += smoothstep(6.2, 1.2, p.distance_to(Vector2(-7.0, -7.8))) * 1.75
	# Mid-left Skull Cave Slope
	h += smoothstep(5.5, 1.4, p.distance_to(Vector2(-8.6, -3.4))) * 1.45
	# Lower-left Waterfall Cliff Ledge
	h += smoothstep(4.2, 1.1, p.distance_to(Vector2(-10.2, 3.2))) * 1.55

	# Northern & Side Forest Ridges
	if z < -8.5:
		h += smoothstep(-8.5, -16.0, z) * 2.1
	if x < -12.0:
		h += smoothstep(-12.0, -20.0, x) * 1.6
	if x > 13.5:
		h += smoothstep(13.5, 20.0, x) * 1.4

	# Central Campfire Clearing
	h = lerpf(h, 0.14, smoothstep(5.2, 1.8, p.distance_to(CAMPFIRE_XZ)) * 0.85)
	# Right Cabin Peninsula
	h = lerpf(h, 0.40, smoothstep(4.2, 1.5, p.distance_to(Vector2(9.2, 4.4))) * 0.84)

	# Carved Right River Valley
	var rx := _river_center_x(z)
	var d_river := absf(x - rx)
	var river_w := 2.30 if z < 4.5 else 3.1
	h = lerpf(h, -1.42, smoothstep(river_w + 1.35, river_w * 0.45, d_river))

	# Carved Deep Southern Lake Basin
	var shore_z := _lake_shore_z(x)
	var lake_cut := smoothstep(shore_z - 1.25, shore_z + 1.35, z)
	if x < -7.0 and z < 4.8:
		lake_cut *= smoothstep(3.6, 4.9, z)
	h = lerpf(h, -1.68, lake_cut)
	return h

func _ready() -> void:
	contact_mat = ShaderMaterial.new()
	contact_mat.shader = SHADER_CONTACT

	ink_fx = INK_FX_SCRIPT.new()
	add_child(ink_fx)
	var state_tex: ImageTexture = ink_fx.setup(Vector3(CAMPFIRE_XZ.x, terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y), CAMPFIRE_XZ.y))
	ink_fx.state_img.fill(Color(0.0, 0.0, 0.0, 1.0))
	ink_fx.paint_scorch(Vector3(CAMPFIRE_XZ.x, 0.0, CAMPFIRE_XZ.y), 0.95, 0.38)
	ink_fx.state_tex.update(ink_fx.state_img)

	_setup_environment_and_lights()
	var height_tex := _build_sculpted_terrain(state_tex)
	_build_water_and_waterfall(height_tex)
	_build_diorama_scene()
	_setup_player_and_camera()
	_setup_minimal_ui()
	_apply_time_of_day(true)

# --- 2. Luminous Night-vs-Day Filmic Lighting (ZERO Pitch-Black Crush!) ---
func _setup_environment_and_lights() -> void:
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Filmic tonemapping keeps night indigos & sage greens luminous like gouache!
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.08
	env.fog_enabled = true
	env.fog_density = 0.0055

	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-46.0, -32.0, 0.0)
	key_light.shadow_enabled = true
	key_light.shadow_blur = 2.8
	key_light.shadow_bias = 0.03
	add_child(key_light)

	# Focused warm honey campfire glow (warms center without turning bridge/cabin neon!)
	campfire_light = OmniLight3D.new()
	campfire_light.light_color = Color("#ffa84c")
	campfire_light.light_energy = 2.45
	campfire_light.omni_range = 9.2
	campfire_light.omni_attenuation = 1.55
	campfire_light.shadow_enabled = true
	campfire_light.shadow_blur = 2.5
	campfire_light.position = Vector3(CAMPFIRE_XZ.x, terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y) + 1.35, CAMPFIRE_XZ.y)
	add_child(campfire_light)

	cabin_light = OmniLight3D.new()
	cabin_light.light_color = Color("#ffc466")
	cabin_light.light_energy = 1.65
	cabin_light.omni_range = 5.2
	cabin_light.position = Vector3(8.5, terrain_height(8.5, 5.2) + 1.25, 5.2)
	add_child(cabin_light)

func _apply_time_of_day(night: bool) -> void:
	is_night = night
	if night:
		# Exact 06_29_51.png Luminous Night Palette (Rich Cobalt Sky + Sage-Teal Meadow + Warm Honey Fire!)
		sky_mat.sky_top_color = Color("#122254")
		sky_mat.sky_horizon_color = Color("#243d7d")
		sky_mat.ground_bottom_color = Color("#182c5c")
		sky_mat.ground_horizon_color = Color("#243d7d")
		env.ambient_light_color = Color("#6e88cc")
		env.ambient_light_energy = 0.88
		env.fog_light_color = Color("#1e3470")
		key_light.light_color = Color("#b8d2ff")
		key_light.light_energy = 0.78
		campfire_light.light_energy = 2.45
		cabin_light.light_energy = 1.65
		if terrain_mat:
			terrain_mat.set_shader_parameter("grass_deep", Color("#2b4b4c"))
			terrain_mat.set_shader_parameter("grass_mid", Color("#3d634f"))
			terrain_mat.set_shader_parameter("grass_hill", Color("#567c52"))
			terrain_mat.set_shader_parameter("trail_col", Color("#e0b27c"))
			terrain_mat.set_shader_parameter("campfire_dirt", Color("#e8a84a"))
			terrain_mat.set_shader_parameter("cliff_rock", Color("#475275"))
			terrain_mat.set_shader_parameter("night_mix", 1.0)
		if water_mat:
			water_mat.set_shader_parameter("deep_color", Color("#1b52a6"))
			water_mat.set_shader_parameter("shallow_color", Color("#388ce6"))
		for gm in godray_mats:
			gm.set_shader_parameter("ray_color", Color(0.62, 0.80, 1.0, 0.14))
		for pm in prop_mats:
			pm.set_shader_parameter("ambient_lift", 0.17)
	else:
		# Exact vC7OEC.mp4 Sunlit Emerald Miniature Forest!
		sky_mat.sky_top_color = Color("#5caaf2")
		sky_mat.sky_horizon_color = Color("#c4e6ff")
		sky_mat.ground_bottom_color = Color("#508c55")
		sky_mat.ground_horizon_color = Color("#c4e6ff")
		env.ambient_light_color = Color("#9cc4d4")
		env.ambient_light_energy = 0.78
		env.fog_light_color = Color("#a8d8eb")
		key_light.light_color = Color("#fff3cf")
		key_light.light_energy = 1.25
		campfire_light.light_energy = 0.85
		cabin_light.light_energy = 0.45
		if terrain_mat:
			terrain_mat.set_shader_parameter("grass_deep", Color("#3d7841"))
			terrain_mat.set_shader_parameter("grass_mid", Color("#5ea148"))
			terrain_mat.set_shader_parameter("grass_hill", Color("#80bd57"))
			terrain_mat.set_shader_parameter("trail_col", Color("#d9b480"))
			terrain_mat.set_shader_parameter("campfire_dirt", Color("#d4a462"))
			terrain_mat.set_shader_parameter("cliff_rock", Color("#7d8599"))
			terrain_mat.set_shader_parameter("night_mix", 0.0)
		if water_mat:
			water_mat.set_shader_parameter("deep_color", Color("#1e6cc9"))
			water_mat.set_shader_parameter("shallow_color", Color("#42aef5"))
		for gm in godray_mats:
			gm.set_shader_parameter("ray_color", Color(1.0, 0.94, 0.66, 0.22))
		for pm in prop_mats:
			pm.set_shader_parameter("ambient_lift", 0.08)

# --- 3. 96x96 Sculpted 3D Terrain Mesh + Heightmap Texture ---
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
			var fire_w := smoothstep(6.2, 1.5, d_fire) * smoothstep(-0.25, 0.05, y)
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
	terrain_mat.set_shader_parameter("map_min", MAP_MIN)
	terrain_mat.set_shader_parameter("map_size", MAP_SIZE)
	mi.material_override = terrain_mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var col_sh := CollisionShape3D.new()
	col_sh.shape = mesh.create_trimesh_shape()
	body.add_child(col_sh)

	var h_res := 128
	var himg := Image.create_empty(h_res, h_res, false, Image.FORMAT_RF)
	for py in range(h_res):
		var z := MAP_MIN.y + (float(py) / float(h_res - 1)) * MAP_SIZE.y
		for px in range(h_res):
			var x := MAP_MIN.x + (float(px) / float(h_res - 1)) * MAP_SIZE.x
			var norm_h := clampf((terrain_height(x, z) + 2.0) / 6.0, 0.0, 1.0)
			himg.set_pixel(px, py, Color(norm_h, 0.0, 0.0, 1.0))
	return ImageTexture.create_from_image(himg)

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
	water_mat.set_shader_parameter("bobber_pos", Vector3(-1.35, WATER_LEVEL, 5.85))
	water_mat.set_shader_parameter("waterfall_pos", Vector3(-8.5, WATER_LEVEL, 5.10))
	w_inst.material_override = water_mat
	w_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w_inst)

	# Curved waterfall cascading from tucked cliff gap into fluffy foam clouds
	var wf_st := SurfaceTool.new()
	wf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wf_w := 1.75
	var segs := 12
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var y0 := lerpf(1.38, WATER_LEVEL - 0.05, t0 * t0)
		var y1 := lerpf(1.38, WATER_LEVEL - 0.05, t1 * t1)
		var z0 := lerpf(3.75, 5.05, t0)
		var z1 := lerpf(3.75, 5.05, t1)
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
	wf_mi.position = Vector3(-8.5, 0.0, 0.0)
	wf_mi.rotation_degrees.y = 12.0
	add_child(wf_mi)

	# 10 Fluffy Matte-White Splash Clouds hugging the waterfall base (06_29_51.png style!)
	for i in range(10):
		var ang := (float(i) / 9.0 - 0.5) * 2.2
		var pos := Vector3(-8.5 + ang * 1.05, WATER_LEVEL + 0.14 + (1.0 - absf(ang)) * 0.14, 5.12 + cos(ang) * 0.25)
		var fm := _soft_cloud_puff(pos, randf_range(0.32, 0.56), Color(0.90, 0.97, 1.0, 0.90))
		waterfall_foam.append({"node": fm, "base": pos, "ph": float(i) * 0.9})

# --- 5. GLB Loader with Vertical Gradient, Contact Shadow Decal & Auto Grounding ---
func _apply_prop_shader(node: Node, aabb: AABB, tint_col: Color, tint_mix: float, brightness := 1.08, grad_str := 0.26) -> void:
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
		_apply_prop_shader(c, aabb, tint_col, tint_mix, brightness, grad_str)

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

func _place_glb(parent: Node3D, fname: String, xz: Vector2, target_size: float, rot_deg := Vector3.ZERO, tint := Color.WHITE, tint_mix := 0.0, y_offset := 0.0, brightness := 1.08, use_terrain_y := true, shadow_r := 0.0) -> Node3D:
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
			_apply_prop_shader(inst, aabb, tint, tint_mix, brightness, 0.28)
			holder.add_child(inst)
	if shadow_r > 0.0:
		_add_contact_shadow(holder, shadow_r, 0.04 - y_offset if use_terrain_y else 0.02)
	return holder

func _soft_cloud_puff(pos: Vector3, rad: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 1.7
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

# Graceful S-Curve Storybook Campfire Smoke Ribbon (matches 06_29_51.png!)
func _build_campfire_smoke_ribbon(base_pos: Vector3) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 18
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var x0 := sin(t0 * PI * 1.7) * 0.45 + t0 * 1.35
		var x1 := sin(t1 * PI * 1.7) * 0.45 + t1 * 1.35
		var y0 := t0 * 4.4
		var y1 := t1 * 4.4
		var w0 := lerpf(0.05, 0.22, sin(t0 * PI * 0.85))
		var w1 := lerpf(0.05, 0.22, sin(t1 * PI * 0.85))
		var a0 := sin(t0 * PI) * 0.26
		var a1 := sin(t1 * PI) * 0.26
		var c0 := Color(0.88, 0.91, 0.97, a0)
		var c1 := Color(0.88, 0.91, 0.97, a1)
		st.set_color(c0); st.add_vertex(Vector3(x0 - w0, y0, 0.0))
		st.set_color(c0); st.add_vertex(Vector3(x0 + w0, y0, 0.0))
		st.set_color(c1); st.add_vertex(Vector3(x1 + w1, y1, 0.0))
		st.set_color(c0); st.add_vertex(Vector3(x0 - w0, y0, 0.0))
		st.set_color(c1); st.add_vertex(Vector3(x1 + w1, y1, 0.0))
		st.set_color(c1); st.add_vertex(Vector3(x1 - w1, y1, 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mi.material_override = mat
	mi.position = base_pos
	add_child(mi)
	return mi

# --- 6. Handcrafted Scene Assembly ---
func _build_diorama_scene() -> void:
	# 6a. Central Campfire + S-Curve Storybook Smoke Ribbon
	for ang_d in [-28.0, 36.0, 102.0, 158.0]:
		var r := deg_to_rad(ang_d)
		_place_glb(self, "charred_log.glb", CAMPFIRE_XZ + Vector2(cos(r), sin(r)) * 0.26, 0.90, Vector3(0, ang_d, 0), Color("#734836"), 0.12, -0.04, 1.02)

	var fy := terrain_height(CAMPFIRE_XZ.x, CAMPFIRE_XZ.y)
	campfire_flame = Node3D.new()
	campfire_flame.position = Vector3(CAMPFIRE_XZ.x, fy + 0.16, CAMPFIRE_XZ.y)
	add_child(campfire_flame)
	for fp in [
		[Vector3(0.0, 0.36, 0.0), 0.34, 0.78, Color("#ff8c2b")],
		[Vector3(0.10, 0.26, 0.05), 0.22, 0.56, Color("#ffd447")],
		[Vector3(-0.08, 0.22, -0.04), 0.18, 0.45, Color("#fff5b2")]
	]:
		var cm := CylinderMesh.new(); cm.top_radius = 0.02; cm.bottom_radius = float(fp[1]); cm.height = float(fp[2])
		var fi := MeshInstance3D.new(); fi.mesh = cm
		var fmat := StandardMaterial3D.new(); fmat.albedo_color = fp[3]; fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fi.material_override = fmat; fi.position = fp[0]
		campfire_flame.add_child(fi)

	campfire_smoke_ribbon = _build_campfire_smoke_ribbon(Vector3(CAMPFIRE_XZ.x + 0.1, fy + 0.75, CAMPFIRE_XZ.y - 0.1))

	# 6b. Hero Campfire Props (Red diamond rug, open journal on log bench, leather backpack, bedroll)
	_place_glb(self, "campfire_rug.glb", Vector2(2.05, 1.35), 2.30, Vector3(0, -14, 0), Color("#c24a40"), 0.16, 0.02, 1.08, true, 1.35)
	_place_glb(self, "journal_log.glb", Vector2(2.65, -0.35), 1.90, Vector3(0, 6, 0), Color("#9e6b46"), 0.10, -0.04, 1.05, true, 1.15)
	_place_glb(self, "journal.glb", Vector2(2.58, -0.35), 0.90, Vector3(0, -12, 0), Color("#faf0db"), 0.08, 0.48, 1.12)
	_place_glb(self, "backpack.glb", Vector2(3.85, -0.42), 1.32, Vector3(0, -24, 0), Color("#a86e42"), 0.10, -0.02, 1.08, true, 0.85)
	_place_glb(self, "bedroll.glb", Vector2(3.45, 0.72), 1.05, Vector3(0, 32, 0), Color("#b54b42"), 0.14, -0.02, 1.05, true, 0.65)

	# 6c. Left of Campfire: Sitting Log + Clockwork Grunt FACING THE CAMPFIRE & CAMERA!
	_place_glb(self, "sit_log.glb", Vector2(-2.25, 0.35), 1.62, Vector3(0, 18, 0), Color("#8f5d3d"), 0.10, -0.05, 1.05, true, 1.05)
	# Rotated +52° so his face & roasting skewer point 3/4 toward the campfire & camera!
	var grunt_root := _place_glb(self, "clockwork_grunt.glb", Vector2(-2.15, 0.32), 1.48, Vector3(0, 52, 0), Color("#d46642"), 0.14, 0.18, 1.12)
	_place_glb(grunt_root, "grunt_helmet.glb", Vector2(0.0, 0.0), 0.74, Vector3(0, 0, 0), Color("#869cbd"), 0.10, 1.24, 1.12, false)
	grunt_key = Node3D.new()
	grunt_key.position = Vector3(0.0, 0.68, -0.38)
	grunt_root.add_child(grunt_key)
	var kmat := StandardMaterial3D.new(); kmat.albedo_color = Color("#e8bc4d"); kmat.roughness = 0.45
	var k_rod := MeshInstance3D.new(); var kcm := CylinderMesh.new(); kcm.top_radius = 0.035; kcm.bottom_radius = 0.035; kcm.height = 0.30
	k_rod.mesh = kcm; k_rod.material_override = kmat; k_rod.rotation_degrees.x = 90.0; k_rod.position = Vector3(0, 0, -0.14)
	grunt_key.add_child(k_rod)
	for kp in [Vector3(-0.15, 0.11, -0.26), Vector3(0.15, -0.11, -0.26)]:
		var kr := MeshInstance3D.new(); var ksm := SphereMesh.new(); ksm.radius = 0.12; ksm.height = 0.24
		kr.mesh = ksm; kr.material_override = kmat; kr.scale = Vector3(1.0, 1.0, 0.35); kr.position = kp
		grunt_key.add_child(kr)
	# Roasting skewer + grilled_fish.glb extending forward (+Z) toward the campfire
	var sk := MeshInstance3D.new(); var skm := CylinderMesh.new(); skm.top_radius = 0.018; skm.bottom_radius = 0.022; skm.height = 0.96
	sk.mesh = skm; sk.rotation_degrees.x = 76.0; sk.position = Vector3(0.22, 0.62, 0.68)
	grunt_root.add_child(sk)
	_place_glb(grunt_root, "grilled_fish.glb", Vector2(0.22, 1.12), 0.56, Vector3(0, 88, 0), Color("#a8c2d9"), 0.15, 0.66, 1.15, false)

	# 6d. Curled Giant Wolf & Fat Yellow Bird beside Campfire
	wolf_node = Node3D.new()
	wolf_node.position = Vector3(0.35, terrain_height(0.35, -1.25), -1.25)
	wolf_node.rotation_degrees.y = 18.0
	add_child(wolf_node)
	_add_contact_shadow(wolf_node, 1.45, 0.04)
	var fur_d := StandardMaterial3D.new(); fur_d.albedo_color = Color("#4d3f4a"); fur_d.roughness = 0.95
	var fur_w := StandardMaterial3D.new(); fur_w.albedo_color = Color("#b57d52"); fur_w.roughness = 0.95
	for wp in [
		[Vector3(0.0, 0.55, 0.0), Vector3(1.65, 0.82, 1.45), fur_d],
		[Vector3(-0.78, 0.52, 0.55), Vector3(0.95, 0.62, 0.85), fur_w],
		[Vector3(-0.75, 0.95, 0.72), Vector3(0.76, 0.64, 0.88), fur_d],
		[Vector3(-0.82, 0.78, 1.15), Vector3(0.36, 0.28, 0.52), fur_w],
		[Vector3(0.72, 0.42, 0.68), Vector3(0.62, 0.42, 1.15), fur_d]
	]:
		var wm := MeshInstance3D.new(); var ws := SphereMesh.new(); ws.radius = 0.5; ws.height = 1.0
		wm.mesh = ws; wm.scale = wp[1]; wm.position = wp[0]; wm.material_override = wp[2]
		wolf_node.add_child(wm)
	for ex in [-0.95, -0.55]:
		var ear := MeshInstance3D.new(); var ec := CylinderMesh.new(); ec.top_radius = 0.03; ec.bottom_radius = 0.16; ec.height = 0.42
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

	# 6e. Upper-Left Standing Stones & Mossy Stone Golem on Raised Knoll
	for ss in [
		[Vector2(-9.2, -7.2), 1.85, 16.0],
		[Vector2(-8.3, -9.1), 2.45, 8.0],
		[Vector2(-6.8, -9.9), 3.25, -4.0],
		[Vector2(-5.0, -9.0), 2.50, -14.0],
		[Vector2(-4.4, -7.3), 1.78, -20.0]
	]:
		var sp2: Vector2 = ss[0]
		var sz: float = ss[1]
		_place_glb(self, "standing_stone.glb", sp2, sz, Vector3(0, float(ss[2]), 0), Color("#99a8cc"), 0.22, -0.10, 1.12, true, 0.95)
		var orb := MeshInstance3D.new(); var os := SphereMesh.new(); os.radius = 0.11; os.height = 0.22
		var omat := StandardMaterial3D.new(); omat.albedo_color = Color("#ffd466"); omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orb.mesh = os; orb.material_override = omat
		orb.position = Vector3(sp2.x, terrain_height(sp2.x, sp2.y) + sz * 0.58, sp2.y + 0.36)
		add_child(orb)

	golem_node = _place_glb(self, "golem.glb", Vector2(-6.9, -7.8), 1.85, Vector3(0, 14, 0), Color("#b5c7a3"), 0.10, -0.04, 1.14, true, 1.05)

	# 6f. Mid-Left Mossy Skull Cave (turned -22° so eye sockets & dark cave mouth face trail/camera)
	_place_glb(self, "skull_cave.glb", Vector2(-8.5, -3.5), 5.4, Vector3(0, -22, 0), Color("#9cb08e"), 0.14, -0.35, 1.10, true, 2.8)

	# 6g. Lower-Left Waterfall Rocks tightly framing the waterfall + Fishing Pier w/ PROPERLY RAISED Bucket!
	_place_glb(self, "waterfall_rock.glb", Vector2(-9.95, 3.85), 3.2, Vector3(0, 20, 0), Color("#7d8eb8"), 0.24, -0.35, 1.08, true, 1.6)
	_place_glb(self, "waterfall_rock.glb", Vector2(-6.75, 4.15), 2.5, Vector3(0, -28, 0), Color("#7d8eb8"), 0.24, -0.30, 1.08, true, 1.3)

	var pier_y := WATER_LEVEL + 0.16
	_place_glb(self, "pier.glb", Vector2(-2.7, 5.15), 3.3, Vector3(0, -6, 0), Color("#b87b4f"), 0.10, pier_y, 1.05, false)
	# Fixed bucket height sitting squarely ON TOP of the pier planks!
	_place_glb(self, "bucket.glb", Vector2(-2.25, 5.10), 0.68, Vector3(0, 18, 0), Color("#9bb2c9"), 0.10, pier_y + 0.94, 1.12, false)
	_place_glb(self, "fishing_rod.glb", Vector2(-1.65, 5.15), 2.25, Vector3(14, -22, -24), Color("#c27e4a"), 0.10, pier_y + 0.78, 1.08, false)
	var line_m := MeshInstance3D.new(); var lcm := CylinderMesh.new(); lcm.top_radius = 0.012; lcm.bottom_radius = 0.012; lcm.height = 1.65
	var lmat := StandardMaterial3D.new(); lmat.albedo_color = Color("#edf4ff"); lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_m.mesh = lcm; line_m.material_override = lmat; line_m.position = Vector3(-1.35, WATER_LEVEL + 0.88, 5.85)
	add_child(line_m)
	fishing_bobber = Node3D.new(); fishing_bobber.position = Vector3(-1.35, WATER_LEVEL + 0.05, 5.85); add_child(fishing_bobber)
	var b_red := MeshInstance3D.new(); var brs := SphereMesh.new(); brs.radius = 0.15; brs.height = 0.30
	var brm := StandardMaterial3D.new(); brm.albedo_color = Color("#e85242"); brm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_red.mesh = brs; b_red.material_override = brm; fishing_bobber.add_child(b_red)
	var b_wht := MeshInstance3D.new(); var bws := SphereMesh.new(); bws.radius = 0.145; bws.height = 0.16
	var bwm := StandardMaterial3D.new(); bwm.albedo_color = Color("#fff9f0"); bwm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_wht.mesh = bws; b_wht.material_override = bwm; b_wht.position = Vector3(0, 0.08, 0); fishing_bobber.add_child(b_wht)

	# 6h. Right Wooden Arch Bridge (Natural Warm Cedar — NOT Red!)
	_place_glb(self, "bridge.glb", Vector2(8.55, -1.10), 4.60, Vector3(0, 6, 0), Color("#c48b5c"), 0.10, -0.20, 0.98, false)

	# 6i. Cozy Red-Roof Cabin pulled slightly inward so the FULL cabin & glowing window are framed!
	var cab_xz := Vector2(9.1, 4.4)
	_place_glb(self, "cabin.glb", cab_xz, 4.25, Vector3(0, -10, 0), Color("#d16b4c"), 0.08, -0.06, 1.05, true, 2.2)
	var cab_y := terrain_height(cab_xz.x, cab_xz.y)
	# Tightly clustered billowing chimney cloud puffs (vC7OEC style!)
	for i in range(8):
		var cp := _soft_cloud_puff(Vector3(9.85, cab_y + 3.25, 4.1), 0.36, Color(0.88, 0.92, 0.98, 0.50))
		cabin_smoke.append({"node": cp, "offset": float(i) / 8.0, "base_y": cab_y + 3.25})

	# 6j. Layered Luminous Forest Enclosure (06_29_51.png Cobalt-Indigo Pines + Hero Terracotta-Crimson Pine!)
	_place_glb(self, "pine_tree.glb", Vector2(0.85, -8.4), 6.2, Vector3(0, 12, 0), Color("#d64b3e"), 0.80, -0.15, 1.15, true, 2.2)
	for tp in [
		[Vector2(-12.2, -7.4), 6.6, 22.0, Color("#345cc2")],
		[Vector2(-14.6, -2.2), 5.8, -14.0, Color("#2c50ad")],
		[Vector2(-13.8, 2.8), 5.4, 34.0, Color("#3057b8")],
		[Vector2(-9.6, -12.2), 5.8, 10.0, Color("#2a4ca6")],
		[Vector2(-3.8, -12.0), 5.5, -24.0, Color("#3158ba")],
		[Vector2(4.4, -11.8), 5.6, 18.0, Color("#2d52b0")],
		[Vector2(6.6, -8.6), 6.0, -18.0, Color("#3660c7")],
		[Vector2(13.2, -6.2), 5.8, 28.0, Color("#2e52b0")],
		[Vector2(14.8, -0.2), 5.5, -10.0, Color("#3258ba")],
		[Vector2(13.4, 3.2), 6.2, -16.0, Color("#2e53b3")],
		[Vector2(14.4, 7.2), 5.4, 24.0, Color("#28499e")],
		[Vector2(-13.4, 7.8), 5.2, -20.0, Color("#28499e")]
	]:
		_place_glb(self, "pine_tree.glb", tp[0], float(tp[1]), Vector3(0, float(tp[2]), 0), tp[3], 0.78, -0.18, 1.14, true, 2.0)

	# Luminous Northern Woodland Backlight Trunks (06_29_51.png tall vertical blue trunks!)
	for bx in [-13.5, -10.2, -7.4, -4.5, -1.8, 1.2, 4.0, 6.8, 9.6, 12.6]:
		var tr_h := randf_range(7.0, 10.5)
		var tr_m := MeshInstance3D.new()
		var tcm := CylinderMesh.new(); tcm.top_radius = 0.45; tcm.bottom_radius = 0.55; tcm.height = tr_h
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color("#243f85") if int(absf(bx)) % 2 == 0 else Color("#1b306b")
		tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tr_m.mesh = tcm; tr_m.material_override = tmat
		tr_m.position = Vector3(float(bx), tr_h * 0.45, -15.4 + fmod(absf(bx) * 1.7, 1.8))
		add_child(tr_m)

	# Shoreline Plum-Violet Foliage Framing
	for sh in [
		["palm_bush.glb", Vector2(-11.4, -1.8), 1.95, 18.0, Color("#733e7a")],
		["palm_bush.glb", Vector2(-10.2, 0.8), 1.65, -24.0, Color("#7d4278")],
		["palm_bush.glb", Vector2(3.8, -6.4), 1.85, 14.0, Color("#673d7d")],
		["palm_bush.glb", Vector2(4.6, 3.6), 1.85, -16.0, Color("#75407a")]
	]:
		_place_glb(self, String(sh[0]), sh[1], float(sh[2]), Vector3(0, float(sh[3]), 0), sh[4], 0.65, -0.10, 1.14, true, 1.0)

	# Foreground Lake-Corner Framing Shrubs (floating cleanly at WATER_LEVEL + 0.05 so they frame bottom corners!)
	for fg in [
		["lush_shrub.glb", Vector2(-11.4, 6.6), 3.2, 20.0, Color("#2e52b0")],
		["lush_shrub.glb", Vector2(-9.5, 7.4), 2.6, -18.0, Color("#7d4282")],
		["lush_shrub.glb", Vector2(11.4, 7.3), 3.1, -28.0, Color("#2e52b0")],
		["lush_shrub.glb", Vector2(12.8, 6.2), 2.6, 16.0, Color("#7d4282")]
	]:
		_place_glb(self, String(fg[0]), fg[1], float(fg[2]), Vector3(0, float(fg[3]), 0), fg[4], 0.72, WATER_LEVEL + 0.05, 1.14, false, 0.0)

	# Scattered White & Blue Bobble Wildflowers & Mossy Shore Rocks
	for wf in [
		Vector2(-4.4, -5.8), Vector2(-2.8, -5.4), Vector2(4.6, -5.0),
		Vector2(6.0, -4.4), Vector2(-5.4, 2.8), Vector2(-4.0, 3.4),
		Vector2(3.2, 2.9), Vector2(11.4, -5.2), Vector2(-9.8, -5.4)
	]:
		_place_glb(self, "wildflowers.glb", wf, 1.15, Vector3(0, wf.x * 41.0, 0), Color.WHITE, 0.0, -0.04, 1.20)

	for sr in [
		[Vector2(-6.2, -1.4), 1.25], [Vector2(6.5, 1.8), 1.35],
		[Vector2(10.6, 1.0), 1.18], [Vector2(11.8, -4.0), 1.22],
		[Vector2(7.2, 5.8), 1.28], [Vector2(-0.8, 4.3), 1.05],
		[Vector2(5.9, 4.1), 1.15]
	]:
		var s_xz: Vector2 = sr[0]
		_place_glb(self, "shore_rock.glb", s_xz, float(sr[1]), Vector3(0, s_xz.x * 31.0, 0), Color("#8a9cc4"), 0.18, -0.14, 1.08, true, 0.85)

	# 6k. Interactive Shatterable Props (RigidBody3D Physics Shards + Pixel Sparks + Smooth Scorch)
	var wood_cols := [Color("#8c5838"), Color("#c48a58"), Color("#543525"), Color("#e0a050")]
	var rock_cols := [Color("#7a8aad"), Color("#a6b5d4"), Color("#56824e"), Color("#586482")]
	for sp in [
		["stump.glb", Vector2(-3.9, 2.1), 1.08, wood_cols],
		["stump.glb", Vector2(5.4, 2.0), 1.05, wood_cols],
		["stump.glb", Vector2(4.6, -3.5), 1.02, wood_cols],
		["shore_rock.glb", Vector2(-4.5, -3.8), 1.15, rock_cols],
		["shore_rock.glb", Vector2(12.0, 1.2), 1.12, rock_cols]
	]:
		var pxz: Vector2 = sp[1]
		var p_node := _place_glb(self, String(sp[0]), pxz, float(sp[2]), Vector3(0, randf() * 360.0, 0), Color.WHITE, 0.0, -0.04, 1.08, true, 0.72)
		ink_fx.register_shatter_prop(p_node, p_node.position, 0.95, sp[3], 3, 1)

	# 6l. Soft Diagonal Volumetric God Rays (vC7OEC signature!)
	for gr in [
		[Vector3(-5.8, 6.4, -3.5), 3.6, 16.0],
		[Vector3(-1.2, 7.0, -2.0), 4.2, 17.0],
		[Vector3(4.2, 6.6, -2.8), 3.8, 16.0],
		[Vector3(8.8, 6.4, 1.5), 3.4, 15.0]
	]:
		var qm := QuadMesh.new(); qm.size = Vector2(float(gr[1]), float(gr[2]))
		var gi := MeshInstance3D.new(); gi.mesh = qm
		var gmat := ShaderMaterial.new(); gmat.shader = SHADER_GODRAY
		gi.material_override = gmat; godray_mats.append(gmat)
		gi.position = gr[0]; gi.rotation_degrees = Vector3(14.0, -18.0, 26.0)
		add_child(gi)

	# 6m. Gentle Floating Fireflies
	for _i in range(22):
		var fx := randf_range(-11.0, 11.0)
		var fz := randf_range(-8.0, 6.5)
		var fy_base := maxf(WATER_LEVEL + 0.6, terrain_height(fx, fz) + randf_range(0.6, 2.4))
		var fm := _soft_cloud_puff(Vector3(fx, fy_base, fz), 0.055, Color("#ffe38a"))
		fireflies.append({"node": fm, "base": fm.position, "ph": randf() * TAU, "spd": randf_range(0.8, 1.7)})

# --- 7. Playable Traveler & Wider Storybook Framing Camera ---
func _setup_player_and_camera() -> void:
	player = Node3D.new()
	player.position = Vector3(1.1, terrain_height(1.1, -0.35), -0.35)
	add_child(player)
	player_visual = Node3D.new()
	player.add_child(player_visual)
	_place_glb(player_visual, "traveler_c01.glb", Vector2.ZERO, 1.18, Vector3.ZERO, Color.WHITE, 0.0, 0.0, 1.14, false, 0.45)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 31.0
	camera.near = 0.5
	camera.far = 160.0
	camera.current = true
	add_child(camera)
	_update_camera(1.0)

func _update_camera(lerp_w: float) -> void:
	var target: Vector3
	var desired: Vector3
	if orbit_camera:
		target = Vector3(0.0, 0.35, -0.5)
		var radius := 28.0
		desired = target + Vector3(sin(orbit_angle) * radius, 16.5, cos(orbit_angle) * radius)
	else:
		# Pulled back to frame FULL 06_29_51.png diorama (lake + waterfall + pier + camp + stones + full cabin + forest!)
		target = player.position.lerp(Vector3(0.1, 0.25, -0.4), 0.72)
		desired = target + Vector3(0.0, 15.2, 26.2)
	camera.position = camera.position.lerp(desired, lerp_w) if lerp_w < 1.0 else desired
	camera.look_at(target)

# --- 8. Ultra-Clean Minimalist UI ---
func _setup_minimal_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	hint_panel = PanelContainer.new()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint_panel.offset_left = 18; hint_panel.offset_bottom = -16; hint_panel.offset_top = -52; hint_panel.offset_right = 680
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.13, 0.28, 0.68)
	sb.border_color = Color(0.95, 0.78, 0.42, 0.45)
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

	if campfire_flame:
		campfire_flame.scale = Vector3(1.0 + sin(t * 8.5) * 0.06, 0.94 + sin(t * 12.5) * 0.14, 1.0 + cos(t * 9.5) * 0.06)
	if campfire_light:
		var base_e := 2.45 if is_night else 0.85
		campfire_light.light_energy = base_e + sin(t * 10.5) * 0.22
	if campfire_smoke_ribbon:
		campfire_smoke_ribbon.rotation.y = sin(t * 0.9) * 0.14
		campfire_smoke_ribbon.scale.x = 1.0 + sin(t * 1.6) * 0.08

	for rec in cabin_smoke:
		var cn: MeshInstance3D = rec["node"]
		var cyc := fmod(t * 0.24 + float(rec["offset"]), 1.0)
		cn.position = Vector3(9.85 + cyc * 1.15, float(rec["base_y"]) + cyc * 2.1, 4.10 + sin(cyc * PI) * 0.18)
		var sc := 0.55 + cyc * 1.15
		cn.scale = Vector3(sc, sc * 0.92, sc)
		(cn.material_override as StandardMaterial3D).albedo_color.a = sin(cyc * PI) * 0.45

	for rec in waterfall_foam:
		var fn: Node3D = rec["node"]
		var bp: Vector3 = rec["base"]
		var ph := float(rec["ph"])
		var s := 0.86 + sin(t * 4.2 + ph) * 0.18
		fn.scale = Vector3(s, s * 0.85, s)
		fn.position.y = bp.y + sin(t * 5.0 + ph) * 0.05

	if fishing_bobber:
		fishing_bobber.position.y = WATER_LEVEL + 0.05 + sin(t * 3.0) * 0.05
	if grunt_key:
		grunt_key.rotation.z += delta * 1.8
	if golem_node:
		golem_node.position.y = terrain_height(-6.9, -7.8) - 0.04 + absf(sin(t * 2.2)) * 0.06
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

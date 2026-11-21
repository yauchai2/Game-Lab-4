extends Node3D

# Ink Studio-inspired Godot 4.7 Systems:
# 1. Persistent Surface State Map (128x128 ImageTexture: R=Scorch, G=Snow/Frost, B=Wetness/Footprints)
# 2. RigidBody3D Shatter Physics + Pixel-Art Cube Particle Bursts
# 3. Interactive Weather Modes ([V]: Starry Night / Falling Snow / Night Rain)

const STATE_RES := 128
const MAP_MIN := Vector2(-24.0, -18.0)
const MAP_SIZE := Vector2(48.0, 36.0)

var state_img: Image
var state_tex: ImageTexture
var _state_dirty := false
var _tex_upload_timer := 0.0

# Weather: 0 = Starry Night (ambient embers), 1 = Falling Snow (frost accumulates, melts near fire), 2 = Night Rain (wet puddles)
var weather_mode := 0
var weather_particles: Array[Dictionary] = []
var pixel_sparks: Array[Dictionary] = []
var physics_shards: Array[Dictionary] = []
var shatter_props: Array[Dictionary] = []

var wet_boots_timer := 0.0
var _step_paint_timer := 0.0
var _weather_accum_timer := 0.0
var _campfire_pos := Vector3.ZERO

func setup(campfire_pos: Vector3) -> ImageTexture:
	_campfire_pos = campfire_pos
	state_img = Image.create_empty(STATE_RES, STATE_RES, false, Image.FORMAT_RGBA8)
	state_img.fill(Color(0.0, 0.0, 0.0, 1.0))
	# Initial subtle campfire char ring & shoreline dampness
	paint_scorch(campfire_pos, 1.45, 0.58)
	for x in range(-14, 14, 2):
		paint_wetness(Vector3(float(x), 0.0, 5.2), 1.8, 0.45)
	for z in range(-10, 6, 2):
		paint_wetness(Vector3(9.4, 0.0, float(z)), 1.6, 0.40)
	state_tex = ImageTexture.create_from_image(state_img)
	_state_dirty = false
	return state_tex

func _world_to_px(world_pos: Vector3) -> Vector2i:
	var u := clampf((world_pos.x - MAP_MIN.x) / MAP_SIZE.x, 0.0, 0.999)
	var v := clampf((world_pos.z - MAP_MIN.y) / MAP_SIZE.y, 0.0, 0.999)
	return Vector2i(int(u * float(STATE_RES)), int(v * float(STATE_RES)))

func _paint_channel(world_pos: Vector3, radius: float, delta_rgb: Vector3) -> void:
	if state_img == null:
		return
	var c := _world_to_px(world_pos)
	var r_px := maxi(1, int(ceil(radius / (MAP_SIZE.x / float(STATE_RES)))))
	for dy in range(-r_px, r_px + 1):
		var py := c.y + dy
		if py < 0 or py >= STATE_RES:
			continue
		for dx in range(-r_px, r_px + 1):
			var px := c.x + dx
			if px < 0 or px >= STATE_RES:
				continue
			var dist := sqrt(float(dx * dx + dy * dy)) / float(r_px)
			if dist > 1.0:
				continue
			var falloff := (1.0 - dist * dist)
			var cur := state_img.get_pixel(px, py)
			cur.r = clampf(cur.r + delta_rgb.x * falloff, 0.0, 1.0)
			cur.g = clampf(cur.g + delta_rgb.y * falloff, 0.0, 1.0)
			cur.b = clampf(cur.b + delta_rgb.z * falloff, 0.0, 1.0)
			state_img.set_pixel(px, py, cur)
	_state_dirty = true

func paint_scorch(world_pos: Vector3, radius := 1.6, strength := 0.55) -> void:
	# Scorching also melts snow and dries wetness cleanly!
	_paint_channel(world_pos, radius, Vector3(strength, -strength * 1.4, -strength * 0.9))

func paint_snow(world_pos: Vector3, radius := 2.2, strength := 0.25) -> void:
	_paint_channel(world_pos, radius, Vector3(0.0, strength, 0.0))

func paint_wetness(world_pos: Vector3, radius := 1.1, strength := 0.45) -> void:
	_paint_channel(world_pos, radius, Vector3(-strength * 0.15, -strength * 0.5, strength))

func cycle_weather() -> String:
	weather_mode = (weather_mode + 1) % 3
	for wp in weather_particles:
		if is_instance_valid(wp["node"]):
			(wp["node"] as Node3D).queue_free()
	weather_particles.clear()
	match weather_mode:
		1:
			# Immediate light frost coat outside campfire warmth so player sees it right away!
			for _i in range(28):
				var p := Vector3(randf_range(-16.0, 16.0), 0.0, randf_range(-12.0, 9.0))
				if p.distance_to(_campfire_pos) > 4.6:
					paint_snow(p, 2.8, 0.34)
			return "❄️ 天氣切換：飄雪積霜（地表持續積雪，營火暖區自動融雪！）"
		2:
			for _i in range(24):
				var p := Vector3(randf_range(-16.0, 16.0), 0.0, randf_range(-12.0, 9.0))
				paint_wetness(p, 2.6, 0.38)
			return "🌧 天氣切換：夜雨濕潤（草地積水反光＋水窪漣漪！）"
		_:
			return "✨ 天氣切換：靜謐星夜（營火暖光＋持久焦痕與腳印保留）"

func get_weather_label() -> String:
	match weather_mode:
		1: return "❄️ 飄雪積霜"
		2: return "🌧 夜雨濕潤"
		_: return "✨ 靜謐星夜"

# --- Ink Studio RigidBody3D Shatterable Props & Pixel-Art Voxel Particle Bursts ---
func register_shatter_prop(node: Node3D, pos: Vector3, radius: float, shard_colors: Array, coin_count := 3, hp := 1) -> void:
	var body := StaticBody3D.new()
	node.add_child(body)
	var col := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius * 0.65
	sh.height = 1.2
	col.shape = sh
	col.position = Vector3(0.0, 0.6, 0.0)
	body.add_child(col)
	shatter_props.append({
		"node": node,
		"pos": pos,
		"radius": radius,
		"colors": shard_colors,
		"coins": coin_count,
		"hp": hp,
		"broken": false,
	})

func spawn_pixel_burst(origin: Vector3, colors: Array, count := 20, speed_mult := 1.0) -> void:
	for i in range(count):
		var sz := randf_range(0.09, 0.21)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * sz
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.position = origin + Vector3(randf_range(-0.35, 0.35), randf_range(0.25, 0.85), randf_range(-0.35, 0.35))
		add_child(mi)
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(2.2, 6.2) * speed_mult
		pixel_sparks.append({
			"node": mi,
			"vel": Vector3(cos(ang) * spd, randf_range(3.0, 7.2) * speed_mult, sin(ang) * spd),
			"rot": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)),
			"age": 0.0,
			"life": randf_range(0.45, 0.95),
		})

func spawn_physics_shatter(origin: Vector3, colors: Array, impulse_from: Vector3, count := 10) -> void:
	var push_dir := Vector3(origin.x - impulse_from.x, 0.0, origin.z - impulse_from.z)
	if push_dir.length() > 0.05:
		push_dir = push_dir.normalized()
	else:
		push_dir = Vector3.RIGHT
	for i in range(count):
		var rb := RigidBody3D.new()
		rb.collision_layer = 4
		rb.collision_mask = 1
		rb.mass = 0.6
		var pm := PhysicsMaterial.new()
		pm.bounce = 0.42
		pm.friction = 0.72
		rb.physics_material_override = pm
		rb.position = origin + Vector3(randf_range(-0.42, 0.42), randf_range(0.28, 0.92), randf_range(-0.42, 0.42))
		var chunk_sz := Vector3(randf_range(0.18, 0.38), randf_range(0.14, 0.32), randf_range(0.18, 0.36))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = chunk_sz
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.roughness = 1.0
		mat.metallic = 0.0
		mi.material_override = mat
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = chunk_sz
		cs.shape = bs
		rb.add_child(cs)
		add_child(rb)
		var ang := randf_range(0.0, TAU)
		var out_v := Vector3(cos(ang), 0.0, sin(ang)) * randf_range(2.2, 4.8) + push_dir * 2.4 + Vector3(0.0, randf_range(3.6, 6.4), 0.0)
		rb.apply_central_impulse(out_v)
		rb.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		physics_shards.append({"node": rb, "age": 0.0})

func try_hit_shatter_props(origin: Vector3, radius: float, host: Node) -> bool:
	var hit_any := false
	for p in shatter_props:
		if bool(p["broken"]):
			continue
		var pn: Node3D = p["node"]
		if not is_instance_valid(pn):
			continue
		var d := Vector2(origin.x - pn.position.x, origin.z - pn.position.z).length()
		if d <= radius + float(p["radius"]):
			hit_any = true
			p["hp"] = int(p["hp"]) - 1
			var cols: Array = p["colors"]
			if int(p["hp"]) > 0:
				if host.has_method("flash_hit"):
					host.flash_hit(pn)
				spawn_pixel_burst(pn.position, cols, 8, 0.8)
				paint_scorch(pn.position, 1.1, 0.25)
			else:
				p["broken"] = true
				var pos := pn.position
				pn.queue_free()
				PrologueState.play_sfx("wood")
				spawn_physics_shatter(pos, cols, origin, 10)
				spawn_pixel_burst(pos, cols + [Color("#ff9838"), Color("#fff2b2")], 22, 1.15)
				paint_scorch(pos, 1.85, 0.65)
				if host.has_method("spawn_bouncing_coins"):
					host.spawn_bouncing_coins(pos, int(p["coins"]), 5)
				if host.has_method("spawn_damage_pop"):
					host.spawn_damage_pop(pos, "💥 碎裂！", Color("#ffd97d"), false)
	return hit_any

func step(delta: float, actor_pos: Vector3, actor_moving: bool) -> void:
	# 1. Persistent Boot Wetness & Footprints when walking near lake/stream
	var near_water := (actor_pos.z > 3.5 and actor_pos.x < 8.0) or (actor_pos.x > 6.6 and actor_pos.x < 11.4)
	if near_water:
		wet_boots_timer = 5.5
	else:
		wet_boots_timer = maxf(0.0, wet_boots_timer - delta)

	_step_paint_timer -= delta
	if actor_moving and _step_paint_timer <= 0.0:
		_step_paint_timer = 0.16
		if wet_boots_timer > 0.0:
			paint_wetness(actor_pos, 0.72, 0.55)
		elif weather_mode == 1:
			# Walking through snow leaves dark melted/pressed footsteps!
			_paint_channel(actor_pos, 0.62, Vector3(0.0, -0.45, 0.25))

	# 2. Persistent Weather Accumulation + Campfire Warmth Melt
	_weather_accum_timer -= delta
	if _weather_accum_timer <= 0.0:
		_weather_accum_timer = 0.22
		if weather_mode == 1:
			# Accumulate pixel frost across clearing, melt cleanly near campfire!
			for _i in range(3):
				var rp := Vector3(randf_range(-18.0, 18.0), 0.0, randf_range(-13.0, 9.5))
				if rp.distance_to(_campfire_pos) > 4.2:
					paint_snow(rp, 1.9, 0.14)
			_paint_channel(_campfire_pos, 4.4, Vector3(0.01, -0.25, -0.05))
		elif weather_mode == 2:
			for _i in range(3):
				var rp := Vector3(randf_range(-18.0, 18.0), 0.0, randf_range(-13.0, 9.5))
				paint_wetness(rp, 2.0, 0.15)
		else:
			# Campfire gently deepens its warm char ring over time
			paint_scorch(_campfire_pos, 1.5, 0.015)

	# 3. Live Pixel Snow / Rain Particles
	if weather_mode != 0 and weather_particles.size() < 48:
		var wp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.11, 0.11, 0.11) if weather_mode == 1 else Vector3(0.04, 0.42, 0.04)
		wp.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#eaf4ff") if weather_mode == 1 else Color("#7ec8ff")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wp.material_override = mat
		wp.position = actor_pos + Vector3(randf_range(-14.0, 14.0), randf_range(7.0, 11.5), randf_range(-10.0, 10.0))
		add_child(wp)
		weather_particles.append({"node": wp, "spd": randf_range(1.6, 2.8) if weather_mode == 1 else randf_range(11.0, 15.0), "ph": randf_range(0.0, TAU)})

	var t := Time.get_ticks_msec() * 0.001
	for i in range(weather_particles.size() - 1, -1, -1):
		var wp: Dictionary = weather_particles[i]
		var wn: Node3D = wp["node"]
		if not is_instance_valid(wn):
			weather_particles.remove_at(i)
			continue
		if weather_mode == 1:
			wn.position.y -= float(wp["spd"]) * delta
			wn.position.x += sin(t * 2.0 + float(wp["ph"])) * 0.8 * delta
			wn.rotation.y += delta * 2.5
		else:
			wn.position.y -= float(wp["spd"]) * delta
			wn.position.x += 1.4 * delta
		if wn.position.y <= 0.05:
			wn.queue_free()
			weather_particles.remove_at(i)

	# 4. Pixel Cube Spark Particles
	for i in range(pixel_sparks.size() - 1, -1, -1):
		var sp: Dictionary = pixel_sparks[i]
		var sn: Node3D = sp["node"]
		if not is_instance_valid(sn):
			pixel_sparks.remove_at(i)
			continue
		sp["age"] = float(sp["age"]) + delta
		var vel: Vector3 = sp["vel"]
		vel.y -= 16.5 * delta
		sn.position += vel * delta
		if sn.position.y < 0.08:
			sn.position.y = 0.08
			vel.y = absf(vel.y) * 0.45
			vel.x *= 0.7
			vel.z *= 0.7
		sp["vel"] = vel
		var rvel: Vector3 = sp["rot"]
		sn.rotation += rvel * delta
		var life := float(sp["life"])
		if float(sp["age"]) >= life:
			sn.queue_free()
			pixel_sparks.remove_at(i)
		elif float(sp["age"]) > life * 0.6:
			var s := clampf(1.0 - (float(sp["age"]) - life * 0.6) / (life * 0.4), 0.05, 1.0)
			sn.scale = Vector3.ONE * s

	# 5. RigidBody3D Shatter Debris Cleanup (linger 6.5s on the ground so player enjoys the scatter!)
	for i in range(physics_shards.size() - 1, -1, -1):
		var sh: Dictionary = physics_shards[i]
		var rn: Node3D = sh["node"]
		if not is_instance_valid(rn):
			physics_shards.remove_at(i)
			continue
		sh["age"] = float(sh["age"]) + delta
		if float(sh["age"]) > 6.5:
			rn.queue_free()
			physics_shards.remove_at(i)

	# 6. Throttled GPU Upload of Persistent State Texture (at ~15Hz for zero stutter!)
	_tex_upload_timer -= delta
	if _state_dirty and _tex_upload_timer <= 0.0 and state_tex != null:
		state_tex.update(state_img)
		_state_dirty = false
		_tex_upload_timer = 0.07

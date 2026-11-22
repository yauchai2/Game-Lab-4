extends RefCounted

const Wind := preload("res://diorama/foliage/foliage_wind.gdshader")

static func finish() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Wind
	return material

static func broadleaf(seed_value: int, palette: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color("#95613d")
	limb(mesh, Vector3.ZERO, Vector3(0.16, 2.12, -0.08), 0.27, 0.11, bark)
	limb(mesh, Vector3(0.0, 0.19, 0.0), Vector3(-0.43, 0.02, 0.18), 0.22, 0.05, bark)
	limb(mesh, Vector3(0.05, 0.16, -0.04), Vector3(0.36, 0.02, -0.31), 0.24, 0.05, bark)
	var centers: Array[Vector3] = [
		Vector3(0.02, 3.02, -0.11), Vector3(-0.76, 2.46, 0.08),
		Vector3(0.66, 2.53, 0.26), Vector3(-0.42, 2.62, -0.68),
		Vector3(0.61, 2.63, -0.54), Vector3(-0.14, 2.32, 0.71),
	]
	var crown_center := Vector3(0.0, 2.67, 0.0)
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 2.9
	for i in centers.size():
		var center := centers[i] + Vector3(rng.randf_range(-0.13, 0.13), rng.randf_range(-0.14, 0.13), rng.randf_range(-0.14, 0.14))
		if i > 0:
			limb(mesh, Vector3(0.09, 1.44 + i * 0.08, 0.0), center, 0.10, 0.055, bark)
		var size := rng.randf_range(0.79, 0.95)
		var axes := Vector3(size * 1.12, size * 0.90, size)
		var color := palette.lerp(palette.lightened(0.26), rng.randf_range(0.07, 0.85))
		cloud(mesh, center, crown_center, axes, color, noise)
	mesh.index()
	return mesh.commit()

static func conifer(seed_value: int, palette: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	limb(mesh, Vector3.ZERO, Vector3(0.0, 2.16, 0.0), 0.24, 0.10, Color("#936344"))
	const SIDES := 48
	var contour := [Vector2(0.16, -0.11), Vector2(0.86, -0.06), Vector2(1.0, 0.08),
		Vector2(0.75, 0.37), Vector2(0.43, 0.71), Vector2(0.0, 1.0)]
	for tier in 4:
		var radius := (1.22 - tier * 0.22) * rng.randf_range(0.93, 1.07)
		var height := 0.69 + tier * 0.65
		var phase := rng.randf_range(0.0, TAU)
		var tier_color := palette.lerp(palette.lightened(0.24), float(tier) * 0.18)
		var rings: Array[PackedVector3Array] = []
		for profile in contour:
			var ring := PackedVector3Array()
			for side in SIDES:
				var angle := TAU * float(side) / SIDES
				var tooth := 0.5 + 0.5 * cos(angle * 12.0 + phase)
				var radial: float = radius * profile.x * (0.92 + tooth * 0.08 + sin(angle * 3.0 + phase) * 0.046)
				var y: float = height + profile.y * 1.09 - tooth * 0.067 * profile.x
				ring.append(Vector3(cos(angle) * radial, y, sin(angle) * radial))
			rings.append(ring)
		for band in rings.size() - 1:
			for i in SIDES:
				var j := (i + 1) % SIDES
				for v in [rings[band][i], rings[band][j], rings[band + 1][i],
						rings[band][j], rings[band + 1][j], rings[band + 1][i]]:
					var out := Vector3(v.x, 0.0, v.z)
					var normal := (out.normalized() + Vector3.UP * (-0.23 if band < 2 else 0.94)).normalized()
					var tint_ramp := smoothstep(height - 0.15, height + 0.64, v.y)
					var color := tier_color.darkened(0.18).lerp(tier_color.lightened(0.12), tint_ramp)
					leaf_vertex(mesh, v, normal, color, 0.038 + minf(out.length() * 0.035, 0.035))
	mesh.index()
	return mesh.commit()

static func grass(seed_value: int, palette: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 7:
		var a := float(blade) * 2.40 + rng.randf_range(-0.3, 0.3)
		var outward := Vector3(cos(a), 0.0, sin(a))
		var tangent := outward.cross(Vector3.UP)
		var root := outward * rng.randf_range(0.02, 0.10)
		var tall := rng.randf_range(0.18, 0.36)
		var width := rng.randf_range(0.025, 0.058)
		var rings: Array[PackedVector3Array] = []
		for row in 4:
			var t := float(row) / 3.0
			var center := root + outward * (t * t * tall * 0.64) + Vector3.UP * tall * t
			var half := width * sin(PI * lerpf(0.24, 1.0, t))
			rings.append(PackedVector3Array([center - tangent * half, center + tangent * half]))
		for row in 3:
			for v in [rings[row][0], rings[row][1], rings[row + 1][0],
					rings[row][1], rings[row + 1][1], rings[row + 1][0]]:
				var t: float = v.y / tall
				mesh.set_normal(Vector3.UP)
				var color := palette.darkened(0.20).lerp(palette.lightened(0.16), t)
				color.a = 0.0
				mesh.set_color(color)
				mesh.set_uv(Vector2(t * t * 0.088, t * t * 0.038))
				mesh.add_vertex(v)
	mesh.index()
	return mesh.commit()

static func limb(mesh: SurfaceTool, from: Vector3, to: Vector3, base: float, tip: float, tint: Color) -> void:
	var shape := CylinderMesh.new()
	shape.radial_segments = 8
	shape.rings = 1
	shape.height = from.distance_to(to)
	shape.bottom_radius = base
	shape.top_radius = tip
	var rotation := Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	var mid := (from + to) * 0.5
	var arrays := shape.surface_get_arrays(0)
	for index in arrays[Mesh.ARRAY_INDEX]:
		var vertex: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
		var p := mid + rotation * vertex
		mesh.set_normal(rotation * arrays[Mesh.ARRAY_NORMAL][index])
		mesh.set_color(tint.darkened(0.17).lerp(tint, smoothstep(0.0, 1.2, p.y)))
		mesh.set_uv(Vector2(pow(clampf(p.y / 3.7, 0.0, 1.0), 2.1) * 0.11, 0.0))
		mesh.add_vertex(p)

static func cloud(mesh: SurfaceTool, center: Vector3, crown_center: Vector3, axes: Vector3,
		palette: Color, noise: FastNoiseLite) -> void:
	var shape := SphereMesh.new()
	shape.radial_segments = 24
	shape.rings = 14
	shape.radius = 1.0
	shape.height = 2.0
	var arrays := shape.surface_get_arrays(0)
	for i in arrays[Mesh.ARRAY_INDEX]:
		var unit: Vector3 = arrays[Mesh.ARRAY_VERTEX][i]
		var sample := unit * 1.87 + center * 0.84
		var fold := noise.get_noise_3dv(sample)
		var edge := noise.get_noise_3dv(sample * 2.1)
		var p := center + unit * axes * (1.0 + fold * 0.23 + edge * 0.077)
		var lobe := (unit / axes).normalized()
		var whole := (p - crown_center).normalized()
		var normal := lobe.lerp(whole, 0.37).normalized()
		leaf_vertex(mesh, p, normal, palette.lerp(palette.darkened(0.19), clampf(0.46 - fold, 0.0, 1.0)),
			0.045 + float(maxf(0.0, unit.y)) * 0.025)

static func leaf_vertex(mesh: SurfaceTool, point: Vector3, normal: Vector3, tint: Color, detail: float) -> void:
	var height_weight := pow(clampf(point.y / 4.0, 0.0, 1.0), 2.1)
	mesh.set_normal(normal)
	mesh.set_color(tint)
	mesh.set_uv(Vector2(height_weight * 0.17, detail))
	mesh.add_vertex(point)

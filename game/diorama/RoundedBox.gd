extends RefCounted

# Project the faces of a subdivided box onto a rounded box with the same bounds.
static func build(size: Vector3, radius: float) -> ArrayMesh:
	var half := size * 0.5
	var roundness := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.92)
	var core := half - Vector3.ONE * roundness
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var up := Vector3.FORWARD if absf(normal.y) > 0.5 else Vector3.UP
		var tangent: Vector3 = up.cross(normal)
		var bitangent: Vector3 = normal.cross(tangent)
		var width := half.dot(tangent.abs())
		var height := half.dot(bitangent.abs())
		var u := _cuts(width, roundness)
		var v := _cuts(height, roundness)
		var center: Vector3 = normal * half.dot(normal.abs())
		for y in v.size() - 1:
			for x in u.size() - 1:
				for corner in [Vector2i(x, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1),
						Vector2i(x, y), Vector2i(x + 1, y + 1), Vector2i(x + 1, y)]:
					var point: Vector3 = center + tangent * u[corner.x] + bitangent * v[corner.y]
					var inside := point.clamp(-core, core)
					var outward := (point - inside).normalized()
					surface.set_normal(outward)
					surface.set_uv(Vector2(u[corner.x] / width, v[corner.y] / height) * 0.5 + Vector2.ONE * 0.5)
					surface.add_vertex(inside + outward * roundness)
	return surface.commit()

static func _cuts(half: float, radius: float) -> PackedFloat32Array:
	return PackedFloat32Array([
		-half, -half + radius * 0.44, -half + radius,
		half - radius, half - radius * 0.44, half,
	])

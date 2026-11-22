extends RefCounted

# A cupped five-petal flower and two lance-shaped leaves, shared by every sprig.
static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Vector3.ZERO
	var throat := Vector3(0.028, 0.21, 0.0)
	var stalk := Color("#45713c")
	for i in 3:
		var a := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 3.0)
		var b := a.rotated(Vector3.UP, TAU / 3.0)
		_triangle(st, root + a * 0.014, root + b * 0.014, throat + a * 0.009, stalk)
		_triangle(st, root + b * 0.014, throat + b * 0.009, throat + a * 0.009, stalk)
	for i in 2:
		var axis := Vector3.RIGHT.rotated(Vector3.UP, i * 2.5)
		var base := root.lerp(throat, 0.24 + i * 0.17)
		var mid := base + axis * 0.065 + Vector3.UP * 0.025
		var width := axis.cross(Vector3.UP) * 0.029
		var tip := base + axis * 0.14 + Vector3.UP * 0.065
		_triangle(st, base, mid + width, tip, stalk)
		_triangle(st, tip, mid - width, base, stalk)
	for i in 5:
		var axis := Vector3.RIGHT.rotated(Vector3.UP, TAU * i / 5.0)
		var edge := axis.cross(Vector3.UP) * 0.041
		var rim := throat + axis * 0.075 + Vector3.UP * 0.043
		var tip := rim + axis * 0.038
		_triangle(st, throat, rim + edge, rim - edge, Color("#df6c9e"))
		_triangle(st, rim - edge, rim + edge, tip, Color("#f39cb8"))
		var next := axis.rotated(Vector3.UP, TAU / 5.0)
		var center := throat + Vector3.UP * 0.021
		_triangle(st, center, center + axis * 0.032, center + next * 0.032, Color("#ffd36b"))
	st.index()
	return st.commit()

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for point: Vector3 in [a, b, c]:
		st.set_color(color)
		st.set_uv(Vector2(0.0, clampf(point.y / 0.25, 0.0, 1.0)))
		st.set_normal(Vector3.UP)
		st.add_vertex(point)

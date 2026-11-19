extends Node3D

const WALL := Color("#888c94")
const EDGE := Color("#b6bbc0")
const TIMBER := Color("#756864")
const ROUTE := Color("#cdd0cf")
const GOLD := Color("#f1bd70")
const BLUE := Color("#69c5ed")

const SHIP := Vector3(-15.9, 0, 5.1)
const GUILD := Vector3(-9.1, 0, 0.1)
const LEVER := Vector3(1.8, 0, -3.7)
const SMALL_GAP := -3.7
const BIG_GAP := 3.1
const CRAB_HOME := Vector3(9.0, 0, -0.15)
const ARENA := Vector3(5.0, 0, 2.4)

var gate: MeshInstance3D

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

func mesh_at(parent: Node3D, pos: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = pos
	return instance

func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := mesh_at(parent, pos, mesh, color)
	instance.scale = size
	return instance

func label_at(parent: Node3D, pos: Vector3, words: String, color := Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.modulate = color
	label.font_size = 42
	label.outline_size = 10
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	label.position = pos
	return label

func marker(pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.46
	mesh.bottom_radius = 0.46
	mesh.height = 0.035
	return mesh_at(self, pos + Vector3.UP * 0.025, mesh, color)

func build() -> void:
	box(self, Vector3(-7, -0.65, 0), Vector3(15, 1.3, 14), WALL)
	box(self, Vector3(6.75, -0.65, 0), Vector3(12.5, 1.3, 14), Color("#777d78"))
	box(self, Vector3(-16, -0.62, 0), Vector3(9, 0.3, 16), Color("#486f7d"))
	box(self, SHIP + Vector3(0, -0.32, 0), Vector3(3.8, 0.5, 3.2), TIMBER)
	box(self, Vector3(-14.45, -0.08, 5.1), Vector3(1.9, 0.16, 2.4), Color("#ad9a81"))
	box(self, Vector3(-17.5, 0.29, 5.1), Vector3(0.36, 0.58, 3.2), TIMBER)
	for z in [3.55, 6.65]:
		box(self, Vector3(-16.25, 0.25, z), Vector3(2.85, 0.5, 0.27), TIMBER, true)
	box(self, Vector3(-14.47, 0.6, -1.8), Vector3(0.15, 1.2, 10.7), WALL, true)
	for z in [-7.1, 7.1]:
		box(self, Vector3(-2.3, 0.35, z), Vector3(29.6, 0.7, 0.35), WALL, true)
	box(self, Vector3(13.12, 0.55, 0), Vector3(0.35, 1.1, 14.4), WALL, true)
	box(self, Vector3(-18.02, 0.55, 5.1), Vector3(0.35, 1.1, 3.8), TIMBER, true)
	box(self, Vector3(-16.25, 0.55, 6.96), Vector3(3.6, 1.1, 0.35), WALL, true)
	box(self, Vector3(-16.25, 0.55, 3.47), Vector3(3.6, 1.1, 0.2), WALL, true)

	box(self, Vector3(-6.9, 0.015, 3.1), Vector3(14.8, 0.03, 2.8), ROUTE)
	box(self, Vector3(-9.1, 0.018, 1.4), Vector3(3.5, 0.035, 4.7), ROUTE)
	box(self, Vector3(-1.9, 0.015, -0.3), Vector3(2.1, 0.03, 8.7), ROUTE)
	box(self, Vector3(0, 0.015, BIG_GAP), Vector3(4.1, 0.03, 2.8), ROUTE)
	box(self, Vector3(7.9, 0.025, 0), Vector3(9.5, 0.05, 9.7), Color("#a9aaa5"))

	building(Vector3(-11.45, 0, -3.1), Vector3(5.15, 2.65, 3.55), Color("#8e8786"))
	building(Vector3(-6.4, 0, -4.65), Vector3(3.65, 2.15, 3.05), Color("#938e8a"))
	building(Vector3(-4.5, 0, 5.45), Vector3(3.8, 1.8, 1.95), Color("#827a79"))
	box(self, Vector3(-9.4, 1.22, -1.31), Vector3(1.48, 2.04, 0.13), Color("#434752"))
	box(self, Vector3(-8.27, 1.75, -1.14), Vector3(0.60, 1.17, 0.10), BLUE)
	box(self, Vector3(-6.4, 1.48, -2.76), Vector3(3.25, 0.18, 0.94), Color("#aa8178"))
	box(self, Vector3(-6.4, 0.42, -2.40), Vector3(2.65, 0.84, 0.70), TIMBER, true)
	box(self, Vector3(-13.1, 0.46, 1.35), Vector3(1.20, 0.92, 1.00), TIMBER, true)
	box(self, Vector3(-12.1, 0.33, 0.8), Vector3(0.64, 0.66, 0.75), TIMBER, true)
	label_at(self, Vector3(-11.1, 3.48, -1.0), "公會", BLUE)
	label_at(self, Vector3(-6.4, 2.88, -2.65), "食堂")
	label_at(self, Vector3(-15.85, 0.80, 6.75), "貨船")

	# The 1.4 m side opening admits the 0.6 m player and blocks the 1.64 m beast.
	for span in [Vector2(-7.0, -4.4), Vector2(-3.0, 1.45), Vector2(4.75, 7.0)]:
		box(self, Vector3(0, 1.05, (span.x + span.y) / 2.0),
			Vector3(0.72, 2.10, span.y - span.x), WALL, true)
	box(self, Vector3(0, 1.53, SMALL_GAP), Vector3(0.74, 0.25, 1.42), EDGE)
	box(self, Vector3(0, 2.43, BIG_GAP), Vector3(0.83, 0.40, 3.38), EDGE)
	gate = box(self, Vector3(0, 1.06, BIG_GAP), Vector3(0.42, 2.12, 3.30), TIMBER, true)
	box(self, LEVER + Vector3(0.27, 0.33, 0), Vector3(0.36, 0.66, 0.4), WALL)
	box(self, LEVER + Vector3(0.27, 0.78, 0), Vector3(0.12, 0.32, 0.13), GOLD)
	label_at(self, Vector3(0.02, 1.77, SMALL_GAP), "側門")
	label_at(self, Vector3(0.02, 2.8, BIG_GAP), "獸伴閘門")
	box(self, Vector3(0.01, 0.021, SMALL_GAP), Vector3(2.65, 0.04, 1.25), GOLD)
	marker(GUILD, BLUE)
	marker(LEVER, GOLD)
	label_at(self, Vector3(9.7, 0.35, -4.35), "潮灘")

func building(pos: Vector3, size: Vector3, color: Color) -> void:
	box(self, pos + Vector3.UP * size.y / 2.0, size, color, true)
	box(self, pos + Vector3.UP * (size.y + 0.14), Vector3(size.x + 0.25, 0.28, size.z + 0.32), TIMBER)

extends Node3D

const RoundedBoxMesh := preload("res://diorama/RoundedBox.gd")

const ROOF_WIDTH := 3.75
const ROOF_RUN := 1.67
const EAVE_HEIGHT := 1.98
const RIDGE_HEIGHT := 3.13

var pieces: Dictionary[Vector3, Mesh] = {}

func _ready() -> void:
	var dark_wood := _mat("#633a25")
	var board := _mat("#af7142")
	var base_board := _mat("#8d6d48")
	var cream := _mat("#e9ca98")
	var masonry := _mat("#918475")
	var glass := _mat("#475d65")
	glass.roughness = 0.38
	glass.emission_enabled = true
	glass.emission = Color("#ffbc64")
	glass.emission_energy_multiplier = 0.23
	_box(Vector3(3.45, 0.30, 3.07), Vector3(0, 0.13, 0), masonry)
	_box(Vector3(3.18, 1.78, 2.78), Vector3(0, 1.01, 0), dark_wood)
	for row in 9:
		var y := 0.28 + row * 0.19
		var board_finish := base_board if row < 2 else board
		for side in [-1, 1]:
			_box(Vector3(3.22, 0.174, 0.09), Vector3(0, y, side * 1.39), board_finish)
			_box(Vector3(0.09, 0.174, 2.75), Vector3(side * 1.59, y, 0), board_finish)
	for x in [-1.57, 1.57]:
		for z in [-1.39, 1.39]:
			_box(Vector3(0.15, 1.86, 0.15), Vector3(x, 1.04, z), dark_wood)
	for side in [-1, 1]:
		_build_gable(side, board, cream)
		_window(Vector3(-1.06, 1.19, side * 1.46), 0, glass, cream)
		_window(Vector3(side * 1.65, 1.19, -0.35), PI / 2.0, glass, cream)
	_box(Vector3(0.80, 1.32, 0.12), Vector3(0.66, 0.87, 1.46), dark_wood)
	_box(Vector3(0.60, 1.18, 0.13), Vector3(0.66, 0.86, 1.53), board)
	_box(Vector3(0.10, 0.12, 0.09), Vector3(0.81, 0.83, 1.62), cream)
	_box(Vector3(1.3, 0.14, 0.46), Vector3(0.66, 0.14, 1.73), masonry)
	_box(Vector3(1.13, 0.14, 0.38), Vector3(0.66, 0.26, 1.59), masonry)
	_box(Vector3(0.49, 1.29, 0.48), Vector3(0.99, 3.03, -0.49), masonry)
	_box(Vector3(0.61, 0.12, 0.59), Vector3(0.99, 3.70, -0.49), cream)
	_box(Vector3(0.35, 0.02, 0.33), Vector3(0.99, 3.77, -0.49), dark_wood)
	_build_roof(cream)
	_batch_static_details()

func _batch_static_details() -> void:
	var surfaces: Dictionary[Material, SurfaceTool] = {}
	var details: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for child in details:
		var part := child as MeshInstance3D
		var material := part.material_override
		if material is ShaderMaterial:
			continue
		if not surfaces.has(material):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			builder.set_material(material)
			surfaces[material] = builder
		var local := global_transform.affine_inverse() * part.global_transform
		surfaces[material].append_from(part.mesh, 0, local)
		part.queue_free()
	var merged := ArrayMesh.new()
	for builder in surfaces.values():
		builder.commit(merged)
	var structure := MeshInstance3D.new()
	structure.mesh = merged
	add_child(structure)

func _build_gable(side: int, board: Material, trim: Material) -> void:
	for row in 6:
		var height := (row + 0.5) / 6.0
		_box(Vector3(0.10, 0.186, 2.0 * (1.43 * (1.0 - height))), Vector3(side * 1.57, EAVE_HEIGHT + 1.12 * height, 0), board)
	var pitch := atan2(RIDGE_HEIGHT - EAVE_HEIGHT, ROOF_RUN)
	for direction in [-1, 1]:
		_box(Vector3(0.12, 0.13, 2.04), Vector3(side * 1.86, 2.57, direction * ROOF_RUN * 0.5), trim, direction * pitch)

func _build_roof(trim: Material) -> void:
	var pitch := atan2(RIDGE_HEIGHT - EAVE_HEIGHT, ROOF_RUN)
	var length := Vector2(ROOF_RUN, RIDGE_HEIGHT - EAVE_HEIGHT).length()
	var ridge := _mat("#783527")
	var tiles := ShaderMaterial.new()
	tiles.shader = preload("res://diorama/shaders/diorama_roof.gdshader")
	tiles.set_shader_parameter("clay_base", Color("#923821"))
	tiles.set_shader_parameter("clay_light", Color("#ce6843"))
	for side in [-1, 1]:
		var at := Vector3(0, (RIDGE_HEIGHT + EAVE_HEIGHT) * 0.5, side * ROOF_RUN * 0.5)
		_box(Vector3(ROOF_WIDTH, 0.16, length), at, tiles, side * pitch)
		_box(Vector3(ROOF_WIDTH + 0.09, 0.12, 0.12), Vector3(0, EAVE_HEIGHT, side * ROOF_RUN), trim)
	_box(Vector3(ROOF_WIDTH + 0.07, 0.14, 0.19), Vector3(0, RIDGE_HEIGHT + 0.10, 0), ridge)

func _window(at: Vector3, yaw: float, glass: Material, frame: Material) -> void:
	var window := Node3D.new()
	window.position = at
	window.rotation.y = yaw
	add_child(window)
	_window_piece(window, Vector3(0.58, 0.55, 0.07), Vector3.ZERO, frame)
	_window_piece(window, Vector3(0.43, 0.41, 0.09), Vector3.ZERO, glass)
	_window_piece(window, Vector3(0.038, 0.46, 0.10), Vector3.ZERO, frame)
	_window_piece(window, Vector3(0.46, 0.036, 0.10), Vector3.ZERO, frame)

func _window_piece(window: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var piece := _box(size, at, material)
	piece.reparent(window, false)

func _box(size: Vector3, at: Vector3, material: Material, pitch := 0.0) -> MeshInstance3D:
	if not pieces.has(size):
		pieces[size] = RoundedBoxMesh.build(size, 0.085)
	var node := MeshInstance3D.new()
	node.mesh = pieces[size]
	node.material_override = material
	node.position = at
	node.rotation.x = pitch
	add_child(node)
	return node

func _mat(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.73
	material.metallic_specular = 0.23
	return material

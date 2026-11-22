extends Node3D

const Kit := preload("res://diorama/foliage/FoliageKit.gd")
var vegetation: ShaderMaterial
var wind_enabled := true

func _ready() -> void:
	_add_lights()
	vegetation = Kit.finish()
	var meadow := PlaneMesh.new()
	meadow.size = Vector2(80.0, 70.0)
	_place(meadow, Vector3(0.0, -0.012, 0.0), _mat(Color("#8ea162")))

	_place(Kit.broadleaf(34, Color("#217450")), Vector3(-2.5, 0, -1.1), vegetation)
	_place(Kit.broadleaf(89, Color("#8caa37")), Vector3(2.1, 0, -1.65), vegetation)
	_place(Kit.conifer(77, Color("#27674f")), Vector3(-0.2, 0, 0.48), vegetation)
	_place(Kit.conifer(118, Color("#386f42")), Vector3(4.45, 0, -1.1), vegetation).scale = Vector3.ONE * 0.80

	var rng := RandomNumberGenerator.new()
	rng.seed = 3418
	for i in 3:
		var grass := Kit.grass(47 + i, Color("#849a46").lerp(Color("#547f4d"), float(i) * 0.31))
		var patches := MultiMesh.new()
		patches.transform_format = MultiMesh.TRANSFORM_3D
		patches.mesh = grass
		patches.instance_count = 40
		for j in patches.instance_count:
			var strip := Vector2(-3.75 + j % 3 * 2.72, 1.7 + (j % 3) * 0.16)
			var at := strip + Vector2(rng.randf_range(-0.75, 0.92), rng.randf_range(-0.5, 0.50))
			var size := rng.randf_range(0.64, 1.25)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
			patches.set_instance_transform(j, Transform3D(basis, Vector3(at.x, 0, at.y)))
		var grass_group := MultiMeshInstance3D.new()
		grass_group.multimesh = patches
		grass_group.material_override = vegetation
		grass_group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(grass_group)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	add_child(camera)
	camera.position = Vector3(5.15, 6.9, 11.2)
	camera.look_at(Vector3(0.2, 1.36, 0.0))
	camera.current = true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		wind_enabled = not wind_enabled
		vegetation.set_shader_parameter("wind_strength", 0.75 if wind_enabled else 0.0)

func _place(mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

func _add_lights() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("#9abca4")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("#aac2d8")
	sky.ambient_light_energy = 0.59
	sky.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.environment = sky
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-49, -39, 0)
	sun.light_color = Color("#fff1cc")
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.shadow_blur = 2.3
	add_child(sun)

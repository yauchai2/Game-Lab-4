extends Node3D

var snow: GPUParticles3D
var rain: GPUParticles3D
var current_mode := 0

func _ready() -> void:
	snow = _make_weather(true)
	rain = _make_weather(false)

func follow_weather(mode: int, actor_position: Vector3) -> void:
	global_position = Vector3(actor_position.x * 0.42, 9.7, actor_position.z * 0.42)
	if mode == current_mode:
		return
	current_mode = mode
	_set_active(snow, mode == 1)
	_set_active(rain, mode == 2)

func _set_active(effect: GPUParticles3D, active: bool) -> void:
	effect.visible = active
	if active:
		effect.restart()
	effect.emitting = active

func _make_weather(is_snow: bool) -> GPUParticles3D:
	var effect := GPUParticles3D.new()
	effect.amount = 112 if is_snow else 96
	effect.lifetime = 4.2 if is_snow else 0.84
	effect.local_coords = false
	effect.emitting = false
	effect.visible = false
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.visibility_aabb = AABB(Vector3(-25, -15, -25), Vector3(50, 20, 50))

	var travel := ParticleProcessMaterial.new()
	travel.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	travel.emission_box_extents = Vector3(17.0, 0.9, 13.5)
	travel.direction = Vector3(0.18, -1.0, 0.04)
	travel.spread = 10.0 if is_snow else 4.0
	travel.initial_velocity_min = 1.95 if is_snow else 11.5
	travel.initial_velocity_max = 2.5 if is_snow else 14.0
	travel.gravity = Vector3(0.08, -0.13, 0.02)
	travel.scale_min = 0.58
	travel.scale_max = 1.14
	travel.particle_flag_align_y = not is_snow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.79, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.0), Color.WHITE,
		Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	travel.color_ramp = fade_texture
	effect.process_material = travel

	var shape := BoxMesh.new()
	shape.size = Vector3(0.107, 0.089, 0.10) if is_snow else Vector3(0.047, 0.49, 0.047)
	var finish := StandardMaterial3D.new()
	finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finish.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finish.vertex_color_use_as_albedo = true
	finish.albedo_color = Color(0.92, 0.96, 0.99, 0.78) if is_snow else Color(0.64, 0.79, 0.90, 0.49)
	shape.material = finish
	effect.draw_pass_1 = shape
	add_child(effect)
	return effect

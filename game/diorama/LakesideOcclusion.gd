extends Node3D

const FADE_FINISH := preload("res://diorama/shaders/diorama_fade_finish.gdshader")

var candidates: Array[Dictionary] = []

func watch(prop: Node3D, local_bounds: AABB) -> void:
	var finishes: Array[ShaderMaterial] = []
	var meshes: Array[MeshInstance3D] = []
	var shadow_modes: Array[int] = []
	var converted: Dictionary = {}
	for descendant in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := descendant as MeshInstance3D
		if mesh_node.is_queued_for_deletion() or mesh_node.mesh == null:
			continue
		meshes.append(mesh_node)
		shadow_modes.append(mesh_node.cast_shadow)
		if mesh_node.material_override is StandardMaterial3D:
			mesh_node.material_override = _fade_finish(mesh_node.material_override, converted)
			finishes.append(mesh_node.material_override)
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var original := mesh_node.get_active_material(surface)
			if original is StandardMaterial3D:
				var finish := _fade_finish(original, converted)
				mesh_node.set_surface_override_material(surface, finish)
				finishes.append(finish)
			elif original is ShaderMaterial:
				finishes.append(original)
	candidates.append({
		"prop": prop, "bounds": local_bounds, "finishes": finishes,
		"meshes": meshes, "shadow_modes": shadow_modes, "opacity": 1.0,
	})

func _fade_finish(original: StandardMaterial3D, converted: Dictionary) -> ShaderMaterial:
	if converted.has(original):
		return converted[original]
	var finish := ShaderMaterial.new()
	finish.shader = FADE_FINISH
	finish.set_shader_parameter("finish_color", original.albedo_color)
	finish.set_shader_parameter("finish_roughness", original.roughness)
	finish.set_shader_parameter("finish_specular", original.metallic_specular)
	if original.emission_enabled:
		finish.set_shader_parameter("glow_color", original.emission)
		finish.set_shader_parameter("glow_energy", original.emission_energy_multiplier)
	converted[original] = finish
	return finish

func update_view(camera: Camera3D, sight: Vector3, delta: float) -> void:
	for item in candidates:
		var prop: Node3D = item["prop"]
		if not is_instance_valid(prop):
			continue
		var inverse := prop.global_transform.affine_inverse()
		var box: AABB = item["bounds"]
		var obscures := box.intersects_segment(inverse * camera.global_position, inverse * sight) != null
		var target := 0.14 if obscures else 1.0
		var old: float = item["opacity"]
		var opacity := move_toward(old, target, delta * (5.5 if obscures else 3.8))
		if is_equal_approx(old, opacity):
			continue
		item["opacity"] = opacity
		for finish in item["finishes"]:
			finish.set_shader_parameter("cover_opacity", opacity)
		if (old >= 0.99) != (opacity >= 0.99):
			for index in item["meshes"].size():
				var mesh_node: MeshInstance3D = item["meshes"][index]
				mesh_node.cast_shadow = item["shadow_modes"][index] if opacity >= 0.99 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

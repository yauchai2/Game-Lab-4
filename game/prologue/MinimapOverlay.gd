extends Control

# PoE 2-style Translucent Fog-of-War Minimap (press [Tab] to toggle Corner / Large Center Overlay)
const CELL_SIZE := 6.0

var map_bounds := Rect2(-40.0, -30.0, 80.0, 60.0)
var explored: Dictionary = {} # Vector2i -> true
var expanded := false
var player_world_pos := Vector3.ZERO
var wolf_world_pos := Vector3.ZERO
var markers: Array[Dictionary] = [] # {"pos": Vector3, "kind": "mob"|"rare"|"unique"|"boss"|"checkpoint"|"exit", "label": String}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_layout()

func configure_bounds(bounds: Rect2) -> void:
	map_bounds = bounds
	explored.clear()
	queue_redraw()

func toggle_expanded() -> void:
	expanded = not expanded
	_apply_layout()
	queue_redraw()

func _apply_layout() -> void:
	if expanded:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		offset_left = -260
		offset_right = 260
		offset_top = -185
		offset_bottom = 185
	else:
		set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -210
		offset_right = -18
		offset_top = 132
		offset_bottom = 266

func update_state(p_pos: Vector3, w_pos: Vector3, marker_list: Array[Dictionary], reveal_radius := 16.0) -> void:
	player_world_pos = p_pos
	wolf_world_pos = w_pos
	markers = marker_list
	var cx := int(floor(p_pos.x / CELL_SIZE))
	var cz := int(floor(p_pos.z / CELL_SIZE))
	var r_cells := int(ceil(reveal_radius / CELL_SIZE))
	for dx in range(-r_cells, r_cells + 1):
		for dz in range(-r_cells, r_cells + 1):
			if Vector2(float(dx), float(dz)).length() * CELL_SIZE <= reveal_radius:
				var cell := Vector2i(cx + dx, cz + dz)
				if not explored.has(cell):
					explored[cell] = true
	queue_redraw()

func _is_revealed(world_pos: Vector3) -> bool:
	var cell := Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.z / CELL_SIZE)))
	return explored.has(cell)

func _world_to_map(world_pos: Vector3) -> Vector2:
	var pad := 12.0
	var usable := size - Vector2(pad * 2.0, pad * 2.0)
	var nx := clampf((world_pos.x - map_bounds.position.x) / maxf(map_bounds.size.x, 1.0), 0.0, 1.0)
	var nz := clampf((world_pos.z - map_bounds.position.y) / maxf(map_bounds.size.y, 1.0), 0.0, 1.0)
	return Vector2(pad + nx * usable.x, pad + nz * usable.y)

func _draw() -> void:
	var bg_col := Color(0.06, 0.09, 0.16, 0.56 if expanded else 0.74)
	var border_col := Color("#f5c65b") if expanded else Color(0.85, 0.75, 0.55, 0.65)
	draw_rect(Rect2(Vector2.ZERO, size), bg_col, true)
	draw_rect(Rect2(Vector2.ZERO, size), border_col, false, 2.0)

	# Draw Fog-of-War explored footprint
	var pad := 12.0
	var usable := size - Vector2(pad * 2.0, pad * 2.0)
	var cell_px := Vector2(
		maxf(3.0, (CELL_SIZE / maxf(map_bounds.size.x, 1.0)) * usable.x + 1.5),
		maxf(3.0, (CELL_SIZE / maxf(map_bounds.size.y, 1.0)) * usable.y + 1.5)
	)
	for cell_var in explored.keys():
		var cell: Vector2i = cell_var
		var wp := Vector3(float(cell.x) * CELL_SIZE + CELL_SIZE * 0.5, 0.0, float(cell.y) * CELL_SIZE + CELL_SIZE * 0.5)
		if wp.x < map_bounds.position.x or wp.x > map_bounds.end.x or wp.z < map_bounds.position.y or wp.z > map_bounds.end.y:
			continue
		var mp := _world_to_map(wp)
		draw_rect(Rect2(mp - cell_px * 0.5, cell_px), Color(0.45, 0.58, 0.72, 0.34), true)

	# Draw discovered POIs, packs, rares, hidden uniques, boss & checkpoints
	for m in markers:
		var m_pos: Vector3 = m["pos"]
		var kind: String = String(m["kind"])
		var revealed := _is_revealed(m_pos)
		if kind in ["mob", "rare", "unique"] and not revealed:
			continue
		if kind == "boss" and not revealed and not expanded:
			continue
		var mp := _world_to_map(m_pos)
		match kind:
			"mob":
				draw_circle(mp, 2.2 if not expanded else 3.2, Color("#f26b6b"))
			"rare":
				draw_circle(mp, 3.8 if not expanded else 5.5, Color("#ffd659"))
			"unique":
				draw_circle(mp, 5.2 if not expanded else 7.5, Color("#ff7b3b"))
				draw_arc(mp, 7.0 if not expanded else 10.0, 0.0, TAU, 16, Color("#ffd659"), 1.5)
			"boss":
				draw_circle(mp, 5.5 if not expanded else 8.0, Color("#e03c3c"))
				draw_arc(mp, 7.5 if not expanded else 11.0, 0.0, TAU, 16, Color.WHITE, 1.6)
			"checkpoint":
				draw_circle(mp, 3.6 if not expanded else 5.0, Color("#66eae6"))
			"exit":
				draw_circle(mp, 3.4 if not expanded else 4.8, Color("#98ffbd"))

	# Wolf & Player markers
	var wp_2d := _world_to_map(wolf_world_pos)
	draw_circle(wp_2d, 3.0 if not expanded else 4.2, Color("#8cc8ff"))
	var pp_2d := _world_to_map(player_world_pos)
	draw_circle(pp_2d, 4.2 if not expanded else 6.0, Color.WHITE)
	draw_arc(pp_2d, 6.0 if not expanded else 8.5, 0.0, TAU, 14, Color("#66eae6"), 1.6)

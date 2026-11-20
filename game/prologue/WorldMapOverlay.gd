extends Control

# PoE 2-style Hand-Crafted Interactive World Map Overlay (Press [U] or interact with any Waypoint)
# Minimalist @amelicart warm parchment & matte gouache aesthetic

var current_scene_key := ""
var hovered_id := ""
var node_buttons: Dictionary = {}

const WORLD_NODES := [
	{
		"id": "clearing",
		"title": "營火林緣",
		"subtitle": "序幕起點 · 迷路小兵與釣魚碼頭",
		"scene": "res://prologue/CampfireClearing.tscn",
		"spawn": "from_town",
		"pos_norm": Vector2(0.18, 0.56),
		"kind": "wild",
		"playable": true,
	},
	{
		"id": "town",
		"title": "雲丘停戰營地",
		"subtitle": "第一幕主城 · 傳送石陣 / 生命清泉 / 造裝工坊 / 商人",
		"scene": "res://prologue/CloudhillTown.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.36, 0.44),
		"kind": "town",
		"playable": true,
	},
	{
		"id": "road",
		"title": "雲海古道與高地",
		"subtitle": "大型荒野 (150m×96m) · Boss 稻草人哨長 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/CloudhillRoad.tscn",
		"spawn": "from_town",
		"pos_norm": Vector2(0.58, 0.40),
		"kind": "boss_zone",
		"playable": true,
	},
	{
		"id": "forest",
		"title": "翡翠天梯古林",
		"subtitle": "超大型密林 (160m×104m) · Boss 翡翠樹王 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/EmeraldForest.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.73, 0.66),
		"kind": "boss_zone",
		"playable": true,
	},
	{
		"id": "clocktower",
		"title": "舊軍鐘樓哨所",
		"subtitle": "超大型要塞 (164m×106m) · Boss 重裝鐵鐘騎士 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/ClocktowerOutpost.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.76, 0.25),
		"kind": "boss_zone",
		"playable": true,
	},
	{
		"id": "harbor",
		"title": "沉霧燈塔港",
		"subtitle": "第一幕終章 (170m×110m) · Boss 迷霧大提督 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/MistyHarbor.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.89, 0.48),
		"kind": "boss_zone",
		"playable": true,
	},
]

const WORLD_EDGES := [
	["clearing", "town"],
	["town", "road"],
	["road", "forest"],
	["road", "clocktower"],
	["forest", "harbor"],
	["clocktower", "harbor"],
]

var _panel: Panel
var _map_canvas: Control
var _info_title: Label
var _info_desc: Label
var _info_status: Label
var _travel_btn: Button
var _selected_node: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Soft warm dark backdrop
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.10, 0.16, 0.72)
	add_child(dim)

	# Centered Parchment Gouache Map Frame
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -460
	_panel.offset_right = 460
	_panel.offset_top = -280
	_panel.offset_bottom = 280
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f4ebd9")
	sb.border_color = Color("#c89b54")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	# Header
	var title_lbl := Label.new()
	title_lbl.position = Vector2(28, 18)
	title_lbl.text = "✦ 第一幕世界地圖：雲丘停戰邊境"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color("#2b3648"))
	_panel.add_child(title_lbl)

	var hint_lbl := Label.new()
	hint_lbl.position = Vector2(28, 48)
	hint_lbl.text = "點擊已解鎖節點即可傳送 · ★ 傳送點   ！主線目標   💀 未討伐頭目   ✦ 已勸退"
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color("#5c6473"))
	_panel.add_child(hint_lbl)

	var close_btn := Button.new()
	close_btn.position = Vector2(842, 18)
	close_btn.custom_minimum_size = Vector2(58, 34)
	close_btn.text = "✕ [U]"
	close_btn.pressed.connect(close_map)
	_panel.add_child(close_btn)

	# Interactive Map Canvas
	_map_canvas = Control.new()
	_map_canvas.position = Vector2(24, 78)
	_map_canvas.size = Vector2(872, 354)
	_map_canvas.draw.connect(_draw_map_canvas)
	_panel.add_child(_map_canvas)

	# Node buttons overlay
	for n in WORLD_NODES:
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(148, 54)
		var p := Vector2(float(n["pos_norm"].x) * _map_canvas.size.x, float(n["pos_norm"].y) * _map_canvas.size.y)
		btn.position = p - Vector2(74, 27)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var node_data: Dictionary = n
		btn.pressed.connect(func() -> void: _select_node(node_data))
		btn.mouse_entered.connect(func() -> void:
			hovered_id = String(node_data["id"])
			_map_canvas.queue_redraw()
		)
		btn.mouse_exited.connect(func() -> void:
			hovered_id = ""
			_map_canvas.queue_redraw()
		)
		_map_canvas.add_child(btn)
		node_buttons[String(n["id"])] = btn

	# Bottom Info & Fast-Travel Footer Bar
	var footer := Panel.new()
	footer.position = Vector2(24, 444)
	footer.size = Vector2(872, 96)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#e8dcc4")
	fsb.border_color = Color("#c89b54")
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(8)
	footer.add_theme_stylebox_override("panel", fsb)
	_panel.add_child(footer)

	_info_title = Label.new()
	_info_title.position = Vector2(18, 12)
	_info_title.add_theme_font_size_override("font_size", 19)
	_info_title.add_theme_color_override("font_color", Color("#222b38"))
	footer.add_child(_info_title)

	_info_desc = Label.new()
	_info_desc.position = Vector2(18, 42)
	_info_desc.add_theme_font_size_override("font_size", 14)
	_info_desc.add_theme_color_override("font_color", Color("#4e596b"))
	footer.add_child(_info_desc)

	_info_status = Label.new()
	_info_status.position = Vector2(18, 66)
	_info_status.add_theme_font_size_override("font_size", 13)
	_info_status.add_theme_color_override("font_color", Color("#8c5220"))
	footer.add_child(_info_status)

	_travel_btn = Button.new()
	_travel_btn.position = Vector2(684, 24)
	_travel_btn.custom_minimum_size = Vector2(168, 48)
	_travel_btn.text = "✦ 傳送至此區"
	_travel_btn.pressed.connect(_on_travel_pressed)
	footer.add_child(_travel_btn)

func open_map(scene_key: String) -> void:
	current_scene_key = scene_key
	visible = true
	# Default select current scene
	for n in WORLD_NODES:
		if String(n["id"]) == scene_key:
			_select_node(n)
			break
	if _selected_node.is_empty():
		_select_node(WORLD_NODES[1])
	_map_canvas.queue_redraw()

func close_map() -> void:
	visible = false

func toggle_map(scene_key: String) -> bool:
	if visible:
		close_map()
	else:
		open_map(scene_key)
	return visible

func _select_node(n: Dictionary) -> void:
	_selected_node = n
	_info_title.text = String(n["title"])
	_info_desc.text = String(n["subtitle"])
	var nid := String(n["id"])
	var playable := bool(n["playable"])
	if nid == "road":
		var boss_txt := "✦ 稻草人哨長（已勸退）" if PrologueState.boss_retired else "💀 稻草人哨長（尚在加班）"
		var uniq_cnt := PrologueState.uniques_defeated.size()
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [boss_txt, uniq_cnt]
	elif nid == "forest":
		var fboss_txt := "✦ 翡翠樹王（已退休開果茶亭）" if PrologueState.emerald_boss_retired else "💀 翡翠樹王（仍在備戰攻城）"
		var funiq_cnt := PrologueState.emerald_uniques_defeated.size()
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [fboss_txt, funiq_cnt]
	elif nid == "clocktower":
		var cboss_txt := "✦ 重裝鐵鐘騎士（已退休開咖啡座）" if PrologueState.clocktower_boss_retired else "💀 重裝鐵鐘騎士（仍在整點敲鐘）"
		var cuniq_cnt := PrologueState.clocktower_uniques_defeated.size()
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [cboss_txt, cuniq_cnt]
	elif nid == "harbor":
		var hboss_txt := "✦ 迷霧大提督（已退休開海鮮燒烤）" if PrologueState.harbor_boss_retired else "💀 迷霧大提督（仍在開造霧機）"
		var huniq_cnt := PrologueState.harbor_uniques_defeated.size()
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [hboss_txt, huniq_cnt]
	elif nid == "town":
		_info_status.text = "安全主城 · 免費回血泉水 / 造裝工坊 / 商人 / 任務書記官"
	elif nid == "clearing":
		_info_status.text = "序幕起點 · 營火烤魚 / 湖畔垂釣 / 西北青苔洞"
	else:
		_info_status.text = "後續章節區域（已完成世界地圖規劃，待實裝）"

	if not playable:
		_travel_btn.disabled = true
		_travel_btn.text = "尚未開放"
	elif nid == current_scene_key:
		_travel_btn.disabled = true
		_travel_btn.text = "目前所在位置"
	else:
		_travel_btn.disabled = false
		_travel_btn.text = "✦ 傳送至此區"
	_map_canvas.queue_redraw()

func _on_travel_pressed() -> void:
	if _selected_node.is_empty() or not bool(_selected_node["playable"]):
		return
	var target_scene := String(_selected_node["scene"])
	var target_spawn := String(_selected_node["spawn"])
	var target_title := String(_selected_node["title"])
	close_map()
	PrologueState.transition_to(target_scene, target_spawn, target_title)

func _node_pos(nid: String) -> Vector2:
	for n in WORLD_NODES:
		if String(n["id"]) == nid:
			return Vector2(float(n["pos_norm"].x) * _map_canvas.size.x, float(n["pos_norm"].y) * _map_canvas.size.y)
	return Vector2.ZERO

func _draw_map_canvas() -> void:
	var rect := Rect2(Vector2.ZERO, _map_canvas.size)
	# Painted ocean & coastal landmass silhouettes (@amelicart gouache palette)
	_map_canvas.draw_rect(rect, Color("#8cc4c9"), true)
	_map_canvas.draw_rect(rect, Color("#b8955e"), false, 2.0)

	# Soft stylized landmass blobs
	var west_land := PackedVector2Array([
		Vector2(65, 130), Vector2(180, 65), Vector2(410, 58), Vector2(565, 92),
		Vector2(540, 265), Vector2(360, 310), Vector2(140, 285), Vector2(55, 220)
	])
	_map_canvas.draw_colored_polygon(west_land, Color("#e4cc92"))
	var east_land := PackedVector2Array([
		Vector2(555, 78), Vector2(765, 45), Vector2(835, 145), Vector2(810, 245),
		Vector2(685, 315), Vector2(560, 260)
	])
	_map_canvas.draw_colored_polygon(east_land, Color("#a4c878"))
	# Decorative pink wildflower meadow & canyon river
	_map_canvas.draw_circle(Vector2(265, 210), 42.0, Color(0.96, 0.56, 0.68, 0.42))
	_map_canvas.draw_line(Vector2(512, 48), Vector2(552, 315), Color("#58b2d6"), 14.0, true)

	# Draw dashed ink trails between nodes
	for edge in WORLD_EDGES:
		var a := _node_pos(String(edge[0]))
		var b := _node_pos(String(edge[1]))
		var steps := 14
		for i in range(steps):
			if i % 2 == 1:
				continue
			var p0 := a.lerp(b, float(i) / float(steps))
			var p1 := a.lerp(b, float(i + 1) / float(steps))
			_map_canvas.draw_line(p0, p1, Color("#4a3b2c", 0.72), 2.5, true)

	# Draw nodes
	var font := ThemeDB.fallback_font
	for n in WORLD_NODES:
		var nid := String(n["id"])
		var p := _node_pos(nid)
		var is_cur := nid == current_scene_key
		var is_sel := not _selected_node.is_empty() and String(_selected_node["id"]) == nid
		var is_hov := nid == hovered_id
		var playable := bool(n["playable"])

		var fill := Color("#4ecdc4") if String(n["kind"]) == "town" else (Color("#f5b82e") if playable else Color("#8d96a3"))
		var rad := 16.0 if String(n["kind"]) == "town" else 13.0
		if is_sel or is_hov:
			_map_canvas.draw_circle(p, rad + 6.0, Color(1.0, 0.85, 0.35, 0.42))
		if is_cur:
			_map_canvas.draw_arc(p, rad + 9.0, 0.0, TAU, 24, Color("#ffffff"), 2.5)
		_map_canvas.draw_circle(p, rad, fill)
		_map_canvas.draw_arc(p, rad, 0.0, TAU, 24, Color("#2b3648"), 2.2)

		# Status badge (Quest / Boss)
		var badge := ""
		if nid == "town" and not PrologueState.has_sword:
			badge = "！"
		elif nid == "road":
			badge = "✦" if PrologueState.boss_retired else "💀"
		elif nid == "forest":
			badge = "✦" if PrologueState.emerald_boss_retired else "💀"
		elif nid == "clocktower":
			badge = "✦" if PrologueState.clocktower_boss_retired else "💀"
		elif nid == "harbor":
			badge = "✦" if PrologueState.harbor_boss_retired else "💀"
		elif playable:
			badge = "★"
		else:
			badge = "🔒"
		_map_canvas.draw_string(font, p + Vector2(-7, 5), badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color("#1c2430"))

		# Node label
		var title := String(n["title"])
		var lpos := p + Vector2(-56, rad + 20)
		_map_canvas.draw_string(font, lpos + Vector2(1, 1), title, HORIZONTAL_ALIGNMENT_CENTER, 112, 13, Color(1, 1, 1, 0.85))
		_map_canvas.draw_string(font, lpos, title, HORIZONTAL_ALIGNMENT_CENTER, 112, 13, Color("#222b38"))

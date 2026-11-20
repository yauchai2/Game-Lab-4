extends Control

# @amelicart Folded Parchment Paper-Cut Sea Chart World Map Overlay (Press [U] or interact with any Waypoint)
# Features: Torn-edge folded parchment frame, matte gouache ocean with waves & sparkles,
# clickable low-poly geometric islands with white sticker rims, wooden piers, iconic landmarks,
# and live drifting gouache clouds!

var current_scene_key := ""
var hovered_id := ""
var node_buttons: Dictionary = {}
var _cloud_time := 0.0

const WORLD_NODES := [
	{
		"id": "clearing",
		"title": "營火林緣",
		"subtitle": "序幕起點 (68×50m) · 月夜營火與湖畔釣魚碼頭",
		"scene": "res://prologue/CampfireClearing.tscn",
		"spawn": "from_town",
		"pos_norm": Vector2(0.14, 0.64),
		"kind": "wild",
		"biome_col": Color("#5c87a6"),
		"accent_col": Color("#3b5f7a"),
		"pier_dir": Vector2(1.0, -0.35),
		"playable": true,
	},
	{
		"id": "town",
		"title": "雲丘停戰營地",
		"subtitle": "第一幕主城 (86×62m) · 傳送石陣 / 生命清泉 / 造裝工坊 / 商人",
		"scene": "res://prologue/CloudhillTown.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.28, 0.34),
		"kind": "town",
		"biome_col": Color("#94c468"),
		"accent_col": Color("#e8cc84"),
		"pier_dir": Vector2(0.0, 1.0),
		"playable": true,
	},
	{
		"id": "road",
		"title": "雲海古道與高地",
		"subtitle": "大型荒野 (150×96m) · Boss 稻草人哨長 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/CloudhillRoad.tscn",
		"spawn": "from_town",
		"pos_norm": Vector2(0.48, 0.45),
		"kind": "boss_zone",
		"biome_col": Color("#e3ae5c"),
		"accent_col": Color("#c97e42"),
		"pier_dir": Vector2(-0.8, 0.6),
		"playable": true,
	},
	{
		"id": "forest",
		"title": "翡翠天梯古林",
		"subtitle": "超大型密林 (160×104m) · Boss 翡翠樹王 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/EmeraldForest.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.64, 0.24),
		"kind": "boss_zone",
		"biome_col": Color("#5aa864"),
		"accent_col": Color("#387d4c"),
		"pier_dir": Vector2(-0.85, 0.45),
		"playable": true,
	},
	{
		"id": "clocktower",
		"title": "舊軍鐘樓哨所",
		"subtitle": "超大型要塞 (164×106m) · Boss 重裝鐵鐘騎士 · 隱藏傳奇怪 ×2",
		"scene": "res://prologue/ClocktowerOutpost.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.62, 0.72),
		"kind": "boss_zone",
		"biome_col": Color("#c4a374"),
		"accent_col": Color("#8f7154"),
		"pier_dir": Vector2(-0.9, -0.35),
		"playable": true,
	},
	{
		"id": "harbor",
		"title": "沉霧燈塔港",
		"subtitle": "第一幕終章 (170×110m) · Boss 迷霧大提督 · 遠航號碼頭",
		"scene": "res://prologue/MistyHarbor.tscn",
		"spawn": "from_waypoint",
		"pos_norm": Vector2(0.81, 0.50),
		"kind": "boss_zone",
		"biome_col": Color("#82b86e"),
		"accent_col": Color("#e6d29e"),
		"pier_dir": Vector2(1.0, 0.25),
		"playable": true,
	},
	{
		"id": "act2_coral",
		"title": "第二幕：珊瑚群島",
		"subtitle": "下一幕遠航目的地 · 勸退迷霧大提督後由《遠航號》啟航",
		"scene": "",
		"spawn": "",
		"pos_norm": Vector2(0.92, 0.24),
		"kind": "future",
		"biome_col": Color("#f0a486"),
		"accent_col": Color("#f5d98e"),
		"pier_dir": Vector2(-0.9, 0.5),
		"playable": false,
	},
]

const WORLD_EDGES := [
	["clearing", "town"],
	["town", "road"],
	["road", "forest"],
	["road", "clocktower"],
	["forest", "harbor"],
	["clocktower", "harbor"],
	["harbor", "act2_coral"],
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

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.11, 0.16, 0.74)
	add_child(dim)

	# Outer Warm Parchment Map Container
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -490
	_panel.offset_right = 490
	_panel.offset_top = -305
	_panel.offset_bottom = 305
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#e8c38d")
	sb.border_color = Color("#b38348")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var title_lbl := Label.new()
	title_lbl.position = Vector2(26, 14)
	title_lbl.text = "🗺 第一幕摺紙航海圖：雲丘停戰邊境"
	title_lbl.add_theme_font_size_override("font_size", 21)
	title_lbl.add_theme_color_override("font_color", Color("#3b2a1a"))
	_panel.add_child(title_lbl)

	var hint_lbl := Label.new()
	hint_lbl.position = Vector2(26, 42)
	hint_lbl.text = "點擊任一島嶼即可檢視進度與傳送 · ★ 主城   💀 未討伐頭目   ✦ 已勸退退休   ⛵ 遠航"
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.add_theme_color_override("font_color", Color("#5c442a"))
	_panel.add_child(hint_lbl)

	var close_btn := Button.new()
	close_btn.position = Vector2(896, 14)
	close_btn.custom_minimum_size = Vector2(62, 34)
	close_btn.text = "✕ [U]"
	close_btn.pressed.connect(close_map)
	_panel.add_child(close_btn)

	# Folded Gouache Sea Chart Canvas
	_map_canvas = Control.new()
	_map_canvas.position = Vector2(22, 68)
	_map_canvas.size = Vector2(936, 420)
	_map_canvas.clip_contents = true
	_map_canvas.draw.connect(_draw_map_canvas)
	_panel.add_child(_map_canvas)

	# Clickable Island Hitboxes
	for n in WORLD_NODES:
		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(138, 104)
		var p := Vector2(float(n["pos_norm"].x) * _map_canvas.size.x, float(n["pos_norm"].y) * _map_canvas.size.y)
		btn.position = p - Vector2(69, 52)
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

	# Bottom Parchment Info & Fast-Travel Bar
	var footer := Panel.new()
	footer.position = Vector2(22, 498)
	footer.size = Vector2(936, 94)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#f7eedb")
	fsb.border_color = Color("#b38348")
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(8)
	footer.add_theme_stylebox_override("panel", fsb)
	_panel.add_child(footer)

	_info_title = Label.new()
	_info_title.position = Vector2(18, 10)
	_info_title.add_theme_font_size_override("font_size", 19)
	_info_title.add_theme_color_override("font_color", Color("#2a3240"))
	footer.add_child(_info_title)

	_info_desc = Label.new()
	_info_desc.position = Vector2(18, 40)
	_info_desc.add_theme_font_size_override("font_size", 13)
	_info_desc.add_theme_color_override("font_color", Color("#4e596b"))
	footer.add_child(_info_desc)

	_info_status = Label.new()
	_info_status.position = Vector2(18, 64)
	_info_status.add_theme_font_size_override("font_size", 13)
	_info_status.add_theme_color_override("font_color", Color("#8c5220"))
	footer.add_child(_info_status)

	_travel_btn = Button.new()
	_travel_btn.position = Vector2(746, 22)
	_travel_btn.custom_minimum_size = Vector2(170, 50)
	_travel_btn.text = "✦ 傳送至此島"
	_travel_btn.pressed.connect(_on_travel_pressed)
	footer.add_child(_travel_btn)

func _process(delta: float) -> void:
	if not visible:
		return
	_cloud_time += delta
	_map_canvas.queue_redraw()

func open_map(scene_key: String) -> void:
	current_scene_key = scene_key
	visible = true
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
		var boss_txt := "✦ 稻草人哨長（已退休開茶攤）" if PrologueState.boss_retired else "💀 稻草人哨長（尚在加班）"
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [boss_txt, PrologueState.uniques_defeated.size()]
	elif nid == "forest":
		var fboss_txt := "✦ 翡翠樹王（已退休開果茶亭）" if PrologueState.emerald_boss_retired else "💀 翡翠樹王（仍在備戰攻城）"
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [fboss_txt, PrologueState.emerald_uniques_defeated.size()]
	elif nid == "clocktower":
		var cboss_txt := "✦ 重裝鐵鐘騎士（已退休開咖啡座）" if PrologueState.clocktower_boss_retired else "💀 重裝鐵鐘騎士（仍在整點敲鐘）"
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [cboss_txt, PrologueState.clocktower_uniques_defeated.size()]
	elif nid == "harbor":
		var hboss_txt := "✦ 迷霧大提督（已退休開海鮮燒烤）" if PrologueState.harbor_boss_retired else "💀 迷霧大提督（仍在開造霧機）"
		_info_status.text = "%s   |   隱藏傳奇怪進度：%d / 2" % [hboss_txt, PrologueState.harbor_uniques_defeated.size()]
	elif nid == "town":
		_info_status.text = "安全主城 · 免費生命清泉 / 簡約造裝工坊 / 五折軍需商人 / 停戰書記官"
	elif nid == "clearing":
		_info_status.text = "序幕起點 · 營火烤魚 / 湖畔垂釣解鎖印章 / 西北青苔洞"
	else:
		_info_status.text = "第二幕籌備中 · 第一幕全區勸退後將由《遠航號》展開新航程"

	if not playable:
		_travel_btn.disabled = true
		_travel_btn.text = "⛵ 第二幕籌備中"
	elif nid == current_scene_key:
		_travel_btn.disabled = true
		_travel_btn.text = "目前所在位置"
	else:
		_travel_btn.disabled = false
		_travel_btn.text = "✦ 傳送至此島"
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

func _island_poly(center: Vector2, nid: String, scale_f := 1.0) -> PackedVector2Array:
	var raw: Array[Vector2] = []
	match nid:
		"clearing":
			raw = [Vector2(-46, -16), Vector2(-18, -32), Vector2(28, -26), Vector2(46, 2), Vector2(30, 28), Vector2(-24, 30), Vector2(-48, 10)]
		"town":
			raw = [Vector2(-52, -18), Vector2(-12, -38), Vector2(38, -28), Vector2(54, 4), Vector2(34, 34), Vector2(-20, 32), Vector2(-50, 14)]
		"road":
			raw = [Vector2(-62, -20), Vector2(-16, -40), Vector2(44, -34), Vector2(64, -4), Vector2(48, 34), Vector2(-10, 38), Vector2(-56, 22)]
		"forest":
			raw = [Vector2(-56, -14), Vector2(-22, -38), Vector2(34, -36), Vector2(58, -6), Vector2(40, 30), Vector2(-18, 34), Vector2(-54, 16)]
		"clocktower":
			raw = [Vector2(-54, -22), Vector2(4, -36), Vector2(52, -20), Vector2(56, 18), Vector2(18, 34), Vector2(-36, 30), Vector2(-58, 6)]
		"harbor":
			raw = [Vector2(-54, -26), Vector2(6, -40), Vector2(54, -18), Vector2(58, 20), Vector2(26, 38), Vector2(-26, 34), Vector2(-56, 6)]
		_:
			raw = [Vector2(-38, -14), Vector2(-8, -28), Vector2(32, -20), Vector2(40, 8), Vector2(18, 26), Vector2(-26, 22)]
	var out := PackedVector2Array()
	for v in raw:
		out.append(center + v * scale_f)
	return out

func _draw_wooden_pier(center: Vector2, dir: Vector2) -> void:
	var n := dir.normalized()
	var perp := Vector2(-n.y, n.x)
	var start := center + n * 34.0
	var end_p := start + n * 24.0
	# Main timber deck
	_map_canvas.draw_line(start, end_p, Color("#6b3f24"), 11.0, false)
	# Plank stripes
	for i in range(4):
		var t := float(i + 1) / 5.0
		var pt := start.lerp(end_p, t)
		_map_canvas.draw_line(pt - perp * 5.5, pt + perp * 5.5, Color("#9e653b"), 2.0, false)
	# Corner pilings
	_map_canvas.draw_circle(end_p - perp * 5.0, 2.6, Color("#4a2915"))
	_map_canvas.draw_circle(end_p + perp * 5.0, 2.6, Color("#4a2915"))

func _draw_island_landmark(center: Vector2, nid: String) -> void:
	match nid:
		"clearing":
			# Mini pine trees + glowing campfire
			for tx in [-20.0, -8.0, 18.0]:
				var tp := center + Vector2(tx, -10.0)
				_map_canvas.draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -14), tp + Vector2(-8, 4), tp + Vector2(8, 4)]), Color("#27594d"))
			_map_canvas.draw_circle(center + Vector2(2, 6), 7.0, Color("#ff9c3b"))
			_map_canvas.draw_circle(center + Vector2(2, 5), 3.6, Color("#fff2a6"))
		"town":
			# Red-roofed camp tent + glowing cyan Waypoint crystal
			var tp := center + Vector2(-18, -6)
			_map_canvas.draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -14), tp + Vector2(-13, 6), tp + Vector2(13, 6)]), Color("#d9534f"))
			var wp := center + Vector2(12, -2)
			_map_canvas.draw_colored_polygon(PackedVector2Array([wp + Vector2(0, -15), wp + Vector2(9, 0), wp + Vector2(0, 12), wp + Vector2(-9, 0)]), Color("#5ce6e0"))
			_map_canvas.draw_circle(wp, 3.5, Color("#ffffff"))
		"road":
			# Autumn windmill + stone arch bridge
			var wm := center + Vector2(-18, -8)
			_map_canvas.draw_rect(Rect2(wm + Vector2(-5, -6), Vector2(10, 16)), Color("#8a5436"), true)
			_map_canvas.draw_line(wm + Vector2(-11, -13), wm + Vector2(11, 5), Color("#fff2d6"), 2.5, true)
			_map_canvas.draw_line(wm + Vector2(11, -13), wm + Vector2(-11, 5), Color("#fff2d6"), 2.5, true)
			_map_canvas.draw_rect(Rect2(center + Vector2(8, -2), Vector2(24, 9)), Color("#d6cfc2"), true)
		"forest":
			# Giant emerald canopy dome + tiny tea stand
			_map_canvas.draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 16)), Color("#6e4429"), true)
			_map_canvas.draw_circle(center + Vector2(0, -12), 14.0, Color("#2a8c52"))
			_map_canvas.draw_circle(center + Vector2(-11, -7), 9.5, Color("#3ba862"))
			_map_canvas.draw_circle(center + Vector2(11, -7), 9.5, Color("#3ba862"))
		"clocktower":
			# Stone clocktower + cream clock face + brass gear
			var ct := center + Vector2(-4, -8)
			_map_canvas.draw_rect(Rect2(ct + Vector2(-9, -14), Vector2(18, 28)), Color("#9e9488"), true)
			_map_canvas.draw_colored_polygon(PackedVector2Array([ct + Vector2(0, -24), ct + Vector2(-12, -13), ct + Vector2(12, -13)]), Color("#cf5c4e"))
			_map_canvas.draw_circle(ct + Vector2(0, -4), 6.0, Color("#fff6dc"))
			_map_canvas.draw_circle(center + Vector2(18, 8), 8.0, Color("#d4a442"))
			_map_canvas.draw_circle(center + Vector2(18, 8), 3.2, Color("#8f7154"))
		"harbor":
			# Towering red-and-white striped Grand Lighthouse
			var lh := center + Vector2(2, -8)
			_map_canvas.draw_rect(Rect2(lh + Vector2(-7, -18), Vector2(14, 30)), Color("#ffffff"), true)
			_map_canvas.draw_rect(Rect2(lh + Vector2(-7, -14), Vector2(14, 6)), Color("#e04a3a"), true)
			_map_canvas.draw_rect(Rect2(lh + Vector2(-7, -2), Vector2(14, 6)), Color("#e04a3a"), true)
			_map_canvas.draw_circle(lh + Vector2(0, -21), 5.5, Color("#fff3a3"))
		_:
			# Coral Archipelago pink blooms
			_map_canvas.draw_circle(center + Vector2(-10, -4), 7.5, Color("#ff8da6"))
			_map_canvas.draw_circle(center + Vector2(6, -8), 8.5, Color("#ff6e91"))
			_map_canvas.draw_circle(center + Vector2(14, 2), 6.5, Color("#ffd166"))

func _draw_gouache_cloud(pos: Vector2, scl := 1.0, alpha := 0.92) -> void:
	var c_base := Color(0.97, 0.97, 0.94, alpha)
	var c_shd := Color(0.76, 0.85, 0.88, alpha * 0.72)
	_map_canvas.draw_circle(pos + Vector2(0, 6) * scl, 18.0 * scl, c_shd)
	_map_canvas.draw_circle(pos + Vector2(-18, 8) * scl, 13.0 * scl, c_shd)
	_map_canvas.draw_circle(pos + Vector2(18, 8) * scl, 13.0 * scl, c_shd)
	_map_canvas.draw_circle(pos + Vector2(0, 0) * scl, 18.0 * scl, c_base)
	_map_canvas.draw_circle(pos + Vector2(-17, 4) * scl, 13.0 * scl, c_base)
	_map_canvas.draw_circle(pos + Vector2(17, 4) * scl, 13.0 * scl, c_base)
	_map_canvas.draw_rect(Rect2(pos + Vector2(-18, 3) * scl, Vector2(36, 13) * scl), c_base, true)

func _draw_map_canvas() -> void:
	var sz := _map_canvas.size
	var rect := Rect2(Vector2.ZERO, sz)

	# 1. Matte Gouache Sea-Teal Ocean Backdrop
	_map_canvas.draw_rect(rect, Color("#7ab8b4"), true)
	# Soft aged parchment-vignette sea rim
	_map_canvas.draw_rect(rect, Color(0.45, 0.42, 0.48, 0.22), false, 16.0)
	_map_canvas.draw_rect(rect, Color("#b38348"), false, 3.0)

	# 2. Minimalist Ocean Wave Strokes & 4-Point Sparkle Stars (just like @amelicart chart!)
	for wi in range(18):
		var wx := fmod(float(wi) * 137.0 + 48.0, sz.x - 90.0) + 30.0
		var wy := fmod(float(wi) * 89.0 + 36.0, sz.y - 60.0) + 24.0
		_map_canvas.draw_line(Vector2(wx, wy), Vector2(wx + 24.0, wy), Color(0.32, 0.58, 0.60, 0.45), 1.8, true)
		_map_canvas.draw_line(Vector2(wx + 6.0, wy + 5.0), Vector2(wx + 20.0, wy + 5.0), Color(0.88, 0.96, 0.94, 0.42), 1.4, true)
	for sp in [Vector2(88, 92), Vector2(215, 295), Vector2(412, 86), Vector2(538, 340), Vector2(760, 108), Vector2(842, 336)]:
		_map_canvas.draw_line(sp + Vector2(-6, 0), sp + Vector2(6, 0), Color(1, 1, 1, 0.72), 1.6, true)
		_map_canvas.draw_line(sp + Vector2(0, -6), sp + Vector2(0, 6), Color(1, 1, 1, 0.72), 1.6, true)

	# 3. Subtle Folded-Paper Quadrant Creases (Vertical & Horizontal Center Folds)
	_map_canvas.draw_line(Vector2(sz.x * 0.5, 0), Vector2(sz.x * 0.5, sz.y), Color(0.35, 0.25, 0.16, 0.14), 3.0)
	_map_canvas.draw_line(Vector2(sz.x * 0.5 + 2.0, 0), Vector2(sz.x * 0.5 + 2.0, sz.y), Color(1.0, 0.96, 0.88, 0.22), 2.0)
	_map_canvas.draw_line(Vector2(0, sz.y * 0.5), Vector2(sz.x, sz.y * 0.5), Color(0.35, 0.25, 0.16, 0.13), 3.0)
	_map_canvas.draw_line(Vector2(0, sz.y * 0.5 + 2.0), Vector2(sz.x, sz.y * 0.5 + 2.0), Color(1.0, 0.96, 0.88, 0.20), 2.0)

	# 4. Hand-Drawn Dashed Sea/Travel Routes Between Islands
	for edge in WORLD_EDGES:
		var a := _node_pos(String(edge[0]))
		var b := _node_pos(String(edge[1]))
		var is_sea_leg := String(edge[1]) == "act2_coral"
		var steps := 14
		for i in range(steps):
			if i % 2 == 1:
				continue
			var p0 := a.lerp(b, float(i) / float(steps))
			var p1 := a.lerp(b, float(i + 1) / float(steps))
			var col := Color(0.95, 0.98, 1.0, 0.72) if is_sea_leg else Color(0.38, 0.27, 0.18, 0.55)
			_map_canvas.draw_line(p0, p1, col, 2.4, true)

	# 5. Clickable Paper-Cut Geometric Islands + Wooden Piers + Iconic Landmarks
	var font := ThemeDB.fallback_font
	for n in WORLD_NODES:
		var nid := String(n["id"])
		var p := _node_pos(nid)
		var is_cur := nid == current_scene_key
		var is_sel := not _selected_node.is_empty() and String(_selected_node["id"]) == nid
		var is_hov := nid == hovered_id
		var scl := 1.07 if (is_sel or is_hov) else 1.0

		# Wooden Pier Anchor first (sticks out into water)
		_draw_wooden_pier(p, n["pier_dir"] as Vector2)

		# Soft drop shadow + clean white sticker/gouache rim
		_map_canvas.draw_colored_polygon(_island_poly(p + Vector2(3, 6), nid, scl * 1.06), Color(0.14, 0.30, 0.34, 0.30))
		var rim_col := Color("#ffe680") if (is_sel or is_hov) else Color(0.98, 0.97, 0.93, 0.94)
		_map_canvas.draw_colored_polygon(_island_poly(p, nid, scl * 1.08), rim_col)
		# Main geometric biome polygon + inner facet highlight
		_map_canvas.draw_colored_polygon(_island_poly(p, nid, scl), n["biome_col"] as Color)
		_map_canvas.draw_colored_polygon(_island_poly(p + Vector2(4, 4), nid, scl * 0.62), n["accent_col"] as Color)

		# Cute iconic landmark illustration on top of the island
		_draw_island_landmark(p, nid)

		# Current-location crisp white ring
		if is_cur:
			_map_canvas.draw_arc(p, 48.0, 0.0, TAU, 32, Color("#ffffff"), 3.0)

		# Compact top-right status medal
		var badge := "⛵"
		var bfill := Color("#5aa8d6")
		if nid == "town":
			badge = "★"
			bfill = Color("#4ecdc4")
		elif nid == "clearing":
			badge = "★"
			bfill = Color("#5b9cf0")
		elif nid == "road":
			badge = "✦" if PrologueState.boss_retired else "💀"
			bfill = Color("#5ec978") if PrologueState.boss_retired else Color("#e05347")
		elif nid == "forest":
			badge = "✦" if PrologueState.emerald_boss_retired else "💀"
			bfill = Color("#5ec978") if PrologueState.emerald_boss_retired else Color("#e05347")
		elif nid == "clocktower":
			badge = "✦" if PrologueState.clocktower_boss_retired else "💀"
			bfill = Color("#5ec978") if PrologueState.clocktower_boss_retired else Color("#e05347")
		elif nid == "harbor":
			badge = "✦" if PrologueState.harbor_boss_retired else "💀"
			bfill = Color("#5ec978") if PrologueState.harbor_boss_retired else Color("#e05347")
		var bp := p + Vector2(36, -24)
		_map_canvas.draw_circle(bp, 12.0, bfill)
		_map_canvas.draw_arc(bp, 12.0, 0.0, TAU, 20, Color("#fffdf5"), 2.0)
		_map_canvas.draw_string(font, bp + Vector2(-6, 5), badge, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color("#ffffff"))

		# Parchment name pill directly beneath the island
		var title := String(n["title"])
		var pill_w := 124.0
		var pill_rect := Rect2(p + Vector2(-pill_w * 0.5, 34.0), Vector2(pill_w, 22.0))
		_map_canvas.draw_rect(pill_rect, Color(0.98, 0.95, 0.88, 0.94), true)
		_map_canvas.draw_rect(pill_rect, Color("#b38348"), false, 1.5)
		_map_canvas.draw_string(font, pill_rect.position + Vector2(0, 16), title, HORIZONTAL_ALIGNMENT_CENTER, pill_w, 12, Color("#2b2116"))

	# 6. Live Drifting Gouache Clouds (and gentle mist cloud over Act 2 Coral Archipelago!)
	var clouds := [
		{"x": 92.0, "y": 46.0, "s": 1.05, "spd": 6.0},
		{"x": 388.0, "y": 42.0, "s": 0.92, "spd": 4.5},
		{"x": 116.0, "y": 374.0, "s": 1.12, "spd": 5.2},
		{"x": 456.0, "y": 382.0, "s": 0.96, "spd": 4.0},
		{"x": 864.0, "y": 362.0, "s": 1.08, "spd": 5.5},
	]
	for c in clouds:
		var cx := fmod(float(c["x"]) + _cloud_time * float(c["spd"]), sz.x + 120.0) - 60.0
		_draw_gouache_cloud(Vector2(cx, float(c["y"])), float(c["s"]), 0.90)
	# Soft drifting mist over locked Act 2 island
	var act2_p := _node_pos("act2_coral")
	_draw_gouache_cloud(act2_p + Vector2(sin(_cloud_time * 0.8) * 10.0, 14.0), 1.02, 0.78)

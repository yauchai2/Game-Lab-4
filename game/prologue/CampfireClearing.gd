extends "res://prologue/PrologueBase.gd"

const CAMPFIRE_POS := Vector3(0.0, 0.0, 0.0)
const EXIT_TO_TOWN := Vector3(9.2, 0.0, -0.5)

var campfire_flame: MeshInstance3D
var title_overlay: ColorRect

func _ready() -> void:
	can_attack = false
	_build_map()
	var spawn := Vector3(7.2, 0.0, -0.5) if PrologueState.spawn_tag == "from_town" else Vector3(0.65, 0.0, -0.35)
	setup_core_trio(spawn)
	setup_camera_and_lighting(13.5, Color("#111a30"), Color("#375488"), 0.58, Color("#6085c4"), 0.38)
	setup_hud()

	if not PrologueState.has_started:
		input_locked = true
		_build_title_overlay()
	else:
		show_subtitle("林間營火空地｜深藍夜色依然安靜，隨時可沿東側林徑返回雲丘小鎮。", 3.5)
	_update_ui()

func _build_map() -> void:
	# Circular forest clearing floor + stream bank
	box(self, Vector3(0.0, -0.5, 0.0), Vector3(24.0, 1.0, 14.0), NIGHT_GRASS)
	cylinder(self, Vector3(0.0, 0.01, 0.0), 4.6, 4.8, 0.04, Color("#c78e54"))
	box(self, Vector3(5.8, 0.015, -0.5), Vector3(9.5, 0.03, 2.6), TRAIL)
	# Reflective night stream along south edge
	box(self, Vector3(0.0, -0.35, 6.2), Vector3(24.0, 0.4, 3.6), Color("#262247"))
	box(self, Vector3(0.0, -0.13, 6.2), Vector3(1.8, 0.02, 2.8), Color("#d97236"), false, true)

	# Boundary curbs
	box(self, Vector3(-11.5, 0.8, 0.0), Vector3(0.6, 1.6, 15.0), PINE_DARK, true)
	box(self, Vector3(11.5, 0.8, 0.0), Vector3(0.6, 1.6, 15.0), PINE_DARK, true)
	box(self, Vector3(0.0, 0.8, -6.5), Vector3(23.5, 1.6, 0.6), PINE_DARK, true)
	box(self, Vector3(0.0, 0.8, 4.4), Vector3(23.5, 1.6, 0.5), NIGHT_GRASS, true)

	# Central Campfire + Stone Ring + Mossy Sitting Log + Bedroll
	for i in range(8):
		var ang := i * TAU / 8.0
		sphere(self, CAMPFIRE_POS + Vector3(cos(ang) * 0.72, 0.14, sin(ang) * 0.72), Vector3(0.32, 0.22, 0.28), STONE)
	campfire_flame = cylinder(self, CAMPFIRE_POS + Vector3(0, 0.38, 0), 0.05, 0.34, 0.78, FIRE_ORANGE, true)
	cylinder(self, CAMPFIRE_POS + Vector3(0, 1.8, 0), 0.22, 0.08, 2.4, Color("#d4ecf0"), true)
	var light := OmniLight3D.new()
	light.light_color = Color("#ff9f43")
	light.light_energy = 4.6
	light.omni_range = 11.5
	light.position = CAMPFIRE_POS + Vector3(0, 1.3, 0)
	add_child(light)

	var sit_log := cylinder(self, CAMPFIRE_POS + Vector3(1.85, 0.28, -0.45), 0.28, 0.30, 1.9, TIMBER)
	sit_log.rotation_degrees = Vector3(0, 22, 90)
	cylinder(self, CAMPFIRE_POS + Vector3(1.9, 0.16, 0.25), 0.16, 0.16, 0.7, Color("#6fa69d")).rotation_degrees.z = 90.0

	# Mossy Ancient Skull Cavern (NW landmark matching reference art)
	var skull := Node3D.new()
	skull.position = Vector3(-5.2, 0.0, -3.6)
	add_child(skull)
	sphere(skull, Vector3(0, 1.9, 0), Vector3(3.4, 2.9, 2.6), STONE_LIGHT)
	sphere(skull, Vector3(0, 2.85, 0), Vector3(3.1, 1.2, 2.5), Color("#466e40"))
	sphere(skull, Vector3(-0.75, 1.75, 1.15), Vector3(0.75, 0.85, 0.5), Color("#151926"), true)
	sphere(skull, Vector3(0.75, 1.75, 1.15), Vector3(0.75, 0.85, 0.5), Color("#151926"), true)
	box(skull, Vector3(0, 0.65, 1.05), Vector3(1.5, 1.3, 0.6), Color("#151926"), false, true)

	# Giant tree stump on SW bank + midnight pines + glowing cyan mist pillars
	cylinder(self, Vector3(-6.2, 0.45, 2.8), 0.95, 1.15, 0.9, TIMBER)
	for p in [
		Vector3(-9.2, 0, -4.8), Vector3(-1.8, 0, -5.2), Vector3(3.5, 0, -4.8),
		Vector3(7.4, 0, -4.6), Vector3(-9.5, 0, 3.2), Vector3(8.5, 0, 3.1)
	]:
		pine_tree(p, randf_range(1.0, 1.35), PINE_DARK)
	for x in [-7.5, -1.0, 2.5]:
		cylinder(self, Vector3(x, 2.8, -7.8), 1.5, 2.0, 5.6, MIST_CYAN, true)
	# Subtle golden dawn glow peeking at east trail exit
	cylinder(self, Vector3(11.8, 2.2, -0.5), 1.8, 2.2, 4.4, Color("#ffd199"), true)

	transition_signpost(EXIT_TO_TOWN, "前往：雲丘小鎮（按 E）", GOLD)

func _build_title_overlay() -> void:
	title_overlay = ColorRect.new()
	title_overlay.color = Color(0.05, 0.08, 0.16, 0.25)
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(title_overlay)

	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.position = Vector2(-280, -170)
	center.custom_minimum_size = Vector2(560, 220)
	title_overlay.add_child(center)

	var title := Label.new()
	title.text = "《補簽遠行》\n地圖一：林間營火空地"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_outline_color", Color("#101726"))
	title.add_theme_constant_override("outline_size", 10)
	center.add_child(title)

	var hint := Label.new()
	hint.text = "\n[ 按 空白鍵 / Enter / 點擊畫面 醒來出發 ]"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("#ffd88a"))
	hint.add_theme_color_override("font_outline_color", Color("#101726"))
	hint.add_theme_constant_override("outline_size", 8)
	center.add_child(hint)

func on_map_input(event: InputEvent) -> bool:
	if not PrologueState.has_started:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			PrologueState.has_started = true
			input_locked = false
			if title_overlay:
				var tw := create_tween()
				tw.tween_property(title_overlay, "modulate:a", 0.0, 0.45)
				tw.tween_callback(title_overlay.queue_free)
			show_player_emote("!", 1.5)
			show_subtitle("「一百年前，魔王軍與王國聯軍爆發世紀大戰……」── 沿右側林徑前往雲丘小鎮吧！", 5.5)
			return true
	return false

func _physics_process(delta: float) -> void:
	campfire_flame.scale.y = 0.9 + sin(Time.get_ticks_msec() * 0.012) * 0.14
	if not step_shared_physics(delta):
		return
	_update_ui()

func on_interact() -> void:
	if near(EXIT_TO_TOWN, 2.6):
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_campfire")
	elif near(CAMPFIRE_POS, 2.4):
		PrologueState.player_hp = 5
		show_player_emote("✨", 1.4)
		show_subtitle("在營火旁稍作休息，體力已完全恢復。", 2.5)

func _update_ui() -> void:
	objective_label.text = "地圖一：林間營火空地　／　" + ("按任意鍵開始旅程" if not PrologueState.has_started else "熟悉移動與 [F] 上下騎，沿東側林徑前往雲丘小鎮")
	update_status_line()
	prompt_label.text = ""
	if not PrologueState.has_started:
		return
	if near(EXIT_TO_TOWN, 2.6):
		prompt_label.text = "[E] 沿林徑前往：雲丘小鎮（地圖二）"
	elif near(CAMPFIRE_POS, 2.4):
		prompt_label.text = "[E] 烤火休息（回滿體力）"
	elif not PrologueState.mounted and near(wolf.position, 2.7):
		prompt_label.text = "[F] 騎上巨狼拍檔"

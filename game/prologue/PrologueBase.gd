extends Node3D

# Shared Amelicart-inspired matte gouache palette
const NIGHT_GRASS := Color("#2f4659")
const DAY_GRASS := Color("#d89448")
const MEADOW_GREEN := Color("#8db858")
const TRAIL := Color("#e5be8a")
const BOARDWALK := Color("#c97e49")
const STONE := Color("#8a8796")
const STONE_LIGHT := Color("#b7b3c4")
const TIMBER := Color("#78523d")
const TIMBER_LIGHT := Color("#a87854")
const WHITE_WALL := Color("#f7f3ea")
const CORAL_ROOF := Color("#d9786c")
const BLUE_CURTAIN := Color("#1e6fa8")
const BUNTING_BLUE := Color("#5d96d8")
const PINE_DARK := Color("#1e3148")
const PINE_ORANGE := Color("#d9532f")
const PINE_TEAL := Color("#2e6b6b")
const MIST_CYAN := Color("#5ae8e5")
const FIRE_ORANGE := Color("#ff9838")
const GOLD := Color("#f5c65b")
const GOBLIN_GREEN := Color("#6ec25a")
const PINK_PEAK := Color("#d896c8")
const PURPLE_PEAK := Color("#9688d4")
const CLOUD_WHITE := Color("#f7eaf2")
const STAMP_RED := Color("#e03c3c")

# Storybook UI Palette
const UI_PARCHMENT := Color("#fbf2df")
const UI_WOOD_BORDER := Color("#6b4a35")
const UI_INK := Color("#2e211b")
const UI_DARK_BG := Color(0.10, 0.13, 0.22, 0.88)
const UI_ACCENT_GOLD := Color("#f5c65b")
const UI_HP_RED := Color("#e0534f")
const UI_HP_BG := Color("#3d2d29")

const PLAYER_RADIUS := 0.30
const WOLF_RADIUS := 0.82

# 60 FPS integer frame counter hitstop (never mutates Engine.time_scale)
var hitstop_frames := 0
var attack_cooldown := 0.0
var wolf_charge_cooldown := 0.0
var wolf_charge_max := 1.5
var wolf_charge_timer := 0.0
var shake_time := 0.0
var air_slam_active := false
var vertical_vel := 0.0
var emote_timer := 0.0
var subtitle_timer := 0.0
var input_locked := false
var can_attack := true
var inv_open := false
var selected_inv_idx := -1

var player := CharacterBody3D.new()
var wolf := CharacterBody3D.new()
var bird := Node3D.new()
var camera := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()

var player_sword: MeshInstance3D
var wolf_spring_pad: MeshInstance3D
var player_emote: Label3D
var wolf_emote: Label3D

# Upgraded Storybook HUD nodes
var hud_layer: CanvasLayer
var hud_root: Control
var zone_badge_label: Label
var objective_label: Label
var hp_hearts_label: Label
var hp_bar: ProgressBar
var gear_tags_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label

# Boss HP Bar (Top-Center)
var boss_panel: PanelContainer
var boss_name_label: Label
var boss_hp_bar: ProgressBar
var boss_state_badge: Label

# 5-Slot Bottom ARPG Hotbar
var slot_attack: PanelContainer
var slot_attack_cd: ColorRect
var slot_mount: PanelContainer
var slot_mount_sub: Label
var slot_wolf: PanelContainer
var slot_wolf_cd: ColorRect
var slot_bag: PanelContainer
var slot_reset: PanelContainer

# PoE 2 Inventory & Currency Crafting Modal (press I)
var inv_panel: PanelContainer
var inv_stats_label: Label
var inv_equipped_label: Label
var inv_currency_label: Label
var inv_list_box: VBoxContainer
var inv_feedback_label: Label

# --- Procedural matte gouache geometry helpers ---
func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false, unshaded := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var mesh := mesh_at(parent, pos, shape, color, unshaded)
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

func mesh_at(parent: Node3D, pos: Vector3, mesh: Mesh, color: Color, unshaded := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	instance.position = pos
	return instance

func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := mesh_at(parent, pos, mesh, color, unshaded)
	instance.scale = size
	return instance

func cylinder(parent: Node3D, pos: Vector3, top_r: float, bottom_r: float, h: float, color: Color, unshaded := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = h
	mesh.radial_segments = 10
	return mesh_at(parent, pos, mesh, color, unshaded)

func label_at(parent: Node3D, pos: Vector3, words: String, color := Color.WHITE, font_size := 36) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.modulate = color
	label.font_size = font_size
	label.outline_size = 10
	label.pixel_size = 0.0085
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	label.position = pos
	return label

func marker(pos: Vector3, color: Color, radius := 0.58) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	return mesh_at(self, pos + Vector3.UP * 0.03, mesh, color, true)

func pine_tree(pos: Vector3, scale_val := 1.0, tint := PINE_DARK) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_val
	add_child(root)
	cylinder(root, Vector3(0, 1.1, 0), 0.24, 0.34, 2.2, TIMBER)
	cylinder(root, Vector3(0, 2.5, 0), 0.12, 1.45, 2.2, tint)
	cylinder(root, Vector3(0, 3.9, 0), 0.06, 1.10, 1.9, tint.lightened(0.08))

func transition_signpost(pos: Vector3, title: String, color := GOLD) -> void:
	cylinder(self, pos + Vector3(0, 0.85, 0), 0.09, 0.11, 1.7, TIMBER)
	box(self, pos + Vector3(0.25, 1.45, 0), Vector3(1.1, 0.36, 0.12), TIMBER_LIGHT)
	marker(pos + Vector3(0, 0, 0.8), color, 0.85)
	label_at(self, pos + Vector3(0, 2.35, 0), title, color, 34)

# --- Core Trio Builders ---
func setup_core_trio(spawn_pos: Vector3) -> void:
	_make_body(player, spawn_pos, PLAYER_RADIUS)
	box(player, Vector3(0, 0.36, 0), Vector3(0.46, 0.56, 0.34), Color("#4da1e8"))
	sphere(player, Vector3(0, 0.84, 0.02), Vector3(0.50, 0.50, 0.48), Color("#f4c9a8"))
	cylinder(player, Vector3(0, 1.12, 0), 0.08, 0.32, 0.32, Color("#498e62"))
	box(player, Vector3(-0.22, 1.24, -0.05), Vector3(0.08, 0.30, 0.14), Color("#d7e4ff"))
	box(player, Vector3(0, 0.44, -0.25), Vector3(0.36, 0.36, 0.18), Color("#8c5234"))
	player_sword = box(player, Vector3(0.38, 0.48, 0.25), Vector3(0.11, 0.11, 0.85), Color("#e6f4ff"))
	player_sword.visible = PrologueState.has_sword
	player_emote = label_at(player, Vector3(0, 1.75, 0), "", Color("#fff59d"), 46)

	_make_body(wolf, spawn_pos + Vector3(-1.45, 0, -0.55), WOLF_RADIUS)
	var fur := Color("#464b59")
	var fur_light := Color("#747d91")
	box(wolf, Vector3(0, 0.78, 0), Vector3(1.12, 0.86, 1.82), fur)
	box(wolf, Vector3(0, 1.05, 0.88), Vector3(0.72, 0.65, 0.72), fur)
	box(wolf, Vector3(0, 0.85, 1.32), Vector3(0.42, 0.32, 0.48), fur_light)
	for sx in [-0.36, 0.36]:
		for sz in [-0.62, 0.62]:
			box(wolf, Vector3(sx, 0.30, sz), Vector3(0.24, 0.60, 0.26), fur)
		cylinder(wolf, Vector3(sx * 0.62, 1.54, 0.92), 0.03, 0.16, 0.42, fur)
	var tail := box(wolf, Vector3(0, 0.95, -1.18), Vector3(0.28, 0.28, 0.78), fur)
	tail.rotation_degrees.x = 24.0
	box(wolf, Vector3(0, 1.24, -0.10), Vector3(0.92, 0.16, 0.72), Color("#a87b54"))
	wolf_spring_pad = cylinder(wolf, Vector3(0, 1.42, -0.10), 0.38, 0.38, 0.22, GOLD)
	wolf_spring_pad.visible = PrologueState.has_spring_saddle
	wolf_emote = label_at(wolf, Vector3(0, 2.25, 0.5), "", Color("#d0ecff"), 40)

	if PrologueState.mounted:
		wolf.position = spawn_pos
		player.position = wolf.position + Vector3.UP * 1.38

	add_child(bird)
	sphere(bird, Vector3.ZERO, Vector3(0.32, 0.28, 0.34), Color("#ffbf3c"))
	box(bird, Vector3(0, 0.0, 0.19), Vector3(0.10, 0.08, 0.12), Color("#e8632c"))
	bird.position = player.position + Vector3(0, 1.45, 0)

func _make_body(body: CharacterBody3D, pos: Vector3, radius: float) -> void:
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	body.collision_layer = 2
	body.collision_mask = 1
	add_child(body)
	var shape := SphereShape3D.new()
	shape.radius = radius
	add_shape(body, shape, Vector3.UP * radius)
	body.position = pos

# --- 2.5D Orthographic Oblique Top-Down Camera ---
func setup_camera_and_lighting(cam_size: float, bg_col: Color, amb_col: Color, amb_energy: float, sun_col: Color, sun_energy: float) -> void:
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.current = true
	position_camera(feet(), 1.0)

	env.background_mode = Environment.BG_COLOR
	env.background_color = bg_col
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = amb_col
	env.ambient_light_energy = amb_energy
	camera.environment = env

	add_child(sun)
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.shadow_enabled = true

func position_camera(target: Vector3, lerp_weight: float) -> void:
	var offset := Vector3(3.2, 14.2, 16.5)
	var desired := target + offset
	camera.position = camera.position.lerp(desired, lerp_weight) if lerp_weight < 1.0 else desired
	camera.look_at(camera.position - offset)

# --- Storybook UI/UX + PoE 2 Crafting HUD ---
func make_panel_style(bg: Color, border: Color, radius := 12, border_w := 2, pad_x := 14, pad_y := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	sb.shadow_color = Color(0.05, 0.06, 0.12, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb

func setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# 1. Top-Left: Vitals & Active Gear Card
	var vitals_card := PanelContainer.new()
	vitals_card.position = Vector2(20, 18)
	vitals_card.custom_minimum_size = Vector2(310, 74)
	vitals_card.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_WOOD_BORDER, 14, 3, 14, 10))
	vitals_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(vitals_card)

	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 5)
	vitals_card.add_child(v_box)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	v_box.add_child(hp_row)
	hp_hearts_label = _styled_label("旅人  ♥ ♥ ♥ ♥ ♥", 15, UI_INK, false)
	hp_row.add_child(hp_hearts_label)

	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = 5
	hp_bar.value = PrologueState.player_hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(110, 14)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.add_theme_stylebox_override("background", make_panel_style(UI_HP_BG, UI_WOOD_BORDER, 7, 1, 0, 0))
	hp_bar.add_theme_stylebox_override("fill", make_panel_style(UI_HP_RED, Color.TRANSPARENT, 7, 0, 0, 0))
	hp_row.add_child(hp_bar)

	gear_tags_label = _styled_label("", 13, Color("#6b4a35"), false)
	v_box.add_child(gear_tags_label)

	# 2. Top-Right: Zone Badge & Objective Card
	var obj_card := PanelContainer.new()
	obj_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	obj_card.offset_left = -410
	obj_card.offset_right = -20
	obj_card.offset_top = 18
	obj_card.offset_bottom = 96
	obj_card.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, UI_ACCENT_GOLD, 14, 2, 16, 10))
	obj_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(obj_card)

	var o_box := VBoxContainer.new()
	o_box.add_theme_constant_override("separation", 4)
	obj_card.add_child(o_box)
	zone_badge_label = _styled_label("地圖", 13, UI_ACCENT_GOLD, false)
	o_box.add_child(zone_badge_label)
	objective_label = _styled_label("", 16, Color("#fff9eb"), false)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o_box.add_child(objective_label)

	# 3. Top-Center: Boss HP Bar
	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_panel.offset_left = -220
	boss_panel.offset_right = 220
	boss_panel.offset_top = 18
	boss_panel.offset_bottom = 92
	boss_panel.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, STAMP_RED, 14, 2, 16, 10))
	boss_panel.hide()
	hud_root.add_child(boss_panel)

	var b_box := VBoxContainer.new()
	b_box.add_theme_constant_override("separation", 5)
	boss_panel.add_child(b_box)
	var b_top := HBoxContainer.new()
	b_box.add_child(b_top)
	boss_name_label = _styled_label("稻草人哨長", 16, Color("#fff2cc"), false)
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_top.add_child(boss_name_label)
	boss_state_badge = _styled_label("", 14, GOLD, false)
	b_top.add_child(boss_state_badge)
	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.min_value = 0
	boss_hp_bar.max_value = 6
	boss_hp_bar.value = 6
	boss_hp_bar.show_percentage = false
	boss_hp_bar.custom_minimum_size = Vector2(390, 16)
	boss_hp_bar.add_theme_stylebox_override("background", make_panel_style(UI_HP_BG, UI_WOOD_BORDER, 8, 1, 0, 0))
	boss_hp_bar.add_theme_stylebox_override("fill", make_panel_style(Color("#f06b4f"), Color.TRANSPARENT, 8, 0, 0, 0))
	b_box.add_child(boss_hp_bar)

	# 4. Bottom-Center Stack
	var bottom_stack := VBoxContainer.new()
	bottom_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_stack.offset_left = -380
	bottom_stack.offset_right = 380
	bottom_stack.offset_top = -205
	bottom_stack.offset_bottom = -16
	bottom_stack.alignment = BoxContainer.ALIGNMENT_END
	bottom_stack.add_theme_constant_override("separation", 8)
	bottom_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(bottom_stack)

	subtitle_panel = PanelContainer.new()
	subtitle_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	subtitle_panel.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, Color("#7382a6"), 12, 1, 18, 8))
	subtitle_panel.hide()
	bottom_stack.add_child(subtitle_panel)
	subtitle_label = _styled_label("", 16, Color("#ffe8a3"), false)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_panel.add_child(subtitle_label)

	prompt_panel = PanelContainer.new()
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_panel.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_ACCENT_GOLD, 20, 3, 18, 7))
	prompt_panel.hide()
	bottom_stack.add_child(prompt_panel)
	prompt_label = _styled_label("", 16, UI_INK, false)
	prompt_panel.add_child(prompt_label)

	var hotbar := HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 10)
	bottom_stack.add_child(hotbar)

	var atk_pair := _make_hotbar_slot(hotbar, "左鍵 / J", "揮劍", Color("#4da1e8"))
	slot_attack = atk_pair[0]
	slot_attack_cd = atk_pair[1]
	var mnt_pair := _make_hotbar_slot(hotbar, "F", "上鞍騎乘", Color("#498e62"))
	slot_mount = mnt_pair[0]
	slot_mount_sub = mnt_pair[2]
	var wlf_pair := _make_hotbar_slot(hotbar, "Q", "巨狼破防", Color("#d97836"))
	slot_wolf = wlf_pair[0]
	slot_wolf_cd = wlf_pair[1]
	var bag_pair := _make_hotbar_slot(hotbar, "I", "背包造裝", Color("#c99438"))
	slot_bag = bag_pair[0]
	var rst_pair := _make_hotbar_slot(hotbar, "R", "重置序章", Color("#7d8597"))
	slot_reset = rst_pair[0]

	_build_inventory_modal()

func _build_inventory_modal() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inv_panel.offset_left = -360
	inv_panel.offset_right = 360
	inv_panel.offset_top = -235
	inv_panel.offset_bottom = 225
	inv_panel.add_theme_stylebox_override("panel", make_panel_style(UI_PARCHMENT, UI_WOOD_BORDER, 18, 4, 22, 16))
	inv_panel.hide()
	hud_layer.add_child(inv_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	inv_panel.add_child(root_v)

	var header := HBoxContainer.new()
	root_v.add_child(header)
	var h_title := _styled_label("🎒 旅人背包 × PoE 2 退休魔物通貨造裝（按 I 關閉）", 20, UI_INK, false)
	h_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(h_title)
	var close_btn := Button.new()
	close_btn.text = "關閉 [I]"
	close_btn.pressed.connect(toggle_inventory)
	header.add_child(close_btn)

	inv_stats_label = _styled_label("", 15, Color("#5a3b28"), false)
	root_v.add_child(inv_stats_label)
	inv_equipped_label = _styled_label("", 14, Color("#244a75"), false)
	root_v.add_child(inv_equipped_label)
	inv_currency_label = _styled_label("", 15, Color("#8a4b16"), false)
	root_v.add_child(inv_currency_label)

	# Currency Crafting Action Buttons
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 8)
	root_v.add_child(craft_row)

	var btn_equip := Button.new()
	btn_equip.text = "穿戴所選裝備"
	btn_equip.pressed.connect(func() -> void:
		var msg := PrologueState.equip_from_inventory(selected_inv_idx)
		if not msg.is_empty():
			selected_inv_idx = -1
			player_sword.visible = PrologueState.has_sword
			wolf_spring_pad.visible = PrologueState.has_spring_saddle
			_refresh_inventory_ui(msg)
	)
	craft_row.add_child(btn_equip)

	var btn_blue := Button.new()
	btn_blue.text = "用【改裝藍印章】(白→藍)"
	btn_blue.pressed.connect(func() -> void:
		_refresh_inventory_ui(PrologueState.craft_blue(selected_inv_idx))
	)
	craft_row.add_child(btn_blue)

	var btn_gold := Button.new()
	btn_gold.text = "用【百年金漆罐】(升黃/加詞綴)"
	btn_gold.pressed.connect(func() -> void:
		_refresh_inventory_ui(PrologueState.craft_gold(selected_inv_idx))
	)
	craft_row.add_child(btn_gold)

	var btn_chaos := Button.new()
	btn_chaos.text = "用【史萊姆洗白劑】(重洗黃裝)"
	btn_chaos.pressed.connect(func() -> void:
		_refresh_inventory_ui(PrologueState.craft_chaos(selected_inv_idx))
	)
	craft_row.add_child(btn_chaos)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(670, 185)
	root_v.add_child(scroll)
	inv_list_box = VBoxContainer.new()
	inv_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(inv_list_box)

	inv_feedback_label = _styled_label("點選下方一件背包裝備後，即可穿戴或點擊通貨造裝！", 14, Color("#8a2f2f"), false)
	root_v.add_child(inv_feedback_label)

func toggle_inventory() -> void:
	if input_locked and not inv_open:
		return
	inv_open = not inv_open
	inv_panel.visible = inv_open
	if inv_open:
		_refresh_inventory_ui("點選下方裝備即可穿戴，或使用造裝通貨即時洗詞綴！")

func _refresh_inventory_ui(msg := "") -> void:
	if not msg.is_empty():
		inv_feedback_label.text = msg
	inv_stats_label.text = "總屬性：攻擊 %d　｜　暴擊 %d%%　｜　破防增傷 +%d　｜　移速 %d%%　｜　銅幣 %d¢" % [
		PrologueState.get_total_atk(),
		PrologueState.get_total_crit(),
		PrologueState.get_stagger_bonus(),
		int(round(PrologueState.get_speed_multiplier() * 100.0)),
		PrologueState.coins
	]
	var w_txt := PrologueState.format_item_details(PrologueState.equipped_weapon) if not PrologueState.equipped_weapon.is_empty() else "（空）"
	var s_txt := PrologueState.format_item_details(PrologueState.equipped_saddle) if not PrologueState.equipped_saddle.is_empty() else "（標準皮鞍）"
	inv_equipped_label.text = "已裝備武器：%s\n已裝備狼鞍：%s" % [w_txt, s_txt]
	inv_currency_label.text = "造裝通貨：改裝藍印章 x%d　｜　百年金漆罐 x%d　｜　史萊姆洗白劑 x%d" % [
		PrologueState.orb_blue, PrologueState.orb_gold, PrologueState.orb_chaos
	]

	for c in inv_list_box.get_children():
		c.queue_free()
	if PrologueState.inventory.is_empty():
		inv_list_box.add_child(_styled_label("背包目前為空。去地圖三擊敗小怪或精英班長就能噴出裝備與通貨！", 14, Color("#6b4a35"), false))
	else:
		for i in range(PrologueState.inventory.size()):
			var item: Dictionary = PrologueState.inventory[i]
			var btn := Button.new()
			var prefix := "▶ " if i == selected_inv_idx else "   "
			btn.text = prefix + PrologueState.format_item_details(item)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_color_override("font_color", PrologueState.rarity_color(item["rarity"]))
			var cap_idx := i
			btn.pressed.connect(func() -> void:
				selected_inv_idx = cap_idx
				_refresh_inventory_ui("已選取：" + PrologueState.format_item_title(item))
			)
			inv_list_box.add_child(btn)
	update_status_line()

func _make_hotbar_slot(parent: HBoxContainer, key_txt: String, title_txt: String, accent: Color) -> Array:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(108, 58)
	slot.add_theme_stylebox_override("panel", make_panel_style(UI_DARK_BG, accent, 12, 2, 8, 6))
	parent.add_child(slot)

	var overlay_host := Control.new()
	overlay_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(overlay_host)

	var cd_rect := ColorRect.new()
	cd_rect.color = Color(0.05, 0.06, 0.12, 0.65)
	cd_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cd_rect.visible = false
	overlay_host.add_child(cd_rect)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)
	var k := _styled_label(key_txt, 12, accent.lightened(0.25), false)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(k)
	var t := _styled_label(title_txt, 14, Color("#fff8e8"), false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(t)
	return [slot, cd_rect, t]

func _styled_label(words: String, size: int, color: Color, with_outline := true) -> Label:
	var l := Label.new()
	l.text = words
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if with_outline:
		l.add_theme_color_override("font_outline_color", Color("#181b26"))
		l.add_theme_constant_override("outline_size", 6)
	return l

func set_zone_objective(zone_name: String, goal: String) -> void:
	zone_badge_label.text = "🗺️  " + zone_name
	objective_label.text = goal

func set_prompt(text_val: String) -> void:
	prompt_label.text = text_val
	prompt_panel.visible = not text_val.is_empty()

func update_boss_bar(visible_flag: bool, boss_title: String, hp_val: int, max_hp_val: int, state_txt := "", badge_col := GOLD) -> void:
	boss_panel.visible = visible_flag
	if not visible_flag:
		return
	boss_name_label.text = boss_title
	boss_hp_bar.max_value = max_hp_val
	boss_hp_bar.value = hp_val
	boss_state_badge.text = state_txt
	boss_state_badge.add_theme_color_override("font_color", badge_col)

func set_hud_visible(flag: bool) -> void:
	if hud_root:
		hud_root.visible = flag

func feet() -> Vector3:
	return wolf.position if PrologueState.mounted else player.position

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func near(pos: Vector3, dist := 2.2) -> bool:
	return flat(feet() - pos).length() < dist

func show_player_emote(icon: String, duration := 1.5) -> void:
	player_emote.text = icon
	emote_timer = duration
	player_emote.scale = Vector3.ONE * 0.4
	create_tween().tween_property(player_emote, "scale", Vector3.ONE, 0.18)

func show_subtitle(words: String, duration := 3.5) -> void:
	subtitle_label.text = words
	subtitle_panel.visible = not words.is_empty()
	subtitle_timer = duration

func move_body(body: CharacterBody3D, dir: Vector3, speed: float) -> void:
	body.velocity = dir * speed
	if dir.length_squared() > 0.002:
		body.rotation.y = atan2(dir.x, dir.z)
	body.move_and_slide()

func step_shared_physics(delta: float, cam_override_target := Vector3.INF) -> bool:
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return false

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	wolf_charge_cooldown = maxf(0.0, wolf_charge_cooldown - delta)
	wolf_charge_timer = maxf(0.0, wolf_charge_timer - delta)
	shake_time = maxf(0.0, shake_time - delta)

	if emote_timer > 0.0:
		emote_timer -= delta
		if emote_timer <= 0.0:
			player_emote.text = ""
	if subtitle_timer > 0.0:
		subtitle_timer -= delta
		if subtitle_timer <= 0.0:
			subtitle_label.text = ""
			subtitle_panel.hide()

	_update_hotbar_visuals()

	if input_locked or inv_open or PrologueState.is_transitioning:
		bird.position = player.position + Vector3(0.0, 1.45 + sin(Time.get_ticks_msec() * 0.006) * 0.05, 0.0)
		return true

	var h := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var v := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var right := flat(camera.transform.basis.x).normalized()
	var fwd := flat(camera.transform.basis.z).normalized()
	var dir := (right * h + fwd * v).limit_length()
	var spd_mult := PrologueState.get_speed_multiplier()

	if air_slam_active:
		vertical_vel -= 28.0 * delta
		player.position.y += vertical_vel * delta
		move_body(player, dir, 5.6 * spd_mult)
		if player.position.y <= 0.0:
			player.position.y = 0.0
			_finish_air_slam()
	elif PrologueState.mounted:
		var spd := (12.0 if wolf_charge_timer > 0.0 else 7.6) * spd_mult
		move_body(wolf, dir if dir.length() > 0.05 else (Vector3.RIGHT if wolf_charge_timer > 0.0 else Vector3.ZERO), spd)
		player.position = wolf.position + Vector3.UP * 1.38
		player.rotation.y = wolf.rotation.y
	else:
		move_body(player, dir, 5.2 * spd_mult)
		update_wolf_follow(delta)

	var bird_target := (wolf.position + Vector3(0, 1.56, 0.85)) if PrologueState.mounted else (player.position + Vector3(0, 1.45, 0))
	bird.position = bird.position.lerp(bird_target, clampf(delta * 10.0, 0.0, 1.0))

	var target := cam_override_target if cam_override_target != Vector3.INF else feet()
	position_camera(target, clampf(delta * 4.8, 0.0, 1.0))
	if shake_time > 0.0:
		camera.position += Vector3(randf_range(-0.18, 0.18), randf_range(-0.12, 0.12), 0.0)
	return true

func _update_hotbar_visuals() -> void:
	if not slot_attack:
		return
	slot_attack.modulate = Color.WHITE if (can_attack and PrologueState.has_sword and not PrologueState.mounted) else Color(0.55, 0.55, 0.62, 0.85)
	slot_attack_cd.visible = attack_cooldown > 0.0
	if PrologueState.mounted:
		slot_mount_sub.text = "彈飛下劈!" if PrologueState.has_spring_saddle else "下鞍步行"
	else:
		slot_mount_sub.text = "上鞍騎乘"
	slot_wolf_cd.visible = wolf_charge_cooldown > 0.0
	if wolf_charge_cooldown > 0.0:
		slot_wolf_cd.scale.y = clampf(wolf_charge_cooldown / wolf_charge_max, 0.0, 1.0)

func update_wolf_follow(_delta: float) -> void:
	var diff := flat(player.position - wolf.position)
	move_body(wolf, diff.normalized() if diff.length() > 1.85 else Vector3.ZERO, 6.0)

func _unhandled_input(event: InputEvent) -> void:
	if PrologueState.is_transitioning:
		return
	if on_map_input(event):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		toggle_inventory()
		return
	if input_locked or inv_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E: on_interact()
			KEY_F: toggle_mount()
			KEY_Q: on_wolf_action()
			KEY_J: perform_sword_attack()
			KEY_R: PrologueState.reset_all()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		perform_sword_attack()

func on_map_input(_event: InputEvent) -> bool:
	return false

func on_interact() -> void:
	pass

func on_wolf_action() -> void:
	if wolf_charge_cooldown > 0.0:
		return
	wolf_charge_cooldown = wolf_charge_max
	wolf_charge_timer = 0.45
	show_player_emote("!", 0.7)

func on_sword_hit() -> void:
	pass

func on_air_slam_land() -> void:
	pass

func perform_sword_attack() -> void:
	if not can_attack or not PrologueState.has_sword or PrologueState.mounted or attack_cooldown > 0.0:
		return
	attack_cooldown = 0.30
	var tw := create_tween()
	tw.tween_property(player_sword, "rotation:y", -1.45, 0.10)
	tw.tween_property(player_sword, "rotation:y", 0.0, 0.16)
	on_sword_hit()

func toggle_mount() -> void:
	if air_slam_active:
		return
	if PrologueState.mounted:
		PrologueState.mounted = false
		if PrologueState.has_spring_saddle:
			player.position = wolf.position + Vector3(0, 1.55, 0)
			air_slam_active = true
			vertical_vel = 11.4
			show_player_emote("✨", 1.2)
			return
		var shape := SphereShape3D.new()
		shape.radius = PLAYER_RADIUS
		var params := PhysicsShapeQueryParameters3D.new()
		params.shape = shape
		params.collision_mask = 1
		for off in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
			var cand: Vector3 = wolf.position + off * 1.18
			params.transform.origin = cand + Vector3.UP * PLAYER_RADIUS
			if get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty():
				player.position = cand
				return
		player.position = wolf.position + Vector3(0, 0, 1.15)
	elif near(wolf.position, 2.7):
		PrologueState.mounted = true
		player.position = wolf.position + Vector3.UP * 1.38
		show_player_emote("✨", 0.8)

func _finish_air_slam() -> void:
	air_slam_active = false
	shake_time = 0.22
	var ring := marker(player.position, GOLD, 2.6)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(1.6, 1.0, 1.6), 0.25)
	tw.tween_callback(ring.queue_free)
	show_player_emote("✨", 1.3)
	show_subtitle("彈簧試驗鞍座・飛天暴擊下劈！(200% CRIT)", 2.2)
	on_air_slam_land()

func update_status_line() -> void:
	var hearts := ""
	for i in range(5):
		hearts += "♥ " if i < PrologueState.player_hp else "♡ "
	hp_hearts_label.text = "旅人  " + hearts.strip_edges()
	hp_bar.value = PrologueState.player_hp

	var tags: Array[String] = ["攻%d" % PrologueState.get_total_atk()]
	tags.append("包%d" % PrologueState.inventory.size())
	if not PrologueState.campfire_dish.is_empty():
		tags.append("🍲" + PrologueState.campfire_dish)
	if PrologueState.has_spring_saddle:
		tags.append("🌀彈簧鞍")
	if PrologueState.mounted:
		tags.append("🐺騎乘")
	gear_tags_label.text = " ｜ ".join(tags)

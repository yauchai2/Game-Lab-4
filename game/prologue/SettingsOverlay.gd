extends Control

# PoE 2-Style Settings & Controls Menu (Press [Esc] to toggle)
# Audio Volumes, Playful Storybook Music Toggle, Screen Shake, Controls Reference & Quick Actions

var _panel: Panel
var _bgm_slider: HSlider
var _sfx_slider: HSlider
var _bgm_val_lbl: Label
var _sfx_val_lbl: Label
var _music_mode_btn: CheckButton
var _shake_btn: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.10, 0.16, 0.72)
	add_child(dim)

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f7f0de")
	sb.border_color = Color("#c89b54")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var title := Label.new()
	title.position = Vector2(26, 18)
	title.text = "⚙ 遊戲設定與 PoE 2 操作說明"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#2b3648"))
	_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(618, 18)
	close_btn.custom_minimum_size = Vector2(78, 34)
	close_btn.text = "✕ [Esc]"
	close_btn.pressed.connect(close_page)
	_panel.add_child(close_btn)

	# --- Audio & Display Controls ---
	var sec1 := Label.new()
	sec1.position = Vector2(28, 66)
	sec1.text = "🎵 音訊與手感設定"
	sec1.add_theme_font_size_override("font_size", 15)
	sec1.add_theme_color_override("font_color", Color("#784421"))
	_panel.add_child(sec1)

	var bgm_lbl := Label.new()
	bgm_lbl.position = Vector2(28, 98)
	bgm_lbl.text = "背景音樂音量"
	bgm_lbl.add_theme_color_override("font_color", Color("#2b3648"))
	_panel.add_child(bgm_lbl)

	_bgm_slider = HSlider.new()
	_bgm_slider.position = Vector2(150, 100)
	_bgm_slider.size = Vector2(360, 22)
	_bgm_slider.min_value = 0.0
	_bgm_slider.max_value = 1.0
	_bgm_slider.step = 0.05
	_bgm_slider.value_changed.connect(func(v: float) -> void:
		PrologueState.set_bgm_volume(v)
		_bgm_val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	_panel.add_child(_bgm_slider)

	_bgm_val_lbl = Label.new()
	_bgm_val_lbl.position = Vector2(525, 98)
	_bgm_val_lbl.add_theme_color_override("font_color", Color("#5c6473"))
	_panel.add_child(_bgm_val_lbl)

	var sfx_lbl := Label.new()
	sfx_lbl.position = Vector2(28, 132)
	sfx_lbl.text = "趣味音效音量"
	sfx_lbl.add_theme_color_override("font_color", Color("#2b3648"))
	_panel.add_child(sfx_lbl)

	_sfx_slider = HSlider.new()
	_sfx_slider.position = Vector2(150, 134)
	_sfx_slider.size = Vector2(360, 22)
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		PrologueState.set_sfx_volume(v)
		_sfx_val_lbl.text = "%d%%" % int(round(v * 100.0))
	)
	_panel.add_child(_sfx_slider)

	_sfx_val_lbl = Label.new()
	_sfx_val_lbl.position = Vector2(525, 132)
	_sfx_val_lbl.add_theme_color_override("font_color", Color("#5c6473"))
	_panel.add_child(_sfx_val_lbl)

	_music_mode_btn = CheckButton.new()
	_music_mode_btn.position = Vector2(28, 166)
	_music_mode_btn.text = "使用《補簽遠行》趣味輕快主題八音盒／木琴配樂（關閉則改播管弦 MP3）"
	_music_mode_btn.add_theme_color_override("font_color", Color("#2b3648"))
	_music_mode_btn.toggled.connect(func(on: bool) -> void:
		PrologueState.set_playful_bgm(on)
	)
	_panel.add_child(_music_mode_btn)

	_shake_btn = CheckButton.new()
	_shake_btn.position = Vector2(28, 200)
	_shake_btn.text = "啟用戰鬥打擊鏡頭震動（Screen Shake）"
	_shake_btn.add_theme_color_override("font_color", Color("#2b3648"))
	_shake_btn.toggled.connect(func(on: bool) -> void:
		PrologueState.screen_shake_enabled = on
	)
	_panel.add_child(_shake_btn)

	# --- PoE 2 Controls Reference ---
	var sec2 := Label.new()
	sec2.position = Vector2(28, 244)
	sec2.text = "🎮 PoE 2 操作按鍵總覽"
	sec2.add_theme_font_size_override("font_size", 15)
	sec2.add_theme_color_override("font_color", Color("#784421"))
	_panel.add_child(sec2)

	var guide := Label.new()
	guide.position = Vector2(28, 274)
	guide.size = Vector2(664, 155)
	guide.text = (
		"WASD：角色移動（支援 PoE 2 滑鼠游標方向瞄準）\n" +
		"滑鼠左鍵 (LMB) / J：主攻擊（三段旋風斬／彈弓騎射）\n" +
		"滑鼠右鍵 (RMB) / Q：巨狼衝撞破防 / 引力聚怪\n" +
		"Space：俐落翻滾閃避（0.30s 無敵幀）　　1：喝生命茶壺\n" +
		"E / F：互動拾取 / 上下巨狼（裝備彈簧鞍可飛天重劈）\n" +
		"I：背包與造裝　　G：技能與印章頁　　U：世界地圖　　Tab：迷霧小地圖　　M：靜音"
	)
	guide.add_theme_font_size_override("font_size", 13)
	guide.add_theme_color_override("font_color", Color("#3b4454"))
	_panel.add_child(guide)

	# --- Bottom Utility Buttons ---
	var row := HBoxContainer.new()
	row.position = Vector2(28, 452)
	row.size = Vector2(664, 44)
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)

	var town_btn := Button.new()
	town_btn.custom_minimum_size = Vector2(210, 42)
	town_btn.text = "✦ 傳送回主城（雲丘營地）"
	town_btn.pressed.connect(func() -> void:
		close_page()
		PrologueState.transition_to("res://prologue/CloudhillTown.tscn", "from_waypoint", "雲丘停戰營地")
	)
	row.add_child(town_btn)

	var reset_btn := Button.new()
	reset_btn.custom_minimum_size = Vector2(180, 42)
	reset_btn.text = "↺ 重置全部進度"
	reset_btn.pressed.connect(func() -> void:
		close_page()
		PrologueState.reset_all()
	)
	row.add_child(reset_btn)

	var resume_btn := Button.new()
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.text = "繼續冒險 [Esc]"
	resume_btn.pressed.connect(close_page)
	row.add_child(resume_btn)

func open_page() -> void:
	visible = true
	_bgm_slider.value = PrologueState.bgm_volume
	_sfx_slider.value = PrologueState.sfx_volume
	_bgm_val_lbl.text = "%d%%" % int(round(PrologueState.bgm_volume * 100.0))
	_sfx_val_lbl.text = "%d%%" % int(round(PrologueState.sfx_volume * 100.0))
	_music_mode_btn.button_pressed = PrologueState.prefer_playful_bgm
	_shake_btn.button_pressed = PrologueState.screen_shake_enabled

func close_page() -> void:
	visible = false

func toggle_page() -> bool:
	if visible:
		close_page()
	else:
		open_page()
	return visible

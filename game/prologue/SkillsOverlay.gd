extends Control

# PoE 2-Style Skills & Support Seals Page (Press [G] to toggle)
# Minimalist @amelicart warm parchment storybook aesthetic

var _panel: Panel
var _skills_box: VBoxContainer
var _seals_box: HBoxContainer
var _status_lbl: Label

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
	_panel.offset_left = -410
	_panel.offset_right = 410
	_panel.offset_top = -265
	_panel.offset_bottom = 265
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f7f0de")
	sb.border_color = Color("#c89b54")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var title := Label.new()
	title.position = Vector2(26, 18)
	title.text = "⚔ 技能寶石與輔助印章（PoE 2 技能頁）"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#2b3648"))
	_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(732, 18)
	close_btn.custom_minimum_size = Vector2(66, 34)
	close_btn.text = "✕ [G]"
	close_btn.pressed.connect(close_page)
	_panel.add_child(close_btn)

	var sub := Label.new()
	sub.position = Vector2(26, 50)
	sub.text = "所有主動技能皆支援滑鼠游標瞄準 · 切換下方輔助印章可立即改變技能形態"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color("#5c6473"))
	_panel.add_child(sub)

	_skills_box = VBoxContainer.new()
	_skills_box.position = Vector2(26, 82)
	_skills_box.size = Vector2(768, 295)
	_skills_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_skills_box)

	var seal_header := Label.new()
	seal_header.position = Vector2(26, 392)
	seal_header.text = "💠 輔助印章插槽（點擊即可鑲嵌／切換）"
	seal_header.add_theme_font_size_override("font_size", 15)
	seal_header.add_theme_color_override("font_color", Color("#784421"))
	_panel.add_child(seal_header)

	_seals_box = HBoxContainer.new()
	_seals_box.position = Vector2(26, 420)
	_seals_box.size = Vector2(768, 46)
	_seals_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_seals_box)

	_status_lbl = Label.new()
	_status_lbl.position = Vector2(26, 480)
	_status_lbl.add_theme_font_size_override("font_size", 13)
	_status_lbl.add_theme_color_override("font_color", Color("#8a4b16"))
	_panel.add_child(_status_lbl)

func open_page() -> void:
	visible = true
	refresh()

func close_page() -> void:
	visible = false

func toggle_page() -> bool:
	if visible:
		close_page()
	else:
		open_page()
	return visible

func refresh(msg := "") -> void:
	for c in _skills_box.get_children():
		c.queue_free()
	var atk := PrologueState.get_total_atk()
	var crit := PrologueState.get_total_crit()
	var stag := PrologueState.get_stagger_bonus()
	var is_sling := PrologueState.is_slingshot()
	var skill_defs := [
		{
			"key": "滑鼠左鍵 (LMB)",
			"name": "旅人彈弓連射" if is_sling else "斥候三段連斬・旋風",
			"stats": "攻擊力 %d ｜ 暴擊 %d%% ｜ %s" % [atk, crit, "支援騎狼移動射擊！" if is_sling else "第 3 段 360° 旋風斬 (160% 傷害)"],
			"desc": "朝滑鼠游標方向精準揮砍或射擊。鑲嵌【分裂印章】時可額外發射三連彈或金色劍氣波！",
			"accent": Color("#4da1e8"),
		},
		{
			"key": "滑鼠右鍵 (RMB) / Q",
			"name": "巨狼衝撞・破防吼叫",
			"stats": "冷卻 1.4s ｜ 破防增傷 +%d ｜ 可撞碎路障與打斷紅光蓄力" % stag,
			"desc": "指揮巨狼朝游標方向衝鋒，打斷 Boss 紅光蓄力並使其陷入破防踉蹌！鑲嵌【引力印章】時附帶大範圍聚怪暈眩。",
			"accent": Color("#d97836"),
		},
		{
			"key": "Space",
			"name": "俐落翻滾閃避（Dodge Roll）",
			"stats": "無敵幀 0.30s ｜ 冷卻 0.45s ｜ 零消耗",
			"desc": "PoE 2 核心保命動作，翻滾瞬間完全免疫敵人紅圈重擊，騎乘巨狼時可觸發疾風衝刺閃避。",
			"accent": Color("#4ecdc4"),
		},
		{
			"key": "F",
			"name": "巨狼上鞍 / 彈簧飛天重劈" if PrologueState.has_spring_saddle else "巨狼上鞍 / 下鞍",
			"stats": "騎乘移速 +45%% ｜ %s" % ("已裝備《彈簧試驗鞍座》：下騎彈飛 200% 暴擊重劈！" if PrologueState.has_spring_saddle else "裝備彈簧鞍後可解鎖飛天重劈"),
			"desc": "在廣袤野外高速趕路，或於戰鬥中一鍵飛天重劈清場與躍上高台秘寶點。",
			"accent": Color("#498e62"),
		},
	]
	for sd in skill_defs:
		var card := PanelContainer.new()
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color("#efe4cc")
		csb.border_color = sd["accent"]
		csb.set_border_width_all(2)
		csb.set_corner_radius_all(8)
		csb.content_margin_left = 14
		csb.content_margin_right = 14
		csb.content_margin_top = 8
		csb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", csb)
		_skills_box.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card.add_child(vb)

		var top := HBoxContainer.new()
		vb.add_child(top)
		var nm := Label.new()
		nm.text = "[%s]  %s" % [String(sd["key"]), String(sd["name"])]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", Color("#222b38"))
		top.add_child(nm)

		var st := Label.new()
		st.text = String(sd["stats"])
		st.add_theme_font_size_override("font_size", 12)
		st.add_theme_color_override("font_color", Color("#7d4a1e"))
		top.add_child(st)

		var ds := Label.new()
		ds.text = String(sd["desc"])
		ds.add_theme_font_size_override("font_size", 12)
		ds.add_theme_color_override("font_color", Color("#4e596b"))
		vb.add_child(ds)

	for c in _seals_box.get_children():
		c.queue_free()
	var all_seals: Array[String] = ["split", "vortex", "paycheck"]
	for sid: String in all_seals:
		var unlocked: bool = PrologueState.unlocked_seals.has(sid)
		var active: bool = PrologueState.active_seal == sid
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(244, 42)
		if not unlocked:
			btn.disabled = true
			btn.text = "🔒 " + PrologueState.get_seal_title(sid).split("(")[0] + "（探索解鎖）"
		else:
			btn.text = ("★ " if active else "○ ") + PrologueState.get_seal_title(sid).split("(")[0]
			var cap_sid: String = sid
			btn.pressed.connect(func() -> void:
				var next_id: String = "" if PrologueState.active_seal == cap_sid else cap_sid
				var res: String = PrologueState.set_active_seal(next_id)
				refresh(res)
			)
		_seals_box.add_child(btn)

	if not msg.is_empty():
		_status_lbl.text = msg
	else:
		var cur_s := PrologueState.get_seal_title(PrologueState.active_seal)
		_status_lbl.text = "目前鑲嵌印章：%s  ｜  提示：探索湖畔釣魚、洞窟與沙洲寶箱可解鎖全部 3 枚印章" % cur_s

extends Control

# PoE 2-Style Class, Ascendancy, Skills & Support Seals Page (Press [G] to toggle)
# Minimalist @amelicart warm parchment storybook aesthetic

var _panel: Panel
var _class_box: HBoxContainer
var _asc_box: HBoxContainer
var _skills_box: VBoxContainer
var _seals_box: HBoxContainer
var _status_lbl: Label

const CLASS_DEFS := [
	{"id": "swordsman", "title": "⚔ 停戰劍士", "asc": ["red_stamp", "iaido"]},
	{"id": "malletier", "title": "🔨 工匠槌手", "asc": ["demolition", "skillet_chef"]},
	{"id": "ranger", "title": "🥢 雲海遊俠", "asc": ["staff_dancer", "angler"]},
	{"id": "arcanist", "title": "📖 書記魔導士", "asc": ["spellbook", "bartender"]},
]

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
	_panel.offset_left = -430
	_panel.offset_right = 430
	_panel.offset_top = -300
	_panel.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f7f0de")
	sb.border_color = Color("#c89b54")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var title := Label.new()
	title.position = Vector2(26, 16)
	title.text = "⚔ 職業・昇華（Ascendancy）與技能印章頁"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("#2b3648"))
	_panel.add_child(title)

	var close_btn := Button.new()
	close_btn.position = Vector2(772, 16)
	close_btn.custom_minimum_size = Vector2(66, 34)
	close_btn.text = "✕ [G]"
	close_btn.pressed.connect(close_page)
	_panel.add_child(close_btn)

	var cls_hdr := Label.new()
	cls_hdr.position = Vector2(26, 50)
	cls_hdr.text = "🧭 基礎職業與昇華路線（隨時可切換流派體驗不同戰鬥手感）"
	cls_hdr.add_theme_font_size_override("font_size", 13)
	cls_hdr.add_theme_color_override("font_color", Color("#784421"))
	_panel.add_child(cls_hdr)

	_class_box = HBoxContainer.new()
	_class_box.position = Vector2(26, 74)
	_class_box.size = Vector2(808, 36)
	_class_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_class_box)

	_asc_box = HBoxContainer.new()
	_asc_box.position = Vector2(26, 116)
	_asc_box.size = Vector2(808, 36)
	_asc_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_asc_box)

	_skills_box = VBoxContainer.new()
	_skills_box.position = Vector2(26, 164)
	_skills_box.size = Vector2(808, 294)
	_skills_box.add_theme_constant_override("separation", 7)
	_panel.add_child(_skills_box)

	var seal_header := Label.new()
	seal_header.position = Vector2(26, 468)
	seal_header.text = "💠 輔助印章插槽（點擊即可鑲嵌／切換）"
	seal_header.add_theme_font_size_override("font_size", 14)
	seal_header.add_theme_color_override("font_color", Color("#784421"))
	_panel.add_child(seal_header)

	_seals_box = HBoxContainer.new()
	_seals_box.position = Vector2(26, 494)
	_seals_box.size = Vector2(808, 42)
	_seals_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_seals_box)

	_status_lbl = Label.new()
	_status_lbl.position = Vector2(26, 550)
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
	for c in _class_box.get_children():
		c.queue_free()
	var active_cls_def: Dictionary = CLASS_DEFS[0]
	for cd in CLASS_DEFS:
		var cid := String(cd["id"])
		var is_cur := cid == PrologueState.player_class
		if is_cur:
			active_cls_def = cd
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(194, 34)
		cb.text = ("★ " if is_cur else "   ") + String(cd["title"])
		var cap_cid := cid
		var default_asc: String = String((cd["asc"] as Array)[0])
		cb.pressed.connect(func() -> void:
			refresh(PrologueState.set_class_and_ascendancy(cap_cid, default_asc))
		)
		_class_box.add_child(cb)

	for c in _asc_box.get_children():
		c.queue_free()
	var asc_list: Array = active_cls_def["asc"]
	for aid_v in asc_list:
		var aid := String(aid_v)
		var is_a := aid == PrologueState.player_ascendancy
		var ab := Button.new()
		ab.custom_minimum_size = Vector2(398, 34)
		ab.text = ("✦ 昇華：" if is_a else "○ 昇華：") + PrologueState.get_ascendancy_title(aid)
		var cap_aid := aid
		var cap_cls := String(active_cls_def["id"])
		ab.pressed.connect(func() -> void:
			refresh(PrologueState.set_class_and_ascendancy(cap_cls, cap_aid))
		)
		_asc_box.add_child(ab)

	for c in _skills_box.get_children():
		c.queue_free()
	var atk := PrologueState.get_total_atk()
	var crit := PrologueState.get_total_crit()
	var stag := PrologueState.get_stagger_bonus()
	var wsp := PrologueState.get_weapon_special()
	var main_name := "斥候三段連斬・旋風"
	var main_note := "第 3 段 360° 旋風斬 (160% 傷害)"
	if wsp == "slingshot":
		main_name = "旅人彈弓連射"
		main_note = "支援騎狼移動射擊！"
	elif wsp == "mallet":
		main_name = "🔨 巨型工藝木槌・震地重砸"
		main_note = "135% 重擊＋3.8m 大範圍衝擊波"
	elif wsp == "skillet":
		main_name = "🍳 鑄鐵平底鍋・彈幕全反擊"
		main_note = "揮擊直接把敵方光球反彈回去！"
	elif wsp == "staff":
		main_name = "🥢 紅白雙頭長棍・雲步連舞"
		main_note = "0.19s 極速攻速＋3.7m 長距橫掃"

	var skill_defs := [
		{
			"key": "滑鼠左鍵 (LMB)",
			"name": main_name,
			"stats": "攻擊力 %d ｜ 暴擊 %d%% ｜ %s" % [atk, crit, main_note],
			"desc": "朝滑鼠游標瞄準。雲丘主城紅篷商人已備齊【巨型木槌／鑄鐵平底鍋／雙頭長棍／彈弓】供自由切換！",
			"accent": Color("#4da1e8"),
		},
		{
			"key": "滑鼠右鍵 (RMB) / Q",
			"name": "巨狼衝撞・破防吼叫",
			"stats": "冷卻 4.2s ｜ 破防增傷 +%d ｜ 敵人受控後具 5 秒霸體" % stag,
			"desc": "指揮巨狼朝游標衝鋒，打斷 Boss 紅光蓄力並使其陷入破防踉蹌！鑲嵌【引力印章】附帶聚怪暈眩。",
			"accent": Color("#d97836"),
		},
		{
			"key": "Space",
			"name": "俐落翻滾閃避（Dodge Roll）",
			"stats": "無敵幀 0.30s ｜ 冷卻 %ss ｜ 零消耗" % ("0.34" if PrologueState.player_ascendancy == "iaido" else "0.45"),
			"desc": "翻滾瞬間完全免疫紅圈重擊與彈幕。若昇華【疾風居合客】，翻滾後下一擊必定觸發金色暴擊！",
			"accent": Color("#4ecdc4"),
		},
		{
			"key": "F",
			"name": "巨狼上鞍 / 彈簧飛天重劈" if PrologueState.has_spring_saddle else "巨狼上鞍 / 下鞍",
			"stats": "騎乘移速 +45%% ｜ %s" % ("已裝備《彈簧試驗鞍座》：下騎彈飛 200% 暴擊重劈！" if PrologueState.has_spring_saddle else "裝備彈簧鞍後可解鎖飛天重劈"),
			"desc": "在非線性大型荒野中高速趕路，或於戰鬥中一鍵飛天重劈清場與躍上高台秘寶點。",
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
		csb.content_margin_top = 6
		csb.content_margin_bottom = 6
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
		nm.add_theme_font_size_override("font_size", 14)
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
		btn.custom_minimum_size = Vector2(256, 38)
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
		_status_lbl.text = "當前流派：%s（%s） ｜ 印章：%s" % [
			PrologueState.get_class_title(),
			PrologueState.get_ascendancy_title(),
			PrologueState.get_seal_title(PrologueState.active_seal)
		]

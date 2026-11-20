extends Node

# Persistent state shared across standalone PoE 2-style prologue zones
var has_started := false
var has_sword := false
var has_spring_saddle := false
var campfire_dish := ""
var flask_charges := 2
var skull_gift_claimed := false
var road_intro_played := false
var timber_broken := false
var gate_opened := false
var boss_retired := false
var high_chest_claimed := false
var waypoint_road_unlocked := false
var mounted := false
var player_hp := 5
var coins := 50

# PoE 2-style Crafting Currencies
var orb_blue := 2   # 改裝藍印章 (Transmutation)
var orb_gold := 1   # 百年金漆罐 (Regal / Exalted)
var orb_chaos := 2  # 史萊姆洗白劑 (Chaos)

# Dual-track Equipment & Inventory (Dictionaries for clean zero-dependency graybox)
var equipped_weapon: Dictionary = {}
var equipped_saddle: Dictionary = {}
var inventory: Array[Dictionary] = []

var spawn_tag := "default"
var is_transitioning := false

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _zone_banner: Label
var _sfx_player: AudioStreamPlayer
var _sfx_gen: AudioStreamGenerator

const AFFIX_POOL := [
	{"name": "鋒利 (+1 攻擊)", "stat": "atk", "val": 1},
	{"name": "重擊 (+2 攻擊)", "stat": "atk", "val": 2},
	{"name": "會心 (+25% 暴擊)", "stat": "crit", "val": 25},
	{"name": "破甲 (+1 破防增傷)", "stat": "stagger_dmg", "val": 1},
	{"name": "輕盈 (+12% 移速)", "stat": "spd", "val": 12},
]

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.11, 0.14, 0.24, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

	_zone_banner = Label.new()
	_zone_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_zone_banner.position = Vector2(-260, -28)
	_zone_banner.custom_minimum_size = Vector2(520, 56)
	_zone_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zone_banner.add_theme_font_size_override("font_size", 28)
	_zone_banner.add_theme_color_override("font_color", Color("#fff2cc"))
	_zone_banner.add_theme_color_override("font_outline_color", Color("#171b2b"))
	_zone_banner.add_theme_constant_override("outline_size", 8)
	_zone_banner.modulate.a = 0.0
	_zone_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_zone_banner)

	# Procedural zero-dependency storybook SFX player
	_sfx_gen = AudioStreamGenerator.new()
	_sfx_gen.mix_rate = 22050.0
	_sfx_gen.buffer_length = 0.35
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.stream = _sfx_gen
	_sfx_player.volume_db = -8.0
	add_child(_sfx_player)
	_sfx_player.play()

func play_sfx(kind: String) -> void:
	if not _sfx_player or not _sfx_player.playing:
		return
	var pb := _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var sr := 22050.0
	var frames := 0
	var f0 := 440.0
	var f1 := 440.0
	var amp := 0.22
	var noise_mix := 0.0
	match kind:
		"slash":
			frames = int(sr * 0.09)
			f0 = 520.0
			f1 = 190.0
			noise_mix = 0.35
		"slingshot":
			frames = int(sr * 0.11)
			f0 = 310.0
			f1 = 760.0
			amp = 0.25
		"hit":
			frames = int(sr * 0.08)
			f0 = 210.0
			f1 = 75.0
			amp = 0.32
			noise_mix = 0.25
		"coin":
			frames = int(sr * 0.14)
			f0 = 880.0
			f1 = 1320.0
			amp = 0.20
		"stamp":
			frames = int(sr * 0.22)
			f0 = 160.0
			f1 = 52.0
			amp = 0.42
			noise_mix = 0.30
		"craft":
			frames = int(sr * 0.18)
			f0 = 523.25
			f1 = 1046.5
			amp = 0.24
		"heal":
			frames = int(sr * 0.20)
			f0 = 440.0
			f1 = 659.25
			amp = 0.22
		"wood":
			frames = int(sr * 0.14)
			f0 = 180.0
			f1 = 65.0
			amp = 0.36
			noise_mix = 0.55
		_:
			return
	var avail := pb.get_frames_available()
	var count := mini(frames, avail)
	if count <= 0:
		return
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / sr
		var env := (1.0 - t) * (1.0 - t)
		var sig := sin(phase) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		var s := sig * env * amp
		pb.push_frame(Vector2(s, s))

func reset_all() -> void:
	has_started = false
	has_sword = false
	has_spring_saddle = false
	campfire_dish = ""
	flask_charges = 2
	skull_gift_claimed = false
	road_intro_played = false
	timber_broken = false
	gate_opened = false
	boss_retired = false
	high_chest_claimed = false
	waypoint_road_unlocked = false
	mounted = false
	player_hp = 5
	coins = 50
	orb_blue = 2
	orb_gold = 1
	orb_chaos = 2
	equipped_weapon = {}
	equipped_saddle = {}
	inventory.clear()
	spawn_tag = "default"
	transition_to("res://prologue/CampfireClearing.tscn", "default", "湖畔營火窩")

func transition_to(scene_path: String, target_spawn := "default", destination_title := "") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	spawn_tag = target_spawn
	_zone_banner.text = ("正在前往：" + destination_title) if not destination_title.is_empty() else ""

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_fade_rect, "color:a", 0.96, 0.22)
	if not destination_title.is_empty():
		tw.tween_property(_zone_banner, "modulate:a", 1.0, 0.18)
	tw.chain().tween_callback(func() -> void:
		get_tree().change_scene_to_file(scene_path)
		var tw_in := create_tween().set_parallel(true)
		tw_in.tween_property(_fade_rect, "color:a", 0.0, 0.30)
		tw_in.tween_property(_zone_banner, "modulate:a", 0.0, 0.20)
		tw_in.chain().tween_callback(func() -> void:
			is_transitioning = false
		)
	)

# --- PoE 2 Item Generation, Crafting & Stat Calculation ---
func make_item(item_name: String, slot: String, rarity: String, base_atk := 0, special := "") -> Dictionary:
	var affixes: Array = []
	var count := 0
	if rarity == "magic":
		count = 1
	elif rarity == "rare":
		count = 3
	for _i in range(count):
		affixes.append(_pick_random_affix(affixes))
	return {
		"name": item_name,
		"slot": slot, # "weapon" or "saddle"
		"rarity": rarity, # "normal", "magic", "rare", "unique"
		"base_atk": base_atk,
		"special": special, # "", "spring_slam", "slingshot"
		"affixes": affixes,
	}

func is_slingshot() -> bool:
	return not equipped_weapon.is_empty() and String(equipped_weapon.get("special", "")) == "slingshot"

func _pick_random_affix(existing: Array) -> Dictionary:
	var candidates: Array = []
	for a in AFFIX_POOL:
		var dup := false
		for e in existing:
			if e["name"] == a["name"]:
				dup = true
				break
		if not dup:
			candidates.append(a)
	if candidates.is_empty():
		return AFFIX_POOL[randi() % AFFIX_POOL.size()].duplicate()
	return candidates[randi() % candidates.size()].duplicate()

func add_item_to_inventory(item: Dictionary) -> void:
	inventory.append(item)

func equip_from_inventory(idx: int) -> String:
	if idx < 0 or idx >= inventory.size():
		return ""
	var item: Dictionary = inventory[idx]
	inventory.remove_at(idx)
	if item["slot"] == "weapon":
		if not equipped_weapon.is_empty():
			inventory.append(equipped_weapon)
		equipped_weapon = item
		has_sword = true
	else:
		if not equipped_saddle.is_empty():
			inventory.append(equipped_saddle)
		equipped_saddle = item
		has_spring_saddle = item["special"] == "spring_slam"
	play_sfx("craft")
	return "已裝備：" + format_item_title(item)

func craft_blue(idx: int) -> String:
	if orb_blue <= 0:
		return "改裝藍印章不足！"
	if idx < 0 or idx >= inventory.size():
		return "請先選取背包內的裝備。"
	var item: Dictionary = inventory[idx]
	if item["rarity"] != "normal":
		return "改裝藍印章僅能用於「白裝」底材！"
	orb_blue -= 1
	item["rarity"] = "magic"
	var affixes: Array = item["affixes"]
	affixes.append(_pick_random_affix(affixes))
	play_sfx("craft")
	return "造裝成功！" + format_item_title(item) + " 獲得新詞綴！"

func craft_gold(idx: int) -> String:
	if orb_gold <= 0:
		return "百年金漆罐不足！"
	if idx < 0 or idx >= inventory.size():
		return "請先選取背包內的裝備。"
	var item: Dictionary = inventory[idx]
	if item["rarity"] == "unique" or item["rarity"] == "normal":
		return "百年金漆罐僅能用於藍裝升階或黃裝加詞綴！"
	var affixes: Array = item["affixes"]
	if affixes.size() >= 4:
		return "該黃裝已達 4 詞綴上限！"
	orb_gold -= 1
	item["rarity"] = "rare"
	affixes.append(_pick_random_affix(affixes))
	play_sfx("craft")
	return "金漆升階成功！" + format_item_title(item) + " 新增一條詞綴！"

func craft_chaos(idx: int) -> String:
	if orb_chaos <= 0:
		return "史萊姆洗白劑不足！"
	if idx < 0 or idx >= inventory.size():
		return "請先選取背包內的裝備。"
	var item: Dictionary = inventory[idx]
	if item["rarity"] != "rare":
		return "史萊姆洗白劑僅能重洗「黃裝」詞綴！"
	orb_chaos -= 1
	var new_affixes: Array = []
	for _i in range(3):
		new_affixes.append(_pick_random_affix(new_affixes))
	item["affixes"] = new_affixes
	play_sfx("craft")
	return "洗白重鑄完成！" + format_item_title(item) + " 詞綴已刷新！"

func salvage_normal_items() -> Dictionary:
	var kept: Array[Dictionary] = []
	var count := 0
	for item in inventory:
		if item["rarity"] == "normal":
			count += 1
		else:
			kept.append(item)
	inventory = kept
	var gained_coins := count * 25
	var gained_blue := count
	var gained_chaos := int(count / 2)
	coins += gained_coins
	orb_blue += gained_blue
	orb_chaos += gained_chaos
	if count > 0:
		play_sfx("coin")
	return {"count": count, "coins": gained_coins, "blue": gained_blue, "chaos": gained_chaos}

func get_total_atk() -> int:
	var total := 1
	if not equipped_weapon.is_empty():
		total += int(equipped_weapon["base_atk"])
	for gear in [equipped_weapon, equipped_saddle]:
		if gear.is_empty():
			continue
		for a in gear["affixes"]:
			if a["stat"] == "atk":
				total += int(a["val"])
	if campfire_dish == "烤魚":
		total += 1
	return total

func get_total_crit() -> int:
	var total := 10
	for gear in [equipped_weapon, equipped_saddle]:
		if gear.is_empty():
			continue
		for a in gear["affixes"]:
			if a["stat"] == "crit":
				total += int(a["val"])
	return mini(100, total)

func get_stagger_bonus() -> int:
	var total := 1
	for gear in [equipped_weapon, equipped_saddle]:
		if gear.is_empty():
			continue
		for a in gear["affixes"]:
			if a["stat"] == "stagger_dmg":
				total += int(a["val"])
	return total

func get_speed_multiplier() -> float:
	var pct := 0
	for gear in [equipped_weapon, equipped_saddle]:
		if gear.is_empty():
			continue
		for a in gear["affixes"]:
			if a["stat"] == "spd":
				pct += int(a["val"])
	return 1.0 + float(pct) / 100.0

func rarity_color(rarity: String) -> Color:
	match rarity:
		"magic": return Color("#6cb8ff")
		"rare": return Color("#ffd659")
		"unique": return Color("#ff7b3b")
		_: return Color("#f2efe9")

func format_item_title(item: Dictionary) -> String:
	var tag := "[白]"
	match item["rarity"]:
		"magic": tag = "[藍]"
		"rare": tag = "[黃]"
		"unique": tag = "[傳奇]"
	return tag + " " + String(item["name"])

func format_item_details(item: Dictionary) -> String:
	var parts: Array[String] = [format_item_title(item)]
	if int(item["base_atk"]) > 0:
		parts.append("基礎攻+%d" % int(item["base_atk"]))
	var sp := String(item.get("special", ""))
	if sp == "spring_slam":
		parts.append("特效:下騎彈飛200%暴擊")
	elif sp == "slingshot":
		parts.append("職業:弱點狙擊手(支援騎射!)")
	for a in item["affixes"]:
		parts.append(String(a["name"]))
	return " · ".join(parts)

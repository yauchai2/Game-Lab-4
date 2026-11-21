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
var golem_befriended := false
var sandbar_chest_claimed := false
var lighthouse_viewed := false
var scribe_quest_accepted := false
var uniques_defeated: Array[String] = []
var emerald_boss_retired := false
var emerald_chest_claimed := false
var emerald_uniques_defeated: Array[String] = []
var clocktower_boss_retired := false
var clocktower_chest_claimed := false
var clocktower_uniques_defeated: Array[String] = []
var harbor_boss_retired := false
var harbor_chest_claimed := false
var harbor_uniques_defeated: Array[String] = []
var mounted := false
var player_hp := 5
var coins := 50

# PoE 2-style Classes & Ascendancies (4 Base Classes x 2 Ascendancies = 8 Builds)
var player_class := "swordsman" # "swordsman", "malletier", "ranger", "arcanist"
var player_ascendancy := "red_stamp" # "red_stamp", "iaido", "demolition", "skillet_chef", "staff_dancer", "angler", "spellbook", "bartender"

# PoE 2-style Support Seals (immediately reshape active combat skills!)
var unlocked_seals: Array[String] = []
var active_seal := "" # "split", "vortex", "paycheck"

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
var _bgm_player: AudioStreamPlayer
var _bgm_synth_player: AudioStreamPlayer
var _bgm_synth_gen: AudioStreamGenerator
var current_bgm_zone := ""
var bgm_muted := false
var bgm_volume := 0.75
var sfx_volume := 0.85
var prefer_playful_bgm := true
var screen_shake_enabled := true
var _bgm_using_file := false
var _bgm_note_timer := 0.0
var _bgm_step_idx := 0
var _bgm_phase := 0.0
var _bgm_bass_phase := 0.0
var _bgm_cur_freq := 261.63
var _bgm_bass_freq := 130.81
var _bgm_note_env := 0.0

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

	# Per-Zone Crossfading BGM Player (loads res://assets/audio/bgm/{zone}.mp3 or .ogg)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = -12.0
	add_child(_bgm_player)

	# Cozy procedural music-box fallback when external MP3/OGG tracks are not yet placed
	_bgm_synth_gen = AudioStreamGenerator.new()
	_bgm_synth_gen.mix_rate = 22050.0
	_bgm_synth_gen.buffer_length = 0.25
	_bgm_synth_player = AudioStreamPlayer.new()
	_bgm_synth_player.stream = _bgm_synth_gen
	_bgm_synth_player.volume_db = -18.0
	add_child(_bgm_synth_player)
	_bgm_synth_player.play()

func _apply_audio_volumes() -> void:
	var bgm_db := -80.0 if (bgm_muted or bgm_volume <= 0.01) else linear_to_db(bgm_volume * 0.35)
	var synth_db := -80.0 if (bgm_muted or bgm_volume <= 0.01) else linear_to_db(bgm_volume * 0.25)
	var sfx_db := -80.0 if sfx_volume <= 0.01 else linear_to_db(sfx_volume * 0.55)
	if _bgm_player:
		_bgm_player.volume_db = bgm_db
	if _bgm_synth_player:
		_bgm_synth_player.volume_db = synth_db
	if _sfx_player:
		_sfx_player.volume_db = sfx_db

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	_apply_audio_volumes()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_audio_volumes()

func set_playful_bgm(enabled: bool) -> void:
	prefer_playful_bgm = enabled
	var z := current_bgm_zone
	current_bgm_zone = ""
	if not z.is_empty():
		play_bgm(z)

func play_bgm(zone: String) -> void:
	if zone == current_bgm_zone:
		return
	current_bgm_zone = zone
	_bgm_step_idx = 0
	var stream: AudioStream = null
	if not prefer_playful_bgm:
		for ext in [".mp3", ".ogg", ".wav"]:
			var p := "res://assets/audio/bgm/%s%s" % [zone, ext]
			if ResourceLoader.exists(p):
				stream = ResourceLoader.load(p) as AudioStream
				if stream:
					break
	if stream:
		_bgm_using_file = true
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_bgm_player.stream = stream
		_bgm_player.play()
		_apply_audio_volumes()
	else:
		_bgm_using_file = false
		if _bgm_player.playing:
			_bgm_player.stop()
		_apply_audio_volumes()

func toggle_bgm_mute() -> bool:
	bgm_muted = not bgm_muted
	_apply_audio_volumes()
	return bgm_muted

func _process(delta: float) -> void:
	if bgm_muted or _bgm_using_file or current_bgm_zone.is_empty():
		return
	if not _bgm_synth_player or not _bgm_synth_player.playing:
		return
	var pb := _bgm_synth_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var notes: Array[float] = [392.00, 440.00, 523.25, 440.00, 392.00, 329.63, 293.66, 329.63, 392.00, 523.25, 587.33, 523.25]
	var bass: Array[float] = [196.00, 146.83, 130.81, 146.83]
	var step_dur := 0.34
	match current_bgm_zone:
		"town":
			notes = [523.25, 659.25, 587.33, 523.25, 440.00, 523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 440.00]
			bass = [261.63, 196.00, 220.00, 196.00]
			step_dur = 0.28
		"road":
			notes = [392.00, 440.00, 493.88, 587.33, 523.25, 493.88, 440.00, 392.00, 329.63, 392.00, 440.00, 587.33]
			bass = [196.00, 196.00, 164.81, 146.83]
			step_dur = 0.25
		"boss":
			notes = [329.63, 329.63, 392.00, 329.63, 440.00, 392.00, 349.23, 329.63, 293.66, 329.63, 392.00, 493.88]
			bass = [164.81, 196.00, 146.83, 164.81]
			step_dur = 0.19
	_bgm_note_timer -= delta
	if _bgm_note_timer <= 0.0:
		_bgm_note_timer = step_dur
		_bgm_cur_freq = notes[_bgm_step_idx % notes.size()]
		_bgm_bass_freq = bass[(_bgm_step_idx / 2) % bass.size()]
		_bgm_step_idx += 1
		_bgm_note_env = 1.0
	var avail := pb.get_frames_available()
	var sr := 22050.0
	for _i in range(mini(avail, 512)):
		_bgm_phase += TAU * _bgm_cur_freq / sr
		_bgm_bass_phase += TAU * _bgm_bass_freq / sr
		_bgm_note_env = maxf(0.0, _bgm_note_env - 2.6 / sr)
		var marimba := (sin(_bgm_phase) * 0.72 + sin(_bgm_phase * 3.0) * 0.16) * _bgm_note_env
		var pluck_bass := sin(_bgm_bass_phase) * maxf(0.18, _bgm_note_env * 0.65)
		var s := (marimba * 0.14 + pluck_bass * 0.08)
		pb.push_frame(Vector2(s, s))

func play_sfx(kind: String) -> void:
	if not _sfx_player or not _sfx_player.playing or sfx_volume <= 0.01:
		return
	var pb := _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var sr := 22050.0
	var avail := pb.get_frames_available()
	if avail <= 64:
		return
	var frames := int(sr * 0.14)
	var phase := 0.0
	var phase2 := 0.0
	match kind:
		"stamp":
			frames = mini(avail, int(sr * 0.28))
			for i in range(frames):
				var t := float(i) / float(frames)
				var thud_f := lerpf(155.0, 48.0, minf(1.0, t * 3.0))
				var boing_f := 320.0 + sin(t * 28.0) * 95.0 + t * 240.0
				phase += TAU * thud_f / sr
				phase2 += TAU * boing_f / sr
				var s := sin(phase) * maxf(0.0, 1.0 - t * 3.2) * 0.42 + sin(phase2) * (1.0 - t) * 0.22
				pb.push_frame(Vector2(s, s))
			return
		"slingshot":
			frames = mini(avail, int(sr * 0.16))
			for i in range(frames):
				var t := float(i) / float(frames)
				var f := 220.0 + t * 620.0 + sin(t * 40.0) * 65.0
				phase += TAU * f / sr
				var s := sin(phase) * (1.0 - t) * 0.28
				pb.push_frame(Vector2(s, s))
			return
		"coin":
			frames = mini(avail, int(sr * 0.16))
			for i in range(frames):
				var t := float(i) / float(frames)
				var f := 987.77 if t < 0.35 else 1318.51
				phase += TAU * f / sr
				var s := (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2) * (1.0 - t) * 0.24
				pb.push_frame(Vector2(s, s))
			return
		"craft", "checkpoint":
			frames = mini(avail, int(sr * 0.24))
			var arp := [523.25, 659.25, 783.99, 1046.50]
			for i in range(frames):
				var t := float(i) / float(frames)
				var f: float = arp[mini(3, int(t * 4.0))]
				phase += TAU * f / sr
				var s := sin(phase) * (1.0 - t * 0.85) * 0.24
				pb.push_frame(Vector2(s, s))
			return
		"heal":
			frames = mini(avail, int(sr * 0.22))
			for i in range(frames):
				var t := float(i) / float(frames)
				var f := 380.0 + sin(t * 22.0) * 110.0 + t * 340.0
				phase += TAU * f / sr
				var s := sin(phase) * (1.0 - t) * 0.26
				pb.push_frame(Vector2(s, s))
			return
		"wolf":
			frames = mini(avail, int(sr * 0.16))
			for i in range(frames):
				var t := float(i) / float(frames)
				var f := lerpf(290.0, 125.0, t)
				phase += TAU * f / sr
				var s := (sin(phase) * 0.7 + randf_range(-1.0, 1.0) * 0.3) * (1.0 - t) * 0.32
				pb.push_frame(Vector2(s, s))
			return
	var f0 := 440.0
	var f1 := 440.0
	var amp := 0.24
	var noise_mix := 0.0
	match kind:
		"slash":
			frames = int(sr * 0.09); f0 = 560.0; f1 = 210.0; noise_mix = 0.35
		"hit":
			frames = int(sr * 0.08); f0 = 230.0; f1 = 80.0; amp = 0.32; noise_mix = 0.25
		"wood":
			frames = int(sr * 0.14); f0 = 190.0; f1 = 68.0; amp = 0.36; noise_mix = 0.55
		"dodge":
			frames = int(sr * 0.10); f0 = 420.0; f1 = 170.0; amp = 0.22; noise_mix = 0.45
		"whirl":
			frames = int(sr * 0.18); f0 = 280.0; f1 = 760.0; amp = 0.30; noise_mix = 0.32
		_:
			return
	var count := mini(frames, avail)
	for i in range(count):
		var t := float(i) / float(count)
		phase += TAU * lerpf(f0, f1, t) / sr
		var env := (1.0 - t) * (1.0 - t)
		var sig := sin(phase) * (1.0 - noise_mix) + randf_range(-1.0, 1.0) * noise_mix
		pb.push_frame(Vector2(sig * env * amp, sig * env * amp))

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
	golem_befriended = false
	sandbar_chest_claimed = false
	lighthouse_viewed = false
	scribe_quest_accepted = false
	uniques_defeated.clear()
	emerald_boss_retired = false
	emerald_chest_claimed = false
	emerald_uniques_defeated.clear()
	clocktower_boss_retired = false
	clocktower_chest_claimed = false
	clocktower_uniques_defeated.clear()
	harbor_boss_retired = false
	harbor_chest_claimed = false
	harbor_uniques_defeated.clear()
	mounted = false
	player_hp = 5
	coins = 50
	player_class = "swordsman"
	player_ascendancy = "red_stamp"
	unlocked_seals.clear()
	active_seal = ""
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

func get_weapon_special() -> String:
	if equipped_weapon.is_empty():
		return ""
	return String(equipped_weapon.get("special", ""))

func is_slingshot() -> bool:
	return get_weapon_special() == "slingshot"

func get_class_title(cls := player_class) -> String:
	match cls:
		"swordsman": return "⚔ 停戰傳令官 (Swordsman)"
		"malletier": return "🔨 工坊重槌手 (Malletier)"
		"ranger": return "🏹 荒野巡遊者 (Ranger)"
		"arcanist": return "📖 繪本魔導士 (Arcanist)"
		_: return "⚔ 停戰傳令官 (Swordsman)"

func get_ascendancy_title(asc := player_ascendancy) -> String:
	match asc:
		"red_stamp": return "🔴 紅章審判官 (+2破防)"
		"iaido": return "⚡ 居合急行客 (閃避CD-25%且必暴)"
		"demolition": return "💥 爆破拆屋匠 (重擊範圍+35%)"
		"skillet_chef": return "🍳 鐵鍋大廚 (揮擊反彈敵方彈幕)"
		"staff_dancer": return "🥢 雙棍舞風者 (攻速與移速+12%)"
		"angler": return "🎣 懸崖神釣手 (彈幕+1且急射)"
		"spellbook": return "✨ 浮頁魔導書 (揮擊飛出魔導頁刃)"
		"bartender": return "🧪 戰地調酒師 (藥水震波+12秒疾風)"
		_: return "未昇華"

func set_class_and_ascendancy(cls: String, asc := "") -> String:
	player_class = cls
	if asc.is_empty():
		match cls:
			"swordsman": player_ascendancy = "red_stamp"
			"malletier": player_ascendancy = "demolition"
			"ranger": player_ascendancy = "staff_dancer"
			"arcanist": player_ascendancy = "spellbook"
			_: player_ascendancy = "red_stamp"
	else:
		player_ascendancy = asc
	play_sfx("craft")
	return "已切換流派：%s｜%s" % [get_class_title(), get_ascendancy_title()]

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
	if player_class == "swordsman":
		total += 1
	elif player_class == "malletier":
		total += 2
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
	match player_class:
		"swordsman": total += 10
		"ranger": total += 15
		"arcanist": total += 20
	if active_seal == "paycheck":
		total += 20
	for gear in [equipped_weapon, equipped_saddle]:
		if gear.is_empty():
			continue
		for a in gear["affixes"]:
			if a["stat"] == "crit":
				total += int(a["val"])
	return mini(100, total)

func unlock_seal(seal_id: String) -> bool:
	if unlocked_seals.has(seal_id):
		return false
	unlocked_seals.append(seal_id)
	if active_seal.is_empty():
		active_seal = seal_id
	play_sfx("craft")
	return true

func set_active_seal(seal_id: String) -> String:
	if not unlocked_seals.has(seal_id):
		return "尚未解鎖此輔助印章！"
	active_seal = seal_id
	play_sfx("craft")
	return "已鑲嵌輔助印章：" + get_seal_title(seal_id)

func record_unique_defeated(uid: String) -> bool:
	if uniques_defeated.has(uid):
		return false
	uniques_defeated.append(uid)
	return true

func record_emerald_unique_defeated(uid: String) -> bool:
	if emerald_uniques_defeated.has(uid):
		return false
	emerald_uniques_defeated.append(uid)
	return true

func record_clocktower_unique_defeated(uid: String) -> bool:
	if clocktower_uniques_defeated.has(uid):
		return false
	clocktower_uniques_defeated.append(uid)
	return true

func record_harbor_unique_defeated(uid: String) -> bool:
	if harbor_uniques_defeated.has(uid):
		return false
	harbor_uniques_defeated.append(uid)
	return true

func get_quest_tracker_text() -> String:
	var main_q := "主線《百年停戰令》：勸退雲海石橋・稻草人哨長"
	if not has_sword:
		main_q = "主線《百年停戰令》：於雲丘營地整備裝備"
	elif boss_retired and not emerald_boss_retired:
		main_q = "主線《翡翠天梯》：深入古林勸退翡翠樹王"
	elif emerald_boss_retired and not clocktower_boss_retired:
		main_q = "主線《百年鐘樓》：進軍鐘樓勸退重裝鐵鐘騎士"
	elif clocktower_boss_retired and not harbor_boss_retired:
		main_q = "主線《終章燈塔》：前往沉霧燈塔港勸退迷霧大提督"
	elif harbor_boss_retired:
		main_q = "主線《第一幕通關》：✦ 百年海霧散去！登上遠航號"
	var total_u := uniques_defeated.size() + emerald_uniques_defeated.size() + clocktower_uniques_defeated.size() + harbor_uniques_defeated.size()
	var side_q := "支線《荒野傳奇怪》：探索第一幕隱藏傳奇怪 (%d/8)" % total_u
	if total_u >= 8:
		side_q = "支線《荒野傳奇怪》：✦ 8/8 全數勸退！"
	return main_q + "\n" + side_q

func get_seal_title(seal_id: String) -> String:
	match seal_id:
		"split": return "【分裂印章】(彈弓3連射/揮劍發劍氣)"
		"vortex": return "【引力印章】(巨狼撞與重劈聚怪暈眩)"
		"paycheck": return "【雙薪印章】(+20%暴擊且暴擊噴幣)"
		_: return "未鑲嵌"

func get_stagger_bonus() -> int:
	var total := 1
	if player_class == "malletier":
		total += 2
	if player_ascendancy == "red_stamp":
		total += 2
	for gear in [equipped_weapon, equipped_saddle]:
		if gear.is_empty():
			continue
		for a in gear["affixes"]:
			if a["stat"] == "stagger_dmg":
				total += int(a["val"])
	return total

func get_speed_multiplier() -> float:
	var pct := 0
	if player_class == "ranger":
		pct += 18
	if player_ascendancy == "staff_dancer":
		pct += 12
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
	match sp:
		"spring_slam": parts.append("特效:下騎彈飛200%暴擊")
		"slingshot": parts.append("武器:橡木彈弓(支援騎射!)")
		"mallet": parts.append("武器:工藝木槌(1.35倍廣域震波)")
		"skillet": parts.append("武器:鑄鐵平底鍋(揮擊反彈敵方彈幕!)")
		"staff": parts.append("武器:雙頭長棍(極速連掃突刺)")
	for a in item["affixes"]:
		parts.append(String(a["name"]))
	return " · ".join(parts)

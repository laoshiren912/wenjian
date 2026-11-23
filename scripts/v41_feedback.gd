extends "res://scripts/combat_feedback.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
var guard_effects: Array[Dictionary] = []
var slash_impacts: Array[Dictionary] = []
var thunder_ghosts: Array[Dictionary] = []
var lifesteal_orbs: Array[Dictionary] = []
var heal_pulses: Array[Dictionary] = []
var broken_markers: Array[Dictionary] = []
var death_dissolves: Array[Dictionary] = []
var breakthrough_effects: Array[Dictionary] = []
var exit_beacons: Array[Dictionary] = []
var wave_summons: Array[Dictionary] = []
var card_arcs: Array[Dictionary] = []
var card_slashes: Array[Dictionary] = []
const SHAKE_MERGE_WINDOW := 0.18
const SHAKE_MAX_STRENGTH := 6.5
var shake_gate_left := 0.0
var shake_duration := 0.0
var shake_direction := Vector2.RIGHT
var guard_sound: AudioStreamWAV
var break_sound: AudioStreamWAV
var sword_sounds := {}
var sword_voices := {}
var cue_times := {}

func _ready() -> void:
	guard_sound = _metal_sound(false)
	break_sound = _metal_sound(true)
	sword_sounds = {
		"light_swing": _layered_sound(780.0, 190.0, 0.10, 0.68, 0.56, 0.18),
		"heavy_swing": _layered_sound(320.0, 95.0, 0.18, 0.54, 0.52, 0.46),
		"light_hit": _layered_sound(440.0, 118.0, 0.095, 1.16, 0.32, 0.72),
		"heavy_hit": _layered_sound(185.0, 62.0, 0.22, 0.50, 0.24, 0.98),
		"miss_light": _layered_sound(960.0, 260.0, 0.075, 0.62, 0.78, 0.08),
		"miss_heavy": _layered_sound(480.0, 140.0, 0.12, 0.50, 0.80, 0.22),
		"kill_confirm": _layered_sound(620.0, 130.0, 0.18, 1.38, 0.22, 0.68),
		"dash": _layered_sound(920.0, 175.0, 0.18, 1.85, 0.60, 0.36),
		"dash_hit": _layered_sound(310.0, 96.0, 0.11, 0.62, 0.36, 0.74),
		"thunder_dash": _layered_sound(1280.0, 210.0, 0.16, 0.65, 0.48, 0.38),
		"thunder_burst": _layered_sound(380.0, 68.0, 0.23, 0.48, 0.40, 0.92),
		"mark": _layered_sound(540.0, 180.0, 0.11, 0.55, 0.48, 0.26),
		"mark_hit": _layered_sound(240.0, 74.0, 0.18, 0.46, 0.44, 0.80),
		"throw_cast": _layered_sound(680.0, 190.0, 0.12, 1.65, 0.50, 0.28),
		"throw_spin": _layered_sound(1120.0, 260.0, 0.16, 0.74, 0.58, 0.22),
		"throw_hit": _layered_sound(430.0, 110.0, 0.105, 0.66, 0.38, 0.70),
		"throw_catch": _layered_sound(1480.0, 340.0, 0.075, 0.80, 0.28, 0.18),
		"sword_rain_cast": _layered_sound(1480.0, 136.0, 0.25, 1.62, 0.26, 0.42),
		"sword_rain_gather": _layered_sound(1040.0, 240.0, 0.22, 1.36, 0.22, 0.28),
		"sword_rain_ascend": _layered_sound(760.0, 165.0, 0.20, 1.72, 0.36, 0.34),
		"sword_rain_fire": _layered_sound(360.0, 66.0, 0.25, 0.50, 0.44, 0.88),
		"sword_rain_hit": _layered_sound(335.0, 51.0, 0.20, 0.49, 0.39, 0.99),
		"defeat": _layered_sound(187.0, 49.0, 0.48, 0.45, 0.18, 0.78),
		"breakthrough": _chime_sound([587.3, 880.0, 1174.7], 0.68, 0.36),
		"room_clear": _chime_sound([659.25, 987.77], 0.48, 0.18),
		"portal_activate": _chime_sound([783.99, 1174.66, 1567.98], 0.56, 0.32),
		"boss_clear": _chime_sound([523.25, 783.99, 1046.5, 1567.98], 0.85, 0.42),
		"wave_summon": _layered_sound(145.0, 56.0, 0.36, 0.62, 0.46, 0.72),
		"title_start": _unsheathe_sound(),
	}

func reset_sword_cues() -> void:
	sword_voices.clear()
	cue_times.clear()
	slash_impacts.clear()
	thunder_ghosts.clear()
	lifesteal_orbs.clear()
	heal_pulses.clear()
	broken_markers.clear()
	death_dissolves.clear()
	breakthrough_effects.clear()
	exit_beacons.clear()
	wave_summons.clear()
	card_arcs.clear()
	card_slashes.clear()
	shake_gate_left = 0.0
	shake_time = 0.0
	shake_strength = 0.0

func spawn_card_lightning(points: PackedVector2Array) -> void:
	card_arcs.append({"points": points, "left": 0.27})
	play_sword_cue("thunder_burst", points[0])

func spawn_card_slash(point: Vector2, direction: Vector2) -> void:
	card_slashes.append({"point": point, "direction": direction, "left": 0.24})

func trigger_camera_kick(direction: Vector2, strength: float) -> void:
	_submit_camera_shake(strength, 0.14, direction)

func request_camera_shake(strength: float, duration: float) -> void:
	_submit_camera_shake(strength, duration, Vector2(0.79, 0.61))

func _submit_camera_shake(strength: float, duration: float, direction: Vector2) -> void:
	if shake_gate_left > 0.00001:
		if shake_time > 0.0:
			shake_strength = minf(SHAKE_MAX_STRENGTH, maxf(shake_strength, strength))
		return
	shake_gate_left = SHAKE_MERGE_WINDOW
	shake_strength = minf(SHAKE_MAX_STRENGTH, strength)
	shake_duration = minf(duration, SHAKE_MERGE_WINDOW)
	shake_time = shake_duration
	shake_direction = Vector2.RIGHT if direction.is_zero_approx() else direction.normalized()

func _update_camera_shake(delta: float) -> void:
	var elapsed := delta / Engine.time_scale
	shake_gate_left = maxf(0.0, shake_gate_left - elapsed)
	shake_time = maxf(0.0, shake_time - elapsed)
	if shake_time == 0.0:
		shake_strength = 0.0
	if not is_instance_valid(camera):
		return
	camera.offset = Vector2.ZERO
	if shake_time > 0.0:
		var phase := (shake_duration - shake_time) * 65.0
		var envelope := pow(shake_time / shake_duration, 2.1)
		var motion := shake_direction * sin(phase) + shake_direction.orthogonal() * (sin(phase * 1.17) * 0.18)
		camera.offset = motion.limit_length() * shake_strength * envelope
	camera.force_update_scroll()

func _voice(channel: String) -> AudioStreamPlayer:
	if not is_instance_valid(sword_voices.get(channel)):
		var voice := AudioStreamPlayer.new()
		if AudioServer.get_bus_index("SFX") != -1:
			voice.bus = "SFX"
		add_child(voice)
		sword_voices[channel] = voice
		voice.tree_exiting.connect(func():
			voice.stop()
			voice.stream = null)
	return sword_voices[channel]

func _cue_ready(channel: String, gap_ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(cue_times.get(channel, -10000)) < gap_ms:
		return false
	cue_times[channel] = now
	return true

func play_sword_cue(kind: String, point: Vector2) -> void:
	var sound_key := "throw_hit" if kind == "throw_hit_twin" else kind
	var channel := "motion"
	if sound_key == "defeat":
		channel = "defeat"
	elif sound_key.begins_with("mark"):
		channel = "mark"
	elif sound_key == "sword_rain_hit":
		channel = "rain_hit"
	elif sound_key.begins_with("sword_rain"):
		channel = "rain"
	elif sound_key.ends_with("hit") or sound_key == "thunder_burst":
		channel = "contact"
	var gap := CONFIG.COMBO_SOUND_GAP_MS
	if channel == "mark":
		gap = 68
	elif channel == "rain_hit":
		gap = 78
	if sword_sounds.has(sound_key) and _cue_ready(channel, gap):
		var voice := _voice(channel)
		voice.stream = sword_sounds[sound_key]
		var db := -12.5
		if sound_key in ["heavy_hit", "thunder_burst", "sword_rain_fire", "sword_rain_hit", "sword_rain_cast"]:
			db = -8.0
		elif sound_key in ["sword_rain_gather", "sword_rain_ascend"]:
			db = -10.5
		elif sound_key == "light_swing":
			db = -17.0
		voice.volume_db = db
		voice.pitch_scale = randf_range(0.92, 1.08)
		voice.play()
	if kind in ["throw_hit", "throw_hit_twin"]:
		_spawn_slash_impact("spin_twin" if kind == "throw_hit_twin" else "spin_hit", point, Vector2.RIGHT, 0, 2 if kind == "throw_hit_twin" else 1)
		trigger_camera_kick(Vector2.RIGHT, 2.6 if kind == "throw_hit_twin" else 2.1)
	elif kind == "sword_rain_hit":
		_spawn_slash_impact("rain_hit", point, Vector2.DOWN, 2, 2)
		trigger_camera_kick(Vector2.DOWN, 6.2)
	if sound_key in ["dash_hit", "mark_hit", "sword_rain_fire"] and _cue_ready("dash_shake", 140):
		trigger_camera_kick(Vector2.DOWN if sound_key == "sword_rain_fire" else Vector2.RIGHT, 5.2 if sound_key == "dash_hit" else 6.4)

func spawn_thunder_afterimage(point: Vector2, direction: Vector2, landing: bool) -> void:
	if thunder_ghosts.size() >= 10:
		thunder_ghosts.remove_at(0)
	thunder_ghosts.append({
		"point": point,
		"dir": direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT,
		"landing": landing,
		"age": 0.0,
		"duration": CONFIG.THUNDER_GHOST_DELAY,
	})
	if _cue_ready("thunder", 85):
		var voice := _voice("thunder")
		voice.stream = sword_sounds["thunder_dash"]
		voice.volume_db = -13.0 if landing else -14.5
		voice.play()

func spawn_thunder_burst(point: Vector2, direction: Vector2) -> void:
	_spawn_slash_impact("thunder_burst", point, direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT, 2, 2)
	play_sword_cue("thunder_burst", point)

func spawn_lifesteal_orbs(from_point: Vector2, target_player: Node2D, count: int = 5) -> void:
	for i in range(count):
		var a := TAU * float(i) / float(maxi(1, count)) + 0.35
		lifesteal_orbs.append({
			"start": from_point,
			"ctrl": from_point + Vector2.from_angle(a) * (34.0 + float(i % 2) * 18.0),
			"target": target_player,
			"age": 0.0,
			"duration": 0.28 + float(i) * 0.032,
			"warm": i % 2 == 1,
			"spirit": false,
		})

func spawn_clear_spirit_orbs(from_point: Vector2, target_player: Node2D, count: int = 6) -> void:
	# 清场缓冲期：青金色灵气光点从最后倒地位置弧线飞向主角吸收
	if not is_instance_valid(target_player):
		return
	for i in range(count):
		var a := TAU * float(i) / float(maxi(1, count)) + 0.5
		var spread := 52.0 + float(i % 2) * 28.0
		lifesteal_orbs.append({
			"start": from_point,
			"ctrl": from_point + Vector2(cos(a) * spread, sin(a) * spread * 0.7 - 30.0),
			"target": target_player,
			"age": -0.10 - float(i) * 0.06,
			"duration": 0.62 + float(i % 3) * 0.10,
			"warm": i % 2 == 1,
			"spirit": true,
		})

func register_guard_break_target(target: Node2D, duration: float) -> void:
	if not is_instance_valid(target):
		return
	for m in broken_markers:
		if m.target == target:
			m.left = maxf(float(m.left), duration)
			m.duration = maxf(float(m.duration), duration)
			return
	broken_markers.append({"target": target, "left": duration, "duration": duration, "age": 0.0})

func spawn_death_dissolve(point: Vector2, is_boss: bool = false) -> void:
	if death_dissolves.size() >= 14:
		death_dissolves.remove_at(0)
	death_dissolves.append({
		"point": point,
		"boss": is_boss,
		"age": 0.0,
		"duration": 0.52 if is_boss else 0.34,
	})

func spawn_breakthrough(target_player: Node2D, rank: int) -> void:
	if not is_instance_valid(target_player):
		return
	breakthrough_effects.append({
		"target": target_player,
		"rank": clampi(rank, 1, 2),
		"age": 0.0,
		"duration": 1.12,
	})
	if sword_sounds.has("breakthrough"):
		var voice := _voice("ceremony")
		voice.stream = sword_sounds["breakthrough"]
		voice.volume_db = -7.5
		voice.play()
	request_camera_shake(2.8 if rank == 2 else 2.0, 0.14)

func spawn_exit_beacon(point: Vector2) -> void:
	exit_beacons.append({
		"point": point,
		"age": 0.0,
		"duration": 0.90,
	})

func play_clear_sound(is_boss: bool = false) -> void:
	var key := "boss_clear" if is_boss else "room_clear"
	if sword_sounds.has(key):
		var voice := _voice("clear_chime")
		voice.stream = sword_sounds[key]
		voice.volume_db = -7.0 if is_boss else -9.0
		voice.pitch_scale = 1.0
		voice.play()

func play_portal_activate() -> void:
	if sword_sounds.has("portal_activate"):
		var voice := _voice("portal_chime")
		voice.stream = sword_sounds["portal_activate"]
		voice.volume_db = -8.0
		voice.pitch_scale = 1.0
		voice.play()

func play_title_start() -> void:
	if sword_sounds.has("title_start"):
		var voice := _voice("title_start")
		voice.stream = sword_sounds["title_start"]
		voice.volume_db = -6.5
		voice.pitch_scale = 1.0
		voice.play()

func spawn_wave_summon(points: Array[Vector2], duration: float = 0.55) -> void:
	for pt in points:
		wave_summons.append({
			"point": pt,
			"age": 0.0,
			"duration": maxf(0.2, duration),
		})
	if sword_sounds.has("wave_summon"):
		var voice := _voice("wave_summon")
		voice.stream = sword_sounds["wave_summon"]
		voice.volume_db = -9.5
		voice.pitch_scale = randf_range(0.95, 1.05)
		voice.play()

func handle_combo_event(kind: String, slot: int, point: Vector2, direction: Vector2, rank: int) -> void:
	var dir := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	match kind:
		"miss":
			if _cue_ready("miss_wind", 75):
				var voice := _voice("miss_wind")
				voice.stream = sword_sounds["miss_heavy" if slot == 2 else "miss_light"]
				voice.volume_db = -21.0 if slot == 2 else -24.0
				voice.pitch_scale = randf_range(0.92, 1.08)
				voice.play()
		"hit":
			_spawn_slash_impact("hit", point, dir, slot, rank)
		"blocked":
			_spawn_slash_impact("blocked", point, -dir, slot, rank)
		"guard_break":
			_spawn_slash_impact("guard_break", point, dir, slot, rank)
		"kill":
			_spawn_slash_impact("kill", point, dir, slot, rank)
			if _cue_ready("kill", 95):
				var kill_voice := _voice("kill")
				kill_voice.stream = sword_sounds["kill_confirm"]
				kill_voice.volume_db = -13.5
				kill_voice.pitch_scale = randf_range(0.92, 1.08)
				kill_voice.play()

func _spawn_slash_impact(kind: String, point: Vector2, direction: Vector2, slot: int, rank: int) -> void:
	# Prevent particle spam when hitting several enemies simultaneously.
	if slash_impacts.size() >= 18:
		slash_impacts.remove_at(0)
	var duration := 0.13
	if kind == "blocked":
		duration = 0.16
	elif kind == "guard_break" or kind == "thunder_burst":
		duration = 0.22
	elif kind == "kill":
		duration = 0.19
	elif kind == "spin_twin":
		duration = 0.17
	slash_impacts.append({
		"kind": kind,
		"point": point,
		"dir": direction,
		"slot": slot,
		"rank": clampi(rank, 0, 2),
		"age": 0.0,
		"duration": duration,
	})

func show_damage(point: Vector2, amount: float, is_player: bool, camera_shake: bool = true, blocked: bool = false, crit: bool = false) -> void:
	super.show_damage(point, amount, is_player, camera_shake, blocked, crit)
	if blocked and amount > 0.0:
		_guard_effect(point, false)

func show_guard_break(point: Vector2) -> void:
	_spawn_crit_sparks(point)
	_guard_effect(point, true)

func _guard_effect(point: Vector2, broken: bool) -> void:
	guard_effects.append({"point": point, "age": 0.0, "broken": broken})
	if not _cue_ready("guard", 82) or not _cue_ready("contact", CONFIG.COMBO_SOUND_GAP_MS):
		return
	var sound := _voice("guard")
	sound.stream = break_sound if broken else guard_sound
	sound.volume_db = CONFIG.GUARD_SOUND_DB
	sound.pitch_scale = randf_range(0.92, 1.08)
	sound.play()

func _layered_sound(pitch: float, body_pitch: float, duration: float, glide: float, noise_mix: float, punch: float) -> AudioStreamWAV:
	# 多层复合像素战斗音效：短促低频亚音重击层 + 中低频拳感 + 中高频金铁/剑鸣泛音层 + 滤波风压噪声
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch * 3.0 + body_pitch)
	var phase_hi := 0.0
	var phase_lo := 0.0
	var phase_sub := 0.0
	var filtered := 0.0
	for i in range(samples):
		var progress := float(i) / float(maxi(1, samples))
		var env_hi := minf(progress * 75.0, 1.0) * pow(1.0 - progress, 2.3)
		var env_lo := minf(progress * 120.0, 1.0) * pow(1.0 - progress, 3.6)
		var env_sub := minf(progress * 160.0, 1.0) * pow(1.0 - progress, 5.2)
		phase_hi += TAU * pitch * lerpf(1.0, glide, progress) / stream.mix_rate
		phase_lo += TAU * body_pitch * lerpf(1.0, 0.42, progress) / stream.mix_rate
		phase_sub += TAU * maxf(48.0, body_pitch * 0.56) * lerpf(1.0, 0.36, progress) / stream.mix_rate
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.30)
		var tone_hi := sin(phase_hi) * 0.56 + sin(phase_hi * 2.41) * 0.25 + sin(phase_hi * 3.73) * 0.11
		var body_lo := sin(phase_lo) * punch * env_lo
		var sub_thump := sin(phase_sub) * punch * 0.62 * env_sub
		var raw := (lerpf(tone_hi, filtered, noise_mix) * env_hi + body_lo + sub_thump) * 0.78
		var sample := tanh(raw * 1.15)
		bytes.encode_s16(i * 2, int(clampf(sample, -0.95, 0.95) * 32767.0))
	stream.data = bytes
	return stream

func _metal_sound(broken: bool) -> AudioStreamWAV:
	# 复合清脆金铁交击 / 浑厚碎盾破防音
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := CONFIG.BREAK_SPARK_TIME if broken else CONFIG.GUARD_SPARK_TIME
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 901 if broken else 402
	var noise_lp := 0.0
	for i in range(samples):
		var t := float(i) / stream.mix_rate
		var env := minf(t * 140.0, 1.0) * exp(-t * (16.0 if broken else 28.0))
		var pitch := (1020.0 - t * 1400.0) if broken else 1880.0
		var clang := sin(TAU * pitch * t) * 0.52 + sin(TAU * pitch * 2.71 * t) * 0.30 + sin(TAU * pitch * 4.13 * t) * 0.14
		var sub := sin(TAU * lerpf(135.0, 52.0, minf(t * 5.0, 1.0)) * t) * (0.65 if broken else 0.18) * exp(-t * 12.0)
		noise_lp = lerpf(noise_lp, rng.randf_range(-1.0, 1.0), 0.28)
		var sample := (clang * env + sub + noise_lp * (0.28 if broken else 0.10) * env) * 0.58
		bytes.encode_s16(i * 2, int(clampf(sample, -0.95, 0.95) * 32767.0))
	stream.data = bytes
	return stream

func _chime_sound(notes: Array, duration: float, sword_ring: float) -> AudioStreamWAV:
	# 清越钟磬与仙剑共鸣音（五声音阶逐音入耳 + 细腻金属剑鸣余韵）
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var step := 0.075
	for i in range(samples):
		var t := float(i) / float(stream.mix_rate)
		var mix := 0.0
		for n_idx in range(notes.size()):
			var nt := t - float(n_idx) * step
			if nt < 0.0:
				continue
			var freq: float = float(notes[n_idx])
			var env := minf(nt * 95.0, 1.0) * exp(-nt * 5.2)
			var bell := sin(TAU * freq * nt) * 0.55 + sin(TAU * freq * 2.0 * nt) * 0.24 + sin(TAU * freq * 3.01 * nt) * 0.12
			mix += bell * env * (0.62 / sqrt(float(maxi(1, notes.size()))))
		# 仙剑高频泛音共鸣与极轻低频基座
		var ring_env := minf(t * 45.0, 1.0) * exp(-t * 4.4)
		var ring_f: float = float(notes[notes.size() - 1]) * 1.5
		var shimmer := (sin(TAU * ring_f * t) * 0.6 + sin(TAU * ring_f * 1.006 * t) * 0.4) * sword_ring * ring_env
		var bass := sin(TAU * float(notes[0]) * 0.25 * t) * 0.22 * minf(t * 60.0, 1.0) * exp(-t * 6.5)
		var sample := clampf((mix + shimmer + bass) * 0.78, -0.95, 0.95)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = bytes
	return stream

func _unsheathe_sound() -> AudioStreamWAV:
	# 清脆出鞘擦刃 + 仙侠清越剑鸣（点击「踏入仙途」专用）
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.72
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261
	var hp_prev := 0.0
	var phase_slide := 0.0
	for i in range(samples):
		var t := float(i) / float(stream.mix_rate)
		# 1. 前 0.16s 清脆出鞘金属擦音
		var slide := 0.0
		if t < 0.18:
			var sp := t / 0.18
			var s_env := sin(sp * PI) * (1.0 - sp * 0.25)
			var raw_n := rng.randf_range(-1.0, 1.0)
			var hp := raw_n - hp_prev * 0.86
			hp_prev = raw_n
			var slide_f := lerpf(1180.0, 3420.0, sp * sp)
			phase_slide += TAU * slide_f / float(stream.mix_rate)
			slide = (sin(phase_slide) * 0.42 + hp * 0.46) * s_env * 0.62
		# 2. 0.05s 起清越剑鸣泛音（D5 + A5 + D6 交叠共鸣）
		var ring := 0.0
		if t >= 0.04:
			var rt := t - 0.04
			var r_env := minf(rt * 110.0, 1.0) * exp(-rt * 4.6)
			var f1 := 587.33
			var f2 := 880.0
			var f3 := 1174.66
			var shimmer := sin(TAU * f1 * rt) * 0.36 + sin(TAU * f2 * rt) * 0.30 + sin(TAU * f3 * rt) * 0.22 + sin(TAU * f3 * 2.012 * rt) * 0.14 * exp(-rt * 7.0)
			var sub := sin(TAU * 146.83 * rt) * 0.18 * exp(-rt * 9.5)
			ring = (shimmer + sub) * r_env * 0.85
		var sample := clampf(tanh((slide + ring) * 1.15), -0.95, 0.95)
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = bytes
	return stream

func _process(delta: float) -> void:
	super._process(delta)
	for effects in [card_arcs, card_slashes]:
		for i in range(effects.size() - 1, -1, -1):
			effects[i].left -= delta
			if effects[i].left <= 0.0:
				effects.remove_at(i)
	for i in range(guard_effects.size() - 1, -1, -1):
		guard_effects[i].age += delta
		var duration := CONFIG.BREAK_SPARK_TIME if guard_effects[i].broken else CONFIG.GUARD_SPARK_TIME
		if guard_effects[i].age >= duration:
			guard_effects.remove_at(i)
	for i in range(slash_impacts.size() - 1, -1, -1):
		slash_impacts[i].age += delta
		if float(slash_impacts[i].age) >= float(slash_impacts[i].duration):
			slash_impacts.remove_at(i)
	for i in range(thunder_ghosts.size() - 1, -1, -1):
		thunder_ghosts[i].age += delta
		if float(thunder_ghosts[i].age) >= float(thunder_ghosts[i].duration):
			thunder_ghosts.remove_at(i)
	for i in range(lifesteal_orbs.size() - 1, -1, -1):
		var orb := lifesteal_orbs[i]
		orb.age += delta
		if float(orb.age) >= float(orb.duration):
			if is_instance_valid(orb.target):
				heal_pulses.append({"target": orb.target, "age": 0.0, "duration": 0.24})
			lifesteal_orbs.remove_at(i)
	for i in range(heal_pulses.size() - 1, -1, -1):
		heal_pulses[i].age += delta
		if float(heal_pulses[i].age) >= float(heal_pulses[i].duration) or not is_instance_valid(heal_pulses[i].target):
			heal_pulses.remove_at(i)
	for i in range(broken_markers.size() - 1, -1, -1):
		var m := broken_markers[i]
		m.age += delta
		m.left -= delta
		if float(m.left) <= 0.0 or not is_instance_valid(m.target) or m.target.dead:
			broken_markers.remove_at(i)
	for i in range(death_dissolves.size() - 1, -1, -1):
		death_dissolves[i].age += delta
		if float(death_dissolves[i].age) >= float(death_dissolves[i].duration):
			death_dissolves.remove_at(i)
	for i in range(breakthrough_effects.size() - 1, -1, -1):
		breakthrough_effects[i].age += delta
		if float(breakthrough_effects[i].age) >= float(breakthrough_effects[i].duration) or not is_instance_valid(breakthrough_effects[i].target):
			breakthrough_effects.remove_at(i)
	for i in range(exit_beacons.size() - 1, -1, -1):
		exit_beacons[i].age += delta
		if float(exit_beacons[i].age) >= float(exit_beacons[i].duration):
			exit_beacons.remove_at(i)
	for i in range(wave_summons.size() - 1, -1, -1):
		wave_summons[i].age += delta
		if float(wave_summons[i].age) >= float(wave_summons[i].duration):
			wave_summons.remove_at(i)

func _rank_accent(rank: int) -> Color:
	if rank == 1:
		return Color("66f2ea")
	if rank == 2:
		return Color("52d2ff")
	return Color("eaf4ff")

func _draw() -> void:
	super._draw()
	for arc in card_arcs:
		var points: PackedVector2Array = arc.points
		var alpha := smoothstep(0.0, 0.27, float(arc.left))
		for i in range(1, points.size()):
			var start := to_local(points[i - 1])
			var end := to_local(points[i])
			var side := start.direction_to(end).orthogonal()
			var bolt := PackedVector2Array([start])
			for j in range(1, 6):
				bolt.append(start.lerp(end, j / 6.0) + side * (8.0 if j % 2 == 0 else -8.0))
			bolt.append(end)
			draw_polyline(bolt, Color(0.22, 0.92, 0.86, alpha * 0.65), 7.0, true)
			draw_polyline(bolt, Color(1.0, 0.87, 0.47, alpha), 2.3, true)
	for slash in card_slashes:
		var alpha := float(slash.left) / 0.24
		var point := to_local(slash.point)
		draw_set_transform(point, slash.direction.angle(), Vector2(1.0, 0.55))
		var radius := lerpf(96.0, 44.0, alpha)
		draw_arc(Vector2.ZERO, radius, -1.52, 1.52, 26, Color(0.31, 0.86, 0.80, alpha * 0.80), 10.0, true)
		draw_arc(Vector2.ZERO, radius, -1.48, 1.48, 26, Color(1.0, 0.90, 0.56, alpha), 3.0, true)
		draw_set_transform(Vector2.ZERO)
	for effect in guard_effects:
		var broken: bool = effect.broken
		var duration := CONFIG.BREAK_SPARK_TIME if broken else CONFIG.GUARD_SPARK_TIME
		var t: float = effect.age / duration
		var point := to_local(effect.point)
		var color := Color("ffce77") if broken else Color("8fe5ff")
		color.a = 1.0 - t
		for i in range(8):
			var angle := TAU * i / 8.0
			var direction := Vector2.from_angle(angle)
			var center := point + direction * (23.0 + t * (34.0 if broken else 12.0))
			if broken:
				# Separated blue shield shards with golden crack edges.
				var tangent := direction.orthogonal()
				draw_colored_polygon(PackedVector2Array([center - tangent * 5.0, center + tangent * 5.0, center + direction * 9.0]), Color(0.45, 0.8, 1.0, 1.0 - t))
				draw_line(center, center + direction * 11.0, color, 2.0, true)
			else:
				draw_line(center - direction * 5.0, center + direction * 8.0, color, 3.0, true)

	for impact in slash_impacts:
		var t := clampf(float(impact.age) / maxf(0.01, float(impact.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var point := to_local(impact.point).round()
		var dir: Vector2 = impact.dir
		var slot: int = impact.slot
		var rank: int = impact.rank
		var accent := _rank_accent(rank)
		var kind: String = impact.kind
		if kind == "hit" or kind == "rain_hit":
			# 高对比度沿攻击切线方向爆裂像素火花（重劈/万剑额外叠加扩散冲击波环）
			var heavy_impact := (slot == 2) or (kind == "rain_hit")
			var tangent := dir.orthogonal()
			var slash_axis := dir.rotated(-0.42 if slot == 0 else (0.42 if slot == 1 else 0.0))
			var half_len := lerpf(13.0, 24.0 if heavy_impact else 17.0, t) * inv
			var core_col := Color(1.0, 1.0, 0.95, inv * 0.98)
			var hot_gold := Color(1.0, 0.86, 0.36, inv * 0.94)
			var edge_col := Color(accent, inv * 0.90)
			if half_len > 1.5:
				draw_line((point - slash_axis * half_len).round(), (point + slash_axis * half_len).round(), edge_col, 3.6 if heavy_impact else 2.6, false)
				draw_line((point - slash_axis * half_len * 0.72).round(), (point + slash_axis * half_len * 0.72).round(), core_col, 2.0, false)
			if heavy_impact:
				var ring_r := lerpf(7.0, 34.0, pow(t, 0.52))
				draw_arc(point, ring_r, 0.0, TAU, 24, Color(1.0, 0.92, 0.56, inv * 0.88), 3.0 * inv + 1.0, false)
				draw_arc(point, ring_r * 0.68, 0.0, TAU, 18, Color(accent, inv * 0.78), 2.0, false)
			var spark_n := 10 if heavy_impact else 7
			for i in range(spark_n):
				var frac := (float(i) / float(maxi(1, spark_n - 1))) * 2.0 - 1.0
				var sdir := (dir * 0.78 + tangent * frac * 0.95).normalized()
				var dist := lerpf(4.0, (32.0 if heavy_impact else 24.0) + float(i % 3) * 6.0, pow(t, 0.62))
				var p0 := (point + sdir * dist).round()
				var tail := (7.0 if heavy_impact else 5.0) * inv + 2.0
				var p1 := (p0 + sdir * tail).round()
				var scol := core_col if i % 3 == 0 else (hot_gold if i % 2 == 0 else edge_col)
				draw_line(p0, p1, scol, 2.5 if heavy_impact else 2.0, false)
				draw_rect(Rect2(p0 - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), core_col)
		elif kind == "blocked":
			# 金属火星反向弹开 + 短促反弹弧
			var spark_a := Color(1.0, 0.86, 0.45, inv * 0.95)
			var spark_b := Color(0.88, 0.97, 1.0, inv * 0.92)
			var b_angles := [-0.75, -0.38, -0.10, 0.14, 0.42, 0.78]
			for i in range(b_angles.size()):
				var sdir := dir.rotated(b_angles[i])
				var dist := lerpf(6.0, 26.0 + float(i % 3) * 5.0, pow(t, 0.65))
				var p0 := (point + sdir * dist).round()
				var p1 := (p0 + sdir * (5.5 * inv + 2.0)).round()
				draw_line(p0, p1, spark_a if i % 2 == 0 else spark_b, 2.0, false)
				draw_rect(Rect2(p0 - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.98, 0.88, inv))
		elif kind == "guard_break":
			# 破防：锐利金青双色十字裂锋 + 爆发短芒
			var gold := Color(1.0, 0.84, 0.44, inv * 0.95)
			var cyan := Color(accent, inv * 0.9)
			var cross_len := lerpf(10.0, 30.0, pow(t, 0.6))
			for a in [0.0, PI * 0.5, PI * 0.25, -PI * 0.25]:
				var v := Vector2.from_angle(a)
				var len_scale := 1.0 if a <= PI * 0.5 else 0.68
				draw_line((point + v * 5.0).round(), (point + v * cross_len * len_scale).round(), gold if len_scale > 0.9 else cyan, 2.5 if len_scale > 0.9 else 2.0, false)
				draw_line((point - v * 5.0).round(), (point - v * cross_len * len_scale).round(), gold if len_scale > 0.9 else cyan, 2.5 if len_scale > 0.9 else 2.0, false)
		elif kind == "kill":
			# 击杀：干净交叉斩断光痕 + 6枚收束消散像素微粒
			var k_core := Color(1.0, 1.0, 1.0, inv * 0.95)
			var k_col := Color(accent.lightened(0.18), inv * 0.9)
			var slash_len := lerpf(16.0, 28.0, pow(t, 0.55)) * inv
			if slash_len > 2.0:
				var a1 := dir.rotated(-0.42)
				var a2 := dir.rotated(0.55)
				draw_line((point - a1 * slash_len).round(), (point + a1 * slash_len).round(), k_col, 3.0, false)
				draw_line((point - a1 * slash_len * 0.7).round(), (point + a1 * slash_len * 0.7).round(), k_core, 1.5, false)
				draw_line((point - a2 * slash_len * 0.75).round(), (point + a2 * slash_len * 0.75).round(), k_col, 2.0, false)
			for i in range(6):
				var v := dir.rotated((float(i) - 2.5) * 0.45)
				var pos := (point + v * lerpf(6.0, 28.0, pow(t, 0.7))).round()
				draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(3, 3)), k_core if i % 2 == 0 else k_col)
		elif kind == "thunder_burst":
			# 【雷霆残影】翻倍一剑命中时的青金雷霆气浪与折线电弧火花
			var r_ring := lerpf(10.0, 44.0, pow(t, 0.62))
			draw_arc(point, r_ring, 0.0, TAU, 24, Color(0.55, 0.96, 1.0, inv * 0.85), 2.5, false)
			draw_arc(point, r_ring * 0.72, 0.0, TAU, 20, Color(1.0, 0.90, 0.46, inv * 0.82), 2.0, false)
			for i in range(6):
				var a := TAU * float(i) / 6.0 + 0.25
				var v := Vector2.from_angle(a)
				var mid := (point + v * (r_ring * 0.52) + v.orthogonal() * (6.0 if i % 2 == 0 else -6.0)).round()
				var tip := (point + v * (r_ring * 1.08)).round()
				draw_line(point, mid, Color(1.0, 0.95, 0.66, inv * 0.95), 2.0, false)
				draw_line(mid, tip, Color(0.58, 0.98, 1.0, inv * 0.90), 1.5, false)
		elif kind in ["spin_hit", "spin_twin"]:
			# 右键御剑旋斩 / 【双星旋刃】命中高密度青金火星
			var twin := kind == "spin_twin"
			var spark_count := 8 if twin else 5
			for i in range(spark_count):
				var a := TAU * float(i) / float(spark_count) + t * 2.2
				var v := Vector2.from_angle(a)
				var d0 := lerpf(4.0, 18.0 if twin else 13.0, pow(t, 0.65))
				var p0 := (point + v * d0).round()
				var p1 := (p0 + v * ((7.0 if twin else 4.5) * inv + 2.0)).round()
				var scol := Color(1.0, 0.90, 0.50, inv * 0.94) if (twin and i % 2 == 0) else Color(0.58, 0.96, 1.0, inv * 0.92)
				draw_line(p0, p1, scol, 2.0, false)
				if twin:
					draw_rect(Rect2(p0 - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 1.0, 0.92, inv))

	# 【雷霆残影】穿阵起手与落地青金电光残影
	for tg in thunder_ghosts:
		var t := clampf(float(tg.age) / maxf(0.01, float(tg.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(tg.point).round()
		var col_c := Color(0.52, 0.96, 1.0, inv * 0.80)
		var col_g := Color(1.0, 0.88, 0.45, inv * 0.85)
		draw_set_transform(pt + Vector2(0, 12), 0.0, Vector2(1.0, 0.36))
		draw_arc(Vector2.ZERO, lerpf(12.0, 32.0 if tg.landing else 24.0, t), 0.0, TAU, 24, col_c, 2.0, false)
		draw_set_transform(Vector2.ZERO)
		# 剑客雷影轮廓线 + 2 道折线电弧
		draw_line((pt + Vector2(0, 10)).round(), (pt + Vector2(0, -26)).round(), col_c, 3.0 * inv + 1.0, false)
		draw_line((pt + Vector2(-8, -16)).round(), (pt + Vector2(4, -6)).round(), col_g, 2.0, false)
		draw_line((pt + Vector2(4, -6)).round(), (pt + Vector2(-5, 6)).round(), col_c, 2.0, false)
		draw_line((pt + Vector2(9, -20)).round(), (pt + Vector2(2, -4)).round(), col_g, 1.5, false)

	# 【破阵嗜血】与【清场灵气吸收】光点与主角回气微光脉冲
	for orb in lifesteal_orbs:
		if not is_instance_valid(orb.target) or float(orb.age) < 0.0:
			continue
		var t := clampf(float(orb.age) / maxf(0.01, float(orb.duration)), 0.0, 1.0)
		var s: Vector2 = orb.start
		var c: Vector2 = orb.ctrl
		var e: Vector2 = orb.target.global_position
		var pos := s.lerp(c, t).lerp(c.lerp(e, t), t)
		var prev_t := maxf(0.0, t - 0.16)
		var prev_pos := s.lerp(c, prev_t).lerp(c.lerp(e, prev_t), prev_t)
		var p_local := to_local(pos).round()
		var prev_local := to_local(prev_pos).round()
		var is_spirit: bool = bool(orb.get("spirit", false))
		var ocol := (Color("ffe078") if orb.warm else Color("6ef5e0")) if is_spirit else (Color("ff7a6b") if orb.warm else Color("6df5de"))
		draw_line(prev_local, p_local, Color(ocol, 0.78 if is_spirit else 0.65), 3.2 if is_spirit else 2.5, false)
		var core_sz := 5.0 if is_spirit else 4.0
		draw_rect(Rect2(p_local - Vector2(core_sz * 0.5, core_sz * 0.5), Vector2(core_sz, core_sz)), Color(1.0, 0.99, 0.92, 0.96))
		draw_rect(Rect2(p_local - Vector2(core_sz * 0.85, core_sz * 0.85), Vector2(core_sz * 1.7, core_sz * 1.7)), Color(ocol, 0.46))

	for hp in heal_pulses:
		if not is_instance_valid(hp.target):
			continue
		var t := clampf(float(hp.age) / maxf(0.01, float(hp.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(hp.target.global_position).round()
		draw_set_transform(pt + Vector2(0, lerpf(14.0, -14.0, t)), 0.0, Vector2(1.0, 0.36))
		draw_arc(Vector2.ZERO, lerpf(14.0, 26.0, t), 0.0, TAU, 24, Color(0.45, 0.98, 0.82, inv * 0.78), 2.5, false)
		draw_set_transform(Vector2.ZERO)

	# 【双星旋刃】被破防敌人醒目破防弱点状态提示
	for m in broken_markers:
		if not is_instance_valid(m.target) or m.target.dead:
			continue
		var pt := to_local(m.target.global_position).round()
		var pulse := 0.65 + 0.35 * sin(float(m.age) * 14.0)
		var ratio := clampf(float(m.left) / maxf(0.01, float(m.duration)), 0.0, 1.0)
		draw_set_transform(pt + Vector2(0, 14), 0.0, Vector2(1.0, 0.38))
		draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color(1.0, 0.82, 0.34, 0.78), 2.5, false)
		draw_set_transform(Vector2.ZERO)
		# 头顶金色碎盾裂纹菱印
		var head := pt + Vector2(0, -48)
		var g := Color(1.0, 0.84, 0.38, 0.90 * pulse)
		draw_line(head + Vector2(-6, -3), head + Vector2(-1, 3), g, 2.0, false)
		draw_line(head + Vector2(6, -3), head + Vector2(1, 3), g, 2.0, false)
		draw_line(head + Vector2(0, -7), head + Vector2(0, 5), Color(1.0, 0.98, 0.82, 0.92 * pulse), 1.5, false)

	# 1–7 关统一像素死亡消散（散尘环 + 上浮像素灵屑，浅色地面亦清晰可见）
	for dd in death_dissolves:
		var t := clampf(float(dd.age) / maxf(0.01, float(dd.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(dd.point).round()
		var scale_m := 1.65 if dd.boss else 1.0
		var ring_col := Color(0.98, 0.76, 0.34, inv * 0.68) if dd.boss else Color(0.28, 0.34, 0.42, inv * 0.55)
		draw_set_transform(pt + Vector2(0, 10), 0.0, Vector2(1.0, 0.40))
		draw_arc(Vector2.ZERO, lerpf(8.0, 30.0 * scale_m, pow(t, 0.65)), 0.0, TAU, 20, ring_col, 2.5 if dd.boss else 2.0, false)
		draw_set_transform(Vector2.ZERO)
		var count := 10 if dd.boss else 6
		for i in range(count):
			var a := TAU * float(i) / float(count) + 0.4
			var spread := lerpf(5.0, 24.0 * scale_m, pow(t, 0.7))
			var rise := -lerpf(0.0, 26.0 * scale_m, t)
			var mp := (pt + Vector2(cos(a) * spread, sin(a) * spread * 0.45 + rise)).round()
			var mc := Color(1.0, 0.82, 0.42, inv * 0.92) if dd.boss else (Color(0.86, 0.94, 0.98, inv * 0.82) if i % 2 == 0 else Color(0.32, 0.38, 0.46, inv * 0.75))
			draw_rect(Rect2(mp - Vector2(1.5, 1.5), Vector2(3, 3)), mc)

	# 破境成功：主角周身双层灵气冲击波环 + 螺旋升腾像素灵光微粒
	for bt in breakthrough_effects:
		if not is_instance_valid(bt.target):
			continue
		var t := clampf(float(bt.age) / maxf(0.01, float(bt.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(bt.target.global_position).round()
		var immortal := int(bt.rank) >= 2
		var primary := Color("ffe078") if immortal else Color("66f2ea")
		var secondary := Color("72e6ff") if immortal else Color("f6dc84")
		# 1. 地面斜椭圆双层灵气冲击波环
		var wave_t := clampf(t / 0.62, 0.0, 1.0)
		if wave_t < 1.0:
			var w_inv := 1.0 - wave_t
			var r_outer := lerpf(16.0, 118.0 if immortal else 92.0, pow(wave_t, 0.52))
			var r_inner := lerpf(10.0, 74.0 if immortal else 58.0, pow(wave_t, 0.65))
			draw_set_transform(pt + Vector2(0, 14), 0.0, Vector2(1.0, 0.40))
			draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, 36, Color(primary, w_inv * 0.88), 3.6 * w_inv + 1.2, false)
			draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, 28, Color(secondary, w_inv * 0.76), 2.2 * w_inv + 1.0, false)
			draw_arc(Vector2.ZERO, r_inner * 0.65, 0.0, TAU, 20, Color(1.0, 0.99, 0.92, w_inv * 0.68), 1.5, false)
			draw_set_transform(Vector2.ZERO)
		# 2. 短促纵向上冲微光柱（0..0.42 消散，通透不糊主角）
		if t < 0.42:
			var col_t := t / 0.42
			var col_a := sin(col_t * PI) * 0.34
			var half_w := lerpf(24.0 if immortal else 18.0, 8.0, col_t)
			draw_rect(Rect2(pt + Vector2(-half_w, -78.0), Vector2(half_w * 2.0, 92.0)), Color(primary, col_a))
			draw_rect(Rect2(pt + Vector2(-half_w * 0.45, -90.0), Vector2(half_w * 0.9, 104.0)), Color(1.0, 0.99, 0.90, col_a * 0.9))
		# 3. 螺旋升腾像素灵光粒子
		var p_count := 22 if immortal else 16
		for i in range(p_count):
			var phase_i := float(i) / float(p_count)
			var local_t := clampf((t - phase_i * 0.22) / 0.78, 0.0, 1.0)
			if local_t <= 0.0 or local_t >= 1.0:
				continue
			var p_inv := 1.0 - local_t
			var angle := phase_i * TAU * 2.0 + local_t * 3.6
			var rad := lerpf(12.0, 44.0 if immortal else 34.0, pow(local_t, 0.7))
			var lift := -lerpf(0.0, 72.0 if immortal else 56.0, local_t)
			var pos := (pt + Vector2(cos(angle) * rad, sin(angle) * rad * 0.36 + lift)).round()
			var pcol := primary if i % 2 == 0 else secondary
			var sz := 3.5 if (immortal and i % 3 == 0) else 2.5
			draw_rect(Rect2(pos - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), Color(pcol, p_inv * 0.95))
			draw_rect(Rect2(pos - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), Color(1.0, 0.99, 0.92, p_inv * 0.85))

	# 清场成功：出口点亮扩散微光环与上浮灵点
	for eb in exit_beacons:
		var t := clampf(float(eb.age) / maxf(0.01, float(eb.duration)), 0.0, 1.0)
		var inv := 1.0 - t
		var pt := to_local(eb.point).round()
		var r1 := lerpf(16.0, 62.0, pow(t, 0.55))
		var r2 := lerpf(10.0, 40.0, pow(t, 0.7))
		draw_arc(pt, r1, 0.0, TAU, 32, Color(0.96, 0.86, 0.54, inv * 0.85), 3.0 * inv + 1.0, false)
		draw_arc(pt, r2, 0.0, TAU, 24, Color(0.55, 0.96, 0.86, inv * 0.78), 2.0, false)
		for i in range(8):
			var a := TAU * float(i) / 8.0 + t * 1.5
			var sp := (pt + Vector2(cos(a) * lerpf(12.0, 32.0, t), sin(a) * lerpf(8.0, 20.0, t) - t * 34.0)).round()
			draw_rect(Rect2(sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(1.0, 0.94, 0.70, inv * 0.92))

	# 波次刷新：地面暗红/墨黑魔气召唤阵与升腾黑烟粒子（末段收缩爆发破雾现身）
	for ws in wave_summons:
		var t := clampf(float(ws.age) / maxf(0.01, float(ws.duration)), 0.0, 1.0)
		var pt := to_local(ws.point).round()
		var appear := smoothstep(0.0, 0.22, t)
		var contract := smoothstep(0.78, 1.0, t)
		var r := lerpf(14.0, 30.0, appear) * lerpf(1.0, 0.42, contract)
		var alpha := appear * (1.0 - smoothstep(0.92, 1.0, t))
		draw_set_transform(pt + Vector2(0, 10), 0.0, Vector2(1.0, 0.48))
		# 深墨底晕 + 暗红魔纹旋转外环 + 反向三角符印
		draw_circle(Vector2.ZERO, r * 1.08, Color(0.08, 0.03, 0.06, 0.42 * alpha))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.10, 0.04, 0.07, 0.85 * alpha), 4.5, false)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.88, 0.24, 0.22, 0.92 * alpha), 2.2, false)
		var rot := t * 3.2
		for seg in range(6):
			var a0 := rot + TAU * float(seg) / 6.0
			draw_arc(Vector2.ZERO, r * 0.68, a0, a0 + 0.55, 5, Color(1.0, 0.46, 0.30, 0.88 * alpha), 1.8, false)
		# 内侧反向旋转魔气菱印
		var in_pts := PackedVector2Array()
		for k in range(4):
			var a := -rot * 1.4 + float(k) * PI * 0.5
			in_pts.append(Vector2(cos(a), sin(a)) * (r * 0.52))
		draw_polyline(in_pts + PackedVector2Array([in_pts[0]]), Color(0.95, 0.36, 0.28, 0.82 * alpha), 1.6, false)
		draw_set_transform(Vector2.ZERO)
		# 升腾墨黑/赤红魔雾粒子
		for i in range(8):
			var p_t := fposmod(t * 1.45 + float(i) / 8.0, 1.0)
			var p_a := sin(p_t * PI) * alpha
			var ang := float(i) * 0.8 + t * 2.2
			var rad := lerpf(r * 0.85, 6.0, p_t)
			var mp := (pt + Vector2(cos(ang) * rad, sin(ang) * rad * 0.42 + 8.0 - p_t * 36.0)).round()
			var col := Color(0.14, 0.07, 0.12, 0.85 * p_a) if i % 2 == 0 else Color(0.92, 0.30, 0.24, 0.88 * p_a)
			var sz := 4.0 if i % 2 == 0 else 2.5
			draw_rect(Rect2(mp - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), col)
		# 末段收缩爆发赤墨灵雾
		if contract > 0.05:
			var burst_r := lerpf(8.0, 36.0, contract)
			draw_arc(pt + Vector2(0, 6), burst_r, 0.0, TAU, 24, Color(0.95, 0.34, 0.26, (1.0 - contract) * 0.90), 2.8, false)

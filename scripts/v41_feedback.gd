extends "res://scripts/combat_feedback.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
var guard_effects: Array[Dictionary] = []
var guard_sound: AudioStreamWAV
var break_sound: AudioStreamWAV
var sword_sounds := {}
var sword_voices := {}
var cue_times := {}

func _ready() -> void:
	guard_sound = _metal_sound(false)
	break_sound = _metal_sound(true)
	sword_sounds = {
		"light_swing": _sword_sound(760.0, 0.09, 0.76, 0.50),
		"heavy_swing": _sword_sound(345.0, 0.15, 0.61, 0.65),
		"light_hit": _sword_sound(465.0, 0.065, 1.30, 0.38),
		"heavy_hit": _sword_sound(155.0, 0.16, 0.63, 0.24),
		"dash": _sword_sound(970.0, 0.18, 2.04, 0.58),
		"dash_hit": _sword_sound(295.0, 0.08, 0.65, 0.42),
		"mark": _sword_sound(530.0, 0.10, 0.50, 0.51),
		"mark_hit": _sword_sound(235.0, 0.16, 0.47, 0.56),
		"throw_cast": _sword_sound(633.0, 0.11, 1.8, 0.57),
		"throw_spin": _sword_sound(1170.0, 0.14, 0.72, 0.62),
		"throw_hit": _sword_sound(411.0, 0.085, 0.65, 0.45),
		"throw_catch": _sword_sound(1510.0, 0.062, 0.78, 0.33),
	}

func reset_sword_cues() -> void:
	sword_voices.clear()
	cue_times.clear()

func _voice(channel: String) -> AudioStreamPlayer:
	if not is_instance_valid(sword_voices.get(channel)):
		var voice := AudioStreamPlayer.new()
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

func play_sword_cue(kind: String, _point: Vector2) -> void:
	var channel := "mark" if kind.begins_with("mark") else ("contact" if kind.ends_with("hit") else "motion")
	if _cue_ready(channel, 68 if channel == "mark" else 50):
		var voice := _voice(channel)
		voice.stream = sword_sounds[kind]
		voice.volume_db = -12.0 if kind == "heavy_hit" else (-20.0 if kind == "light_swing" else -16.0)
		voice.play()
	if kind in ["dash_hit", "mark_hit"] and _cue_ready("dash_shake", 200):
		shake_strength = maxf(shake_strength, 2.2 if kind == "dash_hit" else 3.7)
		shake_time = maxf(shake_time, 0.11)

func show_damage(point: Vector2, amount: float, is_player: bool, camera_shake: bool = true, blocked: bool = false) -> void:
	super.show_damage(point, amount, is_player, camera_shake, blocked)
	if blocked and amount > 0.0:
		_guard_effect(point, false)

func show_guard_break(point: Vector2) -> void:
	_popup(point, "破防", Color("ffce77"), "guard_break", 0.0)
	_guard_effect(point, true)

func _guard_effect(point: Vector2, broken: bool) -> void:
	guard_effects.append({"point": point, "age": 0.0, "broken": broken})
	if not _cue_ready("guard", 82):
		return
	var sound := _voice("guard")
	sound.stream = break_sound if broken else guard_sound
	sound.volume_db = CONFIG.GUARD_SOUND_DB
	sound.play()

func _sword_sound(pitch: float, duration: float, glide: float, noise_mix: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch)
	var phase_value := 0.0
	var filtered := 0.0
	for i in range(samples):
		var progress := float(i) / samples
		var envelope := minf(progress * 70.0, 1.0) * pow(1.0 - progress, 2.6)
		phase_value += TAU * pitch * lerpf(1.0, glide, progress) / stream.mix_rate
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.32)
		var tone := sin(phase_value) * 0.62 + sin(phase_value * 2.41) * 0.24
		var sample := lerpf(tone, filtered, noise_mix) * envelope * 0.82
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = bytes
	return stream

func _metal_sound(broken: bool) -> AudioStreamWAV:
	# Short deterministic metallic transient; no imported audio dependency.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := CONFIG.BREAK_SPARK_TIME if broken else CONFIG.GUARD_SPARK_TIME
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / stream.mix_rate
		var envelope := exp(-t * (22.0 if broken else 32.0))
		var pitch := (950.0 - t * 1500.0) if broken else 1800.0
		var sample := (sin(TAU * pitch * t) + 0.45 * sin(TAU * pitch * 2.71 * t)) * envelope * 0.45
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = bytes
	return stream

func _process(delta: float) -> void:
	super._process(delta)
	for i in range(guard_effects.size() - 1, -1, -1):
		guard_effects[i].age += delta
		var duration := CONFIG.BREAK_SPARK_TIME if guard_effects[i].broken else CONFIG.GUARD_SPARK_TIME
		if guard_effects[i].age >= duration:
			guard_effects.remove_at(i)

func _draw() -> void:
	super._draw()
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

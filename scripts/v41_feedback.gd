extends "res://scripts/combat_feedback.gd"

const CONFIG = preload("res://scripts/v41_config.gd")
var guard_effects: Array[Dictionary] = []
var guard_sound: AudioStreamWAV
var break_sound: AudioStreamWAV

func _ready() -> void:
	guard_sound = _metal_sound(false)
	break_sound = _metal_sound(true)

func show_damage(point: Vector2, amount: float, is_player: bool, camera_shake: bool = true, blocked: bool = false) -> void:
	super.show_damage(point, amount, is_player, camera_shake, blocked)
	if blocked and amount > 0.0:
		_guard_effect(point, false)

func show_guard_break(point: Vector2) -> void:
	_popup(point, "破防", Color("ffce77"), "guard_break", 0.0)
	_guard_effect(point, true)

func _guard_effect(point: Vector2, broken: bool) -> void:
	guard_effects.append({"point": point, "age": 0.0, "broken": broken})
	var sound := AudioStreamPlayer.new()
	sound.stream = break_sound if broken else guard_sound
	sound.volume_db = CONFIG.GUARD_SOUND_DB
	add_child(sound)
	sound.tree_exiting.connect(func():
		sound.stop()
		sound.stream = null)
	sound.finished.connect(sound.queue_free)
	sound.play()

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

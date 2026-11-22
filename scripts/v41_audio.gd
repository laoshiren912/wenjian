extends Node

const BGM_BUS := "BGM"
const SFX_BUS := "SFX"
const BGM_VOLUME_DB := -12.5
const SFX_VOLUME_DB := -0.5
const NORMAL_BGM_PATH := "res://assets/audio/bgm_normal.ogg"
const BOSS_BGM_PATH := "res://assets/audio/bgm_boss.ogg"

var bgm_player: AudioStreamPlayer
var normal_bgm: AudioStream
var boss_bgm: AudioStream
var current_boss_mode := false
var bgm_muted := false
var master_muted := false
var _bgm_target_db := -3.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BgmPlayer"
	bgm_player.bus = BGM_BUS
	bgm_player.volume_db = _bgm_target_db
	add_child(bgm_player)
	normal_bgm = _load_or_build_bgm(false)
	boss_bgm = _load_or_build_bgm(true)
	play_room_bgm(false)

func _process(delta: float) -> void:
	if is_instance_valid(bgm_player) and not is_equal_approx(bgm_player.volume_db, _bgm_target_db):
		bgm_player.volume_db = move_toward(bgm_player.volume_db, _bgm_target_db, delta * 9.0)

func set_title_soft_mode(enabled: bool, instant: bool = false) -> void:
	_bgm_target_db = -7.8 if enabled else -3.0
	if instant and is_instance_valid(bgm_player):
		bgm_player.volume_db = _bgm_target_db

func _ensure_buses() -> void:
	# Master 挂 Limiter 防止群怪连击或万剑齐落瞬间削波爆音
	var has_limiter := false
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLimiter:
			has_limiter = true
			break
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.2
		limiter.threshold_db = -4.0
		AudioServer.add_bus_effect(0, limiter)

	if AudioServer.get_bus_index(BGM_BUS) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BGM_BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, BGM_VOLUME_DB)

	if AudioServer.get_bus_index(SFX_BUS) == -1:
		var idx := AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, SFX_VOLUME_DB)

func play_room_bgm(is_boss: bool) -> void:
	if not is_instance_valid(bgm_player):
		return
	var target_stream := boss_bgm if is_boss else normal_bgm
	if bgm_player.playing and current_boss_mode == is_boss and bgm_player.stream == target_stream:
		return
	current_boss_mode = is_boss
	bgm_player.stream = target_stream
	bgm_player.play()

func toggle_master_mute() -> bool:
	master_muted = not master_muted
	AudioServer.set_bus_mute(0, master_muted)
	return master_muted

func toggle_bgm_mute() -> bool:
	bgm_muted = not bgm_muted
	var idx := AudioServer.get_bus_index(BGM_BUS)
	if idx != -1:
		AudioServer.set_bus_mute(idx, bgm_muted)
	return bgm_muted

func _load_or_build_bgm(is_boss: bool) -> AudioStream:
	var path := BOSS_BGM_PATH if is_boss else NORMAL_BGM_PATH
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is AudioStream:
			return loaded
	return _synthesize_xianxia_bgm(is_boss)

func _synthesize_xianxia_bgm(is_boss: bool) -> AudioStreamWAV:
	# 高律动武侠/仙侠动作推进 BGM：普通关 132 BPM，Boss 关 150 BPM（8 小节无缝循环）
	var mix_rate := 22050
	var bpm := 150.0 if is_boss else 132.0
	var beat_sec := 60.0 / bpm
	var step_sec := beat_sec * 0.5 # 8 分音符步长
	var total_steps := 64 # 8 小节 * 8 个八分音符
	var duration := step_sec * float(total_steps)
	var total_samples := int(round(duration * mix_rate))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples

	var buf := PackedFloat32Array()
	buf.resize(total_samples)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7711 if is_boss else 4132

	# 1) 打击乐推进轨：沉稳堂鼓(kick) + 清脆竹板/木击(rim) + 轻快切分沙锤(hat)
	for step in range(total_steps):
		var start_idx := int(float(step) * step_sec * mix_rate)
		var bar_step := step % 8
		var is_fill := (step >= total_steps - 4)

		# 堂鼓强拍与切分推进
		var kick_gain := 0.0
		if bar_step == 0:
			kick_gain = 0.34 if is_boss else 0.28
		elif bar_step == 3 or bar_step == 4:
			kick_gain = (0.26 if is_boss else 0.20) if bar_step == 4 else (0.18 if is_boss else 0.14)
		elif is_boss and bar_step == 6:
			kick_gain = 0.22
		if is_fill:
			kick_gain = maxf(kick_gain, 0.24)
		if kick_gain > 0.0:
			var k_len := mini(total_samples - start_idx, int(0.18 * mix_rate))
			for j in range(k_len):
				var lt := float(j) / float(mix_rate)
				var env := minf(lt * 160.0, 1.0) * exp(-lt * 19.0)
				var f := lerpf(138.0, 50.0, minf(lt * 12.0, 1.0))
				buf[start_idx + j] += sin(TAU * f * lt) * env * kick_gain

		# 反拍清脆竹板/木击（让律动清醒带劲）
		if bar_step == 2 or bar_step == 6 or (is_fill and bar_step % 2 == 1):
			var r_len := mini(total_samples - start_idx, int(0.065 * mix_rate))
			var r_gain := 0.17 if is_boss else 0.14
			for j in range(r_len):
				var lt := float(j) / float(mix_rate)
				var env := minf(lt * 240.0, 1.0) * exp(-lt * 46.0)
				var wood := sin(TAU * 920.0 * lt) * 0.55 + sin(TAU * 1580.0 * lt) * 0.30 + rng.randf_range(-0.25, 0.25)
				buf[start_idx + j] += wood * env * r_gain

		# 轻快 8 分沙锤/竹叶切分（克制不刺耳）
		var h_len := mini(total_samples - start_idx, int(0.032 * mix_rate))
		var h_gain := (0.055 if bar_step % 2 == 1 else 0.032) * (1.2 if is_boss else 1.0)
		var prev_n := 0.0
		for j in range(h_len):
			var lt := float(j) / float(mix_rate)
			var env := exp(-lt * 95.0)
			var raw := rng.randf_range(-1.0, 1.0)
			var hp := raw - prev_n * 0.82
			prev_n = raw
			buf[start_idx + j] += hp * env * h_gain

	# 2) 疾走低音拨弦推进轨（每小节 8 步切分驱动，彻底告别沉闷长音）
	var bass_roots_normal := [146.83, 146.83, 130.81, 130.81, 116.54, 130.81, 146.83, 164.81] # D3-C3-Bb2-C3-D3-E3
	var bass_roots_boss := [146.83, 116.54, 130.81, 110.00, 146.83, 116.54, 130.81, 164.81] # D3-Bb2-C3-A2
	var bass_roots: Array = bass_roots_boss if is_boss else bass_roots_normal
	for step in range(total_steps):
		var bar := step / 8
		var bar_step := step % 8
		if bar_step in [1, 5] and not is_boss:
			continue
		var root_f: float = float(bass_roots[bar]) * (1.5 if bar_step == 7 else 1.0)
		var start_idx := int(float(step) * step_sec * mix_rate)
		var b_len := mini(total_samples - start_idx, int(step_sec * 1.15 * mix_rate))
		for j in range(b_len):
			var lt := float(j) / float(mix_rate)
			var env := minf(lt * 110.0, 1.0) * exp(-lt * 9.5)
			var tone := sin(TAU * root_f * lt) * 0.72 + sin(TAU * root_f * 2.0 * lt) * 0.24 * exp(-lt * 12.0)
			buf[start_idx + j] += tone * env * (0.20 if is_boss else 0.17)

	# 3) 主旋律轨：英气疾快琵琶/古筝五声音阶（高颗粒感短促拨弦，带跳跃推进感）
	# 音高表：D4=293.66, E4=329.63, F4=349.23, G4=392.00, A4=440.00, C5=523.25, D5=587.33, E5=659.25, F5=698.46
	var lead_normal := [
		293.66, 0.0, 349.23, 440.00, 523.25, 0.0, 440.00, 392.00,
		440.00, 0.0, 349.23, 329.63, 293.66, 0.0, 349.23, 440.00,
		523.25, 0.0, 587.33, 523.25, 440.00, 0.0, 392.00, 349.23,
		392.00, 440.00, 349.23, 0.0, 329.63, 0.0, 293.66, 0.0,
		587.33, 0.0, 523.25, 587.33, 659.25, 0.0, 587.33, 523.25,
		440.00, 0.0, 523.25, 440.00, 392.00, 0.0, 349.23, 440.00,
		587.33, 523.25, 440.00, 392.00, 440.00, 0.0, 523.25, 587.33,
		659.25, 0.0, 587.33, 523.25, 440.00, 0.0, 349.23, 440.00,
	]
	var lead_boss := [
		587.33, 587.33, 523.25, 587.33, 698.46, 0.0, 659.25, 587.33,
		523.25, 0.0, 440.00, 523.25, 587.33, 0.0, 440.00, 392.00,
		440.00, 523.25, 587.33, 659.25, 698.46, 659.25, 587.33, 523.25,
		440.00, 0.0, 392.00, 349.23, 440.00, 0.0, 523.25, 440.00,
		587.33, 0.0, 698.46, 659.25, 587.33, 523.25, 587.33, 659.25,
		698.46, 0.0, 587.33, 523.25, 440.00, 523.25, 587.33, 0.0,
		659.25, 587.33, 523.25, 440.00, 523.25, 587.33, 659.25, 698.46,
		587.33, 523.25, 440.00, 392.00, 440.00, 523.25, 587.33, 0.0,
	]
	var lead: Array = lead_boss if is_boss else lead_normal
	for step in range(total_steps):
		var freq: float = float(lead[step])
		if freq <= 0.0:
			continue
		var start_idx := int(float(step) * step_sec * mix_rate)
		var n_len := mini(total_samples - start_idx, int(step_sec * 1.85 * mix_rate))
		for j in range(n_len):
			var lt := float(j) / float(mix_rate)
			var env := minf(lt * 160.0, 1.0) * exp(-lt * (7.2 if is_boss else 6.2))
			# 琵琶/古筝拨弦：干净基频 + 明亮泛音瞬态，不刺耳
			var pluck := sin(TAU * freq * lt) * 0.62 + sin(TAU * freq * 2.0 * lt) * 0.25 * exp(-lt * 10.0) + sin(TAU * freq * 3.0 * lt) * 0.09 * exp(-lt * 18.0)
			buf[start_idx + j] += pluck * env * (0.22 if is_boss else 0.20)

	# 4) 后半段（第 5-8 小节）清亮短促竹笛应答点缀（增加层次与闯关爽感）
	var flute_cues := [[32, 880.0, 2], [36, 1046.5, 2], [40, 880.0, 2], [48, 1174.66, 2], [56, 1318.5, 2], [60, 880.0, 2]]
	for cue in flute_cues:
		var start_idx := int(float(cue[0]) * step_sec * mix_rate)
		var f: float = float(cue[1])
		var f_len := mini(total_samples - start_idx, int(float(cue[2]) * step_sec * mix_rate))
		for j in range(f_len):
			var lt := float(j) / float(mix_rate)
			var prog := float(j) / float(maxi(1, f_len))
			var env := sin(prog * PI) * 0.85
			var vib := 1.0 + 0.008 * sin(TAU * 5.8 * lt)
			var flute := sin(TAU * f * vib * lt) * 0.82 + sin(TAU * f * 2.0 * vib * lt) * 0.14
			buf[start_idx + j] += flute * env * 0.085

	# 首尾 25ms 平滑防爆点
	var fade_len := int(0.025 * mix_rate)
	for i in range(fade_len):
		var k := float(i) / float(fade_len)
		buf[i] *= k
		buf[total_samples - 1 - i] *= k

	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var s := clampf(buf[i], -0.92, 0.92)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	stream.data = bytes
	return stream

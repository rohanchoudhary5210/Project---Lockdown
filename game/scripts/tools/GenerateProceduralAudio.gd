@tool
extends SceneTree

const SAMPLE_RATE := 44100
const OUTPUT_DIR := "res://game/assets/audio/procedural/"

func _init() -> void:
	print("--- Generating Procedural Audio Assets ---")
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	seed(1337) # same assets every run
	
	# Survival / tension set (run with "-- --tension-only" to regenerate just these)
	_generate_tension_set()
	if "--tension-only" in OS.get_cmdline_user_args():
		print("--- Tension audio generated ---")
		quit(0)
		return
	
	_generate_sfx_pistol_shot()
	_generate_sfx_rifle_shot()
	_generate_sfx_dry_fire()
	_generate_sfx_reload()
	_generate_sfx_melee_swing()
	_generate_sfx_melee_hit()
	_generate_sfx_parry_clang()
	_generate_sfx_block_thud()
	_generate_sfx_footsteps()
	_generate_sfx_pickup()
	_generate_sfx_checkpoint_chime()
	_generate_sfx_heartbeat()
	_generate_amb_building_hum()
	
	print("--- All Procedural Audio Assets Generated Successfully ---")
	quit(0)

func _save_wav_and_tres(filename_base: String, samples: Array[float], is_looping: bool = false) -> void:
	var num_samples = samples.size()
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	for i in range(num_samples):
		var s = clampf(samples[i], -1.0, 1.0)
		var val = clampi(int(s * 32767.0), -32768, 32767)
		byte_data.encode_s16(i * 2, val)
	
	# Create AudioStreamWAV resource
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = byte_data
	if is_looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = num_samples
	
	var tres_path = OUTPUT_DIR + filename_base + ".tres"
	var err = ResourceSaver.save(stream, tres_path)
	if err != OK:
		push_error("Failed to save " + tres_path + ": " + str(err))
	else:
		print("Saved resource: ", tres_path)
	
	# Also save .wav file with standard 44-byte RIFF header
	var riff_bytes = _build_riff_wav(byte_data, SAMPLE_RATE)
	var wav_path = OUTPUT_DIR + filename_base + ".wav"
	var file = FileAccess.open(wav_path, FileAccess.WRITE)
	if file:
		file.store_buffer(riff_bytes)
		file.close()
		print("Saved WAV file: ", wav_path)

func _build_riff_wav(pcm_data: PackedByteArray, sample_rate: int) -> PackedByteArray:
	var header = PackedByteArray()
	header.resize(44)
	# "RIFF"
	header.set(0, 0x52); header.set(1, 0x49); header.set(2, 0x46); header.set(3, 0x46)
	var chunk_size = 36 + pcm_data.size()
	header.encode_u32(4, chunk_size)
	# "WAVE"
	header.set(8, 0x57); header.set(9, 0x41); header.set(10, 0x56); header.set(11, 0x45)
	# "fmt "
	header.set(12, 0x66); header.set(13, 0x6D); header.set(14, 0x74); header.set(15, 0x20)
	header.encode_u32(16, 16) # Subchunk1Size = 16 for PCM
	header.encode_u16(20, 1)  # AudioFormat = 1 (PCM)
	header.encode_u16(22, 1)  # NumChannels = 1 (Mono)
	header.encode_u32(24, sample_rate)
	header.encode_u32(28, sample_rate * 2) # ByteRate = sample_rate * 1 * 16 / 8
	header.encode_u16(32, 2)  # BlockAlign = 1 * 16 / 8
	header.encode_u16(34, 16) # BitsPerSample = 16
	# "data"
	header.set(36, 0x64); header.set(37, 0x61); header.set(38, 0x74); header.set(39, 0x61)
	header.encode_u32(40, pcm_data.size())
	return header + pcm_data

# 1. Pistol shot: punchy noise burst + pitch-dropping sine (800 -> 60 Hz)
func _generate_sfx_pistol_shot() -> void:
	var dur = 0.22
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	var phase = 0.0
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var freq = 60.0 + (800.0 - 60.0) * exp(-t * 35.0)
		phase += TAU * freq / SAMPLE_RATE
		var sine_val = sin(phase) * exp(-t * 18.0) * 0.75
		var noise = (randf() * 2.0 - 1.0) * exp(-t * 45.0) * 0.65
		var sample = sine_val + noise
		# Soft saturation
		sample = tanh(sample * 1.4)
		samples[i] = sample
	_save_wav_and_tres("sfx_pistol_shot", samples)

# 2. Enemy rifle shot: deeper, more resonant crack (380 -> 45 Hz)
func _generate_sfx_rifle_shot() -> void:
	var dur = 0.35
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	var phase1 = 0.0
	var phase2 = 0.0
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var freq = 45.0 + (380.0 - 45.0) * exp(-t * 22.0)
		phase1 += TAU * freq / SAMPLE_RATE
		phase2 += TAU * 170.0 / SAMPLE_RATE
		var bass = sin(phase1) * exp(-t * 12.0) * 0.7
		var body = sin(phase2) * exp(-t * 16.0) * 0.3
		var crack = (randf() * 2.0 - 1.0) * exp(-t * 32.0) * 0.7
		var sample = bass + body + crack
		sample = tanh(sample * 1.5)
		samples[i] = sample
	_save_wav_and_tres("sfx_rifle_shot", samples)

# 3. Dry-fire click: short metallic click
func _generate_sfx_dry_fire() -> void:
	var dur = 0.05
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var click = sin(TAU * 2200.0 * t) * exp(-t * 110.0) * 0.5
		var metallic = sin(TAU * 3400.0 * t) * exp(-t * 130.0) * 0.3
		var noise = (randf() * 2.0 - 1.0) * exp(-t * 200.0) * 0.3
		samples[i] = click + metallic + noise
	_save_wav_and_tres("sfx_dry_fire", samples)

# 4. Reload: mag out (lower click) then mag in (higher snap)
func _generate_sfx_reload() -> void:
	var dur = 0.65
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var s = 0.0
		# Part 1: Mag out at t=0.06s
		if t >= 0.06 and t < 0.25:
			var dt1 = t - 0.06
			var slide = (randf() * 2.0 - 1.0) * exp(-dt1 * 40.0) * 0.25
			var clk = sin(TAU * 650.0 * dt1) * exp(-dt1 * 60.0) * 0.4
			s += slide + clk
		# Part 2: Mag in snap at t=0.40s
		if t >= 0.40:
			var dt2 = t - 0.40
			var snap = sin(TAU * 1550.0 * dt2) * exp(-dt2 * 75.0) * 0.5
			var snap2 = sin(TAU * 2300.0 * dt2) * exp(-dt2 * 90.0) * 0.3
			var latch = (randf() * 2.0 - 1.0) * exp(-dt2 * 110.0) * 0.3
			s += snap + snap2 + latch
		samples[i] = s
	_save_wav_and_tres("sfx_reload", samples)

# 5. Melee swing: whoosh (filtered noise sweep)
func _generate_sfx_melee_swing() -> void:
	var dur = 0.22
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	var lp_state = 0.0
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var norm_t = t / dur
		var env = sin(PI * norm_t)
		# Frequency sweep 160 -> 420 -> 140 Hz
		var sweep_freq = 140.0 + 280.0 * sin(PI * norm_t)
		var noise = randf() * 2.0 - 1.0
		var alpha = clampf(TAU * sweep_freq / SAMPLE_RATE, 0.0, 1.0)
		lp_state += alpha * (noise - lp_state)
		samples[i] = lp_state * env * 0.7
	_save_wav_and_tres("sfx_melee_swing", samples)

# 6. Melee hit: blunt impact thud
func _generate_sfx_melee_hit() -> void:
	var dur = 0.22
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	var phase = 0.0
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var freq = 45.0 + (125.0 - 45.0) * exp(-t * 25.0)
		phase += TAU * freq / SAMPLE_RATE
		var bass = sin(phase) * exp(-t * 18.0) * 0.7
		var noise = (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.5
		var sample = bass + noise
		samples[i] = tanh(sample * 1.3)
	_save_wav_and_tres("sfx_melee_hit", samples)

# 7. Parry: sharp metallic clang (two high sines + fast ring-out)
func _generate_sfx_parry_clang() -> void:
	var dur = 0.55
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var ring = exp(-t * 8.5)
		var s1 = sin(TAU * 1850.0 * t) * 0.45
		var s2 = sin(TAU * 2420.0 * t) * 0.4
		var s3 = sin(TAU * 3880.0 * t) * 0.15
		var spark = (randf() * 2.0 - 1.0) * exp(-t * 120.0) * 0.35
		samples[i] = (s1 + s2 + s3 + spark) * ring
	_save_wav_and_tres("sfx_parry_clang", samples)

# 8. Block: muffled thud
func _generate_sfx_block_thud() -> void:
	var dur = 0.20
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	var phase = 0.0
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var freq = 40.0 + (70.0 - 40.0) * exp(-t * 20.0)
		phase += TAU * freq / SAMPLE_RATE
		var bass = sin(phase) * exp(-t * 16.0) * 0.65
		var muffled_noise = (randf() * 2.0 - 1.0) * exp(-t * 50.0) * 0.25
		samples[i] = bass + muffled_noise
	_save_wav_and_tres("sfx_block_thud", samples)

# 9. Footsteps: 4 slight variations of a concrete tap (short noise + low thud)
func _generate_sfx_footsteps() -> void:
	var variations = [
		{"noise_freq": 1200.0, "bass_freq": 80.0, "decay": 48.0},
		{"noise_freq": 1400.0, "bass_freq": 92.0, "decay": 52.0},
		{"noise_freq": 1100.0, "bass_freq": 74.0, "decay": 44.0},
		{"noise_freq": 1300.0, "bass_freq": 86.0, "decay": 50.0}
	]
	var dur = 0.10
	var total = int(SAMPLE_RATE * dur)
	
	for idx in range(variations.size()):
		var v = variations[idx]
		var samples: Array[float] = []
		samples.resize(total)
		var lp_state = 0.0
		for i in range(total):
			var t = float(i) / SAMPLE_RATE
			var env = exp(-t * v.decay)
			var bass = sin(TAU * v.bass_freq * t) * 0.45 * env
			var raw_noise = randf() * 2.0 - 1.0
			var alpha = clampf(TAU * v.noise_freq / SAMPLE_RATE, 0.0, 1.0)
			lp_state += alpha * (raw_noise - lp_state)
			var tap = lp_state * env * 0.4
			samples[i] = bass + tap
		_save_wav_and_tres("sfx_footstep_" + str(idx + 1), samples)

# 10. Pickup: pleasant two-tone chime
func _generate_sfx_pickup() -> void:
	var dur = 0.28
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var s = 0.0
		# Tone 1: D5 (587.33 Hz)
		if t < 0.14:
			var env1 = exp(-t * 16.0)
			s += sin(TAU * 587.33 * t) * 0.4 * env1
			s += sin(TAU * 1174.66 * t) * 0.1 * env1
		# Tone 2: A5 (880.0 Hz)
		if t >= 0.09:
			var dt2 = t - 0.09
			var env2 = exp(-dt2 * 14.0)
			s += sin(TAU * 880.0 * dt2) * 0.45 * env2
			s += sin(TAU * 1760.0 * dt2) * 0.12 * env2
		samples[i] = s
	_save_wav_and_tres("sfx_pickup", samples)

# 11. Checkpoint: resonant chime (three tones ascending: C5 523 -> E5 659 -> G5 784)
func _generate_sfx_checkpoint_chime() -> void:
	var dur = 1.3
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	var notes = [
		{"t_start": 0.0, "freq": 523.25},
		{"t_start": 0.18, "freq": 659.25},
		{"t_start": 0.36, "freq": 783.99}
	]
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var s = 0.0
		for n in notes:
			if t >= n.t_start:
				var dt = t - n.t_start
				var env = exp(-dt * 3.8)
				var tone = sin(TAU * n.freq * dt) * 0.3 * env
				var harmonic = sin(TAU * n.freq * 2.0 * dt) * 0.08 * env
				s += tone + harmonic
		samples[i] = s
	_save_wav_and_tres("sfx_checkpoint_chime", samples)

# 12. Low-HP heartbeat: low double-thump (lub-dub) every 0.8s when below 30 HP
func _generate_sfx_heartbeat() -> void:
	var dur = 0.80
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var s = 0.0
		# Lub at t=0.0s
		if t < 0.20:
			var env1 = exp(-t * 22.0)
			s += sin(TAU * 55.0 * t) * 0.65 * env1
		# Dub at t=0.16s
		if t >= 0.16 and t < 0.45:
			var dt2 = t - 0.16
			var env2 = exp(-dt2 * 20.0)
			s += sin(TAU * 48.0 * dt2) * 0.75 * env2
		samples[i] = s
	_save_wav_and_tres("sfx_heartbeat", samples)

# 13. Ambience: a soft, low, looping hum for the building (two low sines with slight beating)
func _generate_amb_building_hum() -> void:
	# 4.0s loop: 60Hz * 4 = 240 cycles; 61.5Hz * 4 = 246 cycles; 120Hz * 4 = 480 cycles.
	# Perfect cycle alignment across 4 seconds = 100% seamless loop!
	var dur = 4.0
	var total = int(SAMPLE_RATE * dur)
	var samples: Array[float] = []
	samples.resize(total)
	for i in range(total):
		var t = float(i) / SAMPLE_RATE
		var s1 = sin(TAU * 60.0 * t) * 0.25
		var s2 = sin(TAU * 61.5 * t) * 0.25
		var s3 = sin(TAU * 120.0 * t) * 0.08
		samples[i] = s1 + s2 + s3
	_save_wav_and_tres("amb_building_hum", samples, true)

# ── Survival / tension set ──────────────────────────────────────────────────
func _generate_tension_set() -> void:
	_generate_sfx_breath()
	_generate_sfx_flashlight_click()
	_generate_sfx_distant_thud()
	_generate_sfx_metal_creak()
	_generate_sfx_door_bang()
	_generate_sfx_debris_fall()
	_generate_sfx_power_down()
	_generate_amb_tension_drone()

func _lowpass(samples: Array[float], amount: float) -> void:
	var y := 0.0
	for i in samples.size():
		y += (samples[i] - y) * amount
		samples[i] = y

func _buffer(dur: float) -> Array[float]:
	var s: Array[float] = []
	s.resize(int(SAMPLE_RATE * dur))
	s.fill(0.0)
	return s

# One shaky breath (in, then out): band-limited noise under a two-hump envelope
func _generate_sfx_breath() -> void:
	var s := _buffer(1.7)
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		var env_in := sin(clampf(t / 0.65, 0.0, 1.0) * PI) * 0.55
		var env_out := sin(clampf((t - 0.75) / 0.9, 0.0, 1.0) * PI) * 0.8
		var tremble := 1.0 + 0.25 * sin(TAU * 9.0 * t)
		s[i] = randf_range(-1.0, 1.0) * (env_in + env_out) * tremble
	_lowpass(s, 0.12)
	for i in s.size():
		s[i] *= 1.6
	_save_wav_and_tres("sfx_breath", s)

func _generate_sfx_flashlight_click() -> void:
	var s := _buffer(0.06)
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		s[i] = (randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 3200.0 * t) * 0.4) * exp(-t * 160.0)
	_save_wav_and_tres("sfx_flashlight_click", s)

# Something heavy dropped far away in the building
func _generate_sfx_distant_thud() -> void:
	var s := _buffer(1.4)
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		s[i] = (sin(TAU * 42.0 * t) * 0.8 + randf_range(-1.0, 1.0) * 0.25) * exp(-t * 4.5)
	_lowpass(s, 0.05)
	for i in s.size():
		s[i] *= 2.2
	_save_wav_and_tres("sfx_distant_thud", s)

# Slow metal groan: detuned sweeping tones with a scraping noise layer
func _generate_sfx_metal_creak() -> void:
	var s := _buffer(2.2)
	var ph1 := 0.0
	var ph2 := 0.0
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		var f := 180.0 + 70.0 * sin(TAU * 0.35 * t) + 15.0 * sin(TAU * 7.0 * t)
		ph1 += TAU * f / SAMPLE_RATE
		ph2 += TAU * f * 1.51 / SAMPLE_RATE
		var env := sin(clampf(t / 2.2, 0.0, 1.0) * PI)
		s[i] = (sin(ph1) * 0.3 + sin(ph2) * 0.15 + randf_range(-1.0, 1.0) * 0.12 * absf(sin(TAU * 11.0 * t))) * env
	_save_wav_and_tres("sfx_metal_creak", s)

# Fist / shoulder against a door: low thump plus a short rattle
func _generate_sfx_door_bang() -> void:
	var s := _buffer(0.6)
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		var thump := sin(TAU * 70.0 * t) * exp(-t * 18.0)
		var rattle := randf_range(-1.0, 1.0) * exp(-t * 9.0) * 0.35 * absf(sin(TAU * 38.0 * t))
		s[i] = (thump + rattle) * 0.9
	_save_wav_and_tres("sfx_door_bang", s)

# Ceiling giving way: a crack, then tumbling concrete
func _generate_sfx_debris_fall() -> void:
	var s := _buffer(2.0)
	var hits := []
	for k in 14:
		hits.append([randf_range(0.05, 1.6), randf_range(0.3, 0.9), randf_range(60.0, 160.0)])
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		var v := randf_range(-1.0, 1.0) * 0.6 * exp(-t * 30.0) # crack
		for h in hits:
			if t >= h[0]:
				var dt: float = t - h[0]
				v += (sin(TAU * h[2] * dt) * 0.6 + randf_range(-1.0, 1.0) * 0.4) * h[1] * exp(-dt * 14.0)
		v += randf_range(-1.0, 1.0) * 0.08 * exp(-t * 1.2) # dust/settling
		s[i] = v * 0.6
	_save_wav_and_tres("sfx_debris_fall", s)

# Power failing: hum dropping in pitch and fading, with a relay clunk at the start
func _generate_sfx_power_down() -> void:
	var s := _buffer(1.8)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		var f := lerpf(120.0, 25.0, clampf(t / 1.6, 0.0, 1.0))
		ph += TAU * f / SAMPLE_RATE
		var clunk := randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.8
		s[i] = (sin(ph) * 0.5 + sin(ph * 2.0) * 0.15) * (1.0 - clampf(t / 1.8, 0.0, 1.0)) + clunk
	_save_wav_and_tres("sfx_power_down", s)

# Looping low drone for tension (4s, whole cycles so it loops cleanly)
func _generate_amb_tension_drone() -> void:
	var s := _buffer(4.0)
	for i in s.size():
		var t := float(i) / SAMPLE_RATE
		var swell := 0.75 + 0.25 * sin(TAU * 0.25 * t)
		s[i] = (sin(TAU * 41.0 * t) * 0.3 + sin(TAU * 41.5 * t) * 0.3 + sin(TAU * 82.25 * t) * 0.08 + sin(TAU * 123.0 * t) * 0.04) * swell
	_save_wav_and_tres("amb_tension_drone", s, true)

extends Node
## Music (crossfaded loops per region / Gate / boss) and pooled SFX/UI one-shots.
## Sounds are referenced by id: assets/audio/sfx/<id>.wav and assets/audio/bgm/<id>.ogg
## (tools/gen_audio.py placeholders), falling back to Synth. Gameplay events are hooked here
## so systems never call audio directly.

const BUS_UI: StringName = &"UI"
const BUS_SFX: StringName = &"SFX"
const BUS_BGM: StringName = &"BGM"
const POOL_SIZE: int = 12
const SFX_DIR: String = "res://assets/audio/sfx/%s.wav"
const BGM_DIR: String = "res://assets/audio/bgm/%s.ogg"
const FADE_S: float = 1.6
const MUSIC_DB: float = -8.0
## The same SFX id plays at most once per this interval (multi-hits).
const SFX_MIN_GAP_S: float = 0.05

var music_id: StringName = &""
## Music to return to after a boss fight.
var _base_music: StringName = &""
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary[StringName, AudioStream] = {}
var _last_played: Dictionary[StringName, float] = {}
var _music: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _fade: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	for i: int in 2:
		var m: AudioStreamPlayer = AudioStreamPlayer.new()
		m.bus = BUS_BGM
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_hook_events()


func play_ui(id: StringName) -> void:
	_play(id, BUS_UI)


func play_sfx(id: StringName) -> void:
	_play(id, BUS_SFX)


func get_stream(id: StringName) -> AudioStream:
	if not _cache.has(id):
		var path: String = SFX_DIR % id
		_cache[id] = load(path) as AudioStream if ResourceLoader.exists(path) else Synth.make(id)
	return _cache[id]


## Crossfades to a looping track (no-op if it is already playing).
func play_music(id: StringName) -> void:
	# Headless runs (CI / validation) use the dummy audio driver, which never releases
	# streaming playbacks at exit — skip music there.
	if id == music_id or DisplayServer.get_name() == "headless":
		return
	var path: String = BGM_DIR % id
	if not ResourceLoader.exists(path):
		return
	music_id = id
	var old: AudioStreamPlayer = _music[_music_index]
	_music_index = 1 - _music_index
	var new: AudioStreamPlayer = _music[_music_index]
	new.stream = load(path) as AudioStream
	new.volume_db = -40.0
	new.play()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(new, ^"volume_db", MUSIC_DB, FADE_S)
	_fade.tween_property(old, ^"volume_db", -80.0, FADE_S)
	_fade.chain().tween_callback(old.stop)


func _exit_tree() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null
	for m: AudioStreamPlayer in _music + _pool:
		m.stop()
		m.stream = null
	_cache.clear()


## Area music (region / Gate); bosses temporarily override it.
func set_area_music(id: StringName) -> void:
	_base_music = id
	play_music(id)


## Linear 0..1 volume for a bus by name.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))


func _play(id: StringName, bus: StringName) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(id, -1.0) < SFX_MIN_GAP_S:
		return
	_last_played[id] = now
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = get_stream(id)
	player.bus = bus
	# Headless runs (validation, tests) use a dummy driver that keeps playbacks alive at exit.
	if DisplayServer.get_name() != "headless":
		player.play()


func _hook_events() -> void:
	EventBus.player_attack_started.connect(func() -> void: play_sfx(&"swing"))
	EventBus.player_dodge_started.connect(func() -> void: play_sfx(&"dodge"))
	EventBus.damage_number_requested.connect(func(_p: Vector3, _a: int, crit: bool, _e: int, on_player: bool) -> void:
		play_sfx(&"hurt" if on_player else (&"crit" if crit else &"hit")))
	EventBus.enemy_killed.connect(func(_id: StringName, _p: Vector3) -> void: play_sfx(&"enemy_death"))
	EventBus.item_picked.connect(func(_id: StringName, _n: int) -> void: play_ui(&"pickup"))
	EventBus.skill_used.connect(func(_id: StringName) -> void: play_sfx(&"skill"))
	EventBus.gate_cleared.connect(func(_id: StringName) -> void: play_ui(&"fanfare"))
	EventBus.boss_started.connect(func(_b: Node3D) -> void: play_music(&"boss"))
	EventBus.boss_ended.connect(func(_b: Node3D, _won: bool) -> void:
		if _base_music != &"":
			play_music(_base_music))

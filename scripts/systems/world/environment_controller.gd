class_name EnvironmentController
extends Node
## Graybox day/night + weather presentation: sun angle/energy, sky/ambient brightness,
## fog density, rain particles following the camera, storm flashes.

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
@export var rain: GPUParticles3D
@export var day_sun_energy: float = 1.0
@export var night_sun_energy: float = 0.28
@export var day_ambient: float = 1.0
@export var night_ambient: float = 0.62
@export var clear_fog: float = 0.004
@export var fog_fog: float = 0.04
@export var rain_fog: float = 0.012
@export var storm_flash_interval_s: float = 6.0
@export var day_fog_color: Color = Color(0.6, 0.68, 0.8)
@export var night_fog_color: Color = Color(0.08, 0.07, 0.16)

var _flash_timer: float = 0.0
var _sky: ShaderMaterial = null
var _cloud: float = 0.35

const DUSK_SUN: Color = Color(1.0, 0.58, 0.34)
const DUSK_SUN_ENERGY: float = 0.75
const DUSK_AMBIENT: float = 1.0
const DUSK_FOG: Color = Color(0.5, 0.33, 0.48)
const DAY_AMBIENT_COLOR: Color = Color(0.42, 0.45, 0.52)
const DUSK_AMBIENT_COLOR: Color = Color(0.5, 0.38, 0.55)
const NIGHT_AMBIENT_COLOR: Color = Color(0.3, 0.32, 0.55)
const SKY_SHADER: Shader = preload("res://assets/shaders/sky_dynamic.gdshader")


func _ready() -> void:
	# Rain keeps falling while a dialog / panel pauses the game.
	if rain != null:
		rain.process_mode = Node.PROCESS_MODE_ALWAYS
	var env: Environment = world_environment.environment if world_environment != null else null
	if env == null:
		return
	# PC: contact shadows and soft occlusion in corners (Genshin-like depth); phones skip.
	if Settings.wants_ssao():
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.6
		env.glow_enabled = true
		env.glow_intensity = maxf(env.glow_intensity, 0.35)
		env.glow_hdr_threshold = 1.1
	# Dynamic sky built from the region's procedural sky colours.
	if env.sky != null:
		var old: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
		_sky = ShaderMaterial.new()
		_sky.shader = SKY_SHADER
		if old != null:
			_sky.set_shader_parameter(&"top_color", old.sky_top_color)
			_sky.set_shader_parameter(&"horizon_color", old.sky_horizon_color)
		env.sky.sky_material = _sky
	var high: bool = Settings.preset >= QualityPresets.Preset.PC_MEDIUM
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.glow_enabled = Settings.preset != QualityPresets.Preset.ANDROID_LOW
	env.glow_intensity = 0.4
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.04
	env.adjustment_contrast = 1.1
	env.ssao_enabled = high and not OS.has_feature("mobile")


func _process(delta: float) -> void:
	var clock: WorldClock = GameState.clock
	var elevation: float = sin((clock.day_fraction() - 0.25) * TAU)
	var daylight: float = clampf(elevation * 1.5 + 0.2, 0.0, 1.0)
	# Sunrise / sunset band: warm sun, orange-violet sky, purple haze (not pitch black).
	var dusk: float = clampf(1.0 - absf(elevation) * 3.2, 0.0, 1.0)
	if sun != null:
		sun.rotation = Vector3(deg_to_rad(-15.0 - 60.0 * maxf(elevation, 0.0)), clock.day_fraction() * TAU, 0.0)
		sun.light_energy = lerpf(night_sun_energy, day_sun_energy, daylight)
		# Moonlight is cool and blue, sunlight warm.
		sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.96, 0.9), daylight).lerp(DUSK_SUN, dusk * 0.85)
		sun.light_energy = maxf(sun.light_energy, DUSK_SUN_ENERGY * dusk)
	var env: Environment = world_environment.environment if world_environment != null else null
	var weather: StringName = GameState.weather.current
	if env != null:
		env.background_energy_multiplier = lerpf(night_ambient, day_ambient, daylight)
		env.ambient_light_energy = maxf(lerpf(night_ambient, day_ambient, daylight), DUSK_AMBIENT * dusk)
		# Ambient from a colour (sky radiance went black in shadows at dusk / night).
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = NIGHT_AMBIENT_COLOR.lerp(DAY_AMBIENT_COLOR, daylight).lerp(DUSK_AMBIENT_COLOR, dusk * 0.7)
		env.fog_light_color = night_fog_color.lerp(day_fog_color, daylight).lerp(DUSK_FOG, dusk * 0.8)
		env.fog_sky_affect = 1.0 - daylight * 0.5
		var fog_target: float = clear_fog
		if weather == WeatherSystem.FOG:
			fog_target = fog_fog
		elif GameState.weather.is_wet():
			fog_target = rain_fog
		env.fog_density = lerpf(env.fog_density, fog_target, 1.0 - exp(-delta))
		if _sky != null:
			var cloud_target: float = 0.3
			if weather == WeatherSystem.FOG:
				cloud_target = 0.6
			elif GameState.weather.is_wet():
				cloud_target = 0.85
			_cloud = lerpf(_cloud, cloud_target, 1.0 - exp(-delta * 0.5))
			_sky.set_shader_parameter(&"daylight", daylight)
			_sky.set_shader_parameter(&"dusk", dusk)
			WorldStreamer.set_night(1.0 - daylight)
			_sky.set_shader_parameter(&"cloud_cover", _cloud)
	_update_rain(weather, delta)


func _update_rain(weather: StringName, delta: float) -> void:
	if rain == null:
		return
	var wet: bool = GameState.weather.is_wet()
	rain.emitting = wet
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		rain.global_position = camera.global_position + Vector3.UP * 8.0
	if weather == WeatherSystem.STORM and sun != null:
		_flash_timer += delta
		if _flash_timer >= storm_flash_interval_s:
			_flash_timer = 0.0
			sun.light_energy = 3.0

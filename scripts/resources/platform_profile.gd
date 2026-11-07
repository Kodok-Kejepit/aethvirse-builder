class_name PlatformProfile
extends Resource
## Quality preset data. Platform differences live here, never in duplicated scenes.

enum ShadowQuality { OFF, LOW, MEDIUM, HIGH }

@export var display_name: String = ""
@export var target_fps: int = 60
@export_range(0.5, 2.0, 0.05) var render_scale: float = 1.0
@export var shadow_quality: ShadowQuality = ShadowQuality.MEDIUM
@export_range(0.0, 1.0, 0.05) var foliage_density: float = 1.0
@export var view_distance_m: float = 600.0
@export var chunk_load_radius: int = 2
@export var contact_shadows: bool = false
@export var volumetric_fog: bool = false
@export var ssr: bool = false
@export var global_illumination: bool = false

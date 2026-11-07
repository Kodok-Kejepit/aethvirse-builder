class_name QualityPresets
extends RefCounted
## Quality preset ids, profile lookup and platform-based default detection (pure, testable).

enum Preset { ANDROID_LOW, ANDROID_MID, PC_LOW, PC_MEDIUM, PC_HIGH, PC_ULTRA }

const PROFILE_PATHS: Dictionary[Preset, String] = {
	Preset.ANDROID_LOW: "res://data/platform_profiles/android_low.tres",
	Preset.ANDROID_MID: "res://data/platform_profiles/android_mid.tres",
	Preset.PC_LOW: "res://data/platform_profiles/pc_low.tres",
	Preset.PC_MEDIUM: "res://data/platform_profiles/pc_medium.tres",
	Preset.PC_HIGH: "res://data/platform_profiles/pc_high.tres",
	Preset.PC_ULTRA: "res://data/platform_profiles/pc_ultra.tres",
}
## Devices with less RAM than this fall back to the Android Low preset.
const ANDROID_LOW_RAM_BYTES: int = 6 * 1024 * 1024 * 1024
## Machines with less RAM than this (e.g. owner's 8 GB iGPU laptop) default to PC Low.
const PC_LOW_RAM_BYTES: int = 12 * 1024 * 1024 * 1024


## physical_ram_bytes <= 0 means "unknown".
static func detect_default(mobile: bool, physical_ram_bytes: int) -> Preset:
	if mobile:
		if physical_ram_bytes > 0 and physical_ram_bytes < ANDROID_LOW_RAM_BYTES:
			return Preset.ANDROID_LOW
		return Preset.ANDROID_MID
	if physical_ram_bytes > 0 and physical_ram_bytes < PC_LOW_RAM_BYTES:
		return Preset.PC_LOW
	return Preset.PC_MEDIUM


static func load_profile(preset: Preset) -> PlatformProfile:
	return load(PROFILE_PATHS[preset]) as PlatformProfile

extends GutTest

const GB: int = 1024 * 1024 * 1024
const P := QualityPresets.Preset


func test_mobile_low_ram_uses_android_low() -> void:
	assert_eq(QualityPresets.detect_default(true, 4 * GB), P.ANDROID_LOW)


func test_mobile_enough_ram_uses_android_mid() -> void:
	assert_eq(QualityPresets.detect_default(true, 8 * GB), P.ANDROID_MID)


func test_mobile_unknown_ram_uses_android_mid() -> void:
	assert_eq(QualityPresets.detect_default(true, 0), P.ANDROID_MID)


func test_pc_8gb_laptop_uses_pc_low() -> void:
	assert_eq(QualityPresets.detect_default(false, 8 * GB), P.PC_LOW)


func test_pc_16gb_uses_pc_medium() -> void:
	assert_eq(QualityPresets.detect_default(false, 16 * GB), P.PC_MEDIUM)


func test_every_preset_has_a_valid_profile() -> void:
	for preset: P in P.values():
		var profile: PlatformProfile = QualityPresets.load_profile(preset)
		assert_not_null(profile, "profile for preset %d" % preset)
		if profile != null:
			assert_gt(profile.render_scale, 0.0)
			assert_ne(profile.display_name, "")


func test_android_profiles_are_lighter_than_pc_high() -> void:
	var high: PlatformProfile = QualityPresets.load_profile(P.PC_HIGH)
	for preset: P in [P.ANDROID_LOW, P.ANDROID_MID]:
		var mobile: PlatformProfile = QualityPresets.load_profile(preset)
		assert_lt(mobile.foliage_density, high.foliage_density)
		assert_lt(mobile.view_distance_m, high.view_distance_m)


func test_settings_autoload_applied_a_profile() -> void:
	assert_not_null(Settings.profile)

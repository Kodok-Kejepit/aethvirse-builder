extends GutTest

const E := Element.Type


func test_natural_cycle_strong() -> void:
	assert_eq(Element.multiplier(E.FIRE, E.ICE), 1.5)
	assert_eq(Element.multiplier(E.ICE, E.WIND), 1.5)
	assert_eq(Element.multiplier(E.WIND, E.EARTH), 1.5)
	assert_eq(Element.multiplier(E.EARTH, E.LIGHTNING), 1.5)
	assert_eq(Element.multiplier(E.LIGHTNING, E.FIRE), 1.5)


func test_natural_cycle_weak() -> void:
	assert_eq(Element.multiplier(E.ICE, E.FIRE), 0.75)
	assert_eq(Element.multiplier(E.FIRE, E.LIGHTNING), 0.75)
	assert_eq(Element.multiplier(E.LIGHTNING, E.EARTH), 0.75)


func test_unrelated_natural_is_neutral() -> void:
	assert_eq(Element.multiplier(E.FIRE, E.WIND), 1.0)
	assert_eq(Element.multiplier(E.FIRE, E.EARTH), 1.0)


func test_same_element_resists_except_physical() -> void:
	assert_eq(Element.multiplier(E.FIRE, E.FIRE), 0.75)
	assert_eq(Element.multiplier(E.SHADOW, E.SHADOW), 0.75)
	assert_eq(Element.multiplier(E.PHYSICAL, E.PHYSICAL), 1.0)


func test_shadow_light_both_strong() -> void:
	assert_eq(Element.multiplier(E.SHADOW, E.LIGHT), 1.5)
	assert_eq(Element.multiplier(E.LIGHT, E.SHADOW), 1.5)


func test_physical_is_neutral() -> void:
	assert_eq(Element.multiplier(E.PHYSICAL, E.FIRE), 1.0)
	assert_eq(Element.multiplier(E.FIRE, E.PHYSICAL), 1.0)


func test_void() -> void:
	assert_eq(Element.multiplier(E.VOID, E.FIRE), 1.25)
	assert_eq(Element.multiplier(E.VOID, E.PHYSICAL), 1.25)
	assert_eq(Element.multiplier(E.VOID, E.VOID), 0.5)
	assert_eq(Element.multiplier(E.FIRE, E.VOID), 1.0)

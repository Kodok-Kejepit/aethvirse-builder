extends GutTest
## Animated hero rig (owner's Mixamo animations): loading, hair springs, pose -> clip
## mapping and joints following the animated bones.

var _model: CharacterModel


func before_each() -> void:
	_model = CharacterModel.new()
	add_child_autofree(_model)
	_model.setup(null, CharacterRig.Weapon.SWORD, true, HeroData.load_hero(&"dragon_maiden"), 0)


func test_dragon_maiden_uses_the_animated_rig() -> void:
	assert_true(HeroData.load_hero(&"dragon_maiden").has_rig())
	assert_not_null(_model.animated)
	assert_eq(_model.rig.joints.size(), CharacterRig.JOINTS.size())
	assert_not_null(_model.rig.weapon_tip)


func test_hair_has_spring_chains_off_the_head() -> void:
	var springs: SpringBoneSimulator3D = _model.animated.springs
	assert_not_null(springs)
	assert_gt(springs.get_setting_count(), 4, "hair split into several chains")
	var skel: Skeleton3D = _model.animated.skeleton
	var root: int = skel.find_bone(springs.get_root_bone_name(0))
	assert_eq(skel.get_bone_name(skel.get_bone_parent(root)), "mixamorig_Head", "chains hang from the head")


func test_poses_pick_clips() -> void:
	var body: AnimatedBody = _model.animated
	body.drive(&"walk", 0, 0.0, 1.6, 0.016)
	assert_eq(body.animation.current_animation, AnimatedBody.ANIM_WALK)
	body.drive(&"sprint", 0, 0.0, 7.0, 0.016)
	assert_eq(body.animation.current_animation, AnimatedBody.ANIM_SPRINT)
	body.drive(&"attack", 1, 0.5, 0.0, 0.016)
	assert_eq(body.animation.current_animation, AnimatedBody.ANIM_COMBO)
	var seg: Vector2 = AnimatedBody.COMBO_SEGMENTS[1]
	assert_almost_eq(body.animation.current_animation_position, lerpf(seg.x, seg.y, 0.5), 0.02)
	body.drive(&"fall", 0, 1.0, 0.0, 0.016)
	assert_eq(body.animation.current_animation, AnimatedBody.ANIM_JUMP)


func test_finished_one_shot_keeps_holding() -> void:
	var body: AnimatedBody = _model.animated
	for i: int in 30:
		body.drive(&"cast", 3, 2.0, 0.0, 0.1)
	assert_eq(body.animation.current_animation, AnimatedBody.ANIM_COMBO, "clip still active at its end")


func test_hand_joint_follows_the_animated_hand() -> void:
	var body: AnimatedBody = _model.animated
	body.drive(&"attack", 2, 0.5, 0.0, 0.016)
	body.sync_to_rig()
	var skel: Skeleton3D = body.skeleton
	var bone: int = skel.find_bone("mixamorig_RightHand")
	var expected: Vector3 = (skel.global_transform * skel.get_bone_global_pose(bone)).origin
	assert_almost_eq(_model.rig.joints[&"hand_r"].global_position.distance_to(expected), 0.0, 0.001)

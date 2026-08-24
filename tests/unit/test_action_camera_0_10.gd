extends RefCounted


func run() -> bool:
	var rig := CameraController3D.new()
	var yaw := Node3D.new()
	yaw.name = "YawPivot"
	var pitch := Node3D.new()
	pitch.name = "PitchPivot"
	var spring := SpringArm3D.new()
	spring.name = "ThirdPersonSpringArm"
	var anchor := Marker3D.new()
	anchor.name = "FirstPersonAnchor"
	anchor.position = Vector3(0.0, 1.55, 0.0)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(yaw)
	yaw.add_child(pitch)
	pitch.add_child(spring)
	pitch.add_child(anchor)
	pitch.add_child(camera)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(rig)
	await tree.process_frame
	rig.set_look_angles(4.0, 10.0)
	var angles := rig.get_look_angles()
	var ok := angles.x <= PI and angles.x >= -PI
	ok = ok and angles.y <= CameraController3D.MAX_PITCH and angles.y >= CameraController3D.MIN_PITCH
	rig.set_sensitivity(99.0)
	ok = ok and is_equal_approx(rig.look_sensitivity, CameraController3D.MAX_SENSITIVITY)
	var hud_focus := Button.new()
	hud_focus.name = "RetainedHudFocus"
	tree.root.add_child(hud_focus)
	hud_focus.grab_focus()
	await tree.process_frame
	ok = ok and tree.root.gui_get_focus_owner() == hud_focus
	ok = ok and not rig._is_ui_owned()
	tree.paused = true
	ok = ok and rig._is_ui_owned()
	tree.paused = false
	ok = ok and rig.get_perspective() == CameraController3D.PerspectiveMode.THIRD_PERSON
	rig.toggle_perspective()
	ok = ok and rig.get_perspective() == CameraController3D.PerspectiveMode.FIRST_PERSON
	ok = ok and is_equal_approx(camera.fov, rig.first_person_fov)
	hud_focus.free()
	rig.free()
	return ok

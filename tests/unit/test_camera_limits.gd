extends RefCounted


func run() -> bool:
	var world := Vector2(3840, 2400)
	var ok := true

	var small := CameraLimits.calculate_camera_limits(world, Vector2(1280, 720))
	ok = ok and small.position == Vector2i(0, 0)
	ok = ok and small.size == Vector2i(3840, 2400)

	var wide := CameraLimits.calculate_camera_limits(world, Vector2(5000, 720))
	ok = ok and wide.position.x == int((world.x - 5000) * 0.5)
	ok = ok and wide.size.x == 5000

	var tall := CameraLimits.calculate_camera_limits(world, Vector2(1280, 3000))
	ok = ok and tall.size.y == 3000

	var huge := CameraLimits.calculate_camera_limits(world, Vector2(5000, 3000))
	ok = ok and huge.size.x == 5000
	ok = ok and huge.size.y == 3000

	var again := CameraLimits.calculate_camera_limits(world, Vector2(1280, 720))
	ok = ok and again == small

	if not ok:
		push_error("Camera limits assertions failed")
	return ok

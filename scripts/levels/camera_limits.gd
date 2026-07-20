class_name CameraLimits
extends RefCounted
## Pure camera limit math for world bounds and viewport size.


static func calculate_camera_limits(
	world_size: Vector2,
	viewport_size: Vector2,
) -> Rect2i:
	var left := 0
	var top := 0
	var right := int(world_size.x)
	var bottom := int(world_size.y)
	if viewport_size.x >= world_size.x:
		left = int((world_size.x - viewport_size.x) * 0.5)
		right = int(left + viewport_size.x)
	if viewport_size.y >= world_size.y:
		top = int((world_size.y - viewport_size.y) * 0.5)
		bottom = int(top + viewport_size.y)
	return Rect2i(left, top, right - left, bottom - top)

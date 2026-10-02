extends SceneTree
const Flight = preload("res://addons/live_editor_camera/flight.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1

func _initialize() -> void:
	var flight = Flight.new()
	flight.move(Vector3(0, 0, -1), 1.0, false)
	check(flight.pose.origin.is_equal_approx(Vector3(0, 0, -80)), "W travels along camera forward")
	flight.pose = Transform3D.IDENTITY
	flight.move(Vector3(1, 0, -1), 1.0, false)
	check(is_equal_approx(flight.pose.origin.length(), 80.0), "diagonal flight does not accelerate")
	flight.pose = Transform3D.IDENTITY
	flight.move(Vector3.UP, 1.0, true)
	check(flight.pose.origin.is_equal_approx(Vector3(0, 320, 0)), "Shift accelerates vertical flight")
	flight.pose = Transform3D.IDENTITY
	flight.look(Vector2(100, 100000))
	check(absf(flight.pose.basis.get_euler().x) <= 1.501, "mouse look clamps pitch")
	check(is_equal_approx(flight.pose.basis.determinant(), 1.0), "mouse look preserves orthonormal camera basis")
	flight.pose = Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	flight.move(Vector3(0, 0, -1), 1.0, false)
	check(flight.pose.origin.is_equal_approx(Vector3(-80, 0, 0)), "flight follows camera orientation")
	var racer := Node3D.new()
	root.add_child(racer)
	racer.position = Vector3(200, 3, 50)
	flight.frame_racer(racer)
	var direction := (racer.global_position + Vector3.UP * 2.0 - flight.pose.origin).normalized()
	check((-flight.pose.basis.z).is_equal_approx(direction), "racer framing points toward moving craft")
	racer.position.x += 100.0
	flight.frame_racer(racer)
	check(is_equal_approx(flight.pose.origin.x, 300.0), "follow pose tracks racer movement")
	racer.free()
	quit(failures)

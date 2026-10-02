@tool
extends RefCounted

var pose := Transform3D.IDENTITY
var speed := 80.0

func look(relative: Vector2) -> void:
	var angles := pose.basis.get_euler()
	angles.y -= relative.x * 0.003
	angles.x = clampf(angles.x - relative.y * 0.003, -1.5, 1.5)
	pose.basis = Basis.from_euler(Vector3(angles.x, angles.y, 0.0))

func move(local_direction: Vector3, delta: float, fast: bool) -> void:
	if local_direction.length_squared() > 0.0:
		pose.origin += pose.basis * local_direction.normalized() * speed * (4.0 if fast else 1.0) * delta

func frame_racer(racer: Node3D) -> void:
	var target := racer.global_position + Vector3.UP * 2.0
	pose = Transform3D(Basis.IDENTITY, target + racer.global_basis.z * 24.0 + Vector3.UP * 12.0)
	pose = pose.looking_at(target, Vector3.UP)

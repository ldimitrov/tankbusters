extends Node2D
## A homing cannonball. Chases its target and applies damage on arrival.
## Drawn in code (a circle) — the asset pack has no projectile art.

var target: Tank
var damage := 0.0
var speed := 420.0


func _process(delta: float) -> void:
	# The target may have died (been freed) mid-flight. is_instance_valid is
	# the safe way to check — a freed object reference cannot be used at all.
	if not is_instance_valid(target):
		queue_free()
		return

	var aim := target.position + Vector2(0, -10)  # roughly turret-height on the tank
	var to_target := aim - position
	var step := speed * delta
	if to_target.length() <= step:
		target.take_damage(damage)
		queue_free()
		return
	position += to_target.normalized() * step


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color("2b2b33"))
	draw_circle(Vector2(-1.5, -1.5), 2.0, Color(1, 1, 1, 0.35))

class_name Turret
extends Node2D
## A cannon tower. Every frame it looks for the tank that is furthest along
## the road within range ("first" targeting — the classic TD default) and
## fires when its cooldown allows.

## @export makes these editable per-instance in the Inspector — later, turret
## tiers will just be different values for these numbers.
@export var fire_range := 175.0  # radius in ground units, not screen pixels
@export var fire_interval := 0.9
@export var damage := 34.0

const CANNONBALL_SCENE := preload("res://scenes/turrets/cannonball.tscn")
## Where cannonballs appear, relative to the tower base (top of the tower).
const MUZZLE_OFFSET := Vector2(0, -58)

var show_range := false:
	set(value):
		show_range = value
		queue_redraw()

var _cooldown := 0.0


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _pick_target()
	if target != null:
		_shoot(target)
		_cooldown = fire_interval


func _pick_target() -> Tank:
	var best: Tank = null
	for node in get_tree().get_nodes_in_group("tanks"):
		var tank := node as Tank
		# Range is a circle on the GROUND, which the camera sees as an ellipse,
		# so measure the un-projected distance instead of the on-screen one.
		var offset := Iso.screen_to_ground(tank.global_position - global_position)
		if offset.length() > fire_range:
			continue
		if best == null or tank.progress > best.progress:
			best = tank
	return best


func _shoot(target: Tank) -> void:
	var ball := CANNONBALL_SCENE.instantiate()
	ball.target = target
	ball.damage = damage
	ball.position = position + MUZZLE_OFFSET
	# Sibling, not child: the ball must keep flying if this turret is removed,
	# and it lives in the same Y-sorted layer as tanks and turrets.
	add_sibling(ball)


## The range indicator: a ground circle, projected to the iso ellipse.
func _draw() -> void:
	if not show_range:
		return
	var points := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		points.append(Iso.ground_to_screen(Vector2.from_angle(angle) * fire_range))
	draw_colored_polygon(points, Color(1, 1, 1, 0.08))
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, 0.4), 1.5, true)

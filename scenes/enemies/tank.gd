class_name Tank
extends Node2D
## An enemy tank. It is NOT a physics body: tower-defense enemies never collide
## with anything, they just follow the road — so a plain Node2D moved by math
## is the right (and cheapest) tool. The road is a Curve2D handed over by the
## spawner; `sample_baked(distance)` gives us the point that far along it.

signal died(bounty: int, at: Vector2)
signal reached_base

@export var speed := 90.0
@export var max_hp := 100.0
@export var bounty := 15

var path: Curve2D
## Distance travelled along the curve, in pixels. Turrets read this to decide
## which tank is "first" (furthest along the road).
var progress := 0.0
var hp := 0.0
# Frost effect: speed is multiplied by (1 - _slow_factor) while time remains.
var _slow_factor := 0.0
var _slow_time_left := 0.0

const SLOW_TINT := Color(0.55, 1.05, 1.75)

## @onready defers the assignment until the node enters the tree, when
## children exist. $Body is shorthand for get_node("Body").
@onready var body: Node2D = $Body


func _ready() -> void:
	hp = max_hp
	# Groups are Godot's cheap global tagging: turrets ask the scene tree for
	# every node in group "tanks" instead of keeping fragile lists.
	add_to_group("tanks")
	position = path.sample_baked(0.0)


func _process(delta: float) -> void:
	if _slow_time_left > 0.0:
		_slow_time_left -= delta
		if _slow_time_left <= 0.0:
			_slow_factor = 0.0
			body.modulate = Color.WHITE

	progress += speed * (1.0 - _slow_factor) * delta
	if progress >= path.get_baked_length():
		reached_base.emit()
		queue_free()
		return

	var previous := position
	position = path.sample_baked(progress)

	# Turn the drawn body toward the direction we actually moved. The movement
	# happens on screen, so un-project it back into ground-plane coordinates.
	var step := position - previous
	if step.length_squared() > 0.01:
		body.heading = Iso.screen_to_ground(step).angle()


## Frost turrets call this repeatedly while a tank is inside their aura.
## Stronger slows win; the effect wears off `duration` seconds after leaving.
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = maxf(_slow_factor, factor)
	_slow_time_left = maxf(_slow_time_left, duration)
	body.modulate = SLOW_TINT


func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		died.emit(bounty, position)
		queue_free()


## Health bar, only shown once damaged.
func _draw() -> void:
	if hp >= max_hp or hp <= 0.0:
		return
	var width := 36.0
	draw_rect(Rect2(-width / 2, -38, width, 5), Color(0, 0, 0, 0.55))
	var ratio := hp / max_hp
	var fill := Color("7ec850").lerp(Color("d84b4b"), 1.0 - ratio)
	draw_rect(Rect2(-width / 2 + 1, -37, (width - 2) * ratio, 3), fill)

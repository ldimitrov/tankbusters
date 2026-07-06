extends Area2D
## A clickable pad where a turret may be built. Area2D is Godot's "invisible
## interactive region": its CollisionPolygon2D (a diamond matching the tile
## top) gives us mouse_entered / mouse_exited / input_event signals for free.
##
## Note it does NOT build the turret itself — it just asks. Main decides,
## because Main owns the money check and the scene layers. Keeping nodes
## ignorant of their surroundings ("signal up, call down") is the core Godot
## architecture habit.

signal build_requested(spot: Area2D)

var turret: Turret = null
var _hovered := false


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


func _set_hovered(state: bool) -> void:
	_hovered = state
	queue_redraw()
	# Once built, hovering the pad shows the turret's range ellipse.
	if turret != null:
		turret.show_range = state


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and turret == null:
		build_requested.emit(self)


## Brief red flash when the player can't afford the turret.
func flash_denied() -> void:
	modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.35)


func _draw() -> void:
	if turret != null:
		return
	var diamond := PackedVector2Array([
		Vector2(0, -26), Vector2(52, 0), Vector2(0, 26), Vector2(-52, 0),
	])
	draw_colored_polygon(diamond, Color(1, 1, 1, 0.22 if _hovered else 0.10))
	diamond.append(diamond[0])
	draw_polyline(diamond, Color(1, 1, 1, 0.55), 2.0, true)

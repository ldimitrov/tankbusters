class_name Turret
extends Node2D
## A tower driven entirely by a TurretData resource: which family it is and
## which tier it has reached decide its sprite and stats. Two behaviors:
## shooting (damage > 0, fires cannonballs at the "first" tank in range) and
## frost aura (slow_factor > 0, slows every tank inside the range ellipse).

const CANNONBALL_SCENE := preload("res://scenes/turrets/cannonball.tscn")
## How often the aura re-applies its slow; the effect outlives it slightly.
const AURA_TICK := 0.2
const SELL_RATIO := 0.7

var data: TurretData
var tier_index := 0
## Total gold spent on this turret (build + upgrades) — basis for sell value.
var invested := 0

var show_range := false:
	set(value):
		show_range = value
		queue_redraw()

var _cooldown := 0.0
var _muzzle := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	invested += tier().cost
	_apply_tier()


func tier() -> TurretTier:
	return data.tiers[tier_index]


func can_upgrade() -> bool:
	return tier_index < data.tiers.size() - 1


func upgrade_cost() -> int:
	return data.tiers[tier_index + 1].cost


func sell_value() -> int:
	return int(invested * SELL_RATIO)


func upgrade() -> void:
	tier_index += 1
	invested += tier().cost
	_apply_tier()


## Swap in the tier's look and recompute where cannonballs spawn from.
func _apply_tier() -> void:
	sprite.texture = tier().texture
	sprite.modulate = tier().tint
	var height := float(tier().texture.get_height())
	# Anchor the sprite so its base sits on the tile no matter how tall it is.
	sprite.offset = Vector2(0, 16.0 - height / 2.0)
	_muzzle = Vector2(0, 16.0 - height * 0.8)
	queue_redraw()


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if tier().slow_factor > 0.0:
		for tank in _tanks_in_range():
			tank.apply_slow(tier().slow_factor, AURA_TICK + 0.25)
		_cooldown = AURA_TICK
	else:
		var target := _pick_target()
		if target != null:
			_shoot(target)
			_cooldown = tier().fire_interval


func _tanks_in_range() -> Array[Tank]:
	var result: Array[Tank] = []
	for node in get_tree().get_nodes_in_group("tanks"):
		var tank := node as Tank
		# Range is a circle on the GROUND, which the camera sees as an ellipse,
		# so measure the un-projected distance instead of the on-screen one.
		if Iso.screen_to_ground(tank.global_position - global_position).length() <= tier().fire_range:
			result.append(tank)
	return result


func _pick_target() -> Tank:
	var best: Tank = null
	for tank in _tanks_in_range():
		if best == null or tank.progress > best.progress:
			best = tank
	return best


func _shoot(target: Tank) -> void:
	var ball := CANNONBALL_SCENE.instantiate()
	ball.target = target
	ball.damage = tier().damage
	ball.position = position + _muzzle
	# Sibling, not child: the ball must keep flying if this turret is sold,
	# and it lives in the same Y-sorted layer as tanks and turrets.
	add_sibling(ball)


## The range indicator: a ground circle, projected to the iso ellipse.
func _draw() -> void:
	if not show_range:
		return
	var points := PackedVector2Array()
	for i in 48:
		var angle := TAU * i / 48.0
		points.append(Iso.ground_to_screen(Vector2.from_angle(angle) * tier().fire_range))
	var color := Color(0.6, 0.85, 1.0) if tier().slow_factor > 0.0 else Color.WHITE
	draw_colored_polygon(points, Color(color, 0.08))
	points.append(points[0])
	draw_polyline(points, Color(color, 0.4), 1.5, true)

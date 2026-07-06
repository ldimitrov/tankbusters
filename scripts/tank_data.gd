class_name TankData
extends Resource
## An enemy tank type. Same pattern as TurretData: stats live in .tres files
## (resources/tanks/), so new enemy types are data, not code. The code-drawn
## tank body recolors and rescales itself from this.

@export var display_name := "Tank"
@export var speed := 90.0
@export var max_hp := 100.0
@export var bounty := 15
## Hull color; the body shades sides/turret from it automatically.
@export var color := Color(0.42, 0.56, 0.31)
@export var body_scale := 1.0

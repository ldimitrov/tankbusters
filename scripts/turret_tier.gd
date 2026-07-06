class_name TurretTier
extends Resource
## One level of a turret. Resources are Godot's data files: instances of this
## script get saved as .tres text files you can edit in the Inspector (or by
## hand) — adding/balancing turrets never touches code again.

@export var cost := 40
@export var damage := 0.0
@export var fire_interval := 0.9
## Radius in ground units (the projected ellipse is drawn from it).
@export var fire_range := 160.0
## 0 = normal shooting turret. > 0 = aura turret: tanks in range are slowed
## to (1 - slow_factor) of their speed while inside.
@export var slow_factor := 0.0
@export var texture: Texture2D
## Sprite tint — lets one Kenney tower double as e.g. an icy variant.
@export var tint := Color.WHITE

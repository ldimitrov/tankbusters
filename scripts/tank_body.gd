extends Node2D
## Placeholder tank art, drawn entirely in code via Godot's _draw() API.
## The Kenney pack ships no enemy sprites, so we project a tiny 3D box model
## into the same 2:1 isometric view the tiles use — consistent style for free,
## and it can rotate to any heading (sprites would need one image per angle).

## Direction of travel in the ground plane, radians. The setter calls
## queue_redraw(), which asks Godot to run _draw() again on the next frame —
## canvas items are cached, they do NOT redraw automatically.
var heading := 0.0:
	set(value):
		heading = value
		queue_redraw()

# Model measurements in "ground units": (half-length, half-width, height).
const TRACKS := Vector3(26, 16, 5)
const BODY := Vector3(22, 12, 8)
const TURRET := Vector3(10, 8, 8)
const BARREL_LENGTH := 28.0

## Hull color; the shades for sides and turret derive from it, so recoloring
## a whole tank type is a single value in its TankData resource.
var base_color := Color("6a8f4f"):
	set(value):
		base_color = value
		queue_redraw()

const C_BARREL := Color("39462f")
# Light comes from the upper-left, matching the Kenney tiles.
const LIGHT_DIR := Vector2(-0.6, -0.8)


## Rotate a model-space ground point by heading, then squash to isometric.
## z is height above the ground: on screen that's simply "up" (minus y).
func _project(u: float, v: float, z: float) -> Vector2:
	var g := Vector2(u, v).rotated(heading)
	return Vector2(g.x - g.y, (g.x + g.y) * 0.5 - z)


func _draw() -> void:
	# Soft shadow diamond under the tank.
	var shadow := PackedVector2Array()
	for corner in [Vector2(28, 19), Vector2(28, -19), Vector2(-28, -19), Vector2(-28, 19)]:
		shadow.append(_project(corner.x, corner.y, -1.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.18))

	_draw_box(TRACKS, 0.0, base_color.darkened(0.5), base_color.darkened(0.62))
	_draw_box(BODY, TRACKS.z, base_color, base_color.darkened(0.22))
	_draw_box(TURRET, TRACKS.z + BODY.z, base_color.lightened(0.12), base_color.darkened(0.1))
	# Barrel: a thick line from the turret front, slightly above turret mid-height.
	var barrel_z := TRACKS.z + BODY.z + TURRET.z * 0.6
	draw_line(
		_project(TURRET.x, 0, barrel_z),
		_project(TURRET.x + BARREL_LENGTH, 0, barrel_z + 1.5),
		C_BARREL, 3.5)


## Draws one box: four side faces painted back-to-front, then the top face.
func _draw_box(size: Vector3, base_z: float, top_color: Color, side_color: Color) -> void:
	var corners := [
		Vector2(size.x, size.y), Vector2(size.x, -size.y),
		Vector2(-size.x, -size.y), Vector2(-size.x, size.y),
	]
	var faces := []
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var mid := ((a + b) * 0.5).rotated(heading)
		# Depth in iso: larger (ground x + ground y) means closer to the camera.
		faces.append({"depth": mid.x + mid.y, "a": a, "b": b})
	faces.sort_custom(func(f1, f2): return f1.depth < f2.depth)

	for f in faces:
		var quad := PackedVector2Array([
			_project(f.a.x, f.a.y, base_z),
			_project(f.b.x, f.b.y, base_z),
			_project(f.b.x, f.b.y, base_z + size.z),
			_project(f.a.x, f.a.y, base_z + size.z),
		])
		# Fake lighting: shade each face by how much it points at the light.
		var normal: Vector2 = (f.b - f.a).rotated(heading + PI / 2).normalized()
		var lit := 0.55 + 0.45 * clampf(normal.dot(LIGHT_DIR), 0.0, 1.0)
		draw_colored_polygon(quad, side_color.darkened(1.0 - lit))

	var top := PackedVector2Array()
	for c in corners:
		top.append(_project(c.x, c.y, base_z + size.z))
	draw_colored_polygon(top, top_color)

class_name Iso
## Isometric grid math, in one place. `class_name` registers "Iso" globally,
## so any script can call Iso.cell_to_world(...) without preloading anything.
##
## Kenney's tiles are 132x99 px: the walkable top surface is a 132x66 diamond,
## the remaining 33 px below are the block's visible side. Moving one grid cell
## therefore shifts a sprite by (+-66, +33) on screen — the classic 2:1 iso.

const TILE_SIZE := Vector2(132, 99)
const HALF_W := 66.0
const HALF_H := 33.0
## Where the center of the top diamond sits inside the tile sprite.
const TOP_CENTER := Vector2(66, 33)


## Grid cell -> world position of the center of that tile's top surface.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * HALF_W, (cell.x + cell.y) * HALF_H)


## A vector in the flat "ground plane" -> its on-screen (projected) vector.
## Ground +X runs toward the lower-right tile edge, ground +Y toward lower-left.
static func ground_to_screen(g: Vector2) -> Vector2:
	return Vector2(g.x - g.y, (g.x + g.y) * 0.5)


## Inverse projection: an on-screen vector -> the ground-plane vector.
static func screen_to_ground(s: Vector2) -> Vector2:
	return Vector2(s.y + s.x * 0.5, s.y - s.x * 0.5)

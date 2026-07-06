extends Node2D
## The level. Builds the isometric map from data, owns the enemy road curve,
## spawns waves, and reacts to game events. For milestone 1 the map and wave
## live here as constants; later milestones move them into Resource files so
## new levels/waves are data, not code.

const TANK_SCENE := preload("res://scenes/enemies/tank.tscn")
const TURRET_SCENE := preload("res://scenes/turrets/turret.tscn")
const BUILD_SPOT_SCENE := preload("res://scenes/turrets/build_spot.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/explosion.tscn")

const TILE_DIR := "res://assets/kenney/PNG/Landscape/"
const DETAIL_DIR := "res://assets/kenney/PNG/Details/"

const GRASS_TILE := "landscape_28.png"
## The two straight road pieces, one per screen diagonal.
const ROAD_WE := "landscape_32.png"  # connects the cell's West and East edges
const ROAD_NS := "landscape_29.png"
## Turn pieces, keyed by which two cell edges the road connects. The grass arc
## in each tile marks the INNER corner, so the road joins the other two edges.
const ROAD_TURNS := {
	"NE": "landscape_02.png",
	"ES": "landscape_38.png",
	"NW": "landscape_07.png",
	"SW": "landscape_03.png",
}

const GRID := Vector2i(12, 8)
## The road, cell by cell, entrance to exit.
const PATH_CELLS: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5),
	Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
	Vector2i(7, 4), Vector2i(7, 3), Vector2i(7, 2),
	Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 2), Vector2i(11, 2),
]
const BUILD_CELLS: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(2, 3), Vector2i(5, 3),
	Vector2i(6, 4), Vector2i(8, 3), Vector2i(9, 1),
]
const DECOR := {
	Vector2i(1, 0): "trees_4.png",
	Vector2i(6, 1): "trees_1.png",
	Vector2i(10, 0): "trees_2.png",
	Vector2i(10, 4): "trees_7.png",
	Vector2i(9, 6): "trees_9.png",
	Vector2i(1, 5): "rocks_5.png",
	Vector2i(3, 6): "rocks_1.png",
	Vector2i(6, 3): "crystals_2.png",
}
## The HQ the tanks are trying to reach, next to the road exit.
const BASE_CELL := Vector2i(11, 1)

const TURRET_COST := 50
const WAVE_SIZE := 10
const SPAWN_INTERVAL := 1.1

@onready var world: Node2D = $World
@onready var ground: Node2D = $World/Ground
@onready var markers: Node2D = $World/Markers
@onready var enemy_path: Path2D = $World/EnemyPath
@onready var objects: Node2D = $World/Objects
@onready var hud: CanvasLayer = $HUD

var _wave_running := false
var _game_ended := false
var _tanks_remaining := 0


func _ready() -> void:
	GameState.reset()
	_center_world()
	_build_ground()
	_build_road_curve()
	_place_build_spots()
	_place_base()

	hud.start_wave_pressed.connect(start_wave)
	GameState.lives_changed.connect(_on_lives_changed)

	_handle_debug_args()


## ---------- Map construction ----------

## Position the World node so the map is centered in the window.
func _center_world() -> void:
	var bounds := Rect2(Iso.cell_to_world(Vector2i.ZERO), Vector2.ZERO)
	for y in GRID.y:
		for x in GRID.x:
			bounds = bounds.expand(Iso.cell_to_world(Vector2i(x, y)))
	bounds = bounds.grow_individual(Iso.HALF_W, Iso.HALF_H, Iso.HALF_W, Iso.TILE_SIZE.y - Iso.HALF_H)
	var view := get_viewport_rect().size
	# Shrink slightly if the map is larger than the window (uniform scale).
	var fit := minf(1.0, minf(view.x / bounds.size.x, (view.y - 60.0) / bounds.size.y))
	world.scale = Vector2(fit, fit)
	world.position = (view - bounds.size * fit) / 2.0 - bounds.position * fit + Vector2(0, 30.0)


func _build_ground() -> void:
	# Painter's algorithm: draw back rows first. In iso, "further back" simply
	# means a smaller (x + y), so sort all cells by that sum.
	var cells: Array[Vector2i] = []
	for y in GRID.y:
		for x in GRID.x:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))

	var road_tiles := _road_tile_map()
	for cell in cells:
		_add_tile(ground, TILE_DIR + road_tiles.get(cell, GRASS_TILE), cell)
		if DECOR.has(cell):
			# Decor sprites include their own tile block and stick up above it,
			# so they go in the Y-sorted Objects layer: tanks and towers that
			# are "in front" (lower on screen) must draw on top of them.
			_add_tile(objects, DETAIL_DIR + DECOR[cell], cell)


## One tile sprite, bottom-aligned so taller-than-standard art lines up.
func _add_tile(layer: Node2D, texture_path: String, cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.centered = false
	var extra_height := sprite.texture.get_height() - Iso.TILE_SIZE.y
	sprite.position = Iso.cell_to_world(cell) - Iso.TOP_CENTER - Vector2(0, extra_height)
	# Y-sort compares the node's own position, so anchor it to the tile center.
	if layer == objects:
		sprite.offset = sprite.position - Iso.cell_to_world(cell)
		sprite.position = Iso.cell_to_world(cell)
	layer.add_child(sprite)


## For every road cell, pick the tile matching which edges the road crosses.
func _road_tile_map() -> Dictionary:
	var result := {}
	for i in PATH_CELLS.size():
		var cell := PATH_CELLS[i]
		# Edges toward the previous and next path cell (map edge at the ends).
		var to_prev := PATH_CELLS[i - 1] - cell if i > 0 else Vector2i(-1, 0)
		var to_next := PATH_CELLS[i + 1] - cell if i < PATH_CELLS.size() - 1 else Vector2i(1, 0)
		var edges := [_edge_letter(to_prev), _edge_letter(to_next)]
		if "W" in edges and "E" in edges:
			result[cell] = ROAD_WE
		elif "N" in edges and "S" in edges:
			result[cell] = ROAD_NS
		else:
			edges.sort_custom(func(a, b): return "NESW".find(a) < "NESW".find(b))
			result[cell] = ROAD_TURNS[edges[0] + edges[1]]
	return result


func _edge_letter(dir: Vector2i) -> String:
	match dir:
		Vector2i(1, 0): return "E"
		Vector2i(-1, 0): return "W"
		Vector2i(0, 1): return "S"
		Vector2i(0, -1): return "N"
	push_error("Path cells must be adjacent, got step %s" % dir)
	return "?"


## Build the Curve2D the tanks drive along: through the midpoints of the cell
## borders, with bezier handles so corners are smooth arcs instead of kinks.
func _build_road_curve() -> void:
	var points: Array[Vector2] = []
	var first := Iso.cell_to_world(PATH_CELLS[0])
	var last := Iso.cell_to_world(PATH_CELLS[PATH_CELLS.size() - 1])
	points.append(first - Vector2(Iso.HALF_W, Iso.HALF_H) * 0.9)  # spawn at map edge
	for i in PATH_CELLS.size() - 1:
		points.append((Iso.cell_to_world(PATH_CELLS[i]) + Iso.cell_to_world(PATH_CELLS[i + 1])) / 2.0)
	points.append(last + Vector2(Iso.HALF_W, Iso.HALF_H) * 0.9)  # drive off-map

	var curve := Curve2D.new()
	for p in points:
		curve.add_point(p)
	for i in range(1, points.size() - 1):
		var handle := (points[i + 1] - points[i - 1]).normalized() * 22.0
		curve.set_point_in(i, -handle)
		curve.set_point_out(i, handle)
	enemy_path.curve = curve


func _place_build_spots() -> void:
	for cell in BUILD_CELLS:
		var spot := BUILD_SPOT_SCENE.instantiate()
		spot.position = Iso.cell_to_world(cell)
		spot.build_requested.connect(_on_build_requested)
		markers.add_child(spot)


func _place_base() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/kenney/PNG/Towers (grey)/tower_00.png")
	sprite.position = Iso.cell_to_world(BASE_CELL)
	sprite.offset = Vector2(0, -33)
	objects.add_child(sprite)


## ---------- Gameplay ----------

func _on_build_requested(spot: Area2D) -> void:
	if not GameState.spend(TURRET_COST):
		spot.flash_denied()
		return
	var turret := TURRET_SCENE.instantiate()
	turret.position = spot.position  # Markers and Objects share the same origin
	objects.add_child(turret)
	spot.turret = turret
	spot.queue_redraw()


func start_wave() -> void:
	if _wave_running or _game_ended:
		return
	_wave_running = true
	_tanks_remaining = WAVE_SIZE
	hud.set_start_enabled(false)
	hud.set_wave_text("Wave 1/1")
	for i in WAVE_SIZE:
		_spawn_tank()
		# await pauses THIS function (not the game) until the timer fires.
		await get_tree().create_timer(SPAWN_INTERVAL).timeout


func _spawn_tank() -> void:
	var tank := TANK_SCENE.instantiate()
	tank.path = enemy_path.curve
	tank.died.connect(_on_tank_died)
	tank.reached_base.connect(_on_tank_reached_base)
	objects.add_child(tank)


func _on_tank_died(bounty: int, at: Vector2) -> void:
	GameState.earn(bounty)
	var boom := EXPLOSION_SCENE.instantiate()
	boom.position = at + Vector2(0, -10)
	objects.add_child(boom)
	_on_tank_resolved()


func _on_tank_reached_base() -> void:
	GameState.lose_life()
	_on_tank_resolved()


func _on_tank_resolved() -> void:
	_tanks_remaining -= 1
	if _tanks_remaining <= 0 and not _game_ended:
		_end_game("Victory!")


func _on_lives_changed(lives: int) -> void:
	if lives <= 0 and not _game_ended:
		_end_game("Game Over")


func _end_game(message: String) -> void:
	_game_ended = true
	hud.show_end_screen(message)
	# Freeze the world; the HUD keeps working (process_mode = Always).
	get_tree().paused = true


## ---------- Development helpers ----------
## Custom args after "--" reach the game, e.g.:
##   Godot --path . -- --autobuild --autostart --screenshot=/tmp/shot.png --delay=5
func _handle_debug_args() -> void:
	var args := OS.get_cmdline_user_args()
	if "--autobuild" in args:
		GameState.earn(TURRET_COST * markers.get_child_count())
		for spot in markers.get_children():
			_on_build_requested(spot)
	if "--autostart" in args:
		start_wave()
	for arg in args:
		if arg.begins_with("--screenshot="):
			var delay := 1.0
			for a in args:
				if a.begins_with("--delay="):
					delay = float(a.trim_prefix("--delay="))
			_save_screenshot(arg.trim_prefix("--screenshot="), delay)


func _save_screenshot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

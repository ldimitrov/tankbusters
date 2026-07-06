extends Node2D
## The level. Generates a RANDOM map each game (path, build spots, decor),
## builds it from Kenney tiles, and runs the wave sequence defined in
## resources/waves/. Turret and tank stats live in resources too — this
## script is orchestration, not content.

const TANK_SCENE := preload("res://scenes/enemies/tank.tscn")
const TURRET_SCENE := preload("res://scenes/turrets/turret.tscn")
const BUILD_SPOT_SCENE := preload("res://scenes/turrets/build_spot.tscn")
const EXPLOSION_SCENE := preload("res://scenes/fx/explosion.tscn")

## The buildable turret families. Adding a third = one .tres + one line here.
const TURRET_TYPES := {
	"cannon": preload("res://resources/turrets/cannon.tres"),
	"frost": preload("res://resources/turrets/frost.tres"),
}

## The wave sequence, easiest to hardest.
const WAVES: Array = [
	preload("res://resources/waves/wave_1.tres"),
	preload("res://resources/waves/wave_2.tres"),
	preload("res://resources/waves/wave_3.tres"),
	preload("res://resources/waves/wave_4.tres"),
	preload("res://resources/waves/wave_5.tres"),
]

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
const DECOR_TEXTURES := [
	"trees_1.png", "trees_2.png", "trees_4.png", "trees_7.png", "trees_9.png",
	"rocks_1.png", "rocks_5.png", "crystals_2.png",
]

const GRID := Vector2i(12, 8)
const MIN_PATH_LENGTH := 15
const BUILD_SPOT_COUNT := 7
const DECOR_COUNT := 8

var _rng := RandomNumberGenerator.new()

# Filled by _generate_map() — a fresh layout every game.
var path_cells: Array[Vector2i] = []
var build_cells: Array[Vector2i] = []
var decor := {}  # cell -> texture file name
var base_cell := Vector2i(-1, -1)

@onready var world: Node2D = $World
@onready var ground: Node2D = $World/Ground
@onready var markers: Node2D = $World/Markers
@onready var enemy_path: Path2D = $World/EnemyPath
@onready var objects: Node2D = $World/Objects
@onready var hud: CanvasLayer = $HUD

var _wave_index := 0  # how many waves have been started
var _wave_running := false
var _game_ended := false
var _tanks_remaining := 0
var _auto_waves := false
## The spot whose menu is currently open (null when the menu is closed).
var _menu_spot: Area2D = null


func _ready() -> void:
	GameState.reset()
	_generate_map()
	_center_world()
	_build_ground()
	_build_road_curve()
	_place_build_spots()
	_place_base()

	hud.start_wave_pressed.connect(start_wave)
	hud.build_menu.option_selected.connect(_on_menu_option)
	hud.build_menu.closed.connect(_on_menu_closed)
	GameState.lives_changed.connect(_on_lives_changed)
	hud.set_wave_text("Wave 0/%d" % WAVES.size())

	_handle_debug_args()


## ---------- Random map generation ----------

func _generate_map() -> void:
	# A seeded RNG replays the exact same "random" map — reproducible bugs.
	var forced_seed := _arg_value("--seed")
	if forced_seed != "":
		_rng.seed = int(forced_seed)
	else:
		_rng.randomize()
	print("Map seed: %d (relaunch with -- --seed=%d for the same map)" % [_rng.seed, _rng.seed])

	path_cells = _generate_path(_rng)
	_pick_build_spots(_rng)
	_scatter_decor(_rng)
	_pick_base_cell()


## Random walk from the west edge to the east edge. The one rule that keeps
## the road drawable with our tile set: a new cell may touch the path ONLY at
## the cell we came from — otherwise two road lanes would run side by side
## and no tile could render that. Dead ends happen; we just retry.
func _generate_path(rng: RandomNumberGenerator) -> Array[Vector2i]:
	while true:
		var attempt := _try_path(rng)
		if attempt.size() >= MIN_PATH_LENGTH:
			return attempt
	return []  # unreachable, keeps the compiler happy


func _try_path(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var start := Vector2i(0, rng.randi_range(1, GRID.y - 2))
	var path: Array[Vector2i] = [start]
	var occupied := {start: true}
	var head := start
	# Directions to try: east twice (bias toward the exit), the detours once.
	var dirs := [
		Vector2i(1, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0),
	]
	while head.x < GRID.x - 1:
		var options: Array[Vector2i] = []
		for dir in dirs:
			var next: Vector2i = head + dir
			if next.x < 1 or next.x >= GRID.x or next.y < 0 or next.y >= GRID.y:
				continue
			if occupied.has(next):
				continue
			var touches_path := false
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if next + n != head and occupied.has(next + n):
					touches_path = true
					break
			if not touches_path:
				options.append(next)
		if options.is_empty():
			return []  # walked into a dead end — caller retries
		head = options[rng.randi_range(0, options.size() - 1)]
		path.append(head)
		occupied[head] = true
	return path


## Build spots go on grass next to the road, spread out from each other.
func _pick_build_spots(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2i] = []
	for cell in path_cells:
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = cell + n
			if c.x < 0 or c.x >= GRID.x or c.y < 0 or c.y >= GRID.y:
				continue
			if c in path_cells or c in candidates:
				continue
			candidates.append(c)
	_shuffle(candidates, rng)

	build_cells = []
	for c in candidates:
		if build_cells.size() >= BUILD_SPOT_COUNT:
			break
		var too_close := false
		for chosen in build_cells:
			if (c - chosen).length_squared() < 4:  # keep some spacing
				too_close = true
				break
		if not too_close:
			build_cells.append(c)


func _scatter_decor(rng: RandomNumberGenerator) -> void:
	var free: Array[Vector2i] = []
	for y in GRID.y:
		for x in GRID.x:
			var c := Vector2i(x, y)
			if c not in path_cells and c not in build_cells:
				free.append(c)
	_shuffle(free, rng)
	decor = {}
	for i in mini(DECOR_COUNT, free.size()):
		decor[free[i]] = DECOR_TEXTURES[rng.randi_range(0, DECOR_TEXTURES.size() - 1)]


## The HQ stands next to the road exit, on the first free neighbor cell.
func _pick_base_cell() -> void:
	var exit: Vector2i = path_cells[path_cells.size() - 1]
	for n in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(-1, 1)]:
		var c: Vector2i = exit + n
		if c.y < 0 or c.y >= GRID.y or c in path_cells:
			continue
		base_cell = c
		decor.erase(c)
		return


## Fisher-Yates with OUR rng — Array.shuffle() would use the global one and
## break seed reproducibility.
func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


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
	# Pave every cell the window can see — the play area plus grass filler all
	# the way past the screen edges, so the world has no visible border.
	# Painter's algorithm: draw back rows first. In iso, "further back" simply
	# means a smaller (x + y), so sort all cells by that sum.
	var area := _visible_cell_bounds()
	var cells: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y + 1):
		for x in range(area.position.x, area.end.x + 1):
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a, b): return (a.x + a.y) < (b.x + b.y))

	var road_tiles := _road_tile_map()
	var in_grid := func(c: Vector2i) -> bool:
		return c.x >= 0 and c.x < GRID.x and c.y >= 0 and c.y < GRID.y
	for cell in cells:
		if in_grid.call(cell):
			_add_tile(ground, TILE_DIR + road_tiles.get(cell, GRASS_TILE), cell)
			if decor.has(cell):
				# Decor sprites include their own tile block and stick up above
				# it, so they go in the Y-sorted Objects layer: tanks and towers
				# "in front" (lower on screen) must draw on top of them.
				_add_tile(objects, DETAIL_DIR + decor[cell], cell)
			continue
		# Filler: the road runs on through it to the screen edge; the rest is
		# grass with the occasional tree so it doesn't look like a dead sea.
		if (cell.y == path_cells[0].y and cell.x < 0) \
				or (cell.y == path_cells[path_cells.size() - 1].y and cell.x >= GRID.x):
			_add_tile(ground, TILE_DIR + ROAD_WE, cell)
			continue
		_add_tile(ground, TILE_DIR + GRASS_TILE, cell)
		if _rng.randf() < 0.05:
			_add_tile(objects, DETAIL_DIR + DECOR_TEXTURES[_rng.randi_range(0, 4)], cell)


## Which cells the window can see: un-project the viewport corners through
## the world transform back into grid coordinates, then pad generously.
func _visible_cell_bounds() -> Rect2i:
	var inverse := world.transform.affine_inverse()
	var view := get_viewport_rect().size
	var min_c := Vector2i.ZERO
	var max_c := GRID - Vector2i.ONE
	for corner in [Vector2.ZERO, Vector2(view.x, 0), Vector2(0, view.y), view]:
		var p: Vector2 = inverse * corner
		# Inverse of cell_to_world.
		var cx := (p.x / Iso.HALF_W + p.y / Iso.HALF_H) / 2.0
		var cy := (p.y / Iso.HALF_H - p.x / Iso.HALF_W) / 2.0
		min_c = Vector2i(mini(min_c.x, floori(cx) - 1), mini(min_c.y, floori(cy) - 1))
		max_c = Vector2i(maxi(max_c.x, ceili(cx) + 1), maxi(max_c.y, ceili(cy) + 1))
	return Rect2i(min_c, max_c - min_c)


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
	for i in path_cells.size():
		var cell := path_cells[i]
		# Edges toward the previous and next path cell (map edge at the ends).
		var to_prev := path_cells[i - 1] - cell if i > 0 else Vector2i(-1, 0)
		var to_next := path_cells[i + 1] - cell if i < path_cells.size() - 1 else Vector2i(1, 0)
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
	var first := Iso.cell_to_world(path_cells[0])
	var last := Iso.cell_to_world(path_cells[path_cells.size() - 1])
	# Spawn/despawn just past the screen edges: measure how far the entry and
	# exit cells are from them, in "cells travelled" (66*scale px per cell).
	var step_x := Iso.HALF_W * world.scale.x
	var view_width := get_viewport_rect().size.x
	var entry_overhang := ceilf((world.transform * first).x / step_x) + 1.0
	var exit_overhang := ceilf((view_width - (world.transform * last).x) / step_x) + 1.0
	points.append(first - Vector2(Iso.HALF_W, Iso.HALF_H) * entry_overhang)
	for i in path_cells.size() - 1:
		points.append((Iso.cell_to_world(path_cells[i]) + Iso.cell_to_world(path_cells[i + 1])) / 2.0)
	points.append(last + Vector2(Iso.HALF_W, Iso.HALF_H) * exit_overhang)

	var curve := Curve2D.new()
	for p in points:
		curve.add_point(p)
	for i in range(1, points.size() - 1):
		var handle := (points[i + 1] - points[i - 1]).normalized() * 22.0
		curve.set_point_in(i, -handle)
		curve.set_point_out(i, handle)
	enemy_path.curve = curve


func _place_build_spots() -> void:
	for cell in build_cells:
		var spot := BUILD_SPOT_SCENE.instantiate()
		spot.position = Iso.cell_to_world(cell)
		spot.clicked.connect(_on_spot_clicked)
		markers.add_child(spot)


func _place_base() -> void:
	if base_cell.x < 0:
		return
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/kenney/PNG/Towers (grey)/tower_00.png")
	sprite.position = Iso.cell_to_world(base_cell)
	sprite.offset = Vector2(0, -33)
	objects.add_child(sprite)


## ---------- Building ----------

## Clicking a spot opens a context menu: build options when empty,
## upgrade/sell when occupied. The menu is dumb; the decisions live here.
func _on_spot_clicked(spot: Area2D) -> void:
	_menu_spot = spot
	var options := []
	var title: String
	if spot.turret == null:
		title = "Build"
		for id in TURRET_TYPES:
			var data: TurretData = TURRET_TYPES[id]
			var cost: int = data.tiers[0].cost
			options.append({
				"id": "build:" + id,
				"label": "%s — %dg" % [data.display_name, cost],
				"cost": cost,
			})
	else:
		var turret: Turret = spot.turret
		title = "%s (level %d)" % [turret.data.display_name, turret.tier_index + 1]
		turret.show_range = true
		if turret.can_upgrade():
			options.append({
				"id": "upgrade",
				"label": "Upgrade — %dg" % turret.upgrade_cost(),
				"cost": turret.upgrade_cost(),
			})
		else:
			options.append({"id": "upgrade", "label": "Max level", "enabled": false})
		options.append({
			"id": "sell",
			"label": "Sell — +%dg" % turret.sell_value(),
		})
	# The spot lives in the scaled world; the menu lives on the screen.
	# This transform converts between the two spaces.
	var screen_pos := spot.get_global_transform_with_canvas().origin
	hud.build_menu.open(screen_pos, title, options)


func _on_menu_option(id: String) -> void:
	var spot := _menu_spot
	if spot == null:
		return
	if id.begins_with("build:"):
		_build_turret(spot, id.trim_prefix("build:"))
	elif id == "upgrade" and spot.turret != null:
		if GameState.spend(spot.turret.upgrade_cost()):
			spot.turret.upgrade()
	elif id == "sell" and spot.turret != null:
		GameState.earn(spot.turret.sell_value())
		spot.turret.queue_free()
		spot.turret = null
		spot.queue_redraw()


func _on_menu_closed() -> void:
	if _menu_spot != null and _menu_spot.turret != null:
		_menu_spot.turret.show_range = false
	_menu_spot = null


func _build_turret(spot: Area2D, type_id: String) -> void:
	var data: TurretData = TURRET_TYPES[type_id]
	if not GameState.spend(data.tiers[0].cost):
		spot.flash_denied()
		return
	var turret := TURRET_SCENE.instantiate()
	turret.data = data
	turret.position = spot.position  # Markers and Objects share the same origin
	objects.add_child(turret)
	spot.turret = turret
	spot.queue_redraw()


## ---------- Waves ----------

func start_wave() -> void:
	if _wave_running or _game_ended or _wave_index >= WAVES.size():
		return
	_wave_running = true
	var wave: WaveData = WAVES[_wave_index]
	_wave_index += 1
	hud.set_start_enabled(false)
	hud.set_wave_text("Wave %d/%d" % [_wave_index, WAVES.size()])

	_tanks_remaining = 0
	for group in wave.groups:
		_tanks_remaining += group.count
	for group in wave.groups:
		for i in group.count:
			if _game_ended:
				return
			_spawn_tank(group.tank, wave.hp_multiplier)
			# await pauses THIS function (not the game) until the timer fires.
			await get_tree().create_timer(group.interval).timeout


func _spawn_tank(tank_data: TankData, hp_multiplier: float) -> void:
	var tank := TANK_SCENE.instantiate()
	tank.data = tank_data
	tank.hp_multiplier = hp_multiplier
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
	if _tanks_remaining > 0 or _game_ended:
		return
	if _wave_index >= WAVES.size():
		_end_game("Victory!")
		return
	# Wave cleared: pay the bonus and open the next build phase.
	GameState.earn(WAVES[_wave_index - 1].bonus)
	_wave_running = false
	hud.set_start_enabled(true)
	if _auto_waves:
		get_tree().create_timer(1.0).timeout.connect(start_wave)


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
##   Godot --path . -- --seed=7 --autobuild --autostart --screenshot=/tmp/s.png
func _handle_debug_args() -> void:
	var args := OS.get_cmdline_user_args()
	# Fast-forward the whole simulation (physics, timers, tweens alike).
	var timescale := _arg_value("--timescale")
	if timescale != "":
		Engine.time_scale = float(timescale)
	if "--autobuild" in args:
		GameState.earn(2000)
		var type_ids := TURRET_TYPES.keys()
		var spots := markers.get_children()
		for i in spots.size():
			_build_turret(spots[i], type_ids[i % type_ids.size()])
		# Exercise the upgrade path too.
		spots[0].turret.upgrade()
		spots[0].turret.upgrade()
		spots[1].turret.upgrade()
	if "--menu-test" in args:
		# Regression test for the build flow: open the menu on a spot and
		# press its first button, exactly like a player click would.
		_on_spot_clicked(markers.get_child(2))
		await get_tree().process_frame
		# Affordability must track money changes while the menu is open.
		var button: Button = hud.build_menu.options_box.get_child(0)
		GameState.spend(GameState.money)
		print("menu-test broke: disabled=%s (want true)" % button.disabled)
		GameState.earn(500)
		print("menu-test rich: disabled=%s (want false)" % button.disabled)
		button.pressed.emit()
	_auto_waves = "--autowaves" in args
	if "--autostart" in args or _auto_waves:
		start_wave()
	var shot_path := _arg_value("--screenshot")
	if shot_path != "":
		_save_screenshot(shot_path, float(_arg_value("--delay", "1.0")))


## Reads "--name=value" from the user args; returns `fallback` when absent.
func _arg_value(name: String, fallback := "") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return arg.trim_prefix(name + "=")
	return fallback


func _save_screenshot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()

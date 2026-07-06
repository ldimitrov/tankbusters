# Godot 101 — as used in Tank Busters

A tour of the Godot concepts this project uses, each pointing at the file
where you can see it working. Read code and doc side by side.

## Nodes and the scene tree

Everything in Godot is a **Node** in one big tree. Each node type does one
thing: `Node2D` has a 2D transform, `Sprite2D` draws a texture, `Area2D`
detects overlaps/mouse, `CanvasLayer` renders in screen space. You compose
behavior by nesting nodes, and attach a **script** (GDScript) to a node to
give it logic. The script *is* the node: `extends Node2D` means "this script
runs as a Node2D".

See: `scenes/main/main.tscn` — Main > World > (Ground, Markers, EnemyPath,
Objects) is pure structure, no logic; the script on Main fills it.

## Scenes = prefabs

A `.tscn` file is a reusable subtree ("scene"). `tank.tscn` is one tank;
`preload(...).instantiate()` stamps out copies at runtime. Godot games are
scenes instancing other scenes — the composition pattern you'd call prefabs
in Unity.

See: `main.gd` (`TANK_SCENE`, `TURRET_SCENE`), `main.tscn` instancing
`hud.tscn`.

## The lifecycle: _ready and _process

- `_ready()` runs once when the node enters the tree (children exist by then).
- `_process(delta)` runs every rendered frame; `delta` is seconds since the
  last frame — multiply all movement by it so speed is framerate-independent.
- `@onready var x = $Body` defers a member assignment to `_ready` time.
  `$Body` is shorthand for `get_node("Body")` (path relative to this node).

See: `scenes/enemies/tank.gd`, `scenes/turrets/turret.gd`.

## Signals (the observer pattern)

Nodes emit **signals**; anyone can connect. This keeps nodes decoupled: the
build spot doesn't know what money is — it emits `build_requested` and Main
decides. Rule of thumb: **signal up, call down**. UI never polls: GameState
emits `money_changed` and the HUD label updates itself.

See: `autoload/game_state.gd` (declaring), `scenes/ui/hud.gd` (connecting),
`scenes/turrets/build_spot.gd` (signalling up to `main.gd`).

## Autoloads (singletons)

Scripts registered in Project Settings > Globals > Autoload exist once,
globally, for the whole game — reachable by name from any script. They
survive scene reloads, hence `GameState.reset()` in `main.gd:_ready`.

See: `autoload/game_state.gd`, registered in `project.godot`.

## Groups

`add_to_group("tanks")` tags a node; `get_tree().get_nodes_in_group("tanks")`
finds them all. Cheap, global, no bookkeeping — how turrets find targets.

See: `tank.gd:_ready`, `turret.gd:_pick_target`.

## Custom drawing with _draw()

Any CanvasItem can paint itself with `draw_*` calls inside `_draw()`. The
result is cached — call `queue_redraw()` when something changed. We use it
for the tank model, health bars, range ellipse, build pads and cannonballs.

See: `scripts/tank_body.gd` (a tiny 3D-to-iso box renderer), `turret.gd:_draw`.

## Paths and curves

`Path2D` holds a `Curve2D`. `curve.sample_baked(distance)` returns the point
`distance` pixels along it — that one function is the whole enemy movement
system. Tanks store their `progress` (distance driven), which doubles as
"who is first" for targeting.

See: `main.gd:_build_road_curve`, `tank.gd:_process`.

## Y-sorting (isometric depth)

With `y_sort_enabled`, a node draws its children ordered by their y position:
lower on screen = drawn later = in front. That is all the depth sorting an
isometric game needs, as long as every object's *position* is its "foot".
Ground tiles don't need it (painter's order at build time suffices).

See: `Objects` node in `main.tscn`, `main.gd:_build_ground`.

## Isometric math

The 2:1 iso projection is two formulas: `screen = (gx - gy, (gx + gy) / 2)`
and its inverse. Everything else (tile placement, tank headings, ground-circle
ranges drawn as ellipses) falls out of them.

See: `scripts/iso.gd`, used by `tank.gd` (heading), `turret.gd` (range).

## Pausing

`get_tree().paused = true` freezes every node whose `process_mode` is
Pausable (the default). The HUD sets `process_mode = Always` so its buttons
still work on the game-over screen.

See: `main.gd:_end_game`, `hud.tscn` root.

## await

`await get_tree().create_timer(1.1).timeout` suspends *that function* (not
the game) until the timer fires — how the wave spawner staggers tanks without
threads or timer-node boilerplate.

See: `main.gd:start_wave`.

## res:// and imports

`res://` is the project root. Godot imports every asset into `.godot/`
(gitignored, regenerated on demand) — commit sources, never the cache.

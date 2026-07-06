# Tank Busters

An isometric tower-defense game built with Godot 4.7. Tanks invade in waves
along a road; you stop them by building (and later upgrading) turrets on
fixed build spots.

Art: [Kenney Tower Defense (isometric) pack](https://kenney.nl) — CC0.

## Run it

Open the project in Godot (Project Manager > Import > pick `project.godot`)
and press **F5**, or from the terminal:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Click a white diamond pad and pick a turret — **Cannon** (damage) or
**Frost** (slows tanks in its aura) — then press **Start Wave**. Click a
built turret to **upgrade** it (3 levels each) or **sell** it (70% refund)
and build something else on the freed spot. Hover a built pad to see range.

## Development flags

Custom args after `--` are read by `main.gd` for scripted test runs:

```sh
# build all turrets, start the wave, save a screenshot after 6s and quit
/Applications/Godot.app/Contents/MacOS/Godot --path . -- \
  --autobuild --autostart --delay=6 --screenshot=/tmp/shot.png
```

## Learning notes

New to Godot? Start with [docs/GODOT-101.md](docs/GODOT-101.md) — it maps
every Godot concept used here to the file that demonstrates it.

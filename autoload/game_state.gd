extends Node
## Autoload (singleton). Registered under Project Settings > Globals > Autoload,
## which makes it accessible from ANY script simply as `GameState`.
## It owns the shared economy and broadcasts changes via signals, so the UI
## never polls — it just listens. This is Godot's observer pattern.

signal money_changed(amount: int)
signal lives_changed(amount: int)

const STARTING_MONEY := 100
const STARTING_LIVES := 20

var money := STARTING_MONEY
var lives := STARTING_LIVES


## Autoloads survive scene reloads (they live outside the current scene),
## so the main scene must call this from _ready() to start a fresh game.
func reset() -> void:
	money = STARTING_MONEY
	lives = STARTING_LIVES
	money_changed.emit(money)
	lives_changed.emit(lives)


func can_afford(cost: int) -> bool:
	return money >= cost


## Returns false (and changes nothing) when the player can't afford it.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	money -= cost
	money_changed.emit(money)
	return true


func earn(amount: int) -> void:
	money += amount
	money_changed.emit(money)


func lose_life() -> void:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)

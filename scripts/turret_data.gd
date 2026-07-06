class_name TurretData
extends Resource
## A turret family: its name plus the ladder of tiers it upgrades through.

@export var display_name := "Turret"
@export var tiers: Array[TurretTier] = []

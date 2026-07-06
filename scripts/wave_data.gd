class_name WaveData
extends Resource
## A wave: its spawn groups (run one after another) and the gold bonus
## awarded for clearing it.

@export var groups: Array[WaveGroup] = []
@export var bonus := 30
## Tank max HP is multiplied by this — later waves reuse the same tank
## types but send them in with thicker armor.
@export var hp_multiplier := 1.0

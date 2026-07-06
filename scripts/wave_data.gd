class_name WaveData
extends Resource
## A wave: its spawn groups (run one after another) and the gold bonus
## awarded for clearing it.

@export var groups: Array[WaveGroup] = []
@export var bonus := 30

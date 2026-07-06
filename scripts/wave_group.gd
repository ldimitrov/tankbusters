class_name WaveGroup
extends Resource
## One burst inside a wave: "spawn `count` of `tank` every `interval` seconds".

@export var tank: TankData
@export var count := 5
@export var interval := 1.5

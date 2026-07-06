extends CPUParticles2D
## One-shot explosion burst. `finished` fires when the last particle dies,
## so the node cleans itself up — no timers, no leaks.


func _ready() -> void:
	emitting = true
	finished.connect(queue_free)

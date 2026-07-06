extends CanvasLayer
## The HUD lives on a CanvasLayer: it renders in screen space, ignoring
## whatever the game world / camera does underneath.
## It knows nothing about tanks or turrets — it only listens to GameState
## signals and re-emits button presses upward for Main to handle.

signal start_wave_pressed

## %Name reaches any node marked "unique in scene" regardless of where it
## sits in the hierarchy — no brittle $Path/To/Node chains.
@onready var money_label: Label = %MoneyLabel
@onready var lives_label: Label = %LivesLabel
@onready var wave_label: Label = %WaveLabel
@onready var start_button: Button = %StartButton
@onready var end_overlay: Control = %EndOverlay
@onready var end_label: Label = %EndLabel
@onready var restart_button: Button = %RestartButton


func _ready() -> void:
	GameState.money_changed.connect(func(amount: int) -> void:
		money_label.text = "Gold: %d" % amount)
	GameState.lives_changed.connect(func(amount: int) -> void:
		lives_label.text = "Lives: %d" % amount)
	start_button.pressed.connect(func() -> void: start_wave_pressed.emit())
	restart_button.pressed.connect(_restart)


func set_wave_text(text: String) -> void:
	wave_label.text = text


func set_start_enabled(enabled: bool) -> void:
	start_button.disabled = not enabled


func show_end_screen(message: String) -> void:
	end_label.text = message
	end_overlay.visible = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

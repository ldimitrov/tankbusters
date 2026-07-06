extends Control
## Popup menu shown when a build spot is clicked. Deliberately dumb: it gets
## a list of {id, label, enabled} options, shows buttons, and reports which
## id was picked. What the options MEAN is Main's business.
##
## The root Control covers the whole screen while open — it catches the
## "clicked elsewhere" case (closing the menu) and blocks clicks from
## reaching build spots underneath.

signal option_selected(id: String)
signal closed

## Option dicts: {id, label, cost (optional), enabled (optional)}.
var _options := []

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var options_box: VBoxContainer = %OptionsBox


func _ready() -> void:
	# Costs can become affordable WHILE the menu is open (a bounty lands),
	# so re-check the buttons on every money change instead of only on open.
	GameState.money_changed.connect(func(_amount: int) -> void:
		if visible:
			_refresh_affordability())


func open(screen_pos: Vector2, title: String, options: Array) -> void:
	title_label.text = title
	_options = options
	# Rebuild the option buttons from scratch each time. remove_child (not
	# just queue_free) so the box holds ONLY the new buttons immediately —
	# freed nodes linger until the end of the frame.
	for child in options_box.get_children():
		options_box.remove_child(child)
		child.queue_free()
	for option in options:
		var button := Button.new()
		button.text = option.label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_option_pressed.bind(option.id))
		options_box.add_child(button)
	_refresh_affordability()

	visible = true
	# Wait one frame so the panel recomputes its size before we position it.
	await get_tree().process_frame
	var pos := screen_pos + Vector2(20, -panel.size.y / 2.0)
	var limit := get_viewport_rect().size - panel.size - Vector2(8, 8)
	panel.position = pos.clamp(Vector2(8, 8), limit)


func _refresh_affordability() -> void:
	for i in options_box.get_child_count():
		var option: Dictionary = _options[i]
		var button: Button = options_box.get_child(i)
		button.disabled = not option.get("enabled", true) \
				or option.get("cost", 0) > GameState.money


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _on_option_pressed(id: String) -> void:
	# Order matters: whoever listens needs the selection BEFORE `closed`
	# fires, because closing resets the "which spot is this menu for" state.
	option_selected.emit(id)
	close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

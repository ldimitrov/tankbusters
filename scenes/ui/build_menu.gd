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

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var options_box: VBoxContainer = %OptionsBox


func open(screen_pos: Vector2, title: String, options: Array) -> void:
	title_label.text = title
	# Rebuild the option buttons from scratch each time.
	for child in options_box.get_children():
		child.queue_free()
	for option in options:
		var button := Button.new()
		button.text = option.label
		button.disabled = not option.enabled
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_option_pressed.bind(option.id))
		options_box.add_child(button)

	visible = true
	# Wait one frame so the panel recomputes its size before we position it.
	await get_tree().process_frame
	var pos := screen_pos + Vector2(20, -panel.size.y / 2.0)
	var limit := get_viewport_rect().size - panel.size - Vector2(8, 8)
	panel.position = pos.clamp(Vector2(8, 8), limit)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _on_option_pressed(id: String) -> void:
	close()
	option_selected.emit(id)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

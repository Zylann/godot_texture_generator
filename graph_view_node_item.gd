extends HBoxContainer


const MODE_INPUT = 0
const MODE_PARAM = 1
const MODE_OUTPUT = 2

signal connection_dragging
signal connection_drag_stopped

var _input_slot: Control = null
var _output_slot: Control = null
var _mode = MODE_PARAM
var _control: Control = null
var _pressed = false
var _slot_index: int = -1


func _gather_nodes():
	if _input_slot == null:
		_input_slot = get_node("InputSlot")
	if _output_slot == null:
		_output_slot = get_node("OutputSlot")


func _ready():
	_gather_nodes()


func set_mode(mode):
	_gather_nodes()
	_input_slot.visible = (mode == MODE_INPUT)
	_output_slot.visible = (mode == MODE_OUTPUT)
	_mode = mode


func get_mode():
	return _mode


func get_slot_index() -> int:
	return _slot_index


func set_slot_index(i: int):
	assert(_slot_index == -1)
	_slot_index = i


func set_control(control: Control):
	assert(control != null)
	assert(control is Control)
	
	if _control != null:
		_control.get_parent().remove_child(_control)
		_control.call_deferred("free")
	
	_control = control
	_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child_below_node(_input_slot, control)


func get_control() -> Control:
	return _control


func get_slot_rect() -> Rect2:
	assert(_mode != MODE_PARAM)
	var r = Rect2()
	match _mode:
		MODE_INPUT:
			r = _input_slot.get_rect()
		MODE_OUTPUT:
			r = _output_slot.get_rect()
	r.position += rect_position
	return r


func get_slot_global_position():
	match _mode:
		MODE_INPUT:
			return _input_slot.rect_global_position + _input_slot.rect_size / 2.0
		MODE_OUTPUT:
			return _output_slot.rect_global_position + _output_slot.rect_size / 2.0
	printerr("Item has no slot!")
	return null


func _on_InputSlot_gui_input(event):
	_on_Slot_gui_input(event, MODE_INPUT)


func _on_OutputSlot_gui_input(event):
	_on_Slot_gui_input(event, MODE_OUTPUT)


func _on_Slot_gui_input(event, mode):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_LEFT:
				_pressed = true
		else:
			if _pressed:
				_pressed = false
				emit_signal("connection_drag_stopped")
	
	elif event is InputEventMouseMotion:
		if _pressed:
			emit_signal("connection_dragging")



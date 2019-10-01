extends Control

const Item = preload("./graph_view_node_item.gd")
const ItemScene = preload("./graph_view_node_item.tscn")

signal connection_dragging(from_item)
signal connection_drag_stopped(from_item)
signal moved

onready var _container = get_node("VBoxContainer")

var _title: Label = null
var _id: int = -1
var _inputs = []
var _outputs = []
var _params = []
var _pressed = false


func _gather_nodes():
	if _title == null:
		_title = get_node("VBoxContainer/Label")


func _ready():
	_gather_nodes()	


func get_title() -> String:
	_gather_nodes()
	return _title.text


func set_title(title: String):
	_gather_nodes()
	_title.text = title


func add_input(control: Control):
	return _add_item(control, Item.MODE_INPUT)


func add_output(control: Control):
	return _add_item(control, Item.MODE_OUTPUT)


func add_param(control: Control):
	return _add_item(control, Item.MODE_PARAM)


func get_id() -> int:
	return _id


func set_id(id: int):
	assert(_id == -1)
	_id = id


func get_slot_at(pos: Vector2) -> Control:
	#print("Get slot at ", pos)
	for items in [_inputs, _outputs]:
		for item in items:
			if item.get_slot_rect().has_point(pos):
				return item
	return null


func get_item(mode, index):
	match mode:
		Item.MODE_INPUT:
			return _inputs[index]
		Item.MODE_PARAM:
			return _params[index]
		Item.MODE_OUTPUT:
			return _outputs[index]
	return null


func _add_item(control: Control, mode: int) -> Control:
	
	var item = ItemScene.instance()
	item.set_mode(mode)
	item.set_control(control)
	item.connect("connection_dragging", self, "_on_item_connection_dragging", [item])
	item.connect("connection_drag_stopped", self, "_on_item_connection_drag_stopped", [item])
	_container.add_child(item)
	# TODO Auto-resize
	
	match mode:

		Item.MODE_INPUT:
			item.set_slot_index(len(_inputs))
			_inputs.append(item)

		Item.MODE_PARAM:
			item.set_slot_index(len(_params))
			_params.append(item)

		Item.MODE_OUTPUT:
			item.set_slot_index(len(_outputs))
			_outputs.append(item)
	
	return item
	

func _on_item_connection_dragging(item):
	emit_signal("connection_dragging", item)


func _on_item_connection_drag_stopped(item):
	emit_signal("connection_drag_stopped", item)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_LEFT:
				_pressed = true
		else:
			_pressed = false
	
	elif event is InputEventMouseMotion:
		if _pressed:
			rect_position += event.relative
			emit_signal("moved")


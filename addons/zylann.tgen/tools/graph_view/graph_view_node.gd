extends Control

const Item = preload("./graph_view_node_item.gd")
const ItemScene = preload("./graph_view_node_item.tscn")
const NormalBgStylebox = preload("./node_stylebox.tres")
const SelectedBgStylebox = preload("./node_selected_stylebox.tres")

signal connection_dragging(from_item)
signal connection_drag_stopped(from_item)
signal moved
#signal selected

var _container : Container = null
var _title: Label = null
var _id: int = -1
var _inputs = []
var _outputs = []
var _params = []
var _pressed = false
var _controller = null


func _gather_nodes():
	if _title == null:
		_title = get_node("VBoxContainer/Label")
	if _container == null:
		_container = get_node("VBoxContainer")


func _ready():
	#add_stylebox_override("Panel", NormalBgStylebox)
	_gather_nodes()


func get_title() -> String:
	_gather_nodes()
	return _title.text


func set_title(title: String):
	_gather_nodes()
	_title.text = title


func get_controller():
	return _controller


func set_controller(c):
	assert(_controller == null)
	assert(c != null)
	_controller = c


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


func add_item(mode: int, label_text: String) -> Control:
	
	_gather_nodes()
	
	var item = ItemScene.instance()
	item.set_mode(mode)
	item.set_label_text(label_text)
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
			grab_click_focus()
			#emit_signal("selected")
		else:
			_pressed = false
	
	elif event is InputEventMouseMotion:
		if _pressed:
			rect_position += event.relative
			emit_signal("moved")


func _get_minimum_size():
	_gather_nodes()
	var minsize = _container.get_combined_minimum_size()
	minsize.x += _container.margin_left * 2
	minsize.y += _container.margin_top * 2
	return minsize


func _on_GraphViewNode_focus_entered():
	_set_focused_visual(true)


func _on_GraphViewNode_focus_exited():
	_set_focused_visual(false)


func _set_focused_visual(focused):
	if focused:
		add_stylebox_override("panel", SelectedBgStylebox)
	else:
		add_stylebox_override("panel", NormalBgStylebox)


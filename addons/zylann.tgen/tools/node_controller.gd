extends Node

const NodeDefs = preload("./../node_defs.gd")
const NodeItem = preload("./graph_view/graph_view_node_item.gd")
const GraphView = preload("./graph_view/graph_view.gd")
const Util = preload("./../util/util.gd")

signal param_changed


func _get_view():
	return get_parent()


func _get_graph():
	var gv = Util.get_node_in_parents(self, GraphView)
	return gv.get_graph()


func _get_graph_node():
	var node_id = _get_view().get_id()
	var graph = _get_graph()
	return graph.get_node(node_id)


func setup_for_node_type(type_name):
	var type = NodeDefs.get_type_by_name(type_name)
	var view = _get_view()

	if type.has("outputs"):
		for i in len(type.outputs):
			var p = type.outputs[i]
			var item = view.add_item(NodeItem.MODE_OUTPUT, p.name)
	
	if type.has("params"):
		for i in len(type.params):
			var p = type.params[i]
			var item = view.add_item(NodeItem.MODE_PARAM, p.name)
			_setup_item(item, p)

	if type.has("inputs"):
		for i in len(type.inputs):
			var p = type.inputs[i]
			var item = view.add_item(NodeItem.MODE_INPUT, p.name)
			_setup_item(item, p)


func _setup_item(item, param_def):
	match param_def.type:
		"scalar", "float", "int":
			var ed = SpinBox.new()
			if param_def.type == "int":
				ed.step = 1
			else:
				ed.step = 0.001
			ed.min_value = -1000
			ed.max_value = 1000
			if param_def.has("default"):
				ed.value = param_def.default
			ed.connect("value_changed", self, "_on_param_modified", [param_def.name])
			item.set_control(ed)
		"color":
			var ed = ColorPickerButton.new()
			ed.connect("color_changed", self, "_on_param_modified", [param_def.name])
			item.set_control(ed)
		# TODO Image
		# TODO Gradient
		# TODO Curve


func _on_param_modified(new_value, param_name):
	var node = _get_graph_node()
	node.data.params[param_name] = new_value
	emit_signal("param_changed")

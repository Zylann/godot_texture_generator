extends Control


const NodeDefs = preload("./node_defs.gd")
const Compiler = preload("./compiler.gd")
const DAG = preload("./graph.gd")
const CodeFont = preload("./fonts/hack_regular.tres")
const NodeItem = preload("./graph_view_node_item.gd")

onready var _graph_view = get_node("VBoxContainer/MainView/GraphView")
onready var _codes_tab_container = get_node("VBoxContainer/MainView/BottomPanel/CodeView/TabContainer")
onready var _preview = get_node("VBoxContainer/MainView/BottomPanel/Preview")


func _ready():
	NodeDefs.check()
	
	var types = NodeDefs.get_node_types()
	for type_name in types:
		_graph_view.add_node_type(type_name)


static func create_graph_node(type_name):

	var type = NodeDefs.get_type_by_name(type_name)
	var node = DAG.TGNode.new()

	node.data = {
		"type": type_name,
		"params": {},
		"rect": Rect2()
	}

	if type.has("inputs"):
		for i in len(type.inputs):
			node.inputs.append([])

	if type.has("outputs"):
		for i in len(type.outputs):
			node.outputs.append([])

	if type.has("params"):
		for i in len(type.params):
			var p = type.params[i]
			var v = null
			if p.has("default"):
				v = p.default
			node.data.params[p.name] = v

	return node


func _on_GraphView_create_node_requested(type_name, position):
	_add_graph_node(type_name, position)


func _add_graph_node(type_name, position = Vector2()):
	
	var node = create_graph_node(type_name)
	var type = NodeDefs.get_type_by_name(type_name)
	var node_view = _graph_view.add_node(node, type_name)
	node_view.rect_position = position
	
	if type.has("outputs"):
		for i in len(type.outputs):
			var p = type.outputs[i]
			var item = node_view.add_item(NodeItem.MODE_OUTPUT, p.name)

	if type.has("params"):
		for i in len(type.params):
			var p = type.params[i]
			node_view.add_item(NodeItem.MODE_PARAM, p.name)

	if type.has("inputs"):
		for i in len(type.inputs):
			var p = type.inputs[i]
			var item = node_view.add_item(NodeItem.MODE_INPUT, p.name)
			var temp = SpinBox.new()
			item.set_control(temp)


func _on_GraphView_graph_changed():
	for i in _codes_tab_container.get_child_count():
		var child = _codes_tab_container.get_child(i)
		child.queue_free()
	
	var graph = _graph_view.get_graph()
	var compiler = Compiler.new(graph)
	var res = compiler.compile()
	
	for key in res:
		var ed = TextEdit.new()
		ed.syntax_highlighting = true
		ed.add_font_override("font", CodeFont)
		ed.name = key
		var code = res[key]
		ed.text = code
		_codes_tab_container.add_child(ed)
		
		var shader = Shader.new()
		shader.code = code
		var mat = ShaderMaterial.new()
		mat.shader = shader
		_preview.material = mat


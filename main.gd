extends Control


const NodeDefs = preload("./node_defs.gd")
const Compiler = preload("./compiler.gd")
const DAG = preload("./graph.gd")
const CodeFont = preload("./fonts/hack_regular.tres")
const NodeController = preload("./node_controller.gd")

onready var _graph_view = get_node("VBoxContainer/MainView/GraphView")
onready var _codes_tab_container = get_node("VBoxContainer/MainView/BottomPanel/CodeView/TabContainer")
onready var _preview = get_node("VBoxContainer/MainView/BottomPanel/Preview")
onready var _renderer = get_node("Renderer")
onready var _status_label = get_node("VBoxContainer/StatusBar/Label")

var _graph_view_context_menu : PopupMenu = null


func _ready():
	NodeDefs.check()
	_preview.texture = _renderer.get_texture()


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


func _add_graph_node(type_name, position = Vector2()):
	
	var node = create_graph_node(type_name)
	var node_view = _graph_view.add_node(node, type_name)
	node_view.rect_position = position
	
	var controller = NodeController.new()
	node_view.add_child(controller)
	node_view.set_controller(controller)
	
	controller.setup_for_node_type(type_name)
	controller.connect("param_changed", self, "_on_node_controller_param_changed")


func _on_GraphView_graph_changed():
	_recompile_graph()


func _on_node_controller_param_changed():
	_recompile_graph()
	

func _recompile_graph():
	
	var graph = _graph_view.get_graph()
	var compiler = Compiler.new(graph)
	var render_steps = compiler.compile()
	
	_display_render_steps_in_debug_panel(render_steps)
	
	_renderer.submit(render_steps)
	
	# TODO Make renderer


func _display_render_steps_in_debug_panel(render_steps):
	
	for i in _codes_tab_container.get_child_count():
		var child = _codes_tab_container.get_child(i)
		child.queue_free()
	
	for i in len(render_steps):
		var rs = render_steps[i]
		
		var ed = TextEdit.new()
		ed.syntax_highlighting = true
		ed.add_font_override("font", CodeFont)
		ed.name = str("Pass", i + 1)
		var code = rs.shader_code
		if rs.composition != null:
			code += str("\n\n// Composition: ", rs.composition.data.type, rs.composition.id)
		ed.text = code
		_codes_tab_container.add_child(ed)


func _on_GraphView_context_menu_requested(position):
	if _graph_view_context_menu == null:
		_graph_view_context_menu = PopupMenu.new()
		_graph_view.add_child(_graph_view_context_menu)
	var menu = _graph_view_context_menu
	menu.clear()
	
	# Gather node types
	var model = []
	var types_by_name = NodeDefs.get_node_types()
	for type_name in types_by_name:
		var type = types_by_name[type_name]
		if type.has("category"):
			var found = false
			for m in model:
				if m is Dictionary and m.category == type.category:
					m.node_types.append(type_name)
					found = true
					break
			if not found:
				model.append({
					"category": type.category,
					"node_types": [type_name]
				})
		else:
			model.append(type_name)

	# TODO Icons
	# Generate menu
	for m in model:
		if m is Dictionary:
			var submenu = PopupMenu.new()
			for type_name in m.node_types:
				_add_node_type_to_menu(submenu, type_name)
			submenu.name = m.category
			submenu.connect("index_pressed", self, \
				"_on_graph_view_context_menu_item_selected", [submenu, position])
			menu.add_child(submenu)
			menu.add_submenu_item(m.category, submenu.name)
		else:
			assert(typeof(m) == TYPE_STRING)
			var type_name = m
			_add_node_type_to_menu(menu, type_name)
			menu.connect("index_pressed", self, \
				"_on_graph_view_context_menu_item_selected", [menu, position])
	
	# Show menu
	menu.rect_position = position
	menu.popup()


static func _add_node_type_to_menu(menu, type_name):
	var i = menu.get_item_count()
	menu.add_item(type_name)
	menu.set_item_metadata(i, type_name)


func _on_graph_view_context_menu_item_selected(index, menu, position):
	var type_name = menu.get_item_metadata(index)
	_add_graph_node(type_name, position)


func _on_Renderer_progress_notified(progress):
	_status_label.text = str("Rendering ", int(progress * 100.0), " %")

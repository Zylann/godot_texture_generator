extends Control


const NodeDefs = preload("./../node_defs.gd")
const Compiler = preload("./../compiler.gd")
const DAG = preload("./../util/graph.gd")
const GraphNodeFactory = preload("./../graph_node_factory.gd")
const CodeFont = preload("./fonts/hack_regular.tres")
const NodeController = preload("./node_controller.gd")
const Preview2D = preload("./preview_2d/preview_2d.gd")
const Preview2DScene = preload("./preview_2d/preview_2d.tscn")
const GraphSerializer = preload("./../graph_serializer.gd")

const MENU_FILE_NEW = 0
const MENU_FILE_OPEN = 1
const MENU_FILE_SAVE = 2
const MENU_FILE_SAVE_AS = 3

onready var _graph_view = get_node("VBoxContainer/MainView/GraphView")
onready var _codes_tab_container = get_node("VBoxContainer/MainView/BottomPanel/CodeView/TabContainer")
onready var _bottom_panel = get_node("VBoxContainer/MainView/BottomPanel")
onready var _renderer = get_node("Renderer")
onready var _status_label = get_node("VBoxContainer/StatusBar/Label")
onready var _file_menu = get_node("VBoxContainer/MenuBar/FileMenuButton")

var _graph_view_context_menu : PopupMenu = null
var _open_file_dialog : FileDialog = null
var _save_file_dialog : FileDialog = null
var _error_dialog : AcceptDialog = null
var _discard_changes_dialog : ConfirmationDialog = null

var _current_file_path := ""
var _has_unsaved_modifications = false
var _action_on_discard_changes = null


func _ready():
	
	NodeDefs.check()
	
	_file_menu.get_popup().add_item("New...", MENU_FILE_NEW)
	_file_menu.get_popup().add_item("Open...", MENU_FILE_OPEN)
	_file_menu.get_popup().add_separator()
	_file_menu.get_popup().add_item("Save", MENU_FILE_SAVE)
	_file_menu.get_popup().add_item("Save As...", MENU_FILE_SAVE_AS)
	_file_menu.get_popup().connect("id_pressed", self, "_on_file_menu_id_pressed")
	
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.mode = FileDialog.MODE_OPEN_FILE
	fd.window_title = "Open Graph"
	fd.add_filter("*.tgen ; TGEN files")
	fd.connect("file_selected", self, "_on_open_file_dialog_file_selected")
	add_child(fd)
	_open_file_dialog = fd
	
	fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.mode = FileDialog.MODE_SAVE_FILE
	fd.window_title = "Save Graph"
	fd.add_filter("*.tgen ; TGEN files")
	fd.connect("file_selected", self, "_on_save_file_dialog_file_selected")
	add_child(fd)
	_save_file_dialog = fd
	
	_error_dialog = AcceptDialog.new()
	add_child(_error_dialog)
	
	var cd = ConfirmationDialog.new()
	cd.get_ok().text = "Don't save"
	cd.connect("confirmed", self, "_on_discard_changes_dialog_confirmed")
	cd.dialog_text = "Discard changes?"
	add_child(cd)
	_discard_changes_dialog = cd


func _add_graph_node(type_name, position = Vector2()):
	
	var node = GraphNodeFactory.create_graph_node(type_name)
	
	var graph = _graph_view.get_graph()
	graph.add_node(node)
	
	var node_view = _graph_view.create_node_view(node.id, type_name)
	
	_setup_node_view_controller(node_view, node)
	
	node_view.rect_position = position	
	node_view.select()
	
	_has_unsaved_modifications = true
	_recompile_graph()


func _setup_node_view_controller(node_view, node):
	
	var controller = NodeController.new()
	node_view.add_child(controller)
	node_view.set_controller(controller)
	
	controller.setup_for_node_type(node.data.type)
	controller.connect("param_changed", self, "_on_node_controller_param_changed")


func _on_GraphView_graph_changed():
	_has_unsaved_modifications = true
	_recompile_graph()


func _on_node_controller_param_changed():
	_has_unsaved_modifications = true
	_recompile_graph()
	

func _recompile_graph():
	
	var graph = _graph_view.get_graph()
	var compiler = Compiler.new(graph)
	var render_steps = compiler.compile()
	
	_display_render_steps_in_debug_panel(render_steps)
	
	_renderer.submit(render_steps)


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
			code += str("\n\n// Composition: ", rs.composition.type, i)
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
		if type.category != "":
			assert(typeof(type.category) == TYPE_STRING)
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


static func _add_node_type_to_menu(menu: PopupMenu, type_name: String):
	var i := menu.get_item_count()
	menu.add_item(type_name)
	menu.set_item_metadata(i, type_name)


func _on_graph_view_context_menu_item_selected(index, menu, position):
	var type_name := menu.get_item_metadata(index) as String
	_add_graph_node(type_name, position)


func _on_Renderer_progress_notified(progress: float):
	_status_label.text = str("Rendering ", int(progress * 100.0), " %")
	#_preview.texture = _renderer.get_texture()
	
	# TODO Mostly for debugging, won't stay that way
	for child in _bottom_panel.get_children():
		if child is Preview2D:
			child.queue_free()
	var textures = _renderer.get_textures()
	for tex in textures:
		var t = Preview2DScene.instance()
		t.call_deferred("set_texture", tex)
		_bottom_panel.add_child(t)


func _on_GraphView_delete_node_requested(node_view):
	
	var graph = _graph_view.get_graph()
	graph.remove_node(node_view.get_id())
	_recompile_graph()
	
	_graph_view.remove_node(node_view.get_id())


# To remember nodes positions in the graph view
func _tag_nodes_with_gui_data():
	var graph = _graph_view.get_graph()
	var nodes = graph.get_nodes()
	for node_id in nodes:
		var node = nodes[node_id]
		var node_view : Control = _graph_view.get_node_view(node_id)
		var rect = node_view.get_rect()
		node.data["rect"] = rect


func _on_file_menu_id_pressed(id: int):
	match id:
		MENU_FILE_NEW:
			_request_new_graph()
		
		MENU_FILE_OPEN:
			_request_open_file_dialog()
		
		MENU_FILE_SAVE:
			_request_save()
		
		MENU_FILE_SAVE_AS:
			_request_save_file_dialog()


func _request_open_file_dialog():
	if _has_unsaved_modifications:
		_discard_changes_dialog.popup_centered_minsize()
		_action_on_discard_changes = funcref(_open_file_dialog, "popup_centered_ratio")
	else:
		_open_file_dialog.popup_centered_ratio()


func _on_open_file_dialog_file_selected(fpath: String):
	_open_file(fpath)


func _request_save():
	if _current_file_path == "":
		_request_save_file_dialog()
	else:
		_save_file(_current_file_path)


func _request_save_file_dialog():
	_save_file_dialog.popup_centered_ratio()


func _on_save_file_dialog_file_selected(fpath: String):
	_save_file(fpath)


func _open_file(fpath: String):

	assert(fpath != "")
	var graph = GraphSerializer.load_from_file(fpath)

	if graph != null:
		
		_graph_view.clear()

		var nodes = graph.get_nodes()
		for id in nodes:
			var node = nodes[id]
			var node_view = _graph_view.create_node_view(node.id, node.data.type)
			node_view.rect_position = node.data.rect.position
			_setup_node_view_controller(node_view, node)
		
		_current_file_path = fpath
		_graph_view.set_graph(graph)
		_recompile_graph()

		_has_unsaved_modifications = false
		
	else:
		_error_dialog.dialog_text = str("Could not load \"", fpath, "\"")
		_error_dialog.popup_centered_minsize()


func _save_file(fpath: String):
	assert(fpath != "")
	_tag_nodes_with_gui_data()
	var graph = _graph_view.get_graph()
	if GraphSerializer.save_to_file(fpath, graph):
		_current_file_path = fpath
		_has_unsaved_modifications = false
	else:
		_error_dialog.dialog_text = str("Could not save \"", fpath, "\"")
		_error_dialog.popup_centered_minsize()


func _request_new_graph():
	if _has_unsaved_modifications:
		_discard_changes_dialog.popup_centered_minsize()
		_action_on_discard_changes = funcref(self, "_new_graph")
	else:
		_new_graph()


func _on_discard_changes_dialog_confirmed():
	var f = _action_on_discard_changes
	_action_on_discard_changes = null
	f.call_func()


func _new_graph():
	_graph_view.clear()
	_current_file_path = ""
	_has_unsaved_modifications = false



# GUI displaying a graph. Some functions allow to edit it as well.
# This UI doesn't depend on the logic of the graph,
# it only knows that the graph is a DAG and nodes have types.
# Specific logic is deferred to callbacks.

extends Control

const NodeScene = preload("./graph_view_node.tscn")
const GraphViewNode = preload("./graph_view_node.gd")
const NodeItem = preload("./graph_view_node_item.gd")
const DAG = preload("./../../util/graph.gd")
const Util = preload("./../../util/util.gd")

signal graph_changed
signal context_menu_requested(position)

var _graph = DAG.new()
var _nodes = {}
var _dragging_from_id = -1
var _dragging_from_item = null


func _gather_nodes():
	pass


func _ready():
	_gather_nodes()


func clear():
	_graph.clear()
	for id in _nodes:
		var node = _nodes[id]
		node.queue_free()
	_nodes.clear()
	emit_signal("graph_changed")


func set_graph(graph):
	if _graph == graph:
		return
	clear()
	_graph = graph
	emit_signal("graph_changed")
	# TODO Recreate all views from graph?


func get_graph():
	return _graph


func add_node(node, title) -> Control:
	_graph.add_node(node)
	emit_signal("graph_changed")
	
	assert(not _nodes.has(node.id))
	assert(node.id >= 0)
	
	var node_view = NodeScene.instance()
	node_view.set_title(title)
	node_view.set_id(node.id)
	add_child(node_view)
	node_view.connect("connection_dragging", self, "_on_node_connection_dragging", [node_view])
	node_view.connect("connection_drag_stopped", self, "_on_node_connection_drag_stopped")
	node_view.connect("moved", self, "_on_node_moved")
	_nodes[node.id] = node_view
	
	return node_view


func try_add_arc(from_id, from_slot, to_id, to_slot):
	
	if not _graph.check_connection(from_id, from_slot, to_id, to_slot):
		return
	# TODO Check connection types validity
	
	_graph.add_arc(from_id, from_slot, to_id, to_slot)
	
	# Hide editor on the input since it's now overriden by the connection
	var to_node_view = _nodes[to_id]
	var to_item = to_node_view.get_item(NodeItem.MODE_INPUT, to_slot)
	var item_control = to_item.get_control()
	if item_control != null:
		item_control.hide()
	
	emit_signal("graph_changed")
	print("Added arc")


func _remove_arc(arc_id):
	var arc = _graph.get_arc(arc_id)
	_graph.remove_arc(arc_id)
	
	var to_node_view = _nodes[arc.to_id]
	var to_item = to_node_view.get_item(NodeItem.MODE_INPUT, arc.to_slot)
	var item_control = to_item.get_control()
	if item_control != null:
		item_control.show()
		
	emit_signal("graph_changed")


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_RIGHT:
				emit_signal("context_menu_requested", event.position)


func _on_node_connection_dragging(item, node_view):
	if _dragging_from_id == -1:
		# Started dragging

		_dragging_from_id = node_view.get_id()
		_dragging_from_item = item
		
		if item.get_mode() == NodeItem.MODE_INPUT:
			# Dragging from an input
			
			var node = _graph.get_node(node_view.get_id())
			var slot = node.inputs[item.get_slot_index()]
			
			if len(slot) > 0:
				# That input is connected, dragging will disconnect it
				var arc_id = slot[0]
				var arc = _graph.get_arc(arc_id)
				
				# Override `from` variables
				_dragging_from_id = arc.from_id
				var from_node_view = _nodes[arc.from_id]
				_dragging_from_item = from_node_view.get_item(NodeItem.MODE_OUTPUT, arc.from_slot)

				_remove_arc(arc_id)
	
	update()
	# TODO Snap to connections?


func _get_node_at(pos: Vector2) -> Control:
	var hit = null
	for i in get_child_count():
		var child = get_child(i)
		if child is GraphViewNode:
			if child.get_rect().has_point(pos):
				hit = child
	return hit


func _on_node_connection_drag_stopped(original_dragged_item):

	var from_node_view = _nodes[_dragging_from_id]
	var from_item = _dragging_from_item
	_dragging_from_id = -1
	_dragging_from_item = null
	
	update()

	var to_pos = get_local_mouse_position()
	var to_node = _get_node_at(to_pos)
	
	if to_node == null:
		print("No destination")
		return

	var to_item = to_node.get_slot_at(to_pos - to_node.rect_position)
	
	if to_item == null:
		print("No destination on node")
		return
		
	if from_item.get_mode() == to_item.get_mode():
		print("Invalid connection")
		return

	var from_id = from_node_view.get_id()
	var from_slot = from_item.get_slot_index()
	var to_id = to_node.get_id()
	var to_slot = to_item.get_slot_index()
	
	if from_item.get_mode() == NodeItem.MODE_INPUT and to_item.get_mode() == NodeItem.MODE_OUTPUT:
		# Invert connection

		var temp = from_id
		from_id = to_id
		to_id = temp
		
		temp = from_slot
		from_slot = to_slot
		to_slot = temp
	
	try_add_arc(from_id, from_slot, to_id, to_slot)


func _draw():
	var gpos = rect_global_position
	
	if _dragging_from_id != -1:
		var from_pos = _dragging_from_item.get_slot_global_position() - gpos
		var to_pos = get_local_mouse_position()
		_draw_arc(from_pos, to_pos)
	
	var arcs = _graph.get_arcs()
	
	for id in arcs:
		var arc = arcs[id]
		
		var from_node = _nodes[arc.from_id]
		var from_item = from_node.get_item(NodeItem.MODE_OUTPUT, arc.from_slot)
		var from_pos = from_item.get_slot_global_position() - gpos
		
		var to_node = _nodes[arc.to_id]
		var to_item = to_node.get_item(NodeItem.MODE_INPUT, arc.to_slot)
		var to_pos = to_item.get_slot_global_position() - gpos

		_draw_arc(from_pos, to_pos)
	

func _draw_arc(from, to):
	var pre = Vector2(min(40, 0.3*from.distance_to(to)), 0)
	var p1 = from + pre
	var p2 = to - pre
	var color = Color(1, 1, 0, 0.6)
	#draw_polyline(PoolVector2Array([from, p1, p2, to]), color, 3)
	var pts = [from, p1, p2, to]
#	for p in pts:
#		draw_circle(p, 4, Color(0,0,1))
	pts = Util.angle_tessellate(pts, 30)
	draw_polyline(PoolVector2Array(pts), color, 3)
	
	color.a = 1.0
	color *= 1.25 # hack
	draw_circle(from, 4, color)
	draw_circle(to, 4, color)


func _on_node_moved():
	update()

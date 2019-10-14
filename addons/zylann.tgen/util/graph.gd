
# Directed Acyclic Graph (DAG) with inputs and outputs.


class TGNode:
	var id = -1
	# Array of arrays of arc indices
	var inputs = []
	var outputs = []
	
	var data = null
	
	func duplicate():
		var d = get_script().new()
		d.data = data
		d.inputs = inputs.duplicate(true)
		d.outputs = outputs.duplicate(true)
		return d


class TGArc:
	var from_id = -1
	var from_slot = -1
	var to_id = -1
	var to_slot = -1
	
	func duplicate():
		var d = get_script().new()
		d.from_id = from_id
		d.from_slot = from_slot
		d.to_id = to_id
		d.to_slot = to_slot
		return d


var _nodes = {}
var _arcs = {}
var _next_id = 1


func _make_id():
	var id = _next_id
	_next_id += 1
	return id


func add_node(n):
	var id = _make_id()
	assert(not _nodes.has(id))
	_nodes[id] = n
	n.id = id
	return id


func get_node(node_id):
	return _nodes[node_id]


func get_nodes():
	return _nodes


func get_arcs():
	return _arcs


func remove_node(node_id):

	var node = _nodes[node_id]
	assert(node.id == node_id)

	for slot in node.inputs:
		for arc_id in slot:
			remove_arc(arc_id)

	for slot in node.outputs:
		for arc_id in slot:
			remove_arc(arc_id)

	_nodes.erase(node_id)


func check_connection(from_id, from_slot, to_id, to_slot):
	
	assert(from_id >= 0)
	assert(to_id >= 0)
	assert(from_slot >= 0)
	assert(to_slot >= 0)
	
	if from_id == to_id:
		print("Can't connect to self")
		return false
	
	var from_node = _nodes[from_id]
	var to_node = _nodes[to_id]
	
	if from_slot >= len(from_node.outputs):
		print("Source slot is out of range")
		return false
	
	if to_slot >= len(to_node.inputs):
		print("Destination slot is out of range")
		return false
	
	if len(to_node.inputs[to_slot]) != 0:
		print("Destination slot is already connected once")
		return false
	
	var to_process = [to_node]
	var processed = {}
	while len(to_process) > 0:
		var node = to_process[-1]
		to_process.pop_back()
		if node == from_node:
			# Found cycle
			print("Connection invalid, found cycle")
			return false
		to_process.pop_back()
		for slot in node.outputs:
			for arc_id in slot:
				var arc = _arcs[arc_id]
				if processed.has(arc.to_id):
					continue
				var next_node = _nodes[arc.to_id]
				to_process.append(next_node)
				processed[next_node.id] = true
	
	return true


func add_arc(from_id, from_slot, to_id, to_slot):
	
	assert(from_id >= 0)
	assert(to_id >= 0)
	assert(from_slot >= 0)
	assert(to_slot >= 0)
	assert(from_id != to_id)
	
	# TODO Check cycle
	
	var from_node = _nodes[from_id]
	var to_node = _nodes[to_id]
	
	assert(from_slot < len(from_node.outputs))
	assert(to_slot < len(to_node.inputs))
	
	# An input can have only one incoming arc (assuming to_slot is an input!)
	assert(len(to_node.inputs[to_slot]) == 0)
	
	# TODO Check types compatibility
	
	var arc = TGArc.new()
	arc.from_id = from_id
	arc.to_id = to_id
	arc.from_slot = from_slot
	arc.to_slot = to_slot
	var arc_id = _make_id()
	assert(not _arcs.has(arc_id))
	_arcs[arc_id] = arc
	
	from_node.outputs[from_slot].append(arc_id)
	to_node.inputs[to_slot].append(arc_id)
	
	return arc_id


func get_arc(arc_id):
	return _arcs[arc_id]


func remove_arc(arc_id):
	
	assert(arc_id >= 0)
	
	var arc = _arcs[arc_id]
	
	var from_node = _nodes[arc.from_id]
	var to_node = _nodes[arc.to_id]
	
	from_node.outputs[arc.from_slot].erase(arc_id)
	to_node.inputs[arc.to_slot].erase(arc_id)
	
	_arcs.erase(arc_id)


func duplicate():
	var d = get_script().new()
	
	for id in _nodes:
		var node = _nodes[id]
		node = node.duplicate()
		d._nodes[id] = node

	for id in _arcs:
		var arc = _arcs[id]
		arc = arc.duplicate()
		d._arcs[id] = arc

	d._next_id = _next_id
	
	return d


#func get_ancestors(base_node, root_predicate):
#
#	var prev_nodes = []
#	var root_nodes = []
#	var nodes_to_process = [base_node]
#	var visited_nodes = {}
#
#	while len(nodes_to_process) > 0:
#
#		var node = nodes_to_process[-1]
#		nodes_to_process.pop_back()
#		visited_nodes[node] == true
#
#		for input_slot in node.inputs:
#			if len(input_slot) == 0:
#				continue
#			assert(len(input_slot) == 1)
#			var arc = get_arc(input_slot[0])
#			var prev_node = get_node(arc.from_id)
#			if prev_nodes.has(prev_node):
#				continue
#			prev_nodes.append(prev_node)
#
#		for prev_node in prev_nodes:
#			if root_predicate.call_func(prev_node):
#				if not root_nodes.has(prev_node):
#					root_nodes.append(prev_node)
#			else:
#				nodes_to_process.append(prev_node)
#
#	return {
#		"root_nodes": root_nodes,
#		"visited_nodes": visited_nodes
#	}


func get_output_nodes():
	var nodes = []
	for id in _nodes:
		var node = _nodes[id]
		if len(node.outputs) == 0:
			nodes.append(node)
	return nodes


# output_nodes: nodes from which to start evaluation
# block_predicate: nodes for at evaluation must stop
func evaluate(output_nodes = null, block_predicate = null) -> Array:

	var to_process
	if output_nodes == null:
		to_process = get_output_nodes()
	else:
		to_process = output_nodes.duplicate(false)
	
	var processed_node_ids = {}
	var order = []
	
	while len(to_process) > 0:
		var node = to_process[-1]
		
		var input_node_ids_to_process = []
		if (block_predicate == null or not block_predicate.call_func(node)) or output_nodes.has(node):
			for slot_index in len(node.inputs):
				var slot = node.inputs[slot_index]
				if len(slot) == 0:
					continue
				assert(len(slot) == 1)
				var arc = get_arc(slot[0])
				if processed_node_ids.has(arc.from_id):
					continue
				if not input_node_ids_to_process.has(arc.from_id):
					input_node_ids_to_process.append(arc.from_id)
		
		if len(input_node_ids_to_process) == 0:
			# All inputs got processed, now we can add the current node
			#process_func.call_func(node)
			order.append(node)
			processed_node_ids[node.id] = true
			to_process.pop_back()
		
		else:
			for node_id in input_node_ids_to_process:
				to_process.append(get_node(node_id))

	return order


const NodeDefs = preload("./node_defs.gd")
	

var _graph = null


func _init(graph):
	_graph = graph


func evaluate():
	
	var all_steps = _graph.evaluate()
#	for step in all_steps:
#		print("- ", step.data.debug_name)
	
	var outputs = []
	for step in all_steps:
		if _is_composition_node(step) or len(step.outputs) == 0:
			outputs.append(step)
	
	#print("------")
	var list = []
	for output in outputs:
		#print("Eval from ", output.data.debug_name)
		var steps = _graph.evaluate([output], funcref(self, "_is_composition_node"))
		list.append(steps)
	
	#print("------")
#	for i in len(list):
#		var steps = list[i]
#		print("Pass ", i + 1)
#		for step in steps:
#			print("- ", step.data.debug_name)
	
	return list


func _is_composition_node(node):
	var type = NodeDefs.get_type_by_name(node.data.type)
	var b = type.family == "composition"
	#print(b)
	return b

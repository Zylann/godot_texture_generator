
const NodeDefs = preload("./node_defs.gd")
const DAG = preload("./util/graph.gd")


static func create_graph_node(type_name):

	var type = NodeDefs.get_type_by_name(type_name)
	var node = DAG.TGNode.new()

	node.data = {
		"type": type_name,
		"params": {},
		"rect": Rect2()
	}

	for i in len(type.inputs):
		node.inputs.append([])

	for i in len(type.outputs):
		node.outputs.append([])

	for i in len(type.params):
		var p = type.params[i]
		var v = null
		if p.has("default"):
			v = p.default
		node.data.params[p.name] = v

	return node


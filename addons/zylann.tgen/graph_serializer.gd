
const Factory = preload("./graph_node_factory.gd")
const DAG = preload("./util/graph.gd")
const Jsonify = preload("./util/jsonify.gd")


static func save_to_file(fpath, graph):
	
	var nodes = graph.get_nodes()
	var arcs = graph.get_arcs()
	
	var nodes_data = {}
	for node_id in nodes:
		var node = nodes[node_id]
		var dd = node.data.duplicate(true)
		Jsonify.jsonify(dd)
		nodes_data[str(node_id)] = dd
	
	var arcs_data = {}
	for arc_id in arcs:
		var arc = arcs[arc_id]
		arcs_data[str(arc_id)] = {
			"from_id": arc.from_id,
			"from_slot": arc.from_slot,
			"to_id": arc.to_id,
			"to_slot": arc.to_slot
		}
	
	var data = {
		"tgen_version": 1,
		"tgen_graph": {
			"nodes": nodes_data,
			"arcs": arcs_data
		}
	}
	
	var text = JSON.print(data, "\t")
	
	var f = File.new()
	var err = f.open(fpath, File.WRITE)
	if err != OK:
		printerr("Could not save to file ", fpath, ", error ", err)
		return false
	
	f.store_string(text)
	f.close()
	
	return true


static func load_from_file(fpath):
	var f = File.new()
	var err = f.open(fpath, File.READ)
	if err != OK:
		printerr("Could not open file ", fpath, ", error ", err)
		return null
	
	var text = f.get_as_text()
	f.close()
	
	var parse_result : JSONParseResult = JSON.parse(text)
	if parse_result.error != OK:
		printerr("Failed to parse file ", fpath, ", ", parse_result.error_string)
		return null
	
	var data = parse_result.result
	
	if not data.has("tgen_version") or data.tgen_version != 1:
		printerr("Invalid format version")
		return null
	
	if not data.has("tgen_graph"):
		printerr("File contains no graph")
		return null
	
	var nodes_data = data.tgen_graph.nodes
	var arcs_data = data.tgen_graph.arcs
	
	var graph = DAG.new()
	
	for node_id_s in nodes_data:
		var node_data = nodes_data[node_id_s]
		var node_id = int(node_id_s)
		var node = Factory.create_graph_node(node_data.type)
		# Warning: integers can't be recovered, we may need to fix case by case if needed
		var dd = Jsonify.godotify(node_data)
		for k in dd:
			node.data[k] = dd[k]
		node.id = node_id
		graph.add_node(node)
	
	for arc_id_s in arcs_data:
		var arc_data = arcs_data[arc_id_s]
		var arc_id = int(arc_id_s)
		graph.add_arc( \
			int(arc_data.from_id), \
			int(arc_data.from_slot), \
			int(arc_data.to_id), \
			int(arc_data.to_slot), \
			arc_id)
	
	return graph


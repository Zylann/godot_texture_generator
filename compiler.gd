
const NodeDefs = preload("./node_defs.gd")


var _graph = null
# All statements gathered so far
var _statements = []
# node id => [output expressions]
var _expressions = {}


func _init(graph):
	_graph = graph


func compile():
	_generate()
	# TODO Handle multiple outputs
	# TODO Handle composition steps
	return {
		"output1": _get_full_code()
	}


func _generate():
	
	var parse_list = _graph.evaluate()
	print("----")
	for node in parse_list:
		print("[", node.id, "] ", node.data.type)
	
	_expressions.clear()
	_statements.clear()
	
	for node in parse_list:
		
		var type = NodeDefs.get_type_by_name(node.data.type)
		#var code = CodeGen.new(node.id, len(type.outputs) if type.has("outputs") else 1)
		
		var expressions = null
		
		match node.data.type:
			
			"TextureCoordinates":
				expressions = ["UV"]
				
			"Multiply":
				var a_code = _get_input_code(node, 0)
				var b_code = _get_input_code(node, 1)
				expressions = [str("(", a_code, ") * (", b_code, ")")]

			"GaussianBlur":
				# TODO Not correct
				expressions = ["TEXTURE"]

			"Output":
				var a_code = _get_input_code(node, 0)
				# TODO mark final
				_statements.append(str("COLOR = ", a_code, ";"))
			
			"Texture":
				# TODO Not correct
				var tex_code = _get_input_code(node, 0)
				var uv_code = _get_input_code(node, 1)
				expressions = [str("texture(", tex_code, ", ", uv_code, ")")]
		
		for i in len(node.outputs):
			if len(node.outputs[i]) > 1:
				# Output used by more than one node,
				# store result in a var to avoid redoing the same calculation
				var var_name = str("v", node.id, "_", i)
				_statements.append(str(var_name, " = ", expressions[i], ";"))
				expressions[i] = var_name
		
		_expressions[node.id] = expressions


func _get_input_code(node, input_index):
	if len(node.inputs[input_index]) != 1:
		# That input is not connected, use value
		# TODO Handle slot values
		var type = NodeDefs.get_type_by_name(node.data.type)
		var input_def = type.inputs[input_index]
		var v = input_def.default
		return str(v)
	else:
		var arc = _graph.get_arc(node.inputs[input_index][0])
		# TODO Have a flag to know if parenthesis are needed
		var prev_outputs = _expressions[arc.from_id]
		return prev_outputs[arc.from_slot]


func _get_full_code():
	var lines = [
		"shader_type canvas_item;",
		"void fragment() {",
	]
	for statement in _statements:
		lines.append(str("\t", statement))
	lines.append("}")
	
	return PoolStringArray(lines).join("\n")


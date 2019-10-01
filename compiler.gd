
const NodeDefs = preload("./node_defs.gd")

#const CONTEXT_BINOP = 1

const _scalar_type_dimension = {
	"float": 1,
	"vec2": 2,
	"vec3": 3,
	"vec4": 4
}

const _scalar_type_members = "xyzw"


class Expr:
	var code = ""
	var type = ""
	#var composite = true
	
	func duplicate():
		var e = get_script().new()
		e.code = code
		e.type = type
		#e.composite = composite
		return e


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
#	print("----")
#	for node in parse_list:
#		print("[", node.id, "] ", node.data.type)
	
	_expressions.clear()
	_statements.clear()
	
	for node in parse_list:
		
		var node_type_name = node.data.type
		var node_type = NodeDefs.get_type_by_name(node_type_name)
		#var code = CodeGen.new(node.id, len(type.outputs) if type.has("outputs") else 1)
		
		var expressions = null
		
		match node_type_name:
			
			"TextureCoordinates":
				var e = Expr.new()
				e.code = "UV"
				e.type = "vec2"
				expressions = [e]
				
			"Multiply":
				var a_exp = _get_input_expression_or_default(node, 0, "float")
				var b_exp = _get_input_expression_or_default(node, 1, "float")
				var ie = _autocast_pair(a_exp, b_exp)
				var e = Expr.new()
				e.code = str("(", ie[0].code, ") * (", ie[1].code, ")")
				e.type = ie[0].type
				print(e.type)
				expressions = [e]

			"GaussianBlur":
				# TODO mark final
				# TODO Not correct
				expressions = ["TEXTURE"]

			"Output":
				var a_exp = _get_input_expression_or_default(node, 0, "vec4")
				# TODO mark final
				var e = _autocast(a_exp, "vec4") #node_type.inputs[0].type
				_statements.append(str("COLOR = ", e.code, ";"))
			
			"Texture":
				# TODO Not correct
				var tex_exp = _get_input_expression(node, 0)
				var uv_exp = _get_input_expression_or_default(node, 1, "vec2")
				var e = Expr.new()
				e.code = str("texture(", tex_exp.code, ", ", uv_exp.code, ")")
				e.type = "vec4"
				expressions = [e]
		
		for i in len(node.outputs):
			if len(node.outputs[i]) > 1:
				# Output used by more than one node,
				# store result in a var to avoid redoing the same calculation
				var var_name = str("v", node.id, "_", i)
				var prev_exp = expressions[i]
				_statements.append(str(prev_exp.type, " ", var_name, " = ", prev_exp.code, ";"))
				var ve = Expr.new()
				ve.code = var_name
				ve.type = prev_exp.type
				expressions[i] = ve
		
		_expressions[node.id] = expressions


func _get_input_default_expression(node, input_index, data_type):
	# TODO Handle slot values
	var node_type = NodeDefs.get_type_by_name(node.data.type)
	var input_def = node_type.inputs[input_index]
	var v = input_def.default
	var e = Expr.new()
	if data_type == "float":
		# TODO Not pretty
		e.code = "1.0" if int(v) == 1 else "0.0"
	elif data_type == "vec4" and v == 0:
		e.code = "vec4(0.0, 0.0, 0.0, 1.0)"
	else:
		e.code = str(data_type, "(", v, ")")
	e.type = data_type
	return e


func _get_input_expression(node, input_index):
	if len(node.inputs[input_index]) != 1:
		return null
	else:
		var arc = _graph.get_arc(node.inputs[input_index][0])
		# TODO Have a flag to know if parenthesis are needed
		var prev_outputs = _expressions[arc.from_id]
		return prev_outputs[arc.from_slot]


func _get_input_expression_or_default(node, input_index, data_type):
	var e = _get_input_expression(node, input_index)
	if e == null:
		e = _get_input_default_expression(node, input_index, data_type)
	return e


func _autocast_pair(e1, e2, context=-1):
	
	if e1.type == e2.type:
		return [e1, e2]
	
	var e1_dim = _scalar_type_dimension[e1.type]
	var e2_dim = _scalar_type_dimension[e2.type]
	
#	if context == CONTEXT_BINOP and (e1_dim == 1 or e2_dim == 1):
#		return [e1, e2]
	
	# The type of larger dimension wins
	if e1_dim < e2_dim:
		e1 = _autocast(e1, e2.type)
	else:
		e2 = _autocast(e2, e1.type)
	
	return [e1, e2]


func _autocast(e, dst_type):
	
	if e.type == dst_type:
		return e
	
	e = e.duplicate()
	# TODO If an expression isn't primitive, store in a var to avoid repeating it
	
	var src_dim = _scalar_type_dimension[e.type]
	var dst_dim = _scalar_type_dimension[dst_type]
	
	if src_dim < dst_dim:
		if dst_dim < 4:
			e.code = str(dst_type, "(", e.code, ")")
		else:
			# TODO Only do this upon color context?
			# Alpha to 1.0 for color use cases
			match src_dim:
				1:
					e.code = str(dst_type, "(", e.code, ", 0.0, 0.0, 1.0)")
				2:
					e.code = str(dst_type, "(", e.code, ", 0.0, 1.0)")
				3:
					e.code = str(dst_type, "(", e.code, ", 1.0)")
	else:
		var s = _scalar_type_members.substr(0, dst_dim)
		e.code = str("(", e.code, ").", s)
		
	e.type = dst_type
	return e


func _get_full_code():
	var lines = [
		"shader_type canvas_item;",
		"void fragment() {",
	]
	for statement in _statements:
		lines.append(str("\t", statement))
	lines.append("}")
	
	return PoolStringArray(lines).join("\n")


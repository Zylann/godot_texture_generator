
const NodeDefs = preload("./node_defs.gd")
const GraphEvaluator = preload("./compiler_graph_evaluator.gd")

const _scalar_type_dimension = {
	"float": 1,
	"vec2": 2,
	"vec3": 3,
	"vec4": 4
}

const _scalar_type_defaults = {
	"float": 0.0,
	"vec2": Vector2(),
	"vec3": Vector3(),
	"vec4": Color()
}

const _scalar_type_members = "xyzw"


class Expr:
	var code = ""
	var type = ""
	# By default we assume expressions are complex.
	# We set this to false only when we are sure it's just a variable or constant.
	var composite = true
	
	func duplicate():
		var e = get_script().new()
		e.code = code
		e.type = type
		e.composite = composite
		return e
	
	func get_code_for_op():
		if composite:
			return str("(", code, ")")
		return code


class RenderStep:
	var shader_code = ""
	var shader = null
	var composition = null
	# uniform name => texture source
	var texture_uniforms = {}


class TextureSource:
	var render_step_index = -1
	var filepath = ""


class NodeCompilerContext:
	
	var node
	var _compiler
	
	func _init(compiler):
		_compiler = compiler
	
	func create_expression(code, type):
		var e = Expr.new()
		e.code = code
		e.type = type
		return e
	
	func get_input_expression_or_default(index, data_type):
		return _compiler._get_input_expression_or_default(node, index, data_type)

	func autocast_pair(a, b):
		return _compiler._autocast_pair(a, b)

	func autocast(a, dst_type):
		return _compiler._autocast(a, dst_type)


# Read-only graph
var _graph = null

# All statements gathered so far
var _statements = []

# node id => [output expressions]
var _expressions = {}

# input node id => texture uniform index
var _texture_uniforms = {}

var _next_var_id = 0


func _init(graph):
	_graph = graph


func compile():
	
	var graph_evaluator = GraphEvaluator.new(_graph)
	var parse_lists = graph_evaluator.evaluate()
	
#	print("----")
#	for node in parse_list:
#		print("[", node.id, "] ", node.data.type)

	var render_steps = []
	var node_pass_indexes = {}
	
	for parse_list in parse_lists:
		var rs = _generate_pass(parse_list, node_pass_indexes)
		
		var last_node = parse_list[-1]
		node_pass_indexes[last_node.id] = len(render_steps)
		
		render_steps.append(rs)
	
	return render_steps


func _generate_pass(parse_list, node_pass_indexes):
	
	_expressions.clear()
	_statements.clear()
	_texture_uniforms.clear()
	
	for node_index in len(parse_list) - 1:
		
		var node = parse_list[node_index]
		var expressions = _process_node(node)
		
		for i in len(node.outputs):
			if len(node.outputs[i]) > 1:
				var prev_exp = expressions[i]
				if prev_exp.composite:
					# Complex output used by more than one node,
					# store result in a var to avoid redoing the same calculation
					var var_name = _generate_var_name()
					_statements.append(str(prev_exp.type, " ", var_name, " = ", prev_exp.code, ";"))
					var ve = Expr.new()
					ve.code = var_name
					ve.type = prev_exp.type
					ve.composite = false
					expressions[i] = ve
		
		_expressions[node.id] = expressions

	var rs = RenderStep.new()

	# The last node must be an output of some sort
	var last_node = parse_list[-1]
	var last_node_type = NodeDefs.get_type_by_name(last_node.data.type)
	assert(last_node_type.family in ["output", "composition"])

	if last_node_type.family == "composition":
		# TODO This is a deep duplication, however I don't want resources to be duped... careful
		rs.composition = last_node.data.duplicate(true)
	
	_process_output_node(last_node)
	
	rs.shader_code = _get_full_code()
	rs.shader = Shader.new()
	rs.shader.code = rs.shader_code
	
	for node_id in _texture_uniforms:
		var uniform_name = _texture_uniforms[node_id]
		var ts = TextureSource.new()
		ts.render_step_index = node_pass_indexes[node_id]
		rs.texture_uniforms[uniform_name] = ts
	
	return rs


func _process_node(node):
	var node_type_name = node.data.type
	#var node_type = NodeDefs.get_type_by_name(node_type_name)
	
	var expressions = null
	var context = NodeCompilerContext.new(self)
	context.node = node
	
	match node_type_name:
		
		"Sin":
			var a_exp = _get_input_expression_or_default(node, 0, "float")
			var e = Expr.new()
			e.code = str("sin(", a_exp.code, ")")
			e.type = a_exp.type
			expressions = [e]
		
		"Wave":
			var a_exp = _get_input_expression_or_default(node, 0, "float")
			var offset = _get_param_code(node, "offset")
			var freq = _get_param_code(node, "frequency")
			# TODO Wave type: triangle, square, sine, saw
			var e = Expr.new()
			# 0.5*cos(o+f*x*TAU+PI)+0.5
			e.code = str("0.5 + 0.5 * cos(", offset, " + ", freq, " * ", \
				a_exp.get_code_for_op(), " * ", TAU, " + ", PI, ")")
			e.type = a_exp.type
			expressions = [e]

		"Clamp":
			var a_exp = _get_input_expression_or_default(node, 0, "float")
			var minv = _get_param_code(node, "min")
			var maxv = _get_param_code(node, "max")
			var e = Expr.new()
			e.code = str("clamp(", a_exp.code, ", ", minv, ", ", maxv, ")")
			e.type = a_exp.type
			expressions = [e]

		"GaussianBlur":
			# TODO This may eventually be the same code for each compo output
			var tex_var_name
			if not _texture_uniforms.has(node.id):
				tex_var_name = _get_texture_uniform_name(len(_texture_uniforms))
				_texture_uniforms[node.id] = tex_var_name
			else:
				tex_var_name = _texture_uniforms[node.id]
			var e = Expr.new()
			e.code = tex_var_name
			e.type = "texture"
			expressions = [e]

		"Output":
			_process_output_node(node)
		
		"Texture":
			var tex_exp = _get_input_expression(node, 0)
			if tex_exp != null:
				var uv_exp = _get_input_expression_or_default(node, 1, "vec2")
				var e = Expr.new()
				e.code = str("texture(", tex_exp.code, ", ", uv_exp.code, ")")
				e.type = "vec4"
				expressions = [e]
			else:
				var e = Expr.new()
				e.code = _var_to_shader(Color())
				e.type = "vec4"
				expressions = [e]
		
		"Construct":
			var e0 = _get_input_expression_or_default(node, 0, "float")
			var e1 = _get_input_expression_or_default(node, 1, "float")
			var e2 = _get_input_expression_or_default(node, 2, "float")
			var e3 = _get_input_expression_or_default(node, 3, "float")
			e0 = _autocast(e0, "float")
			e1 = _autocast(e1, "float")
			e2 = _autocast(e2, "float")
			e3 = _autocast(e3, "float")
			var e = Expr.new()
			e.code = str("vec4(", e0.code, ", ", e1.code, ", ", e2.code, ", ", e3.code, ")")
			e.type = "vec4"
			expressions = [e]
		
		"Separate":
			var e = _get_input_expression_or_default(node, 0, "vec4")
			var e0 = Expr.new()
			var e1 = Expr.new()
			var e2 = Expr.new()
			var e3 = Expr.new()
			e0.code = str(e.code, ".x")
			e1.code = str(e.code, ".y")
			e2.code = str(e.code, ".z")
			e3.code = str(e.code, ".w")
			e0.type = "float"
			e1.type = "float"
			e2.type = "float"
			e3.type = "float"
			expressions = [e0, e1, e2, e3]
		
		_:
			var type = NodeDefs.get_type_by_name(node_type_name)
			expressions = type.compile(context)
	
	return expressions


func _process_output_node(node):
	# TODO Handle composition nodes with more than one input
	var a_exp = _get_input_expression_or_default(node, 0, "vec4")
	var e = _autocast(a_exp, "vec4") #node_type.inputs[0].type
	_statements.append(str("COLOR = ", e.code, ";"))


func _get_param_code(node, param_name):
	var v = node.data.params[param_name]
	return _var_to_shader(v)
#	var e = Expr.new()
#	e.code = _var_to_shader(v)
#	e.type = _var_to_type(v)
#	return e


func _get_input_default_expression(node, input_index, data_type):
	
	var node_type = NodeDefs.get_type_by_name(node.data.type)
	var input_def = node_type.inputs[input_index]
	var params = node.data.params
	
	var v
	if params.has(input_def.name) and params[input_def.name] != null:
		v = params[input_def.name]
	elif input_def.has("default"):
		v = input_def.default
	else:
		v = _scalar_type_defaults[data_type]
		
	var e = Expr.new()
	e.code = _var_to_shader(v)
	
#	if data_type == "float":
#		# TODO Not pretty
#		e.code = "1.0" if int(v) == 1 else "0.0"
#	elif data_type == "vec4" and v == 0:
#		e.code = "vec4(0.0, 0.0, 0.0, 1.0)"
#	else:
#		e.code = str(data_type, "(", v, ")")

	e.type = data_type
	e.composite = false
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


func _autocast_pair(e1, e2):
	
	if e1.type == e2.type:
		return [e1, e2]
	
	var e1_dim = _get_type_dimension(e1.type)
	var e2_dim = _get_type_dimension(e2.type)
		
	# The type of larger dimension wins
	if e1_dim < e2_dim:
		e1 = _autocast(e1, e2.type)
	else:
		e2 = _autocast(e2, e1.type)
	
	return [e1, e2]


static func _get_type_dimension(type):
	if _scalar_type_dimension.has(type):
		return _scalar_type_dimension[type]
	assert(type == "texture")
	return 4


func _autocast(e, dst_type):
	
	assert(_is_scalar_type(dst_type))
	
	if e.type == dst_type:
		return e
	
	e = e.duplicate()
	# TODO If an expression isn't primitive, store in a var to avoid repeating it
	
	# TODO This is a fallback, normally such things would fail
	if not _is_scalar_type(e.type):
		if e.type == "texture":
			e.code = str("texture(", e.code, ", UV)")
			e.type = "vec4"
	
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


func _generate_var_name():
	var vn = str("v", _next_var_id)
	_next_var_id += 1
	return vn


func _get_full_code():
	var lines = [
		"shader_type canvas_item;",
		""
	]
	
	if len(_texture_uniforms) > 0:
		for node_id in _texture_uniforms:
			var uniform_name = _texture_uniforms[node_id]
			lines.append(str("uniform sampler2D ", uniform_name, ";"))
		lines.append("")
	
	lines.append("void fragment() {")
	for statement in _statements:
		lines.append(str("\t", statement))
	lines.append("}")
	lines.append("")
	
	return PoolStringArray(lines).join("\n")


static func _var_to_shader(v, no_alpha=false):

	match typeof(v):

		TYPE_REAL:
			if int(v) == v:
				return str(v, ".0")
			else:
				return str(v)

		TYPE_INT:
			return str(v, ".0")

		TYPE_VECTOR2:
			return str("vec2(", \
				_var_to_shader(v.x), ", ", \
				_var_to_shader(v.y), ")")

		TYPE_VECTOR3:
			return str("vec3(", \
				_var_to_shader(v.x), ", ", \
				_var_to_shader(v.y), ", ", \
				_var_to_shader(v.z), ")")

		TYPE_COLOR:
			if no_alpha:
				return _var_to_shader(Vector3(v.r, v.g, v.b))
			return str("vec4(", \
				_var_to_shader(v.r), ", ", \
				_var_to_shader(v.g), ", ", \
				_var_to_shader(v.b), ", ", \
				_var_to_shader(v.a), ")")


#static func _var_to_type(v):
#	match typeof(v):
#		TYPE_REAL:
#			return "float"
#		TYPE_INT:
#			return "int"
#		TYPE_VECTOR2:
#			return "vec2"
#		TYPE_VECTOR3:
#			return "vec3"
#		TYPE_COLOR:
#			return "vec4"
#		TYPE_OBJECT:
#			if v is Texture:
#				return "sampler2D"
		

static func _is_scalar_type(type):
	return _scalar_type_dimension.has(type)


static func _get_texture_uniform_name(index):
	return str("u_input_texture_", index)



const NodeDefs = preload("./node_defs.gd")
const GraphEvaluator = preload("./compiler_graph_evaluator.gd")

const _scalar_type_dimension = {
	"float": 1,
	"vec2": 2,
	"vec3": 3,
	"vec4": 4,
	"int": 1
}

const _scalar_type_defaults = {
	"float": 0.0,
	"vec2": Vector2(),
	"vec3": Vector3(),
	"vec4": Color(),
	"int": 0
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
	var uniform_name = ""
	var composition_node_id = -1
	var render_step_index = -1
	var file_path = ""
	
#	func duplicate():
#		var ts = get_script().new()
#		ts.uniform_name = uniform_name
#		ts.composition_node_id = composition_node_id
#		ts.render_step_index = render_step_index
#		ts.file_path = file_path
#		return ts


class _NodeCompilerContext:
	
	var node
	var _compiler
	var _internal_texture_dir = ""
	
	func _init(compiler, internal_tex_dir):
		_compiler = compiler
		_internal_texture_dir = internal_tex_dir
	
	func create_expression(code, type):
		var e = Expr.new()
		e.code = code
		e.type = type
		return e

	func get_input_expression(index):
		return _compiler._get_input_expression(node, index)
	
	func get_input_expression_or_default(index, data_type):
		return _compiler._get_input_expression_or_default(node, index, data_type)

	func get_param_code(param_name):
		return _compiler._get_param_code(node, param_name)

	func autocast_pair(a, b):
		return _compiler._autocast_pair(a, b)

	func autocast(a, dst_type):
		return _compiler._autocast(a, dst_type)
	
	func var_to_shader(v):
		return _compiler._var_to_shader(v)
	
	func require_function(fname, code):
		_compiler._require_function(fname, code)
	
	func require_texture_from_file(fpath):
		var ts = _compiler._require_texture_from_file(fpath)
		return ts.uniform_name

	func require_texture_from_internal(fname):
		var fpath = _internal_texture_dir.plus_file(fname)
		var ts = _compiler._require_texture_from_file(fpath)
		return ts.uniform_name


class _Function:
	var name = ""
	var code = ""


# Read-only graph
var _graph = null

# All statements gathered so far
var _statements = []

# node id => [output expressions]
var _expressions = {}

var _texture_uniforms = []

var _functions = []

var _next_var_id = 0
var _internal_texture_dir = ""


func _init(graph):
	_graph = graph
	_internal_texture_dir = \
		get_script().resource_path.get_base_dir().plus_file("textures")


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
	_functions.clear()
	
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
					_statements.append( \
						str(prev_exp.type, " ", var_name, " = ", prev_exp.code, ";"))
					
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
		# TODO This is a deep duplication, 
		# however I don't want resources to be duped... careful
		rs.composition = last_node.data.duplicate(true)
	
	_process_output_node(last_node)
	
	rs.shader_code = _get_full_code()
	rs.shader = Shader.new()
	rs.shader.code = rs.shader_code
	
	for ts in _texture_uniforms:
		if ts.composition_node_id != -1:
			ts.render_step_index = node_pass_indexes[ts.composition_node_id]
		rs.texture_uniforms[ts.uniform_name] = ts
	
	return rs


func _require_texture_from_node_output(node_id):
	for ts in _texture_uniforms:
		if ts.composition_node_id == node_id:
			return ts
	var ts = TextureSource.new()
	ts.composition_node_id = node_id
	ts.uniform_name = _get_texture_uniform_name(len(_texture_uniforms))
	_texture_uniforms.append(ts)
	return ts


func _require_texture_from_file(texture_path):
	for ts in _texture_uniforms:
		if ts.file_path == texture_path:
			return ts
	var ts = TextureSource.new()
	ts.file_path = texture_path
	ts.uniform_name = _get_texture_uniform_name(len(_texture_uniforms))
	_texture_uniforms.append(ts)
	return ts


func _process_node(node):
	var node_type_name = node.data.type
	var node_type = NodeDefs.get_type_by_name(node_type_name)
	
	if node_type.family == "composition":
		# TODO This may eventually be the same code for each compo output
		var ts = _require_texture_from_node_output(node.id)
		var e = Expr.new()
		# The output is straight the sampler name
		e.code = ts.uniform_name
		e.type = "texture"
		e.composite = false
		return [e]
	
	elif node_type_name == "Output":
		_process_output_node(node)
		return null
	
	var context = _NodeCompilerContext.new(self,_internal_texture_dir)
	context.node = node
	
	return node_type.compile(context)


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
		# TODO Why `data_type` had to be passed here? Can't we use `input_def.type`?
		v = _scalar_type_defaults[data_type]
		
	var e = Expr.new()
	if typeof(v) != TYPE_STRING:
		e.code = _var_to_shader(v)
	else:
		e.code = v
	
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


func _to_scalar(e):
	if _is_scalar_type(e.type):
		return e
	if e.type == "texture":
		# Automatic sampling using default UV.
		# Custom UVs requires to manually have a TextureCoordinates node.
		e.type = "vec4"
		e.code = str("texture(", e.code, ", UV)")
	else:
		printerr("_to_scalar called with non-convertible type")
	return e


func _autocast_pair(e1, e2):
	
	# A binop with two variables must be scalar
	e1 = _to_scalar(e1)
	e2 = _to_scalar(e2)

	if e1.type == e2.type:
		return [e1, e2]
	
	var e1_dim = _get_type_dimension(e1.type)
	var e2_dim = _get_type_dimension(e2.type)
		
	# The type of larger dimension wins
	if e1_dim < e2_dim:
		e1 = _autocast(e1, e2.type)
	elif e2_dim > e1_dim:
		e2 = _autocast(e2, e1.type)
	else:
		if e1.type == "int":
			e1 = _autocast(e1, e2.type)
		elif e2.type == "int":
			e2 = _autocast(e2, e1.type)
		else:
			e2 = _autocast(e2, e1.type)
	
	return [e1, e2]


static func _get_type_dimension(type):
	if _scalar_type_dimension.has(type):
		return _scalar_type_dimension[type]
	assert(type == "texture")
	return 4


func _autocast(e, dst_type):
	
	# Cannot cast to something not scalar
	assert(_is_scalar_type(dst_type))
	
	if e.type == dst_type:
		return e
	
	e = e.duplicate()
	# TODO If an expression isn't primitive, store in a var to avoid repeating it
	
	e = _to_scalar(e)
	
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
					
	elif src_dim > dst_dim:
		var s = _scalar_type_members.substr(0, dst_dim)
		e.code = str("(", e.code, ").", s)
	
	else:
		e.code = str(dst_type, "(", e.code, ")")
		
	e.type = dst_type
	return e


func _generate_var_name():
	var vn = str("v", _next_var_id)
	_next_var_id += 1
	return vn


func _require_function(fname, code):
	for f in _functions:
		if f.name == fname:
			return
	var f = _Function.new()
	f.name = fname
	f.code = code
	_functions.append(f)


func _get_full_code():
	var lines = [
		"shader_type canvas_item;",
		""
	]
	
	if len(_texture_uniforms) > 0:
		for ts in _texture_uniforms:
			lines.append(str("uniform sampler2D ", ts.uniform_name, ";"))
		lines.append("")
	
	for f in _functions:
		lines.append(f.code)
		#lines.append("")
	
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
			return str(v)

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


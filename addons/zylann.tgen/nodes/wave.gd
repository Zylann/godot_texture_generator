
const family = "operation"
const category = "Shapes"

const inputs = [
	{"name": "in", "type": "scalar", "default": 0}
]

const params = [
	{"name": "frequency", "type": "float", "default": 10.0},
	{"name": "offset", "type": "float", "default": 0.0}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func compile(ctx):
	var a_exp = ctx.get_input_expression_or_default(0, "float")
	var offset = ctx.get_param_code("offset")
	var freq = ctx.get_param_code("frequency")
	# TODO Wave type: triangle, square, sine, saw
	# 0.5*cos(o+f*x*TAU+PI)+0.5
	var code = str("0.5 + 0.5 * cos(", offset, " + ", freq, " * ", \
		a_exp.get_code_for_op(), " * ", TAU, " + ", PI, ")")
	var e = ctx.create_expression(code, a_exp.type)
	return [e]

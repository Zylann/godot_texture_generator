
const family = "operation"
const category = "Math"

const inputs = [
	{"name": "in", "type": "scalar", "default": 0}
]

const params = [
	{"name": "min", "type": "float", "default": 0.0},
	{"name": "max", "type": "float", "default": 1.0}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func compile(ctx):
	var a_exp = ctx.get_input_expression_or_default(0, "float")
	var minv = ctx.get_param_code("min")
	var maxv = ctx.get_param_code("max")
	var e = ctx.create_expression(str("clamp(", a_exp.code, ", ", minv, ", ", maxv, ")"), a_exp.type)
	return [e]

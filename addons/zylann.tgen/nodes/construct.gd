
const family = "operation"
const category = "Vector"

const inputs = [
	{"name": "x", "type": "float", "default": 0.0},
	{"name": "y", "type": "float", "default": 0.0},
	{"name": "z", "type": "float", "default": 0.0},
	{"name": "w", "type": "float", "default": 1.0}
]

const params = []

const outputs = [
	{"name": "v", "type": "vec4"}
]

static func compile(ctx):
	var e0 = ctx.get_input_expression_or_default(0, "float")
	var e1 = ctx.get_input_expression_or_default(1, "float")
	var e2 = ctx.get_input_expression_or_default(2, "float")
	var e3 = ctx.get_input_expression_or_default(3, "float")
	e0 = ctx.autocast(e0, "float")
	e1 = ctx.autocast(e1, "float")
	e2 = ctx.autocast(e2, "float")
	e3 = ctx.autocast(e3, "float")
	var code = str("vec4(", e0.code, ", ", e1.code, ", ", e2.code, ", ", e3.code, ")")
	return [ctx.create_expression(code, "vec4")]

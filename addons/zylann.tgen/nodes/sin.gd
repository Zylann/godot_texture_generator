
const family = "operation"
const category = "Math"

const inputs =  [
	{"name": "in", "type": "scalar", "default": 0}
]

const params = []

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func compile(ctx):
	var a_exp = ctx.get_input_expression_or_default(0, "float")
	var e = ctx.create_expression(str("sin(", a_exp.code, ")"), a_exp.type)
	return [e]

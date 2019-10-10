
const family = "operation"
const category = "Math"

const inputs = [
	{"name": "a", "type": "scalar", "default": 1},
	{"name": "b", "type": "scalar", "default": 1}
]

const params = []

const outputs = [
	{"name": "out", "type": "scalar"}
]


static func compile(ctx):
	var a_exp = ctx.get_input_expression_or_default(0, "float")
	var b_exp = ctx.get_input_expression_or_default(1, "float")
	var ie = ctx.autocast_pair(a_exp, b_exp)
	var e = ctx.create_expression(str(ie[0].get_code_for_op(), " * ", ie[1].get_code_for_op()), ie[0].type)
	return [e]


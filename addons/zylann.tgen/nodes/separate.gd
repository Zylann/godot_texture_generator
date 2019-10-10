
const family = "operation"
const category = "Vector"

const inputs = [
	{"name": "v", "type": "vec4"}
]

const params = []

const outputs = [
	{"name": "x", "type": "float"},
	{"name": "y", "type": "float"},
	{"name": "z", "type": "float"},
	{"name": "w", "type": "float"}
]
		
static func compile(ctx):
	var e = ctx.get_input_expression_or_default(0, "vec4")
	var e0 = ctx.create_expression(str(e.get_code_for_op(), ".x"), "float")
	var e1 = ctx.create_expression(str(e.get_code_for_op(), ".y"), "float")
	var e2 = ctx.create_expression(str(e.get_code_for_op(), ".z"), "float")
	var e3 = ctx.create_expression(str(e.get_code_for_op(), ".w"), "float")
	return [e0, e1, e2, e3]

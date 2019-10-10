
const family = "input"
const category = "Input"

const inputs = []
const params = []

const outputs = [
	{"name": "uv", "type": "vec2"}
]

static func compile(context):
	var e = context.create_expression("UV", "vec2")
	e.composite = false
	return [e]


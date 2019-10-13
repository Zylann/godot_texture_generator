
const ErodeShader = preload("./../shaders/erode.shader")

const family = "composition"
const category = "Effects"

const inputs = [
	{"name": "in", "type": "vec4", "default": 0}
]

const params = [
	{"name": "amount", "type": "int", "default": 3},
	{"name": "weight", "type": "float", "default": 0.5}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func process_composition(ctx):
	
	var amount = ctx.get_param("amount")
	
	if ctx.iteration < amount:
		var mat = ctx.material
		mat.shader = ErodeShader
		mat.set_shader_param("u_weight", ctx.get_param("weight"))
		return false
	
	return true




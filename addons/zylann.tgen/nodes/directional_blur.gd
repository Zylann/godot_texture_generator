
const BlurShader = preload("./../shaders/directional_blur.shader")

const family = "composition"
const category = "Effects"

const inputs = [
	{"name": "in", "type": "vec4", "default": 0}
]

const params = [
	{"name": "amount", "type": "int", "default": 10},
	{"name": "angle", "type": "float", "default": 0.0}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func process_composition(ctx):
	
	if ctx.iteration == 0:
		var mat = ctx.material
		mat.shader = BlurShader
		mat.set_shader_param("u_amount", ctx.get_param("amount"))
		mat.set_shader_param("u_angle", deg2rad(ctx.get_param("angle")))
		return false
	
	return true




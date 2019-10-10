
const BlurShader = preload("./../blur.shader")

const family = "composition"
const category = "Effects"

const inputs = [
	{"name": "in", "type": "vec4", "default": 0}
]

const params = [
	{"name": "r", "type": "int", "default": 10.0}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func process_composition(ctx):
	var mat = ctx.material
	
	if ctx.iteration == 0:
		mat.shader = BlurShader
		mat.set_shader_param("u_orientation", 0.0)
		mat.set_shader_param("u_amount", ctx.get_param("r"))
		return false
		
	elif ctx.iteration == 1:
		mat.set_shader_param("u_orientation", 1.0)
		return false
	
	return true


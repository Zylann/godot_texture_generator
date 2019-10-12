
const BumpToNormalShader = preload("./../bump_to_normal.shader")

const family = "composition"
const category = "Effects"

const inputs = [
	{"name": "in", "type": "vec4", "default": 0}
]

const params = [
	{"name": "strength", "type": "float", "default": 1.0}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

static func process_composition(ctx):
	
	if ctx.iteration == 0:
		var mat = ctx.material
		mat.shader = BumpToNormalShader
		mat.set_shader_param("u_strength", ctx.get_param("strength"))
		return false
		
	return true


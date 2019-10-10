
const family = "operation"
const category = "Texture"

const inputs = [
	# TODO Texture can optionally come from a previous pass, otherwise will be taken from param
	{"name": "texture", "type": "Texture", "default": null},
	{"name": "uv", "type": "vec2"}
]

const params = []

const outputs = [
	{"name": "color", "type": "vec4"}
]

static func compile(ctx):
	var tex_exp = ctx.get_input_expression(0)
	if tex_exp != null:
		var uv_exp = ctx.get_input_expression_or_default(1, "vec2")
		var e = ctx.create_expression(str("texture(", tex_exp.code, ", ", uv_exp.code, ")"), "vec4")
		return [e]
	else:
		var e = ctx.create_expression(ctx.var_to_shader(Color()), "vec4")
		return [e]


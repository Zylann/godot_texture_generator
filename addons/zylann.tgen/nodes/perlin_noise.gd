
const family = "operation"
const category = "Shapes"

const inputs = [
	{"name": "uv", "type": "vec2", "default": "UV"}
]

const params = [
	{"name": "octaves", "type": "int", "default": 4},
	{"name": "period", "type": "float", "default": 32.0},
	{"name": "roughness", "type": "float", "default": 0.5},
	# TODO Implementation isn't great for seeds higher than 1000
	{"name": "seed", "type": "int", "default": 42}
]

const outputs = [
	{"name": "out", "type": "scalar"}
]

const _get_noise_code = """
float get_noise(vec2 uv) {

	vec2 ts = vec2(textureSize(u_noise_texture, 0));
	//vec2 ps = 1.0 / ts;

	vec2 puv = uv * ts;

	float c00 = texture(u_noise_texture, floor(puv) / ts).r;
	float c10 = texture(u_noise_texture, floor(puv + vec2(1.0, 0.0)) / ts).r;
	float c01 = texture(u_noise_texture, floor(puv + vec2(0.0, 1.0)) / ts).r;
	float c11 = texture(u_noise_texture, floor(puv + vec2(1.0, 1.0)) / ts).r;

	vec2 fuv = fract(puv);

	//return mix(mix(c00, c01, fuv.y), mix(c10, c11, fuv.y), fuv.x);

	vec2 u = fuv * fuv * (3.0 - 2.0 * fuv);
	return mix(c00, c10, u.x) + (c01 - c00) * u.y * (1.0 - u.x) + (c11 - c10) * u.x * u.y;

	// Normally, the filter offered by OpenGL should have done the job,
	// but for some reason it has 8-bit quality results, despite the texture being 32bit,
	// which produce aliasing when calculating normals...
	// something must be wrong between my driver and Godot
	//return texture(u_noise_texture, uv).r;
}
"""

const _get_perlin_noise_code = """
float get_perlin_noise(vec2 uv, int octaves, float period, float roughness, int seed) {
	float scale = 1.0;
	float sum = 0.0;
	float amp = 0.0;
	float p = 1.0;
	
	uv /= period;
	
	for (int i = 0; i < octaves; ++i) {
		// Rotate and translate lookups to reduce directional artifacts
		vec2 vx = vec2(cos(float(i * 543)), sin(float(i * 543)));
		vec2 vy = vec2(-vx.y, vx.x);
		mat2 magic_rotation = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));//mat2(vx, vy);
		vec2 magic_offset = vec2(-0.113 * float(i + seed), 0.0538 * float(i - seed));
		
		sum += p * get_noise((magic_rotation * uv) * scale + magic_offset);
		amp += p;
		scale *= 2.0;
		p *= roughness;
	}

	float gs = sum / amp;
	return gs;
}
"""


static func compile(ctx):

	var noise_tex_name = ctx.require_texture_from_internal("noise.exr")
	# TODO Maybe allow fixed-name textures?
	ctx.require_function("get_noise", \
		_get_noise_code.replace("u_noise_texture", noise_tex_name))
	ctx.require_function("get_perlin_noise", _get_perlin_noise_code)
	
	var uv_exp = ctx.get_input_expression_or_default(0, "vec2")
	uv_exp = ctx.autocast(uv_exp, "vec2")

	var octaves = ctx.get_param_code("octaves")
	var roughness = ctx.get_param_code("roughness")
	var period = ctx.get_param_code("period")
	var pseed = ctx.get_param_code("seed")
	
	var e = ctx.create_expression(str("get_perlin_noise(",\
		uv_exp.code, ", ", \
		octaves, ", ", \
		period, ", ", \
		roughness, ", ", \
		pseed, ")"),
		"float")

	return [e]


shader_type canvas_item;

uniform float u_strength = 1.0;

vec4 pack_normal(vec3 n) {
	return vec4((0.5 * (n + 1.0)).xzy, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ps = SCREEN_PIXEL_SIZE;
	float left = texture(SCREEN_TEXTURE, uv + vec2(-ps.x, 0)).r * u_strength;
	float right = texture(SCREEN_TEXTURE, uv + vec2(ps.x, 0)).r * u_strength;
	float back = texture(SCREEN_TEXTURE, uv + vec2(0, -ps.y)).r * u_strength;
	float fore = texture(SCREEN_TEXTURE, uv + vec2(0, ps.y)).r * u_strength;
	vec3 n = normalize(vec3(left - right, 2.0, fore - back));
	COLOR = pack_normal(n);
}

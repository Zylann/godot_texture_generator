shader_type canvas_item;

uniform float u_orientation;
uniform float u_amount;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec2 s0 = mix(vec2(ps.x, 0.0), vec2(0.0, ps.y), u_orientation);
	vec2 s = s0;
	
	vec4 col = texture(SCREEN_TEXTURE, uv);
	
	for (float i = 0.0; i < u_amount; ++i) {
		col += texture(SCREEN_TEXTURE, uv - s);
		col += texture(SCREEN_TEXTURE, uv + s);
		s += s0;
	}
	
	COLOR = col / (1.0 + 2.0 * u_amount);
}

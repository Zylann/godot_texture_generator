shader_type canvas_item;

uniform float u_angle;
uniform float u_amount;

float curve(float x) {
	// Gaussian approximation
	return max(1.1 / (x * 4.0 + 1.0) - 0.1, 0.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec2 s0 = vec2(cos(u_angle), sin(u_angle)) * ps;
	vec2 s = s0;
	float sum = 1.0;
	float ia = 1.0 / u_amount;
	
	vec4 col = texture(SCREEN_TEXTURE, uv);
	
	for (float i = 0.0; i < u_amount; ++i) {
		float k = curve(i * ia);
		col += k * texture(SCREEN_TEXTURE, uv - s);
		col += k * texture(SCREEN_TEXTURE, uv + s);
		sum += 2.0 * k;
		s += s0;
	}
	
	COLOR = col / sum;
}

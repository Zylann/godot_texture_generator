shader_type canvas_item;

uniform float u_radius;

float curve(float x) {
	// Gaussian approximation
	return max(1.1 / (x * 4.0 + 1.0) - 0.1, 0.0);
}

float length_sq(vec2 v) {
	return v.x * v.x + v.y * v.y;
}

void fragment() {
	// TODO Optimize, wrote this quite plainly
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	float r = u_radius;
	float ir = 1.0 / r;
	vec4 col = vec4(0,0,0,0);
	float sum = 0.0;
	for (float i = -r; i < r; ++i) {
		for (float j = -r; j < r; ++j) {
			float d = length_sq(vec2(i, j) * ir);
			float k = curve(d);
			col += k * texture(SCREEN_TEXTURE, uv + vec2(i, j) * ps);
			sum += k;
		}
	}
	COLOR = col / sum;
}
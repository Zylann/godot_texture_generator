shader_type canvas_item;

uniform float u_min = 0.0;
uniform float u_max = 1.0;

void fragment() {
	COLOR = (texture(TEXTURE, UV) - vec4(u_min)) / vec4(u_max - u_min);
}

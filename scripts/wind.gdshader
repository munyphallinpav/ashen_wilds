shader_type canvas_item;
// Gentle wind sway: the top of a sprite moves, the base stays planted. Phase depends on world position.
uniform float strength = 1.6;
uniform float speed = 1.5;
uniform float height = 32.0;

void vertex() {
	float h = clamp((4.0 - VERTEX.y) / height, 0.0, 1.0);
	vec2 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float ph = TIME * speed + wp.x * 0.045 + wp.y * 0.02;
	VERTEX.x += (sin(ph) + 0.5 * sin(ph * 2.3 + 1.7)) * strength * h * h;
}

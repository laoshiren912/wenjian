shader_type canvas_item;
render_mode unshaded;

uniform sampler2D stage : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 source = texture(stage, uv).rgb;
	float gray = dot(source, vec3(0.299, 0.587, 0.114));
	float pooled = smoothstep(0.07, 0.94, gray);
	float grain = fract(sin(dot(floor(uv / SCREEN_PIXEL_SIZE), vec2(12.9898, 78.233))) * 43758.5453);
	float vignette = smoothstep(0.17, 0.73, length((uv - vec2(0.50, 0.46)) * vec2(1.0, 1.12)));
	float ink = clamp((0.06 + gray * 0.49 + pooled * 0.14 + (grain - 0.5) * 0.037) * (1.0 - vignette * 0.67), 0.0, 1.0);
	COLOR = vec4(mix(source, vec3(ink), amount), 1.0);
}

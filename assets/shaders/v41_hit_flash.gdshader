shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), clamp(hurt_flash, 0.0, 1.0));
}

shader_type canvas_item;
render_mode unshaded;

uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), hurt_flash);
}

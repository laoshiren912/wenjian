shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;
uniform float brightness_boost : hint_range(0.8, 1.6) = 1.20;

void fragment() {
	vec4 tex = texture(TEXTURE, UV) * COLOR;
	if (tex.a < 0.05) {
		discard;
	}
	vec3 rgb = tex.rgb;
	// 保留纯黑/极暗像素描边锐度，对非描边中亮部提亮约 18~20%，提升敌人在暗色地面上的轮廓辨识度
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	float lift_mask = smoothstep(0.07, 0.16, luma);
	vec3 brightened = clamp(rgb * brightness_boost + vec3(0.032, 0.028, 0.024), 0.0, 1.0);
	rgb = mix(rgb, brightened, lift_mask);
	rgb = mix(rgb, vec3(1.0, 0.99, 0.96), hurt_flash);
	COLOR = vec4(rgb, tex.a);
}

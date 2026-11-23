shader_type canvas_item;
render_mode unshaded, blend_mix;

// 0..1 受击纯白闪白
uniform float hurt_flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.05) {
		discard;
	}
	vec3 rgb = tex.rgb;
	float luma = dot(rgb, vec3(0.299, 0.587, 0.114));
	float max_c = max(rgb.r, max(rgb.g, rgb.b));
	float min_c = min(rgb.r, min(rgb.g, rgb.b));
	float sat = (max_c > 0.001) ? (max_c - min_c) / max_c : 0.0;

	// 将原剑客蓝白衣袍重映射为“玄铁深黑 + 鎏金甲纹 + 赤红仙煞”守庭者配色
	vec3 remapped = rgb;
	bool is_blue = (rgb.b > rgb.r * 1.08 && rgb.b > rgb.g * 0.96 && sat > 0.16);
	bool is_warm = (rgb.r > rgb.b * 1.18 && rgb.g > rgb.b * 0.95 && sat > 0.18);
	bool is_bright_cloth = (luma > 0.62 && sat < 0.25);

	if (is_blue) {
		// 蓝袍/束发 -> 深玄铁青紫带赤金煞边（提亮避免黑成一团）
		remapped = mix(vec3(0.18, 0.16, 0.24), vec3(0.68, 0.26, 0.24), smoothstep(0.18, 0.72, luma));
	} else if (is_warm) {
		// 金饰/肤色 -> 明亮古铜鎏金与赤金甲纹
		remapped = mix(vec3(0.68, 0.40, 0.20), vec3(1.0, 0.88, 0.46), smoothstep(0.20, 0.80, luma));
	} else if (is_bright_cloth) {
		// 白衣/钢刃 -> 亮银玄钢带暖金高光
		remapped = mix(vec3(0.36, 0.34, 0.40), vec3(1.0, 0.92, 0.70), smoothstep(0.55, 0.94, luma));
	} else {
		// 暗部描边 -> 保留清晰度，取消过度乘法压暗
		float outline_keep = smoothstep(0.06, 0.15, luma);
		remapped = mix(rgb, clamp(rgb * vec3(0.92, 0.86, 0.82) + vec3(0.03, 0.025, 0.025), 0.0, 1.0), outline_keep);
	}

	// 受击纯白高对比度闪白
	remapped = mix(remapped, vec3(1.0), clamp(hurt_flash, 0.0, 1.0));

	COLOR = vec4(remapped, tex.a * COLOR.a);
}

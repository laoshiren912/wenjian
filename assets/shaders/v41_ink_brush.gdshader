shader_type canvas_item;
render_mode unshaded;

// mode = 0: 封面柔和多层次水墨烟云托底
// mode = 1: 败北凌厉横向挥洒飞白水墨笔锋
uniform int mode = 0;
uniform float time_sec = 0.0;
uniform vec4 ink_color : source_color = vec4(0.03, 0.045, 0.06, 0.88);
uniform vec4 accent_color : source_color = vec4(0.86, 0.72, 0.42, 0.16);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = rot * p * 2.02 + vec2(13.7, 7.3);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	if (mode == 0) {
		// 柔和椭圆水墨烟云，中心略浓、边缘随 FBM 自然晕散，无任何硬几何边界
		vec2 d = (uv - vec2(0.50, 0.50)) * vec2(2.05, 2.35);
		float dist = length(d);
		float n1 = fbm(uv * vec2(4.2, 2.6) + vec2(time_sec * 0.03, -time_sec * 0.015));
		float n2 = fbm(uv * vec2(8.5, 5.2) - vec2(time_sec * 0.02, 0.0));
		float cloud = smoothstep(1.06, 0.14, dist + (n1 - 0.52) * 0.46 + (n2 - 0.5) * 0.18);
		float core = smoothstep(0.85, 0.08, dist + (n1 - 0.5) * 0.28);
		float alpha = clamp(cloud * 0.52 + core * 0.24, 0.0, 0.72) * ink_color.a;
		// 极淡暖金云气微辉
		float gold_glow = smoothstep(0.75, 0.10, length((uv - vec2(0.49, 0.50)) * vec2(2.2, 2.4))) * (0.45 + 0.55 * n2);
		vec3 col = mix(ink_color.rgb, accent_color.rgb, clamp(gold_glow * accent_color.a * 1.4, 0.0, 0.26));
		COLOR = vec4(col, alpha);
	} else {
		// 横向挥洒水墨飞白笔锋：左厚右收、中间浓墨、上下与笔尾带自然干笔飞白纹理
		float x = uv.x;
		float spine_y = 0.50 + sin(x * 3.2 - 0.5) * 0.035 - (x - 0.5) * 0.04;
		float thickness = mix(0.28, 0.075, smoothstep(0.18, 0.96, x)) * smoothstep(0.01, 0.14, x) * smoothstep(1.0, 0.86, x);
		float dy = abs(uv.y - spine_y);
		float brush_tex = fbm(vec2(uv.x * 5.0, uv.y * 26.0));
		float coarse = fbm(vec2(uv.x * 3.4, uv.y * 8.5));
		float edge_dist = dy / max(0.01, thickness + (coarse - 0.5) * 0.08);
		float body = smoothstep(1.15, 0.22, edge_dist + (brush_tex - 0.5) * 0.36);
		// 飞白干笔丝缕（越靠近笔尾与上下边缘越明显）
		float dry_bias = smoothstep(0.35, 0.95, x) * 0.45 + smoothstep(0.45, 1.0, edge_dist) * 0.35;
		float dry_cut = smoothstep(0.22 + dry_bias * 0.38, 0.66 + dry_bias * 0.22, brush_tex);
		float alpha = clamp(body * mix(1.0, dry_cut, 0.72), 0.0, 1.0) * ink_color.a;
		// 极轻外围水墨洇染晕开
		float wash = smoothstep(1.08, 0.18, length((uv - vec2(0.48, 0.50)) * vec2(2.05, 2.55)) + (coarse - 0.5) * 0.42);
		alpha = clamp(max(alpha, wash * 0.34), 0.0, 0.90);
		COLOR = vec4(ink_color.rgb, alpha);
	}
}

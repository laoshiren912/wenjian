shader_type canvas_item;
render_mode unshaded, blend_mix;

// 0 = 横扫扇区像素预警, 1 = 横扫赤金罡风刀光, 2 = 直线突进像素预警, 3 = 直线突进赤金罡风尾焰
uniform int mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float half_arc = 1.32;
uniform float pixel_grid = 96.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 q_uv = (cell + vec2(0.5)) / pixel_grid;

	if (mode == 0) {
		// === 横扫扇区像素地面预警 ===
		vec2 p = (q_uv - vec2(0.5)) * 2.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		if (r > 0.98 || abs(ang) > half_arc) {
			discard;
		}
		float edge_r = step(0.91, r);
		float edge_a = step(half_arc - 0.05, abs(ang)) * step(0.12, r);
		float sweep_fill = step(r, mix(0.16, 0.96, progress));
		float pulse_ring = step(abs(r - mix(0.16, 0.94, progress)), 0.045);
		float inner_grid = step(0.88, fract(r * 6.0)) * 0.35;

		float alpha = 0.16 + sweep_fill * 0.22 + max(edge_r, edge_a) * 0.45 + pulse_ring * 0.38 + inner_grid;
		alpha *= mix(0.65, 1.0, progress);
		vec3 col = mix(vec3(0.92, 0.24, 0.12), vec3(1.0, 0.72, 0.26), clamp(max(pulse_ring, max(edge_r, edge_a)), 0.0, 1.0));
		alpha = clamp(floor(alpha * 6.0 + 0.5) / 6.0, 0.0, 0.82);
		COLOR = vec4(col, alpha);
	} else if (mode == 1) {
		// === 横扫赤金罡风重斩刀光 ===
		vec2 p = (q_uv - vec2(0.5)) * 2.0;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float fade = 1.0 - smoothstep(0.10, 1.0, progress);
		float norm_a = abs(ang) / max(0.05, half_arc);
		if (norm_a > 1.0 || fade < 0.05) {
			discard;
		}
		float arch = cos(norm_a * 1.5707963);
		float r_outer = 0.95;
		float thick = mix(0.42, 0.14, progress) * (0.20 + 0.80 * arch);
		float r_inner = max(0.24, r_outer - thick);
		float band = step(r_inner, r) * step(r, r_outer);
		float core = step(r_outer - 0.08 * (0.3 + 0.7 * arch), r) * step(r, r_outer + 0.01);
		float rim = step(r_outer + 0.03, r) * step(r, r_outer + 0.065 * arch) * (1.0 - progress * 0.7);
		float n = hash21(vec2(floor(ang * 24.0), floor(r * 20.0)));
		float spark = step(r_inner - 0.08, r) * step(r, r_outer + 0.08) * step(0.94, n);

		float mask = max(band, max(rim, spark));
		if (mask < 0.1) {
			discard;
		}
		vec3 col = mix(vec3(0.88, 0.22, 0.12), vec3(1.0, 0.72, 0.28), clamp((r - r_inner) / max(0.01, r_outer - r_inner), 0.0, 1.0));
		col = mix(col, vec3(1.0, 0.96, 0.82), clamp(max(core, spark), 0.0, 1.0));
		float alpha = clamp(floor(mask * fade * 0.92 * 6.0 + 0.5) / 6.0, 0.0, 0.92);
		COLOR = vec4(col, alpha);
	} else if (mode == 2) {
		// === 直线突进像素走廊预警 ===
		// q_uv.x: 0(起手) -> 1(终点), q_uv.y: 0..1(走廊宽度)
		float edge_y = step(0.43, abs(q_uv.y - 0.5));
		float edge_x = step(0.95, q_uv.x) + step(q_uv.x, 0.03);
		float fill = step(q_uv.x, progress);
		// 前进箭头波纹
		float chevron = fract(q_uv.x * 5.0 - abs(q_uv.y - 0.5) * 1.4 - progress * 2.5);
		float arrow = step(0.76, chevron) * step(abs(q_uv.y - 0.5), 0.36);

		float alpha = 0.15 + fill * 0.24 + clamp(edge_y + edge_x, 0.0, 1.0) * 0.45 + arrow * 0.32;
		alpha *= mix(0.65, 1.0, progress);
		vec3 col = mix(vec3(0.95, 0.24, 0.12), vec3(1.0, 0.74, 0.28), clamp(max(edge_y, arrow), 0.0, 1.0));
		alpha = clamp(floor(alpha * 6.0 + 0.5) / 6.0, 0.0, 0.80);
		COLOR = vec4(col, alpha);
	} else {
		// === 直线突进赤金破空罡风尾焰（前尖破风、后拖流焰）===
		// q_uv.x: 0(尾端) -> 1(前方破风锋尖), q_uv.y: 0..1
		float dy = abs(q_uv.y - 0.5) * 2.0;
		float head_taper = smoothstep(1.0, 0.48, q_uv.x);
		float tail_taper = smoothstep(0.0, 0.36, q_uv.x);
		float cone = 0.88 * head_taper * (0.35 + 0.65 * tail_taper);
		float body = step(dy, cone) * smoothstep(0.05, 0.35, q_uv.x);
		float core = step(dy, cone * 0.42) * smoothstep(0.22, 0.85, q_uv.x);
		float n = hash21(vec2(floor(q_uv.x * 26.0 - progress * 18.0), floor(q_uv.y * 18.0)));
		float streak = step(dy, cone * 1.18) * step(0.70, n) * tail_taper;

		float mask = max(body * 0.85, streak * 0.65);
		if (mask < 0.08) {
			discard;
		}
		vec3 col = mix(vec3(0.88, 0.22, 0.12), vec3(1.0, 0.72, 0.24), q_uv.x);
		col = mix(col, vec3(1.0, 0.96, 0.84), core);
		float alpha = clamp(floor(mask * 6.0 + 0.5) / 6.0, 0.0, 0.88);
		COLOR = vec4(col, alpha);
	}
}

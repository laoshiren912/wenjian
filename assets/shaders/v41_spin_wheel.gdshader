shader_type canvas_item;
render_mode unshaded, blend_mix;

// 0 = 凡剑(亮银青), 1 = 御气(碧青炽白), 2 = 仙术成型(霜青炽银双层)
uniform int rank_stage = 0;
// 0 = 普通御剑旋斩, 1 = 持有【双星旋刃】交错双剑大光轮
uniform int twin_star = 0;
// 旋转相位（弧度）
uniform float spin_angle = 0.0;
// 出现/收剑整体强度 (0..1)
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// 像素网格密度
uniform float pixel_grid = 96.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 q_uv = (cell + vec2(0.5)) / pixel_grid;
	vec2 p = (q_uv - vec2(0.5)) * 2.0;

	float r = length(p);
	if (r > 0.98 || strength < 0.02) {
		discard;
	}
	float ang = atan(p.y, p.x);

	// 旋转风刃瓣数：普通 2 瓣对称月牙轮，双星旋刃 4 瓣交错大光轮
	float blades = (twin_star == 1) ? 4.0 : 2.0;
	float rel_a = fract((ang - spin_angle) / 6.2831853 * blades);
	// 每瓣头部锐利、尾部渐收的锯齿风刃
	float blade_tail = smoothstep(0.06, 0.92, rel_a);
	float saw = sin(rel_a * 3.14159265);

	// 外层霜青锯齿气浪环
	float outer_r = (twin_star == 1) ? 0.90 : 0.84;
	float outer_w = ((twin_star == 1) ? 0.20 : 0.16) * (0.28 + 0.72 * saw);
	float outer_ring = step(outer_r - outer_w, r) * step(r, outer_r + 0.03 * blade_tail) * blade_tail;

	// 外层边缘锐利高光锋线
	float outer_edge = step(outer_r - 0.035, r) * step(r, outer_r + 0.02 * blade_tail) * smoothstep(0.32, 0.96, rel_a);

	// 内层高亮炽银白剑刃残影环（逆相微错增强高速旋转感）
	float inner_a = fract((ang - spin_angle * 1.35 + 0.5) / 6.2831853 * 2.0);
	float inner_r = (twin_star == 1) ? 0.56 : 0.54;
	float inner_w = ((twin_star == 1) ? 0.12 : 0.10) * (0.35 + 0.65 * sin(inner_a * 3.14159265));
	float inner_ring = step(inner_r - inner_w, r) * step(r, inner_r) * smoothstep(0.15, 0.92, inner_a);

	// 双星旋刃额外外层星芒细环（更抓眼）
	float twin_rim = 0.0;
	if (twin_star == 1) {
		float rim_a = fract((ang + spin_angle * 0.8) / 6.2831853 * 4.0);
		twin_rim = step(0.92, r) * step(r, 0.965) * smoothstep(0.25, 0.90, rim_a);
	}

	// 稀疏旋转像素灵点
	float n = hash21(cell + vec2(floor(spin_angle * 6.0), 17.0));
	float sparks = step(0.45, r) * step(r, outer_r + 0.06) * step(0.968, n);

	// 三阶段色彩对齐左键三连：凡剑高对比银青 -> 御气碧青炽白 -> 仙术霜青炽银
	vec3 col_core;
	vec3 col_main;
	vec3 col_accent;
	if (rank_stage == 0) {
		col_core = vec3(1.0, 1.0, 1.0);
		col_main = vec3(0.72, 0.90, 0.98);
		col_accent = vec3(0.42, 0.76, 0.92);
	} else if (rank_stage == 1) {
		col_core = vec3(0.96, 1.0, 1.0);
		col_main = vec3(0.32, 0.92, 0.90);
		col_accent = vec3(0.16, 0.66, 0.78);
	} else {
		col_core = vec3(1.0, 1.0, 1.0);
		col_main = vec3(0.30, 0.85, 1.0);
		col_accent = vec3(0.58, 0.96, 1.0);
	}
	if (twin_star == 1) {
		// 双星旋刃在霜青主调上叠一抹亮金星芒
		col_accent = mix(col_accent, vec3(1.0, 0.90, 0.48), 0.55);
	}

	float alpha = 0.0;
	vec3 rgb = col_main;

	if (outer_ring > 0.0) {
		rgb = mix(col_accent, col_main, blade_tail);
		alpha = max(alpha, outer_ring * (twin_star == 1 ? 0.92 : 0.86));
	}
	if (twin_rim > 0.0) {
		rgb = mix(rgb, col_accent, twin_rim);
		alpha = max(alpha, twin_rim * 0.92);
	}
	if (inner_ring > 0.0) {
		rgb = mix(rgb, col_core, 0.90);
		alpha = max(alpha, inner_ring * 0.95);
	}
	if (outer_edge > 0.0) {
		rgb = mix(rgb, col_core, outer_edge * 0.92);
		alpha = max(alpha, outer_edge * 0.96);
	}
	if (sparks > 0.0) {
		rgb = col_core;
		alpha = max(alpha, sparks * 0.90);
	}

	alpha *= strength;
	if (alpha < 0.06) {
		discard;
	}
	alpha = clamp(floor(alpha * 7.0 + 0.5) / 7.0, 0.0, 0.96);
	COLOR = vec4(rgb, alpha);
}

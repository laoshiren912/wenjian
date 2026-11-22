shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float time_sec = 0.0;
uniform float active_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float burst_flash : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_grid = 76.0;

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 q_uv = (cell + vec2(0.5)) / pixel_grid;
	vec2 p = (q_uv - vec2(0.5)) * 2.0;

	// 俯视角轻微贴地透视压扁
	vec2 ep = vec2(p.x, p.y * 1.18);
	float r = length(ep);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(ep.y, ep.x);

	float breath = 0.84 + 0.16 * sin(time_sec * 3.4);

	// === 1. 外圈：暗金与霜青交织八角八卦符阵（缓慢顺时针旋转）===
	float outer_a = ang + time_sec * 0.42;
	float sector = 0.78539816; // PI / 4
	float local_a = mod(outer_a + 3.14159265 + sector * 0.5, sector) - sector * 0.5;
	float oct_r = r * cos(local_a);

	float outer_oct = step(0.80, oct_r) * step(oct_r, 0.87);
	float outer_ring = step(0.90, r) * step(r, 0.945);
	float rim_dots = step(0.84, r) * step(r, 0.895) * step(0.90, abs(cos(outer_a * 4.0)));

	// 八卦三爻像素纹
	int trigram = int(floor(mod(outer_a + 3.14159265 + sector * 0.5, 6.2831853) / sector));
	float tang_span = abs(local_a);
	float trigram_mask = 0.0;
	if (tang_span < 0.25) {
		float b0 = step(0.54, r) * step(r, 0.585);
		float b1 = step(0.625, r) * step(r, 0.67);
		float b2 = step(0.71, r) * step(r, 0.755);
		float g0 = ((trigram & 1) == 0) ? step(0.055, tang_span) : 1.0;
		float g1 = (((trigram >> 1) & 1) == 0) ? step(0.055, tang_span) : 1.0;
		float g2 = (((trigram >> 2) & 1) == 0) ? step(0.055, tang_span) : 1.0;
		trigram_mask = max(b0 * g0, max(b1 * g1, b2 * g2));
	}

	// === 2. 内圈：核心剑纹星阵（缓慢逆时针旋转）===
	float inner_a = ang - time_sec * 0.72;
	float inner_ring = step(0.41, r) * step(r, 0.465);
	float inner_sec = 1.5707963; // PI / 2
	float in_loc = mod(inner_a + 3.14159265 + inner_sec * 0.5, inner_sec) - inner_sec * 0.5;
	float sq_r = r * cos(in_loc);
	float inner_diamond = step(0.28, sq_r) * step(sq_r, 0.33);
	float core_cross = step(abs(sin(inner_a * 2.0)), 0.16) * step(r, 0.26);
	float core_orb = 1.0 - smoothstep(0.06, 0.16, r);

	// === 3. 边缘柔和地面微光融合 ===
	float ground_glow = (1.0 - smoothstep(0.18, 0.98, r)) * 0.30 * breath;

	// 配色：暗金 #e8c468 + 霜青 #5ef2e6 + 炽白核心
	vec3 col_gold = vec3(0.92, 0.77, 0.41);
	vec3 col_cyan = vec3(0.37, 0.95, 0.90);
	vec3 col_white = vec3(0.98, 1.0, 0.96);
	vec3 col_dormant = vec3(0.36, 0.44, 0.47);

	float gold_layer = clamp(max(outer_oct, max(trigram_mask, rim_dots)), 0.0, 1.0);
	float cyan_layer = clamp(max(outer_ring * 0.85, max(inner_ring, inner_diamond)), 0.0, 1.0);
	float core_layer = clamp(max(core_cross, core_orb), 0.0, 1.0);

	float line_mask = clamp(max(gold_layer, max(cyan_layer, core_layer)), 0.0, 1.0);

	// 激活与未激活平滑融合
	vec3 active_col = mix(col_cyan, col_gold, gold_layer * 0.88);
	active_col = mix(active_col, col_white, clamp(core_layer * 0.82 + burst_flash * 0.78, 0.0, 1.0));
	vec3 final_col = mix(col_dormant, active_col, active_ratio);

	float dormant_a = line_mask * 0.22;
	float active_a = clamp(line_mask * (0.86 * breath + burst_flash * 0.35) + ground_glow * (1.0 + burst_flash * 0.9), 0.0, 1.0);
	float alpha = mix(dormant_a, active_a, active_ratio);

	if (alpha < 0.03) {
		discard;
	}
	alpha = floor(alpha * 10.0 + 0.5) / 10.0;
	COLOR = vec4(final_col, alpha);
}

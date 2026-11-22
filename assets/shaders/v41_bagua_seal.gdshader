shader_type canvas_item;
render_mode unshaded, blend_mix;

// mode 0 = 阶段3重斩落点仙纹/八卦微光印记 (0.15s 一瞬即逝)
// mode 1 = 第三击命中/破防克制像素环形气浪 (空挥不触发)
uniform int effect_mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_grid = 56.0;
uniform vec4 primary_color : source_color = vec4(0.42, 0.90, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform float intensity = 1.0;

void fragment() {
	vec2 cell = floor(UV * pixel_grid);
	vec2 q_uv = (cell + vec2(0.5)) / pixel_grid;
	vec2 p = (q_uv - vec2(0.5)) * 2.0;

	// 俯视角轻微椭圆压扁（贴地感）
	vec2 ep = vec2(p.x, p.y * 1.18);
	float r = length(ep);
	float ang = atan(ep.y, ep.x);

	if (effect_mode == 0) {
		// === 阶段3：一瞬即逝的像素仙纹 / 八卦微光印记 ===
		// 极快显形(0..0.22) -> 短暂停留(0.22..0.55) -> 利落消散(0.55..1.0)
		float appear = smoothstep(0.0, 0.20, progress);
		float vanish = 1.0 - smoothstep(0.42, 1.0, progress);
		float env = appear * vanish * intensity;

		// 缓慢微旋增强仙阵灵动感
		float rot = progress * 0.28;
		float a = ang + rot;

		// 八边形灵阵外框距离场
		float sector = 0.78539816; // PI / 4
		float local_a = mod(a + 3.14159265 + sector * 0.5, sector) - sector * 0.5;
		float oct_r = r * cos(local_a);

		// 外八角细环 + 内圆环
		float outer_oct = step(0.76, oct_r) * step(oct_r, 0.83);
		float inner_ring = step(0.32, r) * step(r, 0.37);

		// 八卦三爻像素纹（8 个方位角扇区，每个扇区三条径向短横，按方位分阴阳爻）
		int trigram = int(floor(mod(a + 3.14159265 + sector * 0.5, 6.2831853) / sector));
		float tang_span = abs(local_a);
		float trigram_mask = 0.0;
		if (tang_span < 0.24) {
			// 三层爻半径
			float b0 = step(0.45, r) * step(r, 0.50);
			float b1 = step(0.55, r) * step(r, 0.60);
			float b2 = step(0.65, r) * step(r, 0.70);

			// 用位掩码决定每爻是阳爻(整条)还是阴爻(中间断开)
			float gap0 = ((trigram & 1) == 0) ? step(0.055, tang_span) : 1.0;
			float gap1 = (((trigram >> 1) & 1) == 0) ? step(0.055, tang_span) : 1.0;
			float gap2 = (((trigram >> 2) & 1) == 0) ? step(0.055, tang_span) : 1.0;
			trigram_mask = max(b0 * gap0, max(b1 * gap1, b2 * gap2));
		}

		// 中心四向剑印星芒
		float cross_star = (step(abs(ep.x), 0.045) * step(abs(ep.y), 0.22) + step(abs(ep.y), 0.045) * step(abs(ep.x), 0.22));
		cross_star = clamp(cross_star, 0.0, 1.0);

		float core_m = max(cross_star, inner_ring * 0.85);
		float shape = clamp(max(outer_oct, max(trigram_mask, core_m)), 0.0, 1.0);

		float alpha = shape * env * 0.72;
		if (alpha < 0.05) {
			discard;
		}
		vec3 col = mix(primary_color.rgb, core_color.rgb, clamp(core_m * 0.85 + (1.0 - progress) * 0.25, 0.0, 1.0));
		alpha = floor(alpha * 6.0 + 0.5) / 6.0;
		COLOR = vec4(col, alpha);
	} else {
		// === 第三击命中/破防落点：克制的像素环形气浪 ===
		float radius = mix(0.24, 0.90, pow(progress, 0.68));
		float width = mix(0.085, 0.030, progress);
		float outer_ring = step(radius - width, r) * step(r, radius);
		// 内侧紧随一道细次波
		float sub_r = radius - 0.13;
		float inner_wave = step(sub_r - 0.025, r) * step(r, sub_r) * (1.0 - progress);
		// 8 方向短气纹（轻微风压，非碎石）
		float spoke = step(0.93, abs(cos(ang * 4.0))) * step(radius - 0.07, r) * step(r, radius + 0.05);

		float mask = clamp(max(outer_ring, max(inner_wave * 0.6, spoke * 0.65)), 0.0, 1.0);
		float alpha = mask * (1.0 - smoothstep(0.25, 1.0, progress)) * intensity * 0.74;
		if (alpha < 0.05) {
			discard;
		}
		vec3 col = mix(primary_color.rgb, core_color.rgb, clamp(outer_ring * 0.65, 0.0, 1.0));
		alpha = floor(alpha * 6.0 + 0.5) / 6.0;
		COLOR = vec4(col, alpha);
	}
}

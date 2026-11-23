shader_type canvas_item;
render_mode unshaded, blend_mix;

// 0 = 凡剑(银白), 1 = 御气(青白流光), 2 = 仙术成型(霜青双层+炽银核)
uniform int rank_stage = 0;
// 0 = 第一击顺向横斩, 1 = 第二击反向斜挑回斩, 2 = 第三击厚重重斩
uniform int combo_slot = 0;
// 0..1 有效挥砍进度
uniform float slash_progress : hint_range(0.0, 1.0) = 0.5;
// 0..1 收招淡出进度 (0 = 未淡出, 1 = 完全消散)
uniform float fade_progress : hint_range(0.0, 1.0) = 0.0;
// 扇面半角 (弧度)
uniform float half_arc = 1.05;
// 像素对齐虚拟网格密度
uniform float pixel_grid = 112.0;
// 格挡弹刀反馈 (0..1)
uniform float block_recoil : hint_range(0.0, 1.0) = 0.0;
// 朝上挥砍时略降内侧遮挡感 (0..1)
uniform float behind_soften : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float band_mask(float x, float lo, float hi) {
	return step(lo, x) * step(x, hi);
}

void fragment() {
	// 像素网格量化：边缘与角色 Nearest 像素密度严格匹配
	vec2 cell = floor(UV * pixel_grid);
	vec2 q_uv = (cell + vec2(0.5)) / pixel_grid;
	vec2 p = (q_uv - vec2(0.5)) * 2.0;

	// 格挡弹开时略微回缩半径，体现弹刀感
	float recoil_scale = 1.0 - block_recoil * 0.14;
	p /= max(0.25, recoil_scale);

	// 姿态透视变换：一横（俯视扁长）、二回（反向斜挑交叉）、三劈（前冲厚重）
	vec2 sp = p;
	if (combo_slot == 0) {
		// 第一击顺向横斩：轻微前斜横切
		float tilt = 0.10;
		float ct = cos(tilt);
		float st = sin(tilt);
		sp = vec2(p.x * ct - p.y * st, p.x * st + p.y * ct);
		sp.y *= 1.08;
	} else if (combo_slot == 1) {
		// 第二击反向斜挑回斩：与第一击相反倾角，形成鲜明交叉连击轨迹
		float tilt = -0.32;
		float ct = cos(tilt);
		float st = sin(tilt);
		sp = vec2(p.x * ct - p.y * st, p.x * st + p.y * ct);
		sp.y *= 1.14;
	} else {
		// 第三击重斩：轻微纵向拉伸让重劈扇面更具压迫感
		sp.y *= 0.96;
	}

	float r = length(sp);
	float ang = atan(sp.y, sp.x);
	float fade = 1.0 - smoothstep(0.0, 1.0, fade_progress);

	float core_mask = 0.0;
	float body_mask = 0.0;
	float outer_aura = 0.0;
	float dual_rim = 0.0;
	float spark_mask = 0.0;
	float trail_grad = 0.0;

	if (combo_slot < 2) {
		// === 第一击(顺向锐利横斩) & 第二击(反向斜挑回斩) ===
		float dir_sign = (combo_slot == 0) ? 1.0 : -1.0;
		float prog = clamp(slash_progress, 0.0, 1.0);

		// 前沿迅速划出整条修长月牙弧线，尾沿大幅滞后形成飘逸长弧，末段与收招再快速收束
		float head_t = clamp(pow(prog, 0.52), 0.0, 1.0);
		float tail_t = clamp(pow(max(0.0, prog - 0.18) / 0.82, 1.75) * 0.45, 0.0, 0.55);
		if (fade_progress > 0.0) {
			head_t = 1.0;
			tail_t = clamp(mix(0.45, 0.98, pow(fade_progress, 0.78)), 0.0, 0.99);
		}

		float a_start = -half_arc * dir_sign;
		float a_end = half_arc * dir_sign;
		float head_a = mix(a_start, a_end, head_t);
		float tail_a = mix(a_start, a_end, tail_t);

		float span = max(0.18, abs(head_a - tail_a));
		float s = (ang - tail_a) * dir_sign / span;

		if (s >= 0.0 && s <= 1.0) {
			trail_grad = s;
			// 修长月牙轮廓：头部极锐利前冲收尖，中前部饱满，尾部流畅细尖收束
			float crescent = sin(pow(s, 0.78) * 3.14159265);
			float lead_curve = smoothstep(0.25, 0.94, s);

			// 紧贴剑尖半径（不留远程空隙）
			float base_r = (combo_slot == 0) ? 0.78 : 0.80;
			float r_outer = base_r + 0.06 * lead_curve - 0.10 * (1.0 - s) * (1.0 - s);

			// 凡剑窄利、御气适中、仙术饱满且加独立双层外轮廓
			float base_thick = (combo_slot == 0) ? 0.18 : 0.21;
			if (rank_stage == 1) {
				base_thick += 0.04;
			} else if (rank_stage == 2) {
				base_thick += 0.06;
			}
			float thick = base_thick * (0.14 + 0.86 * crescent) * (1.0 - fade_progress * 0.42);
			float r_inner = max(0.26, r_outer - thick);

			// 主刀光弧体
			float main_band = band_mask(r, r_inner, r_outer);
			body_mask = main_band * smoothstep(0.01, 0.22, s);

			// 亮刃锋：紧贴最外沿，头部锋利明亮
			float core_thick = mix(0.025, 0.062, lead_curve) * (0.25 + 0.75 * crescent) * (1.0 - fade_progress * 0.45);
			core_mask = band_mask(r, r_outer - core_thick, r_outer + 0.008) * smoothstep(0.14, 0.50, s);

			// 阶段 2（中期御气）：青白外沿轻盈灵气拖尾流光
			if (rank_stage >= 1) {
				float wave = sin(s * 20.0 - prog * 16.0) * 0.024;
				float aura_lo = r_inner - 0.075 + wave;
				float aura_hi = r_outer + 0.042 + wave * 0.5;
				float n = hash21(vec2(floor(s * 34.0), floor(r * 28.0) + float(combo_slot) * 11.0));
				float ribbon = band_mask(r, aura_lo, aura_hi) * (1.0 - main_band);
				outer_aura = ribbon * smoothstep(0.02, 0.62, s) * step(0.42, n + s * 0.30) * 0.76;

				// 零星灵气像素微点
				float p_noise = hash21(cell + vec2(float(combo_slot) * 19.0, floor(prog * 12.0)));
				float near_edge = band_mask(r, r_inner - 0.10, r_outer + 0.09);
				spark_mask = near_edge * step(0.962, p_noise) * smoothstep(0.06, 0.55, s);
			}

			// 阶段 3（后期仙术成型）：主锋外侧独立霜青双层剑气轮廓
			if (rank_stage == 2) {
				float gap = 0.045;
				float rim_w = 0.036 * (0.22 + 0.78 * crescent);
				float rim_lo = r_outer + gap;
				float rim_hi = rim_lo + rim_w;
				dual_rim = band_mask(r, rim_lo, rim_hi) * smoothstep(0.12, 0.40, s) * (1.0 - fade_progress * 0.55);
			}
		}
	} else {
		// === 第三击：独立宽厚重斩扇面轨迹（圆润深月牙宽劈，绝非平切盾牌）===
		float prog = clamp(slash_progress, 0.0, 1.0);
		float impact_start = 0.22;

		if (prog < impact_start && fade_progress <= 0.0) {
			// 高举蓄势期：克制的剑意凝聚微光竖线，提示重斩落线
			float gather = prog / impact_start;
			float line_w = mix(0.020, 0.044, gather);
			float along = band_mask(sp.x, 0.16, mix(0.32, 0.70, gather));
			float across = step(abs(sp.y), line_w * (1.0 - sp.x * 0.35));
			core_mask = along * across * (0.35 + 0.38 * gather);
			body_mask = along * step(abs(sp.y), line_w * 1.8) * 0.26 * gather;
			trail_grad = 0.85;
		} else {
			float cut_t = clamp((prog - impact_start) / (1.0 - impact_start), 0.0, 1.0);
			float expand = clamp(pow(cut_t, 0.48), 0.0, 1.0);
			float cur_half = half_arc * mix(0.58, 1.06, expand);
			float norm_a = abs(ang) / max(0.05, cur_half);

			if (norm_a <= 1.0) {
				// 弧形平滑收尖权重：中轴最宽厚，两侧弯成锐利尖角
				float center_w = cos(norm_a * 1.5707963);
				float arch = pow(center_w, 0.78);

				// 外刃中心前冲凸出，形成重劈破空峰
				float r_outer = mix(0.56, 0.84, expand) + 0.09 * pow(center_w, 1.5);

				// 宽厚重斩主体：厚度达到第一击近 2 倍，内沿为贴剑弯曲圆弧
				float thick_base = 0.36;
				if (rank_stage == 1) {
					thick_base = 0.42;
				} else if (rank_stage == 2) {
					thick_base = 0.46;
				}
				float thick = thick_base * (0.10 + 0.90 * arch) * (1.0 - fade_progress * 0.45);
				float r_inner = max(0.20, r_outer - thick);
				// 收招时内沿向外推开，呈现干脆切空消散感
				r_inner = mix(r_inner, r_outer - 0.025, fade_progress * 0.84);

				float fan_band = band_mask(r, r_inner, r_outer);
				// 细腻径向风压刻纹（增强劈落张力，保持干净）
				float streak_n = hash21(vec2(floor((ang + 3.14) * 24.0), floor(r * 12.0 - cut_t * 7.0)));
				float streak_mod = mix(0.80, 1.0, step(0.32, streak_n + center_w * 0.30));
				body_mask = fan_band * streak_mod;
				trail_grad = clamp((r - r_inner) / max(0.01, r_outer - r_inner), 0.0, 1.0);

				// 锋利紧凑的亮白前刃（不糊成一大块纯白）
				float edge_w = mix(0.028, 0.072, pow(center_w, 1.1)) * (1.0 - fade_progress * 0.50);
				core_mask = band_mask(r, r_outer - edge_w, r_outer + 0.010) * smoothstep(0.06, 0.30, center_w);

				// 极细中心破风锋线（1~2像素细线，取代笨重白块）
				float fine_rib = step(abs(ang), 0.028 * (1.0 - fade_progress * 0.6)) * band_mask(r, mix(r_inner, r_outer, 0.35), r_outer + 0.012);
				core_mask = max(core_mask, fine_rib * 0.85);

				// 阶段 2（中期御气）：外沿灵气拖尾流光
				if (rank_stage >= 1) {
					float wave = sin(ang * 16.0 + cut_t * 10.0) * 0.020;
					float aura_band = band_mask(r, r_inner - 0.07 + wave, r_outer + 0.055 + wave * 0.5) * (1.0 - fan_band);
					float n2 = hash21(vec2(floor(ang * 28.0), floor(r * 24.0)));
					outer_aura = aura_band * step(0.44, n2 + center_w * 0.25) * 0.76;

					float sp_n = hash21(cell + vec2(37.0, floor(cut_t * 14.0)));
					spark_mask = band_mask(r, r_inner - 0.05, r_outer + 0.10) * step(0.955, sp_n) * center_w;
				}

				// 阶段 3（后期仙术成型）：独立霜青外轮廓双层剑气弧
				if (rank_stage == 2) {
					float rim_lo = r_outer + 0.044;
					float rim_hi = rim_lo + 0.044 * (0.20 + 0.80 * arch);
					dual_rim = band_mask(r, rim_lo, rim_hi) * smoothstep(0.08, 0.34, center_w) * (1.0 - fade_progress * 0.58);
				}
			}
		}
	}

	// === 三阶段色彩分级（凡剑 → 御气 → 仙术成型）===
	vec3 col_core;
	vec3 col_body;
	vec3 col_tail;
	vec3 col_rim;

	if (rank_stage == 0) {
		// 阶段1（凡剑）：干净利落冷钢银白
		col_core = vec3(0.98, 0.99, 1.0);
		col_body = vec3(0.77, 0.85, 0.92);
		col_tail = vec3(0.46, 0.56, 0.67);
		col_rim  = vec3(0.86, 0.92, 0.98);
	} else if (rank_stage == 1) {
		// 阶段2（御气）：清透青白色剑光 + 轻盈灵气拖尾
		col_core = vec3(0.94, 1.0, 0.99);
		col_body = vec3(0.32, 0.90, 0.88);
		col_tail = vec3(0.14, 0.58, 0.68);
		col_rim  = vec3(0.56, 0.98, 0.95);
	} else {
		// 阶段3（仙术成型）：霜青主锋 + 高明度银白核心 + 独立外轮廓
		col_core = vec3(1.0, 1.0, 1.0);
		col_body = vec3(0.30, 0.84, 1.0);
		col_tail = vec3(0.14, 0.46, 0.88);
		col_rim  = vec3(0.64, 0.96, 1.0);
	}

	col_core = mix(col_core, vec3(1.0, 0.94, 0.80), block_recoil * 0.70);

	vec3 final_rgb = mix(col_tail, col_body, clamp(trail_grad * 1.15, 0.0, 1.0));
	float alpha = body_mask * mix(0.58, 0.90, trail_grad);

	if (outer_aura > 0.0) {
		final_rgb = mix(final_rgb, col_rim, outer_aura * 0.78);
		alpha = max(alpha, outer_aura * 0.66);
	}
	if (dual_rim > 0.0) {
		final_rgb = mix(final_rgb, col_rim, dual_rim);
		alpha = max(alpha, dual_rim * 0.92);
	}
	if (core_mask > 0.0) {
		final_rgb = mix(final_rgb, col_core, clamp(core_mask, 0.0, 1.0));
		alpha = max(alpha, core_mask * 0.96);
	}
	if (spark_mask > 0.0) {
		final_rgb = mix(final_rgb, col_core, 0.88);
		alpha = max(alpha, spark_mask * 0.86);
	}

	if (behind_soften > 0.0 && r < 0.45) {
		alpha *= mix(1.0, 0.52, behind_soften);
	}

	alpha *= fade;
	if (alpha < 0.05) {
		discard;
	}
	alpha = clamp(floor(alpha * 7.0 + 0.5) / 7.0, 0.0, 0.94);

	COLOR = vec4(final_rgb, alpha);
}

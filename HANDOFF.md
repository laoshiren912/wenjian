# 当前项目交接

## 2026-11-22 · 手眼分离与万剑归宗冷却
- 左键三连、剑气和右键飞剑取点击时的鼠标世界方向，预输入及飞剑回手后的续斩也保留点击方向。WASD 独立八向移动，空格优先沿 WASD 合成向量穿阵，无方向键时朝鼠标。素金月牙实时跟随瞄准，封面、选卡、结算隐藏。
- 万剑归宗三阶基础冷却为 8.0 / 6.5 / 5.0 秒。《万剑归宗·极》每名命中敌人返还 1.5 秒，每次施法总冷却最低 3.5 秒。施放用青金冲击波、0.12 秒暗角、飞剑拖尾与剑鸣。
- 10 项核心回归及 12 项扩展脚本全部通过，GL Compatibility 流程 380/380、操作 257/257。日志及两张战斗截图在 `artifacts/runtime/v41-aim-and-cooldown/`。
- 同一把右键飞剑对同一目标至少间隔 0.12 秒。敌人闪白间隔 0.15 秒，镜头震动在 0.18 秒内合并。八荒魔轮预警 0.45 秒，角速度 0.688 rad/s。
- 书法与水墨重塑（`v41_ink_brush.gdshader`、`v41_reward_ui.gd`、`v41_hud.gd`）：彻底清除斜向黑条、同心黑圆晕与散乱短线；《问剑》封面改用行楷端正微错落大字 + 柔和水墨烟云 Shader + 暖金微光 + 暗红朱砂「剑」印；「败北」改用端正苍劲大字 + 横向水墨飞白笔锋 Shader + 裂纹朱砂小印。
- 物理抛物线跳字与精英架势破防（`combat_feedback.gd`、`v41_feedback.gd`、`enemy.gd`、`v41_sword.gd`、`v41_thrown_sword.gd`、`v41_sword_rain.gd`）：伤害数字改为独立抛物线弹射并分普通素白、暴击/背刺/破防 `1.4×` 赤金弹性缩放+金星粒子、格挡 `0.75×` 暗铁灰侧下弹开三级；自动格挡限定重装精英怪，身前展开流光青金扇形剑罡与头顶明黄架势条，穿阵绕背 100% 赤金大暴击，右键/三段重击震碎架势进入 `1.5s` 全暴击硬直。

## 2026-11-22 · 第二轮演出、败北与心魔机制
- 败北经约 0.5 秒慢动作过渡到黑白水墨结算。Enter 默认重战本关，保留功法与修为、回满气血体力，并把击杀数回到进关时；R 重入仙途，另可重归山门。
- 心魔按 75%／53%／35% 阶段逐步进入万魔剑域、太极剑轮、心魔幻斩，三式按冷却轮换。屏幕上方报招，场地标明预警、爆发和安全空间。
- Godot 4.7.2 的 22 项脚本回归通过；GL Compatibility 流程 380/380、第二轮专项 43/43。截图在 `artifacts/runtime/v41-second-pass/`。

## 2026-11-22 · 第一轮实机优化与功法升级
- 小怪贴图保留源色，取消共用受击 Shader 的常驻提亮与暖色偏移；短暂纯白闪烁后恢复原色。前摇和格挡通过地面、武器及身前剑罡提示。
- E 万剑归宗加入屏幕中上方暗金水墨飘字、0.09 秒顿帧及 4.5% 峰值缩放；左键、右键出招不飘招式名。
- 六个阵眼按本关和修为领悟。凡剑第 1–2 关、御气第 3–4 关、仙术第 5–6 关。10 张牌可实际出招，已习得功法同步到选卡及胜利页。
- 第 3–6 关扩至 3／4／4／4 波，混入真格挡精英，全程 88 敌。单怪生命、伤害和同时起手上限沿用原配置。
- Godot 4.7.2 回归 21 个脚本全过，GL Compatibility 流程 379/379、专项 312/312。原生截图与日志在 `artifacts/runtime/v41-first-pass/`。

## 2026-11-22 · 战斗深度、心魔大招、玉简选卡与通关结算
- **第 7 关通关结算**（`v41_run.gd`、`v41_hud.gd`、`v41_reward_ui.gd`）：击败【心魔】触发 `1.0s` 慢动作定格与清脆剑鸣收尾，随后转入 `phase = "victory"`、隐藏局内战斗 HUD 并展示暗金水墨结算横幅（`心魔已斩 · 问剑大成` + 朱砂「成」印 + 通关耗时/斩敌总数/修为境界），提供「重归山门」（回原版《问剑》开局封面）与「再入仙途」（直开第 1 关）。
- **怪物真格挡与破防博弈**（`enemy.gd`、`v41_pixel_visual.gd`、`v41_sword.gd`、`v41_thrown_sword.gd`、`v41_sword_rain.gd`）：近战格挡态切为持剑横挡姿态并身前展开半透明青金护体剑罡；正面轻击弹刀火星并轻微震退玩家（不阻断立刻空格穿阵）；绕背攻击格挡目标触发 `1.5×` 背击暴击并破防；右键旋斩与 `E` 万剑归宗命中可直接震碎护体剑罡触发碎盾与硬直。
- **心魔全屏大招「万魔剑域」**（`v41_boss.gd`、`v41_boss_domain.gd`、`v41_player.gd`、`v41_hud.gd`）：半血以下（及冷却就绪后）闪现居中浮空蓄力 `1.2s`，全屏暗红边缘预警、地面纵横暗红剑气预警线与 3 枚青光安全阵眼；爆发期降下黑红剑雨与十字剑气波，安全阵眼与 `Space` 穿阵闪避窗免疫伤害。
- **三选一暗金水墨功法玉简与质变**（`v41_reward_ui.gd`、`v41_hud.gd`）：保留 `v41_card_pool.gd` 抽卡与原版开局封面，选卡重绘为三张竖排古风玉简（双层流派微光框、程序化仙侠徽记、描边牌名与流派标签、悬停上浮流光与轻脆音效、点击收束闪光）；强化万剑命中减冷却、雷霆穿阵起落延迟爆炸残影、破阵嗜血回血回体+万剑吸血、双星旋刃范围 `+26%` 与强聚怪。

## 2026-11-22 · 三连像素刀光 Shader、三阶段演化与打击感闭环
- 停用旧图集与旧几何斩光，新增 GL Compatibility / WebGL2 兼容的程序化像素对齐刀光着色器 `assets/shaders/v41_combo_slash.gdshader`、仙纹八卦/气浪着色器 `assets/shaders/v41_bagua_seal.gdshader` 及控制器 `scripts/v41_slash_vfx.gd`。严格绑定锁定攻击朝向与贴剑半径，区分顺向横斩、反向斜挑回斩、宽厚重斩扇面；第三击仅命中/破防扩散克制像素环形气浪，空挥不砸地。
- 三阶段演化落地：阶段 1（凡剑银白锋刃）→ 阶段 2（御气青白剑光+外沿灵气拖尾流光）→ 阶段 3（霜青主锋+高明度银白核心双层轮廓，第三击落点闪现 0.15s 像素八卦微光印记）。战斗中按顶排/小键盘 `1/2/3` 实时切阶段、`0` 恢复自然修为。
- `scripts/v41_run.gd` 与 `scripts/v41_feedback.gd` 全面接入 `combo_event`（空挥轻风、普通命中闪白+定向像素火花、被格挡金属火星+弹刀微缩、破防与击杀强顿帧/克制微震/爆发光痕），严格执行多通道防叠加节流。
- `scripts/v41_pixel_visual.gd` 补强一、二、三击动作区分度（帧序偏移、前冲/斜挑上提、第三击蓄力压低重心与沉重定势收招），未改动判定半径、时间基线与 `blade_segment`。
- `Space` 穿阵一线手感与跨冲刺连段（[v41_config.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_config.gd)、[v41_player.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_player.gd)、[v41_sword.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_sword.gd)）：冷却 `1.55s` + `0.30s` 冷却尾段预输入缓存；一/二/三击只要进入 `recovery` 收招期即可瞬间取消起手穿阵；穿阵全程冻结连段超时计时，通用保留 1/2 段后续接索引（打通 `1→穿阵→2→3` 与 `1→2→穿阵→3`），落地后给足 `0.42s` 续段窗口（超时或三击后重置回 1 段）；落地 `RECOVERY` 保留 `82%` 移速并可在 `0.05s` 后取消剩余后摇接攻。
- 第 7 关 Boss（守庭者）像素化与 2–7 关氛围补齐（[v41_boss_visual.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_boss_visual.gd)、[v41_boss_tint.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_boss_tint.gdshader)、[v41_boss_vfx.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_boss_vfx.gdshader)、[v41_ambient_fx.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_ambient_fx.gd)）：移除 Boss 几何占位，改用玄铁深黑+鎏金赤煞调色的高大像素 8 向动画、横扫像素预警与赤金罡风刀光、直线突进走廊预警与破风尾焰残像；死亡薄烟统一接入 1–7 关全部敌人（Boss 败北放大赤金消散）；2–7 关新增克制流动云影与分主题像素微粒。
- 4 张技能卡招式异变、右键御剑旋斩强化与 2–7 关氛围增强（[v41_sword_wave.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_sword_wave.gd)、[v41_thrown_sword.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_thrown_sword.gd)、[v41_feedback.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_feedback.gd)、[v41_ambient_fx.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_ambient_fx.gd)）：万剑归宗（第三击齐射 3 道青白穿透剑气）、雷霆残影（穿阵起手/落地青金电光残影 + 下一剑充能微光 + 翻倍命中雷霆气浪爆发）、破阵嗜血（击杀 5 颗吸魂光点飞回主角并触发回气脉冲）、双星旋刃（被破防敌人醒目金色碎盾弱点印记 + 右键对称双星剑轮与高密度火星）；1–7 关敌人死亡叠加像素薄烟与散尘灵屑，2–7 关强化翻转飘叶/灵尘/三层错速云影。
- 右键御剑旋斩视觉重做与 2–4 关海拔递进云影（[v41_spin_wheel.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_spin_wheel.gdshader)、[v41_thrown_sword.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_thrown_sword.gd)、[v41_ambient_fx.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_ambient_fx.gd)）：右键飞剑接入像素量化双环霜青/炽银白剑气轮盘与飞行青白长拖尾，持有【双星旋刃】升级为 4 瓣交错双剑大光轮 + 旋停地面像素八卦光纹；复用第 1 关云影与边缘前景云接入第 2、3、4 关，云影密度与流速逐关递进，前景云严格限定上下边缘不遮挡中央战斗区。
- 独立 `E` 键【万剑归宗】四段式大招（[v41_sword_rain.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_sword_rain.gd)、[v41_pixel_visual.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_pixel_visual.gd)、[v41_config.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_config.gd)）：体力 `18`、冷却 `3.5s`（与三连/穿阵/掷剑解耦），按 `E` 后执行节奏清晰的四段演出（念咒结印前摇 `0.30s` 微收步伐 `28%` 移速 + 沉身竖剑起诀与双层聚灵法环 → 身后顺时针转满 360° `0.38s` → 竖刃冲天拔高 `0.24s` → 错峰从天而降砸向目标约 `0.25~0.35s`，主体约 `1.17s`）；念咒期受击打断会干净清理并压冷却至 `1.5s`，HUD 实时显示 `念咒中 / 施法中 / 冷却`。
- 听觉氛围与多层战斗音效（[v41_audio.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_audio.gd)、[v41_feedback.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_feedback.gd)、[v41_hud.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_hud.gd)）：初始化 `BGM`（`-12.5 dB`）与 `SFX`（`-0.5 dB`）总线并在 `Master` 挂防削波 `AudioEffectLimiter`；预留 `assets/audio/bgm_normal.ogg`/`bgm_boss.ogg` 自动接管，当前内置四轨高律动国风武侠动作 BGM（普通关 `132 BPM` 堂鼓/竹板/切分低音/琵琶主旋律/短竹笛应答，第 7 关 Boss `150 BPM` 急促战鼓决战变奏）；强化 22 条多层复合战斗/技能音效并严格多通道节流；按 `M` 键随时静音，暂停菜单可独立开关 BGM 与全部音频。
- 无框极简仙侠风战斗 HUD 与属性/暂停页收口（[v41_hud.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_hud.gd)、[v41_skill_slot.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_skill_slot.gd)、[v41_config.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_config.gd)、[v41_boss.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_boss.gd)、[v41_run.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_run.gd)）：补齐 7 关关名 `ROOM_NAMES`、第 7 关 Boss 更名为 `心魔`、修为进阶阈值拉长至 `CULTIVATION_KILLS := [0, 8, 18]`（`凡剑期/御气期/仙术期`，保留后台 `1/2/3/0` 热键）；左上角在红/霜青细条下方新增同宽鎏金 `#E6C15A`「修为」进阶管道（满阶圆满高亮+突破金光），并将全战斗 HUD 整体放大 ~22%–25%（底部 4 枚无框 16-bit 图标约 `55×55` + 纯中文键位 `左键/右键/空格/E` + 圆弧冷却遮罩与 `施法中`）；`Esc` 暂停页含镜头/音频开关，`Tab` 属性页含 `E 万剑归宗` 数值；选卡奖励页未改动。
- 战斗难度平衡与原版主角贴图保持（[v41_config.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_config.gd)、[enemy.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/enemy.gd)、[v41_boss.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_boss.gd)）：前 6 关波次调整为 `4 / 6(3+3) / 7(3+4) / 9(3+3+3) / 9(3+3+3) / 10(3+3+4)`（共 45 小怪+1 Boss，匹配 `[0, 8, 18]` 修为曲线）；小怪保持低血脆感但伤害 `+25%`（15/14/19）、追击提速且缩短前摇与恢复；「心魔」Boss 生命提升至 `4400`（`+37.5%`）、横扫/突进增伤至 `22/25` 并压缩蓄力与收招间隔；主角精灵图已还原至 Git 基线原貌。
- 破境成功屏幕特效、2 秒清场灵气吸收与系统级「打击感五件套」（[v41_run.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_run.gd)、[v41_hud.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_hud.gd)、[v41_feedback.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_feedback.gd)、[v41_pixel_visual.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_pixel_visual.gd)、[v41_boss_visual.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_boss_visual.gd)、[v41_hit_flash.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_hit_flash.gdshader)、[enemy.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/enemy.gd)、[v41_boss.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_boss.gd)）：① 自然突破或按 `2/3` 切至「御气期/仙术期」触发 `1.15s` 不暂停破境演出（主角双层灵气冲击波+螺旋粒子、屏幕四边呼吸流光+光扫横幅、专属钟磬剑鸣音）；② 清场 `clear_celebration` 拉长至 `2.0s`（Boss `2.15s`），`0.0s` 清敌弹、播完死亡消散并从倒地处释放青金灵气光点弧线飞向主角吸收，横幅完整展示并平滑淡出后再弹选卡/通关结算；③ 打击感五件套落地：分级顿帧（1/2 段 `0.018s`、第 3 段 `0.060s`、破防 `0.068s`、万剑 `0.055s`，支持轻→重升级且防同级叠帧不丢输入缓冲）、定向镜头冲击回弹（`4~8px` Camera Kick）、`0.07s` Shader 纯白高光闪烁 + 阻尼物理击退/受击硬直（含 Boss 抗性微击退）、沿攻击切线高对比度爆裂火花与重劈/破防冲击波环、以及低频亚音重击音效层 + `0.92~1.08` 随机音高微变。
- 过关流转重构、仙侠旋转八卦传送阵与顶部中轴/阵点校准（[v41_portal_array.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_portal_array.gdshader)、[v41_portal_fx.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_portal_fx.gd)、[v41_world.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_world.gd)、[v41_run.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_run.gd)、[v41_hud.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_hud.gd)、[v41_config.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_config.gd)）：① 替换素色圆圈为像素量化双色旋转八卦传送阵（外圈暗金/霜青顺旋+内圈剑纹逆旋+灵点+呼吸光晕+激活波纹+光箭导引+踏入聚光音）；② 第 1–6 关清场后直接点亮传送阵进入 `exit_ready`（不再定时强制弹卡），步入阵眼弹选卡、选完直接切下一关；③ 顶部 HUD 改为独立三锚点解耦（左上 `TOP_LEFT` / 中轴 `CENTER_TOP` 严格 `err=0.0px` / 右上 `TOP_RIGHT` 右留白 `22px` 防裁切，双分辨率零重叠）；④ 精准校准第 3 关 `(988,242)` 木桥桥头、第 4 关 `(640,268)` 中央巨剑前、第 5 关 `(948,248)` 右上亭前石阶，复核 1/2/6 关均居中 `x=640`。
- `E`/右键技能重构、波次魔气召阵过渡与敌人模型提亮（[v41_sword_rain.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_sword_rain.gd)、[v41_thrown_sword.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_thrown_sword.gd)、[v41_player.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_player.gd)、[v41_run.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_run.gd)、[v41_feedback.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_feedback.gd)、[v41_hit_flash.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_hit_flash.gdshader)、[v41_boss_tint.gdshader](file:///c:/Users/BAI/Documents/像素幸存者/assets/shaders/v41_boss_tint.gdshader)）：① `E` 键【万剑归宗】移除鼠标落点圈，改为念咒 → 360° 聚势 → 冲天拔高后自动按距离由近到远均匀锁定场上存活敌人并实时追踪砸落（单精英/Boss「心魔」全剑集中错峰砸落，中途死亡自动切换剩余目标，无敌则砸向面朝前方）；② 右键【掷剑旋斩】改为精准飞至鼠标点击位置旋停，旋停期升级为 `3~4` 段高频切割 + 轻度向心牵引 + `0.36s` 减速，提速飞行/回程并解除在途对 `Space` 穿阵的死锁；③ 波次切换改为 `0.25s` 短停顿 → `0.55s` 地面暗红/墨黑魔气召唤阵与升腾黑烟（含 `wave_summon` 音效与来袭提示）→ 破雾淡入现身并附 `0.25s` 落地起手保护；④ 敌人 Shader 保留纯黑描边并将非描边明度提亮约 `+18~20%`（同步取消 Boss 暗部 `0.60×` 过度压暗）。
- 正式定名《问剑》与无框水墨暗金动态开局画面（[project.godot](file:///c:/Users/BAI/Documents/像素幸存者/project.godot)、[v41_run.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_run.gd)、[v41_hud.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_hud.gd)、[v41_player.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_player.gd)、[v41_audio.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_audio.gd)、[v41_feedback.gd](file:///c:/Users/BAI/Documents/像素幸存者/scripts/v41_feedback.gd)）：① 窗口/项目名更新为 `问剑`；② 正常启动进入 `phase = "title"`，复用第 1 关「山门竹林」完整实景（竹林云影与柔和 BGM，主角持剑静立中轴且锁控，暂不刷第 1 波，隐藏战斗 HUD），居中仅呈现无框椭圆墨晕暗金大字 **`问 剑`** + 朱砂小印 + 细云纹线（纯主标题、无副标题）+ 暗金细边 **`踏入仙途`** 按钮（`FOCUS_NONE`、悬停亮金微光、支持点击或 `Enter`/`Space`）、右上低调静音开关（同步 `M`）与底部深墨描边操作指南；③ 点击开局播放出鞘剑鸣音（`title_start`）、`0.35s` 标题淡出/战斗 HUD 渐显、抬升 BGM 音量、解锁主角并立即经魔气召阵过渡刷新第 1 关第 1 波；④ 自动化回归（headless 或 `tests/` 脚本）及局内重开默认跳过标题直入战斗，保留 `enter_title_screen()` / `start_run_from_title()` 显式接口。

## 2026-11-21 · 换机入口
- 分支 `codex/v4.1-combat-pressure`。另一台电脑切到同一分支并执行 `git pull --ff-only`，用 Godot 4.7.2 打开 `project.godot`，等待导入后按 F5。主场景为 `scenes/main_v41.tscn`。
- WASD 移动、鼠标瞄准、点按左键三连、Space 穿阵、右键掷剑。Tab 看属性，Esc 暂停或重开，死亡后 R/Enter 重开。反引号打开 GM，可切修为或跳房，点「返回」继续。
- 每轮按当次范围执行。继续做剑气时，从中期首击 V2 实机对照开始。其余剑气是否替换、下一招先做哪击，等下一轮确定。数值与操作步骤见 `V4.1试玩说明.md`，历史测试见 `docs/HANDOFF_ARCHIVE.md`。

## 场景、落点和出口
前六关须清完所有波次并选属性卡才开放出口。过门保留血量和体力，正式流程单向。下表为 1280×720 底图世界坐标。

| 关卡 | 进入坐标 | 出口或结算 |
| --- | --- | --- |
| 1 山门竹林 | (640,550)，面向北 | 北侧山门，矩形 (575,216) 至 (705,266) |
| 2 山道石阶 | (640,492) | 北侧石阶前 (640,277) |
| 3 峭壁栈道 | (346,365) | 东北栈道桥头前 (988,242) |
| 4 山顶殿前 | (280,363) | 中央巨剑前 (640,268) |
| 5 悬空遗迹 | (280,419) | 右上亭前石阶 (948,248) |
| 6 天门 | (640,539) | 北侧天门前 (640,272) |
| 7 凌霄仙庭 | (640,552) | 击败心魔直接结算 |

- 第1关移除旧练武馆空气墙，按新图校准外围与门墙，中间门洞留空，门后石径封闭。保留云影、三团前景云和 Bandit 死亡薄烟。GM 从第2关跳回第1关落在 (640,305)。
- 第2关三块山石按脚点遮挡。第3关只放开栈道口前的旧边界。第4、5关石碑有遮挡和碑座碰撞，第5关另有石台围边。第6关调整两侧和南缘，北侧沿用旧线。第7关空气墙围住整个台面。
- 第2–6关亮圈与脚底中心检测共用 28 像素半径。原生验证走到圈内才转场、入场安全、无连跳，Boss 场没有旧出口圈。

## 战斗与斩光
- 自然修为按累计击杀 0/10/43 且分别进入第 1/3/5 关。三段左键基础伤害 32/40/60，普通命中有短顿帧，第三击可破防。
- Space 穿阵一线取按下时的 WASD 输入，松开 WASD 时取鼠标方向。消耗 20 体力、冷却 1.55 秒，三阶距离 156/202/246。冲刺移动阶段具闪避窗，脚底碰撞挡墙。
- 右键掷剑旋斩消耗 8 体力、冷却 1.5 秒，三阶上限 156/184/214。飞出、旋停和回程分别判定，撞墙提前回程；在途可以穿阵或缓存左键。
- E 万剑归宗消耗 18 体力，三阶基础剑数 5/7/9。念咒受击打断，缩短至 3.5 秒。真人连续七关与网页导出仍待验证。

## 集中试玩和素材
- 提交前用纯暂存内容重新导入 Godot 4.7.2 并启动主场景，17 个 V4.1 测试脚本均以 0 退出，含流程 248/248、穿阵与三连 213/213、掷剑 44/44、第五关边界 81/81。
- F5 后用 GM 依次切三个修为，返回后朝不同方向单点左键验证 V2 的覆盖范围。朝山石或第5关边缘按 Space，再朝墙右键并边走边缓存招式。跳到第2关清完各波、领奖进亮圈，可连续复核至 Boss 结算。
- 可重跑 `godot --headless --fixed-fps 60 --script tests/v41_flow.gd`，或把脚本换成 `tests/v41_moves.gd`、`tests/v41_thrown_sword.gd`、`tests/v41_room5_edge.gd`。历史原生测试由脚本驱动，包含第1关山门、2–7关转场、斩光深浅地面和 24–60 fps 峰值。
- 正式运行素材均在仓库相对路径：`assets/courtyard/room1/room01_mountain_gate.png`、`assets/courtyard/rooms2-7/`、`assets/characters/Swordsman/` 内直剑图集和派生攻击姿势、`assets/vfx/mid-horizontal-slash-v2/` 的正式图集及对应导入设置。云影与死亡薄烟沿用已跟踪素材。
- 原素材 ZIP、斩光逐帧与预览、仓外快照、日志、临时脚本和原生演示留在原电脑。旧第1关练武馆四张废案贴图及 Frostwindz 试验留本机工作区。正式运行、编辑和上述回归不依赖这些材料。Frostwindz 的贴图、授权文件和本机试验版剑脚本需要另行转移才能在换机后继续试验。

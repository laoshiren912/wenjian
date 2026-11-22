# 当前项目交接

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
- 验证结果：GL Compatibility 实机验证原版主角还原、`E` 键群怪自动追击（3/3 命中）与「心魔」Boss 全剑集火（9 剑 252 伤）均零报错复核通过；全套 10 项回归零错全绿（flow 279/279、moves 222/222、thrown_sword 45/45、combo_contract 163/163、finisher 40/40、boss_obstacle 0 失败、room5_edge 80/80、card_pool 72/72、third_links 0 失败、roll_links 5/5）。真人键鼠完整七关连打手感与网页导出仍待验收。

## 2026-11-22 · 三连状态与判定整理
- 三击使用同一锁定攻击朝向；15°辅助瞄准按当前击距离、修为延伸和地形遮挡选目标，表现及扫掠沿锁定方向。时间和缓冲集中于 `scripts/v41_config.gd`：三击前摇/有效/收招 0.08/0.10/0.14、0.10/0.12/0.16、0.085/0.14/0.20 秒；输入缓冲和动作结束后续段窗口各 0.30 秒。
- `combo_event` 分发 miss/hit/blocked/guard_break/kill；单次接触可附带破防、击杀。第三击顿帧、震屏和接触音效增加间隔限制；原有伤害、招式和判定半径保留。
- 移除左键旧几何斩光与连线；第三击暂只有人物挥剑动作，专用重斩素材仍缺。此前未提交的前两击 V2 工作保留；未提交或推送。
- 受控检查：三连契约 163/163、moves 213/213、finisher 40/40、flow 248/248、掷剑 44/44。尚需真人键鼠试玩、方向与反馈观感验收；不代表完整七关或网页验收。

## 2026-11-22 · 三连斩光进行中
- 原目录 `codex/v4.1-combat-pressure` 基于 `656a6fb`；本轮未提交。前三阶段的第一、二击接入 V2 图集，第二击反向并按剑尖定位；初期派生银白图集，后期仅初步蓝色调，分层短拖尾尚未完成。
- 第三击的旧几何表现现已停用，专用重斩尚未完成：现有 V2 素材是横斩，缺少可可靠派生的上举、下落、收势重斩序列。角色原举剑姿势未重绘。
- Godot 4.7.2 导入成功；moves 213/213、flow 248/248、掷剑 44/44。前两击 3 阶段×2 击×8 方向的受控峰值截图已检查；三阶段脚本直接触发攻击的正常速度视频含旧第三击。低帧率、正常键鼠手感、完整视觉验收尚未完成。
- 备份在 `C:/Users/BAI/Documents/像素幸存者备份/before-nine-slashes-20261122/`；视频与截图在同级 `slash-preview/`。F5 后反引号打开 GM，切修为并返回，再连续点左键三次试玩。

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
- 自然修为按累计击杀 0/2/3 解锁「实体剑招／剑气外放／仙术成型」。三段左键基础伤害 32/40/60，第三击命中才有短停顿和破防。原直剑 V2 角色图集已验收。
- Space 穿阵一线指向按下时的鼠标，消耗 20 体力，冷却 2 秒，阶段距离 156/202/246。角色脚底挡墙，穿阵时仍可受伤。中、后期有短促延爆，一名敌人每次至多吃一次直击和一次剑痕。
- 右键掷剑旋斩消耗 8 体力，冷却 1.5 秒，阶段距离 146/174/202。飞出、旋停、回程分别判定，撞墙提前回程；在途可走动、缓存一次左键和一次 Space，回手后 Space 优先。死亡、重开、切房清理飞剑。
- 中期左键第一击沿用 V2：按实际剑尖对齐，0.55 倍、普通透明混合；F08 在原 100 ms 挥砍有效期后半显示。其他前两击本轮状态见顶部。
- 三个阶段的第三击没有替代斩光，旧几何已停用。Space、掷剑自带效果沿用。朝上挥砍时人物会遮住少量内侧斩光。真人手感、真人七房连打及网页导出仍待验证。

## 集中试玩和素材
- 提交前用纯暂存内容重新导入 Godot 4.7.2 并启动主场景，17 个 V4.1 测试脚本均以 0 退出，含流程 248/248、穿阵与三连 213/213、掷剑 44/44、第五关边界 81/81。
- F5 后用 GM 依次切三个修为，返回后朝不同方向单点左键验证 V2 的覆盖范围。朝山石或第5关边缘按 Space，再朝墙右键并边走边缓存招式。跳到第2关清完各波、领奖进亮圈，可连续复核至 Boss 结算。
- 可重跑 `godot --headless --fixed-fps 60 --script tests/v41_flow.gd`，或把脚本换成 `tests/v41_moves.gd`、`tests/v41_thrown_sword.gd`、`tests/v41_room5_edge.gd`。历史原生测试由脚本驱动，包含第1关山门、2–7关转场、斩光深浅地面和 24–60 fps 峰值。
- 正式运行素材均在仓库相对路径：`assets/courtyard/room1/room01_mountain_gate.png`、`assets/courtyard/rooms2-7/`、`assets/characters/Swordsman/` 内直剑图集和派生攻击姿势、`assets/vfx/mid-horizontal-slash-v2/` 的正式图集及对应导入设置。云影与死亡薄烟沿用已跟踪素材。
- 原素材 ZIP、斩光逐帧与预览、仓外快照、日志、临时脚本和原生演示留在原电脑。旧第1关练武馆四张废案贴图及 Frostwindz 试验留本机工作区。正式运行、编辑和上述回归不依赖这些材料。Frostwindz 的贴图、授权文件和本机试验版剑脚本需要另行转移才能在换机后继续试验。

# 《问剑》Web 导出自查 · 2026-11-23

## 结果与版本

- 基线：`codex/v4.1-combat-pressure`，`eb23011069bc56ffb13b2a40641296f75cd1b6d6`，开工工作区干净，HEAD 与本地 origin 跟踪引用一致。首次自查结束时未提交、未推送、未发布托管站点；随后用户授权随跳字微调一起提交推送。
- Godot：`4.7.2.stable.official.ed1daf0bf`；本机引擎位于 `C:/Users/BAI/Desktop/123/Godot_v4.7.2-stable_win64.exe`。
- 已完成 Release 导出、本地无隔离响应头 HTTP 启动、Chrome WebGL2 自动输入冒烟。
- 构建目录：`build/web/`；上传压缩包：`build/问剑-Web试玩版.zip`，ZIP 根目录直接包含 `index.html`。

## 四项核心检查

1. 昨晚功能存在：鼠标方向与预输入保存、WASD 独立移动、脚底月牙指向；E 冷却 `[8.0, 6.5, 5.0]`、命中返还与最低 3.5 秒；精英自动格挡/架势条/破防；普通、暴击、格挡三级抛物线跳字；水墨封面与败北 Shader/书法标题。
2. 全部 22 个 `tests/v41*.gd` 以 headless、固定 60 Hz 运行，全部退出码 0，`TOTAL=22 FAILED=0`，最终测试日志没有 SCRIPT ERROR、ERROR、WARNING 或 FAIL。包含流程 380/380、操作 255/255、掷剑 62/62、功法实战 300/300、第二轮专项 56/56。结果表见 `artifacts/runtime/web-release/regression.json`。
3. 原生 GL Compatibility：Intel UHD Graphics 730 / OpenGL 3.3，操作及抓图 257/257、第二轮演出及封面/败北抓图 65/65，未发现脚本或渲染错误。当前截图已复制到 `artifacts/runtime/web-release/native-combat.png`、`native-title.png`、`native-defeat.png`。
4. 字体：将 STXingkai、KaiTi、Microsoft YaHei 字体复制到 `assets/fonts/`；替换两个 SystemFont 字体工厂、直接绘字的 ThemeDB 回退引用，并设置项目默认中文字体。三个字体关闭系统回退；封面、败北、选卡、胜利、HUD 与关键文本字形检查 `FONT_PREFLIGHT FAILED=0`。

## Web 平台与音频

- 渲染器保持 `gl_compatibility`，WebGL2 实际启动成功。
- 正式 `scripts/` 中没有 FileAccess/DirAccess 写文件、截图保存或本地命令执行。测试中的 `res://artifacts/` 抓图仅用于原生测试，`tests/` 与 `artifacts/` 已从 Web 包排除。
- 项目声音由运行时合成 WAV 生成，使用 `AudioEffectLimiter`。Web 的 `audio/general/default_playback_type.web=0` 为 Stream，保留合成与音效混音能力。
- 注意两套枚举不同：项目设置 Stream=0 / Sample=1；AudioServer 播放类型 Stream=1 / Sample=2。首次浏览器检查发现设置误用导致采样为零，已纠正并重新导出；最终实测音频波形非零。
- 音频挂起恢复专项：测试侧先将浏览器 AudioContext 设为 `suspended`，再真实点击「踏入仙途」；Godot 自动恢复为 `running`，采样 RMS 峰值约 0.115。没有向正式包注入测试探针。
- Stream 单线程模式的音频延迟与主观听感仍需真人试玩确认。
- 配置依据：[Godot 4.7 Web 导出文档](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)、[ProjectSettings 音频设置](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-audio-general-default-playback-type-web)。

## 模板与预设

- 开工时未安装模板。已从 Godot 官方下载站获取 4.7.2 标准模板包，仅提取 Web 模板及版本文件到 `%APPDATA%/Godot/export_templates/4.7.2.stable/`。
- `export_presets.cfg` 的 `Web`：`variant/thread_support=false`、`variant/extensions_support=false`、PWA 关闭，路径 `build/web/index.html`。
- 排除 `tests/*,artifacts/*,docs/*,build/*`。`build/` 被 Git 忽略，并放置 `.gdignore` 避免构建产物再次导入。
- 命令行 `--headless --export-release Web build/web/index.html` 成功，退出码 0；最终导出日志无错误/警告。
- 主文件约 36.9 MB PCK + 39.5 MB WASM（十进制），另有 JS、HTML、两份音频 Worklet 与图标。

## 浏览器验证证据

- Node 轻量 HTTP 服务仅绑定 `127.0.0.1:8060`，没有 COOP/COEP 响应头。
- Chrome / Playwright 自动输入验证：封面 → 点击开局 → WASD → 鼠标左键/右键 → E → Esc 暂停/恢复；另一次运行等待自然败北并检查水墨结算。
- `crossOriginIsolated=false`、`SharedArrayBuffer=undefined`，引擎日志明确 `single-threaded`。未使用跨域隔离补丁或 Service Worker。
- 最终控制台 error=0、warning=0、pageerror=0、失败请求=0、HTTP 4xx/5xx=0。
- 截图和报告均在 `artifacts/runtime/web-release/`：`web-title.png`、`web-combat.png`、`web-skill.png`、`web-pause.png`、`web-defeat.png`、`browser-report.json`、`browser-report-strict-autoplay.json`。
- 构建文件大小与 SHA256 见同目录 `build-manifest.json`。

## 复建与试玩

PowerShell 在项目根目录运行：

```powershell
& 'C:/Users/BAI/Desktop/123/Godot_v4.7.2-stable_win64.exe' --headless --path . --export-release Web build/web/index.html
node artifacts/runtime/web-release/serve.cjs build/web
```

打开 `http://127.0.0.1:8060/`。不要通过 `file://` 双击启动。部署静态站点时上传 `build/web/` 全部文件，保持文件名与目录关系；itch.io 可直接上传 ZIP 并选 HTML 游戏。

上述结果覆盖受控回归、原生渲染截图及 Chrome 自动输入冒烟，不构成真人连续七关、操作手感、平衡、主观听感、Safari/Firefox/手机或线上托管验收。

## 同日最终微调 · 敌人伤害统一默认数字

- 普通、暴击/背刺/破防、格挡命中均显示基础 `-数字`，统一 21 px 默认颜色、正常比例和普通抛物线。不再出现格挡前缀、暴击感叹号或独立「破防!」飘字，也没有赤金放大与灰字缩小。
- 只改变跳字显示；保留真实伤害倍率/格挡减伤、破防硬直、护盾碎片、音效、镜头反馈与玩家受伤数字。
- 更新已有真实格挡命中与第三击破防回归断言，检查纯数字、默认字号/颜色/比例，同时保留伤害与破防行为断言。新增断言起初缺少显式 bool 类型，已修正并复测。
- 最终 22 项脚本全部通过，FAILED=0；原生 GL Compatibility 操作抓图 257/257。重新执行 Web Release 导出，退出码 0，最终日志无错误/警告。
- 本轮用户已授权提交推送；Web 构建产物仍按原预设留在 build/，通过 ZIP 单独分发，不纳入 Git。

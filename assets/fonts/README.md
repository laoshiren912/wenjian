# 随包中文字体

本轮按 Web 导出要求复制本机现有字体，运行时只使用 `res://` 资源路径。

| 文件 | 本机来源 | 用途 |
| --- | --- | --- |
| STXINGKA.ttf | Windows/Fonts/STXINGKA.TTF | 《问剑》与「败北」行楷标题 |
| simkai.ttf | Windows/Fonts/simkai.ttf | 书法配字与印章 |
| msyh.ttc | Windows/Fonts/msyh.ttc | 默认中文 UI、HUD、选卡、结算、伤害数字及直接绘制文字 |

三个 `.import` 文件均关闭 `allow_system_fallback`，不再依赖试玩设备安装字体。

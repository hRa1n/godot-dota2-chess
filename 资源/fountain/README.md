# 泉水（像素风）

| 文件 | 阵营 | 说明 |
|---|---|---|
| `fountain_radiant.png` | 天辉 | 绿色森林泉水，金色装饰 |
| `fountain_dire.png` | 夜魇 | 红色熔岩泉水，暗石尖刺 |

- 尺寸：1254×1254，PNG（RGB，**不透明**，自带背景场景）
- 来源：项目作者提供
- 已接入游戏：缩小为 192×192 放在 `assets/fountain/`，画在泉水格子里（天辉 11-6，夜魇 1-6）
- `资源/` 目录不打进网页导出包（见 export_presets.cfg 的 exclude_filter），游戏里用的图都放在 `assets/` 下

## 在 Godot 里使用

```gdscript
var tex: Texture2D = load("res://资源/fountain/fountain_radiant.png")
$Sprite2D.texture = tex
$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素图保持清晰
```

图片自带背景，放在棋盘格子里会是一整块方形。想让泉水和棋盘融为一体，需要先抠出透明背景的版本。

# 小兵头像（像素风）

天辉 / 夜魇各三种小兵：近战、远程、攻城。

| 文件 | 小兵 |
|---|---|
| `radiant_melee.png` | 天辉近战小兵 |
| `radiant_ranged.png` | 天辉远程小兵 |
| `radiant_siege.png` | 天辉攻城小兵 |
| `dire_melee.png` | 夜魇近战小兵 |
| `dire_ranged.png` | 夜魇远程小兵 |
| `dire_siege.png` | 夜魇攻城小兵 |

- 尺寸：258×258，PNG，**透明背景**（原图的灰色底板已去掉，人物底部贴着图片下沿）
- 原图：`creeps_source.png`（项目作者提供的六宫格截图，未改动）
- 处理方式：按原图方格边界裁切，只去掉与方格边缘相连的灰色底板，人物像素保持原样，没有缩放
- 尚未接入游戏；当前双方各有 4 个小兵，显示的是 `assets/icons/` 里的原创图标

## 在 Godot 里使用

```gdscript
var tex: Texture2D = load("res://资源/creeps/radiant_melee.png")
$Sprite2D.texture = tex
$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素图保持清晰
```

想直接替换现有小兵图标，可以把图复制到 `assets/portraits/`，改名为 `soldier_radiant.png` / `soldier_dire.png`（见该目录 README）。

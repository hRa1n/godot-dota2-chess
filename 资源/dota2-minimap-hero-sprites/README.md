# Dota 2 小地图英雄头像（dota2-minimap-hero-sprites）

Dota 2 游戏小地图上的英雄小头像，32×32 像素，透明背景。

- 来源：npm 包 [`dota2-css-hero-sprites`](https://www.npmjs.com/package/dota2-css-hero-sprites) **2.6.2**（2026-01 发布）
  - 是 [dota2-minimap-hero-sprites](https://github.com/RoccoFarrell/dota2-minimap-hero-sprites) 的更新分支，原版 2.4.0 停在 2022 年，缺少新英雄
- 内容：127 个英雄（截至 2025 年底的全部英雄，含 Largo、Kez、Muerta、Ringmaster），另有 50 张变体
- 原包里网页用的 CSS 没有放进来，只保留了图片

## 文件

| 路径 | 内容 |
|---|---|
| `minimap_hero_sheet.png` | 原始整图，512×512，所有头像拼在一起 |
| `heroes/<内部代号>.png` | 127 个英雄，每人一张 32×32 |
| `variants/<内部代号>.png` | 50 张变体：至宝/不朽外观（`_alt1`、`_persona1`）、召唤物（`druid_bear`、`brewmaster_earth` 等）、通用单位 `unit_no_cc` |
| `heroes.csv` | 索引：英雄 ID、内部代号、类型、在整图中的坐标、对应文件 |
| `LICENSE` | 原包的 MIT 许可（只覆盖原包代码；图片版权见下方） |

## 在 Godot 里使用

```gdscript
var tex: Texture2D = load("res://资源/dota2-minimap-hero-sprites/heroes/zuus.png")
$Sprite2D.texture = tex
$Sprite2D.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素图放大时保持清晰
```

## 内部代号对照

文件名用的是**游戏内部代号**，有些和常用名不一样。

当前游戏里的 6 个英雄：

| 英雄 | 文件 |
|---|---|
| 水晶室女 | `heroes/crystal_maiden.png` |
| 宙斯 | `heroes/zuus.png` |
| 剑圣 | `heroes/juggernaut.png` |
| 斧王 | `heroes/axe.png` |
| 混沌骑士 | `heroes/chaos_knight.png` |
| 屠夫 | `heroes/pudge.png` |

其他容易认错的：

| 内部代号 | 英雄 |
|---|---|
| `nevermore` | 影魔 Shadow Fiend |
| `furion` | 先知 Nature's Prophet |
| `wisp` | 艾欧 Io |
| `skeleton_king` | 冥魂大帝 Wraith King |
| `windrunner` | 风行者 Windranger |
| `rattletrap` | 发条技师 Clockwerk |
| `obsidian_destroyer` | 殁境神蚀者 Outworld Destroyer |
| `doom_bringer` | 末日使者 Doom |
| `shredder` | 伐木机 Timbersaw |
| `magnataur` | 马格纳斯 Magnus |
| `necrolyte` | 瘟疫法师 Necrophos |
| `life_stealer` | 噬魂鬼 Lifestealer |
| `abyssal_underlord` | 孽主 Underlord |
| `antimage` | 敌法师 Anti-Mage |
| `queenofpain` | 痛苦女王 Queen of Pain |
| `vengefulspirit` | 复仇之魂 Vengeful Spirit |
| `centaur` | 半人马战行者 Centaur Warrunner |
| `treant` | 树精卫士 Treant Protector |

## 版权

图片从 Dota 2 游戏文件导出，**版权归 Valve 所有**。本项目是免费、非商业的同人作品，使用这些图片须保持非商业：不收费、不卖道具、不放广告或接受赞助（见仓库根目录 README 的版权说明）。

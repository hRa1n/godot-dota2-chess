# godot-dota2-chess

用 Godot 4.7 制作的回合制卡牌棋子游戏（MOBA 风格）。

## 当前进度

- [x] 20×20 棋盘：格子坐标、悬停高亮、点击选中、行列编号
- [x] 摄像机：自动适配整张棋盘、滚轮/双指缩放、右键拖动或 WASD 平移、F 键复位
- [ ] 棋子
- [ ] 卡牌与回合流程

## 操作

| 操作 | 按键 |
|---|---|
| 选中格子 | 左键 |
| 缩放 | 滚轮 / 触控板双指捏合 |
| 平移 | 右键或中键拖动 / WASD / 方向键 / 触控板双指滑动 |
| 重新适配棋盘 | F |

## 目录

```
project.godot            项目配置（GL Compatibility 渲染，兼容网页）
scenes/main.tscn         主场景
scripts/board.gd         棋盘：坐标换算 API、绘制、输入
scripts/camera_controller.gd  摄像机控制
scripts/main.gd          信息栏
export_presets.cfg       网页导出配置（单线程，无需特殊响应头）
.github/workflows/deploy-web.yml  推送后自动导出并发布到 GitHub Pages
```

## 网页试玩

推送到 `main` 后，GitHub Actions 会自动导出网页版并发布到 GitHub Pages。
首次需要在仓库 **Settings → Pages → Source** 选择 **GitHub Actions**。

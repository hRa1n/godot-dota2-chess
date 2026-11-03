# AGENTS.md

给所有 AI 编程助手（Claude、Codex、Cursor、Copilot 等）读的项目说明。

## 项目概况

- Dota 2 主题的回合制「卡牌 + 棋子」游戏，**免费、非商业**的同人作品。
- 引擎 **Godot 4.7.2**，GDScript，GL Compatibility 渲染，网页导出为单线程版本。
- 规则、阵容、卡牌、操作、目录说明都在 `README.md`，改规则时要同步更新它。
- 数值集中在 `scripts/piece_defs.gd`。

## 工作方式（重要）

作者**不在本地安装任何东西**，所有开发都在云端完成：

1. AI 助手在云端克隆仓库，改代码。
2. 在自己的环境里装 Godot 4.7.2（无界面版即可，见 `.github/workflows/deploy-web.yml` 里的下载地址），然后自测：
   ```bash
   godot --headless --import
   godot --headless -s res://tests/test_rules.gd
   ```
   改了规则要在 `tests/test_rules.gd` 里补测试。测试坐标是内部坐标 `Vector2i(列, 行)`，从 0 开始；界面显示为「行-列」，从 1 开始。
3. 推送到 `main`，GitHub Actions 会自动导出网页版并发布到 GitHub Pages（地址见仓库 Settings → Pages）
4. 作者刷新链接试玩。

其他约定：
- 不要提交 `.godot/` 和 `build/`。
- `资源/` 只放原始素材，不打进网页导出包；游戏实际用的图片放在 `assets/` 下。
- Dota 2 素材版权归 Valve，项目必须保持非商业：不收费、不卖道具、不接广告或赞助。

## Skills（动手前先读）

`.agents/skills/` 下放着第三方的 Godot skill，来源和许可证见该目录的 `README.md`。做下面这些事之前，先读对应 skill 的 `SKILL.md`：

| 要做的事 | 先读 |
|---|---|
| 新建场景/脚本、调整目录结构 | `godot-project-foundations`、`godot-gdscript-mastery` |
| 回合流程、移动、眩晕/冷却/复活计时 | `godot-turn-system` |
| 牌库、手牌、技能卡、装备卡、效果结算 | `godot-genre-card-game` |
| 棋子/卡牌的数据定义（`piece_defs.gd`） | `godot-resource-data-patterns` |
| 棋盘、HUD、规则之间互相通知 | `godot-signal-architecture` |
| 写或扩展规则测试 | `godot-testing-patterns` |

skill 里的写法是建议，不是硬性要求。如果和本项目现有代码的结构冲突，以现有代码为准；要大改结构，先问作者。

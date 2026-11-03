# 第三方 Godot Skills

本目录下的 7 个 skill 原样复制自 [thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills)（commit `db004d7`），未做修改。
许可证：LGPL-3.0，全文见 `LICENSE-gd-agentic-skills`。

| Skill | 在本项目里的用途 |
|---|---|
| `godot-project-foundations` | 目录结构、命名规范、Autoload 基础 |
| `godot-gdscript-mastery` | 带类型的 GDScript 写法与代码风格 |
| `godot-genre-card-game` | 牌库、手牌、抽牌/弃牌、卡牌效果结算 |
| `godot-turn-system` | 回合流程、行动锁定、眩晕/冷却等回合计时、网格棋盘状态 |
| `godot-resource-data-patterns` | 棋子与卡牌的数据定义（对应 `scripts/piece_defs.gd`） |
| `godot-signal-architecture` | 棋盘、HUD、规则之间用信号解耦 |
| `godot-testing-patterns` | 扩展 `tests/test_rules.gd` 的规则测试 |

说明：
- `.agents/.gdignore` 让 Godot 跳过这个目录，里面的 `.gd` 示例脚本不会被导入，也不会打进网页包。
- SKILL.md 里指向其他 skill 的链接会跳回原仓库，这些 skill 本仓库没有收录，需要时再从原仓库复制。
- 这些 skill 是按 Godot 4.7+ 写的，本项目用的是 4.7.2。

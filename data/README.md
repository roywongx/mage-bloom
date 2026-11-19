# data · 离线 REA 数据

> 全部为派生事实表，不含第三方插件源码。构建基线：`1.60.1.70959`。
> 置信度：`verified` = 客户端/实测；`inferred` = 多源一致未实测；`todo` = 待游戏内验证。

| 文件 | 内容 | 来源 |
| --- | --- | --- |
| `client/mageprobe_1.60.1.70959.json` | 148 个技能的 id/名称/描述/读条/距离/冷却；玩家光环/目标 debuff | 客户端只读探针 `MageProbe` |
| `client/known_spells.json` | 46 个已学技能（角色约 36–37 级） | 同上 |
| `spells/dfspell_mage.json` | 法师三系全部技能与 rank（含自定义） | `DungeonsForeverSpell/Data_SpellBook.lua` |
| `spells/mage_spells.json` | 合并表：名称、所有 ID、rank、学习等级、探针状态 | DFSpell + 小六月 + 探针 |
| `auras/procs.json` | 热力迸发/寒冰指/飞弹连射/奥冲/冰盾/阅读魔网等的描述与 tip | 客户端探针 |
| `liuyue/spellbook_mage.json` | 小六月 1.3.4 法师技能表（含其缺失 rank 的问题） | 小六月 `Core/SpellBook.lua` |
| `liuyue/durations.json` | 小六月法师持续期（仅 17 条，奥冲 15s 已过期） | 小六月 `Core/SpellDuration.lua` |
| `liuyue/apl_mage.json` | 小六月三套法师 APL 原文（data/leveling/extra） | 小六月 `Core/APL.lua` |
| `liuyue/talents.json` / `gear.json` / `tips.json` / `voice.json` | 天赋预设/套装/提示/语音别名 | 小六月 |
| `client/spell_db_mage_1.60.1.70959.csv` | Wago DB2 导出的法师相关 Spell 行 | Wago Tools |
| `auras/wowhead_tooltips.json` | Wowhead tooltip API（dataEnv=4, locale=zhCN） | Wowhead |
| `spells/gamedata_mage_facts.json` | wowsims/gamedata 核实的技能数值（CD/层数/持续） | wowsims/gamedata |
| `titanforever/control_schema.json` | 128×12 控制块、TC01、flags、snapshot 字段 | `wow-ah/addon-forever` |
| `sao/proc_ids.json` | SAO Forever 分支的触发 ID 与冲突 | `SpellActivationOverlay/classes/mage.lua` |
| `thresholds.json` | 唤醒/奥冲/AOE/热力迸发/冰枪 CD 等阈值 | ForeverDB + WowSims + 探针 |

## 已知冲突 / 待验证

| 项 | 现状 |
| --- | --- |
| 寒冰指 buff | 已核实：`400647` 是天赋，`400669`/`400670` 都是 15s buff（400670 最多 2 层）；两者都监听 |
| 火焰易伤 | 已核实 `22959` 是 Fire Vulnerability（30s/5 层/+3%）；客户端 tooltip 名称“痛苦诅咒”是本地化冲突 |
| 冰枪 CD | 已核实 8s（wowsims/gamedata 1240047） |
| 寒冰护体 buff | 已核实 `1326891` 是 Frigid Power（60s/+15% 冰霜），由 13033 施加 |
| 天赋专精 | 探针 v0.2 已改用 `C_Talent`，待游戏内确认 |
| CLEU | 已注册，但尚未在战斗中验证 |

## 复现

```bash
REA_SRC=/home/roy/wow-addon-re python3 tools/extract_data.py
```

只读、离线；不修改游戏、不上传任何数据。

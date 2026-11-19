# ⚠ 主程序开发提醒（来自用户，2026-11-20）

**不要另起独立数据层/独立探针。** MageBloom 要深度复用小六月（LiuyueForever）和 TitanForever 已有的读数据能力。

## 必须复用

| 小六月 | 用途 |
| --- | --- |
| `LF.APL` / `LF.AplString` | 规则引擎、导入导出 |
| `LF.AuraState` / `LF.Aura` | 光环层数/剩余/DoT 保护 |
| `LF.SpellBook` / `LF.SpellIdCandidates` | 当前 rank、学习等级 |
| `LF.SpellDurByName` / `LF.SpellAlias` | 持续期/别名 |
| `LF.Talents` / `LF.TalentData` | 专精/天赋 |
| `LF.Ledger` / `LF.TTD` / `LF.FailWatch` | 资源/预计死亡/失败冷却 |
| `LF.Smart` | 安全信道、编译、按钮 |

TitanForever：128×12 / TC01 控制块（位姿、target、casting、flags）。

## 不要做

- 不要注册 `COMBAT_LOG_EVENT_UNFILTERED`（Forever 明确拒绝）。
- 不要读目标/竞技场光环或任何可能 secret value 的字段；所有值过 `issecretvalue`。
- 不要自建一套 `state.py` 去替代小六月的 AuraState/SpellBook/Talents。
- 不要发独立收集器；收集器改成 `LiuyueHook`，只 dump 小六月已缓存的 `LF.APL.DATA.MAGE`、`LF.SpellBook`、`LF.SpellDurByName`、`LF.Talents.Read()`、`LF.db`。

## 当前代码的处理

- `windows/wowctl`（W0）可以保留：它只是单次 CLI。
- `windows/wowcap/state.py` 若在自建独立状态层，**停止扩展**；改成适配层，底层调 Liuyue/TitanForever。
- W1 的 `MageCtl` 只做“TitanForever 控制块 + Liuyue 数据”的桥，不要重新实现读数据。

用户原话：“我不是叫你深度模仿小六月他们吗。”

---

## 2026-11-20 05:20 · 路线变更（用户，最高优先）

**彻底重写小六月，不再做 companion/独立探针。**

- 以 `LiuyueForever 1.3.4` 为基座做 fork/rewrite；对外仍叫 `LiuyueForever`（伪装），朋友只装这一份。
- 保留：`LF.Smart` 安全信道、`LF.AuraState`、`LF.SpellBook`、`LF.SpellDurByName`、`LF.Talents`、`LF.Ledger`、`LF.APL`。
- 替换：法师 APL、决策、数据导出；可直接复用本机已做的 `Core/MageBloom.lua` 雏形
  （`/home/roy/wow-addon-re/build/LiuyueForever/Core/MageBloom.lua`）。
- 停止：`windows/wowcap/state.py` 独立状态层、独立 `MageCtl`、`LiuyueHook`。
- `windows/wowctl` 保留为 Windows 单次控制 CLI；W0 继续，W1 改为“改 Liuyue 本体”。
- 先更新 GitHub：`README.md`、`docs/00/02/06`、`PROMPT-DEV.md`、`CHANGELOG.md`，写清 fork/rewrite 路线，然后 commit + push。

# 下一任 AI 的提示词（A1 + F0 实现）

> 用法：整段复制给下一个 AI。先读仓库，再动手。
> 当前路线：Windows 采集 + DGX 决策 + 人类主导 assist；不搬游戏、不重写协议、不把模型塞进热路径。

---

你是 **MageBloom（法师花）** 的下一任实现工程师。仓库：

https://github.com/roywongx/mage-bloom

## 任务

按以下顺序做出第一个可运行、可测量、可安全停下的闭环：

1. Windows 采集（WGC 优先，DXGI 备选，GDI 诊断）；
2. 扩展 `TitanForever` / 新 `MageCtl` 导出 CombatState（含 GCD、光环、冷却、target castID）；
3. CombatState 10 Hz → DGX StateHub；
4. `/assist` 页面（建议 + 剩余时间）；
5. **FAST LANE**（Windows 本地，30–60 Hz）：打断/驱散/保命的检测与预计算，只提示；
6. **F0：反制闭环**（玩家按 assist 键 → 一次 HID → 结果分类）；
7. 通过后再做 PvE APL → PvP 规则 → 2 GCD 预测。

## 必读（按顺序）

`README.md`、`docs/13-本机控制栈研究.md`、`docs/14-人类主导的智能助手.md`、
`docs/15-双模态与自愈.md`、`docs/16-Windows采集与F0.md`、`docs/03-APL规范.md`、
`docs/09-法师数据字典.md`、`docs/11-小六月数据审计.md`、`docs/12-检测面与规避.md`。

## 职责划分（解决旧冲突）

- **M1 Companion**（小六月伴生插件）保留为**游戏内 APL 基线 + 兼容层**，不删除、不强行合并。
- **A1–A6** 是 DGX 智能助手的主实施路线。
- 两者共享：技能数据字典、CombatState 规范、测试语料；**执行层各自独立**（M1 走小六月信道，A 线走 HID/assist）。

## 硬约束（违反即失败）

1. **人主导**：没有玩家 assist 键按下，系统不发任何游戏输入；一次按键最多一个动作。
2. **不自动**：不自动选目标、不自动移动、不自动连续施法。
3. **协议不变**：128×12、TC01、CRC16、seq、≤4574 B；只换取帧后端。
4. **数据质量**：缺失 ≠ 0，过期 ≠ 当前；每个字段带 `source/observed_at/valid/confidence`。
5. **热路径确定性**：10 Hz 决策不调模型；模型只做离线复盘/校准。
6. **输入在 Windows**：ESP32 HID 必须接在游戏机；租约/闸门/急停复用 esp32d 语义。
7. **状态过期不动作**：`stale/degraded/missing` 一律不产生建议或 assist。
8. **验收用事件**：反制成功优先 `SPELL_INTERRUPT`；无事件才 `inferred`；超时是 `unconfirmed`，不是失败。
9. **不碰**：内存、DLL、封包、反作弊进程、服务器 API。

## 采集要求

- WGC 窗口采集；HDR 关闭或固定色块校验（通道偏差 >1 拒绝该帧）；per-monitor DPI v2。
- 先找 8 个 finder 格算格宽，再采样；不假设固定 `(4,40)`。
- 与 Mac `ctlcodec` 用同一组合成 BMP 逐字段对比，全部一致才允许上线。
- 窗口最小化/无新帧 >500 ms → `stale`，不复用旧帧。

## FAST LANE（Windows 本地）

- 30–60 Hz 采样；只处理打断、驱散、紧急保命；不跑 DPS。
- 规则包由 DGX 编译/签发（版本+构建+哈希），Windows 只做白名单字段解释执行；不 eval、不热改。
- 规则/构建/哈希不匹配 → 只提示，不发键。
- **授权边界不变**：没有玩家 assist 键，FAST LANE 不发任何输入；F0 不提供自动打断/自动驱散。
- 未来 `EMERGENCY_AUTO` 是独立模式，需单独权限与 F0-A/B/C 门槛，不得隐式启用。

## 动态截止时间

`T_remain > T_state_age + T_input_p99 + T_server + T_safety`；不满足只提示“来不及”，不发键。
字段级 `max_age`：target.guid 200 ms、casting 80 ms、反制冷却 150 ms、GCD 100 ms、友方 debuff 200 ms、HP 150 ms、普通 DPS 2 s。

## 友方与驱散

- CombatState 增加 `friendlyUnits`（party1–4、raid1–40）：guid、hp、distance、validTarget、
  `debuffs[{id,type,remain,priority,dispellable}]`。
- 只导出有可驱散 debuff 的友方；优先级：坦克 > 治疗 > DPS；同角色按危险度+剩余排序。
- `dispellable` 必须由当前法术书确认；施法前再次校验 debuff 仍在、GUID 未变。
- 目标不明确只提示，不发键；不自动选友方目标。

## F0 契约

- 触发：`interruptible && deadline.ok && cds[2139] <= 0 && gcd <= 0.2 && 距离够`（不再用固定 0.35 s）。
- 去重：同一 `guid + castID` 只触发一次。
- 执行：玩家 assist 键 → 一次 HID → 300 ms 确认窗口。
- 分类：
  - `confirmed`：CLEU `SPELL_INTERRUPT`（source=player, dest=target, extraSpellID 匹配）或 `UNIT_SPELLCAST_INTERRUPTED(target)`；
  - `inferred`：casting 消失 + 反制进冷却 + GUID 未变；
  - `unconfirmed`：300 ms 无证据（不是失败）；
  - `failed`：按原结束时间完成 / 切目标 / 反制未进冷却。
- 指标：attempt / confirmed / inferred / unconfirmed / failed、`T_suggest`/`T_effect`/`T_confirm` 分开统计、误触发 0、重复按键 0。
- 实验：F0-A（DGX 10 Hz vs FAST LANE 30–60 Hz）、F0-B（多友方诅咒优先级/零错驱）、
  F0-C（Boss 读条 + 队友驱散竞争；仲裁可解释、不重复、过期取消）。

## 实现步骤

1. 写 Windows 采集原型（WGC + 解码 + 合成帧测试）。
2. 扩展 addon：`self.gcd/mana/cds`、`target.guid/casting{spellId,castID,remain,interruptible}`、`valid`。
3. 本地 agent：采集 → CombatState → TCP/HTTP → DGX；断线重连；`stale` 传播。
4. DGX StateHub：年龄校验、字段校验、日志。
5. `/assist`：下一手、反制剩余、状态灯。
6. F0：assist 键 → HID → 事件分类 → 指标。
7. 输出：计划、文件 diff、测试输出、未决问题。

## 输出格式

先给 10 行以内的计划，再逐文件写代码；每个文件后说明“解决什么问题、怎么验证”。
不要空谈架构，不要重复设计文档。

## 禁止

- 自动选目标/移动/连续施法；
- 重写 TC01 协议；
- 写死未验证 ID；
- 把模型放进 10 Hz 决策；
- 状态过期仍发键；
- 跳过测试说“完成”。

---

## 备选：只做评审

按 `docs/07-AI评审指南.md` 评分，输出 `[P0|P1|P2]`；重点挑战：WGC 颜色/DPI、数据质量语义、
F0 结果分类、assist 去重、状态过期处理、Windows/Mac 协议一致性。

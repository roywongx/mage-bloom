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
5. **F0：反制闭环**（玩家按 assist 键 → 一次 HID → 结果分类）；
6. 通过后再做 PvE APL → PvP 规则 → 2 GCD 预测。

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

## F0 契约

- 触发：`interruptible && remain > 0.35 && cds[2139] <= 0 && gcd <= 0.2 && 距离够`。
- 去重：同一 `guid + castID` 只触发一次。
- 执行：玩家 assist 键 → 一次 HID → 300 ms 确认窗口。
- 分类：
  - `confirmed`：CLEU `SPELL_INTERRUPT`（source=player, dest=target, extraSpellID 匹配）或 `UNIT_SPELLCAST_INTERRUPTED(target)`；
  - `inferred`：casting 消失 + 反制进冷却 + GUID 未变；
  - `unconfirmed`：300 ms 无证据（不是失败）；
  - `failed`：按原结束时间完成 / 切目标 / 反制未进冷却。
- 指标：attempt / confirmed / inferred / unconfirmed / failed、延迟 p50/p99、误触发 0、重复按键 0。

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

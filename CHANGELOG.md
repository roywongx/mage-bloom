# Changelog

所有改动记录在此。格式：日期 · 类型 · 摘要 · 关联文档/Issue。

## 0.1.6 — 2026-11-20（FAST LANE 双速紧急响应）

### Added
- `docs/17-低延迟紧急响应.md`：Windows FAST LANE（30–60 Hz）、DGX 规则包、动态截止时间、
  字段级 max_age、friendlyUnits/驱散、Action Arbiter、F0-A/B/C 实验。

### Changed
- `docs/15 §5.1` 改为“FAST LANE 只提示，不自动执行”；自动紧急响应是未来独立模式。
- `PROMPT-NEXT.md` 增加 FAST LANE、动态截止时间、友方驱散与 F0-A/B/C；F0 仍为 L2。
- 反制触发不再用固定 `remain > 0.35`，改为 `deadline.ok`。

## 0.1.5 — 2026-11-20（Windows 拍板 + F0 契约）

### Added
- `docs/15-双模态与自愈.md`：AUTO/PVE/PVP 状态机、常驻看门狗、R0–R5 自愈、自动打断边界。
- `docs/16-Windows采集与F0.md`：WGC 优先/DXGI 备选/GDI 诊断、TC01 不改、颜色/DPI/遮挡、
  数据质量语义、F0 反制结果分类（confirmed/inferred/unconfirmed/failed）。

### Changed
- `docs/13 §7` 从“待确认”改为拍板：Windows 采集、DGX 决策、Mac 参考基线。
- `PROMPT-NEXT.md` 重写为 A1+F0 路线；M1 Companion 降为游戏内基线，不强行合并执行层。
- 反制验收改为事件优先：`SPELL_INTERRUPT` → `UNIT_SPELLCAST_INTERRUPTED` → inferred；
  超时只算 unconfirmed，不算失败。

## 0.1.4 — 2026-11-20（人类主导的智能助手）

### Added
- `docs/14-人类主导的智能助手.md`：L0–L3 协助分级、CombatState schema、像素探针采样点、
  PvE/PvP 规则、建议回传通道对比、L2 一键 assist、延迟预算与 A1–A6 路线图。

### Decisions
- 产品形态改为“人主导 + 机器感知/建议”，L2 assist 需玩家按键触发。
- 建议回传首选 DGX `/assist` 副屏/平板 Web + TTS；不做游戏内网络通道。
- 像素只做固定点数值采样，本地解码，不送模型。

## 0.1.3 — 2026-11-20（本机控制栈研究）

### Added
- `docs/13-本机控制栈研究.md`：wow-ah 的色块/解码/statehub、ESP32 HID 租约与闸门、
  证据验收、AH 扫描循环、掉线恢复；给出 Mage Bloom v2 的战斗态字段与 F0 闭环。

### Findings
- 现有栈已解决结构化状态、硬件输入、外部证据验收；缺战斗态字段与 Windows 采集。
- 端到端现实预算 150–300 ms p99，不是 100 ms。
- 控制块 4608 B / 载荷 4574 B，够放 30 光环 + 10 冷却。

## 0.1.2 — 2026-11-20（检测面与规避）

### Added
- `docs/12-检测面与规避.md`：行为、输入、静态、账号四层检测面与缓解。
- 提示词加入“规避检测”硬约束：提交抖动、proc 反应、APM 上限、发布构建、日志策略、禁止项。

## 0.1.1 — 2026-11-20（客户端实测 + 数据审计）

### Added
- `docs/11-小六月数据审计.md`：版本线（1.3.1→1.3.4）、SpellBook/SpellDuration/APL/VoiceData 缺陷、客户端实测校正、升级结论。
- 只读探针 `MageProbe`：导出 148 个技能、工具 tip、光环、天赋；已抓到 1.60.1.70959 实测数据。
- 数据字典补充：400624 热力迸发 20s/3 层、400588/400589、400573 18s、1259705 阅读魔网、13033 寒冰护体。

### Changed
- 火焰易伤 `22959` 标记为冲突：客户端解析为“痛苦诅咒”，暂停在默认 profile 使用。
- 寒冰护体 buff `1326891` 更正为“极寒之力”。
- 明确角色约 36 级，APL 必须按名称解析当前 rank、未学跳过。

## 0.1.0 — 2026-11-20（设计基线）

### Added

- 项目总纲、竞品与机制研究、架构设计、APL 规范、安全派发通道、测试与验证、路线图、AI 评审指南；
- 小六月 1.3.4 架构级逆向分析；
- 法师数据字典（技能/触发 ID、阈值、置信度、待验证清单）；
- 三系 profile 草案（JSON）；
- ADR 0001–0005。

### Notes

- 本版本无可安装构建。
- 数据基线：客户端 `1.60.1.70959`，WowSims Forever `ui/specs/mage/dps/apls/*`，ForeverDB 2026-11-18。
- 待办：寒冰指 ID（400669/400670）实测、冰枪 CD、阅读魔网名称。

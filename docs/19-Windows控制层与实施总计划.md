# 19 · Windows 控制层与实施总计划

> 本文件是 M0.5 之后的总施工图：先把 Windows 变成可控、可观测、可停止的执行端，
> 再全面 REA 客户端与插件，最后按 W0–W6 交付 MageBloom。
> 硬规则：**没开游戏就不启动任何采集/agent 进程**。

## 1. 现状（已核实）

| 项 | 状态 |
| --- | --- |
| Windows SSH / PowerShell | 可用；`win` 别名免密 |
| Windows Python | 3.13.12；Pillow 12.3.0；numpy 2.5.1 |
| WoW 进程 | 当前未运行 |
| `bgcap`（炉石研究栈） | 6 个计划任务全部 Disabled；与 WoW 无关，只借模式 |
| Windows 插件 | `LiuyueForever` 1.3.4、`MageProbe`；**无** TitanForever |
| Windows ESP32 | 无 COM 设备（COM1/蓝牙）；HID 归属待定 |
| DGX 监听 | `8793` 炉石 vision、`8893` statehub、`8897` esp32d |
| 仓库 | 设计文档 M0–M0.5；无可运行构建 |

## 2. 控制层：先把 Windows 变成“可编程的手”

### 2.1 两种形态

| 形态 | 文件 | 生命周期 | 用途 |
| --- | --- | --- | --- |
| **一次性 CLI** | `windows/wowctl/wowctl.py` | 单次命令，跑完退出 | REA、截图、按键、诊断 |
| **常驻 agent（可选）** | `windows/wowcap/` | 仅 WoW 运行时启动，退出即停 | 10 Hz 状态、FAST LANE、F0 |

默认只有 CLI；常驻 agent 不是自启，必须由 `start-wowcap.cmd` 或“进程出现”事件拉起。

### 2.2 CLI 契约

```bash
python wowctl.py status                 # JSON: running/hwnd/rect/foreground/dpi
python wowctl.py capture out.bmp        # 窗口截图（PrintWindow/WGC），返回尺寸/哈希
python wowctl.py key F1 [hold_ms]       # 仅 WoW 前台；SendInput
python wowctl.py click X Y              # 仅 WoW 前台
python wowctl.py focus                  # 置前（可选）
```

退出码：`0` 成功；`2` 无 WoW/未前台；`3` 截图失败；`4` 参数错误。
所有输入命令先过 `gate()`：WoW 进程 + 窗口 + 前台 + 非最小化。

### 2.3 门控（硬规则）

1. `status` 以外，任何命令检测不到 `Wow.exe` 或窗口 → 直接退出，不重试。
2. 常驻 agent 启动时先检查；无游戏立即退出（不是空转）。
3. 游戏进程消失 → 2 s 内退出，释放按键。
4. 不创建登录/开机自启任务；不后台轮询 DGX。
5. `stop-wow` 文件存在 → 立即停；`HOLD` → 只观测不输入。
6. 单次会话最长 N 小时自动退出。

### 2.4 输入路径

| 方案 | 阶段 | 说明 |
| --- | --- | --- |
| SendInput | W0–W3 原型 | 现成、快；仅自建测试/测量 |
| ESP32-S3 HID | W4+ 目标 | 需物理接到 Windows；租约/闸门复用 |
| USB/IP | 不采用 | 延迟/稳定性不可控 |

## 3. 采集与状态

### 3.1 取帧

| 优先级 | 后端 | 备注 |
| --- | --- | --- |
| 1 | WGC | 窗口级；Win10 1903+；HDR/DPI 校验 |
| 2 | PrintWindow（`PW_RENDERFULLCONTENT`） | 兜底；WoW 可能黑屏，需检测 |
| 3 | GDI BitBlt | 诊断 |

### 3.2 协议

- 沿用 TC01 / CRC16 / 128×12 / ≤4574 B；先找 8 个 finder 再采样。
- 与 Mac `ctlcodec` 用同一组合成 BMP 逐字段对比。
- 10 Hz 常规；FAST LANE 只对 `target casting / gcd / cds[2139] / friendly debuff` 做 30–60 Hz 快采样。

### 3.3 数据质量

`source / observed_at / valid / confidence`；缺失 ≠ 0，过期 ≠ 当前；addon 与像素冲突时 addon 优先。

## 4. MageCtl 插件

Windows 侧新增（或扩展 TitanForever）：

| 字段 | 用途 |
| --- | --- |
| `gcd`, `mana`, `hp` | 资源/节奏 |
| `cast {id, remain, channel}` | 防断条 |
| `buffs [{id,n,rem}]` | 热力迸发/寒冰指/飞弹连射/节能 |
| `cds {id: remain}` | 反制/爆发/保命 |
| `target {guid, hp, casting{spellId,castID,remain,interruptible}}` | 打断 |
| `friendlyUnits [{guid,hp,debuffs}]` | 驱散 |
| `mode/context/health` | 双模态/自愈 |
| `events` | 施法/打断/光环事件（CLEU） |

输出走 128×12 控制块；预算 4574 B，友方只导出“有可驱散 debuff”的单位。

## 5. DGX 服务

```
wowcap → /wow/state（10 Hz） → statehub
wowcap fast → /wow/fast（30–60 Hz，仅紧急字段）
DGX brain：模式状态机 → PvE APL / PvP 规则 → /assist + TTS
DGX → 规则包（version/build/hash）→ Windows 本地解释器
```

- 没有状态帧 → DGX 不计算、不轮询。
- 规则包只由 DGX 签发；Windows 不 eval、不热改。
- 所有决策带 trace，可回放。

## 6. 全面 REA 清单

| 对象 | 要回答的问题 | 方法 |
| --- | --- | --- |
| 客户端 | build/Interface/API 可用性 | `GetBuildInfo`、探针 |
| 窗口/UI | 客户区、DPI、UI scale、颜色 | `wowctl status/capture` |
| 法术书 | 已学 rank、自定义技能 | `C_SpellBook`、`MageProbe` |
| 光环 | id/层数/剩余/来源 | `C_UnitAuras`、CLEU |
| 施法 | castID、interruptible、school | `UnitCastingInfo`、事件 |
| 目标/竞技场 | GUID、class、arena1-3 | Unit API |
| 友方 | party/raid debuff、距离 | Unit API + 过滤 |
| 插件 | Liuyue/TitanForever/SAO/DFSpell | 已完成 13/08/11 |
| 采集 | finder、颜色、HDR、遮挡 | 合成帧 + 实机 |
| 事件 | `SPELL_INTERRUPT` 等是否可用 | CLEU 实测 |

产出：数据字典增补、`verified/inferred/todo` 标记、探针脚本。

## 7. 施工阶段

| 阶段 | 交付 | 验收 |
| --- | --- | --- |
| **W0** | `wowctl.py`（status/capture/key/click/gate） | 无 WoW 时全部拒绝；有 WoW 时截图成功 |
| **W1** | `MageCtl` 最小导出（GCD/寒冰指/反制/CD） | 10 Hz 稳定，TC01 CRC 通过 |
| **W2** | Windows 解码 + DGX `/wow/state` + `/assist` | 与 Mac 合成帧逐字段一致 |
| **W3** | F0 反制（assist 一次 HID/SendInput） | confirmed/inferred/unconfirmed/failed 可统计 |
| **W4** | PvE APL + 模式状态机 | 木桩/副本一致率 |
| **W5** | PvP 规则 + friendlyUnits 驱散 | F0-B/C：零错驱、仲裁可解释 |
| **W6** | FAST LANE 30–60 Hz + 规则包 | F0-A 延迟 p50/p95/p99 |

## 8. 门禁（违反不得合并）

1. 无游戏即无进程；无自启；无后台轮询。
2. 无 assist 键不输入；一次按键最多一个动作。
3. 状态过期/缺失不动作。
4. 协议不重写；TC01 与 Mac 一致。
5. 未验证 ID 不进默认规则。
6. 模型不进 10 Hz 热路径。
7. F0 结果必须按事件分类，超时 ≠ 失败。

## 9. 风险

- SendInput 的检测面高于 HID；生产路径需换 ESP32。
- WGC 颜色/DPI/遮挡；WoW 可能全屏独占。
- 动作条映射变化；键位缺失即停。
- 4574 B 容量；友方/光环需裁剪。
- 双机时钟偏差；以 `observed_at` 为准。

## 10. 文件计划

```
windows/wowctl/wowctl.py          # W0 单次 CLI
windows/wowctl/README.md
windows/wowcap/capture.py          # W1–W2 常驻采集（门控）
windows/wowcap/start-wowcap.cmd
addon/MageCtl/MageCtl.toc
addon/MageCtl/Core.lua             # W1 状态导出
dgx/wow_state.py                   # W2 接收/校验
dgx/assist/                        # W2–W3 规则/面板
tests/fixtures/                    # 合成帧/状态
```

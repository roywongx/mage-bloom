# 18 · Windows 现状与复用边界

> 结论：Windows 上现成的 `bgcap` 是**炉石**研究控制台，不是 WoW 控制栈；只复用架构模式，
> 不复用游戏逻辑。所有新组件必须满足：**没开游戏就不启动、不轮询、不驻留**。

## 1. 现场盘点（2026-11-20）

| 项 | 状态 | 结论 |
| --- | --- | --- |
| `C:\Users\roywa\bgcap` | 炉石抓屏/结构化/输入研究栈；`bgcap-*` 6 个计划任务全部 **Disabled** | 不用于 WoW；只借模式 |
| `bgcap` 采集 | PrintWindow/GDI → `vision/detect.py` → JSON POST `DGX:8793/vision` | 模式可借：本地结构化、不发图 |
| `bgcap` 输入 | `inputd.py`（DGX:8791）+ `agent_hid.ps1`（Windows 轮询，SendInput） | 模式可借：队列/令牌/前台校验/stop |
| `MageProbe`（我们装的） | Windows `_forever_` 插件，仅游戏内运行 | 被动只读，可保留 |
| `LiuyueForever` | Windows `_forever_` 插件 | 基线 |
| `TitanForever` | **不在** Windows（只在 Mac 参考栈） | Windows 需新 `MageCtl` |
| WoW 进程 | 当前未运行 | 不应有任何采集/agent 进程 |
| ESP32 | Windows 无 COM 设备（仅 COM1/蓝牙）；DGX 侧 8897 在听 | HID 归属需确认/迁移 |

DGX 侧监听：`8793`（炉石 vision）、`8893`（statehub）、`8897`（esp32d）。

## 2. 复用矩阵

| 能力 | 可复用 | 不复用 |
| --- | --- | --- |
| 抓屏 → 本地结构化 → JSON | ✓ 模式（bgcap） | ✗ 炉石 `detect.py` |
| DGX 状态中枢 | ✓ statehub（8893） | — |
| 输入队列/令牌/前台校验/stop | ✓ 模式（inputd/agent_hid） | ✗ SendInput 作为长期方案 |
| 炉石窗口/模板/插件 | ✗ | ✗ 全部 |
| 计划任务 | ✗ 不自启 | — |

**WoW 专用件**：`wowcap`（WGC + TC01 解码 + 像素探针）、`wowagent`（前台校验 + HID/SendInput）、
`MageCtl`（CombatState 导出）、DGX `/wow/state`。

## 3. 硬规则：没开游戏就不启动

适用于所有新组件（采集、agent、FAST LANE、DGX 轮询）：

1. **启动门**：只有检测到 `Wow.exe` 且窗口存在才启动采集/agent；否则立即退出（不是空转）。
2. **退出门**：WoW 进程消失 → 采集/agent 在 2 s 内退出；释放按键、关闭句柄。
3. **不设自启**：不创建登录/开机计划任务；用桌面 `start-wowcap.cmd` 手动启动，或由“进程出现”事件拉起。
4. **DGX 不主动轮询**：没有状态帧就不查；不允许后台每 30 s SSH/HTTP 探活。
5. **stop/HOLD**：`stop-wow` 文件存在 → 立即停；`HOLD` → 只观测不输入。
6. **最长运行**：单次会话超过 N 小时自动退出（配置），防止忘关。
7. **日志**：只在会话内写；退出时不保留截图/原始帧。

> 这不是“优化项”，是硬约束：任何违反“无游戏即无进程”的实现都不得合并。

## 4. 输入路径

| 方案 | 现状 | 风险 | 建议 |
| --- | --- | --- | --- |
| SendInput（bgcap 模式） | Windows 现成 | 软件注入、Warden 风险、需前台/令牌 | 仅原型/自建测试 |
| ESP32-S3 HID | DGX/Mac 有栈，Windows 未接 | 需物理接到 Windows | **目标方案** |
| USB/IP / 远程 HID | 未验证 | 延迟/稳定性 | 不作为首版 |

首版可以先用 SendInput 打通 F0-A 的**测量**，但生产路径必须是 HID；两者共用同一 `wowagent` 接口。

## 5. 与 FAST LANE 的关系

- `wowcap` 负责 10 Hz CombatState + 30–60 Hz 像素快采样（仅紧急字段）。
- `wowagent` 负责前台校验、令牌、stop、HID 提交；不自己做决策。
- DGX 只接收状态、签发规则包；没有游戏时不运行/不轮询。

## 6. 下一步

1. 写 `wowcap` 最小版：找到 WoW 窗口 → WGC/PrintWindow → 解码 TC01 → POST `/wow/state`；带启动/退出门。
2. 写 `start-wowcap.cmd`：检测 `Wow.exe`，没有就打印并退出。
3. `wowagent`：复用 bgcap 的令牌/前台/stop 模式，先 SendInput，后换 HID。
4. `MageCtl`：导出 GCD/光环/冷却/target castID/friendlyUnits。
5. F0-A：没有游戏时不产生任何进程；有游戏时才测延迟。

# Windows 现状盘点（2026-11-20）

| 项 | 值 |
| --- | --- |
| 主机 | `win`（192.168.50.215，用户 roywa） |
| WoW | `C:\Program Files (x86)\World of Warcraft\_forever_`，客户端 build 70959 |
| 插件 | `LiuyueForever` 1.3.4、`MageProbe` |
| Python | 3.13.12；Pillow 12.3.0；numpy 2.5.1 |
| 计划任务 | `bgcap-*` 6 个，全部 Disabled（炉石研究栈） |
| 炉石栈 | `C:\Users\roywa\bgcap`：PrintWindow → 本地结构 → POST DGX:8793；`inputd.py` + `agent_hid.ps1`（SendInput） |
| ESP32 | Windows 无 COM 设备；DGX 侧 8897 监听 |
| WoW 进程 | 盘点时未运行 |

## 复用结论

- 只复用 bgcap 的“模式”（本地结构化、只发 JSON、令牌/前台/stop 门控）；
- 不复用炉石 detect/模板/插件；
- WoW 采集与输入独立实现，且必须满足“无游戏即无进程”。

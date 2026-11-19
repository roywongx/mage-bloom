# PROMPT-DEV · 正式开发（W0 优先）

> 2026-11-20 路线变更：**不再 companion/独立探针**。以 `LiuyueForever 1.3.4` 为基座 fork/rewrite，
> 对外仍叫 `LiuyueForever`，把 MageBloom 放进本体 `Core/MageBloom.lua`。先读 `docs/22`。
> W0（wowctl）保留；W1 改为“改 Liuyue 本体”，不再做独立 `MageCtl/state.py`。
> 基线：`main = 3c4b745`。本轮只做 **W0**，通过验收后再做 W1。
> 离线 REA 已完成，数据在 `data/`；当前 Windows 没有 WoW 进程，禁止启动常驻采集/agent。

---

你是 **MageBloom（法师花）** 的正式开发工程师。仓库：

https://github.com/roywongx/mage-bloom

先读：`README.md`、`docs/13`–`docs/19`、`data/README.md`、`PROMPT-NEXT.md`。

## 本轮任务：W0 `windows/wowctl/wowctl.py`

只写一个**单次命令、跑完退出**的 Windows 控制 CLI；不要 daemon、不要循环、不要自启。

### 命令

```bash
python wowctl.py status
python wowctl.py capture out.bmp
python wowctl.py key NAME [hold_ms]
python wowctl.py click X Y
python wowctl.py focus
```

### 行为

- `status`：输出 JSON（`running/pid/hwnd/title/rect/client_rect/foreground/dpi/minimized`）。
  没有 WoW 时 `running=false`，退出码 0。
- `capture`：找 WoW 主窗口，`PrintWindow(PW_RENDERFULLCONTENT)` 优先，失败退 `BitBlt`；
  保存 BMP；检测全黑帧；输出 `{ok,path,width,height,mean,sha256}`。无 WoW 退出码 2。
- `key` / `click`：必须先过 gate（Wow.exe + 窗口 + 前台 + 非最小化），否则退出码 2；
  用 `SendInput`（scan code），按下/抬起默认 60 ms，可传 `hold_ms`。
- `focus`：尝试置前；失败如实报告，不重试。
- 退出码：0 成功、2 无游戏/未前台、3 截图失败、4 参数错误。
- 进程级 DPI awareness（per-monitor v2）。
- 不创建计划任务、不写自启、不驻留、不轮询。
- 所有 API 失败都要有 JSON/文本原因，不静默。

### 找窗口

- 进程名 `Wow.exe`（可能有多个，取有主窗口且客户区最大的）。
- 标题优先 `World of Warcraft`；找不到就按进程 + `IsWindowVisible` + 客户区面积。
- 排除最小化窗口（`IsIconic`）。

### 测试（必须给出结果）

1. 无游戏：`status` 返回 `running=false`，退出 0；`capture`/`key`/`click` 退出 2，不产生文件。
2. 命令跑完 `Get-Process python` 不应留下新进程。
3. 参数错误退出 4（如 `key` 缺名字、`click` 非数字）。
4. 有游戏时（如果本机可启动）：`capture` 生成非黑 BMP；`status` 的 hwnd/rect 与窗口一致；
   `key` 仅在 WoW 前台成功。
5. 把 `status`/`capture` 的真实输出贴出来。

## 硬约束

1. **无游戏即无进程**：没有 WoW 就不启动、不轮询、不驻留。
2. 不自动施法/选目标/移动；`key`/`click` 只执行用户/调用方明确要求的一次动作。
3. 不改游戏文件、不注入进程、不读写内存。
4. 不写死未验证 ID；数据用 `data/`。
5. 不引入需要安装的第三方依赖；优先 `ctypes` + 标准库（Pillow/numpy 已存在，可选用）。
6. 不写文档凑数；代码 + 测试输出优先。

## 交付

- `windows/wowctl/wowctl.py`
- `windows/wowctl/README.md`（10 行以内，命令示例）
- 测试输出（无游戏 gate、参数错误、有游戏截图如果可测）
- 明确说明：下一步 W1 需要什么（MageCtl 最小字段、TC01 解码）

## 输出格式

先给 10 行以内的计划，再逐文件写代码；每个文件后说明“解决什么问题、怎么验证”。
不要空谈架构，不要跳过测试说“完成”。

## 不要做

- 不要写 W1/W2/W3 的代码；
- 不要实现常驻 agent、FAST LANE、DGX 服务；
- 不要修改小六月或游戏文件；
- 不要在无游戏时启动任何进程。

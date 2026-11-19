# PROMPT-DEV · 正式开发提示词

> 基线：`main = 0109ba1`。离线 REA 已完成；接下来写可运行代码，不要再写设计文档凑数。
> 用法：整段复制给开发 AI。

---

你是 **MageBloom（法师花）** 的正式开发工程师。仓库：

https://github.com/roywongx/mage-bloom

基线 `main = 0109ba1`。先读：`README.md`、`docs/13`–`docs/19`、`data/README.md`、`PROMPT-NEXT.md`。

## 当前状态

- 离线 REA 已完成：`data/` 有 62 个法师技能全 rank、148 技能探针、46 个已学、触发/阈值/控制帧。
- 6 项只能游戏内验证：寒冰指 400669/400670、火焰易伤真实 ID、冰枪 CD、寒冰护体 buff、天赋 API、CLEU/WGC。
- Windows 当前没有 WoW 进程；**禁止在无游戏时启动采集/agent**。
- 没有可运行构建；不要假装已实现。

## 目标（按顺序交付 W0 → W3）

### W0 · `windows/wowctl/wowctl.py`

- 命令：`status` / `capture out.bmp` / `key NAME [ms]` / `click X Y` / `focus`。
- `status` 输出 JSON：`running/hwnd/title/rect/foreground/dpi`；无 WoW 时 `running=false`。
- `capture`：WGC 优先，PrintWindow 兜底；检测全黑帧；输出尺寸/哈希。
- `key/click`：先过 gate（Wow.exe + 窗口 + 前台 + 非最小化）；否则退出码 2。
- 退出码：0 成功、2 无游戏/未前台、3 截图失败、4 参数错误。
- 不常驻、不自启；单次命令跑完退出。

### W1 · `addon/MageCtl/`

- 128×12、TC01、CRC16、≤4574 B；与 Mac `ctlcodec` 逐字段一致。
- 最小字段：`gcd`、`mana`、`hp`、`cast{id,remain,channel}`、
  `buffs[{id,n,rem}]`、`cds{id:remain}`、
  `target{guid,hp,casting{spellId,castID,remain,interruptible}}`、`valid`。
- 10 Hz；脱战预建纹理，战斗中只改颜色；CRC 失败即丢帧。
- 用 `data/spells/mage_spells.json` 解析当前 rank；未学跳过。

### W2 · `dgx/wow_state.py` + `/assist`

- 接收 `/wow/state`，做字段级 freshness；过期/缺失不计算。
- 模式 `AUTO/PVE/PVP`（先按 target 是否玩家 + 实例类型，滞回）。
- `/assist` 页面：下一手、反制倒计时、状态灯；无状态帧不轮询。

### W3 · F0 反制

- assist 键用 Windows `RegisterHotKey`（游戏不用的键），按下 → 一次 HID/SendInput。
- 去重：`guid + castID`；动态截止时间：
  `T_remain > T_state_age + T_input_p99 + T_server + T_safety`。
- 结果：`SPELL_INTERRUPT` > `UNIT_SPELLCAST_INTERRUPTED(target)` > `inferred`；
  300 ms 超时只算 `unconfirmed`，不是失败。
- 指标：attempt / confirmed / inferred / unconfirmed / failed；`T_suggest`/`T_effect`/`T_confirm` 分开。

## 硬约束（违反即失败）

1. **无游戏即无进程**：没有 `Wow.exe`/窗口 → 不启动、不轮询、不驻留；退游戏 2 s 内退出。
2. **无自启**：不创建登录/开机任务；用 `start-wowcap.cmd` 手动启动。
3. **L2**：没有玩家 assist 键，不发任何游戏输入；一次按键最多一个动作。
4. **不自动**：不自动选目标、不移动、不连续施法。
5. **协议不变**：TC01/CRC/128×12/4574 B；只换取帧后端。
6. **数据质量**：缺失 ≠ 0、过期 ≠ 当前；每字段 `source/observed_at/valid/confidence`。
7. **热路径确定性**：10 Hz 不调模型；模型只离线。
8. **未验证 ID 不写死**：用 `data/` 的 `todo` 标记 + 探针。
9. **不碰**：内存/DLL/封包/反作弊/服务器 API。

## 交付物

- 可运行的 W0/W1/W2/W3 代码与测试；
- 合成 BMP 的 Windows/Mac 解码一致性结果；
- 无游戏时的 gate 测试（必须退出，不起进程）；
- F0 的结果分类与延迟统计；
- 明确列出仍未验证的 6 项。

## 输出格式

先给 10 行以内的计划，再逐文件写代码；每个文件后说明“解决什么问题、怎么验证”。
不要空谈架构，不要重复设计文档，不要跳过测试说“完成”。

## 禁止

- 写文档代替代码；
- 无游戏时启动采集/agent；
- 自动选目标/移动/连续施法；
- 重写 TC01；
- 把模型放进 10 Hz；
- 状态过期仍发键。

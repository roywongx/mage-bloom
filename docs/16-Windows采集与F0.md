# 16 · Windows 采集与 F0 契约

> 决策：游戏留在 Windows；采集端部署在游戏机；DGX 决策；Mac 只做协议参考与回归。
> 本文固定三件事：取帧后端、数据质量语义、F0 反制闭环的验收口径。

## 1. 拓扑

```
Windows 游戏机
  WoW _forever_ + TitanForever / MageCtl
     └─ 128×12 控制块（TC01 / CRC16 / seq / ≤4574 B）
  Windows Capture（WGC 优先）
     └─ 解码 + 像素探针 → CombatState（10 Hz）→ LAN → DGX
  ESP32-S3 HID
     └─ 租约 / 闸门 / 急停（复用 esp32d 语义）
DGX
  StateHub → 模式状态机 → PvE/PvP 规则 → /assist + TTS + Replay
Mac
  ScreenCaptureKit + ctlcodec：协议参考实现与离线一致性测试
```

## 2. 取帧后端

| 优先级 | 后端 | 适用 | 限制 |
| --- | --- | --- | --- |
| 1 | **WGC**（Windows.Graphics.Capture） | 窗口/边框化全屏 | Win10 1903+；最小化无帧；HDR 需验证 |
| 2 | DXGI Desktop Duplication | WGC 不可用/全屏独占 | 整屏捕获后裁窗口；HDR 会 tone-map |
| 3 | GDI BitBlt / PrintWindow | 诊断 | 色彩管理不可控，不作为生产 |

### 2.1 WGC 要点

- `GraphicsCaptureItem` 用 `CreateForWindow(hwnd)`；窗口必须存在且未最小化。
- `Direct3D11CaptureFramePool.CreateFreeThreaded`，`GraphicsCaptureSession.StartCapture`。
- `IsCursorCaptureEnabled = false`（光标不参与采样）；Win11 可设 `IsBorderRequired = false`。
- 每帧 `Surface` → 复制到 staging texture → Map → 采样；不持有 `Surface` 跨帧。
- 帧超时（>500 ms 无新帧）= `stale`，不得复用上一帧。
- 窗口被遮挡不影响 WGC；最小化/锁屏会停帧，按 `stale` 处理。

### 2.2 颜色与 DPI

- 进程声明 **per-monitor DPI awareness v2**；所有坐标用物理像素。
- 客户端矩形用 `GetClientRect` + `ClientToScreen`；不要用窗口外框。
- HDR：优先关闭 HDR 或请求 SDR 表面；若只能拿到 FP16/色调映射，必须用固定色块校验，
  任一通道偏差 >1 即判该帧不可用。
- 分辨率/UI scale 变化：重新定位 finder，不缓存旧 cell 尺寸。

## 3. 协议：不重写

沿用现有 TC01：

- 128 列 × 12 行 × 4 px 格；前 8 格是固定 finder/校准。
- `TC01 | payload_len u16 | seq u16 | JSON utf-8 | CRC16`；`MAX_PAYLOAD = 4574`。
- 解码失败（缺格、CRC、截断、finder 不匹配）→ `ValueError`，调用方当 `unknown`。
- **定位方式**：先找 8 个 finder 格，算出格宽 `k`，再按 `(x0 + col*k, y0 + row*k)` 采样中心像素；
  不假设固定 `(4,40)`（UI scale 会改变物理位置）。

### 3.1 与 Mac 一致性测试

1. 用 `ctlcodec.encode_packet` 生成已知 JSON 的合成 BMP（含 finder）。
2. Windows 解码器输出必须与 Mac `decode_bmp` 逐字段一致（JSON 规范化后比较）。
3. 覆盖：100%/125%/150% DPI、窗口 1280×720/1920×1080/2560×1440、HDR 开/关、窗口被遮挡。
4. 任一用例失败 → 该后端不得上线。

## 4. 数据质量语义

每个字段必须带：

```json
{"v": 0.42, "source": "addon|pixel|api", "observed_at": 1760000000.12,
 "valid": true, "confidence": 0.98}
```

三条铁律：

1. **缺失 ≠ 0**：没读到就是 `valid=false`，不得当默认值。
2. **过期 ≠ 当前**：超过 `max_age`（addon 2 s / pixel 0.2 s）即 `valid=false`。
3. **冲突要标记**：addon 与 pixel 不一致时，addon 优先，另一路标 `disagree`，并记 incident。

## 5. F0：反制闭环

### 5.1 最小 CombatState

```json
{
  "seq": 10231,
  "build": "1.60.1.70959",
  "self": {"gcd": 0.0, "cds": {"2139": 0.0}, "mana": [4210, 5210]},
  "target": {
    "guid": "0x...",
    "casting": {"spellId": 12345, "castID": 77, "remain": 0.8, "interruptible": true}
  },
  "valid": true
}
```

### 5.2 触发条件

- `target.casting.interruptible == true`
- `target.casting.remain > 0.35`（留出状态+输入延迟）
- `self.cds[2139] <= 0`（反制可用）
- `self.gcd <= 0.2`
- 目标在反制距离内（`IsSpellInRange`，读不到则保守不触发）
- 同一 `guid + castID` 只触发一次

### 5.3 执行

- 玩家按 **assist 键**（Windows 全局热键或专用小键盘），本地 agent 发一次 `assist` 请求。
- DGX 返回一个技能键；esp32d 持租约、过闸门、发一次 HID。
- 没有 assist 键按下，不发任何游戏输入。
- 超时：从按键到期望状态变化 **300 ms** 为确认窗口；超时只标 `unconfirmed`。

### 5.4 结果分类（修正）

| 状态 | 判据 |
| --- | --- |
| `confirmed` | CLEU `SPELL_INTERRUPT`：source=player，dest=target，`extraSpellID` = 被打断法术，500 ms 内 |
| `confirmed`（无 CLEU 时） | addon `UNIT_SPELLCAST_INTERRUPTED`（unit=target，spellID 匹配） |
| `inferred` | 无上述事件；但 target casting 在 300 ms 内消失 **且** 反制进入冷却 **且** target GUID 未变 |
| `unconfirmed` | 300 ms 内没有足够证据；**不等于失败** |
| `failed` | 目标施法按原结束时间完成、或目标切换、或反制未进冷却（>1 s） |

> “目标 casting 消失”单独不能证明反制成功：也可能是自然结束、取消或切目标。

### 5.5 指标

- 尝试数、`confirmed`、`inferred`、`unconfirmed`、`failed`。
- 端到端延迟 p50/p99（assist 键 → 状态变化）。
- 误触发：目标不可打断/距离不够/无冷却时仍发键的次数（目标 0）。
- 重复按键：同一 `guid+castID` 多次发送（目标 0）。

## 6. 验收用例

| 编号 | 用例 | 通过条件 |
| --- | --- | --- |
| W1 | 合成 BMP 解码 | 与 Mac 逐字段一致 |
| W2 | 窗口遮挡 | 仍能解码；最小化 → `stale` |
| W3 | DPI 100/125/150 | finder 定位正确，CRC 通过 |
| W4 | HDR 开/关 | 固定色块偏差 ≤1，否则拒绝 |
| W5 | 目标读条可打断 | 产生建议，不自动发键 |
| W6 | assist 一次 | 只发一个键；CLEU/中断事件确认 |
| W7 | 超时 | 标 `unconfirmed`，不重按 |
| W8 | 状态过期 | 不产生建议/不 assist |

## 7. 非目标

- 不自动选目标、不自动移动、不自动连续施法。
- 不把模型放进 10 Hz 热路径。
- 不重写 128×12/TC01 协议；不修改 Mac 参考实现的行为。

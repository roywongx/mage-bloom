# 03 · APL 规范（v1）

> APL = Action Priority List。规则是**数据**，引擎是**解释器**；新增专精不改引擎。

## 1. 规则结构

```lua
{
  id    = "frost.lance.fof",     -- 全局唯一，命名：<spec>.<spell>.<variant>
  spell = "冰枪术",               -- 客户端本地化名称（zhCN）
  spellId = 1240047,             -- 可选；用于日志/冷却/校验
  -- 以下全部为 guard；全部通过才命中
  target = true,
  buff = { id = 400669, minStacks = 1 },
  -- ...
}
```

### 1.1 字段类型

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 必填，唯一 |
| `spell` | string | 必填，技能名（zhCN） |
| `spellId` | number | 推荐；用于冷却与 trace |
| `target` | bool | 需要敌对且存活目标 |
| `helpful` | bool | 友方目标（治疗用，法师暂不用） |
| `cd` | bool | 技能冷却就绪（含 GCD 判定） |
| `cdBelow` | number | 冷却剩余 < N 秒（用于"快好了"） |
| `buff` | table | 玩家增益存在且满足条件 |
| `buffMissing` | table | 玩家增益不存在（可带 `remainBelow` 表示快过期） |
| `debuff` | table | 目标减益存在且满足条件 |
| `debuffMissing` | table | 目标减益不存在 |
| `debuffBelow` | table | 目标减益层数 < `stacks` **或** 剩余 < `remain`（任一成立） |
| `manaPctAbove` | number | 法力 ≥ N% |
| `manaPctBelow` | number | 法力 ≤ N% |
| `hpPctBelow` | number | 玩家血量 ≤ N% |
| `targetHpBelow` | number | 目标血量 ≤ N% |
| `aoe` | number | 敌对姓名板 ≥ N |
| `moving` | bool | 玩家在移动 |
| `notChanneling` | bool | 不在引导 |
| `notCasting` | number/string | 当前读条不是该技能（防自我打断） |
| `interrupt` | bool | 目标在读条且可打断 |
| `burst` | bool | 配置里"爆发"开启 |
| `clearcasting` | bool | 节能施法（12536）存在 |
| `item` | number | 饰品槽 13/14 就绪 |
| `alsoReady` | number | 另一个技能就绪（用于 PoM + 奥术愤怒） |
| `config` | string | 需要某个配置开关为 true |
| `range` | bool | 距离检查（默认对 `target` 规则开启） |

### 1.2 光环条件子字段

```lua
buff = {
  id = 400625,          -- 优先用 ID；名称仅作回退
  name = "热力迸发",
  minStacks = 3,
  maxStacks = nil,
  remainBelow = nil,    -- 剩余时间 < N 秒
}
```

**规则**：触发类（层数/窗口）一律用 **ID**；不要用名称，因为不同 rank/不同来源可能重名。

## 2. 求值语义

1. **顺序即优先级**：从第 1 条开始，第一条全 guard 通过者胜出。
2. **全局前置**（先于所有规则）：
   - 玩家死亡/幽灵/坐骑/ taxi → 无推荐；
   - 无目标或目标友方 → 仅允许无 `target` 的规则；
   - 配置 `enabled=false` → 无推荐。
3. **技能前置**（每条规则自动附加）：
   - 技能未学会 → 跳过；
   - `C_Spell.IsSpellUsable` 明确为 false（蓝不够）→ 跳过；
   - `range=true` 且 `IsSpellInRange` 明确为 false → 跳过；
   - 正在引导且候选非瞬发 → 跳过（除非 `notChanneling=false`）。
4. **同 tick 稳定**：同一快照只求值一次；UI 与派发使用同一结果。
5. **禁止隐式副作用**：guard 不求值施法、不改属性、不发消息。

## 3. Profile 元数据

```lua
return {
  schema = 1,
  class = "MAGE",
  spec = "FROST",
  game_build = "1.60.1.70959",
  source = {
    apl = "wowsims/forever@93fde3d",
    notes = "https://tellmenext.cc/zh/forever/mage-frost/",
    db  = "foreverdb.net build 1.60.1.70959",
  },
  updated_at = "2026-11-20",
  changelog = {
    { date = "2026-11-20", change = "初版：寒冰指冰枪、AOE 组、唤醒阈值" },
  },
  rules = { ... },
}
```

`game_build` 不匹配时只告警，不阻止加载；但 trace 记录，便于排查"为什么和模拟器不一样"。

## 4. 三系初版规则

### 4.1 冰霜（FROST）

```lua
rules = {
  { id="frost.interrupt", spell="法术反制", interrupt=true, target=true,
    config="interrupt" },

  { id="frost.evo", spell="唤醒", manaPctBelow=12, notChanneling=true },

  { id="frost.barrier", spell="寒冰护体", cd=true,
    buffMissing={ id=1326891, name="寒冰护体" } },

  { id="frost.block", spell="寒冰屏障", hpPctBelow=25, config="defensive" },

  { id="frost.lance.fof", spell="冰枪术", target=true,
    buff={ id=400669, name="寒冰指", minStacks=1 } },

  { id="frost.coc.aoe", spell="冰锥术", target=true, aoe=3,
    buff={ id=400669, minStacks=1 } },

  { id="frost.blizzard.aoe", spell="暴风雪", target=true, aoe=3,
    manaPctAbove=15 },

  { id="frost.fireblast.move", spell="火焰冲击", target=true, moving=true,
    config="fireblast" },

  { id="frost.bolt", spell="寒冰箭", target=true },
}
```

取舍说明：

- 冰枪只在寒冰指期间放（WowSims 同款）；冰枪 8 秒 CD 由 `cd` 隐式兜底（不满足就跳过后续？不——冰枪在 CD 时 `IsSpellUsable` 仍为 true，但点击会失败；因此冰枪规则应加 `cd=true`）。**修正：所有主动技能默认要求 `cd=true`，填充技能除外**（见 §6 校验）。
- 暴风雪要求 3 目标；WowSims 的 AOE 组在寒冰指期间优先冰锥/冰枪。
- 深冬之寒（12579）仅作为冰锥条件出现在模拟器；首版不纳入，避免依赖未验证的 debuff。

### 4.2 火焰（FIRE）

```lua
rules = {
  { id="fire.interrupt", spell="法术反制", interrupt=true, target=true, config="interrupt" },
  { id="fire.evo", spell="唤醒", manaPctBelow=15, notChanneling=true },
  { id="fire.block", spell="寒冰屏障", hpPctBelow=25, config="defensive" },

  { id="fire.pyro.hs", spell="炎爆术", target=true,
    buff={ id=400625, name="热力迸发", minStacks=3 },
    notCasting=18809 },

  { id="fire.blast", spell="火焰冲击", target=true, cd=true },

  { id="fire.scorch.refresh", spell="灼烧", target=true, config="scorch",
    debuffBelow={ id=22959, name="火焰易伤", stacks=5, remain=5 } },

  { id="fire.ab.buff", spell="奥术冲击", target=true, config="abInFire",
    buffMissing={ id=400573, name="奥术冲击" } },

  { id="fire.am.barrage", spell="奥术飞弹", target=true, notChanneling=true,
    buff={ id=400589, name="飞弹连射" } },

  { id="fire.ball", spell="火球术", target=true },
  { id="fire.scorch.fill", spell="灼烧", target=true },
}
```

说明：

- 热力迸发 **=3 层**才炎爆（WowSims `deepFire` 同款）；`notCasting` 防止在炎爆读条中再次推荐。
- 奥术冲击仅在"有该天赋且 buff 缺失"时穿插（`deepFire` 同款）；`IsSpellKnown` 自动兜底。
- 火球前判断"火焰冲击 CD ≥ 火球读条"是模拟器细节，首版交由优先级近似，M2 再补。

### 4.3 奥术（ARCANE）

```lua
rules = {
  { id="arcane.interrupt", spell="法术反制", interrupt=true, target=true, config="interrupt" },
  { id="arcane.evo", spell="唤醒", manaPctBelow=10, notChanneling=true },
  { id="arcane.block", spell="寒冰屏障", hpPctBelow=25, config="defensive" },

  { id="arcane.ap", spell="奥术强化", cd=true, burst=true, manaPctAbove=40 },

  { id="arcane.pom", spell="气定神闲", cd=true, burst=true,
    alsoReady=1326082 },

  { id="arcane.am.barrage", spell="奥术飞弹", target=true, notChanneling=true,
    buff={ id=400589, name="飞弹连射" } },

  { id="arcane.ab.stack", spell="奥术冲击", target=true,
    buff={ id=400573, name="奥术冲击", maxStacks=3 } },

  { id="arcane.wrath", spell="奥术愤怒", target=true, cd=true },

  { id="arcane.blast", spell="火焰冲击", target=true, cd=true },

  { id="arcane.ab.mana", spell="奥术冲击", target=true, manaPctAbove=25 },

  { id="arcane.ae.aoe", spell="魔爆术", target=true, aoe=3 },

  { id="arcane.frostbolt.oom", spell="寒冰箭", target=true, manaPctBelow=25 },
}
```

说明：

- 奥冲层数用 `maxStacks=3` 表达"少于 4 层继续叠"。
- 飞弹连射优先于叠层（WowSims `arcane` 同款）。
- 奥术愤怒就绪时先气定神闲；PoM 无 GCD，下一 tick 自然接奥术愤怒。
- 25% 法力阈值来自 ForeverDB 的模拟器行为，作为默认值，可配置。

## 5. 与 WowSims APL 的映射

| WowSims 条件 | 本项目字段 |
| --- | --- |
| `auraNumStacks == 3` | `buff={id, minStacks=3, maxStacks=3}` |
| `auraIsActive` | `buff={id}` |
| `auraIsInactive` | `buffMissing={id}` |
| `auraRemainingTime <= 3` | `buffMissing={id, remainBelow=3}` 或 `buff={id, remainBelow=3}` |
| `sourceUnit: Target` | `debuff={unit="target", ...}` |
| `spellIsReady` | `cd=true` |
| `spellIsCasting` | `notCasting=<id>` |
| `currentManaPercent <= 10%` | `manaPctBelow=10` |
| `numberTargets >= 3` | `aoe=3` |
| `groupReference` | 展开为多条规则（保持顺序） |

不支持的条件（首版）：`spellTimeToReady` 比较、`spellCurrentCost` 比较、`spellIsKnown` 显式判断（引擎自动做）、`autocastOtherCooldowns`（用 burst 规则替代）。

## 6. 校验规则（CI 强制）

1. `id` 唯一，命名符合 `<spec>.<spell>.<variant>`。
2. `spell` 在同 profile 内去重；同一技能最多出现 3 次（不同条件）。
3. 主动技能（非填充）必须显式 `cd=true` 或由引擎自动加 `cd`（默认开启，见下）。
4. 每个 profile 至少 1 条无 guard 的填充规则（否则可能"无推荐"）。
5. 触发类条件必须用 `id`，禁止只用名称。
6. `aoe` 只出现在 AOE 规则；不得与单体填充混用。
7. 不允许 `manaPctAbove` 与 `manaPctBelow` 同时出现在一条规则。
8. 所有 `id` 必须能在数据字典或 `meta.source` 找到出处。

**默认 CD 校验**：引擎对 `rule.cd == nil and rule.spell` 的规则自动附加"冷却就绪"检查；填充技能通过 `filler=true` 显式豁免。

## 7. 兼容导入（LYF1 子集）

支持导入小六月的 `LYF1.` 字符串，映射到本规范：

| LYF1 字段 | 本项目 |
| --- | --- |
| `spell`, `id` | 同名 |
| `target` | `target` |
| `cd` | `cd` |
| `mana` | `manaPctAbove`（原语义为最小法力） |
| `aoe` | `aoe` |
| `buffMissing.*` | `buffMissing` |
| `debuffMissing.*` | `debuffMissing` |
| `refreshBelow.*` | `debuffBelow`（stacks 视为极大） |
| `notChanneling` | `notChanneling` |
| 其余字段 | 忽略并告警 |

导入结果只写入 `custom` profile，不覆盖内置三系；导入后必须通过 §6 校验。

## 8. 反模式

- **无 guard 的爆发技能**：会在任何时机开爆发。
- **用名称判定触发**：rank 变更即失效。
- **填充技能放在最前**：后面永远不命中。
- **用 `aoe` 修饰单体填充**：单目标时整条失效。
- **把"引导中"当成"没在施法"**：会推荐新读条，导致断引导。

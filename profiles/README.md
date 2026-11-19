# profiles

`profiles/mage/*.json` 是**评审用**的规则草案：字段与 [APL 规范](../docs/03-APL规范.md) 一致，便于 diff、review 与外部工具校验。

运行时使用 Lua 表（`profiles/mage/*.lua`，M1 提供），语义与 JSON 一一对应；CI 会校验二者一致。

约束：

- `schema` 版本不匹配 → 拒绝加载；
- 技能无法解析 → 载入告警，规则跳过；
- 触发类条件必须带 `id`；
- 每个 profile 至少一条 `filler=true` 的填充规则。

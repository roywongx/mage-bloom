# 贡献指南

## 可以贡献什么

- 规则修正（附数据/日志/来源）；
- 新专精 profile（先开 Issue 说明数据来源）；
- 测试 fixture（尤其是边界：触发叠满、引导中、空蓝、目标切换）；
- 文档纠错（机制、ID、阈值）。

## 规则变更流程

1. 开 Issue：`[profile] <spec> <技能> <问题>`；
2. 附证据：客户端构建号、实测日志/截图、WowSims/ForeverDB 链接；
3. 改 `profiles/<class>/<spec>.json`（评审用）与对应 Lua；
4. 更新 golden fixture；
5. 在 `CHANGELOG.md` 写清"改了什么、为什么、指标变化"；
6. PR 描述里贴 parity/木桩结果（有则更好）。

## 数据置信度

- `verified`：客户端实测或官方数据；
- `inferred`：多源一致但未实测；
- `todo`：待验证，不得进入默认 profile 的必选路径。

## 代码约定

- 引擎不出现具体技能名（`if spell == "寒冰箭"` 是反模式）；
- 热路径零分配；
- 所有外部调用 `pcall` 包裹，失败降级；
- 不引入新库，除非有 ADR。

## 评审

见 [docs/07-AI评审指南.md](docs/07-AI评审指南.md)。P0 问题阻塞合并。

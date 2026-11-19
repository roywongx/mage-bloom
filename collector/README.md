# 改版小六月（LiuyueForever + MageBloom）

完整的小六月 1.3.4 + `Core/MageBloom.lua`，对外仍是 `LiuyueForever`。
朋友不需要另装小六月；安装脚本会备份原版、移走旧探针，再装这一份。

## 内容

```
LiuyueForever/            完整改版插件（含 Core/MageBloom.lua）
1-安装插件.bat            自动找 _forever_，备份原版，移走旧探针，安装改版
2-打包数据.bat            找 SavedVariables\MageBloomDB.lua，打包到桌面
install.ps1 / pack.ps1
common.ps1
使用说明.txt
发给朋友.txt
```

## MageBloom 模块

- 复用 `LF.APL` / `LF.AuraState` / `LF.SpellBook` / `LF.SpellDurByName` / `LF.Talents` / `LF.Smart`
- 接管 MAGE 的 `EffectiveChain` / `PickIndex`（仅法师）
- 导出 `MageBloomDB`：法术书、持续期、天赋、APL、配置、自身光环
- 不注册 CLEU、不读敌方光环、不碰 secret value
- `/mb dump` 手动导出；`/reload` 落盘

# MageProbe 傻瓜收集包

给朋友用的只读数据收集器：安装插件 → 玩 10–15 分钟 → `/mp dump` → `/reload` → 打包回传。

## 包内容

```
1-安装插件.bat      自动找 _forever_，复制 MageProbe 到 Interface\AddOns
2-打包数据.bat      找 SavedVariables\MageProbe.lua，打包到桌面
install.ps1         安装逻辑（失败会自动请求管理员权限）
pack.ps1            打包逻辑
common.ps1          找游戏目录 / 找数据文件
MageProbe/          只读插件（TOC + Lua）
使用说明.txt        给朋友看的步骤
```

## 只读声明

插件只调用公开只读 API；不施法、不按键、不自动操作、不改设置。
收集内容写入 `WTF\Account\*\SavedVariables\MageProbe.lua`，由 `2-打包数据.bat` 打成 zip。

## 开发者

源码在仓库 `collector/`；`MageProbe.lua` 可直接用 `luaparse` 做 Lua 5.1 语法检查。

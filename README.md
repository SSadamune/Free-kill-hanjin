# 紫乔汉晋 · 新月杀扩展

本目录是扩展源码；开发用新月杀 v0.5.25 位于 `.dev/runtime/FreeKill-release`。
扩展标识为 `hanjin`，显示名为“紫乔汉晋”。

本扩展基于**国战模式**，涉及的规则、武将、翼从和卡牌均以目标国战模式为准，
不默认沿用身份局规则。项目开发约定见 `AGENTS.md`。

## 在 Cursor 中开发

用 Cursor 打开本目录。已检测到安装了 `sumneko.lua`；项目使用 Lua 5.4，
通过 `.luarc.json` 引用本地游戏源码进行 API 补全。
Cursor 兼容 `.vscode` 目录中的项目设置与任务。

在“终端 → 运行任务”中选择：

- **紫乔汉晋：检查 Lua 语法**：使用游戏自带 Lua DLL 检查语法（需要 Python 3）。
- **紫乔汉晋：同步扩展**：复制源码与资源到开发版的 `packages/hanjin`。
- **紫乔汉晋：启动开发版**：先同步，再启动独立游戏。
- **紫乔汉晋：安装国战依赖**：按锁定提交安装或核验 `utility` 和 `hegemony`。
- **紫乔汉晋：运行自动化测试**：运行国战基础测试及汉晋技能测试。

也可以在项目终端运行：

```powershell
python scripts/check_lua.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action play
```

修改后关闭开发版，再运行启动任务。同步为复制操作，源码仍以本目录为准；
删除或重命名文件后，需检查开发副本中的旧文件并手动清理。
不要直接修改开发副本中的 `packages/hanjin`，下次同步会覆盖同名文件。

## 自动化测试与 TDD

运行前关闭开发版游戏。以下命令会先核验依赖并同步本扩展，再通过发行版自带的
`FreeKill.exe --testfile` 运行真实游戏逻辑和官方 LuaUnit/FkTest 框架：

```powershell
python scripts/test.py
python scripts/test.py --file tests/hegemony.lua
```

Cursor 的“终端 → 运行任务 → 紫乔汉晋：运行自动化测试”提供相同入口。
默认测试为 `tests/hegemony.lua`，使用真正的 `new_heg_mode` 国战初始化、
规则技能、白名单和牌堆。测试辅助代码仅替代选将输入和无限回合循环，
保留国战角色分配、双将设置、体力计算、技能挂载、起始摸牌与游戏开始结算。
现有六项测试覆盖包的模式限制、暗将与起始手牌、国战将池与牌堆、明置与势力关系、
暗置再明置、移除副将变为士兵且不改变体力上限。
测试超时（默认 60 秒）、断言失败、进程异常、Lua 加载错误或未执行任何测试均返回非零退出码。

新增技能可直接在技能文件中写 `skill:addTest(function(room, me) ... end)`，
默认国战套件会收集 `hanjin_generals` 下这些回调并在国战测试房间中运行。
每个回调中的 `me` 默认是国战曹操/夏侯惇组合且双将暗置；测试汉晋技能时应明确
通过国战接口设置对应武将及位置、明暗状态，不能仅添加技能便声称覆盖了主副将规则。
测试中用
`FkTest.setNextReplies` 预设玩家回复，用 `FkTest.runInRoom` 执行结算，
用 `lu.assertEquals` 等断言结果。按“先写失败测试 → 实现 → 通过 → 重构”的顺序开发。
`--file` 外部测试的全局表命名和返回值写法见 `tests/hegemony.lua`；外部文件在
内置测试收集后加载，应直接定义 LuaUnit 测试表，不能仅在其中调用 `addTest`。
界面提示、动画与交互表现仍需在游戏内验证。

`python scripts/test.py --skills jianxiong` 和 `--file tests/smoke.lua` 保留为
测试工具本身的诊断入口，它们使用官方默认测试房间，不作为国战规则验收。

## 国战基础与依赖

基础包来源为 `https://gitee.com/qsgs-fans/hegemony.git`，模式代码名为
`new_heg_mode`，显示名为“国战模式”；公共函数依赖为
`https://gitee.com/qsgs-fans/utility.git`。
两个仓库独立安装在 `.dev/runtime/FreeKill-release/packages/`，不复制进汉晋发布包。
经本地 v0.5.25 加载和上述国战测试验证的提交固定在 `dependencies.lock.json`。

`hanjin_generals` 使用 `game_modes_whitelist` 限定国战，并通过上游公开的
`Fk:addWhiteListPack` 加入国战将池允许列表。当前无自定义武将，选将列表中还不会
出现汉晋武将。基础国战可直接游玩，尚未实现统领与翼从机制，也未新增独立汉晋模式。
以后规则实现优先复用 `packages.hegemony.util`（如 `removeGeneral`、势力比较及
武将移除事件），不在开发副本内改动上游代码。

首次安装和日常核验：

```powershell
python scripts/setup_dependencies.py
python scripts/setup_dependencies.py --check
```

安装脚本只克隆缺失的依赖并检出锁定提交；已有目录存在修改或版本不符时会停止，
不会覆盖。测试和启动开发版前都会检查依赖。启动游戏后在创建房间中选择“国战模式”。
当前验证为无界面的规则测试，尚未人工验收选将界面、联网及断线重连。

## 文件位置

- `init.lua`：扩展入口，加载子包。
- `pkg/hanjin_generals/init.lua`：武将子包；目前无武将，等待设计。
- `pkg/hanjin_generals/skills/`：每个技能独立一个 Lua 文件。
- `image/generals/`：武将立绘。
- `audio/skill/`、`audio/death/`：技能及阵亡语音。
- `.dev/`：本地运行环境与下载包，不纳入 Git。
- `dependencies.lock.json`：国战依赖仓库和固定提交。
- `tests/support/hegemony.lua`：可复用国战测试房间。

下一步确定首批武将：姓名、势力、体力/上限、技能原文、触发时机、次数限制、
目标和结算顺序。先实现一名武将并在本地房间验证，再扩展名单。

## 环境重建

从官方发布页下载 `FreeKill-v0.5.25.7z`，解压后确保存在
`.dev/runtime/FreeKill-release/FreeKill.exe`，然后运行：

```powershell
python scripts/setup_dependencies.py
python scripts/check_lua.py
python scripts/test.py
```

仅将本仓库源码作为扩展发布；游戏内安装目录须为 `packages/hanjin`。
尚未配置远程仓库和自动更新地址。

## 参考

- [新月杀拓展之书](https://fkbook-all-in-one.readthedocs.io/zh-cn/latest/for-creators/anhe/index.html)
- [官方发布页](https://github.com/Qsgs-Fans/FreeKill/releases/tag/v0.5.25)

教程部分章节标有过时或草稿提示。API 写法以当前开发版自带
`packages/standard/pkg` 和 `lua` 源码为准。

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
python scripts/test.py --file tests/hanjin_rules.lua
```

Cursor 的“终端 → 运行任务 → 紫乔汉晋：运行自动化测试”提供相同入口。
默认入口为 `tests/all.lua`，包括上游国战回归、势力禁选纯规则、独立汉晋模式和连续对局场景。
应变测试位于 `tests/adaptation.lua`，同样纳入默认套件。
汉晋场景使用真实房间初始化、请求传输与选将界面数据、规则事件和起始摸牌，
只替代无限自动回合循环以及原生房间的测试后端。
`tests/support/hanjin_content.lua` 在测试进程中独立创建六势力和野心家测试武将、
无效果测试牌；不会借用原版实体内容，也不会同步或发布这些测试对象。
上游回归套件仍使用原版参考内容，验证基础接口，不将其加入汉晋模式。
测试超时（默认 60 秒）、断言失败、进程异常、Lua 加载错误或未执行任何测试均返回非零退出码。

新增技能可直接在技能文件中写 `skill:addTest(function(room, me) ... end)`，
默认国战套件会收集 `hanjin_generals` 下这些回调并在国战测试房间中运行。
每个回调中的 `me` 默认是随机合法的独立测试武将组合且双将暗置；测试汉晋技能时应明确
通过国战接口设置对应武将及位置、明暗状态，不能仅添加技能便声称覆盖了主副将规则。
测试中用
`FkTest.setNextReplies` 预设玩家回复，用 `FkTest.runInRoom` 执行结算，
用 `lu.assertEquals` 等断言结果。按“先写失败测试 → 实现 → 通过 → 重构”的顺序开发。
`--file` 外部测试的全局表命名和返回值写法见 `tests/hanjin_rules.lua`；外部文件在
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

独立模式为 **紫乔汉晋国战**（`hanjin_heg_mode`），只允许 `hanjin_generals`、
`hanjin_cards` 等明确登记的独立汉晋内容，不直接加入上游武将和卡牌。
`hanjin_generals` 和 `hanjin_cards` 也仅允许在本模式使用。

当前已实现势力禁选规则框架：多于四势力时保留四势力、上一局胜利势力必禁且上局被禁势力必留、
双势力保留、可配置野心家数量（默认4），以及关联装备/锦囊牌堆策略。
规范及实现边界见 [势力禁选规则](rules/faction-ban.md)。
跨局数据使用原生房间 SessionData，随房间关闭销毁；不修改上游模式和引擎源码。

汉晋应变规则已接入：富甲、残躯、助战、空巢、孤军，多条目分别结算、强制非目标效果、
一令牌忽略一项条件，以及只由一个合法协助者支付的同时助战请求。
多条目条件时点暂按逐项重检；`pkg/hanjin_mode/rules/config.lua` 保留统一快照策略，供规则最终确认后切换。
规范和未来卡牌/武将接入 API 见 [应变规则](rules/adaptation.md)。
`execute_both` 是供独立卡牌实现读取的语义标记，尚未创建【逐近弃远】或相关武将、装备。

原版应变在官方 `gamemode` 扩展中，源码仅下载到 `.dev/reference/gamemode` 作核对，
不加入汉晋内容或运行依赖。需重建参考源码时运行：

```powershell
python scripts/setup_dependencies.py --references
```

正式武将和卡牌包目前为空，尚未实现统领与翼从。模式可见，但内容不足时禁止创建汉晋对局，
不会自动借原版内容补齐。赤霄剑、临筱玉舆等目前只登记禁选/替换策略，
未编造装备技能、花色和点数；临筱玉舆的双坐骑副类别需在后续卡牌实装时显式处理。

首次安装和日常核验：

```powershell
python scripts/setup_dependencies.py
python scripts/setup_dependencies.py --check
```

安装脚本只克隆缺失的依赖并检出锁定提交；已有目录存在修改或版本不符时会停止，
不会覆盖。测试和启动开发版前都会检查依赖。正式内容补齐后可在创建房间中选择“紫乔汉晋国战”。
上游“国战模式”仍独立保留，供参考和回归。
当前验证为无界面的规则测试，尚未人工验收选将界面、联网及断线重连。

## 文件位置

- `init.lua`：扩展入口，加载子包。
- `pkg/hanjin_generals/init.lua`：武将子包；目前无武将，等待设计。
- `pkg/hanjin_generals/skills/`：每个技能独立一个 Lua 文件。
- `pkg/hanjin_cards/`：独立卡牌包，目前为空。
- `pkg/hanjin_mode/`：汉晋模式和公共规则模块。
- `rules/faction-ban.md`：供 agent 使用的已确认规则规范。
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

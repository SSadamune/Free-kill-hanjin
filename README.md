# 紫乔汉晋 · 新月杀扩展

本目录是扩展源码；开发用新月杀 v0.5.25 位于 `.dev/runtime/FreeKill-release`。
扩展标识为 `hanjin`，显示名为“紫乔汉晋”。

## 在 Cursor 中开发

用 Cursor 打开本目录。已检测到安装了 `sumneko.lua`；项目使用 Lua 5.4，
通过 `.luarc.json` 引用本地游戏源码进行 API 补全。
Cursor 兼容 `.vscode` 目录中的项目设置与任务。

在“终端 → 运行任务”中选择：

- **紫乔汉晋：检查 Lua 语法**：使用游戏自带 Lua DLL 检查语法（需要 Python 3）。
- **紫乔汉晋：同步扩展**：复制源码与资源到开发版的 `packages/hanjin`。
- **紫乔汉晋：启动开发版**：先同步，再启动独立游戏。

也可以在项目终端运行：

```powershell
python scripts/check_lua.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action play
```

修改后关闭开发版，再运行启动任务。同步为复制操作，源码仍以本目录为准；
删除或重命名文件后，需检查开发副本中的旧文件并手动清理。
不要直接修改开发副本中的 `packages/hanjin`，下次同步会覆盖同名文件。

## 自动化测试与 TDD

运行前关闭开发版游戏。以下命令会先同步本扩展，再通过发行版自带的
`FreeKill.exe --testfile` 运行真实游戏逻辑和官方 LuaUnit/FkTest 框架：

```powershell
python scripts/test.py
python scripts/test.py --skills jianxiong
python scripts/test.py --file tests/smoke.lua
```

Cursor 的“终端 → 运行任务 → 紫乔汉晋：运行自动化测试”提供相同入口。
默认测试包含扩展加载、翻译注册，以及“奸雄”受伤后获得伤害牌的结算回归；
当前尚无自定义武将，因此技能结算暂用官方技能验证。
测试超时（默认 60 秒）、断言失败、进程异常或未执行任何测试均返回非零退出码。

新增技能可直接在技能文件中写 `skill:addTest(function(room, me) ... end)`，
然后用 `python scripts/test.py --skills 技能名` 运行。测试中用
`FkTest.setNextReplies` 预设玩家回复，用 `FkTest.runInRoom` 执行结算，
用 `lu.assertEquals` 等断言结果。按“先写失败测试 → 实现 → 通过 → 重构”的顺序开发。
`--file` 外部测试的全局表命名和返回值写法见 `tests/smoke.lua`；外部文件在
内置测试收集后加载，应直接定义 LuaUnit 测试表，不能仅在其中调用 `addTest`。
界面提示、动画与交互表现仍需在游戏内验证。

## 文件位置

- `init.lua`：扩展入口，加载子包。
- `pkg/hanjin_generals/init.lua`：武将子包；目前无武将，等待设计。
- `pkg/hanjin_generals/skills/`：每个技能独立一个 Lua 文件。
- `image/generals/`：武将立绘。
- `audio/skill/`、`audio/death/`：技能及阵亡语音。
- `.dev/`：本地运行环境与下载包，不纳入 Git。

下一步确定首批武将：姓名、势力、体力/上限、技能原文、触发时机、次数限制、
目标和结算顺序。先实现一名武将并在本地房间验证，再扩展名单。

## 环境重建

从官方发布页下载 `FreeKill-v0.5.25.7z`，解压后确保存在
`.dev/runtime/FreeKill-release/FreeKill.exe`，运行同步任务即可。
仅将本仓库源码作为扩展发布；游戏内安装目录须为 `packages/hanjin`。
尚未配置远程仓库和自动更新地址。

## 参考

- [新月杀拓展之书](https://fkbook-all-in-one.readthedocs.io/zh-cn/latest/for-creators/anhe/index.html)
- [官方发布页](https://github.com/Qsgs-Fans/FreeKill/releases/tag/v0.5.25)

教程部分章节标有过时或草稿提示。API 写法以当前开发版自带
`packages/standard/pkg` 和 `lua` 源码为准。

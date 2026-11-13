# 紫乔汉晋 · 新月杀国战

紫乔汉晋是新月杀的自定义国战模式，包含魏、蜀、吴、群、汉、晋六势力，以及统领、翼从、应变等规则。

项目仍在开发中。已登记 90 张武将和 14 种翼从；汉、魏势力标准包各 15 将 25 个技能、关联翼从穆顺、西园军、并州狼骑、虎卫军、牛金，以及司马炎的垂统、兴图和晋司马懿的应期已实现并通过自动化回归。其他武将与翼从的专属技能主要仍为名称与说明；大部分卡牌已复用或适配新月杀实装，部分特殊装备和势力锦囊仍待实现。项目方向见[愿景说明](docs/vision.md)，规则集底稿见 [`rulebook/`](rulebook/README.md)，设计裁定见[项目规范](rules/README.md)，具体实装与验证范围见[开发状态](docs/development/status.md)、[汉势力实现总览](docs/development/implementation/generals/han-standard.md)和[魏势力实现总览](docs/development/implementation/generals/wei-standard.md)。

## 准备开发环境

以下流程适用于 Windows，所有命令均在本项目根文件夹的终端中运行。

### 1. 获取项目并安装工具

安装 Git、Python 3 和解压工具，确保终端可以运行 `git`、`python`。克隆本项目后，用 VS Code、Cursor 或其他编辑器打开项目文件夹。

```powershell
git clone https://github.com/SSadamune/Free-kill-hanjin.git
cd Free-kill-hanjin
```

VS Code 和 Cursor 可安装 Lua 扩展（`sumneko.lua`），用于语法提示和 API 补全。项目已提供 Lua 5.4 配置及编辑器任务。

### 2. 安装新月杀本体

从 [新月杀 v0.5.25 官方发布页](https://github.com/Qsgs-Fans/FreeKill/releases/tag/v0.5.25) 下载 Windows 发行包 `FreeKill-v0.5.25.7z`，解压到项目内，确保游戏程序位于：

```text
.dev/runtime/FreeKill-release/FreeKill.exe
```

发行包自带开发所需的 `lua/`、`ltk/` 和基础卡牌代码，编辑器会从中读取 API。需要查阅引擎源码时，可访问 [FreeKill 源码仓库](https://github.com/Qsgs-Fans/FreeKill/tree/v0.5.25)。

### 3. 安装国战依赖

运行安装脚本，自动下载国战扩展及公共函数库，并切换到项目验证过的版本：

```powershell
python scripts/setup_dependencies.py
```

| 依赖 | 来源 | 安装位置 |
| --- | --- | --- |
| 国战扩展 | [hegemony](https://gitee.com/qsgs-fans/hegemony) | `.dev/runtime/FreeKill-release/packages/hegemony/` |
| 公共函数库 | [utility](https://gitee.com/qsgs-fans/utility) | `.dev/runtime/FreeKill-release/packages/utility/` |

版本记录在 `dependencies.lock.json`。已有依赖如存在本地修改或版本不符，脚本会提示并停止，需按提示处理后重试。

### 4. 启动游戏

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action play
```

脚本会核验依赖，将本项目的游戏内容复制到 `packages/hanjin/`，然后启动新月杀。创建房间时选择“紫乔汉晋国战”。

### 测试用自由选将

在房间的公共游戏规则设置中开启“自由选将”。进入汉晋选将界面后，右键或长按候选武将，打开武将替换窗口。开启时可选择候选列表外、被禁势力的武将，也可使用不同势力组合或野心家副将；仍须选择两张不同的有效武将牌。

正常合法组合保留原有初始势力选项（含客将势力）；规则外组合改用两将原有势力的交集，无交集时从并集中选择，均无常规势力时使用本局首个允许势力兜底。该功能用于测试，不改变正式随机将池或牌堆；关闭后恢复正常选将限制。

### 刘协技能交互

密诏的收牌角色始终为单选：点击另一名合法角色会自动替换原选择，并保留已选的交牌；再次点击已选角色可取消选择。该交互随扩展安装包发布，无需修改本体。

### 鏖战杀／闪转换

鏖战中，实体【桃】只能当【杀】或【闪】使用或打出。转换选项随当前询问变化：被【杀】询问使用【闪】时只显示并默认选中【闪】；普通出牌阶段只提供【杀】；要求打出牌时也只提供符合该询问的用途。实体牌的原牌名仍为【桃】。该交互随扩展安装包发布。

### 仅开发环境生效的本体适配

运行开发同步、启动或测试脚本时，会修改 `.dev/runtime/FreeKill-release/` 内的本地游戏文件，启用以下适配：

- 单人启动服务器时，操作时间默认“无限”，可手动改为有限秒数，并免除操作超时踢出惩罚。
- 补齐 Windows 客户端 Lua 模块加载路径。

计时适配由 `scripts/prepare_runtime.py` 安装，会影响该开发版中的其他游戏模式。改动在关闭游戏后仍保留，重新解压官方本体可恢复。

**上述适配仅供本地开发使用，用户安装紫乔汉晋扩展后仍使用其新月杀本体原有的操作时间和超时惩罚机制。**

## 构建用户安装包

```powershell
python scripts/build_release.py
```

生成 `.dev/dist/hanjin.zip`，解压到用户游戏的 `packages/` 后得到 `packages/hanjin/`。

构建脚本从项目中的 `init.lua`、`pkg/`、`image/`、`audio/` 打包，排除开发脚本、测试、原素材和 `.dev/` 环境，确保本体适配与用户安装包隔离。

## 日常开发与测试

修改文件后，关闭开发版游戏，再运行启动命令，使改动同步到游戏。请在本项目中修改文件，开发版 `packages/hanjin/` 中的副本会在同步时被覆盖。删除或重命名文件后，还需清理开发副本中的旧文件。

检查 Lua 语法、运行全部自动化测试：

```powershell
python scripts/check_lua.py
python scripts/test.py
```

测试前关闭开发版游戏。默认测试包含国战回归、汉晋公共规则、选将与开局场景。单独运行某个测试文件可使用：

```powershell
python scripts/test.py --file tests/adaptation.lua
```

VS Code 和 Cursor 均可通过“终端 → 运行任务”执行启动、同步、语法检查和自动化测试。界面、联网和断线重连表现仍需在游戏客户端人工验证。

开发前请阅读[项目约定](AGENTS.md)与[开发指南](docs/development/README.md)。

新增武将或卡牌时，先确认规则与引擎接口，再打通正常流程，尽早检查真实客户端选择与提示，随后补核心回归并运行默认全量。夹具、间歇失败诊断及简短故障记录的要求见[测试规范](docs/development/testing.md)。面向玩家的交互应随正式安装包发布；创建或更新 PR 时按[项目模板](.github/pull_request_template.md)填写，并同步对应规则文档的状态。

## 文件结构

```text
Free-kill-hanjin/
├─ init.lua                 游戏内容加载入口
├─ pkg/
│  ├─ hanjin_mode/          国战模式、公共规则与界面
│  ├─ hanjin_generals/      武将、翼从资料与技能
│  └─ hanjin_cards/         牌表、卡牌与技能
├─ image/                   游戏使用的图片
├─ audio/                   技能与阵亡语音
├─ assets-source/           用户提供的原始素材
├─ rules/                   项目设计、机制约定与逐将裁定
├─ rulebook/                汉晋规则集工作底稿与后续正式改编
├─ docs/                    项目愿景、外部规则来源与开发资料
├─ tests/                   自动化测试
├─ scripts/                 环境安装、同步与测试脚本
├─ .dev/                    本地游戏与依赖，不纳入 Git
├─ .vscode/                 VS Code、Cursor 共用任务
├─ .luarc.json              Lua 补全与检查配置
├─ dependencies.lock.json   依赖版本记录
└─ AGENTS.md                项目开发约定
```

## 开发参考

- [新月杀拓展之书](https://fkbook-all-in-one.readthedocs.io/zh-cn/latest/for-creators/anhe/index.html)

教程部分章节可能过时，API 用法请结合当前游戏自带代码核对。

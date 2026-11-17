# 新月杀·国战的平行时空

基于新月杀的《国战的平行时空》扩展。《国战的平行时空》是由紫乔主持设计的DIY应变国战模式，加入了汉、晋两个新势力，以及兵种、客将势力等新机制。
设计专栏参见：[https://www.bilibili.com/read/readlist/rl931960](https://www.bilibili.com/read/readlist/rl931960)

君临天下·不臣篇、君临天下·兵情篇、纵横捭阖已作为空分包预留，暂未登记武将或卡牌。

项目仍在开发中。六势力标准包共 90 张武将及 14 种翼从已有正式技能实现；阵、势包另接入 24 张普通武将、两张君主及三种新翼从，君主经升变／继位取得。阵、势包26张武将的默认插画已接入，真实客户端逐图显示尚待人工验收。各批自动化验证范围见开发状态。晋司马懿的应期与魏司马懿共用技能，泰然后续时机尚未定案，暂按回合结束时逐次结算。大部分卡牌已复用或适配新月杀实装，部分特殊装备和势力锦囊仍待实现。客户端交互、多人联网／重连及干净本体安装的完整人工验收尚未完成。

- [项目愿景](docs/vision.md)与[文档入口](docs/README.md)
- [规则集工作底稿](rulebook/README.md)与[项目设计、裁定](rules/README.md)
- [开发状态与待办](docs/development/status.md)及[实现导航](docs/development/implementation/README.md)

标准包逐将入口：[汉](docs/development/implementation/generals/han-standard.md) · [魏](docs/development/implementation/generals/wei-standard.md) · [蜀](docs/development/implementation/generals/shu-standard.md) · [吴](docs/development/implementation/generals/wu-standard.md) · [群](docs/development/implementation/generals/qun-standard.md) · [晋](docs/development/implementation/generals/jin001-simayan.md)。另见[阵、势包实现与验证](docs/development/implementation/generals/zhen-shi-review.md)。具体技能与验证范围以对应文档为准。

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

脚本会核验依赖，将本项目的游戏内容复制到 `packages/qiao/`，然后启动新月杀。创建房间时选择“大合集”。

### 测试用自由选将

在房间的公共游戏规则设置中开启“自由选将”，然后右键或长按候选武将打开替换窗口。该测试功能允许候选外武将和规则外配对，仍须选择两张不同的有效武将牌；关闭后恢复正常选将限制。初始势力的处理见[自由选将例外](rules/faction-ban.md#测试用自由选将例外)。

### 仅开发环境生效的本体适配

运行开发同步、启动或测试脚本时，会修改 `.dev/runtime/FreeKill-release/` 内的本地游戏文件，启用以下适配：

- 单人启动服务器时，操作时间默认“无限”，可手动改为有限秒数，并免除操作超时踢出惩罚。
- 补齐 Windows 客户端 Lua 模块加载路径。

计时适配由 `scripts/prepare_runtime.py` 安装，会影响该开发版中的其他游戏模式。改动在关闭游戏后仍保留，重新解压官方本体可恢复。

**上述适配仅供本地开发使用，用户安装平行时空扩展后仍使用其新月杀本体原有的操作时间和超时惩罚机制。**

## 构建用户安装包

```powershell
python scripts/build_release.py
```

生成 `.dev/dist/qiao.zip`，解压到用户游戏的 `packages/` 后得到 `packages/qiao/`。

从旧版升级时，先移除旧扩展目录 `packages/hanjin/`，再安装 `packages/qiao/`，避免同时加载两份扩展。

构建脚本从项目中的 `init.lua`、`pkg/`、`image/`、`audio/` 打包，排除开发脚本、测试、原素材和 `.dev/` 环境，确保本体适配与用户安装包隔离。

默认武将及卡牌图片按引擎固定目录和程序 ID 保存，例如 `image/generals/qiao_heg__han001.jpg`；构建与开发同步按原相对路径复制，不做图片改名。客将附加插画的保存与读取约定见[图片资源保存规范](docs/development/assets.md)。

正式武将程序 ID 使用 `qiao_heg__` 前缀，其中 `heg__` 片段命中锁定新月杀 v0.5.25 的国战体力显示；技能、卡牌、标记、包名和模式 ID 均使用 qiao 命名空间（技能、卡牌为 `qiao__`），qiao 命名空间本身不参与该显示识别。这是本项目为兼容该引擎版本采用的约定，并非上游正式命名规范。旧收藏、禁将配置、录像及按旧武将 ID／旧包名／旧模式名保存的外部数据不会自动迁移。

## 日常开发与测试

修改文件后，关闭开发版游戏，再运行启动命令，使改动同步到游戏。请在本项目中修改文件；同步按相对路径覆盖开发版 `packages/qiao/` 中的对应文件，不要在该副本内保存唯一原稿。删除或重命名源文件后，仍需核对并清理开发副本中的旧文件。

检查 Lua 语法、运行全部自动化测试：

```powershell
python scripts/check_lua.py
python scripts/test.py
```

测试前关闭开发版游戏。默认测试包含国战回归、汉晋公共规则、选将与开局场景，以及已实装武将和翼从的专项回归。单独运行某个测试文件可使用：

```powershell
python scripts/test.py --file tests/adaptation.lua
```

测试入口会对共享运行时加进程间锁，占用时立即报告，不与另一轮测试同时同步或执行。新套件模板、公共夹具、请求辅助和串行调度要求见[测试规范](docs/development/testing.md)。这些工具仅供开发，不进入用户安装包。

VS Code 和 Cursor 均可通过“终端 → 运行任务”执行启动、同步、语法检查和自动化测试。界面、联网和断线重连表现仍需在游戏客户端人工验证。

开发前请阅读[项目约定](AGENTS.md)与[开发指南](docs/development/README.md)。内容开发流程、文档职责和提交要求由这些文档统一维护；创建或更新 PR 使用[项目模板](.github/pull_request_template.md)。

### 使用 AI agent 开发内容

武将、卡牌及规则交互开发使用项目 [hanjin-content-development skill](.agents/skills/hanjin-content-development/SKILL.md)。给出动作和范围即可，例如：

```text
按照 hanjin-content-development 审阅群势力标准包
```

规则确认后开始实装：

```text
根据已确认规则实装群势力标准包
```

将示例范围替换为本轮目标。默认由当前 agent 执行，委派遵循明确指定或已有协作配置；提交、推送及 PR 操作需有用户授权。不支持 skill 加载的工具可直接读取上述 `SKILL.md`。资料查找、裁定和协作要求见[新会话入口](docs/development/README.md#新会话入口)。

图片、音效及素材配置使用项目 [hanjin-asset-development skill](.agents/skills/hanjin-asset-development/SKILL.md)。给出动作、范围和已提供的素材即可，例如：

```text
按照 hanjin-asset-development 替换刘协默认插画，素材在 assets-source/
```

```text
按照 hanjin-asset-development 接入技能语音，素材已放在 assets-source/，目标技能见本轮说明
```

缺少原材料时先说明需求并索取；从零生图或绘制素材须用户明确批准；新音效依用户目标与现有接口处理，缺少影响成品的关键需求再澄清。素材技术规范见[图片与音效资源保存规范](docs/development/assets.md)，实际素材、接线与验证结果分别落在 `image/`、`audio/`、`pkg/` 和 `docs/development/`。默认由当前 agent 执行，不自动提交。

## 文件结构

```text
Free-kill-hanjin/
├─ init.lua                 游戏内容加载入口
├─ pkg/
│  ├─ qiao_mode/          国战模式、公共规则与界面
│  ├─ qiao_generals/      武将、翼从资料与技能
│  └─ qiao_cards/         牌表、卡牌与技能
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

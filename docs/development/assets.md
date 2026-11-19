# 图片资源保存规范

本页依据项目锁定的新月杀 v0.5.25 源码规定图片与音效资源的保存、命名和发布方式，是开发规范。升级引擎后须重新核对相关入口。

## 默认图片

默认图片按实际程序 ID 放在引擎固定目录，构建与开发同步保持源码相对路径，不做图片改名或额外路径映射。

| 用途 | 路径示例 |
| --- | --- |
| 武将插画 | `image/generals/qiao_heg__han001.jpg` |
| 翼从插画 | `image/generals/qiao_heg__retinue_niujin.jpg` |
| 卡牌正面 | `image/card/qiao__slash.png` |
| 装备图标 | `image/card/equipIcon/qiao__axe.png` |
| 延时锦囊图标 | `image/card/delayedTrick/qiao__indulgence.png` |

依据是 `Fk/Base/SkinBank.qml` 的 `getGeneralPicture`、`getCardPicture`、`getEquipIcon` 和 `getDelayedTrickPicture`。这些入口按固定目录与程序 ID 查找文件，不递归搜索分包目录。正式武将使用 `qiao_heg__` 前缀，其中 `heg__` 片段用于命中引擎的国战体力显示；技能、卡牌、标记、包名和模式 ID 均使用 qiao 命名空间（技能、卡牌为 `qiao__`），qiao 命名空间本身不参与该识别，不得混用。

## 独立武将版本

普通版、君主版和野心家版按项目设计分别注册为独立武将，各自拥有程序 ID、技能与默认插画。每个版本的图片均保存为 `image/generals/<该版本的程序ID>.jpg`。设计编号中的 `em`、`am` 沿用汉晋既有含义；实际图片文件名取已注册的完整程序 ID，不仅凭设计编号推测或创建武将版本。

分包和多势力属于正式内容数据，默认图片目录不重复表达这些分类。不得仅为图片命名或换图修改武将 ID。

## 客将默认插画

客将是某张武将牌在本局的替换结果。普通与客将默认插画使用相同的程序 ID 文件名，通过目录区分：

```text
image/generals/qiao_heg__han001.jpg
image/generals/guest/qiao_heg__han001.jpg
```

所有客将插画统一放入 `image/generals/guest/`，格式为 `<程序ID>.jpg`。不另加 `_guest`、插画序号或分包层级，不创建新武将 ID，不维护逐将图片路径清单。

引擎 `Fk/Base/SkinBank.qml:getGeneralExtraPic(name, extra)` 已支持在指定附加目录按程序 ID 读取 `.jpg`。例如：

```javascript
SkinBank.getGeneralExtraPic("qiao_heg__han001", "guest/")
```

会查找 `packages/qiao/image/generals/guest/qiao_heg__han001.jpg`。调用中目录参数为 `guest/`，保留末尾斜杠。

通用显示入口根据本局该武将的客将替换结果选择：实际发生替换且附加图存在时使用客将图，否则使用原有默认插画流程。无需逐将登记图片；新增客将插画只需按实际程序 ID 放置文件。引擎读取入口不会自行判断客将状态，选将和局内显示仍需统一接入。

客将插画已随扩展用于选将、局内头像和武将一览。显示行为见[客将默认插画](guest-illustrations.md)，验证范围见[开发状态](status.md#图片资源保存)。

## 音效资源

音效源码放在项目根 `audio/`，构建和开发同步按相对路径复制到 `packages/qiao/audio/`。本页记录引擎接口约定，不代表已有音频或完成播放验收；资源与构建现状见[开发状态](status.md)。

锁定引擎的查找入口如下（`Fk/Base/SkinBank.qml` 与 `ltk/server/`）：

| 用途 | 包内目录 | 命名 |
| --- | --- | --- |
| 技能语音 | `audio/skill/` | `<技能骨架名>_<武将程序ID>.mp3` 或 `<技能骨架名>_<武将程序ID>1.mp3`；通用回退 `<技能骨架名>.mp3` 或 `<技能骨架名>1.mp3` |
| 阵亡语音 | `audio/death/` | `<武将程序ID>.mp3` |
| 胜利语音 | `audio/win/` | `<武将程序ID>.mp3` |
| 卡牌语音 | `audio/card/male/`、`audio/card/female/` | `<牌名>.mp3`；装备通用音由引擎根目录 `audio/card/common/weapon|armor|horse` 提供 |

技能发动时 `ltk/server/events/skill.lua` 调用 `player:broadcastSkillInvoke(skeleton.name, audio_index)`；客户端先试武将专属名，再试技能通用名，`SkinBank.getAudio` 对每个名称依次检查无编号 `.mp3` 与 `1.mp3`，查找阶段不要求无编号文件存在。`audio_index = 0` 不播放，未设置时按 -1（随机）处理。

详情页 `GeneralDetailPage.qml` 从 i=0 开始枚举：i=0 缺失时不终止，继续查 1；i≥1 遇到首个缺失才停止。更高编号如何拼入实际播放路径由 `Backend.playSound(path, idx)` 交给原生端；当前源码检出未含 C++ 层，未核对编号后缀与跳号行为。

非装备卡牌的使用语音由 `ltk/server/events/usecard.lua` 按 `packages/<扩展名>/audio/card/<male|female>/<牌名>.mp3` 查找；装备通用音使用引擎 `./audio/card/common/`。特殊牌技能可以直接调用 `room:broadcastPlaySound("./packages/qiao/audio/card/<名称>")`，客户端 `SkinBank.getAudioByPath` 会补 `.mp3` 再播放；项目 `pkg/qiao_cards/skills/halberd.lua` 目前复用 `standard_cards` 的方天画戟音效。

新增语音前先确认技能骨架名、武将程序 ID 和真实触发入口，不要照搬或猜测文件名。音效格式、码率、音量、裁剪和编号数量按用户素材与目标要求处理，项目未规定通用参数。找不到对应引擎接口或原生实现时，明确记录未核对边界。

## 资料来源与维护

正式武将列表、编号、版本与分包由本项目维护的数据和已确认设计决定，当前标准包见 `pkg/qiao_generals/data/standard.lua` 与[标准武将资料](../rules/standard-generals.md)。外部参考的 `heroes.json`（本仓库未收录）不是正式编号、分包或构建的规范来源。

新增图片或音效先确认实际程序 ID、用途和引擎入口；缺少素材时索取原材料，不自行生成或复制占位。图片格式应符合对应入口，不能直接改扩展名冒充格式转换；迁移原稿时保持文件字节不变，按目标要求转换时另行记录来源与参数，并核对安装包路径。

构建使用 `python scripts/build_release.py`，开发同步使用 `scripts/dev.ps1`，均按原相对路径复制。同步只覆盖对应文件，删除或改名后须核对开发副本旧文件；原稿只在源码中维护。

资源调整按风险核对路径和字节；新增状态换图时另验客户端及运行时行为。静态路径检查不代替实际显示验收，最新结果见[开发状态](status.md)。`python scripts/verify_image_assets.py` 的默认模式只针对当前图片批次，数量、规格与 90／51／14 路径覆盖不代表未来素材的通用验收标准；`--release` 按当前发布集合核对 ZIP 路径与逐文件字节，可用于包含图片、音效的安装包，但不做音频解码或播放。

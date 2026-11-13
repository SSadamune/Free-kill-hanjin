# 图片资源保存规范

本页依据项目锁定的新月杀 v0.5.25 源码规定资源保存方式，是开发规范。升级引擎后须重新核对相关入口。

## 默认图片

默认图片按实际程序 ID 放在引擎固定目录，构建与开发同步保持源码相对路径，不做图片改名或额外路径映射。

| 用途 | 路径示例 |
| --- | --- |
| 武将插画 | `image/generals/hanjin__han001.jpg` |
| 翼从插画 | `image/generals/hanjin__retinue_niujin.jpg` |
| 卡牌正面 | `image/card/hanjin__slash.png` |
| 装备图标 | `image/card/equipIcon/hanjin__axe.png` |
| 延时锦囊图标 | `image/card/delayedTrick/hanjin__indulgence.png` |

依据是 `Fk/Base/SkinBank.qml` 的 `getGeneralPicture`、`getCardPicture`、`getEquipIcon` 和 `getDelayedTrickPicture`。这些入口按固定目录与程序 ID 查找文件，不递归搜索分包目录。`hanjin__` 是当前程序 ID 的一部分，应予保留。

## 独立武将版本

普通版、君主版和野心家版按项目设计分别注册为独立武将，各自拥有程序 ID、技能与默认插画。每个版本的图片均保存为 `image/generals/<该版本的程序ID>.jpg`。设计编号中的 `em`、`am` 沿用汉晋既有含义；实际图片文件名取已注册的完整程序 ID，不仅凭设计编号推测或创建武将版本。

分包和多势力属于正式内容数据，默认图片目录不重复表达这些分类。不得仅为图片命名或换图修改武将 ID。

## 客将默认插画

客将是某张武将牌在本局的替换结果。普通与客将默认插画使用相同的程序 ID 文件名，通过目录区分：

```text
image/generals/hanjin__han001.jpg
image/generals/guest/hanjin__han001.jpg
```

所有客将插画统一放入 `image/generals/guest/`，格式为 `<程序ID>.jpg`。不另加 `_guest`、插画序号或分包层级，不创建新武将 ID，不维护逐将图片路径清单。

引擎 `Fk/Base/SkinBank.qml:getGeneralExtraPic(name, extra)` 已支持在指定附加目录按程序 ID 读取 `.jpg`。例如：

```javascript
SkinBank.getGeneralExtraPic("hanjin__han001", "guest/")
```

会查找 `packages/hanjin/image/generals/guest/hanjin__han001.jpg`。调用中目录参数为 `guest/`，保留末尾斜杠。

通用显示入口根据本局该武将的客将替换结果选择：实际发生替换且附加图存在时使用客将图，否则使用原有默认插画流程。无需逐将登记图片；新增客将插画只需按实际程序 ID 放置文件。引擎读取入口不会自行判断客将状态，选将和局内显示仍需统一接入。

此保存方式已通过锁定源码核对；当前尚未新增客将插画或实装通用显示逻辑，客户端显示验收待完成。接入要求见[客将默认插画功能设计](guest-illustrations.md)。

## 资料来源与维护

正式武将列表、编号、版本与分包由本项目维护的数据和已确认设计决定，当前标准包见 `pkg/hanjin_generals/data/standard.lua` 与[标准武将资料](../../rules/standard-generals.md)。`docs/heroes.json` 只是外部参考，不是正式编号、分包或构建的规范来源。

新增图片先确认实际程序 ID、用途和引擎入口；缺少素材时索取原材料，不自行生成或复制占位。图片格式应符合对应入口，不能直接改扩展名冒充格式转换；迁移时保持文件字节不变并核对安装包路径。

构建使用 `python scripts/build_release.py`，开发同步使用 `scripts/dev.ps1`，均按原相对路径复制。同步只覆盖对应文件，删除或改名后须核对开发副本旧文件；原稿只在源码中维护。

资源调整按风险核对路径和字节；新增状态换图时另验客户端及运行时行为。静态路径检查不代替实际显示验收，最新结果见[开发状态](status.md)。

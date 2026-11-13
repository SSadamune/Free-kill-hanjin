# 图片资源保存规范

本页依据项目锁定的新月杀 v0.5.25 源码规定资源保存方式。它是开发规范，不定义游戏结算规则；升级引擎后须重新核对接口。

## 默认图片

默认图片按实际程序 ID 放在引擎固定目录，不做构建改名或路径映射，不递归分包目录。

| 用途 | 路径示例 |
| --- | --- |
| 武将插画 | `image/generals/hanjin__han001.jpg` |
| 翼从插画 | `image/generals/hanjin__retinue_niujin.jpg` |
| 卡牌正面 | `image/card/hanjin__slash.png` |
| 装备图标 | `image/card/equipIcon/hanjin__axe.png` |
| 延时锦囊图标 | `image/card/delayedTrick/hanjin__indulgence.png` |

依据是 `Fk/Base/SkinBank.qml` 的 `getGeneralPicture`、`getCardPicture`、`getEquipIcon` 和 `getDelayedTrickPicture`。`hanjin__` 是当前程序 ID 的一部分，应予保留。独立武将版本使用各自实际注册的 ID；不为换图修改 ID。

## 额外静态皮肤

额外皮肤采用以下命名，文件名不加 `hanjin__`：

```text
image/skins/<分包>/<资源键>[_guest]_vNN.<格式>
```

- **分包**：项目正式登记的稳定英文目录名；当前标准包为 `standard`，翼从资源为 `retinue`。同包不同外观放在一起，不另建客将、君主或野心家子目录。
- **资源键**：由公共函数按项目确认的设计编号统一转换：小写、势力与数字之间加下划线，保留前导零、末尾字母和多势力原顺序；版本标记固定放在末尾，君主用 `_em`，野心家用 `_am`，兼有时用 `_em_am`。正常编号不额外手填资源键；仅无法按约定转换的特殊情况集中登记例外，无正式编号的翼从使用项目登记的稳定资源名。
- **客将标记**：客将外观加 `_guest`，普通外观省略。当前不按加入的势力细分外观。
- **插画槽位**：所有额外皮肤都带 `_vNN`，至少两位。`_guest_v01` 固定为默认客将皮肤，其他序号用于备选插画。这是稳定标识，不是文件修订版本；更新同一套插画可替换原文件，新增另一套插画才增加序号。删除后不重编号，普通与客将配套图使用相同序号，不强制配齐。
- **格式**：扩展名与真实文件格式一致，命名调整不重新编码。一个分包内同一资源键、客将状态和槽位只能对应一个文件，不能同时存在同名 `.jpg` 与 `.png`。

| 项目确认的编号／用途 | 文件名示例 |
| --- | --- |
| HAN001 普通额外插画 | `han_001_v01.jpg` |
| HAN001 默认客将皮肤 | `han_001_guest_v01.jpg` |
| HAN001 另一套客将皮肤 | `han_001_guest_v02.jpg` |
| EM(HAN001) 默认客将皮肤 | `han_001_em_guest_v01.jpg` |
| HAN016A | `han_016a_v01.jpg` |
| WEI&SHU&JIN028 | `wei_shu_jin_028_v01.jpg` |
| AM(WEI&SHU&JIN028) | `wei_shu_jin_028_am_v01.jpg` |
| EM&AM(WEI002/JIN009) | `wei_002__jin_009_em_am_v01.jpg` |
| QUN044&045 | `qun_044_045_v01.jpg` |
| 牛金翼从 | `niujin_v01.jpg`，放入 `image/skins/retinue/` |

两个完整编号以双下划线分隔，同一势力的多个数字以单下划线分隔。表格只示范转换，不代表这些版本已实装、已有图片或已确定所属分包。

## 引擎注册与路径兼容

此目录与命名方式符合锁定引擎的静态皮肤接口：

- `ltk/core/package.lua` 的 `Package:addSkinPackage` 接受皮肤目录 `path`、武将 ID 列表 `enabled_generals` 和完整文件名列表 `skins`；`path` 默认 `/image/skins`，允许指定分包子目录。
- 静态皮肤的文件名包含真实扩展名。引擎保存的路径为 `packages/<扩展名><path>/`，客户端 `LunarLtk/LtkLuaUtil.qml:getFullSkinPath` 直接拼接该路径与文件名。
- 因此文件名无需等于程序 ID，但必须注册关联。引擎不会仅凭文件名自动识别客将状态。

例如，文件 `image/skins/standard/han_001_guest_v01.jpg` 对应的有效注册结构为：

```lua
extension:addSkinPackage {
  path = "/image/skins/standard",
  content = {
    {
      enabled_generals = { "hanjin__han001" },
      skins = { "han_001_guest_v01.jpg" },
    },
  },
}
```

这只是接口示例，不要求逐将手写上述代码。公共注册入口应依据正式内容数据和命名约定统一生成注册，或采用其他集中方式；不规定必须扫描目录，不维护逐图片路径清单，也不在每名客将技能中写换图分支。中文皮肤标题另行翻译。

`_guest_v01` 存在且已注册时可作为初始客将皮肤；缺图时回退引擎默认图，不要求额外复制普通 `_v01`。选将与入场的通用选择需求另见[客将初始皮肤功能设计](guest-skins.md)。当前尚未实装该功能，皮肤注册也不替代所有界面的默认图片入口。骨骼皮肤多文件结构另按引擎接口处理。

以上兼容性结论来自锁定源码核对，未新增皮肤或进行客户端皮肤显示验收。

## 资料与维护

正式编号和分包以本项目维护的数据与已确认设计为准，当前标准包见 `pkg/hanjin_generals/data/standard.lua` 与[标准武将资料](../../rules/standard-generals.md)。`docs/heroes.json` 只是外部参考，不是正式编号、分包或构建的规范来源。

新增图片先确认用途及引擎入口；缺少素材时索取原材料，不自行生成或复制占位。构建使用 `python scripts/build_release.py`，开发同步使用 `scripts/dev.ps1`，均保持源码相对路径。同步只覆盖对应文件，删除或改名后须核对开发副本旧文件；原稿只在源码中维护。

迁移时核对图片字节和安装包路径，涉及状态换图时另验客户端及运行时行为。静态路径检查不代替实际显示验收；最新结果见[开发状态](status.md)。

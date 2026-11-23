# JIN022B 牵弘

[返回分包索引](../shi.md)

<a id="jin022b-1"></a>

## 烈戎

- **标识与依据** · 牵弘（JIN022B，势包），运行时 ID `qiao__skill_jin022b_1`。见[源码](../../../../../pkg/qiao_generals/skills/skill_jin022b_1.lua)和[逐将规则](../../../../rules/generals/jin022b-qianhong.md)。

牌面采用[项目登记](../../../../../pkg/qiao_generals/data/zhen_shi_jin.lua)的文字，与[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L1958)有差异，采用依据与边界见[项目规则](../../../../rules/generals/jin022b-qianhong.md)。

> 出牌阶段限一次，你可以失去1点体力，令你本回合攻击范围至多+X（X为你已损失的体力值），视为使用火【杀】〈助战→伤害+1〉。

- **实现与接口** · 牵弘于出牌阶段可先失去 1 点体力，按已损失体力值选择本回合增加的攻击范围，再从正式虚拟用牌入口使用火【杀】并登记助战增伤条目。
- **验证依据** · [jin022b_qianhong.lua](../../../../../tests/jin022b_qianhong.lua#L40)。覆盖攻击范围变化和真实火【杀】；目标选择数据使用测试构造。
- **未完成与边界** · 复杂助战分支待独立验收。

<a id="jin022b-2"></a>

## 勤边

- **标识与依据** · 牵弘（JIN022B，势包），运行时 ID `qiao__skill_jin022b_2`。见[源码](../../../../../pkg/qiao_generals/skills/skill_jin022b_2.lua)和[逐将规则](../../../../rules/generals/jin022b-qianhong.md)。

牌面采用[项目登记](../../../../../pkg/qiao_generals/data/zhen_shi_jin.lua)的文字，与[石激桑武将列表.json](../../../../../assets/docs/石激桑武将列表.json#L1959)有差异，采用依据与边界见[项目规则](../../../../rules/generals/jin022b-qianhong.md)。

> 结束阶段，你可以将一张手牌当【逐近弃远】〈助战→执行两项〉对你攻击范围内距离最远的一名其他角色使用。

- **实现与接口** · 牵弘于结束阶段从攻击范围内最远的其他角色中选一人，将一张手牌当【逐近弃远】对其使用，并赋予正式的助战双项条目。
- **验证依据** · [jin022b_qianhong.lua](../../../../../tests/jin022b_qianhong.lua#L40)。验证攻击范围内最远候选的计算。
- **未完成与边界** · 从结束阶段请求到助战双项的完整流程尚未单独验收。

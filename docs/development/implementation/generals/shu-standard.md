# 蜀势力标准包：逐将检索与验证入口

范围为 SHU001–011、SHU013–016 共 15 张标准武将、26 个技能及四种关联翼从；不含君主版。卡面依据为[标准武将表](../../../rules/standard-generals.md)，集智采用[已确认裁定](../../../rules/generals/shu007-huangyueying.md)。技能正文、接口和验证依据在各武将页维护。当前验收状态见[开发状态](../../status.md)。

| 编号 | 武将 | 技能 |
| --- | --- | --- |
| SHU001 | [刘备](standard/shu001.md) | [仁德](standard/shu001.md#shu001-1) |
| SHU002 | [关羽](standard/shu002.md) | [武圣](standard/shu002.md#shu002-1)、[周仓](standard/retinue-zhoucang.md#zhoucang)（关联翼从） |
| SHU003 | [张飞](standard/shu003.md) | [咆哮](standard/shu003.md#shu003-1) |
| SHU004 | [诸葛亮](standard/shu004.md) | [观星](standard/shu004.md#shu004-1)、[空城](standard/shu004.md#shu004-2) |
| SHU005 | [赵云](standard/shu005.md) | [龙胆](standard/shu005.md#shu005-1)、[突阵](standard/shu005.md#shu005-2)、[白马义从](standard/retinue-baima-yicong.md#baima-yicong)（关联翼从） |
| SHU006 | [马超](standard/shu006.md) | [马术](standard/shu006.md#shu006-1)、[铁骑](standard/shu006.md#shu006-2)、[西凉精骑](standard/retinue-xiliang-jingqi.md#xiliang-jingqi)（关联翼从） |
| SHU007 | [黄月英](standard/shu007.md) | [集智](standard/shu007.md#shu007-1)、[藏机](standard/shu007.md#shu007-2) |
| SHU008 | [黄忠](standard/shu008.md) | [烈勇](standard/shu008.md#shu008-1) |
| SHU009 | [魏延](standard/shu009.md) | [狂骨](standard/shu009.md#shu009-1) |
| SHU010 | [庞统](standard/shu010.md) | [连环](standard/shu010.md#shu010-1)、[涅槃](standard/shu010.md#shu010-2) |
| SHU011 | [诸葛亮](standard/shu011.md) | [八阵](standard/shu011.md#shu011-1)、[火计](standard/shu011.md#shu011-2)、[看破](standard/shu011.md#shu011-3) |
| SHU013 | [刘禅](standard/shu013.md) | [享乐](standard/shu013.md#shu013-1)、[放权](standard/shu013.md#shu013-2) |
| SHU014 | [孟获](standard/shu014.md) | [祸首](standard/shu014.md#shu014-1)、[再起](standard/shu014.md#shu014-2) |
| SHU015 | [祝融夫人](standard/shu015.md) | [巨象](standard/shu015.md#shu015-1)、[烈刃](standard/shu015.md#shu015-2)、[象兵](standard/retinue-xiangbing.md#xiangbing)（关联翼从） |
| SHU016 | [甘夫人](standard/shu016.md) | [淑慎](standard/shu016.md#shu016-1)、[神智](standard/shu016.md#shu016-2) |

| 翼从 | 专属技能记录 |
| --- | --- |
| 周仓 | [实现与验证](standard/retinue-zhoucang.md#zhoucang) |
| 白马义从 | [实现与验证](standard/retinue-baima-yicong.md#baima-yicong) |
| 西凉精骑 | [实现与验证](standard/retinue-xiliang-jingqi.md#xiliang-jingqi) |
| 象兵 | [实现与验证](standard/retinue-xiangbing.md#xiangbing) |

统领能力与士兵转换沿用[公共机制](../commander-retinue.md)，与上述专属技能分别结算。周仓的全局唯一取得和关羽限一统领能力是两项独立限制。

## 接线与验证

- 所有正式技能通过 `qiaoImplemented` 登记；连环重铸为辅助入口，不增加天生技能数。
- 模式安装 `shu_lieyong_bonus`、`shu_state_rule`、`shu_savage_rule`、`shu_tieqi_invalidity`，承接已建立持续效果、红牌历史与按位置失效，均随正式 `pkg/` 发布。八阵随八卦阵来源同步，暗将预亮由[公共入口](../skill-ui.md#开局预亮与技能发动请求)统一限制。
- 公开的指定目标条件见[周仓](standard/retinue-zhoucang.md#zhoucang)。
- 六套专项 `shu_conversion`、`shu_effects`、`shu_phases`、`shu_savage`、`shu_tieqi`、`shu_retinues` 均纳入默认套件；命令结果和修复证据集中见[共享验证记录](verification-evidence.md#shu-standard)。
- 蜀区 15 个主称号、26 条卡面文本按 JSON 标准版同步；空城配将贡献仍为主将减一，不改变已有配将接口。

## 验收边界

自动化不替代真实客户端、联网／重连及干净本体安装人工验收。少见组合如多个同名来源、响应牌被插入效果移走、复杂多重抵消，按具体风险补测，不宣称穷举。卡面描述与规范描述中的“虚拟牌”按已确认的描述层次区别解释。

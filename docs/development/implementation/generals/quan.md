# 权包

本包共正式接入 13 张武将牌（六势力各 2 张普通武将共 12 张 + 君曹操 1 张）、2 种翼从／偏将（无当飞军、胡车儿）及 2 条统领来源，统一归入 `qiao_zhenshi` 武将包并使用角标 `qiao_prefix_quan`（「权」）。规则依据见[六势力权包索引](../../../rules/quan-generals.md)。

五名军令武将（刘宏【鬻爵】、于禁【常令】、吴国太【补益】、袁术【庸肆】、卫瓘【追诛】）集中复用汉晋军令公共适配 [junling.lua](../../../../pkg/qiao_mode/rules/junling.lua)，其他国战模式沿用上游的军令准备与执行函数。持续延时与全局历史记账集中承接于模式级规则 [quan_rules.lua](../../../../pkg/qiao_mode/skills/quan_rules.lua)。

机器人的选令和答复见[军令的发起与响应](../robot-ai.md#军令的发起与响应)。其他效果及覆盖边界见[变包与权包的策略覆盖](../robot-ai.md#变包与权包的策略覆盖)。

## 逐将检索

| 编号 | 武将 | 客将势力 | 技能 |
| --- | --- | --- | --- |
| EM(WEI001) | [君曹操](quan/em-wei001.md) | — | [建安](quan/em-wei001.md#em-wei001-1)、[挥鞭](quan/em-wei001.md#em-wei001-2)、[总御](quan/em-wei001.md#em-wei001-3)、[霸者求贤状](quan/em-wei001.md#em-wei001-banner)（派生／标记）、[常令](quan/em-wei001.md#em-wei001-changling)（派生／标记）、[奇策](quan/em-wei001.md#em-wei001-qice)（派生／标记）、[胆戾](quan/em-wei001.md#em-wei001-danli)（派生／标记） |
| HAN003 | [刘宏](quan/han003.md) | — | [鬻爵](quan/han003.md#han003-1) |
| HAN021 | [曹节](quan/han021.md) | 魏 | [守玺](quan/han021.md#han021-1)、[悬壶](quan/han021.md#han021-2) |
| WEI021B | [毛玠](quan/wei021b.md) | — | [征辟](quan/wei021b.md#wei021b-1)、[奉迎](quan/wei021b.md#wei021b-2) |
| WEI024 | [于禁](quan/wei024.md) | 汉、蜀、吴 | [常令](quan/wei024.md#wei024-1) |
| SHU023 | [王平](quan/shu023.md) | — | [将略](quan/shu023.md#shu023-1)（统领：[无当飞军](quan/retinue-wudang-feijun.md#wudang-feijun)） |
| SHU024 | [法正](quan/shu024.md) | 群 | [定军](quan/shu024.md#shu024-1)、[恩怨](quan/shu024.md#shu024-2) |
| WU019 | [陆抗](quan/wu019.md) | — | [决堰](quan/wu019.md#wu019-1)、[恪守](quan/wu019.md#wu019-2) |
| WU024 | [吴国太](quan/wu024.md) | 蜀 | [补益](quan/wu024.md#wu024-1)、[甘露](quan/wu024.md#wu024-2) |
| QUN021 | [袁术](quan/qun021.md) | 汉 | [庸肆](quan/qun021.md#qun021-1)、[伪帝](quan/qun021.md#qun021-2) |
| QUN023 | [张绣](quan/qun023.md) | 魏 | [从谏](quan/qun023.md#qun023-1)、[附敌](quan/qun023.md#qun023-2)（统领限一偏将：[胡车儿](quan/retinue-hucheer.md#hucheer)） |
| JIN021 | [卫瓘](quan/jin021.md) | — | [乘隙](quan/jin021.md#jin021-1)、[追诛](quan/jin021.md#jin021-2) |
| JIN024 | [贾南风](quan/jin024.md) | — | [伤败](quan/jin024.md#jin024-1)、[废戮](quan/jin024.md#jin024-2) |

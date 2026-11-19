-- 阵/势包新增翼从与统领来源的独立 fragment。
-- 由中央 init 合并；翼从武将仍归 zhenshi 包，不进入标准90将。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 0
M.retinueCount = 3
M.commanderCount = 5
M.skillCount = 0
M.retinueSkillCount = 3
M.kingdoms = { "wei", "wu", "jin", "qun" }
M.generals = {  }
M.retinues = {
  {
    id = [==[qiao_heg__retinue_qingzhou_jingrui]==],
    name = [==[青州精锐]==],
    limited = false,
    title = [==[臧霸｜雷杀]==],
    skill = {
      id = [==[qiao__retinue_skill_qingzhou_jingrui]==],
      name = [==[青州精锐]==],
      text = [==[出牌阶段限一次，你可以令一名手牌数最小的角色选择一项：1.弃置一张手牌；2.你对其造成1点伤害。]==],
      tags = {  },
    },
  },
  {
    id = [==[qiao_heg__retinue_lujiang_shangjia]==],
    name = [==[庐江上甲]==],
    limited = false,
    title = [==[陈武&董袭｜铁索连环]==],
    skill = {
      id = [==[qiao__retinue_skill_lujiang_shangjia]==],
      name = [==[庐江上甲]==],
      text = [==[出牌阶段限X次（X为拥有庐江上甲的角色数），你可以调整手牌至你装备区的牌数，若为弃牌，你此阶段使用【杀】的次数+1。]==],
      tags = {  },
    },
  },
  {
    id = [==[qiao_heg__retinue_bazhenbing]==],
    name = [==[八阵兵]==],
    limited = false,
    title = [==[姜维/马隆｜闪]==],
    skill = {
      id = [==[qiao__retinue_skill_bazhenbing]==],
      name = [==[八阵兵]==],
      text = [==[轮次技，一名角色的出牌阶段开始时，你可以视为使用【调虎离山】，此牌结算中其可以将【杀】当【无懈可击】使用。]==],
      tags = {  },
    },
  },
}

M.commanders = {
  {
    general = [==[qiao_heg__wei023]==], number = [==[WEI023]==], name = [==[臧霸]==],
    retinue = [==[qiao_heg__retinue_qingzhou_jingrui]==], retinueName = [==[青州精锐]==],
    card = [==[qiao__thunder__slash]==], cardText = [==[雷杀]==],
    sourceText = [==[青州精锐 | 雷杀]==],
  },
  {
    general = [==[qiao_heg__wu023]==], number = [==[WU023]==], name = [==[陈武&董袭]==],
    retinue = [==[qiao_heg__retinue_lujiang_shangjia]==], retinueName = [==[庐江上甲]==],
    card = [==[qiao__iron_chain]==], cardText = [==[铁索连环]==],
    sourceText = [==[庐江上甲 | 铁索连环]==],
  },
  {
    general = [==[qiao_heg__shu012]==], number = [==[SHU012]==], name = [==[姜维]==],
    retinue = [==[qiao_heg__retinue_bazhenbing]==], retinueName = [==[八阵兵]==],
    card = [==[qiao__jink]==], cardText = [==[闪]==],
    sourceText = [==[八阵兵 | 闪]==],
  },
  {
    general = [==[qiao_heg__jin023]==], number = [==[JIN023]==], name = [==[马隆]==],
    retinue = [==[qiao_heg__retinue_bazhenbing]==], retinueName = [==[八阵兵]==],
    card = [==[qiao__jink]==], cardText = [==[闪]==],
    sourceText = [==[八阵兵 | 闪]==],
  },
  {
    general = [==[qiao_heg__em_qun010]==], number = [==[EM(QUN010)]==], name = [==[张角]==],
    retinue = [==[qiao_heg__retinue_huangjin_leishi]==], retinueName = [==[黄巾雷使]==],
    card = [==[qiao__iron_chain]==], cardText = [==[铁索连环]==],
    sourceText = [==[黄巾雷使 | 铁索连环]==],
  },
}

return M

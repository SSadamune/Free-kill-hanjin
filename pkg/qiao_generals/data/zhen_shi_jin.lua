-- 阵包 JIN006 杜预、势包 JIN022B 牵弘的独立数据片段。
-- 由 pkg/qiao_generals/init.lua 作为同一 zhenshi 包的 fragment 合并计数与将池。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 2
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 5
M.retinueSkillCount = 0
M.kingdoms = { "jin" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[JIN006]==],
    id = [==[qiao_heg__jin006]==],
    name = [==[杜预]==],
    kingdom = [==[jin]==],
    title = [==[文成武德]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = -1,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[JIN005]==],
    companionNames = { [==[JIN005]==] },
    companions = { [==[qiao_heg__jin005]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_jin006_1]==],
        name = [==[三陈]==],
        text = [==[出牌阶段限一次，你可以令一名角色摸三张牌，然后其弃置三张牌，若弃置牌类别各不同，其摸一张牌或复原此技能（本回合不能再选择相同角色）。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_jin006_2]==],
        name = [==[破竹]==],
        text = [==[主将技（☯️-1），出牌阶段限X次（X为此阶段“三陈”被复原的次数），你可以将一张手牌当【出其不意】使用。]==],
        related = false,
        tags = { [==[MainPlace]==] },
      },
      {
        id = [==[qiao__skill_jin006_3]==],
        name = [==[武库]==],
        text = [==[副将技，你可以将一张宝物牌当你本回合使用的上一张基本牌或普通锦囊牌使用。]==],
        related = false,
        tags = { [==[DeputyPlace]==] },
      },
    },
  },
  {
    number = [==[JIN022B]==],
    id = [==[qiao_heg__jin022b]==],
    name = [==[牵弘]==],
    kingdom = [==[jin]==],
    title = [==[猛鸷扑焰]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[—]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_jin022b_1]==],
        name = [==[烈戎]==],
        text = [==[出牌阶段限一次，你可以失去1点体力，令你本回合攻击范围至多+X（X为你已损失的体力值），视为使用火【杀】〈助战→伤害+1〉。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_jin022b_2]==],
        name = [==[勤边]==],
        text = [==[结束阶段，你可以将一张手牌当【逐近弃远】〈助战→执行两项〉对你攻击范围内距离最远的一名其他角色使用。]==],
        related = false,
        tags = {  },
      },
    },
  },
}

return M

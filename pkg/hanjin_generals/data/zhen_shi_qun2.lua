-- QUN024 张任的独立数据片段；仅供主批合入中央。
local M = {}

M.version = 1
M.mode = "hanjin_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 2
M.retinueSkillCount = 0
M.kingdoms = { "qun" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[QUN024]==],
    id = [==[hanjin__qun024]==],
    name = [==[张任]==],
    kingdom = [==[qun]==],
    title = [==[索命神射]==],
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
        id = [==[hanjin__skill_qun024_1]==],
        name = [==[穿心]==],
        text = [==[当你使用【杀】或【决斗】对目标角色造成伤害时，若你的翼从数小于2，你可以随机亮出未加入游戏的三种翼从并选择其中一张，其需将副将武将牌变更为此翼从，否则此伤害+1且你本局拥有此翼从。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[hanjin__skill_qun024_2]==],
        name = [==[龙飞]==],
        text = [==[阵法技，你队列的其他角色也拥有你的翼从。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
}

return M

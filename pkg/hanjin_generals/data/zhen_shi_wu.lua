-- 阵包 WU020 徐盛的独立数据片段。
-- 由中央 init 作为同一 zhenshi 包的 fragment 合并。
local M = {}

M.version = 1
M.mode = "hanjin_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 2
M.retinueSkillCount = 0
M.kingdoms = { "wu" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[WU020]==],
    id = [==[hanjin__wu020]==],
    name = [==[徐盛]==],
    kingdom = [==[wu]==],
    title = [==[江东的铁壁]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[丁奉、蒋钦]==],
    companionNames = { [==[丁奉]==], [==[蒋钦]==] },
    companions = { [==[hanjin__wu016]==], [==[hanjin__wu017]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[hanjin__skill_wu020_1]==],
        name = [==[疑城]==],
        text = [==[与你势力相同的角色成为【杀】的目标后，你可以令其摸一张牌，其选择一项：1.使用一张装备牌；2.于此回合结束时弃置一张牌。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[hanjin__skill_wu020_2]==],
        name = [==[破军]==],
        text = [==[当你使用【杀】指定一个目标后，你可以扣置其至多X张牌（X为其势力角色数），这些牌本回合移出游戏。]==],
        related = false,
        tags = {  },
      },
    },
  },
}

return M

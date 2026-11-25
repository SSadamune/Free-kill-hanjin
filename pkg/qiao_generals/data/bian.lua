-- 六势力变包正式数据：1 名普通武将。
-- 依据 docs/rules/bian-generals.md、各逐将规则页与石激桑武将列表（变包）定稿整理。
-- 由 pkg/qiao_generals/init.lua 合并至君临天下（qiao_zhenshi）正式包，角标为「变」。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 2
M.retinueSkillCount = 0
M.kingdoms = { "han" }

M.generals = {
  {
    number = [==[HAN023]==],
    id = [==[qiao_heg__han023]==],
    name = [==[伍琼&种辑]==],
    kingdom = [==[han]==],
    title = [==[前赴后继]==],
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
        id = [==[qiao__skill_han023_1]==],
        name = [==[除奸]==],
        text = [==[其他角色的出牌阶段开始时，若其体力值或手牌数最大，你可以令其此阶段对你使用【杀】无距离和次数限制，然后此阶段结束时，你对其造成1点伤害。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_han023_2]==],
        name = [==[心疾]==],
        text = [==[锁定技，你处于鏖战状态。当你于濒死状态失救时，你减1点体力上限并回复体力至1点。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
}

M.retinues = {
}

M.commanders = {
}

return M

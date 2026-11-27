-- 势包 SHU021 糜夫人的独立数据片段。
-- 由 pkg/qiao_generals/init.lua 作为同一 zhenshi 包的 fragment 合并计数与将池。
-- 闺秀、勇决为将牌技能；存嗣由勇决授予，不另计为将牌技能。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 2
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 5
M.retinueSkillCount = 0
M.kingdoms = { "shu" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[SHU021]==],
    id = [==[qiao_heg__shu021]==],
    name = [==[糜夫人]==],
    kingdom = [==[shu]==],
    title = [==[乱世沉香]==],
    halfHp = 1.5,
    hp = 3,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[刘备]==],
    companionNames = { [==[刘备]==] },
    companions = { [==[qiao_heg__shu001]==] },
    companionsUnresolved = {  },
    gender = "female",
    skills = {
      {
        id = [==[qiao__skill_shu021_1]==],
        name = [==[闺秀]==],
        text = [==[锁定技，此武将牌明置后，或结束阶段若你未受伤，你摸两张牌。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
      {
        id = [==[qiao__skill_shu021_2]==],
        name = [==[勇决]==],
        text = [==[出牌阶段，你可以移除此武将牌，令一名角色获得一枚珠联璧合标记和技能“存嗣”（每轮各限一次，当你于回合内使用【杀】后/回合外使用【桃】后，你可以获得之。）。]==],
        related = false,
        tags = {  },
      },
    },
  },
  {
    number = [==[SHU012]==],
    id = [==[qiao_heg__shu012]==],
    name = [==[姜维]==],
    kingdom = [==[shu]==],
    title = [==[一意回天、龙的衣缽]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = -1,
    guests = { [==[wei]==] },
    companionText = [==[诸葛亮]==],
    companionNames = { [==[诸葛亮]==] },
    companions = { [==[qiao_heg__shu004]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_shu012_1]==],
        name = [==[挑衅]==],
        text = [==[出牌阶段限一次，你可以令至多两名攻击范围内有你的角色依次执行以下效果：其可以对你使用一张【杀】，若你未因此受到伤害，你弃置其一张牌。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_shu012_2]==],
        name = [==[天覆]==],
        text = [==[主将技，阵法技，你队列的角色的回合内，所有角色的攻击范围+2。]==],
        related = false,
        tags = { [==[MainPlace]==] },
      },
      {
        id = [==[qiao__skill_shu012_3]==],
        name = [==[承志]==],
        text = [==[副将技（☯️-1），若你的主将拥有“观星”，则该技能卜算牌数+2，否则你拥有“观星”。]==],
        related = false,
        tags = { [==[DeputyPlace]==] },
      },
    },
  },
}

return M

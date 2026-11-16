-- 阵包 EM(SHU001) 君刘备的独立数据片段。
-- 君主版程序名不含 "lord"；由君主版登记后设 hidden/is_lord，不进普通将池。
-- 由中央 init 合并至阵势包，并登记君主升变与继位版本。
local M = {}

M.version = 1
M.mode = "hanjin_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "shu" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[EM(SHU001)]==],
    id = [==[hanjin__em_shu001]==],
    name = [==[刘备]==],
    kingdom = [==[shu]==],
    title = [==[龙横蜀汉]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[@faction:蜀]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    is_lord = true,
    lord_kingdoms = { "shu" },
    skills = {
      {
        id = [==[hanjin__skill_em_shu001_1]==],
        name = [==[章武]==],
        text = [==[君主技，你拥有“六师率义旗”。]==],
        related = false,
        tags = { [==[Lord]==] },
      },
      {
        id = [==[hanjin__skill_em_shu001_2]==],
        name = [==[天钺]==],
        text = [==[锁定技，其他角色的【飞龙夺凤】置入场上或弃牌堆时，改为你获得之；你不因使用【飞龙夺凤】而失去此牌时，你展示之并置于牌堆底，摸两张牌。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
      {
        id = [==[hanjin__skill_em_shu001_3]==],
        name = [==[激诏]==],
        text = [==[限定技，当你处于濒死时，你可以回复体力至2点并失去“章武”，获得“仁德”，然后你可以摸等同体力上限的牌，将手牌弃置至体力上限。]==],
        related = false,
        tags = { [==[Limited]==] },
      },
    },
  },
}

-- 中央主批接入时用于 Versions.register；本文件本身不改公共版本注册。
M.versions = {
  { normal = [==[hanjin__shu001]==], lord = [==[hanjin__em_shu001]==], kingdoms = { "shu" } },
}

return M

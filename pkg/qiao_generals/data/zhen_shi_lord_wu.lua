-- 变包 EM(WU001) 君孙权的独立数据片段。
-- 君主版程序名不含 "lord"；由君主版登记后设 hidden/is_lord，不进普通将池。
-- 由中央 init 合并至阵势包，并登记君主升变与继位版本。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "wu" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[EM(WU001)]==],
    id = [==[qiao_heg__em_wu001]==],
    name = [==[孙权]==],
    displayName = [==[<font color="#FFFF00">君</font>孙权]==],
    kingdom = [==[wu]==],
    title = [==[虎踞江东]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[@faction:吴]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_em_wu001_1]==],
        name = [==[嘉禾]==],
        text = [==[君主技，你拥有“缘江烽火图”。]==],
        related = false,
        tags = { [==[Lord]==] },
      },
      {
        id = [==[qiao__skill_em_wu001_2]==],
        name = [==[敛资]==],
        text = [==[出牌阶段限一次，你可以弃置一张牌并亮出牌堆顶的X张牌（X为处于吴势力攻击范围内的角色数），获得其中你弃置类别的牌，若你本回合得到过的牌数达到角色数，你失去此技能并获得“制衡”。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_em_wu001_3]==],
        name = [==[聚宝]==],
        text = [==[锁定技，防止其他角色不因弃置而移动你装备着的宝物牌。结束阶段，若【定澜夜明珠】在场上或弃牌堆，你摸一张牌，获得装备着该牌的角色一张牌。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
}

M.versions = {
  { normal = [==[qiao_heg__wu001]==], lord = [==[qiao_heg__em_wu001]==], kingdoms = { "wu" } },
}

return M

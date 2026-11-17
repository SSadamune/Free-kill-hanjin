-- 矢包 EM(HAN001) 君刘协的独立数据片段。
local M = {}
M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "han" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[EM(HAN001)]==],
    id = [==[qiao_heg__em_han001]==],
    name = [==[刘协]==],
    displayName = [==[<font color="#FFFF00">君</font>刘协]==],
    kingdom = [==[han]==],
    title = [==[或跃在渊]==],
    halfHp = 1.5,
    hp = 3,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[@faction:汉]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_em_han001_1]==],
        name = [==[初平]==],
        text = [==[君主技，此武将牌明置后，你获得游戏外的“诏书”；你因“诏书”获得的势力锦囊由你选择。]==],
        related = false,
        tags = { [==[Lord]==] },
      },
      {
        id = [==[qiao__skill_em_han001_2]==],
        name = [==[转蓬]==],
        text = [==[当你成为伤害牌的唯一目标后，你可以交给使用者一张牌并令此牌对你无效；若你已使用过其势力锦囊，改为其需交给你一张牌，否则此牌对你无效。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_em_han001_3]==],
        name = [==[天授]==],
        text = [==[锁定技，其他角色的【玉玺】或【赤霄剑】置入场上或弃牌堆时，改为置入你装备区。当你从装备区失去这些牌时，改为置于“诏书”上并摸两张牌。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
}

M.versions = {
  { normal = [==[qiao_heg__han001]==], lord = [==[qiao_heg__em_han001]==], kingdoms = { "han" } },
}

return M

-- 阵包 WEI018 曹洪、WU017 蒋钦的独立数据片段。
-- 由 pkg/qiao_generals/init.lua 作为同一 zhenshi 包的 fragment 合并计数与将池；
-- 不再单独注册包。
-- 牌面资料取自 docs/石激桑武将列表.json；效果实现在 pkg/qiao_generals/skills。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 2
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 4
M.retinueSkillCount = 0
M.kingdoms = { "wei", "wu" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[WEI018]==],
    id = [==[qiao_heg__wei018]==],
    name = [==[曹洪]==],
    kingdom = [==[wei]==],
    title = [==[魏之福将]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[曹仁]==],
    companionNames = { [==[曹仁]==] },
    companions = { [==[qiao_heg__wei011]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_wei018_1]==],
        name = [==[护援]==],
        text = [==[你的回合内，当牌置入一名角色的装备区后，你可以弃置其距离1的另一名角色区域里的一张牌。结束阶段，你可以将一张装备牌置于一名角色的装备区。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_wei018_2]==],
        name = [==[鹤翼]==],
        text = [==[阵法技，你队列的角色拥有“飞影”。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
  {
    number = [==[WU017]==],
    id = [==[qiao_heg__wu017]==],
    name = [==[蒋钦]==],
    kingdom = [==[wu]==],
    title = [==[祁奚之器]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[周泰、吕蒙]==],
    companionNames = { [==[周泰]==], [==[吕蒙]==] },
    companions = { [==[qiao_heg__wu013]==], [==[qiao_heg__wu003]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_wu017_1]==],
        name = [==[尚义]==],
        text = [==[出牌阶段限一次/当你响应其他角色的牌后，你可以令一名其他角色/其观看你的手牌，然后你观看其所有暗置武将牌和手牌，且你可以弃置其中每种黑色花色的手牌至多各一张。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_wu017_2]==],
        name = [==[鸟翔]==],
        text = [==[阵法技，若你是围攻角色，被你围攻的角色需多一张【闪】才能抵消围攻角色的【杀】。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
}

return M

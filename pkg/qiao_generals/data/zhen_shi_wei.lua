-- 阵包 WEI032 郭淮的独立数据片段。
-- 由 pkg/qiao_generals/init.lua 作为同一 zhenshi 包的 fragment 合并计数与将池。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "wei" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[WEI032]==],
    id = [==[qiao_heg__wei032]==],
    name = [==[郭淮]==],
    kingdom = [==[wei]==],
    title = [==[垂问秦雍、通儒英博]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = -1,
    deputyHpAdjust = 0,
    guests = { [==[jin]==] },
    companionText = [==[—]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_wei032_1]==],
        name = [==[精策]==],
        text = [==[每回合结束时，若你本回合使用或打出过的牌数：大于体力值，你可以摸一张牌；等于体力值，你可以摸两张牌。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_wei032_2]==],
        name = [==[疲攻]==],
        text = [==[主将技（☯️-1），当你使用或打出基本牌时，你可以指定一名角色，其交给其势力角色各一张手牌。]==],
        related = false,
        tags = { [==[MainPlace]==] },
      },
      {
        id = [==[qiao__skill_wei032_3]==],
        name = [==[屏御]==],
        text = [==[副将技，与你势力相同的其他角色需要使用【闪】时，其可以令你选择是否打出之（视为由其使用）。]==],
        related = false,
        tags = { [==[DeputyPlace]==] },
      },
    },
  },
}

table.insert(M.generals, {
 number="WEI023", id="qiao_heg__wei023", kingdom="wei", hp=4, halfHp=2,
 name=[==[臧霸]==], title=[==[岱岳独雄、节度青徐]==], gender="male", mainHpAdjust=0, deputyHpAdjust=0,
 guests={"qun"}, companions={"qiao_heg__wei004"}, companionsUnresolved={},
 skills={{id="qiao__skill_wei023_1",name=[==[横江]==],text=[==[当你受到1点伤害后，你可以令当前回合角色本回合手牌上限-X（X为其装备区牌数，至少为1）。若如此做，其本回合弃牌阶段结束时，若其此阶段弃置过牌，则你摸一张牌，否则你摸牌至体力上限。]==],related=false,tags={}}},
})
M.generalCount=M.generalCount+1
M.skillCount=M.skillCount+1
return M

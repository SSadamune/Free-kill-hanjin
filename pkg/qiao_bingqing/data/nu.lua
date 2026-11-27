-- 弩包卡面采用石激桑列表，客籍取紫乔专栏客将牌图。
local M = {}
M.generals = {
  {
    id = "qiao_heg__han043", name = "杨奉&韩暹", title = "忠勇半途、浪起艢摧",
    kingdom = "han", hp = 4, gender = "male",
    guests = { "qun" }, companions = {},
    skills = {
      { id = "qiao__skill_han043_1", name = "拔驾", text = "锁定技，此武将牌明置后，你将场上一张装备牌置入装备区，称为“舆”；与你势力相同的其他角色视为装备着“舆”；若为君主装备，对应势力角色不能响应你的牌；当你失去“舆”后，你于此阶段结束时失去1点体力并暗置此武将牌。" },
    },
  },
  {
    id = "qiao_heg__han055", name = "陶谦", title = "寄州桃园、精兵鸷首",
    kingdom = "han", hp = 3, gender = "male",
    guests = { "qun", "shu" }, companions = {},
    commander = { retinue = "qiao_heg__retinue_danyang_qingjin", card = "qiao__slash", cardText = "杀", name = "丹阳青巾" },
    skills = {
      { id = "qiao__skill_han055_1", name = "厉治", text = "锁定技，与你势力相同的角色结束阶段，若其本回合摸牌数不足三张，则你令其失去1点体力并摸两张牌，否则你摸一张牌且交给其一张牌。" },
      { id = "qiao__skill_han055_2", name = "州忧", text = "锁定技，当你进入濒死时，你将三张牌交给其他角色（不足则全给），若你本回合首次以此法给出了三张牌，你回复1点体力。" },
    },
  },
}
M.retinues = {
  {
    id = "qiao_heg__retinue_danyang_qingjin", name = "丹阳青巾",
    skill = { id = "qiao__retinue_skill_danyang_qingjin", name = "丹阳青巾", text = "锁定技，每回合每名角色限一次，当你使用牌指定一名拥有丹阳青巾的角色为目标后，你摸一张牌。" },
  },
}
return M

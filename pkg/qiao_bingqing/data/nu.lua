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
}
M.retinues = {
}
return M

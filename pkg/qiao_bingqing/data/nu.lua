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
  {
    id = "qiao_heg__jin067", name = "李秀", title = "婴城自守",
    kingdom = "jin", hp = 4, gender = "female",
    guests = {}, companions = {},
    skills = {
      { id = "qiao__skill_jin067_1", name = "替军", text = "判定阶段开始前，你可以将场上一张延时锦囊牌移至你判定区，或将一张装备牌置入任意角色装备区。若如此做，此阶段改为出牌阶段。" },
      { id = "qiao__skill_jin067_2", name = "誓众", text = "每阶段限一次，你使用【杀】时可以多指定至多X个目标（X为你场上的牌数），若目标角色场上牌数各不相同，你摸等同目标数的牌。" },
    },
  },
  {
    id = "qiao_heg__jin076", name = "孟观", title = "中宮翊卫",
    kingdom = "jin", hp = 4, gender = "male",
    guests = {}, companions = { "qiao_heg__am_jin039", "qiao_heg__jin039" },
    commander = { retinue = "qiao_heg__retinue_suwei_zhongjun", card = "qiao__chasing_near", cardText = "逐近弃远", name = "宿卫中军" },
    skills = {
      { id = "qiao__skill_jin076_1", name = "积弩", text = "结束阶段，你可以将任意张基本或普通锦囊牌扣置于武将牌上（至多有五张）。你可以如手牌般使用或打出这些牌并判定，若为黑色，此牌不可被抵消。" },
      { id = "qiao__skill_jin076_2", name = "天述", text = "当一名角色的判定牌生效时，若与本局上次判定结果颜色相同，你可以令其摸一张牌。" },
    },
  },
  {
    id = "qiao_heg__qun029", name = "高顺", title = "此志无前",
    kingdom = "qun", hp = 4, gender = "male",
    guests = {}, companions = {},
    commander = { retinue = "qiao_heg__retinue_xianzhenying", card = "qiao__chasing_near", cardText = "逐近弃远", name = "陷阵营" },
    skills = {
      { id = "qiao__skill_qun029_1", name = "迅击", text = "每回合结束时，你可以依次视为对任意名本回合使用过【酒】的角色或明置过武将牌的非当前回合角色各使用一张【杀】。" },
      { id = "qiao__skill_qun029_2", name = "擐甲", text = "当你指定/成为【杀】的目标后，你可以将一个目标/使用者装备区的一张牌置入你装备区，结算后将你装备区同副类别的牌移动给其。" },
    },
  },
  {
    id = "qiao_heg__qun139", name = "管亥", title = "盗跖临青",
    kingdom = "qun", hp = 4, gender = "male",
    guests = {}, companions = {},
    commander = { retinue = "qiao_heg__retinue_qingzhou_jingrui", card = "qiao__iron_chain", cardText = "铁索连环", name = "青州精锐" },
    skills = {
      { id = "qiao__skill_qun139_1", name = "卸尾", text = "每轮各限一次，你可以一张手牌置于武将牌上（称为“饵”），并视为使用【杀】/【闪】。" },
      { id = "qiao__skill_qun139_2", name = "诱阙", text = "出牌阶段，你可以用点数最小的“饵”与一名角色拼点：没赢者展示手牌，弃置其中点数大于拼点牌的牌，视为对赢者使用雷【杀】，此牌造成伤害后，你摸一张牌。" },
    },
  },
}
M.retinues = {
  {
    id = "qiao_heg__retinue_danyang_qingjin", name = "丹阳青巾",
    skill = { id = "qiao__retinue_skill_danyang_qingjin", name = "丹阳青巾", text = "锁定技，每回合每名角色限一次，当你使用牌指定一名拥有丹阳青巾的角色为目标后，你摸一张牌。" },
  },
  {
    id = "qiao_heg__retinue_suwei_zhongjun", name = "宿卫中军",
    skill = { id = "qiao__retinue_skill_suwei_zhongjun", name = "宿卫中军", text = "其他势力角色回合结束时，你可以判定X次（X为你本回合使用过的牌数），其中每包含一种颜色，你视为对其使用一张【杀】。" },
  },
  {
    id = "qiao_heg__retinue_xianzhenying", name = "陷阵营",
    skill = { id = "qiao__retinue_skill_xianzhenying", name = "陷阵营", text = "当你使用【杀】造成伤害时，你可以弃置一张【桃】、【酒】或装备牌，然后此伤害+1。" },
  },
}
return M

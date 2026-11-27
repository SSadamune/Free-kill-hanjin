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
  {
    id = "qiao_heg__shu036", name = "张嶷", title = "通壮逾古",
    kingdom = "shu", hp = 4, gender = "male",
    guests = {}, companions = {},
    commander = { retinue = "qiao_heg__retinue_wudang_feijun", card = "qiao__slash", cardText = "杀", name = "无当飞军" },
    skills = {
      { id = "qiao__skill_shu036_1", name = "越险", text = "当你指定或成为【杀】的一个目标后，你可以令此目标角色摸一张牌（若其手牌数小于2/未受伤，你可以将摸牌数改为两张/零张），其只能使用因此摸的牌响应此【杀】。" },
    },
  },
  {
    id = "qiao_heg__shu054", name = "张翼", title = "逆命承志、秉心维旅",
    kingdom = "shu", hp = 4, gender = "male",
    guests = { "qun" }, companions = { "qiao_heg__shu027" },
    skills = {
      { id = "qiao__skill_shu054_1", name = "殿军", text = "回合结束时，你可以执行额外的出牌阶段。每回合限一次，当你需要使用【杀】时，你可以失去1点体力，将一张手牌当【杀】使用。" },
      { id = "qiao__skill_shu054_2", name = "抗锐", text = "有角色于其回合内首次扣减体力后，你可以选择一项：1.其回复1点体力；2.其本回合下次造成伤害时，此伤害+1且其本回合手牌上限为0。" },
    },
  },
  {
    id = "qiao_heg__wei034", name = "曹真", title = "渊然难测",
    kingdom = "wei", hp = 4, gender = "male",
    guests = {}, companions = {},
    commander = { retinue = "qiao_heg__retinue_hubaoqi", card = "qiao__jink", cardText = "闪", name = "虎豹骑" },
    skills = {
      { id = "qiao__skill_wei034_1", name = "司镇", text = "你响应过牌的阶段结束时，你可以视为使用一张【杀】（若与你势力相同的角色此阶段均未受到过伤害，此【杀】无距离限制）。" },
    },
  },
  {
    id = "qiao_heg__wei061", name = "曹纯", title = "英才孰比",
    kingdom = "wei", hp = 4, gender = "male",
    guests = {}, companions = {},
    commander = { retinue = "qiao_heg__retinue_hubaoqi", card = "qiao__slash", cardText = "杀", name = "虎豹骑" },
    skills = {
      { id = "qiao__skill_wei061_1", name = "督锐", text = "与你势力相同的角色共计造成过至少2点伤害的回合结束时，你可以视为使用一张【杀】， 若本回合受到过伤害且存活的角色仅有一名，此【杀】对其造成伤害时，伤害+1。" },
    },
  },
  {
    id = "qiao_heg__wu028", name = "韩当", title = "义勇的昭公",
    kingdom = "wu", hp = 4, gender = "male",
    guests = {}, companions = { "qiao_heg__wu004", "qiao_heg__wu027" },
    commander = { retinue = "qiao_heg__retinue_jiefanwei", card = "qiao__slash", cardText = "杀", name = "解烦卫" },
    skills = {
      { id = "qiao__skill_wu028_1", name = "弓骑", text = "出牌阶段限一次，你可以弃置一张牌并令你本回合的攻击范围+4，若此牌为装备牌，你弃置一名其他角色的一张牌。" },
      { id = "qiao__skill_wu028_2", name = "驰援", text = "限定技，出牌阶段，你可以选择一名角色，令攻击范围内含有其的角色各选择一项：1.弃置一张武器牌；2.令其摸一张牌。" },
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
  {
    id = "qiao_heg__retinue_hubaoqi", name = "虎豹骑",
    skill = { id = "qiao__retinue_skill_hubaoqi", name = "虎豹骑", text = "每回合首张由拥有虎豹骑的角色使用且目标唯一的【杀】结算后，你可以对相同目标使用一张【杀】并摸一张牌。" },
  },
  {
    id = "qiao_heg__retinue_jiefanwei", name = "解烦卫",
    skill = { id = "qiao__retinue_skill_jiefanwei", name = "解烦卫", text = "限定技，出牌阶段，你可以弃置两张牌并令一名角色回复1点体力。若为你，则你复原自己一个“出牌阶段限一次”的技能，否则你复原其一个限定技。" },
  },
}
return M

-- 武将与技能原文取自石激桑列表的「矢」包。
return {
  generals = {
    {
      id = "qiao_heg__han047", name = "田畴",
      title = "启导山河、长驱自到", kingdom = "han",
      hp = 4, gender = "male",
      guests = { "wei", "qun" }, companions = { "qiao_heg__han022" },
      guestCompanions = { "qiao_heg__wei003" },
      skills = {
        {
          id = "qiao__skill_han047_1", name = "锋引",
          text = "锁定技，你相邻角色成为与你势力相同的角色使用普通【杀】的目标后，你令其不能响应。",
        },
        {
          id = "qiao__skill_han047_2", name = "径出",
          text = "当你于回合内使用牌后，你可以令一名角色本回合移出游戏，然后若场上仅剩你和一名其他角色，你摸两张牌且交给其一张牌，若你与其势力相同，其可以用一个武将交换此武将。",
        },
      },
    },
    {
      id = "qiao_heg__han051", name = "袁隗",
      title = "优游图免", kingdom = "han",
      hp = 3, gender = "male",
      guests = {}, companions = {},
      skills = {
        {
          id = "qiao__skill_han051_1", name = "唆令",
          text = "出牌阶段限一次，你可以将一张黑色手牌交给一名其他角色并指定另一名角色，令其选择一项：1.将两张黑色手牌当【杀】对后者使用；2.后者可以对其使用任意张【杀】。",
        },
        {
          id = "qiao__skill_han051_2", name = "趋奉",
          text = "每回合限一次，你交给或得到其他角色牌后，若你手牌数大于其，你可以与其各摸一张牌。",
        },
      },
    },
    {
      id = "qiao_heg__jin037", name = "成济&成倅",
      title = "袒忿半瓦", kingdom = "jin",
      hp = 4, gender = "male",
      guests = {}, companions = {},
      skills = {
        {
          id = "qiao__skill_jin037_1", name = "养刀",
          text = "锁定技，若你的装备区里没有武器牌，你视为装备着场上攻击范围最大的所有武器牌。",
        },
        {
          id = "qiao__skill_jin037_2", name = "畜鸣",
          text = "其他角色出牌阶段限一次，其可以将一张【杀】当【酒】对你使用，然后将此【杀】交给你并视为对你使用一张无视武器限制的【借刀杀人】或【过河拆桥】。",
        },
      },
    },
    {
      id = "qiao_heg__jin066", name = "胡奋",
      title = "制凶硜北", kingdom = "jin",
      hp = 4, gender = "male",
      guests = {}, companions = {},
      skills = {
        {
          id = "qiao__skill_jin066_1", name = "威惠",
          text = "主将技，你的手牌上限+1；此武将牌被明置或交换后，你可以摸一张牌。",
        },
        {
          id = "qiao__skill_jin066_2", name = "练战",
          text = "副将技，你的攻击范围+1；此武将牌被明置或交换后，你可以视为使用一张目标+1的【杀】。",
        },
        {
          id = "qiao__skill_jin066_3", name = "转征",
          text = "结束阶段，你可以交换主副将，或令一名与你势力相同的其他角色选择是否与你交换副将。",
        },
      },
    },
    {
      id = "qiao_heg__qun033", name = "蔡夫人",
      title = "梅谢未霜、襄江的蒲苇", kingdom = "qun",
      hp = 3, gender = "female",
      guests = { "wei" }, companions = { "qiao_heg__qun_han030" },
      skills = {
        {
          id = "qiao__skill_qun033_1", name = "窃听",
          text = "其他角色的结束阶段，若其本回合未对与其势力不同的角色使用过手牌，你可以摸一张牌，或将其装备区的一张牌移动给你。",
        },
        {
          id = "qiao__skill_qun033_2", name = "献州",
          text = "限定技，出牌阶段，你可以将装备区的所有牌交给一名其他角色，回复等量体力，其对攻击范围内至多等量名角色各造成1点伤害。",
        },
      },
    },
  },
}

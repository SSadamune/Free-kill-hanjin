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
  },
}

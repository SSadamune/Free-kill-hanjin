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
  },
}

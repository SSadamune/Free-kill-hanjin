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
    {
      id = "qiao_heg__qun079", name = "高览",
      title = "攘诟之柱、名门的峦柱", kingdom = "qun",
      hp = 4, gender = "male",
      guests = { "wei" }, companions = {},
      guestCompanions = { "qiao_heg__wei009" },
      skills = {
        {
          id = "qiao__skill_qun079_1", name = "袭阵",
          text = "出牌阶段开始时，你可以弃置一张牌并令所有其他势力角色各选择一项：1.本回合不能使用或打出牌；2.你弃置其一张牌。",
        },
        {
          id = "qiao__skill_qun079_2", name = "芟敌",
          text = "结束阶段，你可以选择一个势力之中两名本回合受到过伤害的角色，交换其各一个武将。",
        },
      },
    },
    {
      id = "qiao_heg__shu048", name = "董允",
      title = "骨鲠良相", kingdom = "shu",
      hp = 3, gender = "male",
      guests = {}, companions = { "qiao_heg__shu018b" },
      skills = {
        {
          id = "qiao__skill_shu048_1", name = "秉正",
          text = "回合结束时，你可以令一名手牌数不等于体力值的角色摸一张牌或弃置一张手牌，然后若其手牌数等于体力值，你摸一张牌且可以交给其一张牌。",
        },
        {
          id = "qiao__skill_shu048_2", name = "舍宴",
          text = "当你每回合首次成为普通锦囊牌的目标时，你可以令此牌增加或减少一个目标（至少为1）。",
        },
      },
    },
    {
      id = "qiao_heg__shu091", name = "杨仪",
      title = "才盈杯杓、高傲的孤鹬", kingdom = "shu",
      hp = 3, gender = "male",
      guests = { "wei" }, companions = {},
      skills = {
        {
          id = "qiao__skill_shu091_1", name = "度断",
          text = "当你需要使用或打出【杀】或【闪】时，你可以令你本回合不能使用和打出此牌名的牌，然后摸两张牌。",
        },
        {
          id = "qiao__skill_shu091_2", name = "孤忿",
          text = "锁定技，当你不因【桃】而回复体力后，你用一个武将交换与你势力相同的其他角色一个武将；你的方片锦囊牌只能当【酒】使用。",
        },
      },
    },
    {
      id = "qiao_heg__wei035", name = "陈群",
      title = "典重千秋、纪世臣表", kingdom = "wei",
      hp = 3, gender = "male",
      guests = { "han", "shu" }, companions = { "qiao_heg__em_wei014", "qiao_heg__wei014" },
      skills = {
        {
          id = "qiao__skill_wei035_1", name = "品第",
          text = "出牌阶段，或当你受到伤害后，你可以弃置一张本回合未以此法选择过的类别的牌，然后令一名本回合未以此法选择过的其他角色摸或弃置X张牌（X为你本回合发动此技能的次数）。若其已受伤，你横置。",
        },
        {
          id = "qiao__skill_wei035_2", name = "法恩",
          text = "有角色横置或叠置后，你可以令其摸一张牌。",
        },
      },
    },
    {
      id = "qiao_heg__wei044", name = "程昱",
      title = "泰山捧日", kingdom = "wei",
      hp = 3, gender = "male",
      guests = {}, companions = { "qiao_heg__wei013" },
      skills = {
        {
          id = "qiao__skill_wei044_1", name = "胆戾",
          text = "当你受到伤害后，你可以选择一项：1.摸牌至与来源相同（至多摸五张）；2.移除副将并回复1点体力，然后来源弃置手牌至与你相同。",
        },
        {
          id = "qiao__skill_wei044_2", name = "脱先",
          text = "每回合限一次，与你势力相同的角色进入濒死时，你可以令另一名与你势力相同的角色选择是否用一个武将交换其一个武将。",
        },
      },
    },
    {
      id = "qiao_heg__wu027", name = "程普",
      title = "三朝虎首", kingdom = "wu",
      hp = 4, gender = "male",
      guests = {}, companions = { "qiao_heg__em_wu010", "qiao_heg__wu010", "qiao_heg__wu005" },
      skills = {
        {
          id = "qiao__skill_wu027_1", name = "铁脊",
          text = "你可以将两张牌当目标+1的火【杀】使用，然后选择一名与你势力相同的其他角色，若此火【杀】伤害数大于1，则你与其补充阴阳鱼标记，否则其选择是否用一个武将交换此武将。",
        },
        {
          id = "qiao__skill_wu027_2", name = "醇义",
          text = "与你势力相同的角色可以将国战标记当【酒】使用。",
        },
      },
    },
    {
      id = "qiao_heg__wu032", name = "顾雍",
      title = "持恒以渐、庙堂的玉磬", kingdom = "wu",
      hp = 3, gender = "male",
      guests = { "han" }, companions = {},
      guestCompanions = { "qiao_heg__han012" },
      skills = {
        {
          id = "qiao__skill_wu032_1", name = "密重",
          text = "锁定技，当你受到伤害时，若你的手牌数等于体力值，此伤害-1。",
        },
        {
          id = "qiao__skill_wu032_2", name = "秉壹",
          text = "每阶段限一次，当你因弃置而失去牌后，你可以展示手牌，若颜色均相同，你令至多等同你手牌数的角色各摸一张牌。",
        },
      },
    },
  },
}

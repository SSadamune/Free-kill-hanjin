-- JIN017 王浑、JIN023 马隆的独立数据片段；仅供主批合入中央。
local M = {}

M.version = 1
M.mode = "hanjin_heg_mode"
M.generalCount = 2
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 4
M.retinueSkillCount = 0
M.kingdoms = { "jin" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[JIN017]==],
    id = [==[hanjin__jin017]==],
    name = [==[王浑]==],
    kingdom = [==[jin]==],
    title = [==[旌旗蔽空]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[—]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[hanjin__skill_jin017_1]==],
        name = [==[总戎]==],
        text = [==[锁定技，你对横置的角色使用牌无距离和次数限制。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
      {
        id = [==[hanjin__skill_jin017_2]==],
        name = [==[遄征]==],
        text = [==[限定技，出牌阶段，你可以移除副将，然后获得“献捷”（你可以将一张非伤害牌当【铁索连环】〈富甲→目标+1〉使用），本回合你杀死角色的奖惩改为摸三张牌。]==],
        related = false,
        tags = { [==[Limited]==] },
      },
    },
  },
  {
    number = [==[JIN023]==],
    id = [==[hanjin__jin023]==],
    name = [==[马隆]==],
    kingdom = [==[jin]==],
    title = [==[灭虏夷险]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[—]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[hanjin__skill_jin023_1]==],
        name = [==[锋械]==],
        text = [==[出牌阶段限一次，你可以交换两名角色场上各一张装备牌，若其中一名角色为你，你视为对其中另一名角色或其队列使用一张【杀】。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[hanjin__skill_jin023_2]==],
        name = [==[锥形]==],
        text = [==[阵法技，若你为围攻角色，被你围攻的角色对你使用【杀】伤害-1；若你为被围攻角色，你对围攻你的角色使用【杀】伤害+1。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
}

return M

-- WU021 凌统 · 勇进
-- 限定技，出牌阶段，你可以依次移动场上至多三张各不同的装备牌。
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

local Board = require "packages.qiao.pkg.qiao_generals.util.wei_phases"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu021_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_wu021_2-prompt",
  max_game_use_time = 1,
  card_num = 0,
  target_num = 0,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryGame) > 0 then return false end
    local froms = Bian.boardEquipParticipants(Fk:currentRoom(), nil, player)
    return #froms > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local moved = {}
    local function allowed(from, to, id)
      return not table.contains(moved, id) and Bian.canMoveEquipTo(from, to, id, player)
    end
    for step = 1, 3 do
      if player.dead or player:isRemoved() then break end
      local result = Board.moveCardInBoard(room, player, skill.name, "e", "#qiao__skill_wu021_2-move:::" .. step,
        { allowed = allowed, exclude_ids = moved, cancelable = step > 1 })
      if not result then break end
      table.insert(moved, result.id)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "勇进",
  [":" .. skill.name] = "限定技，出牌阶段，你可以依次移动场上至多三张各不同的装备牌。",
  ["#qiao__skill_wu021_2-prompt"] = "勇进：依次移动场上至多三张各不同的装备牌",
  ["#qiao__skill_wu021_2-move"] = "勇进（第%arg/3张）：选择两名角色，移动其中一张未移动过的装备牌",
}

return skill

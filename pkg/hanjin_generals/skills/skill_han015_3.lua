-- HAN015 卢植 · 修体
--
-- 副将技。结束阶段，令至多X名角色摸牌至各自体力上限；X为本回合不同明置
-- 武将牌数。以明置事件中实际的将牌名按回合去重，同一张牌重复明置不增加X。
local H = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_history"

local skill = fk.CreateSkill {
  name = "hanjin__skill_han015_3",
  tags = { Skill.DeputyPlace },
}
skill.hanjinImplemented = true

local function revealedCount(room)
  return H.count(room)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Finish and revealedCount(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han015_3-invoke:::" .. revealedCount(player.room),
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = revealedCount(room)
    local targets = table.filter(room.alive_players, function(p)
      return p:isAlive() and not p:isRemoved()
    end)
    if #targets == 0 or x <= 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = math.min(x, #targets),
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han015_3-target:::" .. x,
      cancelable = false,
    })
    for _, to in ipairs(chosen or {}) do
      if to:isAlive() and not to:isRemoved() then
        local need = to.maxHp - #to:getCardIds(Player.Hand)
        if need > 0 then to:drawCards(need, skill.name) end
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han015_3"] = "修体",
  [":hanjin__skill_han015_3"] = "副将技，结束阶段，你可以令至多X名角色摸牌至体力上限（X为本回合明置的武将牌数）。",
  ["#hanjin__skill_han015_3-invoke"] = "修体：本回合明置了 %arg 张武将牌，可以令至多X名角色摸牌至体力上限",
  ["#hanjin__skill_han015_3-target"] = "修体：选择至多 %arg 名角色",
}

return skill

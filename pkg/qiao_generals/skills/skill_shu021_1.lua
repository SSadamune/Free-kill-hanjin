-- SHU021 糜夫人 · 闺秀
-- 锁定技：糜夫人将牌明置后摸2；结束阶段若未受伤（体力等于上限）摸2。
-- 明置分支不要求未受伤；只认糜夫人这张将牌的明置，不认其他将/换将。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu021_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local GENERAL = "qiao_heg__shu021"
local DONE_REVEAL = "qiao__skill_shu021_1-reveal-turn"

local function turnId(player)
  local current = player.room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

skill:addEffect(fk.GeneralRevealed, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if target == nil or target ~= player or data == nil then return false end
    if not player:hasShownSkill(skill.name) then return false end
    return data.m == GENERAL or data.d == GENERAL
  end,
  on_refresh = function(self, event, target, player, data)
    -- 同一张糜夫人牌在当前回合重复明置不重复摸牌。
    local key = tostring(turnId(player)) .. ":" .. GENERAL
    if player:getMark(DONE_REVEAL) == key then return end
    player.room:setPlayerMark(player, DONE_REVEAL, key)
    if not player.dead then player:drawCards(2, skill.name) end
  end,
})

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasShownSkill(skill.name)
      and data ~= nil and data.phase == Player.Finish and player.hp == player.maxHp
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    if not player.dead then player:drawCards(2, skill.name) end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu021_1"] = "闺秀",
  [":qiao__skill_shu021_1"] = "锁定技，此武将牌明置后，或结束阶段若你未受伤，你摸两张牌。",
}

return skill

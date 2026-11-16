-- WEI009 张郃 · 巧变
--
-- 规则基线：rules/standard-generals.md 魏区 WEI009。
-- 在准备与结束阶段以外的阶段即将开始时，可以弃置一张牌并跳过该阶段；
-- 若跳过摸牌阶段，可以获得至多两名其他角色各一张手牌；若跳过出牌阶段，
-- 可以移动场上一张牌。已经跳过的阶段不会再触发 EventPhaseChanging，
-- 因此不会重复跳过。移动场上牌复用公共的两步接口。
local W = require "packages.hanjin.pkg.hanjin_generals.util.wei_phases"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wei009_1",
}

local SKIPPABLE = {
  [Player.Judge] = true,
  [Player.Draw] = true,
  [Player.Play] = true,
  [Player.Discard] = true,
}

---@param player ServerPlayer
---@return integer[]
local function discardableCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

---@param room Room
---@param player ServerPlayer
---@return ServerPlayer[]
local function handCardTargets(room, player)
  return table.filter(room.alive_players, function(p)
    return p ~= player and not p:isRemoved() and #p:getCardIds("h") > 0
  end)
end

skill:addEffect(fk.EventPhaseChanging, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and SKIPPABLE[data.phase] == true and not data.skipped
      and #discardableCards(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei009_1-invoke",
    }) then
      return false
    end
    local discarded = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei009_1-discard",
      cancelable = true,
      skip = true,
    })
    if #discarded == 0 then return false end
    event:setCostData(self, { cards = discarded })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local legal = discardableCards(player)
    local paid = {}
    for _, id in ipairs(cost.cards or {}) do
      if table.contains(legal, id) then table.insert(paid, id) end
    end
    if #paid == 0 then return end
    room:throwCard(paid, skill.name, player, player)
    data.skipped = true

    if data.phase == Player.Draw then
      -- 跳过摸牌阶段后，获得至多两名其他角色各一张手牌。
      local targets = handCardTargets(room, player)
      if #targets == 0 then return end
      local chosen = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = math.min(2, #targets),
        targets = targets,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wei009_1-gain",
        cancelable = true,
      })
      for _, to in ipairs(chosen) do
        if player.dead then return end
        if to:isAlive() and not to:isRemoved() then
          local ids = to:getCardIds("h")
          if #ids > 0 then
            local id = ids[room:random(1, #ids)]
            room:obtainCard(player, id, false, fk.ReasonPrey, to, skill.name)
          end
        end
      end
    elseif data.phase == Player.Play then
      W.moveCardInBoard(room, player, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei009_1"] = "巧变",
  [":hanjin__skill_wei009_1"] = "你可以弃置一张牌并跳过一个阶段（准备和结束阶段除外），若为：摸牌阶段，你可以获得至多两名其他角色各一张手牌；出牌阶段，你可以移动场上的一张牌。",
  ["#hanjin__skill_wei009_1-invoke"] = "巧变：你可以弃置一张牌并跳过此阶段",
  ["#hanjin__skill_wei009_1-discard"] = "巧变：弃置一张牌以跳过此阶段",
  ["#hanjin__skill_wei009_1-gain"] = "巧变：选择至多两名其他角色，各获得其一张手牌",
}

skill.hanjinImplemented = true

return skill

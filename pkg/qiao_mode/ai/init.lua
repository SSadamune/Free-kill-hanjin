local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Skills = require "packages.qiao.pkg.qiao_mode.ai.skills"
local ViewAs = require "packages.qiao.pkg.qiao_mode.ai.view_as"
local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local Diplomacy = require "packages.qiao.pkg.qiao_mode.ai.diplomacy"
local Deadline = require "packages.qiao.pkg.qiao_mode.ai.deadline"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Reactions = require "packages.qiao.pkg.qiao_mode.ai.damage_reactions"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Cuipo = require "packages.qiao.pkg.qiao_generals.util.cuipo"
local Personality = require "packages.qiao.pkg.qiao_mode.ai.personality"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Heg = require "packages.hegemony.util"

local Robot = SmartAI:subclass("HanjinRobot")

local knownKingdom = Diplomacy.knownKingdom

function Robot:isFriend(target)
  if not target or target.dead or target:isRemoved() then return false end
  if target == self.player then return true end
  local own, theirs = Diplomacy.publicFaction(self.player), Diplomacy.publicFaction(target)
  return type(own) == "string" and own == theirs and Heg.compareKingdomWith(self.player, target)
end

function Robot:isEnemy(target)
  if not target or target == self.player or target.dead or target:isRemoved()
    or not knownKingdom(target.kingdom) then return false end
  local own, theirs = Diplomacy.publicFaction(self.player), Diplomacy.publicFaction(target)
  if own then
    return own == self.player or theirs == target or Heg.compareKingdomWith(self.player, target, true)
  end
  -- A robot knows its own selection. Its eventual reveal can also make it wild,
  -- so a matching unrevealed faction does not prove an alliance.
  local kingdom = self.player:getMark("__heg_kingdom")
  return knownKingdom(kingdom) and (kingdom == "wild" or kingdom ~= target.kingdom)
end

function Robot:attitude(target)
  return Diplomacy.attitude(self, target)
end

function Robot:hostileScore(target, tactical)
  local score = Diplomacy.hostileScore(self, target, tactical)
  if score and self.personality == "aggressive" and target.hp + target.shield <= 2 then
    return score + 1
  end
  return score
end

function Robot:supportScore(target, tactical)
  if not self:isFriend(target) then return tactical end
  local bonus = self.personality == "supportive" and target ~= self.player and 0.5 or 0
  return tactical + Diplomacy.humanBonus(self, target, 0.15) + bonus
end

function Robot:makeReply()
  local room = self.room
  local handler, currentSelf = room.current_request_handler, Self
  local skill = self.command == "AskForUseActiveSkill" and Fk.skills[self.data[1]]
  local extra = skill and skill._extra_data
  local ok, reply, timedOut = Deadline.run(SmartAI.makeReply, self)
  if ok and not timedOut then return reply end

  -- A deadline can unwind the native request setup before its cleanup.
  self.handler = nil
  self.mem = nil
  room.current_request_handler = handler
  Self = currentSelf
  if skill then skill._extra_data = extra end
  if timedOut then
    fk.qWarning(string.format("HanJin AI skipped %s for seat %d after 10 seconds", self.command, self.player.seat))
    return "__cancel"
  end
  error(reply, 0)
end

function Robot:handlePlayCard()
  if Cost.effectable(self.player, "qiao__skill_han014_1") then
    local index = Cuipo.useIndex(self.player, self.room.logic:getCurrentEvent())
    for _, stage in ipairs(Personality.standardOrder) do
      local reply = Cards.play(self, stage, index) or ViewAs.play(self, stage, index)
      if reply then return reply end
    end
  end
  for _, stage in ipairs(Personality.playOrder(self)) do
    local reply
    if stage == "cheap_recast" then
      reply = Cards.recast(self, true)
    else
      if stage == "damage" then reply = Skills.play(self, "attack_prep") end
      reply = reply or Cards.play(self, stage) or Skills.play(self, stage) or ViewAs.play(self, stage)
    end
    if reply then return reply end
    if stage == "draw" then
      reply = Skills.cooperativeAlliance(self)
      if reply then return reply end
    end
  end
  return Cards.recast(self) or Skills.fallbackAlliance(self)
end

function Robot:handleAskForSkillInvoke(data)
  local invoke = Skills.invoke(self, data)
  if invoke ~= nil then return invoke and "1" or "" end
  return SmartAI.handleAskForSkillInvoke(self, data)
end

function Robot:handleAskForUseActiveSkill(data)
  local reply = Skills.active(self, data)
  if reply ~= nil then return reply end
  return SmartAI.handleAskForUseActiveSkill(self, data)
end

function Robot:handleAskForChoices(data)
  return Skills.choice(self, data)
end

function Robot:handleAskForOptions(data)
  return Skills.choice(self, data)
end

function Robot:handleAskForUseCard(data)
  if data[1] == "qiao__retinue_skill_niujin" then return Cards.play(self) end
  if data[2] == "slash" then return Cards.playEnemySlash(self) or ViewAs.slash(self) end
  if data[2] == "jink" then
    local reply = ViewAs.response(self, "jink")
    local effect = Damage.effect(self, self.player)
    if effect and effect.card and effect.card.trueName == "slash"
      and Damage.acceptIncoming(self, effect, Reactions.responseCost(self, reply)) then return "" end
    return reply
  end
  if data[2] == "nullification" then
    local effect = Damage.effect(self, self.player)
    -- Only the original effect, never a nested counter-nullification.
    if effect and effect.card and effect.card.is_damage_card
      and effect.card.trueName ~= "duel" and effect.card.trueName ~= "collateral"
      and (data[3] or ""):endsWith(":" .. effect.card.name) then
      local material, cost = Cost.cheapest(self, function(id)
        return Fk:getCardById(id).trueName == "nullification"
      end)
      if material and Damage.acceptIncoming(self, effect, cost) then return "" end
    end
  end
  if data[2] == "peach" or data[2] == "peach,analeptic" then
    local reply = ViewAs.rescue(self, data)
    if reply ~= nil then return reply end
  end
  return SmartAI.handleAskForUseCard(self, data)
end

function Robot:handleAskForResponseCard(data)
  if data[2] == "slash" or data[2] == "jink" then
    local reply = ViewAs.response(self, data[2])
    local effect = Damage.effect(self, self.player)
    local expected = data[2] == "slash" and "savage_assault" or "archery_attack"
    if effect and effect.card and effect.card.trueName == expected
      and Damage.acceptIncoming(self, effect, Reactions.responseCost(self, reply)) then return "" end
    return reply
  end
  return SmartAI.handleAskForResponseCard(self, data)
end

function Robot:handleCustomDialog(data)
  local component = data.component
  if component and component.url == "packages/qiao/pkg/qiao_mode/qml/ZhoujunValueBox.qml" then
    return Slash.sealOption(self, component.prop, Cards.safeDamage)
  end
end

function Robot:handleAskForArrangeCards(data)
  return Skills.arrange(self, data)
end

function Robot:handleAskForPoxi(data)
  if data.type ~= "AskForCardsChosen" or not data.extra_data then return end
  local prompt = data.extra_data.prompt
  if prompt == "#qiao_move_board_pick" then return Board.chooseCard(self, data.data) end
  if prompt == "#qiao__skill_wu006_1-judge_card" then return Removal.chooseJudge(self, data.data) end
end

function Robot:handleAskForCardChosen(data)
  local card = Skills.chosen(self, data)
  if card then return card end
  -- Object-form requests are allowed to omit the prompt in FreeKill.
  if data[3] then return SmartAI.handleAskForCardChosen(self, data) end
end

local M = {}

function M.install(room)
  for _, player in ipairs(room.players) do
    player.ai = Robot:new(player)
    player.ai.room = room
  end
  Personality.assign(room)
end

return M

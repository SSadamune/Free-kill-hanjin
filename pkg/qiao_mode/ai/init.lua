local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Skills = require "packages.qiao.pkg.qiao_mode.ai.skills"
local ViewAs = require "packages.qiao.pkg.qiao_mode.ai.view_as"
local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local Diplomacy = require "packages.qiao.pkg.qiao_mode.ai.diplomacy"
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
  return Diplomacy.hostileScore(self, target, tactical)
end

function Robot:supportScore(target, tactical)
  return tactical + (self:isFriend(target) and Diplomacy.humanBonus(self, target) or 0)
end

function Robot:handlePlayCard()
  return Cards.play(self) or Skills.play(self) or ViewAs.play(self) or Cards.recast(self)
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
  if data[2] == "jink" then return ViewAs.response(self, "jink") end
  if data[2] == "peach" or data[2] == "peach,analeptic" then
    local reply = ViewAs.rescue(self, data)
    if reply ~= nil then return reply end
  end
  return SmartAI.handleAskForUseCard(self, data)
end

function Robot:handleAskForResponseCard(data)
  if data[2] == "slash" or data[2] == "jink" then return ViewAs.response(self, data[2]) end
  return SmartAI.handleAskForResponseCard(self, data)
end

function Robot:handleAskForArrangeCards(data)
  return Skills.arrange(self, data)
end

function Robot:handleAskForPoxi(data)
  if data.type == "AskForCardsChosen" and data.extra_data and data.extra_data.prompt == "#qiao_move_board_pick" then
    return Board.chooseCard(self, data.data)
  end
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
end

return M

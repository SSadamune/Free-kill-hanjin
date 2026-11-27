local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local M = {}

local function good(reason, suit, number)
  if reason == "indulgence_skill" or reason == "qiao__indulgence_skill" then return suit == Card.Heart end
  if reason == "supply_shortage_skill" or reason == "qiao__supply_shortage_skill" then return suit == Card.Club end
  if reason == "qiao__eight_diagram_skill" or reason == "eight_diagram_skill" then
    return suit == Card.Heart or suit == Card.Diamond
  end
  if reason == "qiao__skill_wei007_2" then return suit == Card.Spade or suit == Card.Club end
end

local function leijiValue(ai, source, target, suit)
  local amount = suit == Card.Spade and 2 or suit == Card.Club and 1 or 0
  local score = Damage.value(Damage.assess(ai, target, amount, fk.ThunderDamage))
  if suit == Card.Club and source:isWounded() then
    -- At one HP, keep the healing if the extra damage ties its value.
    local healing = source.hp <= 1 and 5 or source.hp == 2 and 4 or 3
    score = score + (ai:isFriend(source) and healing or -healing)
  end
  return score
end

local function value(ai, data, suit, number)
  local friendly, hostile = ai:isFriend(data.who), ai:isEnemy(data.who)
  if data.reason == "lightning_skill" or data.reason == "qiao__lightning_skill" then
    if not friendly and not hostile and not data.who.chained then return end
    if suit ~= Card.Spade or number < 2 or number > 9 then return 0 end
    return Damage.value(Damage.assess(ai, data.who, 3, fk.ThunderDamage))
  end
  if not friendly and not hostile then return end
  if data.reason == "qiao__skill_qun010_1" then
    local current = ai.room.logic:getCurrentEvent()
    local effect = current and current:findParent(GameEvent.SkillEffect, true)
    local source = effect and effect.data.who
    if (friendly and ai:isEnemy(source)) or (hostile and ai:isFriend(source)) then
      return leijiValue(ai, source, data.who, suit)
    end
    return
  end
  local success = good(data.reason, suit, number)
  if success ~= nil then return success == friendly and 1 or 0 end
end

function M.choose(ai, ghost)
  local frame = Selection.currentCost(ai.player)
  if not frame or not frame.event:isInstanceOf(fk.AskForRetrial) then return false end
  local data = frame.data
  if not data.card or not data.who then return false end
  local current = value(ai, data, data.card.suit, data.card.number)
  if current == nil then return false end
  local budget = ghost and 3 or 2
  return Cost.select(ai, 1, budget, function(id)
    -- The engine refilters this physical card for the judged player after
    -- the retrial. Hongyan changes spades there, even if the giver differs.
    local card = Fk:getCardById(id, true)
    local suit = card.suit
    if suit == Card.Spade and data.who:hasSkill("qiao__skill_wu011_2") then suit = Card.Heart end
    if suit == Card.NoSuit then return false end
    local candidate = value(ai, data, suit, card.number)
    return candidate ~= nil and candidate > current
  end)
end

return M

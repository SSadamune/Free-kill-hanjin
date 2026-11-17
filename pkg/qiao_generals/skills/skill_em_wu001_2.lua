-- EM(WU001) 孙权 · 敛资
-- 出牌阶段限一次：弃置一张牌（不限手牌），亮出牌堆顶 X 张（X 为被至少一名
-- 吴势力存活角色攻击范围覆盖的角色并集人数），获得其中与弃牌同类别且仍在
-- 处理区的牌；本次结算时若本回合得到过的牌数达到场上存活角色数，失去敛资
-- 并获得同文制衡。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local History = require "packages.qiao.pkg.qiao_generals.util.han_history"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local skill = fk.CreateSkill {
  name = P.LIANZI,
}
skill.qiaoImplemented = true

local LOST_TAG = "qiao_em_wu001_lianzi_lost"

-- 敛资属于君主武将牌；失去记录按牌保留，交换后不得重新授回。
local installed = false
local function installProviderFilter()
  if installed then return end
  installed = true
  Exchange.registerSkillProviderFilter(function(room, generalName, skillName)
    if generalName == P.LORD and skillName == P.LIANZI then
      return room:getTag(LOST_TAG) ~= true
    end
    return true
  end)
end
installProviderFilter()

--- 处于至少一名吴势力角色攻击范围内的存活、未移除角色并集人数。
local function rangeUnionCount(room)
  local covered = {}
  for _, wu in ipairs(room.alive_players) do
    if P.isWu(wu) then
      for _, target in ipairs(room.alive_players) do
        if not target.dead and not target:isRemoved() and wu:inMyAttackRange(target) then
          covered[target.id] = true
        end
      end
    end
  end
  local count = 0
  for _ in pairs(covered) do count = count + 1 end
  return count
end

--- 场上存活、未移除的角色数（“达到角色数”的判定口径）。
local function aliveCount(room)
  local count = 0
  for _, p in ipairs(room.alive_players) do
    if not p.dead and not p:isRemoved() then count = count + 1 end
  end
  return count
end

skill:addEffect("active", {
  prompt = function(self, player)
    local room = Fk:currentRoom()
    return "#qiao__skill_em_wu001_2-active:::" .. rangeUnionCount(room)
  end,
  include_equip = true,
  target_num = 0,
  max_phase_use_time = 1,
  min_card_num = 1,
  max_card_num = 1,
  card_filter = function(self, player, to_select, selected)
    return #selected < 1 and not player:prohibitDiscard(to_select)
  end,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    for _, id in ipairs(player:getCardIds("he")) do
      if not player:prohibitDiscard(id) then return true end
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cards = effect.cards or {}
    if player == nil or player.dead or #cards ~= 1 then return end
    local discarded = Fk:getCardById(cards[1], true)
    if discarded == nil then return end
    local cardType = discarded.type
    room:throwCard(cards, skill.name, player, player)
    if player.dead then return end

    local x = rangeUnionCount(room)
    if x > 0 then
      local shown = room:getNCards(x)
      room:turnOverCardsFromDrawPile(player, shown, skill.name)
      local toGet = table.filter(shown, function(id)
        local card = Fk:getCardById(id, true)
        return card ~= nil and card.type == cardType
          and room:getCardArea(id) == Card.Processing
      end)
      if #toGet > 0 then
        room:obtainCard(player, toGet, true, fk.ReasonJustMove, player, skill.name)
      end
      room:cleanProcessingArea(shown, skill.name)
    end
    if player.dead then return end
    local total = aliveCount(room)
    if total > 0 and History.count(room, player) >= total then
      room:setTag(LOST_TAG, true)
      room:handleAddLoseSkills(player, "-" .. skill.name, nil)
      room:handleAddLoseSkills(player, "qiao__skill_wu001_1", skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [P.LIANZI] = "敛资",
  [":" .. P.LIANZI] = "出牌阶段限一次，你可以弃置一张牌并亮出牌堆顶的X张牌（X为处于吴势力攻击范围内的角色数），获得其中你弃置类别的牌，若你本回合得到过的牌数达到角色数，你失去此技能并获得“制衡”。",
  ["#qiao__skill_em_wu001_2-active"] = "敛资：弃置一张牌，亮出牌堆顶%arg张牌并取得同类别牌",
}

return skill

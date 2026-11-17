-- QUN001 华佗 · 除疠
--
-- 规则基线：rules/standard-generals.md 群区 QUN001、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 选择至多三名其他角色，候选彼此不为同势力（不要求与华佗不同）；随后华佗
-- 与这些角色各弃置一张牌。按实际失去的牌判定：失去黑桃牌的角色各摸一张，
-- 判定在全部弃置完成后进行，因此后弃置的黑桃牌不会漏记。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun001_2",
}
skill.qiaoImplemented = true

local function sameKingdom(a, b)
  return a == b or H.compareKingdomWith(a, b)
end

--- 技能可用性在服务端（ServerPlayer）与客户端（ClientPlayer）都会执行：
--- 客户端走 ReqPlayCard.skillButtonValidity → ActiveSkill:canUse，而 ClientPlayer
--- 没有 room 字段，只有 ServerPlayer 才有。因此统一经 Fk:currentRoom() 取公开
--- 存活角色（核心 card.lua 的 getAvailableTargets 亦使用 room.alive_players）。
---@return ServerPlayer[]|ClientPlayer[]
local function alivePlayers()
  local room = Fk:currentRoom()
  if room == nil then return {} end
  if room.alive_players ~= nil then return room.alive_players end
  if type(room.getAlivePlayers) == "function" then return room:getAlivePlayers() end
  return {}
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_qun001_2",
  card_num = 0,
  min_target_num = 1,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryPhase) > 0 then return false end
    if player:isNude() then return false end
    -- 双方共用：不读 player.room（ClientPlayer 没有该字段），经 Fk:currentRoom()
    -- 取得客户端/服务端同源的公开存活角色列表。
    return table.find(alivePlayers(), function(p)
      return p ~= player and not p:isRemoved() and not p:isNude()
    end) ~= nil
  end,
  target_filter = function(self, player, to_select, selected)
    if to_select == player or to_select.dead or to_select:isRemoved() or to_select:isNude() then
      return false
    end
    if #selected >= 3 then return false end
    return table.every(selected, function(sel)
      return not sameKingdom(to_select, sel)
    end)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    -- 服务端复核发动条件与素材：出牌阶段、本人仍有牌、目标仍合法。
    if player.dead or player.phase ~= Player.Play then return end
    if player:isNude() then return end
    local targets = table.simpleClone(effect.tos or {})
    for i, tar in ipairs(targets) do
      if tar == player or tar.dead or tar:isRemoved() or tar:isNude() then return end
      for j = 1, i - 1 do
        if sameKingdom(tar, targets[j]) then return end
      end
    end
    if #targets == 0 then return end

    table.insert(targets, 1, player)
    room:sortByAction(targets)

    local draw = {}
    for _, tar in ipairs(targets) do
      if not tar.dead and not tar:isNude() then
        local chosen = room:askToChooseCard(player, {
          target = tar,
          flag = "he",
          skill_name = skill.name,
          prompt = "#qiao__skill_qun001_2-card::" .. tar.id,
        })
        local ids = Card:getIdList(chosen)
        local id = ids[1]
        -- 合法素材复核：牌仍在该角色的手牌/装备区，且未被禁止弃置。
        if id ~= nil and #ids == 1 and table.contains(tar:getCardIds("he"), id) then
          local card = Fk:getCardById(id)
          if card ~= nil and not tar:prohibitDiscard(card) then
            local isSpade = card.suit == Card.Spade
            room:throwCard(ids, skill.name, tar, player)
            -- 只有真实移动、确实离开该角色的牌区，才算「以此法失去」。
            local area = room:getCardArea(id)
            local lost = area ~= Card.PlayerHand and area ~= Card.PlayerEquip
            if lost and isSpade and not tar.dead then
              table.insert(draw, tar)
            end
          end
        end
      end
    end

    for _, tar in ipairs(draw) do
      if not tar.dead then
        tar:drawCards(1, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun001_2"] = "除疠",
  [":qiao__skill_qun001_2"] = "出牌阶段限一次，你可以选择至多三名不与彼此势力相同的其他角色，弃置你和这些角色各一张牌，以此法失去黑桃牌的角色各摸一张牌。",
  ["#qiao__skill_qun001_2"] = "除疠：选择至多三名彼此势力不同的其他角色，弃置你和这些角色各一张牌",
  ["#qiao__skill_qun001_2-card"] = "除疠：选择该角色的一张牌弃置",
}

return skill

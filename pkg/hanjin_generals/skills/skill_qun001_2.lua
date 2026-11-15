-- QUN001 华佗 · 除疠
--
-- 规则基线：rules/standard-generals.md 群区 QUN001、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 选择至多三名其他角色，候选彼此不为同势力（不要求与华佗不同）；随后华佗
-- 与这些角色各弃置一张牌。按实际失去的牌判定：失去黑桃牌的角色各摸一张，
-- 判定在全部弃置完成后进行，因此后弃置的黑桃牌不会漏记。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun001_2",
}
skill.hanjinImplemented = true

local function sameKingdom(a, b)
  return a == b or H.compareKingdomWith(a, b)
end

--- 跨客户端/服务端取存活角色：服务端 Room 有 getAlivePlayers，客户端房间只有
--- alive_players 字段，双方都要能跑 can_use/target_filter。
---@param room Room
---@return ServerPlayer[]|ClientPlayer[]
local function alivePlayers(room)
  if type(room.getAlivePlayers) == "function" then
    return room:getAlivePlayers()
  end
  return room.alive_players or room.players or {}
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#hanjin__skill_qun001_2",
  card_num = 0,
  min_target_num = 1,
  card_filter = Util.FalseFunc,
  can_use = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryPhase) > 0 then return false end
    if player:isNude() then return false end
    -- 服务端与客户端共用：经 alivePlayers 兼容 getAlivePlayers/alive_players，
    -- 不直接依赖只在服务端存在的房间方法或只在客户端存在的字段。
    return table.find(alivePlayers(player.room), function(p)
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
          prompt = "#hanjin__skill_qun001_2-card::" .. tar.id,
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
  ["hanjin__skill_qun001_2"] = "除疠",
  [":hanjin__skill_qun001_2"] = "出牌阶段限一次，你可以选择至多三名不与彼此势力相同的其他角色，弃置你和这些角色各一张牌，以此法失去黑桃牌的角色各摸一张牌。",
  ["#hanjin__skill_qun001_2"] = "除疠：选择至多三名彼此势力不同的其他角色，弃置你和这些角色各一张牌",
  ["#hanjin__skill_qun001_2-card"] = "除疠：选择该角色的一张牌弃置",
}

return skill

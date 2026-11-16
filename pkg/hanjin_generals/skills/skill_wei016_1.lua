-- WEI016 乐进 · 骁果
--
-- 其他角色的准备阶段，你可以弃置任意张基本牌；然后其弃置装备区等量的牌
-- （不足全弃，无牌不弃）。若你以此法弃置的基本牌多于装备牌，则你对其造成
-- 1点伤害；否则你摸一张牌。弃置基本牌是发动消耗，“任意张”须实际弃置
-- 至少一张，不能零弃牌发动。比较使用实际弃置的基本牌数与目标实际弃置的
-- 装备牌数。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei016_1",
}
skill.hanjinImplemented = true

local BASIC_PATTERN = ".|.|.|hand|.|basic"
local EQUIP_PATTERN = ".|.|.|equip"

local function basicHandIds(player)
  return table.filter(player:getCardIds(Player.Hand), function(id)
    return Fk:getCardById(id).type == Card.TypeBasic
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target ~= player and data.phase == Player.Start
      and player:hasSkill(skill.name) and target:isAlive()
      and #basicHandIds(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei016_1-invoke:" .. target.id,
    }) then
      return false
    end
    local basic = basicHandIds(player)
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = #basic,
      include_equip = false,
      pattern = BASIC_PATTERN,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei016_1-discard:::" .. #basic,
      cancelable = false,
      skip = true,
    })
    if #cards == 0 then return false end
    event:setCostData(self, { cards = cards, to = target })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local basics = cost.cards
    local to = cost.to
    if #basics == 0 or to == nil or to.dead then return end
    room:throwCard(basics, skill.name, player, player)

    local equipIds = to:getCardIds(Player.Equip)
    local discarded = {}
    local need = math.min(#basics, #equipIds)
    if need > 0 then
      if need == #equipIds then
        discarded = equipIds
      else
        discarded = room:askToDiscard(to, {
          min_num = need,
          max_num = need,
          include_equip = true,
          pattern = EQUIP_PATTERN,
          skill_name = skill.name,
          prompt = "#hanjin__skill_wei016_1-equip:::" .. need,
          cancelable = false,
          skip = true,
        })
      end
      if #discarded > 0 then
        room:throwCard(discarded, skill.name, to, player)
      end
    end

    if player.dead then return end
    if #basics > #discarded then
      if to.dead then return end
      room:damage {
        from = player,
        to = to,
        damage = 1,
        skillName = skill.name,
      }
    else
      player:drawCards(1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei016_1-invoke"] = "骁果：你可以弃置至少一张基本牌，令 %dest 弃置等量装备牌",
  ["#hanjin__skill_wei016_1-discard"] = "骁果：弃置至少一张基本牌（至多 %arg 张）",
  ["#hanjin__skill_wei016_1-equip"] = "骁果：弃置装备区 %arg 张牌",
}

return skill

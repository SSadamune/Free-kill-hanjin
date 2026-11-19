-- WEI016 乐进 · 骁果
--
-- 其他角色的准备阶段，你可以弃置任意张基本牌；然后其弃置装备区等量的牌
-- （不足全弃，无牌不弃）。若你以此法弃置的基本牌多于装备牌，则你对其造成
-- 1点伤害；否则你摸一张牌。弃置基本牌是发动消耗，“任意张”须实际弃置
-- 至少一张，不能零弃牌发动。比较使用实际弃置的基本牌数与目标实际弃置的
-- 装备牌数。
--
-- 发动确认并入这一次弃牌请求，不再另发 askToSkillInvoke：取消请求即不发动；
-- 请求返回空（没有合法成本）也不发动。被禁止弃置的基本牌不能支付消耗，也
-- 不计入可选张数和触发条件。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei016_1",
}
skill.qiaoImplemented = true

local BASIC_PATTERN = ".|.|.|hand|.|basic"
local EQUIP_PATTERN = ".|.|.|equip"

--- 手牌中可作为消耗的基本牌；不能弃置的牌不是合法成本。
---@param player ServerPlayer
---@return integer[]
local function basicHandIds(player)
  return table.filter(player:getCardIds(Player.Hand), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.type == Card.TypeBasic
      and not player:prohibitDiscard(id)
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
    local basic = basicHandIds(player)
    if #basic == 0 then return false end
    -- 提示参数位为“#键:来源:目标:参数”，%dest 取第 3 段目标；%arg 为可选张数。
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = #basic,
      include_equip = false,
      pattern = BASIC_PATTERN,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei016_1-discard:"
        .. player.id .. ":" .. target.id .. ":" .. #basic,
      cancelable = true,
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
          prompt = "#qiao__skill_wei016_1-equip:::" .. need,
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
  ["#qiao__skill_wei016_1-discard"] =
    "骁果：弃置至少一张基本牌发动（至多 %arg 张），令 %dest 弃置等量装备牌；若你弃置的基本牌多于其装备牌，你对其造成1点伤害，否则你摸一张牌",
  ["#qiao__skill_wei016_1-equip"] = "骁果：弃置装备区 %arg 张牌",
}

return skill

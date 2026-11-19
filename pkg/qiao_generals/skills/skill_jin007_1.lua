-- JIN007 王元姬 · 识人
--
-- 规则基线：docs/rules/generals/jin007-wangyuanji.md。
-- 准备阶段选择至多三名其他势力角色各一张隐藏手牌并先固定；这些角色按结算
-- 顺序各声明一个牌名。然后只展示并获得其中一张；仅将这张牌的实际牌名与其
-- 拥有者的声明比较，不同才获得其余被选择的牌。选牌阶段不展示、不提前公开。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin007_1",
}

--- 正式可声明的牌名：按 trueName 去重；冰杀/火杀/普通杀仍保留各自
--- trueName，不在比较时合并。
---@return string[]
local function declarationNames()
  local seen, ret = {}, {}
  for _, name in ipairs(Fk.all_card_names) do
    local ct = Fk.all_card_types[name]
    local declared = (ct and ct.trueName) or name
    if not seen[declared] then
      seen[declared] = true
      table.insert(ret, declared)
    end
  end
  return ret
end

--- 与王元姬势力不同的其他角色，且仍有手牌。
---@param player ServerPlayer
---@return ServerPlayer[]
local function candidates(player)
  local room = player.room
  local ret = {}
  for _, p in ipairs(room:getPresentPlayers()) do
    if p ~= player and not p.dead and not p:isRemoved() and not p:isKongcheng()
      and not H.compareKingdomWith(p, player) then
      table.insert(ret, p)
    end
  end
  return ret
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data.phase == Player.Start and #candidates(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin007_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local picked = {}
    local remaining = candidates(player)

    -- 先逐个隐藏选牌并固定；取消即停止继续选择。
    while #picked < 3 and #remaining > 0 do
      local chosen = room:askToChoosePlayers(player, {
        min_num = 1,
        max_num = 1,
        targets = remaining,
        skill_name = skill.name,
        prompt = "#qiao__skill_jin007_1-target",
        cancelable = true,
      })
      local to = chosen and chosen[1]
      if to == nil then break end
      if not to:isKongcheng() then
        local id = room:askToChooseCard(player, {
          target = to,
          flag = "h",
          skill_name = skill.name,
          prompt = "#qiao__skill_jin007_1-card",
        })
        if id ~= nil and id ~= -1 and table.contains(to:getCardIds(Player.Hand), id) then
          table.insert(picked, { owner = to, id = id, declared = nil })
        end
      end
      table.removeOne(remaining, to)
    end

    if #picked == 0 then return end

    -- 按结算顺序声明；只记录声明，不展示牌。
    local owners = table.map(picked, function(e) return e.owner end)
    room:sortByAction(owners)
    for _, owner in ipairs(owners) do
      local entry = table.find(picked, function(e) return e.owner == owner end)
      if entry ~= nil and table.contains(owner:getCardIds(Player.Hand), entry.id) then
        entry.declared = room:askToChoice(owner, {
          choices = declarationNames(),
          skill_name = skill.name,
          prompt = "#qiao__skill_jin007_1-declare",
          cancelable = false,
        })
      end
    end

    -- 只选一张展示并获得；之后再比较这张牌与其拥有者的声明。
    local valid = table.filter(picked, function(e)
      return e.declared ~= nil
        and table.contains(e.owner:getCardIds(Player.Hand), e.id)
    end)
    if #valid == 0 then return end
    local validOwners = table.map(valid, function(e) return e.owner end)
    local chosenOwner = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = validOwners,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin007_1-reveal",
      cancelable = false,
    })
    local revealEntry = table.find(valid, function(e)
      return chosenOwner ~= nil and e.owner == chosenOwner[1]
    end)
    if revealEntry == nil then return end

    local card = Fk:getCardById(revealEntry.id, true)
    if card == nil or not table.contains(revealEntry.owner:getCardIds(Player.Hand), revealEntry.id) then
      return
    end
    local actualName = card.trueName or card.name
    -- 展示与获得是两个操作：先由牌拥有者公开展示，再交给发动者。
    room:showCards(revealEntry.id, revealEntry.owner, revealEntry.owner)
    room:obtainCard(player, revealEntry.id, false, fk.ReasonPrey,
      revealEntry.owner, skill.name)

    if actualName ~= revealEntry.declared then
      for _, entry in ipairs(valid) do
        if entry ~= revealEntry and table.contains(entry.owner:getCardIds(Player.Hand), entry.id) then
          room:obtainCard(player, entry.id, false, fk.ReasonPrey, entry.owner, skill.name)
        end
      end
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin007_1-invoke"] = "识人：选择其他势力角色各一张隐藏手牌，依次声明牌名后展示并获得其中一张",
  ["#qiao__skill_jin007_1-target"] = "识人：选择一名其他势力角色（至多三名，可取消停止）",
  ["#qiao__skill_jin007_1-card"] = "识人：选择其一张手牌（不展示）",
  ["#qiao__skill_jin007_1-declare"] = "识人：声明一个牌名",
  ["#qiao__skill_jin007_1-reveal"] = "识人：选择展示并获得其中一张被选择的牌",
}

return skill

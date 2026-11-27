-- SHU023 王平 · 将略
-- 限定技，出牌阶段，你可以令所有与你势力相同的角色各加1点体力上限并回复1点体力
-- （未确定势力角色可以明置任意张与你势力相同的武将牌并执行之），
-- 你摸等同与你势力相同的角色数的牌，
-- 然后你可以交给其中任意名角色各一张牌并令其选择是否使用一张牌。
local H = require "packages.hegemony.util"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local FreeUse = require "packages.qiao.pkg.qiao_mode.rules.free_use"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu023_1",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

local GIVE_SKILL = "#qiao__skill_shu023_1_give"

local function hiddenMatchesKingdom(room, target, isDeputy, kingdom)
  local public = isDeputy and target.deputyGeneral or target.general
  if public ~= "anjiang" then return false end
  if target:prohibitReveal(isDeputy) then return false end
  if not isDeputy and target:getMark("__heg_wild") == 1 then return false end
  local actual = target:getMark(isDeputy and "__heg_deputy" or "__heg_general")
  if type(actual) ~= "string" or actual == "" then return false end
  local hegKingdom = target:getMark("__heg_kingdom")
  if type(hegKingdom) == "string" and hegKingdom ~= "" and hegKingdom ~= "unknown" then
    return hegKingdom == kingdom
  end
  local ks = Guest.generalKingdoms(room, actual)
  return type(ks) == "table" and table.contains(ks, kingdom)
end

local function askHiddenReveal(room, target, player)
  local kingdom = player.kingdom
  local choices = {}
  local mainChoice = "revealMain:::" .. tostring(target:getMark("__heg_general"))
  local deputyChoice = "revealDeputy:::" .. tostring(target:getMark("__heg_deputy"))
  if hiddenMatchesKingdom(room, target, false, kingdom) then
    table.insert(choices, mainChoice)
  end
  if hiddenMatchesKingdom(room, target, true, kingdom) then
    table.insert(choices, deputyChoice)
  end
  local prompt = #choices == 0 and "#qiao__skill_shu023_1-pass" or "#qiao__skill_shu023_1-reveal"
  if #choices == 2 then table.insert(choices, "revealAll") end
  table.insert(choices, "Cancel")
  local choice = room:askToChoice(target, {
    skill_name = skill.name,
    choices = choices,
    all_choices = choices,
    cancelable = true,
    detailed = true,
    prompt = prompt .. ":" .. player.id .. "::" .. kingdom,
  })
  if choice == mainChoice then
    target:revealGeneral(false)
  elseif choice == deputyChoice then
    target:revealGeneral(true)
  elseif choice == "revealAll" then
    target:revealGenerals()
  end
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__skill_shu023_1-prompt",
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
  end,
  card_num = 0,
  target_num = 0,
  on_use = function(self, room, effect)
    local player = effect.from
    if player.dead then return end

    -- 第一段：按王平起逆时针座次依次处理同势力角色及未确定势力角色响应亮将。
    local ordered = table.simpleClone(room:getPresentPlayers())
    room:sortByAction(ordered)
    local canRecruit = player.kingdom ~= "unknown" and player.kingdom ~= "wild"
    for _, p in ipairs(ordered) do
      if RemovedTargets.isPresent(p) then
        if p.kingdom == "unknown" and canRecruit then
          askHiddenReveal(room, p, player)
        end
        if RemovedTargets.isPresent(p) and H.compareKingdomWith(p, player) then
          room:changeMaxHp(p, 1)
          if RemovedTargets.isPresent(p) and p:isWounded() then
            room:recover {
              who = p,
              num = 1,
              recoverBy = player,
              skillName = skill.name,
            }
          end
        end
      end
    end

    -- 第二段：摸等同于此时同势力在场角色数的牌。
    if not RemovedTargets.isPresent(player) then return end
    local same = table.filter(room:getPresentPlayers(), function(p)
      return H.compareKingdomWith(p, player)
    end)
    if #same > 0 then
      player:drawCards(#same, skill.name)
    end
    if not RemovedTargets.isPresent(player) then return end

    -- 第三段：先一次性分配并同步交给任意名其他同势力角色各 1 张牌，再按座次依次询问是否使用一张牌。
    local others = table.filter(room:getPresentPlayers(), function(p)
      return p ~= player and not p:isHandAreaSealed() and H.compareKingdomWith(p, player)
    end)
    if #others == 0 or #player:getCardIds("he") == 0 then return end

    local allocations = {}
    local usedCards, usedTargets = {}, {}
    while RemovedTargets.isPresent(player) do
      local remainingCards = table.filter(player:getCardIds("he"), function(id)
        return not table.contains(usedCards, id)
      end)
      local remainingTargetIds = {}
      for _, p in ipairs(others) do
        if RemovedTargets.isPresent(p) and not table.contains(usedTargets, p.id) then
          table.insert(remainingTargetIds, p.id)
        end
      end
      if #remainingCards == 0 or #remainingTargetIds == 0 then break end
      local ok, ret = room:askToUseActiveSkill(player, {
        skill_name = GIVE_SKILL,
        prompt = "#qiao__skill_shu023_1-give",
        cancelable = true,
        extra_data = {
          skillName = skill.name,
          qiao_excluded_cards = usedCards,
          qiao_valid_targets = remainingTargetIds,
        },
      })
      if not ok or type(ret) ~= "table"
        or type(ret.cards) ~= "table" or #ret.cards ~= 1
        or type(ret.targets) ~= "table" or #ret.targets ~= 1 then
        break
      end
      local cid, dest = ret.cards[1], ret.targets[1]
      if not table.contains(remainingCards, cid) or not table.contains(remainingTargetIds, dest.id) then
        break
      end
      table.insert(usedCards, cid)
      table.insert(usedTargets, dest.id)
      table.insert(allocations, { to = dest, card = cid })
    end

    if #allocations == 0 then return end

    local moves, destinations = {}, {}
    for _, item in ipairs(allocations) do
      if RemovedTargets.isPresent(item.to) and table.contains(player:getCardIds("he"), item.card) then
        table.insert(moves, {
          ids = { item.card },
          from = player,
          to = item.to,
          toArea = Card.PlayerHand,
          moveReason = fk.ReasonGive,
          proposer = player,
          skillName = skill.name,
          moveVisible = room:getCardArea(item.card) == Card.PlayerEquip,
        })
        destinations[item.card] = item.to
      end
    end
    if #moves == 0 then return end
    local parent = room.logic:getCurrentEvent()
    local before = room.logic.current_event_id
    room:moveCards(table.unpack(moves))

    -- 以这批交牌结算后的移动记录为准。已收到又被其他效果拿走的牌仍计入。
    local recipients = {}
    local delivery = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
      return e.parent == parent
    end, before)[1]
    if not delivery or delivery.interrupted then return end
    for _, move in ipairs(delivery.data) do
      if move.from == player and move.toArea == Card.PlayerHand and move.moveReason == fk.ReasonGive
        and move.skillName == skill.name then
        for _, info in ipairs(move.moveInfo) do
          if destinations[info.cardId] == move.to then table.insertIfNeed(recipients, move.to) end
        end
      end
    end
    room:sortByAction(recipients)
    for _, recipient in ipairs(recipients) do
      if RemovedTargets.isPresent(recipient) then
        local use = FreeUse.askToUseCard(recipient, {
          skill_name = skill.name,
          prompt = "#qiao__skill_shu023_1-use",
          cancelable = true,
          extra_data = {
            bypass_times = true,
            extraUse = true,
          },
        })
        if use ~= nil then
          room:useCard(use)
        end
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "将略",
  [":" .. skill.name] = "限定技，出牌阶段，你可以令所有与你势力相同的角色各加1点体力上限并回复1点体力（未确定势力角色可以明置任意张与你势力相同的武将牌并执行之），你摸等同与你势力相同的角色数的牌，然后你可以交给其中任意名角色各一张牌并令其选择是否使用一张牌。",
  ["#qiao__skill_shu023_1-prompt"] = "将略：令同势力角色加1点体力上限并回复1点体力，随后摸牌并可分牌用牌",
  ["#qiao__skill_shu023_1-reveal"] = "将略：%src 发动了【将略】，你可以明置与 %arg 势力相同的武将牌并加入结算",
  ["#qiao__skill_shu023_1-pass"] = "将略：%src 发动了【将略】（你没有可明置加入 %arg 势力的武将牌）",
  ["#qiao__skill_shu023_1-give"] = "将略：选择一张牌与一名其他同势力角色（点取消结束分配并统一交牌）",
  ["#qiao__skill_shu023_1-use"] = "将略：你可以选择使用一张牌",
}

return skill

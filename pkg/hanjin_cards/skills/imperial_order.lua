local skill = fk.CreateSkill {
  name = "hanjin__imperial_order_skill",
}

local H = require "packages.hegemony.util"

local function doImperialOrder(room, target)
  local all_choices = { "imperial_order_reveal", "imperial_order_discard", "loseHp" }
  local choices = table.clone(all_choices)
  if target.hp < 1 then table.remove(choices) end
  if table.every(target:getCardIds("he"), function(id)
    return Fk:getCardById(id).type ~= Card.TypeEquip or target:prohibitDiscard(Fk:getCardById(id))
  end) then
    table.remove(choices, 2)
  end
  if (target.general ~= "anjiang" or target:prohibitReveal())
    and (target.deputyGeneral ~= "anjiang" or target:prohibitReveal(true)) then
    table.remove(choices, 1)
  end
  if #choices == 0 then return false end
  local choice = room:askToChoice(target, {
    choices = choices,
    skill_name = skill.name,
    all_choices = all_choices,
  })
  if choice == "imperial_order_reveal" then
    H.askToRevealGenerals(target, {
      skill_name = skill.name,
      revealAll = false,
      cancelable = false,
    })
    target:drawCards(1, skill.name)
  elseif choice == "imperial_order_discard" then
    room:askToDiscard(target, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = ".|.|.|.|.|equip",
      cancelable = false,
    })
  else
    room:loseHp(target, 1, skill.name)
  end
end

skill:addEffect("cardskill", {
  prompt = "#hanjin__imperial_order_skill",
  can_use = Util.CanUseFixedTarget,
  mod_target_filter = function(self, player, to_select)
    return to_select.kingdom == "unknown"
  end,
  on_effect = function(self, room, effect)
    doImperialOrder(room, effect.to)
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and target.room:getBanner("ImperialOrderRemoved-turn")
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    for _, p in ipairs(room:getAlivePlayers()) do
      if p.kingdom == "unknown" then doImperialOrder(room, p) end
    end
  end,
})

skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player.seat == 1 then
      for _, move in ipairs(data) do
        if move.toArea == Card.DiscardPile and move.moveReason ~= fk.ReasonUse then
          for _, info in ipairs(move.moveInfo) do
            if Fk:getCardById(info.cardId).name == "hanjin__imperial_order" then
              return true
            end
          end
        end
      end
    end
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local ids = {}
    local mirror_moves = {}
    for _, move in ipairs(data) do
      if move.toArea == Card.DiscardPile and move.moveReason ~= fk.ReasonUse then
        local move_info = {}
        local mirror_info = {}
        for _, info in ipairs(move.moveInfo) do
          local id = info.cardId
          if Fk:getCardById(id).name == "hanjin__imperial_order" then
            table.insert(mirror_info, info)
            table.insert(ids, id)
          else
            table.insert(move_info, info)
          end
        end
        if #mirror_info > 0 then
          move.moveInfo = move_info
          local mirror_move = move:copy()
          mirror_move.to = nil
          mirror_move.toArea = Card.Void
          mirror_move.moveInfo = mirror_info
          mirror_move.moveVisible = true
          mirror_move.moveReason = fk.ReasonJustMove
          table.insert(mirror_moves, mirror_move)
        end
      end
    end
    if #ids > 0 then
      room:sendLog { type = "#ImperialOrderRemoved", card = ids }
      room:setBanner("ImperialOrderRemoved-turn", true)
    end
    table.insertTable(data, mirror_moves)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__imperial_order_skill"] = "敕令",
  ["#hanjin__imperial_order_skill"] = "所有没有势力的角色选择：1.明置一张武将牌，摸一张牌；2.弃置一张装备牌；3.失去1点体力",
}

return skill

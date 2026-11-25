-- JIN003 司马昭 · 昭然
--
-- 规则基线：docs/rules/generals/jin003-simazhao.md。
-- 出牌阶段开始时发动：本阶段自己的手牌对所有角色持续可见（之后获得的手牌也
-- 可见）；每种花色首次失去最后的手牌后，可摸一张或弃其他角色一张牌。阶段事实
-- 与可见按 -phase 标记清理；同花色已失去事实不因重新获得而重开。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Deck = require "packages.qiao.pkg.qiao_generals.util.jin_deck"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin003_1",
}

local OPEN = Visibility.ZHAORAN_OPEN
local DISPLAY = "@qiao_zhaoran-phase"
local LOST = "qiao_jin003_1_lost_suits-phase"
local OPT_DRAW = "qiao__skill_jin003_1-draw"
local OPT_DISCARD = "qiao__skill_jin003_1-discard"

local function handCountOfSuit(player, suit)
  local n = 0
  for _, id in ipairs(player:getCardIds(Player.Hand)) do
    if Fk:getCardById(id).suit == suit then n = n + 1 end
  end
  return n
end

--- 本事件中首次失去最后手牌的花色（尚未记录过）。
---@return integer[]
local function newlyLostSuits(player, data)
  local lost = player:getTableMark(LOST)
  local seen, ret = {}, {}
  for _, move in ipairs(data or {}) do
    if move.from == player then
      for _, info in ipairs(move.moveInfo or {}) do
        if info.fromArea == Card.PlayerHand then
          -- 优先使用移动前的牌面快照，避免牌已进入处理区后读取区域/身份。
          local card = info.beforeCard or Fk:getCardById(info.cardId, true)
          local suit = card and card.suit
          local validSuit = suit == Card.Spade or suit == Card.Heart
            or suit == Card.Club or suit == Card.Diamond
          if validSuit and not table.contains(lost, suit) and not seen[suit]
            and handCountOfSuit(player, suit) == 0 then
            seen[suit] = true
            table.insert(ret, suit)
          end
        end
      end
    end
  end
  return ret
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data.phase == Player.Play
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin003_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, OPEN, 1)
    player.room:setPlayerMark(player, DISPLAY, " ")
  end,
})

skill:addEffect("visibility", Visibility.zhaoran)

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  global = true,
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:getMark(OPEN) > 0
      and #newlyLostSuits(player, data) > 0
  end,
  -- 后续效果已是“且你……”的必然效果，不再询问是否发动/取消。
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    -- 同一事件先固定并记录全部首次花色；任何摸牌/弃牌前完成，防重入与
    -- 摸回同色导致事实丢失。
    local suits = newlyLostSuits(player, data)
    for _, suit in ipairs(suits) do
      room:addTableMarkIfNeed(player, LOST, suit)
    end
    room:setPlayerMark(player, DISPLAY, Deck.suitSymbols(player:getTableMark(LOST)))
    for _, suit in ipairs(suits) do
      if player.dead then return end
      local others = table.filter(room:getPresentPlayers(), function(p)
        return p ~= player and not p:isNude() and not p:isRemoved()
      end)
      local choices = { OPT_DRAW }
      if #others > 0 then table.insert(choices, OPT_DISCARD) end
      local choice = Selection.askOption(room, player, {
        choices = choices,
        all_choices = { OPT_DRAW, OPT_DISCARD },
        skill_name = skill.name,
        prompt = "#qiao__skill_jin003_1-choice",
        cancelable = false,
      })
      if choice == OPT_DRAW then
        player:drawCards(1, skill.name)
      else
        local chosen = room:askToChoosePlayers(player, {
          min_num = 1,
          max_num = 1,
          targets = others,
          skill_name = skill.name,
          prompt = "#qiao__skill_jin003_1-discard-target",
          cancelable = false,
        })
        local to = chosen and chosen[1]
        if to ~= nil and not to:isNude() then
          local id = room:askToChooseCard(player, {
            target = to,
            flag = "he",
            skill_name = skill.name,
            prompt = "#qiao__skill_jin003_1-discard-card",
          })
          if id ~= nil and id ~= -1 then
            room:throwCard({ id }, skill.name, to, player)
          end
        end
      end
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  [DISPLAY] = "昭然",
  [OPT_DRAW] = "摸一张牌",
  [OPT_DISCARD] = "弃置其他角色一张牌",
  ["#qiao__skill_jin003_1-invoke"] = "昭然：本阶段你的手牌公开，并在每种花色首次失去最后手牌后选择一项",
  ["#qiao__skill_jin003_1-choice"] = "昭然：请选择一项",
  ["#qiao__skill_jin003_1-discard-target"] = "昭然：选择弃置一张牌的其他角色",
  ["#qiao__skill_jin003_1-discard-card"] = "昭然：选择弃置其一张牌",
}

return skill

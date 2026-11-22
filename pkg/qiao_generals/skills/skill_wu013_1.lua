-- WU013 周泰 · 不屈
--
-- 锁定技，当周泰进入濒死时：
--   1. 摸 X 张牌（X 为本回合进入濒死的次数，含本次）；
--   2. 将自己的手牌或装备区一张牌置于武将牌上，称为“创”；
--   3. 同花色有多张“创”时，由周泰选择保留哪一张，移去其余同花色“创”；
--   4. 若本次没有移去任何牌，改为回复体力至 1 点。
-- “无须移去”以放牌并处理同花色后的实际结果为准。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local H = require "packages.hegemony.util"
local skill = fk.CreateSkill {
  name = "qiao__skill_wu013_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local DYING_COUNT = "qiao__skill_wu013_1_dying-turn"
local CHUANG = "创"
skill.qiao_piles_kept_when_hidden = { CHUANG }
local SUIT_ORDER = { Card.Spade, Card.Heart, Card.Club, Card.Diamond, Card.NoSuit }

skill:addLoseEffect(function(self, player, isDeath)
  if isDeath or #player:getPile(CHUANG) == 0 then return end -- 死亡时由掩埋处理所有牌堆。
  for _, deputy in ipairs({ false, true }) do
    if not Exchange.isRevealed(player, deputy)
      and Exchange.cardProvidesSkill(player.room, Exchange.actualGeneral(player, deputy), skill.name) then
      return
    end
  end
  if not player:hasSkill(skill.name, true, true) then Exchange.discardPilesKeptWhenHidden(player, skill.name) end
end)

-- 暗将被直接替换、或另有来源继续授予不屈时，移将仍要清理原牌上的创。
local leavingGeneral = {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if target ~= player or #player:getPile(CHUANG) == 0 then return false end
    if event == H.GeneralRemoved then
      return Exchange.cardProvidesSkill(player.room, data.origName, skill.name)
    end
    local results = data.results or {}
    for _, field in ipairs({ "generalChange", "deputyChange" }) do
      local change = results[field]
      if change then
        local old = change[1]
        if old == "anjiang" then
          old = player:getMark(field == "generalChange" and "__heg_general" or "__heg_deputy")
        end
        if old ~= change[2] and Exchange.cardProvidesSkill(player.room, old, skill.name) then return true end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player)
    Exchange.discardPilesKeptWhenHidden(player, skill.name)
  end,
}

--- 对同花色多于一张的“创”逐一询问保留哪一张，移去其余。
---@return integer 移去的张数
local function dedupeChuang(room, player)
  local bySuit = {}
  for _, id in ipairs(player:getPile(CHUANG)) do
    local card = Fk:getCardById(id)
    local suit = card and card.suit or Card.NoSuit
    bySuit[suit] = bySuit[suit] or {}
    table.insert(bySuit[suit], id)
  end

  local remove = {}
  for _, suit in ipairs(SUIT_ORDER) do
    local ids = bySuit[suit]
    if ids ~= nil and #ids > 1 then
      local keep = ids[1]
      if not player.dead then
        local chosen = room:askToCards(player, {
          min_num = 1,
          max_num = 1,
          expand_pile = ids,
          pattern = tostring(Exppattern { id = ids }),
          skill_name = skill.name,
          prompt = "#qiao__skill_wu013_1-keep",
          cancelable = false,
        })
        if chosen ~= nil and chosen[1] ~= nil and table.contains(ids, chosen[1]) then
          keep = chosen[1]
        end
      end
      for _, id in ipairs(ids) do
        if id ~= keep then table.insert(remove, id) end
      end
    end
  end

  if #remove > 0 then
    room:moveCardTo(remove, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      skill.name, nil, true)
  end
  return #remove
end

skill:addEffect(fk.EnterDying, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = player:getMark(DYING_COUNT) + 1
    room:setPlayerMark(player, DYING_COUNT, x)

    player:drawCards(x, skill.name)
    if player.dead then return end

    -- “一张牌”默认自己的牌：手牌区或装备区，不限于手牌。
    local owned = player:getCardIds("he")
    if #owned > 0 then
      local card = room:askToCards(player, {
        include_equip = true, min_num = 1, max_num = 1, cancelable = false,
        skill_name = skill.name,
        prompt = "#qiao__skill_wu013_1-place",
      })[1]
      if card ~= nil and card ~= -1 and table.contains(player:getCardIds("he"), card) then
        room:moveCardTo({ card }, Card.PlayerSpecial, player, fk.ReasonPut,
          skill.name, CHUANG, true, player)
      end
    end

    if player.dead then return end
    local removed = dedupeChuang(room, player)
    if removed == 0 and player.hp < 1 then
      room:recover {
        who = player,
        num = 1 - player.hp,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

skill:addEffect(fk.AfterPropertyChange, leavingGeneral)
skill:addEffect(H.GeneralRemoved, leavingGeneral)

Fk:loadTranslationTable {
  ["qiao__skill_wu013_1"] = "不屈",
  [":qiao__skill_wu013_1"] = "锁定技，当你进入濒死时，你摸X张牌（X为你本回合濒死的次数），将一张牌置于武将牌上，称为“创”，然后移去至每种花色各一张，无须移去则改为回复体力至1点。",
  ["#qiao__skill_wu013_1-place"] = "不屈：将一张手牌或装备牌置于武将牌上，称为“创”",
  ["#qiao__skill_wu013_1-keep"] = "不屈：选择保留哪一张同花色“创”",
  [CHUANG] = CHUANG,
}

return skill

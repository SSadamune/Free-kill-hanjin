-- WEI002 司马懿 · 鹰视
--
-- 规则基线：rules/standard-generals.md WEI002。当一名角色的判定牌生效前，你
-- 可以打出一张自己的手牌或装备牌代替之。
-- 与普通“鬼才”不同，可用牌包含装备区的牌，不限于手牌。改判必须先真实完成
-- “打出”：现有 changeJudge{response=true} 只移牌、不产生 CardRespond 事件，
-- 因此顺序为 responseCard（skipDrop，避免默认弃置）→ 复核牌已在处理区 →
-- changeJudge 替换。禁止打出的牌不能选；同一判定只替换一次。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei002_2",
}

local function playableIds(player)
  local ids = {}
  for _, id in ipairs(table.simpleClone(player:getCardIds("he"))) do
    local card = Fk:getCardById(id)
    if card ~= nil and not player:prohibitResponse(card) then
      table.insert(ids, id)
    end
  end
  return ids
end

skill:addEffect(fk.AskForRetrial, {
  can_trigger = function(self, event, target, player, data)
    if data == nil or data.__hanjin_wei002_2_retrial then return false end
    return player:hasSkill(skill.name) and #playableIds(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei002_2-invoke",
    }) then
      return false
    end
    local ids = playableIds(player)
    local equip = table.filter(player:getCardIds("e"), function(id)
      return table.contains(ids, id)
    end)
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      pattern = tostring(Exppattern { id = ids }),
      prompt = "#hanjin__skill_wei002_2-ask",
      expand_pile = equip,
      cancelable = false,
    })
    if cards == nil or #cards ~= 1 then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local id = event:getCostData(self).cards[1]
    local card = Fk:getCardById(id)
    if card == nil or data.__hanjin_wei002_2_retrial then return end
    data.__hanjin_wei002_2_retrial = true

    -- 先完成真实打出（进入处理区），skipDrop 防止其被默认弃置。
    room:responseCard { from = player, card = card, skipDrop = true }
    if room:getCardArea(id) ~= Card.Processing then return end

    -- 再用改判接口替换判定牌，避免重复结算。
    room:changeJudge {
      card = card,
      player = player,
      data = data,
      skillName = skill.name,
      response = true,
    }
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei002_2"] = "鹰视",
  [":hanjin__skill_wei002_2"] = "当一名角色的判定牌生效前，你可以打出一张牌代替之。",
  ["#hanjin__skill_wei002_2-invoke"] = "鹰视：是否打出一张牌代替判定牌？",
  ["#hanjin__skill_wei002_2-ask"] = "鹰视：打出一张手牌或装备牌",
}

skill.hanjinImplemented = true
return skill

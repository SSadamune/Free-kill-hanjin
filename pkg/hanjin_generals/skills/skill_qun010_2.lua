-- QUN010 张角 · 鬼道
--
-- 规则基线：rules/standard-generals.md 群区 QUN010、rules/generals/qun010-zhangjiao.md。
-- 判定牌生效前打出一张黑色牌替换之；「替换」意味着获得原判定牌，与鹰视的
-- 「代替」不同。可用牌为手牌或装备牌。
-- 顺序：先真实完成打出（responseCard 进入处理区，skipDrop 避免被默认弃置），
-- 再用 changeJudge 替换判定牌。changeJudge 的 response=true 只指定移动原因，
-- 不产生完整的打出事件，所以不能省略前面的 responseCard；exchange=true 才会
-- 把原判定牌交给改判者。
local skill = fk.CreateSkill {
  name = "hanjin__skill_qun010_2",
}
skill.hanjinImplemented = true

local RETRIAL_MARK = "__hanjin_qun010_2_retrial"

--- 可打出的黑色牌：手牌区或装备区，排除禁止打出的牌。
---@param player ServerPlayer
---@return integer[]
local function playableIds(player)
  local ids = {}
  for _, id in ipairs(table.simpleClone(player:getCardIds("he"))) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.color == Card.Black and not player:prohibitResponse(card) then
      table.insert(ids, id)
    end
  end
  return ids
end

skill:addEffect(fk.AskForRetrial, {
  can_trigger = function(self, event, target, player, data)
    if data == nil or data[RETRIAL_MARK] then return false end
    return player:hasSkill(skill.name) and #playableIds(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_qun010_2-invoke",
    }) then
      return false
    end
    local ids = playableIds(player)
    if #ids == 0 then return false end
    local equip = table.filter(player:getCardIds("e"), function(id)
      return table.contains(ids, id)
    end)
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      pattern = tostring(Exppattern { id = ids }),
      prompt = "#hanjin__skill_qun010_2-ask",
      expand_pile = equip,
      cancelable = false,
    })
    if cards == nil or #cards ~= 1 then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local id = (event:getCostData(self) or {}).cards[1]
    local card = Fk:getCardById(id)
    if card == nil or data[RETRIAL_MARK] then return end
    data[RETRIAL_MARK] = true

    -- 真实打出：进入处理区，skipDrop 避免它被当作普通打出牌弃置。
    room:responseCard { from = player, card = card, skipDrop = true }
    if room:getCardArea(id) ~= Card.Processing then return end

    -- 替换判定牌并获得原判定牌（exchange=true）。
    room:changeJudge {
      card = card,
      player = player,
      data = data,
      skillName = skill.name,
      response = true,
      exchange = true,
    }
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_qun010_2"] = "鬼道",
  [":hanjin__skill_qun010_2"] = "当一张判定牌生效前，你可以打出一张黑色牌替换之。",
  ["#hanjin__skill_qun010_2-invoke"] = "鬼道：是否打出一张黑色牌替换判定牌并获得原判定牌？",
  ["#hanjin__skill_qun010_2-ask"] = "鬼道：打出一张黑色手牌或装备牌",
}

return skill

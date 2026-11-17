-- SHU021 糜夫人 · 存嗣
-- 每轮各限一次：回合内使用【杀】后，或回合外使用【桃】后，可以获得该牌。
-- 只取仍在处理区的实体材料；纯虚拟牌无实体材料时不复制生成。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu021_3",
}
skill.qiaoImplemented = true

local SLASH_ROUND = "qiao__skill_shu021_3-slash-round"
local PEACH_ROUND = "qiao__skill_shu021_3-peach-round"

local function roundNo(player)
  return player.room:getBanner("RoundCount") or 0
end

-- mark 默认 0 与首轮 RoundCount 0 不能相等，使用 +1 哨兵。
local function roundMark(player)
  return roundNo(player) + 1
end

local function processingIds(room, card)
  if card == nil then return {} end
  return table.filter(Card:getIdList(card), function(id)
    return room:getCardArea(id) == Card.Processing
  end)
end

local function branchFor(player, card)
  if card == nil then return nil end
  local current = player.room.current
  local name = card.trueName or card.name
  if name == "slash" and current == player then return "slash", SLASH_ROUND end
  if name == "peach" and current ~= player then return "peach", PEACH_ROUND end
  return nil
end

skill:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or data == nil or data.card == nil then return false end
    if not player:hasSkill(skill.name) then return false end
    local branch, mark = branchFor(player, data.card)
    if branch == nil then return false end
    if player:getMark(mark) == roundMark(player) then return false end
    return #processingIds(player.room, data.card) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu021_3-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local branch, mark = branchFor(player, data.card)
    if branch == nil then return end
    local ids = processingIds(room, data.card)
    if #ids == 0 then return end
    room:setPlayerMark(player, mark, roundMark(player))
    local card = Fk:cloneCard(data.card.name, data.card.suit, data.card.number)
    card:addSubcards(ids)
    room:obtainCard(player, card, true, fk.ReasonPrey, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu021_3"] = "存嗣",
  [":qiao__skill_shu021_3"] = "每轮各限一次，当你于回合内使用【杀】后/回合外使用【桃】后，你可以获得之。",
  ["#qiao__skill_shu021_3-invoke"] = "存嗣：你可以获得此牌",
}

return skill

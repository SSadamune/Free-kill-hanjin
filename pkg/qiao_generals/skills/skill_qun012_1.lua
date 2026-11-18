-- QUN012 蔡文姬 · 悲歌
--
-- 当一名角色受到【杀】造成的伤害后，你可以弃置一张牌，然后令其判定：
--   红桃：其回复1点体力；方片：其摸两张牌；
--   梅花：来源弃置两张牌；黑桃：来源叠置。
-- 弃牌者为蔡文姬，判定者为受伤角色；判定走正式 judge 流程（鬼道可改判）。
-- “【杀】造成的伤害”按伤害牌当前实际牌名判断，转化【杀】同样成立。
-- 叠置是定向操作：仅平置→叠置，已叠置不翻回（见 skill_wei014_2 放逐）。
--
-- 发动确认并入这一次弃牌请求，不再另发 askToSkillInvoke：取消请求即不发动，
-- 请求未返回一张牌也不发动。提示保留判定者。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun012_1",
}
skill.qiaoImplemented = true

local J = require "packages.qiao.pkg.qiao_generals.util.qun_judgement"

--- 判定结果分支：红桃回复、方片摸牌、梅花来源弃两张、黑桃来源叠置。
---@param room Room
---@param target ServerPlayer 受伤角色（判定者）
---@param from ServerPlayer? 伤害来源
---@param card Card
local function resolveJudge(room, target, from, card)
  if card == nil then return end
  if card.suit == Card.Heart then
    if not target.dead then
      room:recover { who = target, num = 1, skillName = skill.name }
    end
  elseif card.suit == Card.Diamond then
    if not target.dead then target:drawCards(2, skill.name) end
  elseif card.suit == Card.Club then
    if from == nil or from.dead then return end
    local count = #from:getCardIds("he")
    if count > 0 then
      local num = math.min(2, count)
      room:askToDiscard(from, {
        min_num = num,
        max_num = num,
        include_equip = true,
        skill_name = skill.name,
        prompt = "#qiao__skill_qun012_1-discard",
        cancelable = false,
      })
    end
  elseif card.suit == Card.Spade then
    J.stack(from)
  end
end

skill:addEffect(fk.Damaged, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and player ~= nil
      and player:hasSkill(skill.name) and not player.dead
      and not target.dead and not target:isRemoved()
      and data ~= nil and data.card ~= nil and data.card.trueName == "slash"
      and #player:getCardIds("he") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 弃牌请求本身即发动确认；取消请求即不发动。
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun012_1-discard-self:" .. target.id,
      cancelable = true,
    })
    if cards == nil or #cards < 1 then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local card = J.judge(room, target, skill.name)
    resolveJudge(room, target, data.from, card)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun012_1"] = "悲歌",
  [":qiao__skill_qun012_1"] = "当一名角色受到【杀】造成的伤害后，你可以弃置一张牌，然后令其判定，若为：红桃，其回复1点体力；方片，其摸两张牌；梅花，来源弃置两张牌；黑桃，来源叠置。",
  ["#qiao__skill_qun012_1-discard-self"] = "悲歌：弃置一张牌发动，令 %src 判定",
  ["#qiao__skill_qun012_1-discard"] = "悲歌：弃置两张牌",
}

return skill

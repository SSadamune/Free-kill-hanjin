-- QUN008 庞德 · 猛撼
--
-- 规则基线：rules/standard-generals.md 群区 QUN008、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 使用【杀】指定一个目标后，弃置该目标一张手牌或装备牌：
--   * 弃置的是基本牌：该目标获得本次【杀】可获得的实体牌。只移动真实
--     实体牌（转化牌的 subcards 由 obtainCard 处理），不终止已声明的用牌，
--     后续目标仍照常结算。
--   * 弃置的不是基本牌：仅该目标不能响应此【杀】，其他目标不受影响。
-- 「不能被其响应」使用与锁定烈勇相同的 AimData:setDisresponsive 接口。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun008_2",
}
skill.qiaoImplemented = true

local function discardableTarget(player, data)
  local to = data.to
  if to == nil or to == player or to.dead or to:isRemoved() then return nil end
  if #to:getCardIds("he") == 0 then return nil end
  return to
end

skill:addEffect(fk.TargetSpecified, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    return discardableTarget(player, data) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local to = discardableTarget(player, data)
    if to == nil then return false end
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_qun008_2-invoke",
    }) then
      return false
    end
    local chosen = room:askToChooseCard(player, {
      target = to,
      flag = "he",
      skill_name = skill.name,
      prompt = "#qiao__skill_qun008_2-ask::" .. to.id,
    })
    local ids = Card:getIdList(chosen)
    if #ids ~= 1 or not table.contains(to:getCardIds("he"), ids[1]) then return false end
    event:setCostData(self, { to = to, id = ids[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to, id = cost.to, cost.id
    if to == nil or id == nil or to.dead or to:isRemoved() then return end
    if not table.contains(to:getCardIds("he"), id) then return end
    local card = Fk:getCardById(id)
    if card == nil then return end
    local isBasic = card.type == Card.TypeBasic
    room:throwCard({ id }, skill.name, to, player)
    if isBasic then
      -- 其获得此【杀】：移动本次使用可获得的实体牌，不改变本次用牌的结算。
      if data.card ~= nil and not to.dead then
        room:obtainCard(to, data.card, true, fk.ReasonJustMove, player, skill.name)
      end
    else
      data:setDisresponsive(to)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun008_2"] = "猛撼",
  [":qiao__skill_qun008_2"] = "当你使用【杀】指定一个目标后，你可以弃置其一张牌，若为基本牌，则其获得此【杀】，否则此【杀】不能被其响应。",
  ["#qiao__skill_qun008_2-invoke"] = "猛撼：是否弃置该目标一张牌？",
  ["#qiao__skill_qun008_2-ask"] = "猛撼：选择该目标一张手牌或装备牌弃置",
}

return skill

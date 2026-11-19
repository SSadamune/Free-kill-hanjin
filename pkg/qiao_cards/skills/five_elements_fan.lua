-- 五行鹤翎扇：你可以将一张属性【杀】当任意一种其他属性【杀】使用。
--
-- 规则基线：docs/rules/card-deck.md「普通锦囊与装备的审阅结论 · 五行鹤翎扇」及
-- 《势备应变牌堆差异》「只能在属性【杀】之间互转。这是真正的转化，不是
-- 【朱雀羽扇】那种『改为火【杀】』」。
--   * 真正转化的 ViewAs：一张实体属性【杀】作为转化材料被实际使用；结果牌是
--     带该实体牌为 subcard 的虚拟牌，不采用“已宣告使用后再改牌”的后置替换。
--   * 只在出牌阶段或“使用牌”请求中可选；打出/响应窗口不提供。
--   * 材料须为单张实体属性【杀】；已经转化出的虚拟牌不能作为材料。
--   * 结果属性不能与材料属性相同；同一属性的不同程序牌型不重复作为选项。
local skill = fk.CreateSkill {
  name = "qiao__five_elements_fan_skill",
  attached_equip = "qiao__five_elements_fan",
}

Fk:loadTranslationTable {
  ["qiao__five_elements_fan_skill"] = "五行鹤翎扇",
  ["#qiao__five_elements_fan-prompt"] = "五行鹤翎扇：将一张属性【杀】当另一种属性【杀】使用",
  ["#qiao__five_elements_fan-choose"] = "五行鹤翎扇：选择转化后的属性【杀】",
}

-- 每种属性只登记一个正式程序牌型。七张实体雷杀共用同一个雷杀程序牌型，
-- 不再按实体牌位拆分，转化结果也只有一种雷杀。
local RESULT_CARDS = {
  fire = "qiao__fire__slash",
  thunder = "qiao__thunder__slash",
  ice = "qiao__ice__slash",
}
local ATTRIBUTE_ORDER = { "fire", "thunder", "ice" }

--- 属性【杀】的属性；普通【杀】与无属性牌不算属性杀。
---@param card Card?
---@return string?
local function slashAttribute(card)
  if card == nil or card.trueName ~= "slash" then return nil end
  local damage = card.damage_type
  if damage == fk.FireDamage then return "fire" end
  if damage == fk.ThunderDamage then return "thunder" end
  if damage == fk.IceDamage then return "ice" end
  return nil
end

--- 结果牌名对应的属性。
---@param name string?
---@return string?
local function nameAttribute(name)
  for _, attribute in ipairs(ATTRIBUTE_ORDER) do
    if RESULT_CARDS[attribute] == name then return attribute end
  end
  return nil
end

--- 可作为材料的实体牌：手牌及如手牌般可用的实体牌中的单张属性【杀】。
--- 已转化的虚拟牌没有实体 id，不会进入这里。
local function materialIds(player)
  return table.filter(player:getHandlyIds(true), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and not card:isVirtual() and slashAttribute(card) ~= nil
  end)
end

--- 以实体材料与目标属性构造转化结果牌（虚拟牌，登记该实体为子牌）。
local function buildCard(materialId, attribute)
  local name = RESULT_CARDS[attribute]
  if name == nil then return nil end
  local card = Fk:cloneCard(name)
  card.skillName = skill.name
  card:addSubcard(materialId)
  return card
end

--- 当前窗口中可选的转化目标属性。只有存在“属性不同且本次可合法用出”的实体
--- 材料时才作为可选项；不可用属性仍列入 all_choices 以说明被排除的原因。
local function targetChoices(player)
  local choices, all_choices = {}, {}
  local ids = materialIds(player)
  for _, attribute in ipairs(ATTRIBUTE_ORDER) do
    table.insert(all_choices, RESULT_CARDS[attribute])
    for _, id in ipairs(ids) do
      local material = Fk:getCardById(id)
      if slashAttribute(material) ~= attribute then
        local card = buildCard(id, attribute)
        if card ~= nil and player:canUseOrResponseInCurrent(card) then
          table.insert(choices, RESULT_CARDS[attribute])
          break
        end
      end
    end
  end
  return choices, all_choices
end

--- 校验一次转化：单张实体材料、材料为属性【杀】、结果属性与材料不同。
local function validConversion(player, targetName, cards)
  local attribute = nameAttribute(targetName)
  if attribute == nil or #cards ~= 1 then return nil end
  local material = Fk:getCardById(cards[1])
  if material == nil or material:isVirtual() then return nil end
  local source = slashAttribute(material)
  if source == nil or source == attribute then return nil end
  return attribute, material
end

skill:addEffect("viewas", {
  anim_type = "offensive",
  pattern = table.concat({
    RESULT_CARDS.fire, RESULT_CARDS.thunder, RESULT_CARDS.ice,
  }, ","),
  prompt = "#qiao__five_elements_fan-prompt",
  handly_pile = true,
  interaction = function(self, player)
    local choices, all_choices = targetChoices(player)
    if #choices == 0 then return nil end
    return UI.CardNameBox { choices = choices, all_choices = all_choices }
  end,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    local targetName = self.interaction and self.interaction.data
    local attribute = nameAttribute(targetName)
    if attribute == nil then return false end
    local material = Fk:getCardById(to_select)
    if material == nil or material:isVirtual() then return false end
    local source = slashAttribute(material)
    if source == nil or source == attribute then return false end
    local card = buildCard(to_select, attribute)
    return card ~= nil and player:canUseOrResponseInCurrent(card)
  end,
  view_as = function(self, player, cards)
    local targetName = self.interaction and self.interaction.data
    if validConversion(player, targetName, cards) == nil then return nil end
    return buildCard(cards[1], nameAttribute(targetName))
  end,
  -- 服务端复核：回复只带材料与选项，结果牌在服务端重建，材料与结果必须真实对应。
  before_use = function(self, player, use)
    if use == nil or use.card == nil then return skill.name end
    local targetName = self.interaction and self.interaction.data
    if use.card.name ~= targetName then return skill.name end
    if validConversion(player, targetName, Card:getIdList(use.card)) == nil then
      return skill.name
    end
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #(targetChoices(player)) > 0
  end,
  -- 只对“使用牌”请求开放；打出/响应窗口不提供。
  enabled_at_response = function(self, player, response)
    return not response and #(targetChoices(player)) > 0
  end,
})

return skill

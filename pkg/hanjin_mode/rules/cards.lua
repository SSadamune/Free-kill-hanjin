local M = {}
-- These are independent HanJin identities and deck policies, not implemented card effects.
M.equipment = {}
M.tricks = {}

function M.registerEquipment(name, kingdom, replacement)
  assert(table.contains({ "wei", "shu", "wu", "qun", "han", "jin" }, kingdom), "Invalid equipment kingdom")
  assert(type(name) == "string" and (replacement == nil or type(replacement) == "string"), "Invalid equipment replacement")
  M.equipment[name] = { kingdom = kingdom, replacement = replacement }
end

M.registerEquipment("hanjin__liulongcanjia", "wei", "hanjin__zhuahuangfeidian")
M.registerEquipment("hanjin__dragon_phoenix", "shu", "hanjin__double_swords")
M.registerEquipment("hanjin__luminous_pearl", "wu", "hanjin__six_swords")
M.registerEquipment("hanjin__peace_spell", "qun", "hanjin__jingfan")
M.registerEquipment("hanjin__chixiao_sword", "han", nil)
M.registerEquipment("hanjin__linxiao_yuyu", "jin", "hanjin__jueying")
-- The engine currently stores one sub_type; the eventual card must implement the
-- two mount-slot semantics explicitly, as upstream liulongcanjia does.
M.equipment.hanjin__linxiao_yuyu.subtypes = { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide }

function M.registerTrick(name, kingdom)
  assert(table.contains({ "wei", "shu", "wu", "qun", "han", "jin" }, kingdom), "Invalid trick kingdom")
  M.tricks[name] = kingdom
end

M.registerTrick("hanjin__command_world", "wei")
M.registerTrick("hanjin__restore_heartland", "shu")
M.registerTrick("hanjin__strengthen_state", "wu")
M.registerTrick("hanjin__luanwu_chaos", "qun")

function M.apply(room, draw, void, banned)
  local result, removed, replacements = {}, {}, {}
  void = table.simpleClone(void)
  -- Active lord equipment occupies the matching ordinary deck slot, never all copies of that name.
  local suppressed = {}
  for _, id in ipairs(draw) do
    local card = Fk:getCardById(id)
    local spec = M.equipment[card.name]
    if spec and spec.replacement and not table.contains(banned, spec.kingdom) then
      local ordinary = table.find(draw, function(candidate)
        local c = Fk:getCardById(candidate)
        return not suppressed[candidate] and c.name == spec.replacement
          and c.suit == card.suit and c.number == card.number
      end)
      if ordinary then suppressed[ordinary] = true; table.insertIfNeed(void, ordinary) end
    end
  end
  local used = {}
  for _, id in ipairs(draw) do
    local card = Fk:getCardById(id)
    local spec = M.equipment[card.name]
    local kingdom = spec and spec.kingdom or M.tricks[card.name]
    if suppressed[id] then
      -- The independent special equipment already occupies this slot.
    elseif kingdom and table.contains(banned, kingdom) then
      table.insertIfNeed(void, id)
      table.insert(removed, id)
      if spec and spec.replacement then
        local alreadyInDraw = table.find(draw, function(candidate)
          local c = Fk:getCardById(candidate)
          return not used[candidate] and c.name == spec.replacement and c.suit == card.suit and c.number == card.number
        end)
        local replacement = table.find(void, function(candidate)
          local c = Fk:getCardById(candidate)
          return not used[candidate] and c.name == spec.replacement and c.suit == card.suit and c.number == card.number
        end)
        if alreadyInDraw then
          replacement = alreadyInDraw
        elseif replacement then
          table.removeOne(void, replacement)
        else
          -- A custom deck may omit the matching ordinary copy. Print a room-local copy.
          local prototype = assert(Fk.all_card_types[spec.replacement], "Missing independent replacement: " .. spec.replacement)
          assert(prototype.package.extensionName == "hanjin", "Replacement must be an independent HanJin card")
          replacement = room:printCard(spec.replacement, card.suit, card.number).id
        end
        used[replacement] = true
        if not alreadyInDraw then table.insert(result, replacement) end
        table.insert(replacements, { from = id, to = replacement })
      end
    else
      table.insert(result, id)
    end
  end
  room:setBanner("hanjin_banned_cards", removed)
  room:setBanner("hanjin_card_replacements", replacements)
  return result, void
end

return M

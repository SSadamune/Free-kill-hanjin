local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_shu036_1" }
local PRIVATE = "qiao_yuexian_request"
local function blocked(p, card)
  local mark = p.tag and p.tag[PRIVATE] or nil
  if not mark then mark = p:getMark(PRIVATE) end
  if type(mark) ~= "table" then return false end
  local ids = Card:getIdList(card)
  return #ids == 0 or not table.every(ids, function(id) return table.contains(mark, id) end)
end
skill:addEffect("prohibit", { prohibit_use = function(self, p, card) return blocked(p, card) end,
  prohibit_response = function(self, p, card) return blocked(p, card) end })
for _, timing in ipairs({ fk.TargetSpecified, fk.TargetConfirmed }) do
  skill:addEffect(timing, {
    can_trigger = function(self, event, target, p, data)
      return target == p and p:hasSkill(skill.name) and data.card.trueName == "slash" and S.present(data.to)
    end,
    on_cost = function(self, event, target, p, data)
      local to, choices = data.to, { "1" }
      if to:getHandcardNum() < 2 then table.insert(choices, "2") end
      if not to:isWounded() then table.insert(choices, "0") end
      table.insert(choices, "Cancel")
      local n = tonumber(p.room:askToChoice(p, {
        skill_name = skill.name,
        choices = choices,
        prompt = "#qiao_yuexian-choice::" .. to.id,
      }))
      event:setCostData(self, { n = n })
      return n ~= nil
    end,
    on_use = function(self, event, target, p, data)
      local n = event:getCostData(self).n
      local ids = n > 0 and data.to:drawCards(n, skill.name) or {}
      local limits = data.use.qiao_yuexian or {}
      if limits[data.to.id] then ids = table.filter(ids, function(id) return table.contains(limits[data.to.id], id) end) end
      limits[data.to.id] = ids
      data.use.qiao_yuexian = limits
    end,
  })
end

-- 同一杀的每个目标有独立的应答窗口。嵌套询问结束时恢复原窗口。
local function setWindow(p, mark)
  p.tag[PRIVATE] = mark
  if p._splayer:getState() ~= fk.Player_Robot then
    p._splayer:doNotify("SetPlayerMark", cbor.encode { p.id, PRIVATE, mark or 0 })
  end
end
function skill.install(room)
  for _, name in ipairs({ "askToUseCard", "askToResponse" }) do
    local original = room[name]
    room[name] = function(self, p, params)
      local ev = self.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
      local effect = params.event_data
      local ids = ev and effect and ev.data.card == effect.card and ev.data.qiao_yuexian and ev.data.qiao_yuexian[p.id]
      local previous = p.tag[PRIVATE]
      if not ids and not previous then return original(self, p, params) end
      setWindow(p, ids)
      local ok, result = pcall(original, self, p, params)
      if ok and ids and result and result.card and blocked(p, result.card) then result = nil end
      setWindow(p, previous)
      if not ok then error(result, 0) end
      return result
    end
  end
end

Fk:loadTranslationTable {
  ["#qiao_yuexian-choice"] = "越险：令 %dest 摸所选张数的牌，其只能用因此摸到的牌响应此【杀】",
}

return skill

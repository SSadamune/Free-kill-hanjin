local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_xiangbing",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_xiangbing"] = "象兵",
  [":hanjin__retinue_skill_xiangbing"] = "锁定技，当你使用【杀】后，你视为对受到此【杀】伤害的目标角色使用一张【南蛮入侵】；当你受到火焰伤害后，你视为对所有相邻角色使用一张【杀】。",
}

-- 使用【杀】后，按本次实际受到此杀伤害的目标集合，一次多目标视为南蛮。
skill:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    return data.card ~= nil and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    local tos = {}
    for to, num in pairs(data.damageDealt or {}) do
      if num > 0 and to:isAlive() and not to:isRemoved() and table.contains(data.tos, to) then
        table.insert(tos, to)
      end
    end
    if #tos == 0 then return end
    C.useVirtualCard(room, player, "hanjin__savage_assault", nil, tos, skill.name, true, nil,
      C.explicit({ other_roles = true },
        { names = { "hanjin__savage_assault" }, min_targets = #tos, max_targets = #tos }))
  end,
})

-- 受到火焰伤害后，按座次取相邻合法角色，一次多目标视为杀，不因攻击范围丢目标。
skill:addEffect(fk.DamageFinished, {
  can_trigger = function(self, event, target, player, data)
    return data.to == player and data.damageType == fk.FireDamage and player:hasSkill(skill.name)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead then return end
    local seats = room.players
    local index
    for i, p in ipairs(seats) do
      if p == player then index = i break end
    end
    if index == nil then return end
    local tos, seen = {}, {}
    for _, step in ipairs({ -1, 1 }) do
      local i = index
      for _ = 1, #seats do
        i = i + step
        if i < 1 then i = #seats elseif i > #seats then i = 1 end
        local p = seats[i]
        if p:isAlive() and not p:isRemoved() and p ~= player then
          if not seen[p] then
            seen[p] = true
            table.insert(tos, p)
          end
          break
        end
      end
    end
    if #tos == 0 then return end
    C.useVirtualCard(room, player, "hanjin__slash", nil, tos, skill.name, true, nil,
      C.explicit({ other_roles = true },
        { names = { "hanjin__slash" }, min_targets = #tos, max_targets = #tos }))
  end,
})

return skill

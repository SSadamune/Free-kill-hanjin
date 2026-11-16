-- 汉晋国战：暗将八阵的“需要闪时发动”入口。
--
-- 八阵是锁定技，暗将阶段其技能为假技能；只有预亮后才进入房间触发技表。
-- 仅靠玩家手动明置将使八阵无法在需要【闪】的请求中出现。这里在开局及回合
-- 开始时为暗置的 SHU011 预亮八阵（不移除假技能、不明置武将），之后由八阵
-- 自身的 AskForCardUse/AskForCardResponse 在需要【闪】时询问并明置。
-- 只处理八阵这一个暗将入口，不改变其他技能或明置规则。
local skill = fk.CreateSkill { name = "hanjin__shu_hidden_prelight" }

local BAZHEN = "hanjin__skill_shu011_1"
local GENERAL = "hanjin__shu011"

local function prelight(player)
  if player == nil or player.dead then return end
  local mainHidden = player.general == "anjiang"
    and player:getMark("__heg_general") == GENERAL
  local deputyHidden = player.deputyGeneral == "anjiang"
    and player:getMark("__heg_deputy") == GENERAL
  if not (mainHidden or deputyHidden) then return end
  if player:hasSkill(BAZHEN) then return end
  player:prelightSkill(BAZHEN, true)
end

skill:addEffect(fk.GamePrepared, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player == player.room.players[1]
  end,
  on_refresh = function(self, event, target, player)
    for _, p in ipairs(player.room.players) do prelight(p) end
  end,
})

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    prelight(player)
  end,
})

-- 再次暗置后立即恢复可询问的暗将入口，不等待该角色下个回合。
skill:addEffect(fk.GeneralHidden, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    prelight(player)
  end,
})

return skill

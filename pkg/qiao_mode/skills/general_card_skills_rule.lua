-- 将牌后天技能来源：预注册独立来源技能 + 明暗/交换/死亡同步规则。
local G = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local H = require "packages.hegemony.util"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"
local Array = require "packages.qiao.pkg.qiao_mode.rules.array_summon"

Fk:addPostLoadFunc(SameName.register)
G.addChangeListener(Array.sync)

local skill = fk.CreateSkill { name = "qiao__general_card_skills_rule" }

skill:addAuxActiveSkill(G.SOURCE, {can_use=Util.FalseFunc,on_use=function() end})
local spec = {
  global = true,
  can_refresh = function(self, event, target, player)
    return event==fk.GameStart and player.seat==1 or target==player
  end,
  on_refresh = function(self, event, target, player)
    G.sync(player.room)
  end,
}

skill:addEffect(fk.GameStart, spec)
skill:addEffect(fk.GeneralShown, {
  global = true, late_refresh = true, can_refresh = spec.can_refresh, on_refresh = spec.on_refresh,
})
skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.GeneralHidden, spec)
skill:addEffect(fk.Death, spec)
local Markers = require "packages.qiao.pkg.qiao_mode.rules.marker_cards"
skill:addAuxActiveSkill(Markers.DIRECT, { can_use = Util.FalseFunc, on_use = function() end })

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player) return player.seat == 1 end,
  on_refresh = function(self, event, target, player, moves) Markers.afterMove(player.room, moves) end,
})

skill:addEffect(fk.AfterPropertyChange, {
  global = true, can_refresh = spec.can_refresh,
  on_refresh = function(self, event, target, player, data)
    for field, mark in pairs({ generalChange = "__heg_general", deputyChange = "__heg_deputy" }) do
      local change = data.results and data.results[field]
      if change and change[2] ~= "anjiang" and change[1] ~= change[2] then
        local old = change[1] == "anjiang" and player:getMark(mark) or change[1]
        if old and old ~= change[2] then Markers.endCard(player.room, old) end
      end
    end
    G.sync(player.room)
  end,
})

skill:addEffect(H.GeneralRemoved, {
  global = true, can_refresh = spec.can_refresh,
  on_refresh = function(self, event, target, player, data)
    if data.origName then Markers.endCard(player.room, data.origName) end
    G.sync(player.room)
  end,
})
skill:addEffect(H.GeneralTransformed, spec)
skill:addEffect(H.PlayerRemoved, spec)

return skill

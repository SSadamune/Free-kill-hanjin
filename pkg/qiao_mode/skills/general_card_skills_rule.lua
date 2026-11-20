-- 将牌后天技能来源：预注册独立来源技能 + 明暗/交换/死亡同步规则。
local G = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local H = require "packages.hegemony.util"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"

Fk:addPostLoadFunc(SameName.register)

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
skill:addEffect(fk.AfterPropertyChange,spec)
skill:addEffect(H.GeneralRemoved,spec)
skill:addEffect(H.GeneralTransformed, spec)
skill:addEffect(H.PlayerRemoved, spec)

return skill

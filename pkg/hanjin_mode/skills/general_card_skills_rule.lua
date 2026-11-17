-- 将牌后天技能来源：预注册独立来源技能 + 明暗/交换/死亡同步规则。
local G = require "packages.hanjin.pkg.hanjin_mode.rules.general_card_skills"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill { name = "hanjin__general_card_skills_rule" }

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
skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.GeneralHidden, spec)
skill:addEffect(fk.Death, spec)
skill:addEffect(fk.AfterPropertyChange,spec)
skill:addEffect(H.GeneralRemoved,spec)
skill:addEffect(H.GeneralTransformed, spec)
skill:addEffect(H.PlayerRemoved, spec)

return skill

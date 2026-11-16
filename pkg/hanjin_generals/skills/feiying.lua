-- 飞影：每个独立来源使其他角色计算与你的距离+1。
--
-- 鹤翼通过 zhen_shi_formation 的固定预注册来源技能授予本技能：同一目标
-- 有两份鹤翼来源时距离+2，撤一份后+1；外部原有飞影另算一层。层数在服务端
-- 读真实派生来源，在 ClientPlayer 读公开层数 mark。
local F = require "packages.hanjin.pkg.hanjin_generals.util.zhen_shi_formation"

local skill = fk.CreateSkill {
  name = "hanjin__feiying",
  tags = { Skill.Compulsory },
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    local layers = F.feiyingLayers(to)
    if layers > 0 then return layers end
  end,
})

-- 外部独立来源取得/失去飞影时也刷新公开层数，客户端随之更新。
local function refreshLayers(room)
  F.refreshLayers(room)
end

local spec = {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and player.room ~= nil and target == player
  end,
  on_refresh = function(self, event, target, player)
    refreshLayers(player.room)
  end,
}

skill:addEffect(fk.EventAcquireSkill, spec)
skill:addEffect(fk.EventLoseSkill, spec)

Fk:loadTranslationTable {
  ["hanjin__feiying"] = "飞影",
  [":hanjin__feiying"] = "锁定技，其他角色计算与你的距离+1。",
}

return skill

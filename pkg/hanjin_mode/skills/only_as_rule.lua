local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local H = require "packages.hegemony.util"

-- 汉晋房间的页面规则：同步来源、记录当前请求模式、复核直接使用/打出，
-- 并在上游鏖战技能被添加时改为汉晋来源。所有效果只在汉晋房间加载。
local skill = fk.CreateSkill {
  name = O.RULE_SKILL,
  tags = { Skill.Compulsory },
}

local function refresh(room)
  O.refresh(room)
end

local function initialize(room)
  -- GamePrepared/GameStart 可能先后触发；只在首次初始化时清理，避免把其它
  -- 初始化技能已登记的来源抹掉。
  if not room:getTag(O.INIT_TAG) then
    O.reset(room)
    room:setTag(O.INIT_TAG, true)
  end
  O.refresh(room)
end

-- 这些触发技因为 global 会进入所有房间的触发表；因此每个入口都必须先
-- 确认本房间是汉晋国战，不能把汉晋的“只能当”规则带到普通国战房间。
local function inHanjin(player)
  return player ~= nil and player.room ~= nil
    and player.room:getSettings("gameMode") == "hanjin_heg_mode"
end

-- GamePrepared 初始化测试房间与真实房间的内部来源记录；GameStart 再次
-- 执行同一幂等操作，避免不同引擎版本只触发其中一个时机。
skill:addEffect(fk.GamePrepared, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and inHanjin(player)
  end,
  on_refresh = function(self, event, target, player)
    initialize(player.room)
  end,
})
skill:addEffect(fk.GameStart, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and inHanjin(player)
  end,
  on_refresh = function(self, event, target, player)
    initialize(player.room)
  end,
})

-- 请求模式栈。before_use 与 PreCardUse/PreCardRespond 的服务端复核读取栈顶。
skill:addEffect(fk.AskForCardUse, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player) and data ~= nil
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    O.pushRequest(player.room, player, "use", data.pattern, data.extraData)
  end,
})
skill:addEffect(fk.AskForCardResponse, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player) and data ~= nil
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    O.pushRequest(player.room, player, "response", data.pattern, data.extraData)
  end,
})
skill:addEffect(fk.AfterAskForCardUse, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = -100,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    if data == nil or type(data.result) ~= "table" then
      O.clearAuthorization(player.room, player)
    end
    O.popRequest(player.room)
  end,
})
skill:addEffect(fk.AfterAskForCardResponse, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = -100,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    if data == nil or type(data.result) ~= "table" then
      O.clearAuthorization(player.room, player)
    end
    O.popRequest(player.room)
  end,
})

-- 移动后立即撤销临时取牌授权，即使牌之后回到原牌区也不能复活旧授权。
skill:addEffect(fk.AfterCardsMove, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and inHanjin(player)
  end,
  on_refresh = function(self, event, target, player, data)
    for _, move in ipairs(data) do
      for _, info in ipairs(move.moveInfo) do
        O.clearAuthorizationById(player.room, info.cardId)
      end
    end
  end,
})

-- 直接实体牌（任何牌区）与伪造的汉晋转化牌都在使用/打出生效前复核。
skill:addEffect(fk.PreCardUse, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player) and data ~= nil and data.card ~= nil
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local request = O.currentRequest(room)
    if not O.validateCardUse(room, player, data, "use", {
      mode = "use", pattern = request and request.pattern,
    }) then
      return true
    end
  end,
})
skill:addEffect(fk.PreCardRespond, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player, data)
    return target == player and inHanjin(player) and data ~= nil and data.card ~= nil
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local request = O.currentRequest(room)
    if not O.validateCardUse(room, player, data, "response", {
      mode = "response", pattern = request and request.pattern,
    }) then
      return true
    end
  end,
})

-- 上游鏖战技能的接管在 #hanjin_battle_royal_rule 中处理。

skill:addEffect(fk.TurnStart, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_trigger = function(self, event, target, player)
    return target == player and inHanjin(player)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    O.advanceTurn(player.room)
  end,
})
skill:addEffect(fk.RoundStart, {
  global = true,
  mute = true,
  is_delay_effect = true,
  priority = 10,
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and inHanjin(player)
  end,
  on_refresh = function(self, event, target, player)
    refresh(player.room)
  end,
})

local function refreshTrigger(self, event, target, player)
  if target == player then refresh(player.room) end
end

skill:addEffect(fk.GeneralShown, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = refreshTrigger,
})
skill:addEffect(fk.GeneralHidden, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = refreshTrigger,
})
skill:addEffect(H.GeneralRemoved, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = refreshTrigger,
})
skill:addEffect(fk.AfterPropertyChange, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = refreshTrigger,
})
skill:addEffect(fk.Death, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = refreshTrigger,
})
skill:addEffect(fk.EventLoseSkill, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = refreshTrigger,
})
skill:addEffect(fk.TurnEnd, {
  global = true,
  mute = true,
  can_trigger = function(self, event, target, player) return target == player and inHanjin(player) end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    O.clearAuthorization(player.room, player)
    O.expireTurn(player.room)
    refresh(player.room)
  end,
})

Fk:loadTranslationTable {
  [O.RULE_SKILL] = "牌用途规则",
  ["#hanjin_only_as_choose"] = "选择用途",
  [O.PROHIBIT_SKILL] = "牌用途限制",
}

return skill

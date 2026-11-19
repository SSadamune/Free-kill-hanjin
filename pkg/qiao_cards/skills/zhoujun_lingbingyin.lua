-- 州郡领兵印：进入装备区后按装备者当前的大／小势力类别逐人询问同类别角色
-- 是否交一张自己的手牌或装备；准备阶段可建立本回合摸牌/出杀/手牌上限修正。
-- 准备阶段的修正由独立房间触发器保留，失去装备后仍持续到本回合结束。
local skill = fk.CreateSkill {
  name = "qiao__zhoujun_lingbingyin_skill",
  attached_equip = "qiao__zhoujun_lingbingyin",
}

local DRAW = "qiao_zhoujun_draw"
local SLASH = "qiao_zhoujun_slash"
local HAND = "qiao_zhoujun_hand"

local function addMark(player, mark, value)
  player.room:setPlayerMark(player, mark, value)
end

local function slashLimit(player)
  local maxUse = Fk.skills["slash_skill"]:getMaxUseTime(
    player, Player.HistoryPhase, Fk:cloneCard("slash"))
  return maxUse or 1
end

--- 引擎只在 DrawNCards 事件内暴露本次额定摸牌数；准备阶段没有公共 getter。
--- 当前基数取游戏流程默认 2，其他效果在摸牌事件内的特别修正无法提前得知。
local function drawCount(player)
  return 2
end

local function canMinus(player, key, amount)
  amount = amount or 1
  if key == "draw" then return drawCount(player) >= amount end
  if key == "slash" then return slashLimit(player) >= amount end
  return player:getMaxCards() >= amount
end

--- 生成准备阶段可选的增减组合，扣减不得超过对应基数。
local function optionsFor(player)
  local result = {}
  local function add(draw, slash, hand, minus1, amount1, minus2, amount2)
    if not canMinus(player, minus1, amount1) then return end
    if minus2 ~= nil and not canMinus(player, minus2, amount2) then return end
    table.insert(result, { draw = draw, slash = slash, hand = hand })
  end
  -- +2 的三种合法分配：另外两项各 -1，或任一项足额 -2。
  add(2, -1, -1, "slash", 1, "hand", 1)
  add(2, -2, 0, "slash", 2)
  add(2, 0, -2, "hand", 2)
  add(1, -1, 0, "slash", 1)
  add(1, 0, -1, "hand", 1)
  add(-1, 2, -1, "draw", 1, "hand", 1)
  add(-2, 2, 0, "draw", 2)
  add(0, 2, -2, "hand", 2)
  add(-1, 1, 0, "draw", 1)
  add(0, 1, -1, "hand", 1)
  add(-1, -1, 2, "draw", 1, "slash", 1)
  add(-2, 0, 2, "draw", 2)
  add(0, -2, 2, "slash", 2)
  add(-1, 0, 1, "draw", 1)
  add(0, -1, 1, "slash", 1)
  return result
end

--- 只接受与服务端合法组合完全一致的数值；取消、超时、非法回复均不产生修正。
local function optionFromReply(options, reply)
  if type(reply) ~= "table" then return nil end
  local draw, slash, hand = tonumber(reply.draw), tonumber(reply.slash), tonumber(reply.hand)
  if draw == nil or slash == nil or hand == nil then return nil end
  return table.find(options, function(option)
    return option.draw == draw and option.slash == slash and option.hand == hand
  end)
end

local function askPrepare(player)
  local room = player.room
  local options = optionsFor(player)
  if #options == 0 then return end
  -- AI 或离线/无客户端时 CustomDialog 返回空串，不能回退到任意组合。
  local reply = room:askToCustomDialog(player, {
    skill_name = skill.name,
    component = {
      url = "packages/qiao/pkg/qiao_mode/qml/ZhoujunValueBox.qml",
      prop = {
        options = options,
        prompt = "#qiao__zhoujun-prepare",
      },
    },
  })
  local option = optionFromReply(optionsFor(player), reply)
  if option == nil then return end
  addMark(player, DRAW, option.draw)
  addMark(player, SLASH, option.slash)
  addMark(player, HAND, option.hand)
end

-- 准备阶段：三项修正建立在本回合，独立于装备是否仍在。
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and data.phase == Player.Start
      and player:hasSkill(skill.name) and #optionsFor(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__zhoujun-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    askPrepare(player)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "州郡领兵印",
  ["#qiao__zhoujun-invoke"] = "州郡领兵印：是否调整本回合的摸牌、出杀与手牌上限",
  ["#qiao__zhoujun-prepare"] = "州郡领兵印：调整三项增减值",
  ["#qiao__zhoujun-give"] = "州郡领兵印：是否交给 %dest 一张自己的手牌或装备",
  ["#qiao__zhoujun-choose"] = "州郡领兵印：选择一张自己的手牌或装备交出",
}

return skill

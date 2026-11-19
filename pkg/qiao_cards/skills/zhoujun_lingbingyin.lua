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

--- 生成准备阶段可选的增量组合。+2 时另外两项各 -1；+1 时选择一个其他项 -1。
local function optionsFor(player)
  local result = {}
  local function add(key, draw, slash, hand, minus1, amount1, minus2, amount2)
    if not canMinus(player, minus1, amount1) then return end
    if minus2 ~= nil and not canMinus(player, minus2, amount2) then return end
    table.insert(result, { key = key, draw = draw, slash = slash, hand = hand })
  end
  -- +2 的三种合法分配：另外两项各 -1，或任一项足额 -2。
  add("#qiao__zhoujun-draw2", 2, -1, -1, "slash", 1, "hand", 1)
  add("#qiao__zhoujun-draw2-slash2", 2, -2, 0, "slash", 2)
  add("#qiao__zhoujun-draw2-hand2", 2, 0, -2, "hand", 2)
  add("#qiao__zhoujun-draw1-slash", 1, -1, 0, "slash", 1)
  add("#qiao__zhoujun-draw1-hand", 1, 0, -1, "hand", 1)
  add("#qiao__zhoujun-slash2", -1, 2, -1, "draw", 1, "hand", 1)
  add("#qiao__zhoujun-slash2-draw2", -2, 2, 0, "draw", 2)
  add("#qiao__zhoujun-slash2-hand2", 0, 2, -2, "hand", 2)
  add("#qiao__zhoujun-slash1-draw", -1, 1, 0, "draw", 1)
  add("#qiao__zhoujun-slash1-hand", 0, 1, -1, "hand", 1)
  add("#qiao__zhoujun-hand2", -1, -1, 2, "draw", 1, "slash", 1)
  add("#qiao__zhoujun-hand2-draw2", -2, 0, 2, "draw", 2)
  add("#qiao__zhoujun-hand2-slash2", 0, -2, 2, "slash", 2)
  add("#qiao__zhoujun-hand1-draw", -1, 0, 1, "draw", 1)
  add("#qiao__zhoujun-hand1-slash", 0, -1, 1, "slash", 1)
  return result
end

local function askPrepare(player)
  local room = player.room
  local options = optionsFor(player)
  if #options == 0 then return end
  local labels = {}
  local byKey = {}
  for _, option in ipairs(options) do
    table.insert(labels, option.key)
    byKey[option.key] = option
  end
  local chosen = room:askToChoice(player, {
    choices = labels,
    skill_name = skill.name,
    prompt = "#qiao__zhoujun-prepare",
  })
  local option = byKey[chosen]
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
  ["#qiao__zhoujun-prepare"] = "州郡领兵印：选择一项增量及扣减分配",
  ["#qiao__zhoujun-give"] = "州郡领兵印：是否交给 %dest 一张自己的手牌或装备",
  ["#qiao__zhoujun-choose"] = "州郡领兵印：选择一张自己的手牌或装备交出",
  ["#qiao__zhoujun-draw2"] = "摸牌+2，出杀-1，手牌上限-1",
  ["#qiao__zhoujun-draw2-slash2"] = "摸牌+2，出杀-2",
  ["#qiao__zhoujun-draw2-hand2"] = "摸牌+2，手牌上限-2",
  ["#qiao__zhoujun-draw1-slash"] = "摸牌+1，出杀-1",
  ["#qiao__zhoujun-draw1-hand"] = "摸牌+1，手牌上限-1",
  ["#qiao__zhoujun-slash2"] = "出杀+2，摸牌-1，手牌上限-1",
  ["#qiao__zhoujun-slash2-draw2"] = "出杀+2，摸牌-2",
  ["#qiao__zhoujun-slash2-hand2"] = "出杀+2，手牌上限-2",
  ["#qiao__zhoujun-slash1-draw"] = "出杀+1，摸牌-1",
  ["#qiao__zhoujun-slash1-hand"] = "出杀+1，手牌上限-1",
  ["#qiao__zhoujun-hand2"] = "手牌上限+2，摸牌-1，出杀-1",
  ["#qiao__zhoujun-hand2-draw2"] = "手牌上限+2，摸牌-2",
  ["#qiao__zhoujun-hand2-slash2"] = "手牌上限+2，出杀-2",
  ["#qiao__zhoujun-hand1-draw"] = "手牌上限+1，摸牌-1",
  ["#qiao__zhoujun-hand1-slash"] = "手牌上限+1，出杀-1",
}

return skill

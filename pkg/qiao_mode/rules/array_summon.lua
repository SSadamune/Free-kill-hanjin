-- 汉晋阵法召唤。来源同步只发布明置将牌上的阵法技；选择亮将只在服务端进行。
local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = { skill = "qiao__array_summon" }

local sourcesMark = "qiao_array_summon_sources"
local types = {
  qiao__skill_wei018_2 = "formation", -- 曹洪·鹤翼
  qiao__skill_shu012_2 = "formation", -- 姜维·天覆
  qiao__skill_qun024_2 = "formation", -- 张任·龙飞
  qiao__skill_han014_2 = "siege",     -- 朱儁·虎翼
  qiao__skill_wu017_2 = "siege",      -- 蒋钦·鸟翔
  qiao__skill_jin023_2 = "siege",     -- 马隆·锥形
}

function M.sync(room)
  if not Modes.inRoom(room) then return end
  for _, player in ipairs(room.players) do
    local sources = {}
    for _, deputy in ipairs({false, true}) do
      if Exchange.isRevealed(player, deputy) then
        local general = Exchange.publicGeneral(player, deputy)
        for _, name in ipairs(Exchange.positionSkills(general, deputy, false, false, room)) do
          if types[name] and Exchange.cardProvidesSkill(room, general, name) then
            table.insertIfNeed(sources, name)
          end
        end
      end
    end
    local previous = player:getTableMark(sourcesMark)
    if table.concat(previous, "|") ~= table.concat(sources, "|") then
      room:setPlayerMark(player, sourcesMark, #sources > 0 and sources or 0)
      if (#previous == 0) ~= (#sources == 0) then
        room:handleAddLoseSkills(player, #sources > 0 and M.skill or "-" .. M.skill, nil, false, true)
      end
    end
  end
end

local function canRecruit(room, player)
  if player.dead or player:isRemoved() or player.kingdom == "unknown" or player.kingdom == "wild" then
    return false
  end
  -- 首次明置的势力人数含死亡和暂时移出的角色。十人局第五人起转野。
  local count = 0
  local limit = #room.players == 10 and 4 or #room.players // 2
  for _, other in ipairs(room.players) do
    if other.kingdom == player.kingdom then count = count + 1 end
  end
  return count < limit
end

-- 每次从发动者沿当前座次重新寻找，亮将引起的移出、死亡或势力变化即时生效。
local function candidate(player, kind, step)
  local other = step(player)
  if kind == "siege" then
    if not H.compareKingdomWith(player, other, true) then return end
    other = step(other)
  else
    while other ~= player and H.compareKingdomWith(player, other) do
      other = step(other)
    end
  end
  if other ~= player and other.kingdom == "unknown" then return other end
end

local directions = {
  function(p) return p:getNextAlive() end,
  function(p) return p:getLastAlive() end,
}

-- 点击前后两端共用的公开查询，全暗角色选了哪两张将牌不影响按钮。
function M.choices(room, player)
  local choices = {}
  if room.current ~= player or player.phase ~= Player.Play or not canRecruit(room, player) then return choices end
  for _, source in ipairs(player:getTableMark(sourcesMark)) do
    local kind = types[source]
    if player:hasShownSkill(source) and not table.contains(choices, kind)
      and (candidate(player, kind, directions[1]) or candidate(player, kind, directions[2])) then
      table.insert(choices, kind)
    end
  end
  return choices
end

local function respond(room, target, player, kind)
  -- 国战 revealGeneral 依选将时已确定的本局势力亮将，客将沿用同一结果。
  -- 野心家主将明置会立即转野，只有单亮副将能加入发动者的队列或围攻。
  local choices = {}
  local main = "revealMain:::" .. target:getMark("__heg_general")
  local deputy = "revealDeputy:::" .. target:getMark("__heg_deputy")
  if target:getMark("__heg_kingdom") == player.kingdom then
    if target.general == "anjiang" and target:getMark("__heg_wild") ~= 1 and not target:prohibitReveal() then
      table.insert(choices, main)
    end
    if target.deputyGeneral == "anjiang" and not target:prohibitReveal(true) then
      table.insert(choices, deputy)
    end
  end
  local prompt = #choices == 0 and "#qiao_array_pass" or "#qiao_array_respond_" .. kind
  if #choices == 2 then table.insert(choices, "revealAll") end
  table.insert(choices, "Cancel")
  -- 上游 askToRevealGenerals 使用不可取消的请求，超时可能随机亮将。
  -- 公开座次命中的人均收到私有选择，以免公开的思考读条泄露暗将势力。
  local choice = room:askToChoice(target, {
    skill_name = M.skill, choices = choices, all_choices = choices, cancelable = true,
    prompt = prompt .. ":" .. player.id,
  })
  if choice == main then target:revealGeneral(false)
  elseif choice == deputy then target:revealGeneral(true)
  elseif choice == "revealAll" then target:revealGenerals()
  else return false end
  return H.compareKingdomWith(target, player)
end

function M.resolve(room, player)
  local choices = M.choices(room, player)
  if #choices == 0 then return end
  local kind = choices[1]
  if #choices > 1 then
    local labels = table.map(choices, function(value) return "qiao_array_" .. value end)
    local choice = room:askToChoice(player, {choices = labels, skill_name = M.skill, prompt = "#qiao_array_choose"})
    if not table.contains(labels, choice) then return end
    kind = choice:sub(#"qiao_array_" + 1)
  end
  local asked = {}
  for _, step in ipairs(directions) do
    while canRecruit(room, player) do
      local target = candidate(player, kind, step)
      if not target or asked[target] then break end
      asked[target] = true
      if not respond(room, target, player, kind) or kind == "siege" then break end
    end
  end
end

return M

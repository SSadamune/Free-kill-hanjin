-- 广覆盖：正式武将/翼从及旗授予技能的主动按钮查询，必须使用真实 ClientPlayer。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ActiveSkillLimits = require "packages.qiao.pkg.qiao_mode.rules.active_skill_limits"

local YONGLIANG = "qiao__skill_han015_1"   -- 效果声明：出牌阶段限一次
local FENYUE = "qiao__skill_han013_1"      -- 骨架声明：函数（席面势力数）
local POZHU = "qiao__skill_jin006_2"       -- 效果声明：函数（三陈复原数）
local CRUISE = "qiao__skill_jin017_2"      -- 限定技：本局限一次


local EXPECTED_TRUE = {
  ["qiao__skill_wei013_1"] = true,
  ["qiao__skill_jin006_1"] = true,
  ["qiao__skill_wei011_1"] = true,
  ["qiao__skill_wei012_1"] = true,
  ["qiao__gongxin"] = true,
}

-- 不由正式武将持有、但会授予角色的主动技能（如《缘江烽火图》授予的攻心），
-- 仍须走同一条真实客户端按钮与点击入口。
local GRANTED_ACTIVE = { "qiao__gongxin" }

local EXPECTED_FALSE_SELF = {
  ["qiao__skill_wei013_1"] = true,
  ["qiao__skill_wei011_1"] = true,
  ["qiao__skill_wei012_1"] = true,
}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

--- 正式客户端的普通出牌请求类：由 board.client_klass 注册的 QiaoPlayCard。
local function qiaoPlayCardClass()
  local board = assert(Fk:getBoardGame("qiao_heg_mode"))
  local client = board.client_klass:new(ClientInstance.client)
  return client.request_handlers.PlayCard
end

--- 服务端按正常出牌回包（params == nil）入口执行。
local function serverReply(room, player, skillName, targets, cards)
  return room:handleUseCardReply(
    player, FkTest.ReplyUseSkill(skillName, targets or {}, cards or {}), nil)
end

Testqiao_client_active_skills = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, { "wei", "jin", "wu", "shu", "qun", "han", "jin", "wei" })
      room.current = room.players[1]
      room.players[1].phase = Player.Play
      room.players[1].hp = 2
      room.players[2].hp = 4
      for _, who in ipairs({ room.players[1], room.players[2] }) do
        local c = room:printCard("qiao__jink", Card.Heart, 2)
        room:obtainCard(who, c, false, fk.ReasonJustMove)
      end
    end)
  end,
  tearDown = support.clearRoom,
}

function Testqiao_client_active_skills:testAllFormalSkillButtonsUseClientRoom()
  local room = FkTest.room
  local names = {}
  for id, general in pairs(Fk.generals) do
    if id:startsWith("qiao_heg__") then
      for _, skill in ipairs(general:getSkillNameList()) do
        local sk = Fk.skills[skill]
        if sk ~= nil and (sk:isInstanceOf(ActiveSkill) or sk:isInstanceOf(ViewAsSkill)) then
          names[skill] = true
        end
      end
    end
  end
  -- 授技来源不在武将技能表中，单独补入后与正式技能同样枚举。
  for _, skill in ipairs(GRANTED_ACTIVE) do
    local sk = Fk.skills[skill]
    if sk ~= nil and (sk:isInstanceOf(ActiveSkill) or sk:isInstanceOf(ViewAsSkill)) then
      names[skill] = true
    end
  end
  local sorted = {}
  for name in pairs(names) do table.insert(sorted, name) end
  table.sort(sorted)
  for _, skill in ipairs(GRANTED_ACTIVE) do
    lu.assertTrue(table.contains(sorted, skill), "授予技能应进入客户端枚举：" .. skill)
  end
  for name in pairs(EXPECTED_TRUE) do
    lu.assertTrue(table.contains(sorted, name), "已知合法技能应进入客户端枚举：" .. name)
  end

  local targetOnly = "qiao__retinue_skill_bingzhou_langqi"
  lu.assertTrue(table.contains(sorted, targetOnly))
  local tested = 0
  local available, entered, filtered = 0, 0, 0
  for _, skill in ipairs(sorted) do
    local ok, err = xpcall(function()
      client_room.run(room, function(clients)
        local me = clients[1]
        me.player_skills = table.simpleClone(me.player_skills or {})
        table.insert(me.player_skills, Fk.skills[skill])
        lu.assertNil(me.room, "ClientPlayer 不应有 room：" .. skill)
        local sk = assert(Fk.skills[skill], "缺少技能：" .. skill)
        tested = tested + 1
        local handler = ReqPlayCard:new(me)
        handler.skill_name = skill
        if sk:isInstanceOf(ViewAsSkill) then
          handler.extra_data = handler.extra_data or {}
        else
          handler:setup()
        end
        local valid = handler:skillButtonValidity(skill)
        lu.assertTrue(type(valid) == "boolean", "按钮结果应为布尔：" .. skill)
        if EXPECTED_TRUE[skill] then
          lu.assertTrue(valid, "通用夹具下合法主动技应可用：" .. skill)
        end
        if valid then
          available = available + 1
          -- 真实点击：进入技能选择后必须能走通该技能的选牌/目标筛选。
          handler:selectSkill(skill, { selected = true })
          lu.assertEquals(handler.skill_name, skill, "点击后应进入技能选择：" .. skill)
          entered = entered + 1
          local anyCard = false
          for _, cid in ipairs(me:getHandlyIds(true)) do
            local okCard = handler:cardValidity(cid)
            lu.assertTrue(type(okCard) == "boolean", "选牌结果应为布尔：" .. skill)
            anyCard = anyCard or okCard
          end
          if skill == targetOnly then
            lu.assertFalse(anyCard, "并州狼骑只允许选择目标")
            lu.assertTrue(handler:targetValidity(clients[2].id))
          end
          for _, target in ipairs(clients) do
            local okTarget = handler:targetValidity(target.id)
            lu.assertTrue(type(okTarget) == "boolean", "目标结果应为布尔：" .. skill)
          end
          lu.assertTrue(type(handler:feasible()) == "boolean", "确认结果应为布尔：" .. skill)
          filtered = filtered + 1
          if EXPECTED_TRUE[skill] then
            lu.assertTrue(sk:targetFilter(me, clients[2], {}, {}), "合法目标应通过：" .. skill)
            if EXPECTED_FALSE_SELF[skill] then
              lu.assertFalse(sk:targetFilter(me, me, {}, {}), "自身不应是合法目标：" .. skill)
            end
          end
        end
        handler:_finish()
      end)
    end, debug.traceback)
    if not ok then error(skill .. ": " .. tostring(err), 0) end
  end
  lu.assertTrue(tested >= 60, "客户端主动扫描覆盖过少：" .. tested)
  local expected = 0
  for name in pairs(EXPECTED_TRUE) do
    if table.contains(sorted, name) then expected = expected + 1 end
  end
  lu.assertTrue(available >= expected,
    "可用按钮数量不得少于已知合法技能（可用 " .. available .. " / " .. tested .. "）")
  lu.assertEquals(entered, available, "每个可用按钮都必须实际进入技能选择")
  lu.assertEquals(filtered, available, "每个可用按钮都必须走选牌/目标筛选")
end

-- 正式客户端 QiaoPlayCard：按钮可用性与确认键共用同一条次数声明检查。
-- 用良的效果声明为出牌阶段限一次，但 can_use 本身不检查次数；这里只用声明，
-- 不复制技能自己的可用性策略。
function Testqiao_client_active_skills:testQiaoPlayCardBlocksExhaustedDeclaration()
  local room = FkTest.room
  local user, target = room.players[1], room.players[2]
  inRoom(function()
    room:handleAddLoseSkills(user, YONGLIANG, nil, false, true)
    user.phase = Player.Play
    room.current = user
  end)
  local skill = assert(Fk.skills[YONGLIANG])
  lu.assertTrue(ActiveSkillLimits.appliesTo(skill), "正式主主动效果应进入共享检查")
  lu.assertFalse(ActiveSkillLimits.appliesTo(Fk.skills["#qiao__skill_han007_1_aux"]),
    "辅助主动技不进入共享检查")

  client_room.run(room, function(clients)
    local me = clients[1]
    local handler = qiaoPlayCardClass():new(me)
    handler.skill_name = YONGLIANG
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(YONGLIANG), "未发动时按钮应可用")

    handler:selectSkill(YONGLIANG, { selected = true })
    local clientTarget = clients[2]
    lu.assertTrue(handler:targetValidity(clientTarget.id), "合法目标应可点击")
    handler:selectTarget(clientTarget.id, { selected = true })
    lu.assertTrue(handler:feasible(), "未发动时应可确认")

    me:setSkillUseHistory(YONGLIANG, 1, Player.HistoryPhase)
    lu.assertFalse(handler:skillButtonValidity(YONGLIANG), "声明次数用尽后按钮应禁用")
    lu.assertFalse(handler:feasible(), "声明次数用尽后确认键应禁用")
    handler:_finish()
  end)
end

-- 正常服务端入口（params == nil）用同一份声明覆盖多种声明形态：
-- 固定效果声明、标记驱动的动态效果声明、动态骨架声明与限定技。
-- 每个场景只验证共享入口在计次前拒绝且不增加历史，不重复技能自身结算。
function Testqiao_client_active_skills:testServerNormalPlaySharedDeclarationScenarios()
  local room = FkTest.room
  local user, target = room.players[1], room.players[2]

  local function resolveLimit(owner, declarations, scope)
    local limit = declarations[scope]
    if type(limit) == "function" then limit = limit(owner, user) end
    return limit
  end

  local scenarios = {
    {
      name = "固定效果声明（用良）",
      skill = YONGLIANG,
      scope = Player.HistoryPhase,
      prepare = function()
        local card = room:printCard("qiao__jink", Card.Heart, 4)
        room:obtainCard(user, card, false, fk.ReasonJustMove)
      end,
      limit = function() return 1 end,
    },
    {
      name = "动态骨架声明（奋钺）",
      skill = FENYUE,
      scope = Player.HistoryPhase,
      prepare = function() end,
      limit = function()
        local skeleton = assert(Fk.skills[FENYUE]:getSkeleton())
        return resolveLimit(skeleton, skeleton.max_use_time, Player.HistoryPhase)
      end,
    },
    {
      name = "标记驱动的动态效果声明（破竹）",
      skill = POZHU,
      scope = Player.HistoryPhase,
      prepare = function()
        local card = room:printCard("qiao__jink", Card.Heart, 5)
        room:obtainCard(user, card, false, fk.ReasonJustMove)
        room:setPlayerMark(user, "qiao_jin006_1_phase", { uses = 0, restored = 1 })
      end,
      limit = function()
        local effect = assert(Fk.skills[POZHU])
        return resolveLimit(effect, effect.max_use_time, Player.HistoryPhase)
      end,
    },
    {
      name = "限定技（遄征）",
      skill = CRUISE,
      scope = Player.HistoryGame,
      prepare = function() end,
      limit = function() return 1 end,
    },
  }

  for _, case in ipairs(scenarios) do
    local expected
    inRoom(function()
      room:handleAddLoseSkills(user, case.skill, nil, false, true)
      user.phase = Player.Play
      room.current = user
      case.prepare()
      local limit = case.limit()
      lu.assertTrue(type(limit) == "number" and limit >= 1,
        case.name .. " 应有次数声明")
      user:setSkillUseHistory(case.skill, limit, case.scope)
      expected = limit
    end)

    local result
    inRoom(function() result = serverReply(room, user, case.skill, { target }) end)
    lu.assertNil(result, case.name .. " 次数用尽后应拒绝回包")
    inRoom(function()
      lu.assertEquals(user:usedSkillTimes(case.skill, case.scope), expected,
        case.name .. " 被拒绝时不得增加技能历史")
    end)
  end
end

return { name = "qiao_client_active_skills" }

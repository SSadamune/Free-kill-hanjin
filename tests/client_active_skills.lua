-- 广覆盖：正式武将/翼从及旗授予技能的主动按钮查询，必须使用真实 ClientPlayer。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"


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

return { name = "qiao_client_active_skills" }

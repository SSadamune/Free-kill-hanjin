-- JIN017 王浑：数据片段、遄征移除副将并获得献捷。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.hanjin.pkg.hanjin_generals.data.zhen_shi_jin2"
local XIANJIE = "hanjin__skill_jin017_3"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testhanjin_jin017_wanghun = {
  setup = function()
    local room = support.initHanjinRoom()
    inRoom(function() skill_test.installBlankGenerals(room, "han") end)
  end,
  tearDown = support.clearRoom,
}

function Testhanjin_jin017_wanghun:testDataFragment()
  local general = table.find(DATA.generals, function(g) return g.id == "hanjin__jin017" end)
  lu.assertNotNil(general)
  lu.assertNotNil(Fk.generals["hanjin__jin017"], "正式将池尚未合入 JIN017")
  lu.assertEquals(general.skills[2].tags[1], "Limited")
end

function Testhanjin_jin017_wanghun:testChuanzhengGrantsXianjie()
  local me = p(1)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, "hanjin__skill_jin017_2", nil, false, true)
    me.phase = Player.Play
    Fk.skills["hanjin__skill_jin017_2"]:onUse(FkTest.room, { from = me })
    lu.assertTrue(me:hasSkill(XIANJIE), "移除副将后获得永久献捷")
  end)
end

return { name = "hanjin_jin017_wanghun" }

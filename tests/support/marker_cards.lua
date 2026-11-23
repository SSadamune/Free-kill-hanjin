-- 在已经运行的房间协程中用正式【不屈】产生一张实体「创」。
local requests = __dofile("../../../tests/support/skill_test.lua")
local M = {}

function M.scar(room, player, suit, keep)
  local id = room:printCard("qiao__jink", suit, 7).id
  room:obtainCard(player, id, false, fk.ReasonJustMove)
  requests.withSkillRequests(room, "qiao__skill_wu013_1", {
    askToCards = function(self, who, params)
      if params.prompt == "#qiao__skill_wu013_1-keep" then return { keep or id } end
      return { id }
    end,
  }, function() room:enterDying { who = player } end)
  return id
end

return M

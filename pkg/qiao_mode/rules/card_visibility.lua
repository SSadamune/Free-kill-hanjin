local V = {}

-- 公开效果只声明在哪个座位、哪张牌、哪个位置生效。
-- 手牌转手时客户端已更新牌主；移牌通知保留了原牌主、原区域和移动前的牌面标记。
---@param visibleAt fun(viewer: Player, owner: Player?, area: CardArea, card: Card?, id: integer): boolean?
function V.atLocation(visibleAt)
  return {
    card_visible = function(self, viewer, card)
      local room = Fk:currentRoom()
      if room and card then
        return visibleAt(viewer, room:getCardOwner(card.id), room:getCardArea(card.id), card, card.id) or nil
      end
    end,
    move_visible = function(self, viewer, info, move)
      if info.fromArea ~= Card.PlayerHand or move.toArea ~= Card.PlayerHand then return end
      local room = Fk:currentRoom()
      -- 引擎只在 card_visible 入口检查旁观设置；移动时也遵从同一查看权限。
      if room.observing and not room:getSettings("enableObserverViewCard") then return end
      return visibleAt(viewer, move.from, info.fromArea, info.beforeCard, info.cardId) or nil
    end,
  }
end

V.ZHAORAN_OPEN = "qiao_jin003_1_open-phase"
V.zhaoran = V.atLocation(function(viewer, owner, area)
  return area == Card.PlayerHand and owner and owner:getMark(V.ZHAORAN_OPEN) > 0
end)

return V

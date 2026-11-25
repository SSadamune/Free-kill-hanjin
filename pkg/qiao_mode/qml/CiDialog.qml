// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import LunarLtk
import LunarLtk.Pages.Popups

GraphicsBox {
  id: root
  required property string mode
  required property string prompt
  required property list<string> cardNames
  property var groups: ({})
  property var groupOrder: []

  width: Math.min(720, Math.max(360, (parent?.width ?? 740) - 30))
  height: Math.min((parent?.height ?? 600) * 0.78, 430)

  CiPile {
    anchors.margins: 12
    mode: root.mode
    prompt: root.prompt
    cardNames: root.cardNames
    groups: root.groups
    groupOrder: root.groupOrder
    onSubmitted: choice => Ltk.roomModel.replyToServer(choice)
    onCanceled: Ltk.roomModel.replyToServer("__cancel")
  }
}

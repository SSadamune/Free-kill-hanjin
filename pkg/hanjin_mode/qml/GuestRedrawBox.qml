// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Models.Popups
import LunarLtk.Pages.Popups

GraphicsBox {
  id: root
  required property ChooseGeneralModel dataModel
  property var marked: []
  width: chooser.width
  height: chooser.height + controls.height + 12
  onShown: chooser.shown()

  ChooseGeneralBox {
    id: chooser
    dataModel: root.dataModel
  }

  Flow {
    id: controls
    anchors.top: chooser.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: parent.width - 32
    spacing: 8

    Repeater {
      model: root.dataModel.extraData.guests
      CheckBox {
        required property string modelData
        text: Lua.tr(modelData)
        palette.windowText: "white"
        onToggled: root.marked = checked ? root.marked.concat([modelData])
                                        : root.marked.filter(name => name !== modelData)
      }
    }

    MetroButton {
      text: Lua.tr("hanjin_guest_redraw")
      enabled: root.marked.length > 0
      onClicked: Ltk.roomModel.replyToServer({ indices: root.marked })
    }
  }
}

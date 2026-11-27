pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Fk
import Fk.Widgets as W

W.ActionRow {
  id: root

  property string value
  required property var model

  subTitle: root.model.indexOf(root.value) >= 0 ? Lua.tr("help: " + root.value) : ""

  suffixComponent: ComboBox {
    id: choices

    model: root.model
    currentIndex: root.model.indexOf(root.value)
    displayText: Lua.tr(currentText)
    onActivated: index => root.value = root.model[index]

    background: Rectangle {
      color: "transparent"
      implicitHeight: root.height - 16
      implicitWidth: 120
    }

    delegate: ItemDelegate {
      required property int index
      required property string modelData

      width: choices.width
      text: Lua.tr(modelData)
      highlighted: index === choices.highlightedIndex
    }
  }

  onClicked: root.suffixLoader.item.popup.open()
}

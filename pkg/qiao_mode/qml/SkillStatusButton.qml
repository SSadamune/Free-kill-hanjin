// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Fk
import LunarLtk

Controls.AbstractButton {
  id: button
  objectName: "qiaoSkillStatus"
  required property var states
  visible: states.length > 0
  hoverEnabled: true
  implicitWidth: Math.min(104, Math.max(34, label.implicitWidth + 12))
  implicitHeight: 21
  text: states.length === 1
    ? states[0].title + (states[0].value ? " " + states[0].value : "")
    : Lua.tr("qiao_skill_status") + " " + states.length

  background: Rectangle {
    radius: 4
    color: button.down ? "#383020" : "#59432b"
    border.color: button.hovered || button.visualFocus ? "#fff0b4" : "#cfaa64"
  }

  contentItem: Text {
    id: label
    text: button.text
    font.family: Config.libianName
    font.pixelSize: 14
    color: "#ffdf99"
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  Controls.ToolTip.visible: hovered && visible
  Controls.ToolTip.delay: 300
  Controls.ToolTip.text: states.map(state =>
    state.title + (state.value ? " " + state.value : "") + "　" + state.description).join("\n")

  onClicked: Ltk.roomScene.showInfoPopup(details, { states: Qt.binding(() => button.states) })

  Component {
    id: details
    Controls.ScrollView {
      id: view
      required property var states
      anchors.fill: parent
      padding: 18
      contentWidth: availableWidth
      ColumnLayout {
        width: view.availableWidth
        spacing: 8
        Repeater {
          model: view.states
          delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            Text {
              text: parent.modelData.title + (parent.modelData.value ? "　" + parent.modelData.value : "")
              color: "#ffdf99"
              font.pixelSize: 18
            }
            Text {
              Layout.fillWidth: true
              text: parent.modelData.description
              color: "#e4d5a0"
              font.pixelSize: 16
              wrapMode: Text.Wrap
            }
          }
        }
      }
    }
  }
}

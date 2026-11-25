// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import "SkillReferenceLinks.js" as SkillLinks

ColumnLayout {
  id: root
  anchors.fill: parent

  objectName: "qiaoCiPile"
  property string mode: "view"
  property string prompt: "@[qiao_ci]"
  property list<string> cardNames
  property var groups: ({})
  property var groupOrder: []
  property var actionsByCard: ({})
  property string selectedCi: ""
  property string selectedKingdom: ""
  readonly property var selectedNames: mode === "give" ? (groups[selectedKingdom] ?? []) : [selectedCi]
  readonly property var actions: actionsByCard[selectedCi] ?? []
  signal submitted(var choice)
  signal canceled()

  function inspect(card, name) {
    if (mode === "consume" || mode === "remove") selectedCi = name;
    const detail = Ltk.getGeneralDetail(name);
    skillTip.html = "<b>" + SkillLinks.escapeText(Lua.tr(name)) + "</b><br/>" +
      Array.from(detail.skill, skill => "<b>" + SkillLinks.escapeText(Lua.tr(skill.name)) +
        "</b> " + skill.description).join("<br/>");
    skillTip.linkPosition = card.mapToItem(root, card.width * 0.75, card.height / 2);
    skillTip.open();
  }

  GlowText {
    objectName: "qiaoCiPrompt"
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredHeight: textItem.contentHeight + 4
    text: Ltk.processPrompt(root.prompt)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    wrapMode: Text.Wrap
    font.family: Config.libianName
    font.pixelSize: 22
    font.weight: Font.Medium
    color: "#e4d5a0"
    glow.color: "black"
    glow.spread: 0.3
    glow.radius: 5
  }

  GridView {
    Layout.preferredWidth: Math.max(cellWidth, root.width - root.width % cellWidth)
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignHCenter
    cellWidth: 97
    cellHeight: 134
    clip: true
    model: root.cardNames
    Controls.ScrollBar.vertical: Controls.ScrollBar {}

    delegate: QiaoGeneralCard {
      id: card
      required property string modelData
      autoBack: false
      generalName: modelData
      onClicked: root.inspect(card, modelData)
      onRightClicked: root.inspect(card, modelData)

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 5
        width: 26
        height: 26
        radius: 13
        z: 3
        color: "#165737"
        border.color: "#b0edb8"
        visible: root.selectedNames.includes(card.modelData)
        Text {
          anchors.centerIn: parent
          text: "✓"
          font.pixelSize: 19
          font.bold: true
          color: "#e1ffe5"
        }
      }
    }
  }

  Flow {
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    visible: root.mode === "give"
    spacing: 6
    Repeater {
      model: root.groupOrder
      MetroButton {
        required property string modelData
        text: Ltk.processPrompt("qiao_ci_give_faction:::" + modelData)
        checked: root.selectedKingdom === modelData
        onClicked: root.selectedKingdom = modelData
      }
    }
  }

  RowLayout {
    Layout.alignment: Qt.AlignHCenter
    Repeater {
      model: root.mode === "consume" ? ["main", "deputy", "maxcards", "draw"] : []
      MetroButton {
        required property string modelData
        text: Lua.tr("qiao_ci_" + modelData)
        enabled: root.actions.includes(modelData)
        onClicked: root.submitted({ general: root.selectedCi, action: modelData })
      }
    }
    MetroButton {
      visible: root.mode === "give"
      enabled: root.selectedNames.length > 0
      text: Lua.tr("qiao_ci_give")
      onClicked: root.submitted({ kingdom: root.selectedKingdom })
    }
    MetroButton {
      visible: root.mode === "remove"
      enabled: root.cardNames.includes(root.selectedCi)
      text: Lua.tr("qiao_ci_remove")
      onClicked: root.submitted({ general: root.selectedCi })
    }
    MetroButton {
      text: root.mode === "view" ? "关闭" : Lua.tr("Cancel")
      onClicked: root.canceled()
    }
  }

  SkillReferenceTooltip {
    id: skillTip
    parent: root
    viewport: root
    entries: []
    linkPosition: Qt.point(0, 0)
    html: ""
    dismissOnOutsideClick: true
  }
}

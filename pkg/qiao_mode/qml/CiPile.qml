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
  property string inspectedCi: ""
  readonly property var selectedNames: mode === "give" ? (groups[selectedKingdom] ?? []) : [selectedCi]
  readonly property var actions: actionsByCard[selectedCi] ?? []
  readonly property var roomScene: Ltk.roomScene
  signal submitted(var choice)
  signal canceled()

  onCardNamesChanged: {
    if (!cardNames.includes(inspectedCi)) inspectedCi = "";
    if (!cardNames.includes(selectedCi)) selectedCi = "";
  }

  function inspect(name) {
    if (mode === "consume" || mode === "remove") selectedCi = name;
    if (inspectedCi === name) details.reset();
    inspectedCi = name;
    detailViewport.contentY = 0;
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

  Flickable {
    id: cardRow
    objectName: "qiaoCiCardRow"
    readonly property int cardWidth: 93
    readonly property int cardHeight: 130
    readonly property real cardStep: cards.count > 1
      ? Math.max(cardWidth / 2, Math.min(cardWidth + 4, (width - cardWidth) / (cards.count - 1)))
      : cardWidth

    Layout.fillWidth: true
    Layout.preferredHeight: cardHeight + (contentWidth > width ? 9 : 0)
    visible: cards.count > 0
    clip: true
    contentWidth: cards.count ? cardWidth + (cards.count - 1) * cardStep : 0
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.horizontal: Controls.ScrollBar {
      policy: cardRow.contentWidth > cardRow.width ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
    }

    Repeater {
      id: cards
      model: root.cardNames
      delegate: QiaoGeneralCard {
        id: card
        required property int index
        required property string modelData
        readonly property real exposedWidth: index === cards.count - 1 ? width : Math.min(width, cardRow.cardStep)
        objectName: "qiaoCiCard"
        width: cardRow.cardWidth
        height: cardRow.cardHeight
        x: index * cardRow.cardStep
        z: index
        autoBack: false
        generalName: modelData
        onClicked: root.inspect(modelData)
        onRightClicked: root.inspect(modelData)
        // Match the hit region to the part left visible by the card on its right.
        containmentMask: Item {
          width: card.exposedWidth
          height: card.height
        }

        Rectangle {
          width: card.exposedWidth
          height: card.height
          color: "transparent"
          border.color: "#e4d5a0"
          border.width: 2
          z: 3
          visible: root.inspectedCi === card.modelData
        }
        Image {
          objectName: "qiaoCiChosen"
          source: SkinBank.cardDir + "chosen"
          width: Math.min(implicitWidth * 1.25, card.exposedWidth - 4)
          height: implicitHeight * width / Math.max(implicitWidth, 1)
          x: (card.exposedWidth - width) / 2
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 8
          fillMode: Image.PreserveAspectFit
          z: 3
          visible: root.selectedNames.includes(card.modelData)
        }
      }
    }
  }

  Flickable {
    id: detailViewport
    objectName: "qiaoCiDetailViewport"
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    contentWidth: width
    contentHeight: details.height
    flickableDirection: Flickable.VerticalFlick
    Controls.ScrollBar.vertical: Controls.ScrollBar {}

    SkillReferencePane {
      id: details
      viewport: detailViewport
      width: Math.max(0, detailViewport.width - 16)
      x: 4
      referenceKey: root.inspectedCi
      inlineTips: true
      generalCardPresentation: root.roomScene?.generalCardPresentation
      rootText: (catalog, theme) => {
        const name = root.inspectedCi;
        if (!name) return "";
        const factions = root.roomScene?.generalCardPresentation?.appearanceFor(name).factions;
        const groups = [{ name, detail: Ltk.getGeneralDetail(name), factions }];
        return SkillLinks.generalText(catalog, theme, groups, key => Lua.tr(key), true);
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
}

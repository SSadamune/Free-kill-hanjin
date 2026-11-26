// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Components
import LunarLtk.Pages.Popups
import "GuestIllustration.js" as GuestIllustration

GraphicsBox {
  id: root

  required property var candidates
  required property string prompt
  required property bool guestIllustrations
  required property var guestFactions
  required property var commanderDetails
  required property string partner
  required property bool isDeputy

  property string selectedName: ""
  property string previewName: ""
  readonly property int columns: Math.min(candidates.length, 7,
    Math.max(1, Math.floor(((parent?.width ?? 740) - 44) / 104)))
  readonly property var factionColors: ({
    wei: "#477cbd", shu: "#c34f37", wu: "#448b50",
    qun: "#92959a", han: "#aa832e", jin: "#845ba8"
  })

  title.text: Ltk.processPrompt(prompt)
  width: Math.max(300, columns * 104 + 44)
  height: grid.height + 104

  function factionsFor(name) {
    return GuestIllustration.roomFactions(guestFactions[name]);
  }

  function matchesPartner(name) {
    return partner !== "" && Ltk.isCompanionWith(name, partner);
  }

  function descriptionFor(name) {
    if (!name) return "";
    const detail = Ltk.getGeneralDetail(name);
    let text = "<b>" + Lua.tr(name) + "</b>";
    if (detail.headnote) text += "<br/>" + Lua.tr(detail.headnote);
    if (detail.companions.length > 0) {
      text += "<br/><b>" + Lua.tr("Companions") + "</b>　"
        + Array.from(detail.companions, companion => Lua.tr(companion)).join("、");
    }
    if (matchesPartner(name)) text += "<br/>" + Lua.tr("qiao_change_general-companion");
    const commander = commanderDetails[name];
    if (commander) text += "<br/><b>" + Lua.tr("qiao_change_general-commander") + "</b>　" + commander;
    for (const skill of detail.skill) {
      text += "<br/><b>" + Lua.tr(skill.name) + "</b>　" + skill.description;
    }
    if (detail.endnote) text += "<br/>" + Lua.tr(detail.endnote);
    return text;
  }

  GridView {
    id: grid
    anchors.top: parent.top
    anchors.topMargin: 44
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.columns * cellWidth
    readonly property int visibleRows: Math.max(1, Math.min(3,
      Math.floor(((root.parent?.height ?? 800) * 0.66 - 104) / cellHeight)))
    height: Math.min(visibleRows, Math.ceil(root.candidates.length / Math.max(1, root.columns))) * cellHeight
    cellWidth: 104
    cellHeight: 140
    clip: true
    model: root.candidates
    ScrollBar.vertical: ScrollBar {}

    delegate: Item {
      required property string modelData
      width: grid.cellWidth
      height: grid.cellHeight

      QiaoGeneralCard {
        id: card
        anchors.centerIn: parent
        generalName: parent.modelData
        selectable: true
        selected: root.selectedName === generalName
        readonly property var factions: root.factionsFor(generalName)
        dataModel: {
          const properties = { heg: true, inPosition: root.isDeputy ? -1 : 1 };
          properties.hasCompanion = root.matchesPartner(generalName);
          return Ltk.createGeneralCardModel(generalName, properties);
        }
        GuestCardAppearance {
          card: card
          enabledInContext: root.guestIllustrations
          factions: card.factions
        }
        GuestFactionBorder {
          anchors.fill: parent
          colors: card.factions.map(faction => root.factionColors[faction] ?? "#888888")
        }

        HoverHandler {
          cursorShape: Qt.PointingHandCursor
          onHoveredChanged: {
            if (hovered) {
              dismissPreview.stop();
              root.previewName = card.generalName;
            } else if (root.previewName === card.generalName) {
              dismissPreview.restart();
            }
          }
        }
        onClicked: root.selectedName = selected ? generalName : ""
        Connections {
          target: root
          function onSelectedNameChanged() { card.selected = root.selectedName === card.generalName; }
        }
      }
    }
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 12
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 8

    MetroButton {
      enabled: root.selectedName !== ""
      text: Lua.tr("OK")
      onClicked: Ltk.roomModel.replyToServer({ general: root.selectedName })
    }
    MetroButton {
      text: Lua.tr("Cancel")
      onClicked: Ltk.roomModel.replyToServer("__cancel")
    }
  }

  Timer {
    id: dismissPreview
    interval: 350
    onTriggered: root.previewName = ""
  }

  Popup {
    id: preview
    parent: root.parent
    visible: root.visible && root.previewName !== ""
    modal: false
    closePolicy: Popup.NoAutoClose
    padding: 12
    width: Math.min(430, (parent?.width ?? 454) - 24)
    readonly property bool fitsRight: root.x + root.width + width + 16 <= (parent?.width ?? 0)
    readonly property bool fitsLeft: root.x >= width + 16
    readonly property bool fitsSide: fitsLeft || fitsRight
    height: Math.min(description.implicitHeight + 2 * padding,
      fitsSide ? (parent?.height ?? 460) - 24 : Math.max(80, root.y - 20))
    x: fitsRight ? root.x + root.width + 8 : fitsLeft ? root.x - width - 8
      : Math.max(8, ((parent?.width ?? width) - width) / 2)
    y: fitsSide ? Math.max(8, Math.min(root.y, (parent?.height ?? height) - height - 8))
      : Math.max(8, root.y - height - 8)

    background: Rectangle {
      radius: 6
      color: "#302419"
      border.color: "#846c48"
    }
    contentItem: ScrollView {
      id: descriptionScroll
      clip: true
      contentWidth: availableWidth

      HoverHandler {
        onHoveredChanged: {
          if (hovered) dismissPreview.stop();
          else dismissPreview.restart();
        }
      }
      DescriptionText {
        id: description
        width: descriptionScroll.availableWidth
        color: "#f0dfb2"
        font.pixelSize: 16
        Connections {
          target: root
          function onPreviewNameChanged() {
            description.clearSavedText();
            description.text = root.descriptionFor(root.previewName);
            descriptionScroll.contentItem.contentY = 0;
          }
        }
      }
    }
  }
}

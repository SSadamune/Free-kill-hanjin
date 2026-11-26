// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Fk
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups

Item {
  id: root
  anchors.fill: parent

  required property ChooseGeneralModel dataModel
  required property int index
  required property bool guestIllustrations
  required property var displayFactions
  signal finish()

  readonly property var packageGroups: {
    const available = Array.from(Ltk.getAllGeneralPack());
    // The catalog reads the extension's registered order for each group.
    const local = Array.from(Lua.fk.extensions.qiao ?? []).filter(name => available.includes(name));
    return [local, available.filter(name => !local.includes(name))].filter(group => group.length > 0);
  }
  property var generals: []

  function showGenerals(names) {
    if (stack.depth > 1) stack.pop();
    generals = names;
    stack.push(generalList);
  }

  function search() {
    if (!word.text.length) return;
    root.showGenerals(Ltk.searchAllGenerals(word.text));
    word.clear();
  }

  ToolBar {
    id: bar
    width: parent.width

    RowLayout {
      anchors.fill: parent

      ToolButton {
        opacity: stack.depth > 1 ? 1 : 0
        enabled: stack.depth > 1
        text: Lua.tr("Back")
        onClicked: stack.pop()
      }

      Label {
        Layout.fillWidth: true
        text: Lua.tr("Enable free assign")
        elide: Label.ElideRight
        horizontalAlignment: Text.AlignHCenter
      }

      TextField {
        id: word
        placeholderText: Lua.tr("Search") + "…"
        onAccepted: root.search()
      }

      ToolButton {
        text: Lua.tr("Search")
        enabled: word.text.length > 0
        onClicked: root.search()
      }
    }
  }

  StackView {
    id: stack
    anchors.top: bar.bottom
    anchors.bottom: parent.bottom
    width: parent.width
    initialItem: packageList
  }

  Component {
    id: packageList

    ScrollView {
      id: packageScroll
      contentWidth: availableWidth
      clip: true

      ColumnLayout {
        width: packageScroll.availableWidth
        spacing: 6

        Repeater {
          model: root.packageGroups

          ColumnLayout {
            id: packGroup
            required property var modelData
            required property int index
            Layout.fillWidth: true

            Rectangle {
              objectName: "qiaoFreeAssignSeparator"
              visible: packGroup.index > 0
              Layout.fillWidth: true
              Layout.leftMargin: 12
              Layout.rightMargin: 12
              implicitHeight: 1
              color: "#8e785a"
            }

            GridLayout {
              Layout.fillWidth: true
              columns: 5
              columnSpacing: 0
              rowSpacing: 0
              uniformCellWidths: true

              Repeater {
                model: packGroup.modelData

                ItemDelegate {
                  id: pack
                  required property string modelData
                  Layout.fillWidth: true
                  Layout.minimumWidth: 0
                  implicitHeight: 40
                  contentItem: Text {
                    text: Lua.tr(pack.modelData)
                    color: "#E4D5A0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                  }
                  onClicked: root.showGenerals(Ltk.getGenerals(pack.modelData))
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: generalList

    GridView {
      clip: true
      topMargin: 6
      cellWidth: 100
      cellHeight: 140
      model: root.generals
      ScrollBar.vertical: ScrollBar {}

      delegate: GeneralCardItem {
        id: card
        required property string modelData
        autoBack: false
        dataModel: Ltk.createGeneralCardModel(modelData)

        GuestCardAppearance {
          card: card
          enabledInContext: root.guestIllustrations
          factions: root.displayFactions(card.modelData)
        }

        onClicked: {
          root.dataModel.changeGeneral(root.index, Ltk.createGeneralCardModel(modelData));
          root.finish();
        }
      }
    }
  }
}

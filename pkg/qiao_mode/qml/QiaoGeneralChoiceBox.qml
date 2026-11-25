import QtQuick
import QtQuick.Controls
import Fk
import Fk.Components.Common
import LunarLtk
import LunarLtk.Pages.Popups

GraphicsBox {
  id: root

  // Use the utility dialog's model and reply format.
  required property var dataModel
  readonly property int columns: Math.min(7, Math.max(4, dataModel.all_cards.length))
  width: columns * 100 + 32
  height: Math.min(3, Math.max(1, Math.ceil(dataModel.cards.length / columns))) * 140 + 108

  Text {
    anchors.top: parent.top
    anchors.topMargin: 8
    anchors.horizontalCenter: parent.horizontalCenter
    text: Ltk.processPrompt(root.dataModel.prompt)
    color: "#E4D5A0"
    font.pixelSize: 20
  }

  GridView {
    anchors.fill: parent
    anchors.topMargin: 44
    anchors.bottomMargin: 56
    anchors.leftMargin: 16
    anchors.rightMargin: 16
    cellWidth: 100
    cellHeight: 140
    model: root.dataModel.cards
    clip: true

    delegate: QiaoGeneralCard {
      id: generalCard
      required property string modelData
      generalName: modelData
      scene: root.parent
      selectable: root.dataModel.max > 0 && !root.dataModel.disable_cards.includes(modelData)
      autoBack: false

      onSelectedChanged: {
        chosenInBox = selected;
        root.dataModel.toggleGeneral(modelData, selected);
      }

      Connections {
        target: root.dataModel
        function onRequestGeneralUnselect(name) {
          if (name === generalCard.modelData) generalCard.selected = false;
        }
      }

      onRightClicked: root.parent.showInfoPopup(
        Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"), { generals: [modelData] })
    }
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 8

    MetroButton {
      visible: root.dataModel.max === 0 && root.dataModel.cards.length > 0
      text: Lua.tr("Show General Detail")
      onClicked: root.parent.showInfoPopup(
        Qt.createComponent("LunarLtk.Pages.InfoPopups", "GeneralDetail"),
        { generals: Array.from(root.dataModel.cards) })
    }

    TextField {
      id: search
      visible: root.dataModel.all_cards.length > 21
      enabled: !root.dataModel.isSearching
      placeholderText: Lua.tr("Search")
    }
    MetroButton {
      visible: search.visible
      enabled: search.text.length > 0 || root.dataModel.isSearching
      text: Lua.tr(root.dataModel.isSearching ? "Back" : "Search")
      onClicked: {
        root.dataModel.applySearchToggle(search.text);
        if (!root.dataModel.isSearching) search.clear();
      }
    }
    Repeater {
      model: root.dataModel.ok_options
      MetroButton {
        required property string modelData
        enabled: root.dataModel.okEnabled
        text: Ltk.processPrompt(modelData)
        onClicked: root.dataModel.doAccepted(modelData)
      }
    }
    Repeater {
      model: root.dataModel.cancel_options
      MetroButton {
        required property string modelData
        text: Ltk.processPrompt(modelData)
        onClicked: root.dataModel.rejected()
      }
    }
  }

}

"""Headless regression for the HanJin free-assignment entry points.

The real GuestRedrawBox.qml is loaded in a context that deliberately has no
bare ``roomScene`` context property. The only room route is the same public
singleton used by RoomBase.qml: ``Ltk.roomScene``.

The real runtime FreeAssign.qml is copied into a temporary fixture and opened
through Scene.showInfoPopup. The test clicks the package list and a general
card, then checks the original ChooseGeneralModel and the popup's finish
signal. Both right-click and long press on a candidate card must create a
fresh popup instance.
"""
import os
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_QA = ROOT / ".dev" / "qml-qa"
RUNTIME_ROOT = ROOT / ".dev" / "runtime" / "FreeKill-release"
RUNTIME_FREE_ASSIGN = RUNTIME_ROOT / "LunarLtk" / "Pages" / "InfoPopups" / "FreeAssign.qml"
RUNTIME_TAP_HANDLER = RUNTIME_ROOT / "Fk" / "Widgets" / "TapHandler.qml"
sys.path.insert(0, str(QML_QA))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QMetaObject, QPoint, QPointF, Qt, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest

FIXTURE_PARTS = {
    "Fk/qmldir": "singleton Lua 1.0 Lua.qml\nsingleton Config 1.0 Config.qml\n",
    "Fk/Lua.qml": """pragma Singleton
import QtQuick
QtObject {
  property var client: QtObject { function getSettings(key) { return false } }
  function tr(text) { return text }
}
""",
    "Fk/Config.qml": """pragma Singleton
import QtQuick
QtObject { property string libianName: "Arial" }
""",
    "Fk/Widgets/qmldir": "TapHandler 1.0 TapHandler.qml\n",
    "Fk/Components/Common/qmldir": "MetroButton 1.0 MetroButton.qml\n",
    "Fk/Components/Common/MetroButton.qml": """import QtQuick
Rectangle {
  property string text: ""
  signal clicked()
  width: label.implicitWidth + 24
  height: 40
  color: "gray"
  Text { id: label; anchors.centerIn: parent; text: parent.text }
  MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
}
""",
    "LunarLtk/qmldir": "singleton Ltk 1.0 Ltk.qml\n",
    "LunarLtk/Ltk.qml": """pragma Singleton
import QtQuick
QtObject {
  property var roomScene
  property Component cardComp: Component {
    QtObject {
      property string name
      property string kingdom: "han"
      property string subkingdom: ""
      property int inPosition: 0
      property bool hasCompanion: false
      property int mainMaxHp: 0
      property int deputyMaxHp: 0
    }
  }
  function getAllGeneralPack() { return ["hanjin_test_content"] }
  function getGenerals(pack) { return ["hanjin_test__wei_1", "hanjin_test__shu_1"] }
  function searchAllGenerals(word) { return getGenerals("hanjin_test_content") }
  function createGeneralCardModel(name) {
    let model = cardComp.createObject(null)
    model.name = name
    return model
  }
  function isCompanionWith(first, second) { return false }
}
""",
    "LunarLtk/Components/qmldir": "GeneralCardItem 1.0 GeneralCardItem.qml\n",
    "LunarLtk/Components/GeneralCardItem.qml": """import QtQuick
import Fk.Widgets as W
Rectangle {
  id: root
  width: 93
  height: 130
  required property var dataModel
  property bool selectable: true
  property bool draggable: false
  property bool dragging: false
  property bool autoBack: true
  property real origX: 0
  property real origY: 0
  property real origOpacity: 1
  signal clicked()
  signal rightClicked()
  signal released()
  function goBack(animated) { x = origX; y = origY; opacity = origOpacity }
  function destroyOnStop() {}
  // Reuse the runtime gesture component, including its long-press behavior.
  W.TapHandler {
    onTapped: (point, button) => {
      if (button === Qt.RightButton) root.rightClicked()
      else root.clicked()
    }
    onLongPressed: root.rightClicked()
  }
}
""",
    "LunarLtk/Models/Popups/qmldir": "ChooseGeneralModel 1.0 ChooseGeneralModel.qml\n",
    "LunarLtk/Models/Popups/ChooseGeneralModel.qml": """import QtQuick
import LunarLtk
QtObject {
  property var generals: []
  property int choiceNum: 2
  property bool convertDisabled: false
  property bool hegemony: true
  property var extraData: ({})
  property string prompt: ""
  property var generalDict: []
  property list<int> resultInt: []
  readonly property var result: resultInt.map(e => generals[e])
  readonly property string promptText: "prompt"
  readonly property bool feasible: true
  readonly property bool canConvert: false
  signal generalChanged(int idx, string newname)
  signal accepted()
  signal rejected()
  function generalFilter(choice) { return true }
  function selectGeneralCard(index) {}
  function moveGeneral(generalIndex, toSelect, toIndex) {}
  function changeGeneral(idx, newModel) {
    generalDict[idx] = newModel
    generals[idx] = newModel.name
    generalChanged(idx, newModel.name)
  }
  function initialize() {
    let dict = []
    for (let name of generals) dict.push(Ltk.createGeneralCardModel(name))
    generalDict = dict
  }
}
""",
    "LunarLtk/Pages/Popups/qmldir": "GraphicsBox 1.0 GraphicsBox.qml\n",
    "LunarLtk/Pages/Popups/GraphicsBox.qml": """import QtQuick
Item {
  property alias title: titleText
  signal shown()
  signal accepted()
  signal finished()
  Text { id: titleText }
}
""",
    "LunarLtk/Pages/InfoPopups/qmldir": "FreeAssign 1.0 FreeAssign.qml\n",
}

MAIN_QML = """
import QtQuick
import QtQuick.Window
import LunarLtk
import LunarLtk.Models.Popups

Window {
  id: scene
  width: 1000
  height: 800
  visible: true
  property var model: null
  property var box: null
  property var popup: null
  property var popupParams: null
  property int finishCount: 0
  property var cardCenter0: null
  property var cardCenter1: null

  function showInfoPopup(component, params) {
    popupParams = params
    if (box) box.visible = false
    popup = component.createObject(popupHost, params)
    popup.z = 1000
    popup.finish.connect(function() { finishCount += 1 })
  }

  function closePopup() {
    if (popup) {
      popup.destroy()
      popup = null
    }
    if (box) box.visible = true
  }

  function inspect() {
    let first = box.generalCardList.itemAt(0)
    let second = box.generalCardList.itemAt(1)
    cardCenter0 = Qt.point(box.x + first.x + first.width / 2,
                           box.y + first.y + first.height / 2)
    cardCenter1 = Qt.point(box.x + second.x + second.width / 2,
                           box.y + second.y + second.height / 2)
  }

  Item {
    id: popupHost
    width: 900
    height: 700
  }

  ChooseGeneralModel {
    id: model
    generals: ["hanjin_test__han_1", "hanjin_test__jin_1"]
    extraData: ({
      freeAssign: true,
      offers: ["hanjin_test__han_1", "hanjin_test__jin_1"],
      guests: [],
      guestFactions: {},
      pairing: {},
      wild: {}
    })
  }

  Component.onCompleted: {
    scene.model = model
    model.initialize()
    // This is the only room route. Do not add a bare roomScene context property.
    Ltk.roomScene = scene
    let component = Qt.createComponent("__SOURCE__")
    box = component.createObject(scene, { dataModel: model })
    box.shown()
  }
}
"""


def write_fixture(root):
    imports = root / "imports"
    for rel, text in FIXTURE_PARTS.items():
        path = imports / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    target = imports / "LunarLtk" / "Pages" / "InfoPopups" / "FreeAssign.qml"
    if not RUNTIME_FREE_ASSIGN.is_file():
        raise FileNotFoundError("Missing runtime FreeAssign.qml: %s" % RUNTIME_FREE_ASSIGN)
    shutil.copyfile(RUNTIME_FREE_ASSIGN, target)
    tap_handler = imports / "Fk" / "Widgets" / "TapHandler.qml"
    if not RUNTIME_TAP_HANDLER.is_file():
        raise FileNotFoundError("Missing runtime TapHandler.qml: %s" % RUNTIME_TAP_HANDLER)
    shutil.copyfile(RUNTIME_TAP_HANDLER, tap_handler)
    return target


def walk(item):
    result = [item]
    for child in item.childItems():
        result.extend(walk(child))
    return result


def visible_of_type(root, name):
    return [item for item in walk(root)
            if name in item.metaObject().className() and item.isVisible()]


def click_item(scene, item):
    center = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    QTest.mouseClick(scene, Qt.LeftButton, Qt.NoModifier,
                     QPoint(int(center.x()), int(center.y())))


def long_press_point(scene, point):
    pos = QPoint(int(point.x()), int(point.y()))
    QTest.mousePress(scene, Qt.LeftButton, Qt.NoModifier, pos)
    QTest.qWait(1200)
    QTest.mouseRelease(scene, Qt.LeftButton, Qt.NoModifier, pos)


def main():
    warnings = []
    qInstallMessageHandler(lambda kind, context, message: warnings.append(message))
    app = QGuiApplication([])
    engine = QQmlApplicationEngine()
    fixture = Path(tempfile.mkdtemp(prefix="hanjin-free-assign-"))
    try:
        write_fixture(fixture)
        engine.addImportPath(str(fixture / "imports"))
        source = (ROOT / "pkg/hanjin_mode/qml/GuestRedrawBox.qml").resolve().as_uri()
        engine.loadData(MAIN_QML.replace("__SOURCE__", source).encode(),
                        QUrl.fromLocalFile(str(fixture / "main.qml")))
        if not engine.rootObjects():
            raise RuntimeError("QML failed to load: " + repr(warnings))
        scene = engine.rootObjects()[0]
        QTest.qWait(200)
        QMetaObject.invokeMethod(scene, "inspect")
        card0 = scene.property("cardCenter0")
        card1 = scene.property("cardCenter1")
        model = scene.property("model")
        if not (card0 and card1):
            raise AssertionError("Missing card geometry")

        def fail(message):
            diagnostics = [w for w in warnings if "font" not in w.lower()]
            raise AssertionError(message + "\nQML diagnostics:\n" + "\n".join(diagnostics[-20:]))

        def choose_from_popup(label):
            popup = scene.property("popup")
            if popup is None:
                fail("The %s entry did not create a popup" % label)
            if "FreeAssign" not in popup.metaObject().className():
                fail("The %s entry created %s, not the runtime FreeAssign" %
                     (label, popup.metaObject().className()))
            if popup.width() <= 0 or popup.height() <= 0:
                fail("The %s popup has no real size: %sx%s" %
                     (label, popup.width(), popup.height()))
            packages = visible_of_type(popup, "ItemDelegate")
            if not packages:
                fail("The %s popup has no package delegate" % label)
            click_item(scene, packages[0])
            QTest.qWait(2000)
            cards = visible_of_type(popup, "GeneralCardItem")
            if not cards:
                classes = sorted({i.metaObject().className() for i in walk(popup)})
                stacks = [i for i in walk(popup) if "StackView" in i.metaObject().className()]
                fail("The %s popup did not show general cards after choosing a package; "
                     "stack=%r classes=%r" % (label,
                     stacks[0].property("depth") if stacks else None, classes))
            click_item(scene, cards[0])
            QTest.qWait(120)
            return popup

        # Right-click path: real runtime popup, then package -> general click.
        QTest.mouseClick(scene, Qt.RightButton, Qt.NoModifier,
                         QPoint(int(card0.x()), int(card0.y())))
        QTest.qWait(100)
        first_popup = choose_from_popup("right-click")
        params = scene.property("popupParams")
        if hasattr(params, "toVariant"):
            params = params.toVariant()
        if params["index"] != 0:
            fail("Right-click popup index: %r" % (params["index"],))
        if model.property("generals").toVariant()[0] != "hanjin_test__wei_1":
            fail("Right-click selection did not write back to the model")
        if scene.property("finishCount") != 1:
            fail("Right-click popup did not emit finish")
        QMetaObject.invokeMethod(scene, "closePopup")
        QTest.qWait(50)

        # Long press uses the runtime TapHandler's onLongPressed -> rightClicked.
        long_press_point(scene, card1)
        QTest.qWait(100)
        second_popup = choose_from_popup("long press")
        if second_popup is first_popup:
            fail("Long press reused the previous popup instance")
        params = scene.property("popupParams")
        if hasattr(params, "toVariant"):
            params = params.toVariant()
        if params["index"] != 1:
            fail("Long-press popup index: %r" % (params["index"],))
        if model.property("generals").toVariant()[1] != "hanjin_test__wei_1":
            fail("Long-press selection did not write back to the model")
        if scene.property("finishCount") != 2:
            fail("Long-press popup did not emit finish")

        diagnostics = [w for w in warnings if "font" not in w.lower()]
        if any("roomScene is not defined" in warning for warning in diagnostics):
            fail("GuestRedrawBox still uses bare roomScene")
        print("PASS: runtime FreeAssign opened through Ltk.roomScene from right-click and long press")
        print("PASS: clicked package -> general card; fresh popup, dataModel/index, finish and model writeback verified")
        if diagnostics:
            print("NOTE: QML diagnostics:", diagnostics[-5:])
    finally:
        engine.deleteLater()
        app.processEvents()
        shutil.rmtree(fixture, ignore_errors=True)


if __name__ == "__main__":
    main()

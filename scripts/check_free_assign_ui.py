"""Drive the HanJin free-assignment popup with the runtime model and entry gestures.

The host and card renderer are fixture components. The test opens the real
extension popup, activates its card delegate and checks the loaded portrait.
"""
import os
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_QA = ROOT / ".dev" / "qml-qa"
RUNTIME_ROOT = ROOT / ".dev" / "runtime" / "FreeKill-release"
RUNTIME_FILES = (
    "Fk/Widgets/TapHandler.qml",
    "Fk/Widgets/PopupItem.qml",
    "LunarLtk/Models/GeneralCardModel.qml",
    "LunarLtk/Models/Popups/ChooseGeneralModel.qml",
)
sys.path.insert(0, str(QML_QA))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

from PySide6.QtCore import QMetaObject, QPoint, QPointF, Qt, QUrl, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem  # Registers the QML Item property converter.
from PySide6.QtTest import QTest

FIXTURE_PARTS = {
    "Fk/qmldir": "module Fk\nimport Fk.Base auto\n",
    "Fk/Base/qmldir": "module Fk.Base\nsingleton Lua 1.0 Lua.qml\n"
                      "singleton Config 1.0 Config.qml\nsingleton SkinBank 1.0 SkinBank.qml\n",
    "Fk/Base/Lua.qml": """pragma Singleton
import QtQuick
QtObject {
  property var client: QtObject { function getSettings(key) { return false } }
  property var fk: ({ extensions: { qiao: ["qiao_generals"] } })
  function tr(text) { return text }
  function hasTranslate(text) { return true }
  function ev(code) { return '{"skills":[],"cards":{}}' }
}
""",
    "Fk/Base/Config.qml": """pragma Singleton
import QtQuick
QtObject {
  property bool banChangeSkin: false
  property string libianName: "Arial"
  property var enabledSkins: ({})
  property real winScale: 1
}
""",
    "Fk/Base/SkinBank.qml": """pragma Singleton
import QtQuick
QtObject {
  readonly property url generalsDir: "__GENERALS_DIR__"
  readonly property url generalCardDir: "__CARD_DIR__"
  readonly property url cardDir: "__CARD_DIR__../"
  function getGeneralPicture(name) { return name === "anjiang" ? "__HIDDEN_PORTRAIT__" : generalsDir + name + ".jpg" }
  function getGeneralExtraPic(name, dir) {
    if (dir === "guest/" && ["qiao_heg__qun012", "qiao_heg__han014"].includes(name))
      return generalsDir + dir + name + ".jpg"
  }
  function getGeneralCardDir(name) { return ["han", "jin"].includes(name) ? "__KINGDOM_DIR__" : generalCardDir }
}
""",
    "Fk/Widgets/qmldir": "TapHandler 1.0 TapHandler.qml\nPopupItem 1.0 PopupItem.qml\n",
    "Fk/Components/Common/qmldir": "MetroButton 1.0 MetroButton.qml\nAvatar 1.0 Avatar.qml\nGlowText 1.0 GlowText.qml\n",
    "Fk/Components/Common/Avatar.qml": "import QtQuick\nImage { property string general }\n",
    "Fk/Components/Common/GlowText.qml": """import QtQuick
Text {
  property alias textItem: self
  property Glow glow: Glow {}
  component Glow: QtObject {
    property color color
    property real spread
    property real radius
  }
  id: self
}
""",
    "Fk/Components/Common/MetroButton.qml": """import QtQuick
Rectangle {
  property string text: ""
  property bool checked: false
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
import LunarLtk.Models
QtObject {
  property var roomScene
  property Component cardComp: Component {
    GeneralCardModel {}
  }
  function getAllGeneralPack() { return ["qiao_generals"] }
  function getGenerals(pack) { return ["qiao_heg__jin001", "qiao_heg__qun012"] }
  function getSameGenerals(name) { return [] }
  function getGeneralData(name) {
    const kingdoms = { qiao_heg__qun012: "qun", qiao_heg__han014: "han" };
    return { kingdom: kingdoms[name] ?? "jin", subkingdom: "" };
  }
  function getGeneralDetail(name) {
    return Object.assign(getGeneralData(name), { hp: 4, maxHp: 4, companions: [], skill: [] });
  }
  function processPrompt(prompt) { return prompt }
  function chooseGeneralFilter(rule, name, selected) { return !selected.includes(name) }
  function chooseGeneralFeasible() { return true }
  function createGeneralCardModel(name, values) {
    return cardComp.createObject(null, Object.assign({ name, kingdom: getGeneralData(name).kingdom }, values));
  }
  function isCompanionWith(first, second) { return false }
}
""",
    "LunarLtk/Models/qmldir": "GeneralCardModel 1.0 GeneralCardModel.qml\n",
    "LunarLtk/Components/qmldir": "GeneralCardItem 1.0 GeneralCardItem.qml\n"
                                  "CompactGeneralCardItem 1.0 CompactGeneralCardItem.qml\n"
                                  "CardItem 1.0 CardItem.qml\nPhotoBase 1.0 PhotoBase.qml\nPhoto 1.0 Photo.qml\n",
    "LunarLtk/Components/CompactGeneralCardItem.qml": """import QtQuick
import Fk
Item {
  property var dataModel
  Image {
    property bool useSmallPic: false
    source: SkinBank.getGeneralPicture(parent.dataModel.name)
  }
}
""",
    "LunarLtk/Components/CardItem.qml": """import QtQuick
import Fk
Item {
  width: 93
  height: 130
  property real cardScale: 1
  property var dataModel
  property url cardFrontSource: SkinBank.getGeneralPicture(dataModel.picName.slice(8))
}
""",
    "LunarLtk/Components/PhotoBase.qml": """import QtQuick
import Fk
import LunarLtk.Components.Photo
Item {
  id: photo
  property string general
  property string deputyGeneral
  property Item photoMask: Item { width: 100; height: 160; x: 20 }
  Item {
    property Item maskSource: photo.photoMask
    property Item source: Item {
      Image { source: SkinBank.getGeneralPicture(photo.general) }
      SkinMedia {}
      Image { source: SkinBank.getGeneralPicture(photo.deputyGeneral) }
      SkinMedia {}
    }
  }
}
""",
    "LunarLtk/Components/Photo.qml": """import QtQuick
import Fk
PhotoBase {
  id: photo
  property string role
  Image {
    objectName: "nativeRoleBadge"
    source: SkinBank.getGeneralCardDir(photo.role) + photo.role
  }
}
""",
    "LunarLtk/Components/GeneralCardItem.qml": """import QtQuick
import Fk.Widgets as W
Rectangle {
  id: root
  width: 93
  height: 130
  required property var dataModel
  property url cardFrontSource: dataModel.frontSkin
  readonly property Item cardBg: portrait
  readonly property url renderedPortrait: portrait.source
  readonly property bool portraitReady: portrait.status === Image.Ready
  property bool selectable: true
  property bool draggable: false
  property bool dragging: false
  property bool chosenInBox: false
  property bool autoBack: true
  property real origX: 0
  property real origY: 0
  property real origOpacity: 1
  signal clicked()
  signal rightClicked()
  signal released()
  function goBack(animated) { x = origX; y = origY; opacity = origOpacity }
  Image { id: portrait; anchors.fill: parent; source: root.cardFrontSource }
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
    "LunarLtk/Components/Photo/qmldir": "SkinMedia 1.0 SkinMedia.qml\n",
    "LunarLtk/Components/Photo/SkinMedia.qml": "import QtQuick\nItem {}\n",
    "LunarLtk/Models/Popups/qmldir": "ChooseGeneralModel 1.0 ChooseGeneralModel.qml\n",
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
}

MAIN_QML = """
import QtQuick
import QtQuick.Window
import Fk.Widgets
import LunarLtk
import LunarLtk.Components
import LunarLtk.Models.Popups
import "__QML_DIR__" as Qiao

Window {
  id: scene
  width: 1000
  height: 800
  visible: true
  property var model: null
  property var box: null
  readonly property Item popup: info.item
  property var popupParams: null
  property int finishCount: 0
  readonly property Item first: box?.generalCardList.itemAt(0) ?? null
  readonly property string selectedGeneral: model.result[0] ?? ""
  readonly property alias generalCardPresentation: presentation

  Qiao.GeneralCardPresentation {
    id: presentation
    inRoom: true
    enabledInContext: true
    factions: ({ qiao_heg__qun012: ["han", "qun"] })
  }

  Item {
    id: previews
    x: scene.width + 10
    width: 500
    height: 380

    Photo { id: battlefield; general: "qiao_heg__qun012"; deputyGeneral: "qiao_heg__han014"; role: "qun" }
    Photo { id: opponent; general: "qiao_heg__han014"; deputyGeneral: "qiao_heg__qun012"; role: "han" }
    PhotoBase { id: popupPhoto; general: battlefield.general; deputyGeneral: battlefield.deputyGeneral }
    GeneralCardItem { id: playerDetails; dataModel: Ltk.createGeneralCardModel(battlefield.general) }
    CompactGeneralCardItem { id: compact; dataModel: Ltk.createGeneralCardModel(battlefield.general) }
    CardItem { id: soul; dataModel: ({ known: true, picName: "general:" + battlefield.general }) }
    Qiao.CiPile { id: ci; cardNames: [battlefield.general, battlefield.deputyGeneral] }
    Qiao.QiaoGeneralChoiceBox {
      id: privateChoice
      dataModel: ({
        cards: [battlefield.general], all_cards: [battlefield.general], prompt: "", max: 0,
        disable_cards: [], result: [], ok_options: [], isSearching: false,
      })
    }
  }

  function find(item, match) {
    for (const child of item.children) {
      if (match(child)) return child;
      const nested = find(child, match);
      if (nested) return nested;
    }
    return null;
  }

  function checkPreviews(on, replaced) {
    const faction = replaced ? "han" : "qun";
    const art = (on ? "/guest/" : "/") + battlefield.general + ".jpg";
    const guestArt = source => String(source).includes("/guest/");
    const correct = card => card && card.dataModel.kingdom === faction
      && String(card.cardFrontSource).endsWith(art) && guestArt(card.cardFrontSource) === on;
    const ciCard = find(ci, child => child.objectName === "qiaoCiCard");
    const secondCi = find(ci, child => child.objectName === "qiaoCiCard" && child.index === 1);
    const privateCard = find(privateChoice, child => child.generalName === battlefield.general);
    const compactBadge = find(compact, child => child.source?.toString().endsWith("/" + faction));
    const soulBadge = find(soul, child => child.source?.toString().endsWith("/" + faction));
    const portrait = battlefield.children.filter(child => child.objectName === "qiaoGuestPortrait");
    return correct(playerDetails) && correct(ciCard) && correct(privateCard)
      && secondCi?.dataModel.kingdom === "han" && guestArt(secondCi.cardFrontSource) === on
      && guestArt(compact.children[0].source) === on && compactBadge !== null
      && guestArt(soul.cardFrontSource) === on && soulBadge !== null
      && portrait.length === 2 && guestArt(portrait[0].art.source) === on
      && guestArt(portrait[1].art.source) === on && !portrait[0].skin.visible
      && portrait[0].appearance.factions[0] === faction && portrait[1].appearance.factions[0] === "han";
  }

  function changePortraits(main, deputy) {
    battlefield.general = main;
    battlefield.deputyGeneral = deputy;
  }

  function checkDesktopFactionMarkers() {
    const cardBadge = photo => find(photo, child => child instanceof Qiao.GuestFactionBadges && child.visible);
    const roleBadge = photo => find(photo, child => child.objectName === "nativeRoleBadge" && child.visible
      && String(child.source).endsWith("/" + photo.role));
    return !cardBadge(battlefield) && !cardBadge(opponent) && !!roleBadge(battlefield) && !!roleBadge(opponent)
      && !!cardBadge(popupPhoto);
  }

  function checkHiddenPortraits(main, deputy) {
    const portraits = battlefield.children.filter(child => child.objectName === "qiaoGuestPortrait");
    return portraits.length === 2 && [main, deputy].every((hidden, index) => {
      const portrait = portraits[index];
      return String(portrait.art.source).endsWith("/anjiang.jpg") === hidden
        && (portrait.appearance.factions.length === 0) === hidden;
    });
  }

  function allowOriginalFaction() {
    presentation.factions = {};
  }

  function showInfoPopup(component, params) {
    popupParams = params
    info.setSourceComponent(component, params)
    popup.finish.connect(function() { finishCount += 1 })
    info.open()
  }

  function disableGuestIllustrations() {
    presentation.enabledInContext = false
  }

  PopupItem {
    id: info
    width: 630
    height: 460
    anchors.centerIn: parent
  }

  ChooseGeneralModel {
    id: model
    generals: ["qiao_heg__qun012", "qiao_heg__jin002"]
    choiceNum: 2
    hegemony: true
    prompt: "选择主将与副将"
    extraData: ({
      freeAssign: true,
      guestIllustrations: true,
      offers: ["qiao_heg__qun012", "qiao_heg__jin002"],
      guests: [],
      guestFactions: { qiao_heg__qun012: ["han", "qun"] },
      ascensions: { qiao_heg__jin001: true }
    })
  }

  Component.onCompleted: {
    scene.model = model
    model.initialize()
    // This is the only room route. Do not add a bare roomScene context property.
    Ltk.roomScene = scene
    // Simulate native restoration leaving a cached URL behind, as seen in Qt 6.10.
    const nativeArtwork = battlefield.children.find(child => child.maskSource === battlefield.photoMask).source;
    for (const art of nativeArtwork.children.filter(child => child instanceof Image))
      art.source = art.source;
    presentation.watch(previews)
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
        text = text.replace("__GENERALS_DIR__", (ROOT / "image/generals").as_uri() + "/")
        text = text.replace("__CARD_DIR__", (RUNTIME_ROOT / "image/card/general").as_uri() + "/")
        text = text.replace("__KINGDOM_DIR__", (ROOT / "image/kingdom").as_uri() + "/")
        text = text.replace("__HIDDEN_PORTRAIT__",
                            (RUNTIME_ROOT / "packages/standard/image/generals/anjiang.jpg").as_uri())
        path.write_text(text, encoding="utf-8")
    for rel in RUNTIME_FILES:
        shutil.copyfile(RUNTIME_ROOT / rel, imports / rel)


def walk(item):
    result = [item]
    for child in item.childItems():
        result.extend(walk(child))
    return result


def visible_of_type(root, name):
    return [item for item in walk(root)
            if name in item.metaObject().className() and item.isVisible()]


def center_point(item):
    center = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    return QPoint(int(center.x()), int(center.y()))


def long_press_point(scene, point):
    QTest.mousePress(scene, Qt.LeftButton, Qt.NoModifier, point)
    QTest.qWait(1200)
    QTest.mouseRelease(scene, Qt.LeftButton, Qt.NoModifier, point)


def main():
    warnings = []
    qInstallMessageHandler(lambda kind, context, message: warnings.append(message))
    app = QGuiApplication([])
    engine = QQmlApplicationEngine()
    fixture = Path(tempfile.mkdtemp(prefix="qiao-free-assign-"))
    try:
        write_fixture(fixture)
        engine.addImportPath(str(fixture / "imports"))
        source = (ROOT / "pkg/qiao_mode/qml/GuestRedrawBox.qml").resolve().as_uri()
        engine.loadData(MAIN_QML.replace("__SOURCE__", source)
                        .replace("__QML_DIR__", (ROOT / "pkg/qiao_mode/qml").as_uri()).encode(),
                        QUrl.fromLocalFile(str(fixture / "main.qml")))
        if not engine.rootObjects():
            raise RuntimeError("QML failed to load: " + repr(warnings))
        scene = engine.rootObjects()[0]
        QTest.qWait(200)
        offer = scene.property("first")
        model = scene.property("model")

        def fail(message):
            raise AssertionError(message + "\nQML diagnostics:\n" + "\n".join(warnings[-20:]))

        def choose_from_popup(label, name):
            popup = scene.property("popup")
            if popup is None:
                fail("The %s entry did not create a popup" % label)
            if "QiaoFreeAssign" not in popup.metaObject().className():
                fail("The %s entry created %s, expected QiaoFreeAssign" %
                     (label, popup.metaObject().className()))
            params = scene.property("popupParams").toVariant()
            if params["index"] != 0:
                fail("The %s entry opened the wrong slot: %r" % (label, params["index"]))
            packages = visible_of_type(popup, "ItemDelegate")
            if not packages:
                fail("The %s popup has no package delegate" % label)
            QTest.mouseClick(scene, Qt.LeftButton, Qt.NoModifier, center_point(packages[0]))
            QTest.qWait(400)
            card = next((item for item in visible_of_type(popup, "QiaoGeneralCard")
                         if item.property("dataModel").property("name") == name), None)
            if card is None:
                fail("The %s popup did not show %s" % (label, name))
            preview = card.property("cardFrontSource")
            if not QMetaObject.invokeMethod(card, "clicked"):
                fail(f"Could not activate the {label} popup's delegate for {name}")
            return preview

        def check_offer(name, kingdom, subkingdom, image_path, ascension):
            card_model = offer.property("dataModel")
            identity = tuple(card_model.property(key) for key in ("name", "kingdom", "subkingdom"))
            if identity != (name, kingdom, subkingdom):
                fail(f"Wrong name or factions on the offer for {name}: {identity}")
            expected = ROOT / "image/generals" / image_path
            actual = offer.property("renderedPortrait").toLocalFile()
            if Path(actual) != expected or not offer.property("portraitReady"):
                fail(f"Wrong portrait for {name}: {actual}, expected {expected}")
            badge = next((item for item in walk(offer) if item.objectName() == "qiaoAscensionBadge"), None)
            if badge is None or badge.isVisible() != ascension:
                fail("Wrong ascension badge on the offer for " + name)

        if offer is None:
            fail("Missing candidate card")
        cai = "qiao_heg__qun012"
        sima = "qiao_heg__jin001"
        check_offer(cai, "han", "qun", f"guest/{cai}.jpg", False)
        if not scene.checkPreviews(True, True):
            fail("The room previews did not show guest artwork and factions together")
        if not scene.checkDesktopFactionMarkers():
            fail("Desktop portraits must show only the native role marker, with popup portrait badges preserved")
        scene.changePortraits("anjiang", "anjiang")
        if not scene.checkHiddenPortraits(True, True):
            fail("The concealed battlefield portraits retained a previous artwork or faction")
        scene.changePortraits(cai, "anjiang")
        if not scene.checkHiddenPortraits(False, True):
            fail("Revealing the main general did not leave the deputy portrait concealed")
        scene.changePortraits(cai, "qiao_heg__han014")
        if not scene.checkPreviews(True, True):
            fail("Revealing both generals did not restore their proper artwork and factions")

        QTest.mouseClick(scene, Qt.RightButton, Qt.NoModifier, center_point(offer))
        QTest.qWait(150)
        preview = choose_from_popup("right-click", sima)
        check_offer(sima, "jin", "", f"{sima}.jpg", True)
        if model.property("generals").toVariant()[0] != sima or offer.property("cardFrontSource") != preview:
            fail("Right-click selection did not apply the general and its preview to the offer")
        QTest.qWait(150)
        if scene.property("finishCount") != 1 or scene.property("popup") is not None:
            fail("Right-click popup did not finish and close")

        QTest.mouseClick(scene, Qt.LeftButton, Qt.NoModifier, center_point(offer))
        long_press_point(scene, center_point(offer))
        QTest.qWait(150)
        preview = choose_from_popup("long press", cai)
        check_offer(cai, "han", "qun", f"guest/{cai}.jpg", False)
        if scene.property("selectedGeneral") != cai or offer.property("cardFrontSource") != preview:
            fail("Long-press selection did not refresh the selected slot with its preview")
        QTest.qWait(150)
        if scene.property("finishCount") != 2 or scene.property("popup") is not None:
            fail("Long-press popup did not finish and close")

        scene.allowOriginalFaction()
        check_offer(cai, "qun", "", f"guest/{cai}.jpg", False)
        if not scene.checkPreviews(True, False):
            fail("Cards with a permitted original faction did not keep their faction with guest artwork")

        QMetaObject.invokeMethod(scene, "disableGuestIllustrations")
        check_offer(cai, "qun", "", f"{cai}.jpg", False)
        if not scene.checkPreviews(False, False):
            fail("The room previews did not restore default artwork and printed factions together")
        if not scene.checkDesktopFactionMarkers():
            fail("Toggling guest artwork changed the desktop role markers or popup portrait badges")
        scene.changePortraits("anjiang", "anjiang")
        if not scene.checkHiddenPortraits(True, True):
            fail("Concealing the generals with guest artwork disabled did not show two dark portraits")

        if any("font" not in warning.lower() for warning in warnings):
            fail("Unexpected QML diagnostics")
        print("PASS: right-click and long press refresh the portrait, factions and ascension badge in place")
        print("PASS: disabling guest replacements restores the ordinary portrait and faction")
        print("PASS: room portraits, role details, private choices, Ci, compact cards and general: cards share both displays")
        print("PASS: own and opposing desktop portraits keep native role markers without card faction badges")
    finally:
        engine.deleteLater()
        app.processEvents()
        shutil.rmtree(fixture, ignore_errors=True)


if __name__ == "__main__":
    main()

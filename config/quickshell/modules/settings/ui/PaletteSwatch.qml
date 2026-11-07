// Muestra de una paleta fija (Ajustes › Apariencia › Color › Elegir): medio acento, medio superficie.
// Las pastel tienen pareja clara/oscura (palettes.json "pair"): se muestra la del modo actual y al elegirla no
// se cambia el modo; las demás son de un solo modo y lo fijan (salvo con «Automático»). Lo guarda la sección (picked).
import QtQuick
import "../../.."
import "../../../components"

Item {
    id: sw
    property string key: ""
    property var pals: ({})
    property string current: ""
    property string themeMode: "oscuro"
    readonly property var base: pals[key] ?? ({})
    readonly property var pal: base.pair && pals[base.pair] && !!pals[base.pair].light === Theme.light ? pals[base.pair] : base
    readonly property bool on: current === key
    // mode: "" = no tocar el modo; si no, «claro»/«oscuro» que fija la paleta
    signal picked(string key, string mode)
    width: 28; height: 28
    Rectangle {
        anchors.fill: parent; radius: 14
        color: "transparent"; border.width: sw.on ? 2 : 0; border.color: Theme.t
    }
    Rectangle {
        anchors.centerIn: parent; width: 22; height: 22; radius: 11
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.5; color: sw.base.group === "pastel" ? (sw.pal.light ? sw.pal.pc : sw.pal.p) : (sw.pal.p ?? "transparent") }
            GradientStop { position: 0.501; color: sw.pal.s3 ?? "transparent" }
        }
        border.width: 1; border.color: Qt.alpha(Theme.t, 0.2)
    }
    MouseArea {
        id: sm
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: sw.picked(sw.key, sw.themeMode === "auto" || !!sw.base.pair ? "" : sw.base.light ? "claro" : "oscuro")
    }
    Rectangle {
        visible: sm.containsMouse
        anchors.bottom: parent.top; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
        width: tip.implicitWidth + 12; height: 20; radius: Theme.r(4); color: Theme.s1; border.width: 1; border.color: Theme.ov; z: 5
        Txt { id: tip; anchors.centerIn: parent; text: (sw.base.name ?? "").replace(" · claro", ""); size: 11 }
    }
}

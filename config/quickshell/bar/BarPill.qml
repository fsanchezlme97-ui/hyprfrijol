// Fondo de una píldora de la barra en modo «Archipiélago» (barMode = "archipielago"): cada grupo de módulos
// flota en su propia píldora de vidrio y entre ellas se ve el escritorio. La ventana de la barra solo recibe el
// ratón sobre las píldoras (Bar.qml: máscara con BarH/BarV.pills).
//   BarPill { bar: root.barWindow; x: …; width: …; height: parent.height }
import QtQuick
import ".."
import "../components"

Glass {
    id: pill
    required property var bar
    z: -1
    kind: "bar"
    radius: bar.pillRadius
    shadow: true
    // El filo lo pone el Rectangle de abajo, igual que el borde de las ventanas (no el filo de luz de los paneles)
    showBorder: false
    effects: true
    opacity: bar.emptyWs ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
    Rectangle {
        anchors.fill: parent
        radius: pill.rr
        color: "transparent"
        border.width: pill.bar.pillBorderW
        border.color: pill.bar.pillBorder
        visible: border.width > 0
    }
    // Alerta visual (visualBell) en cada píldora
    Rectangle {
        anchors.fill: parent
        radius: pill.rr
        color: Theme.p
        opacity: pill.bar.bellLevel
    }
}

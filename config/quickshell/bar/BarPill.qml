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
    showBorder: true
    effects: true
    opacity: bar.emptyWs ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.dur } }
    // Alerta visual (visualBell) en cada píldora
    Rectangle {
        anchors.fill: parent
        radius: pill.rr
        color: Theme.p
        opacity: pill.bar.bellLevel
    }
}

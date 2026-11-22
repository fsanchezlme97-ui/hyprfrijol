// Fondo de una píldora de la barra en modo «Archipiélago» (barMode = "archipielago"): cada grupo de módulos
// flota en su propia píldora de vidrio y entre ellas se ve el escritorio. La ventana de la barra solo recibe el
// ratón sobre las píldoras (Bar.qml: máscara con BarH/BarV.pills).
//   BarPill { bar: root.barWindow; x: …; width: …; height: parent.height }
// Forma: el radio sale de Bar.pillRadius (esquinas de las ventanas + Ajustes › Barra › Esquinas); el contorno se
// dibuja con curvas Bézier y suavizado (CurveRenderer), sin escalones ni tramos rectos.
import QtQuick
import ".."

BarBg {
    id: pill
    required property var bar
    z: -1
    radius: bar.pillRadius
    shadow: true
    bellLevel: bar.bellLevel
    borderW: bar.pillBorderW
    borderColor: bar.pillBorder
    feather: 1 / bar.k
}

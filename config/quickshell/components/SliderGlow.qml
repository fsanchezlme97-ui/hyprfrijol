// Resplandor del relleno de un deslizador, del color del tema (como un neón suave alrededor de lo lleno).
// Se activa en Ajustes › Animaciones y efectos › «Deslizadores con brillo» (sliderGlow). El deslizador no debe
// recortar (clip) para que el halo salga por fuera.
//   Rectangle { id: fill … }  SliderGlow { target: fill }   (antes que el relleno: el halo queda debajo)
import QtQuick
import QtQuick.Effects
import ".."

RectangularShadow {
    id: root
    property Item target
    property color glow: Theme.p
    visible: Settings.get("sliderGlow", true) === true && !!target && target.visible && target.width > 1
    x: target?.x ?? 0; y: target?.y ?? 0
    width: target?.width ?? 0; height: target?.height ?? 0
    radius: target?.radius ?? 0
    blur: Math.max(10, height * 0.7)
    spread: 0
    color: Qt.alpha(glow, Theme.light ? 0.40 : 0.55)
}

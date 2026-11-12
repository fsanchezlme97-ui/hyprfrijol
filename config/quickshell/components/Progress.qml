// Barra de progreso común (descargas, modelos del dictado, instalación de apps, pomodoro, impresora…).
// El dato llega a saltos: las descargas se leen cada 1,5 s, la instalación avisa por pasos, el pomodoro cada segundo.
// Una animación corta llegaba al valor y la barra se quedaba quieta hasta el siguiente: se veía «pausada». Aquí el
// relleno va en línea recta hasta el valor nuevo durante «period» (lo que tarda en llegar el siguiente dato), así no
// se para. Con «ceiling» (el final del paso en curso) sigue avanzando despacio mientras el paso tarda, sin pasar de
// ahí. Mientras trabaja (busy) un brillo recorre lo ya hecho; sin valor conocido (value < 0) un tramo va y viene.
// Si el valor baja (otra descarga, reinicio) salta sin animar. Con «Reducir movimiento»: salta y sin brillo.
//   Progress { value: it.progress; period: 1500; busy: live }
//   Progress { value: (i - 1) / n; ceiling: i / n; busy: true }      // por pasos
import QtQuick
import ".."

Item {
    id: root
    property real value: 0              // 0–1; < 0 = no se sabe (indeterminado)
    property real ceiling: -1           // ≥ 0: hasta dónde puede avanzar solo mientras espera el dato siguiente
    property int period: 1000           // ms entre datos: lo que tarda el relleno en alcanzar un valor nuevo
    property int creepMs: 60000         // lo que tardaría en llegar a «ceiling» (se frena al acercarse)
    property bool busy: true            // brillo mientras trabaja (pausado o en cola: false)
    property color color: Theme.p
    property color track: Qt.alpha(Theme.t, 0.12)
    property real radius: height / 2
    implicitHeight: 4
    implicitWidth: 120

    readonly property bool indeterminate: value < 0
    readonly property bool moving: !Theme.still
    property real shown: Math.max(0, Math.min(1, value))

    function target(): real { return Math.max(0, Math.min(1, value)); }
    function follow(): void {
        const v = target();
        creep.stop();
        if (!moving || v < shown - 0.0005) { run.stop(); shown = v; startCreep(); return; }
        run.to = v; run.duration = Math.max(120, period); run.restart();
    }
    function startCreep(): void {
        if (!moving || !busy || ceiling <= shown + 0.001 || indeterminate) return;
        creep.to = Math.min(1, shown + (ceiling - shown) * 0.9);
        creep.duration = creepMs;
        creep.restart();
    }
    onValueChanged: follow()
    onCeilingChanged: if (!run.running) { creep.stop(); startCreep(); }
    onBusyChanged: if (!busy) creep.stop(); else if (!run.running) startCreep()
    Component.onCompleted: shown = target()
    NumberAnimation { id: run; target: root; property: "shown"; easing.type: Easing.Linear; onFinished: root.startCreep() }
    NumberAnimation { id: creep; target: root; property: "shown"; easing.type: Easing.OutCubic }

    // pista
    Rectangle { anchors.fill: parent; radius: root.radius; color: root.track }

    // relleno (con su brillo dentro)
    Item {
        visible: !root.indeterminate
        width: Math.max(root.shown > 0 ? root.height : 0, parent.width * root.shown)
        height: parent.height
        clip: true
        Rectangle { anchors.fill: parent; radius: root.radius; color: root.color }
        Rectangle {
            id: sheen
            visible: root.busy && root.moving && root.shown > 0.02 && root.shown < 0.999
            width: Math.max(24, parent.width * 0.35)
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.alpha("white", Theme.light ? 0.45 : 0.28) }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: sheen.visible
                loops: Animation.Infinite
                from: -sheen.width; to: sheen.parent.width
                duration: 1600
                easing.type: Easing.InOutQuad
            }
        }
    }

    // sin valor: un tramo que va de lado a lado
    Item {
        anchors.fill: parent
        visible: root.indeterminate
        clip: true
        Rectangle {
            id: seg
            width: parent.width * 0.32
            height: parent.height
            radius: root.radius
            color: root.color
            x: root.moving ? -width : (parent.width - width) / 2
            NumberAnimation on x {
                running: root.indeterminate && root.moving && root.visible
                loops: Animation.Infinite
                from: -seg.width; to: seg.parent.width
                duration: 1300
                easing.type: Easing.InOutCubic
            }
        }
    }
}

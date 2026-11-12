// Transformación entre paneles: al saltar de uno a otro sin cerrar (de la música al clima con un clic en la barra,
// del clima al centro de control…), el que se va se estira hasta la caja del que llega mientras se desvanece, y el
// que llega nace con la caja del que se va y crece hasta la suya. Se ve una sola tarjeta que cambia de forma, no un
// cierre y una apertura seguidos. Con «Reducir movimiento» (Theme.durLong = 0) no hace nada.
// Lo usan components/Overlay (morph: true) y modules/widgets/ChipPopup (siempre):
//   Morph { id: morph; target: panel; view: win.view; screenName: win.screen?.name ?? "" }
//   panel.transform: [ …entrada…, Scale { origin.x: 0; origin.y: 0; xScale: morph.sx; yScale: morph.sy },
//                      Translate { x: morph.tx; y: morph.ty } ]      y la opacidad del panel × morph.op
// El dueño llama a leave() al ocultarse (true → no cierres aún: se queda quieto hasta que llegue el otro) y a
// enter() cuando su panel ya está dibujado (true → no hagas la entrada normal: p = 1 sin animar).
// Shell.leaving es la vista que se acaba de sustituir; Shell.morphBoxes, la caja de cada panel al irse.
import QtQuick
import ".."

Item {
    id: m
    required property Item target
    required property string view
    property string screenName: ""
    property bool on: true                         // false: este panel no se transforma (Overlay sin morph)
    readonly property bool enabled_: on && Theme.durLong > 0
    property string role: ""                       // "" · "hold" (esperando al otro) · "in" · "out"
    readonly property bool busy: role !== ""
    property var box: null                         // la otra caja: de dónde viene (in) o adónde va (out)
    property real k: 0                             // progreso 0 → 1
    signal finished()                              // salida terminada: el dueño se oculta sin animar
    signal released()                              // el otro no se transforma: el dueño cierra como siempre

    // De mi caja a la otra (in: k = 0 está en la otra; out: k = 1 está en la otra)
    readonly property real f: role === "in" ? 1 - k : role === "out" ? k : 0
    readonly property real sx: box && target.width > 0 ? 1 + (box.w / target.width - 1) * f : 1
    readonly property real sy: box && target.height > 0 ? 1 + (box.h / target.height - 1) * f : 1
    readonly property real tx: box ? (box.x - target.x) * f : 0
    readonly property real ty: box ? (box.y - target.y) * f : 0
    readonly property real op: role === "in" ? Math.min(1, k * 2.5) : role === "out" ? Math.max(0, 1 - k * 2) : 1

    function myBox(): var { return { x: target.x, y: target.y, w: target.width, h: target.height, screen: screenName }; }

    Component.onCompleted: if (on) Shell.morphViews[view] = true

    // Me sustituyen: guardo mi caja y espero un ciclo a saber si el que llega se transforma
    function leave(): bool {
        if (!enabled_ || Shell.leaving !== view || Shell.view === "") return false;
        Shell.morphBoxes[view] = myBox();
        role = "hold"; k = 0; box = null;
        Qt.callLater(() => { if (role === "hold" && !Shell.morphViews[Shell.view]) release(); });
        holdTimer.restart();
        return true;
    }
    function release(): void { holdTimer.stop(); delete Shell.morphBoxes[view]; role = ""; released(); }
    Timer { id: holdTimer; interval: 400; onTriggered: if (m.role === "hold") m.release() }   // por si el otro no llega a dibujarse

    // Llego en lugar de otro: nazco con su caja
    function enter(): bool {
        const from = Shell.leaving, b = from ? Shell.morphBoxes[from] : null;
        if (!enabled_ || !b || b.screen !== screenName || from === view) return false;
        box = b; role = "in"; k = 0;
        Shell.morphStarted(from, view, myBox());
        run.restart();
        return true;
    }
    Connections {
        target: Shell
        function onMorphStarted(from, to, b) {
            if (from !== m.view || m.role !== "hold") return;
            holdTimer.stop();
            m.box = b; m.role = "out"; m.k = 0;
            run.restart();
        }
        // Vuelven a abrir este mientras se iba: deja de transformarse
        function onViewChanged() { if (Shell.view === m.view && (m.role === "hold" || m.role === "out")) { run.stop(); holdTimer.stop(); m.role = ""; } }
    }
    NumberAnimation {
        id: run
        target: m; property: "k"; from: 0; to: 1
        duration: Theme.durLong
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease
        onFinished: {
            if (m.role === "out") { delete Shell.morphBoxes[m.view]; m.finished(); }
            m.role = ""; m.box = null;
        }
    }
}

// Onda de audio en el centro de la barra (cava, 48 bandas a 30 fps).
// Rendimiento: «barras» son 48 rectángulos que pinta la GPU (antes un Canvas pintado por la CPU y subido como imagen
// en cada fotograma: ~6 % de CPU con música); «onda» y «agujas» van en Canvas. Todo se mueve a 30 fps.
// Estilos (Ajustes › Barra › Onda de audio, ajuste "waveStyle"):
//   barras  barras redondeadas simétricas: cuerpo en primario tenue y la punta en terciario (por defecto)
//   onda    curva suave rellena, simétrica
//   agujas  líneas finas desde el centro con una gota en cada punta
// Colores: los del tema, del primario (izquierda) al terciario (derecha), sin atenuar.
// Movimiento suave: cada banda sigue a cava con un suavizado (sube rápido y baja algo más despacio, sin gravedad ni
// marcas de pico que caen), así no hay «lluvia» de barras cayendo.
// Estados del asistente, con los colores del tema (el estado lo dice sobre todo el movimiento) y siempre como onda
// (las barras son solo para el audio del equipo: con «barras» elegido, la voz se dibuja como «onda»):
//   escucha  primario: el nivel del micrófono (dictado o conversación), lo más reciente en el centro
//   piensa   primario apagado: una ola ancha que va y viene mientras prepara la respuesta (sin animaciones: quieta)
//   habla    terciario: la voz del asistente (cava)
// Sin asistente: la música del equipo; en silencio, una fila de puntos tenues (se pinta una vez). Clic: controles de
// música. Clic central: reproducir/pausar.
// Rueda: volumen.
// Muestra fija (tarjetas de Ajustes › Barra › Onda de audio): Waveform { forceKind: "cinta"; sample: [0.2, 0.5, …] }
// dibuja ese estilo con esos niveles, sin cava, sin animación y sin clics.
import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    property real barHeight: 32
    property string forceKind: ""
    property var sample: null
    readonly property bool isPreview: sample !== null
    // Solo barras, onda y agujas (0.28.0): los estilos retirados se dibujan como barras
    readonly property string kind: { const v = forceKind || Settings.get("waveStyle", "barras"); return ["barras", "onda", "agujas"].includes(v) ? v : "barras"; }
    readonly property string aiState: isPreview ? "" : Shell.aiSpeaking ? "habla"
        : Shell.aiBusy || Shell.dictPhase === "trans" ? "piensa"
        : Shell.dictPhase === "rec" ? "escucha" : ""
    readonly property color stateColor: aiState === "habla" ? Theme.ter : aiState === "piensa" ? thinkColor : Theme.p
    // primario mezclado con el fondo de la barra (opaco: el degradado del Canvas le cambia el alfa)
    readonly property color thinkColor: Qt.tint(Theme.p, Qt.alpha(Theme.glass, 0.45))
    property real thinkT: 0
    readonly property int n: Cava.count
    readonly property string drawKind: kind === "barras" && aiState !== "" ? "onda" : kind
    readonly property real gap: kind === "barras" ? 1.6 : 0
    readonly property real bw: kind === "barras" ? 2.6 : 0
    readonly property real waveW: kind === "barras" ? n * (bw + gap) - gap : 200
    implicitWidth: waveW + 20
    implicitHeight: Math.max(20, barHeight - 8)
    radius: Theme.ctl(height)
    color: hover.hovered && !isPreview ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    readonly property bool live: isPreview || aiState !== "" || Cava.active && (Media.playing || peak > 0.02)
    property real peak: 0
    property var disp: isPreview ? sample.slice() : Array(n).fill(0)
    readonly property bool resting: !live && peak < 0.01
    property bool idlePainted: false
    readonly property var paintKey: [Theme.p, Theme.ter, kind, aiState]
    onPaintKeyChanged: { idlePainted = false; cv.requestPaint(); }

    // Nadie la ve (pantalla completa, modo juego, sesión bloqueada o barra escondida): ni animación ni cava, como el
    // icono del tiempo (WeatherChip). Antes seguía a 30 fps bajo el juego o el bloqueo toda la noche.
    readonly property bool covered: Shell.gameMode || Shell.locked || Shell.barHidden
                                    || WinMode.hasFullscreen(root.QsWindow.window?.screen?.name ?? "")
    UseCounter { target: Cava; active: root.visible && !root.covered && !root.isPreview }

    readonly property bool gpuBars: drawKind === "barras"
    FrameAnimation {
        running: root.visible && !root.covered && !root.isPreview && (Cava.active || root.peak > 0.002 || root.aiState !== "")
        property real acc: 0
        onTriggered: {
            // 30 fps: un fotograma de cada dos (con el tiempo acumulado, para que la caída no se ralentice)
            acc += frameTime;
            if (acc < 1 / 32) return;
            const src = Cava.bars, d = root.disp, st = root.aiState, lv = Shell.micLevels ?? [], half = (root.n - 1) / 2;
            const dt = Math.min(0.08, acc);
            acc = 0;
            if (st === "piensa" && !Theme.still) root.thinkT += dt;
            const tt = root.thinkT;
            const rise = 1 - Math.exp(-dt * 28), fall = 1 - Math.exp(-dt * 11);
            const pos = half + half * 0.85 * Math.sin(tt * 1.5);
            let pk = 0;
            for (let i = 0; i < root.n; i++) {
                let t;
                if (st === "escucha") {          // del centro hacia fuera: del nivel más nuevo al más viejo
                    const k = Math.abs(i - half) / half, j = lv.length - 1 - Math.floor(k * (lv.length - 1) + 0.5);
                    t = Math.min(1, (lv[j] ?? 0) * (1 - 0.35 * k) * (0.8 + 0.2 * Math.sin(i * 1.7)));
                } else if (st === "piensa") {
                    t = 0.1 + 0.6 * Math.exp(-(((i - pos) / 8) ** 2));   // ola ancha de lado a lado
                } else t = Math.min(1, src[i] ?? 0);
                d[i] += (t - d[i]) * (t >= d[i] ? rise : fall);
                if (d[i] > pk) pk = d[i];
            }
            root.peak = pk;
            // En reposo los puntos no cambian: se pintan una vez y no en cada fotograma
            const idle = !root.live && pk < 0.01;
            if (idle && root.idlePainted) return;
            root.idlePainted = idle;
            if (root.gpuBars) root.layoutBars(idle); else cv.requestPaint();
        }
    }

    // ---- «barras» en la GPU: alto de cada rectángulo puesto a mano (sin 48 enlaces que se reevalúen)
    readonly property real barsH: height - 6
    function amp(v: real): real { return Math.pow(Math.min(1, v * 1.15), 0.8); }
    function layoutBars(idle: bool): void {
        for (let i = 0; i < n; i++) {
            const it = bars.itemAt(i);
            if (!it) continue;
            const b = it.bar;
            if (idle) { b.visible = i % 2 === 0; b.height = 2.2; b.opacity = 0.45; continue; }
            b.visible = true; b.opacity = 1;
            // un poco de la vecina: el perfil se ve como una curva y no como dientes sueltos
            const a = disp[i] * 0.6 + ((disp[i - 1] ?? disp[i]) + (disp[i + 1] ?? disp[i])) * 0.2;
            b.height = Math.max(2.6, amp(a) * (barsH - 2));
        }
    }
    Item {
        id: barsBox
        visible: root.gpuBars
        anchors.centerIn: parent
        width: root.waveW
        height: root.barsH
        Repeater {
            id: bars
            model: root.kind === "barras" ? root.n : 0   // se quedan aunque la voz pase a onda
            Item {
                id: slot
                required property int index
                readonly property Item bar: barR
                x: index * (root.bw + root.gap)
                width: root.bw; height: parent.height
                Rectangle {
                    id: barR
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 2.2
                    radius: width / 2
                    visible: slot.index % 2 === 0
                    opacity: 0.45
                    // punta de color: terciario en los extremos, primario tenue en el centro (crece con la barra)
                    // del primario a la izquierda al terciario a la derecha; el centro algo más suave
                    readonly property color hue: Qt.tint(Theme.p, Qt.alpha(Theme.ter, slot.index / (root.n - 1)))
                    gradient: Gradient {
                        GradientStop { position: 0; color: barR.hue }
                        GradientStop { position: 0.5; color: Qt.alpha(barR.hue, 0.7) }
                        GradientStop { position: 1; color: barR.hue }
                    }
                }
            }
        }
        Component.onCompleted: root.layoutBars(!root.isPreview)
    }

    Canvas {
        id: cv
        visible: !root.gpuBars
        anchors.centerIn: parent
        width: root.waveW
        height: parent.height - 6
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, mid = h / 2, d = root.disp, n = root.n;
            const ai = root.aiState !== "", sc = root.stateColor;
            // asistente: su color, más tenue a los lados; música: punta de color (terciario arriba y abajo)
            const g = ctx.createLinearGradient(0, 0, w, 0);
            g.addColorStop(0, ai ? Qt.alpha(sc, 0.7) : Theme.p);
            g.addColorStop(0.5, ai ? sc : Qt.tint(Theme.p, Qt.alpha(Theme.ter, 0.5)));
            g.addColorStop(1, ai ? Qt.alpha(sc, 0.7) : Theme.ter);
            ctx.fillStyle = g;
            ctx.strokeStyle = g;
            // Las bandas graves (izquierda) suelen dominar: se reparte la altura con una ligera curva
            // Con la IA en marcha, un mínimo: en silencio (pausas al hablar, micrófono callado) la onda se seguía viendo
            const amp = (i) => Math.max(ai ? 0.12 : 0, root.amp(d[i]));
            if (root.resting) {
                // Reposo: puntos tenues
                ctx.globalAlpha = 0.45;
                for (let x = 3; x < w; x += 12) { ctx.beginPath(); ctx.arc(x, mid, 1.1, 0, Math.PI * 2); ctx.fill(); }
                return;
            }
            {
                const pts = [];
                for (let i = 0; i < n; i++) pts.push([i / (n - 1) * w, amp(i) * (mid - 1)]);
                const curve = (sign) => {
                    ctx.moveTo(0, mid);
                    for (let i = 0; i < n - 1; i++) {
                        const [x0, a0] = pts[i], [x1, a1] = pts[i + 1], xm = (x0 + x1) / 2;
                        ctx.quadraticCurveTo(x0, mid + sign * a0, xm, mid + sign * (a0 + a1) / 2);
                    }
                    ctx.lineTo(w, mid);
                };
                if (root.drawKind === "agujas") {
                    ctx.lineWidth = 1; ctx.lineCap = "round";
                    for (let i = 0; i < n; i += 2) {
                        const [x, a] = pts[i];
                        ctx.globalAlpha = 0.55; ctx.beginPath(); ctx.moveTo(x, mid - a); ctx.lineTo(x, mid + a); ctx.stroke();
                        ctx.globalAlpha = 1; ctx.beginPath(); ctx.arc(x, mid - a, 1.3, 0, Math.PI * 2); ctx.arc(x, mid + a, 1.3, 0, Math.PI * 2); ctx.fill();
                    }
                } else {   // onda rellena (también la voz del asistente con «barras»)
                    ctx.globalAlpha = 0.9;
                    ctx.beginPath(); curve(-1); curve(1); ctx.fill();
                }
            }
        }
    }
    Connections { target: Theme; function onPChanged() { cv.requestPaint(); } function onTerChanged() { cv.requestPaint(); } }
    onDrawKindChanged: { idlePainted = false; if (gpuBars) Qt.callLater(() => layoutBars(!live)); else cv.requestPaint(); }

    HoverHandler { id: hover; enabled: !root.isPreview; onHoveredChanged: if (hovered) Shell.preload("musica") }
    MouseArea {
        enabled: !root.isPreview
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onPressed: m => m.button === Qt.MiddleButton ? Media.toggle() : Shell.toggle("musica")
        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}

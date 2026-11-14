// Onda de audio en el centro de la barra (cava, 48 bandas a 30 fps).
// Rendimiento: «barras» son 48 rectángulos que pinta la GPU (antes un Canvas pintado por la CPU y subido como imagen
// en cada fotograma: ~6 % de CPU con música); «onda» y «línea» siguen en Canvas. Todo se mueve a 30 fps.
// Estilos (Ajustes › Barra › Onda de audio, ajuste "waveStyle"):
//   barras  barras redondeadas simétricas con degradado primario → terciario (por defecto)
//   onda    curva suave rellena, simétrica
//   linea   una sola línea fina que oscila
// Cada fotograma se acerca al valor de cava con ataque rápido y caída suave, así se mueve fluido y sin retraso.
// Estados del asistente, cada uno con su color fijo (Theme.aiListen/aiThink/aiSpeak) y en el estilo elegido:
//   escucha  verde: el nivel del micrófono (dictado o conversación), lo más reciente en el centro
//   piensa   azul: una ola que recorre las barras mientras prepara la respuesta (sin animaciones: quieta)
//   habla    morado: la voz del asistente (cava)
// Sin asistente: la música del equipo con los colores del tema; en silencio, una línea de puntos tenue. Clic: controles de música. Clic central: reproducir/pausar.
// Rueda: volumen.
import QtQuick
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    property real barHeight: 32
    readonly property string kind: Settings.get("waveStyle", "barras")
    readonly property string aiState: Shell.aiSpeaking ? "habla"
        : Shell.aiConvState === "piensa" || Shell.aiBusy || Shell.dictPhase === "trans" ? "piensa"
        : Shell.dictPhase === "rec" || Shell.aiConvState === "escucha" ? "escucha" : ""
    readonly property color stateColor: aiState === "habla" ? Theme.aiSpeak : aiState === "piensa" ? Theme.aiThink : Theme.aiListen
    property real thinkT: 0
    readonly property int n: Cava.count
    readonly property real gap: kind === "barras" ? 1.6 : 0
    readonly property real bw: kind === "barras" ? 2.6 : 0
    readonly property real waveW: kind === "barras" ? n * (bw + gap) - gap : 200
    implicitWidth: waveW + 20
    implicitHeight: Math.max(20, barHeight - 8)
    radius: Theme.ctl(height)
    color: hover.hovered ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    readonly property bool live: aiState !== "" || Cava.active && (Media.playing || peak > 0.02)
    property real peak: 0
    property var disp: Array(n).fill(0)
    property bool idlePainted: false
    readonly property var paintKey: [Theme.p, Theme.ter, kind, aiState]
    onPaintKeyChanged: { idlePainted = false; cv.requestPaint(); }

    UseCounter { target: Cava; active: root.visible }

    readonly property bool gpuBars: kind === "barras"
    FrameAnimation {
        running: root.visible && (Cava.active || root.peak > 0.002 || root.aiState !== "")
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
            const up = 1 - Math.exp(-dt * 38), down = 1 - Math.exp(-dt * 9);
            let pk = 0;
            for (let i = 0; i < root.n; i++) {
                let t;
                if (st === "escucha") {          // del centro hacia fuera: del nivel más nuevo al más viejo
                    const k = Math.abs(i - half) / half, j = lv.length - 1 - Math.floor(k * (lv.length - 1) + 0.5);
                    t = Math.min(1, (lv[j] ?? 0) * (1 - 0.35 * k) * (0.8 + 0.2 * Math.sin(i * 1.7)));
                } else if (st === "piensa") {
                    t = 0.12 + 0.55 * Math.pow(0.5 + 0.5 * Math.sin(tt * 4.2 - i * 0.36), 2) * (0.7 + 0.3 * Math.sin(tt * 1.3 + i * 0.13));
                } else t = Math.min(1, src[i] ?? 0);
                d[i] += (t - d[i]) * (t > d[i] ? up : down);
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
    function barColor(f: real): color {
        if (aiState !== "") { const c = stateColor; return Qt.rgba(c.r, c.g, c.b, 1 - 0.3 * Math.abs(f * 2 - 1)); }
        const p = Theme.p, t = Theme.ter;
        if (f < 0.5) return Qt.rgba(p.r, p.g, p.b, 0.75 + f * 0.5);
        const k = (f - 0.5) * 2;
        return Qt.rgba(p.r + (t.r - p.r) * k, p.g + (t.g - p.g) * k, p.b + (t.b - p.b) * k, 1 - 0.15 * k);
    }
    function amp(i: int): real { return Math.pow(Math.min(1, disp[i] * 1.15), 0.8); }
    function layoutBars(idle: bool): void {
        for (let i = 0; i < n; i++) {
            const it = bars.itemAt(i);
            if (!it) continue;
            if (idle) { it.visible = i % 2 === 0; it.height = 2.2; it.opacity = 0.45; continue; }
            it.visible = true; it.opacity = 1;
            it.height = Math.max(2.6, amp(i) * (barsH - 2));
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
            model: root.gpuBars ? root.n : 0
            Rectangle {
                required property int index
                x: index * (root.bw + root.gap)
                anchors.verticalCenter: parent.verticalCenter
                width: root.bw; height: 2.2
                radius: width / 2
                visible: index % 2 === 0
                opacity: 0.45
                // degradado de la barra entera, como el del Canvas: primario 75 % → primario → terciario 85 %
                color: root.barColor(index / (root.n - 1))
            }
        }
        Component.onCompleted: root.layoutBars(true)
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
            const g = ctx.createLinearGradient(0, 0, w, 0);
            const ai = root.aiState !== "", sc = root.stateColor;
            g.addColorStop(0, Qt.alpha(ai ? sc : Theme.p, 0.7));
            g.addColorStop(0.5, ai ? sc : Theme.p);
            g.addColorStop(1, Qt.alpha(ai ? sc : Theme.ter, ai ? 0.7 : 0.85));
            ctx.fillStyle = g;
            ctx.strokeStyle = g;
            // Las bandas graves (izquierda) suelen dominar: se reparte la altura con una ligera curva
            const amp = (i) => Math.pow(Math.min(1, d[i] * 1.15), 0.8);
            if (!root.live && root.peak < 0.01) {
                // Reposo: puntos tenues
                ctx.globalAlpha = 0.45;
                const step = root.kind === "barras" ? root.bw + root.gap : 6;
                for (let x = step / 2; x < w; x += step * 2) { ctx.beginPath(); ctx.arc(x, mid, 1.1, 0, Math.PI * 2); ctx.fill(); }
                return;
            }
            if (root.kind === "barras") {
                for (let i = 0; i < n; i++) {
                    const bh = Math.max(2.6, amp(i) * (h - 2));
                    const x = i * (root.bw + root.gap), y = mid - bh / 2, r = root.bw / 2;
                    ctx.beginPath();
                    ctx.moveTo(x, y + r); ctx.arc(x + r, y + r, r, Math.PI, 0);
                    ctx.lineTo(x + root.bw, y + bh - r); ctx.arc(x + r, y + bh - r, r, 0, Math.PI);
                    ctx.closePath(); ctx.fill();
                }
            } else {
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
                if (root.kind === "onda") {
                    ctx.globalAlpha = 0.9;
                    ctx.beginPath(); curve(-1); curve(1); ctx.fill();
                } else {
                    ctx.lineWidth = 1.6; ctx.lineJoin = "round";
                    ctx.beginPath(); curve(-1); ctx.stroke();
                    ctx.globalAlpha = 0.35; ctx.beginPath(); curve(1); ctx.stroke();
                }
            }
        }
    }
    Connections { target: Theme; function onPChanged() { cv.requestPaint(); } function onTerChanged() { cv.requestPaint(); } }
    onKindChanged: { idlePainted = false; if (gpuBars) Qt.callLater(() => layoutBars(!live)); else cv.requestPaint(); }

    HoverHandler { id: hover; onHoveredChanged: if (hovered) Shell.preload("musica") }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onPressed: m => m.button === Qt.MiddleButton ? Media.toggle() : Shell.toggle("musica")
        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}

// Onda de audio en el centro de la barra (cava, 48 bandas a 30 fps).
// Rendimiento: «barras» son 48 rectángulos que pinta la GPU (antes un Canvas pintado por la CPU y subido como imagen
// en cada fotograma: ~6 % de CPU con música); «onda» y «línea» siguen en Canvas. Todo se mueve a 30 fps.
// Estilos (Ajustes › Barra › Onda de audio, ajuste "waveStyle"):
//   barras  barras redondeadas simétricas: cuerpo en primario tenue y la punta en terciario (por defecto)
//   onda    curva suave rellena, simétrica
//   linea   una sola línea fina que oscila
//   zigzag  picos rectos que alternan arriba y abajo, como un trazo de osciloscopio
//   cinta   dos curvas desfasadas que se cruzan, con el hueco relleno: una cinta que se retuerce
//   escalones  columnas de bloques (vúmetro): la altura va por escalones
//   capas   tres ondas suaves rellenas superpuestas, cada una más tenue y ancha
// Movimiento con gravedad: cada barra sube al instante con cava y cae acelerando; en «barras», una marca de pico se
// queda arriba y baja despacio.
// Estados del asistente, con los colores del tema (el estado lo dice sobre todo el movimiento) y siempre como onda
// (las barras son solo para el audio del equipo: con «barras» elegido, la voz se dibuja como «onda»):
//   escucha  primario: el nivel del micrófono (dictado o conversación), lo más reciente en el centro
//   piensa   primario apagado: una ola ancha que va y viene mientras prepara la respuesta (sin animaciones: quieta)
//   habla    terciario: la voz del asistente (cava)
// Sin asistente: la música del equipo; en silencio, una fila de puntos tenues (se pinta una vez). Clic: controles de
// música. Clic central: reproducir/pausar.
// Rueda: volumen.
import QtQuick
import Quickshell
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
    color: hover.hovered ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }

    readonly property bool live: aiState !== "" || Cava.active && (Media.playing || peak > 0.02)
    property real peak: 0
    property var disp: Array(n).fill(0)
    property var vel: Array(n).fill(0)     // velocidad de caída de cada barra (gravedad)
    property var cap: Array(n).fill(0)     // marca de pico de cada barra
    readonly property bool resting: !live && peak < 0.01
    property bool idlePainted: false
    readonly property var paintKey: [Theme.p, Theme.ter, kind, aiState]
    onPaintKeyChanged: { idlePainted = false; cv.requestPaint(); }

    // Nadie la ve (pantalla completa, modo juego, sesión bloqueada o barra escondida): ni animación ni cava, como el
    // icono del tiempo (WeatherChip). Antes seguía a 30 fps bajo el juego o el bloqueo toda la noche.
    readonly property bool covered: Shell.gameMode || Shell.locked || Shell.barHidden
                                    || WinMode.hasFullscreen(root.QsWindow.window?.screen?.name ?? "")
    UseCounter { target: Cava; active: root.visible && !root.covered }

    readonly property bool gpuBars: drawKind === "barras"
    FrameAnimation {
        running: root.visible && !root.covered && (Cava.active || root.peak > 0.002 || root.aiState !== "")
        property real acc: 0
        onTriggered: {
            // 30 fps: un fotograma de cada dos (con el tiempo acumulado, para que la caída no se ralentice)
            acc += frameTime;
            if (acc < 1 / 32) return;
            const src = Cava.bars, d = root.disp, v = root.vel, c = root.cap, st = root.aiState, lv = Shell.micLevels ?? [], half = (root.n - 1) / 2;
            const dt = Math.min(0.08, acc);
            acc = 0;
            if (st === "piensa" && !Theme.still) root.thinkT += dt;
            const tt = root.thinkT;
            const rise = 1 - Math.exp(-dt * 60), g = 3.2 * dt, capFall = 0.32 * dt;
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
                if (t >= d[i]) { d[i] += (t - d[i]) * rise; v[i] = 0; }
                else { v[i] += g; d[i] = Math.max(t, d[i] - v[i] * dt); }
                c[i] = Math.max(d[i], c[i] - capFall);
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
            if (idle) { b.visible = i % 2 === 0; b.height = 2.2; b.opacity = 0.45; it.capT.visible = it.capB.visible = false; continue; }
            b.visible = true; b.opacity = 1;
            const bh = Math.max(2.6, amp(disp[i]) * (barsH - 2)), ch = amp(cap[i]) * (barsH - 2), showCap = ch > bh + 1.5;
            b.height = bh;
            it.capT.visible = it.capB.visible = showCap;
            if (showCap) { it.capT.y = barsH / 2 - ch / 2 - 0.6; it.capB.y = barsH / 2 + ch / 2 - 0.5; }
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
                readonly property Item capT: capTop
                readonly property Item capB: capBot
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
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.ter }
                        GradientStop { position: 0.5; color: Qt.alpha(Theme.p, 0.5) }
                        GradientStop { position: 1; color: Theme.ter }
                    }
                }
                Rectangle { id: capTop; width: parent.width; height: 1.1; radius: 0.55; color: Qt.alpha(Theme.ter, 0.8); visible: false }
                Rectangle { id: capBot; width: parent.width; height: 1.1; radius: 0.55; color: Qt.alpha(Theme.ter, 0.8); visible: false }
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
            const ai = root.aiState !== "", sc = root.stateColor;
            // asistente: su color, más tenue a los lados; música: punta de color (terciario arriba y abajo)
            const g = ai ? ctx.createLinearGradient(0, 0, w, 0) : ctx.createLinearGradient(0, 0, 0, h);
            g.addColorStop(0, ai ? Qt.alpha(sc, 0.7) : Theme.ter);
            g.addColorStop(0.5, ai ? sc : Qt.alpha(Theme.p, 0.55));
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
                const k = root.drawKind;
                if (k === "onda") {
                    ctx.globalAlpha = 0.9;
                    ctx.beginPath(); curve(-1); curve(1); ctx.fill();
                } else if (k === "zigzag") {
                    ctx.lineWidth = 1.4; ctx.lineJoin = "miter";
                    ctx.beginPath(); ctx.moveTo(0, mid);
                    for (let i = 0; i < n; i++) ctx.lineTo(pts[i][0], mid + (i % 2 ? 1 : -1) * pts[i][1]);
                    ctx.lineTo(w, mid); ctx.stroke();
                } else if (k === "cinta") {
                    // dos bordes: la amplitud por un seno que avanza a lo ancho; donde se cruzan, la cinta «gira»
                    const edge = (sign) => {
                        for (let i = 0; i < n; i++) {
                            const [x, a] = pts[i], y = mid + sign * a * Math.cos(i / (n - 1) * Math.PI * 3);
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                    };
                    ctx.globalAlpha = 0.35; ctx.beginPath(); edge(1);
                    for (let i = n - 1; i >= 0; i--) { const [x, a] = pts[i]; ctx.lineTo(x, mid - a * Math.cos(i / (n - 1) * Math.PI * 3)); }
                    ctx.closePath(); ctx.fill();
                    ctx.globalAlpha = 1; ctx.lineWidth = 1.3;
                    ctx.beginPath(); edge(1); ctx.stroke(); ctx.beginPath(); edge(-1); ctx.stroke();
                } else if (k === "escalones") {
                    // 24 columnas (una por cada dos bandas) de bloques de 2 px con 1 px de hueco
                    const cols = Math.floor(n / 2), cw = w / cols, step = 3;
                    for (let c = 0; c < cols; c++) {
                        const a = Math.max(pts[2 * c][1], pts[2 * c + 1]?.[1] ?? 0), blocks = Math.max(1, Math.round(a / step));
                        for (let b = 0; b < blocks; b++) {
                            ctx.globalAlpha = 1 - b / (blocks + 2) * 0.6;
                            ctx.fillRect(c * cw + 0.5, mid - (b + 1) * step + 1, cw - 1.5, 2);
                            ctx.fillRect(c * cw + 0.5, mid + b * step, cw - 1.5, 2);
                        }
                    }
                } else if (k === "capas") {
                    // la de fondo más ancha y tenue; cada capa, la misma onda escalada
                    for (const [sc2, al] of [[1, 0.25], [0.7, 0.45], [0.4, 0.9]]) {
                        ctx.globalAlpha = al;
                        const old = pts.map(p => p[1]);
                        for (let i = 0; i < n; i++) pts[i][1] = old[i] * sc2;
                        ctx.beginPath(); curve(-1); curve(1); ctx.fill();
                        for (let i = 0; i < n; i++) pts[i][1] = old[i];
                    }
                } else {
                    ctx.lineWidth = 1.6; ctx.lineJoin = "round";
                    ctx.beginPath(); curve(-1); ctx.stroke();
                    ctx.globalAlpha = 0.35; ctx.beginPath(); curve(1); ctx.stroke();
                }
            }
        }
    }
    Connections { target: Theme; function onPChanged() { cv.requestPaint(); } function onTerChanged() { cv.requestPaint(); } }
    onDrawKindChanged: { idlePainted = false; if (gpuBars) Qt.callLater(() => layoutBars(!live)); else cv.requestPaint(); }

    HoverHandler { id: hover; onHoveredChanged: if (hovered) Shell.preload("musica") }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onPressed: m => m.button === Qt.MiddleButton ? Media.toggle() : Shell.toggle("musica")
        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}

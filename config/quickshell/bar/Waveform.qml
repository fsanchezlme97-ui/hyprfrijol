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
//   burbujas  una fila de puntos que se hinchan con el sonido
//   agujas  líneas finas desde el centro con una gota en cada punta
//   montana  una sierra rellena que crece desde abajo, con el pie desvanecido
//   reflejo  barras que suben desde abajo con su reflejo tenue debajo, como sobre agua
//   pixeles  columnas de cuadraditos que crecen desde abajo, como un ecualizador de 8 bits
//   eco      la línea y dos ecos más pequeños y tenues
//   cuerdas  tres cuerdas que vibran con el sonido
//   pulso    un trazo de electrocardiograma: plano y con latidos donde hay sonido
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
    readonly property string kind: forceKind || Settings.get("waveStyle", "barras")
    readonly property string aiState: isPreview ? "" : Shell.aiSpeaking ? "habla"
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
                } else if (k === "burbujas") {
                    const cols = Math.floor(n / 2), cw = w / cols;
                    for (let c = 0; c < cols; c++) {
                        const a = (pts[2 * c][1] + (pts[2 * c + 1]?.[1] ?? 0)) / 2 / (mid - 1);
                        ctx.globalAlpha = 0.45 + 0.55 * a;
                        ctx.beginPath(); ctx.arc(c * cw + cw / 2, mid, Math.max(1, Math.min(cw / 2 - 0.4, 1 + a * mid)), 0, Math.PI * 2); ctx.fill();
                    }
                } else if (k === "agujas") {
                    ctx.lineWidth = 1; ctx.lineCap = "round";
                    for (let i = 0; i < n; i += 2) {
                        const [x, a] = pts[i];
                        ctx.globalAlpha = 0.55; ctx.beginPath(); ctx.moveTo(x, mid - a); ctx.lineTo(x, mid + a); ctx.stroke();
                        ctx.globalAlpha = 1; ctx.beginPath(); ctx.arc(x, mid - a, 1.3, 0, Math.PI * 2); ctx.arc(x, mid + a, 1.3, 0, Math.PI * 2); ctx.fill();
                    }
                } else if (k === "montana") {
                    ctx.globalAlpha = 0.9;
                    ctx.beginPath(); ctx.moveTo(0, h);
                    for (let i = 0; i < n - 1; i++) {
                        const [x0, a0] = pts[i], [x1, a1] = pts[i + 1];
                        ctx.quadraticCurveTo(x0, h - 2 * a0, (x0 + x1) / 2, h - (a0 + a1));
                    }
                    ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
                } else if (k === "reflejo") {
                    // línea de agua al 65 %: barras arriba y su reflejo (más corto y tenue) abajo
                    const base = h * 0.65, cols = Math.floor(n / 2), cw = w / cols;
                    for (let c = 0; c < cols; c++) {
                        const a = Math.max(pts[2 * c][1], pts[2 * c + 1]?.[1] ?? 0) / (mid - 1), up = Math.max(1.5, a * (base - 1));
                        ctx.globalAlpha = 1; ctx.fillRect(c * cw + 0.6, base - up, cw - 1.6, up);
                        ctx.globalAlpha = 0.25; ctx.fillRect(c * cw + 0.6, base + 1, cw - 1.6, Math.min(h - base - 1, up * 0.45));
                    }
                } else if (k === "pixeles") {
                    const cols = Math.floor(n / 2), cw = w / cols, cell = Math.max(2, Math.min(cw - 1, 3));
                    for (let c = 0; c < cols; c++) {
                        const a = Math.max(pts[2 * c][1], pts[2 * c + 1]?.[1] ?? 0) / (mid - 1), rows = Math.max(1, Math.round(a * h / (cell + 1)));
                        for (let r = 0; r < rows; r++) {
                            ctx.globalAlpha = 0.5 + 0.5 * (r + 1) / rows;
                            ctx.fillRect(c * cw + (cw - cell) / 2, h - (r + 1) * (cell + 1), cell, cell);
                        }
                    }
                } else if (k === "eco") {
                    ctx.lineWidth = 1.5; ctx.lineJoin = "round";
                    for (const [sc2, al] of [[0.45, 0.25], [0.72, 0.5], [1, 1]]) {
                        ctx.globalAlpha = al;
                        const old = pts.map(p => p[1]);
                        for (let i = 0; i < n; i++) pts[i][1] = old[i] * sc2;
                        ctx.beginPath(); curve(-1); ctx.stroke();
                        for (let i = 0; i < n; i++) pts[i][1] = old[i];
                    }
                } else if (k === "cuerdas") {
                    // la fase avanza con el reloj: las cuerdas ondulan mientras suena
                    const ph = root.isPreview ? 0 : Date.now() / 160;
                    ctx.lineWidth = 1.2;
                    for (let st2 = 0; st2 < 3; st2++) {
                        ctx.globalAlpha = st2 === 1 ? 1 : 0.55;
                        const y0 = mid + (st2 - 1) * h * 0.24;
                        ctx.beginPath();
                        for (let i = 0; i < n; i++) {
                            const [x, a] = pts[i], y = y0 + Math.sin(i * 0.9 + ph + st2 * 2.1) * a * 0.45;
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                } else if (k === "pulso") {
                    // cada 4 bandas un latido (subida, bajada, rebote) proporcional al nivel
                    ctx.lineWidth = 1.4; ctx.lineJoin = "round";
                    const shape = [0.05, 1, -0.6, 0.15];
                    ctx.beginPath(); ctx.moveTo(0, mid);
                    for (let i = 0; i < n; i++) ctx.lineTo(pts[i][0], mid - pts[i][1] * shape[i % 4]);
                    ctx.lineTo(w, mid); ctx.stroke();
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

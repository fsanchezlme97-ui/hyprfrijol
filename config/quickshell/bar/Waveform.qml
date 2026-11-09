// Onda de audio en el centro de la barra (cava, 48 bandas a 60 fps).
// Estilos (Ajustes › Barra › Onda de audio, ajuste "waveStyle"):
//   barras  barras redondeadas simétricas con degradado primario → terciario (por defecto)
//   onda    curva suave rellena, simétrica
//   linea   una sola línea fina que oscila
// Cada fotograma se acerca al valor de cava con ataque rápido y caída suave, así se mueve fluido y sin retraso.
// En silencio queda una línea de puntos tenue. Clic: controles de música. Clic central: reproducir/pausar.
// Rueda: volumen.
import QtQuick
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    property real barHeight: 32
    readonly property string kind: Settings.get("waveStyle", "barras")
    readonly property int n: Cava.count
    readonly property real gap: kind === "barras" ? 1.6 : 0
    readonly property real bw: kind === "barras" ? 2.6 : 0
    readonly property real waveW: kind === "barras" ? n * (bw + gap) - gap : 200
    implicitWidth: waveW + 20
    implicitHeight: Math.max(20, barHeight - 8)
    radius: Theme.ctl(height)
    color: hover.hovered ? Theme.fill2 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.dur } }

    readonly property bool live: Cava.active && (Media.playing || peak > 0.02)
    property real peak: 0
    property var disp: Array(n).fill(0)
    property bool idlePainted: false
    readonly property var paintKey: [Theme.p, Theme.ter, kind]
    onPaintKeyChanged: { idlePainted = false; cv.requestPaint(); }

    Component.onCompleted: Cava.users++
    Component.onDestruction: Cava.users--

    FrameAnimation {
        running: root.visible && (Cava.active || root.peak > 0.002)
        onTriggered: {
            const src = Cava.bars, d = root.disp;
            const dt = Math.min(0.05, frameTime);
            const up = 1 - Math.exp(-dt * 38), down = 1 - Math.exp(-dt * 9);
            let pk = 0;
            for (let i = 0; i < root.n; i++) {
                const t = Math.min(1, src[i] ?? 0);
                d[i] += (t - d[i]) * (t > d[i] ? up : down);
                if (d[i] > pk) pk = d[i];
            }
            root.peak = pk;
            // En reposo los puntos no cambian: se pintan una vez y no en cada fotograma
            const idle = !root.live && pk < 0.01;
            if (idle && root.idlePainted) return;
            root.idlePainted = idle;
            cv.requestPaint();
        }
    }

    Canvas {
        id: cv
        anchors.centerIn: parent
        width: root.waveW
        height: parent.height - 6
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, mid = h / 2, d = root.disp, n = root.n;
            const g = ctx.createLinearGradient(0, 0, w, 0);
            g.addColorStop(0, Qt.alpha(Theme.p, 0.75));
            g.addColorStop(0.5, Theme.p);
            g.addColorStop(1, Qt.alpha(Theme.ter, 0.85));
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
    onKindChanged: cv.requestPaint()

    HoverHandler { id: hover; onHoveredChanged: if (hovered) Shell.preload("musica") }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: m => m.button === Qt.MiddleButton ? Media.toggle() : Shell.toggle("musica")
        onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}

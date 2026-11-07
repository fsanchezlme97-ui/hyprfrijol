// Paisaje del diseño (fondo "escena": cielo, resplandor, sol, montañas y lago con reflejos).
// Se usa en el bloqueo (y en el login) cuando no hay fondo de pantalla elegido. Coordenadas del diseño (1440×900), escaladas.
//   Landscape { anchors.fill: parent; preset: "amanecer" }    presets: amanecer, lago, bosque, noche, bruma
import QtQuick

Item {
    id: root
    property string preset: "amanecer"
    property bool animated: true
    readonly property var presets: ({
        amanecer: { sky: "#2A3042", glow: "#E7B49B", glowOp: 0.55, sun: "#F5D6BE", halo: "#F5D6BE", haloOp: 0.35, far: "#5A627A", mid: "#434A60", near: "#30364A", lake: "#272C3B", refl: "#EDC2AA" },
        lago:     { sky: "#8FA9B2", glow: "#F1E7D0", glowOp: 0.75, sun: "#F7F0E0", halo: "#F7F0E0", haloOp: 0.45, far: "#789199", mid: "#5E7982", near: "#45606A", lake: "#6A8790", refl: "#F7F0E0" },
        bosque:   { sky: "#1C3631", glow: "#86C9A6", glowOp: 0.5, sun: "#D2EBDC", halo: "#D2EBDC", haloOp: 0.35, far: "#2E5A4B", mid: "#23483C", near: "#173A30", lake: "#132E27", refl: "#A8DDBF" },
        noche:    { sky: "#0F1626", glow: "#5B6FA8", glowOp: 0.45, sun: "#E2E8F7", halo: "#E2E8F7", haloOp: 0.3, far: "#1F2B45", mid: "#18233A", near: "#121B2E", lake: "#0D1424", refl: "#B9C6EA" },
        bruma:    { sky: "#E2E8EA", glow: "#FFFFFF", glowOp: 0.9, sun: "#FBF7EE", halo: "#FFFFFF", haloOp: 0.7, far: "#C7D2D6", mid: "#AFBEC4", near: "#95A8B0", lake: "#D0DADD", refl: "#FFFFFF" }
    })
    readonly property var sc: presets[preset] ?? presets.amanecer
    readonly property real k: Math.max(width / 1440, height / 900)
    clip: true

    Canvas {
        id: cv
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: root; function onScChanged() { cv.requestPaint(); } }

        function glowAt(ctx, x, y, w, h, blur, color, op) {
            const rx = w / 2, ry = h / 2, R = rx + blur;
            ctx.save();
            ctx.translate(x + rx, y + ry);
            ctx.scale(1, (ry + blur) / R);
            const g = ctx.createRadialGradient(0, 0, 0, 0, 0, R);
            const c = Qt.color(color);
            const rgba = a => "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
            g.addColorStop(0, rgba(op));
            g.addColorStop(Math.max(0, (rx - blur) / R), rgba(op * 0.8));
            g.addColorStop(rx / R, rgba(op * 0.45));
            g.addColorStop(1, rgba(0));
            ctx.fillStyle = g;
            ctx.beginPath(); ctx.arc(0, 0, R, 0, Math.PI * 2); ctx.fill();
            ctx.restore();
        }
        function ridge(ctx, top, h, pts, color) {
            const W = 1440;
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.moveTo(0, top + h);
            for (const [px, py] of pts) ctx.lineTo(px / 100 * W, top + py / 100 * h);
            ctx.lineTo(W, top + h);
            ctx.closePath(); ctx.fill();
        }
        onPaint: {
            const ctx = getContext("2d");
            const s = root.sc, k = root.k;
            ctx.reset();
            ctx.fillStyle = s.sky; ctx.fillRect(0, 0, width, height);
            ctx.save();
            // centrar horizontalmente la escena 1440×900 escalada
            ctx.translate((width - 1440 * k) / 2, (height - 900 * k) / 2);
            ctx.scale(k, k);
            glowAt(ctx, 420, 220, 1100, 560, 120, s.glow, s.glowOp);
            glowAt(ctx, 80, 60, 420, 300, 110, s.glow, 0.25);
            glowAt(ctx, 560, 150, 520, 90, 40, s.glow, 0.18);
            glowAt(ctx, 120, 300, 380, 70, 36, s.glow, 0.14);
            // halo + sol
            glowAt(ctx, 940 - 10, 420 - 10, 106, 106, 80, s.halo, s.haloOp);
            ctx.fillStyle = s.sun; ctx.beginPath(); ctx.arc(983, 463, 43, 0, Math.PI * 2); ctx.fill();
            ridge(ctx, 360, 280, [[0,62],[9,44],[17,54],[28,22],[38,46],[47,36],[58,52],[69,26],[80,48],[90,32],[100,46]], s.far);
            ridge(ctx, 470, 200, [[0,50],[12,30],[26,58],[40,34],[52,60],[66,30],[80,56],[92,38],[100,48]], s.mid);
            ridge(ctx, 560, 120, [[0,42],[18,70],[34,46],[52,74],[68,50],[86,72],[100,54]], s.near);
            ctx.fillStyle = s.lake; ctx.fillRect(-2000, 678, 5440, 2000);
            ctx.globalAlpha = 0.35;
            const lg = ctx.createLinearGradient(0, 668, 0, 748);
            lg.addColorStop(0, s.near); lg.addColorStop(1, s.lake);
            ctx.fillStyle = lg; ctx.fillRect(0, 668, 1440, 80);
            ctx.globalAlpha = 1;
            ctx.restore();
        }
    }

    // Reflejos del sol en el lago (centelleo suave)
    Item {
        x: (root.width - 1440 * root.k) / 2
        y: (root.height - 900 * root.k) / 2
        width: 1440; height: 900
        scale: root.k
        transformOrigin: Item.TopLeft
        Repeater {
            model: [[903,712,160,3,.55,0],[928,750,110,3,.45,1.2],[950,792,66,3,.4,2.4],[870,846,226,3,.35,3.1],
                    [820,880,326,3,.3,.6],[700,820,90,2,.25,1.8],[1180,864,120,2,.25,4]]
            Rectangle {
                required property var modelData
                x: modelData[0]; y: modelData[1]; width: modelData[2]; height: modelData[3]
                radius: 2
                color: root.sc.refl
                opacity: modelData[4]
                SequentialAnimation on opacity {
                    running: root.animated && root.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: modelData[5] * 700 }
                    NumberAnimation { to: modelData[4] * 0.35; duration: 2400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: modelData[4]; duration: 2400; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}

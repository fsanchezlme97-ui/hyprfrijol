// Respuesta del asistente con formato: trocea el Markdown del modelo y dibuja cada parte con su pieza.
//   texto           Markdown (títulos, listas, negritas, tablas, enlaces)
//   ```bash … ```   bloque de código o de comandos: fondo propio, letra monoespaciada, colores por lenguaje
//                   (highlight.js: SQL, terminal, JSON, Python, diff, yaml/toml, HTML, Lua y estilo C), botón «Copiar»
//   ```hf-chart {…}```  gráfico: {"type":"bar"|"line"|"pie", "title", "labels":[…], "series":[{"name","values":[…]}],
//                   "unit"} (hf-ai explica el formato al modelo; si el JSON no vale, se ve como código)
//   ![alt](url)     imagen (http(s) o ruta local) en una línea propia; clic → se abre fuera
//   AiRich { text: "…"; color: Theme.t; width: … }
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../../components"
import "highlight.js" as Hl

ColumnLayout {
    id: root
    property string text: ""
    property color color: Theme.t
    spacing: 8

    // [{ kind: "md"|"code"|"chart"|"img", text, lang, chart, src, alt }]
    readonly property var parts: {
        const out = [];
        const src = String(text ?? "");
        const fence = /```([\w+.#-]*)[ \t]*\n?([\s\S]*?)```/g;
        let last = 0, m;
        const prose = s => {
            // imágenes en una línea propia → pieza aparte; el resto, Markdown
            let buf = [];
            for (const line of s.split("\n")) {
                const im = line.trim().match(/^!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)$/);
                if (im) {
                    if (buf.join("\n").trim()) out.push({ kind: "md", text: buf.join("\n").trim() });
                    buf = [];
                    out.push({ kind: "img", alt: im[1], src: im[2] });
                } else buf.push(line);
            }
            if (buf.join("\n").trim()) out.push({ kind: "md", text: buf.join("\n").trim() });
        };
        while ((m = fence.exec(src)) !== null) {
            prose(src.slice(last, m.index));
            last = fence.lastIndex;
            const lang = (m[1] || "").toLowerCase(), body = m[2].replace(/\n$/, "");
            if (lang === "hf-query" || lang === "hf-actions") continue;
            if (lang === "hf-chart" || lang === "chart") {
                let c = null;
                try { c = JSON.parse(body); } catch (e) {}
                if (c && Array.isArray(c.labels) && (Array.isArray(c.series) || Array.isArray(c.values) || Array.isArray(c.data))) {
                    if (!Array.isArray(c.series)) c.series = [{ name: c.title ?? "", values: c.values ?? c.data }];
                    out.push({ kind: "chart", chart: c });
                    continue;
                }
            }
            out.push({ kind: "code", lang: lang, text: body });
        }
        prose(src.slice(last));
        return out;
    }

    // con código, gráficos o imágenes la burbuja usa todo el ancho
    readonly property bool wide: parts.some(p => p.kind !== "md")
    // colores de las series: el acento del tema (si tiene color) y una paleta de tonos bien distintos entre sí
    readonly property var seriesColors: {
        const base = Theme.light ? ["#3b6fd8", "#d9485f", "#2f9e6e", "#c98a1b", "#8a5cd1", "#1f9bb5"]
                                 : ["#7aa2f7", "#f7768e", "#9ece6a", "#e0af68", "#bb9af7", "#7dcfff"];
        return Theme.p.hslSaturation > 0.3 ? [Theme.p].concat(base.slice(0, 5)) : base;
    }

    Repeater {
        model: root.parts
        delegate: Loader {
            id: part
            required property var modelData
            Layout.fillWidth: true
            sourceComponent: modelData.kind === "code" ? codeC : modelData.kind === "chart" ? chartC
                : modelData.kind === "img" ? imgC : mdC
        }
    }

    // ---------- Markdown
    Component {
        id: mdC
        Text {
            text: parent?.modelData?.text ?? ""
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            color: root.color
            font.family: Theme.font
            font.pixelSize: Theme.px(12.5)
            lineHeight: 1.18
            linkColor: Theme.p
            onLinkActivated: l => Qt.openUrlExternally(l)
            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }

    // ---------- código / comandos
    Component {
        id: codeC
        Rectangle {
            id: box
            readonly property var d: parent?.modelData ?? {}
            readonly property bool shell: /^(bash|sh|zsh|fish|shell|console|terminal)$/.test(d.lang ?? "")
            property bool copied: false
            implicitHeight: codeCol.implicitHeight + 12
            radius: Theme.r(8)
            color: Qt.alpha(Theme.bg, 0.55)
            border.width: 1; border.color: Theme.ov
            Column {
                id: codeCol
                x: 10; y: 6
                width: parent.width - 20
                spacing: 4
                RowLayout {
                    width: parent.width
                    CatIcon { id: langIcon; visible: valid; lang: box.d.lang || (box.shell ? "bash" : ""); size: 13 }
                    Icon { visible: !langIcon.valid; name: box.shell ? "terminal" : "code"; size: 11; color: Theme.tv }
                    Txt { text: box.shell ? "Terminal" : (box.d.lang || "Código"); size: 10.5; muted: true; weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        implicitWidth: cpRow.implicitWidth + 12; implicitHeight: 20; radius: Theme.r(5)
                        color: cpMa.containsMouse ? Theme.fill2 : "transparent"
                        Row {
                            id: cpRow
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: box.copied ? "check" : "copy"; size: 11; color: Theme.tv }
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: box.copied ? "Copiado" : "Copiar"; size: 10.5; muted: true }
                        }
                        MouseArea {
                            id: cpMa
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Quickshell.execDetached(["wl-copy", "--", box.d.text ?? ""]); box.copied = true; cpT.restart(); }
                        }
                        Timer { id: cpT; interval: 1600; onTriggered: box.copied = false }
                    }
                }
                TextEdit {
                    width: parent.width
                    readOnly: true; selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    textFormat: TextEdit.RichText
                    text: Hl.html(box.d.text ?? "", box.d.lang ?? "", Theme.light)
                    color: Theme.t
                    selectionColor: Qt.alpha(Theme.p, 0.4)
                    font.family: Theme.mono
                    font.pixelSize: Theme.px(11.5)
                }
            }
        }
    }

    // ---------- imagen
    Component {
        id: imgC
        Item {
            id: ib
            readonly property var d: parent?.modelData ?? {}
            readonly property string url: /^(https?|file):/.test(d.src ?? "") ? d.src : (String(d.src ?? "").startsWith("/") ? "file://" + d.src : "")
            implicitHeight: pic.status === Image.Ready ? Math.min(320, width * pic.implicitHeight / Math.max(1, pic.implicitWidth)) + (cap.visible ? cap.implicitHeight + 4 : 0)
                : pic.status === Image.Error || !url ? errT.implicitHeight : 60
            Image {
                id: pic
                width: parent.width
                height: status === Image.Ready ? Math.min(320, width * implicitHeight / Math.max(1, implicitWidth)) : 0
                source: ib.url
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                sourceSize.width: 900
                smooth: true; mipmap: true
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(ib.url) }
            }
            Rectangle {
                visible: pic.status === Image.Loading
                width: parent.width; height: 60; radius: Theme.r(8); color: Theme.fill2
                Txt { anchors.centerIn: parent; text: "Cargando imagen…"; size: 11; muted: true }
            }
            Txt {
                id: cap
                visible: pic.status === Image.Ready && (ib.d.alt ?? "") !== ""
                y: pic.height + 4
                width: parent.width
                text: ib.d.alt ?? ""; size: 10.5; muted: true; wrapMode: Text.Wrap; elide: Text.ElideNone
            }
            Txt {
                id: errT
                visible: pic.status === Image.Error || !ib.url
                width: parent.width
                text: "No se pudo cargar la imagen" + ((ib.d.alt ?? "") ? " «" + ib.d.alt + "»" : "")
                size: 11; muted: true; wrapMode: Text.Wrap; elide: Text.ElideNone
            }
        }
    }

    // ---------- gráfico
    Component {
        id: chartC
        Rectangle {
            id: cb
            readonly property var c: parent?.modelData?.chart ?? ({ labels: [], series: [] })
            readonly property string type: ["bar", "line", "pie"].includes(c.type) ? c.type : "bar"
            readonly property var series: (c.series ?? []).slice(0, 6).map(s => ({ name: String(s.name ?? ""), values: (s.values ?? s.data ?? []).map(v => Number(v) || 0) }))
            readonly property var labels: (c.labels ?? []).map(String)
            implicitHeight: chCol.implicitHeight + 16
            radius: Theme.r(8)
            color: Qt.alpha(Theme.bg, 0.35)
            border.width: 1; border.color: Theme.ov
            function fmt(v) {
                const a = Math.abs(v);
                const s = a >= 1e6 ? (v / 1e6).toFixed(1) + " M" : a >= 1e4 ? (v / 1e3).toFixed(0) + " k" : a >= 100 ? v.toFixed(0) : String(Math.round(v * 10) / 10);
                return s + (cb.c.unit ? " " + cb.c.unit : "");
            }
            Column {
                id: chCol
                x: 10; y: 8
                width: parent.width - 20
                spacing: 6
                Txt { visible: (cb.c.title ?? "") !== ""; width: parent.width; text: cb.c.title ?? ""; size: 12; weight: Font.DemiBold; wrapMode: Text.Wrap; elide: Text.ElideNone }
                Canvas {
                    id: cv
                    width: parent.width
                    height: cb.type === "pie" ? Math.min(180, width * 0.55) : 170
                    antialiasing: true
                    onWidthChanged: requestPaint()
                    Connections { target: Theme; function onPChanged() { cv.requestPaint(); } }
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const W = width, H = height, S = cb.series, L = cb.labels, pal = root.seriesColors;
                        g.font = Theme.px(10) + "px '" + Theme.font + "'";
                        g.textBaseline = "middle";
                        if (cb.type === "pie") {
                            const vals = (S[0]?.values ?? []).map(v => Math.max(0, v)), tot = vals.reduce((a, b) => a + b, 0) || 1;
                            const r = H / 2 - 4, cx = r + 4, cy = H / 2;
                            let a0 = -Math.PI / 2;
                            vals.forEach((v, i) => {
                                const a1 = a0 + v / tot * Math.PI * 2;
                                g.beginPath(); g.moveTo(cx, cy); g.arc(cx, cy, r, a0, a1); g.closePath();
                                g.fillStyle = pal[i % pal.length]; g.fill();
                                g.strokeStyle = Theme.s1; g.lineWidth = 1.5; g.stroke();
                                a0 = a1;
                            });
                            // leyenda
                            const lx = cx + r + 16;
                            vals.forEach((v, i) => {
                                const y = 10 + i * 18;
                                if (y > H - 6) return;
                                g.fillStyle = pal[i % pal.length]; g.fillRect(lx, y - 5, 10, 10);
                                g.fillStyle = Theme.t;
                                g.fillText((L[i] ?? "") + " · " + Math.round(v / tot * 100) + " %", lx + 16, y);
                            });
                            return;
                        }
                        const all = [].concat(...S.map(s => s.values));
                        let max = Math.max(0, ...all), min = Math.min(0, ...all);
                        if (max === min) max = min + 1;
                        // marcas «redondas» (1, 2, 2.5, 5 × 10ⁿ) para que las etiquetas sean legibles
                        const raw = (max - min) / 3, mag = Math.pow(10, Math.floor(Math.log10(raw))), f = raw / mag;
                        const tick = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * mag;
                        max = Math.ceil(max / tick - 1e-9) * tick; min = Math.floor(min / tick + 1e-9) * tick;
                        const nt = Math.max(1, Math.round((max - min) / tick));
                        const ticks = Array.from({ length: nt + 1 }, (_, k) => min + tick * k);
                        const padL = Math.max(...ticks.map(v => g.measureText(cb.fmt(v)).width)) + 8, padB = 18, padT = 6;
                        const pw = W - padL - 4, ph = H - padB - padT;
                        const Y = v => padT + ph - (v - min) / (max - min) * ph;
                        // rejilla
                        g.strokeStyle = Qt.alpha(Theme.t, 0.12); g.lineWidth = 1;
                        g.fillStyle = Theme.tv; g.textAlign = "right";
                        for (const v of ticks) {
                            const y = Math.round(Y(v)) + 0.5;
                            g.beginPath(); g.moveTo(padL, y); g.lineTo(W - 4, y); g.stroke();
                            g.fillText(cb.fmt(v), padL - 6, y);
                        }
                        // etiquetas del eje x (las que quepan)
                        const n = Math.max(1, L.length), step = pw / n;
                        const every = Math.max(1, Math.ceil(n / Math.max(1, Math.floor(pw / 46))));
                        g.textAlign = "center"; g.fillStyle = Theme.tv;
                        for (let i = 0; i < n; i += every) {
                            let t = String(L[i] ?? "");
                            while (t.length > 2 && g.measureText(t).width > step * every - 4) t = t.slice(0, -2) + "…";
                            g.fillText(t, padL + step * (i + 0.5), H - padB / 2 + 2);
                        }
                        if (cb.type === "bar") {
                            const k = S.length, bw = Math.max(2, Math.min(28, step * 0.72 / k));
                            S.forEach((s, j) => {
                                g.fillStyle = pal[j % pal.length];
                                s.values.forEach((v, i) => {
                                    const x = padL + step * (i + 0.5) - bw * k / 2 + bw * j, y0 = Y(0), y1 = Y(v);
                                    g.fillRect(x + 0.5, Math.min(y0, y1), bw - 1, Math.max(1, Math.abs(y1 - y0)));
                                });
                            });
                        } else {
                            S.forEach((s, j) => {
                                g.strokeStyle = pal[j % pal.length]; g.lineWidth = 2; g.lineJoin = "round";
                                g.beginPath();
                                s.values.forEach((v, i) => { const x = padL + step * (i + 0.5); i ? g.lineTo(x, Y(v)) : g.moveTo(x, Y(v)); });
                                g.stroke();
                                g.fillStyle = pal[j % pal.length];
                                s.values.forEach((v, i) => { g.beginPath(); g.arc(padL + step * (i + 0.5), Y(v), 2.5, 0, Math.PI * 2); g.fill(); });
                            });
                        }
                    }
                }
                // leyenda de series (barras / líneas con varias)
                Flow {
                    visible: cb.type !== "pie" && cb.series.length > 1
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: cb.series
                        Row {
                            required property var modelData
                            required property int index
                            spacing: 5
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 2; color: root.seriesColors[index % root.seriesColors.length] }
                            Txt { text: modelData.name; size: 10.5; muted: true }
                        }
                    }
                }
            }
        }
    }
}

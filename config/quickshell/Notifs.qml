pragma Singleton
// Servidor de notificaciones propio (sustituye a mako/dunst).
// - list:    historial (centro de notificaciones y ajustes rápidos); list.values = Notification[]
// - popups:  las que se ven ahora como avisos emergentes
// - dnd:     «no molestar»; se guarda en ~/.local/state/hyprfrijol/dnd.
//            El archivo vacío = hasta que lo desactives; con un número = hora de fin (epoch en ms).
//            dndUntil (ms, 0 = sin fin) · dndPreset("1h" | "noche" | "manana" | "siempre") · dndLeft ("quedan 52 min")
// - timeOf(n) / ago(n) / agoT(ms): hora de llegada relativa ("ahora", "hace 3 min", "hace 2 h", "ayer", "lun")
// - reply(n, texto): respuesta en línea (WhatsApp, Telegram, Valent…)
// - groupsOf(lista): [{ key, app, items }] agrupados por app (más reciente primero; las urgentes delante)
// - popupGroups: los avisos emergentes agrupados (la pila muestra el último y cuántos más hay)
// - history: historial persistente (~/.local/state/hyprfrijol/notify-history.json, notifyHistory, máx. 300)
//            [{ uid, app, key, icon, image, summary, body, urgency, t }] · clearHistory() · forget(uid)
// - Las apps que reemplazan su aviso (replace-id: volumen, descargas…) vuelven a mostrarlo y reinician su tiempo.
// - Reglas por app (notifyApps: allow/popups) se miran aquí al llegar, para que no parpadee el emergente.
// IPC:  qs -p <repo>/config/quickshell ipc call notifs toggleDnd | setDnd true | dndFor 60 | dndPreset noche | clear
//       | recent 20 (JSON: avisos actuales + historial, lo usa hf-ai) | clearHistory
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "services"

Singleton {
    id: root
    property alias list: server.trackedNotifications
    property list<QtObject> popups: []
    property bool dnd: false
    property real dndUntil: 0             // epoch ms en que se apaga solo; 0 = hasta que lo desactives
    property string dndKind: ""           // último atajo usado ("1h" | "noche" | "manana" | "siempre")
    property var arrived: ({})            // id → epoch ms
    readonly property int defaultTimeout: 6000
    readonly property int count: list.values.length
    readonly property int maxPopups: 24

    function isCritical(n): bool { return n?.urgency === NotificationUrgency.Critical; }
    function appOf(n): string { return String(n?.appName || n?.desktopEntry || "Sistema").trim() || "Sistema"; }
    function keyOf(n): string { return String(n?.appName || n?.desktopEntry || "").trim().toLowerCase(); }
    function ruleOf(n) { return (Settings.get("notifyApps", ({})) ?? {})[keyOf(n)] ?? {}; }
    // ¿Puede salir como emergente? (no molestar y reglas por app)
    function canPopup(n): bool {
        if (isCritical(n)) return true;
        const r = ruleOf(n);
        if (r.allow === false || r.popups === false) return false;
        return !dnd;
    }
    // Agrupa por app conservando el orden de la lista (la primera = la más reciente); urgentes delante
    function groupsOf(arr) {
        const out = [], idx = {};
        for (const n of arr) {
            if (!n) continue;
            const k = appOf(n).toLowerCase();
            if (idx[k] === undefined) { idx[k] = out.length; out.push({ key: k, app: appOf(n), items: [], critical: false }); }
            const g = out[idx[k]];
            g.items.push(n);
            if (isCritical(n)) g.critical = true;
        }
        return out.filter(g => g.critical).concat(out.filter(g => !g.critical));
    }
    readonly property var popupGroups: groupsOf(popups)
    function showPopup(n) {
        const rest = popups.filter(p => p !== n);
        const crit = rest.filter(p => isCritical(p)), normal = rest.filter(p => !isCritical(p));
        popups = [n].concat(crit, normal.slice(0, Math.max(0, maxPopups - 1 - crit.length)));
    }
    // Un aviso reemplazado (mismo id): vuelve a salir con su tiempo desde cero y se actualiza en el historial
    function bump(n) {
        if (!n || !n.tracked) return;
        const a = Object.assign({}, arrived); a[n.id] = Date.now(); arrived = a;
        record(n);
        if (canPopup(n)) showPopup(n);
    }

    function setDnd(on: bool) { setDndUntil(on, 0); }
    function setDndUntil(on: bool, until: real) {
        dnd = on;
        dndUntil = on && until > Date.now() ? until : 0;
        dndKind = !on ? "" : dndUntil > 0 ? "" : "siempre";
        dndWriter.command = ["sh", "-c", on ? 'mkdir -p "$1" && printf "%s" "$2" > "$1/dnd"' : 'rm -f "$1/dnd"', "sh", Paths.state, dndUntil > 0 ? String(Math.round(dndUntil)) : ""];
        dndWriter.running = true;
        if (on) popups = popups.filter(p => p.urgency === NotificationUrgency.Critical);
    }
    // Próxima vez que el reloj marque hh:00 (hoy o mañana)
    function nextAt(h: int): real {
        const d = new Date(); d.setHours(h, 0, 0, 0);
        if (d.getTime() <= Date.now() + 60000) d.setDate(d.getDate() + 1);
        return d.getTime();
    }
    // Atajos: 1 h · hasta esta noche (20:00) · hasta mañana (08:00) · hasta que lo desactives
    readonly property var dndPresets: [
        { key: "1h", label: "Durante 1 hora" },
        { key: "noche", label: "Hasta esta noche", hint: "20:00" },
        { key: "manana", label: "Hasta mañana", hint: "08:00" },
        { key: "siempre", label: "Hasta que lo desactive" }
    ]
    function dndPreset(k: string) {
        if (k === "1h") setDndUntil(true, Date.now() + 3600000);
        else if (k === "noche") setDndUntil(true, nextAt(20));
        else if (k === "manana") setDndUntil(true, nextAt(8));
        else if (k === "off") setDnd(false);
        else setDnd(true);
        if (k !== "off") dndKind = k === "1h" || k === "noche" || k === "manana" ? k : "siempre";
    }
    // «quedan 52 min» · «hasta las 20:00» · «hasta mañana a las 08:00» · «hasta que lo desactives»
    readonly property string dndLeft: {
        if (!dnd) return "";
        if (dndUntil <= 0) return "hasta que lo desactives";
        const ms = dndUntil - Time.now.getTime();
        if (ms <= 0) return "terminando…";
        const min = Math.ceil(ms / 60000);
        if (min <= 90) return "quedan " + min + " min";
        const end = new Date(dndUntil), today = new Date(Time.now);
        const tomorrow = new Date(today); tomorrow.setDate(today.getDate() + 1);
        if (end.toDateString() === today.toDateString()) return "hasta las " + Time.fmt(end);
        if (end.toDateString() === tomorrow.toDateString()) return "hasta mañana a las " + Time.fmt(end);
        return "hasta el " + Qt.locale("es_ES").toString(end, "ddd d").replace(".", "") + " a las " + Time.fmt(end);
    }
    // Apaga «no molestar» al llegar la hora de fin
    Timer {
        interval: 15000; repeat: true
        running: root.dnd && root.dndUntil > 0
        triggeredOnStart: true
        onTriggered: if (Date.now() >= root.dndUntil) root.setDnd(false)
    }
    function hidePopup(n) { popups = popups.filter(p => p !== n); }
    function dismiss(n) { hidePopup(n); n.dismiss(); }
    function dismissAll(arr) { const s = arr.slice(); popups = popups.filter(p => !s.includes(p)); for (const n of s) n.dismiss(); }
    function clearAll() {
        popups = [];
        for (const n of list.values.slice()) n.dismiss();
    }
    function reply(n, text: string) {
        if (!text || !n.hasInlineReply) return;
        n.sendInlineReply(text);
        hidePopup(n);
    }
    // Acción por defecto (clic en el aviso)
    function activate(n) {
        const def = n.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        else if (n.desktopEntry) Quickshell.execDetached(["gtk-launch", n.desktopEntry]);
        hidePopup(n);
    }

    function timeOf(n): date { return new Date(arrived[n?.id] ?? Date.now()); }
    function ago(n): string { return agoT(timeOf(n).getTime()); }
    function agoT(ms: real): string {
        const t = new Date(ms), now = Time.now;
        const mins = Math.floor((now - t) / 60000);
        if (mins < 1) return "ahora";
        if (mins < 60) return "hace " + mins + " min";
        const sameDay = t.toDateString() === now.toDateString();
        if (sameDay && mins < 360) return "hace " + Math.floor(mins / 60) + " h";
        if (sameDay) return Time.fmt(t);
        const y = new Date(now); y.setDate(y.getDate() - 1);
        if (t.toDateString() === y.toDateString()) return "ayer";
        if (now - t < 6 * 86400000) return Qt.locale("es_ES").toString(t, "ddd").replace(".", "");
        return Qt.locale("es_ES").toString(t, "d MMM").replace(".", "");
    }
    // «Hoy» · «Ayer» · «lunes 3 de noviembre» (cabeceras del historial)
    function dayOf(ms: real): string {
        const t = new Date(ms), now = Time.now;
        if (t.toDateString() === now.toDateString()) return "Hoy";
        const y = new Date(now); y.setDate(y.getDate() - 1);
        if (t.toDateString() === y.toDateString()) return "Ayer";
        return Qt.locale("es_ES").toString(t, "dddd d 'de' MMMM");
    }
    // Imagen «de contenido» del aviso (captura, foto, fondo…) para mostrarla grande; los chats usan la suya de avatar
    function previewOf(n): string {
        if (!n || tone(n) === "pc") return "";
        const img = String(n.image ?? "");
        if (img.startsWith("image://qsimage")) return img;          // imagen en bruto (image-data): contenido
        // Una ruta que es el icono de la app (kitty: /usr/lib/kitty/logo/kitty.png) NO es contenido: solo cuentan las
        // imágenes de carpetas del usuario o temporales (capturas de grimblast, descargas…)
        const content = (u) => {
            const path = String(u).replace(/^image:\/\/icon\//, "").replace(/^file:\/\//, "");
            return path.startsWith("/") && /\.(jpe?g|png|webp|avif|gif|bmp)$/i.test(path)
                && /^\/(home|tmp|run\/user|var\/tmp)\//.test(path)
                && !/\/(icons|pixmaps|logo|logos)\/|\/\.local\/share\/(icons|applications)\//i.test(path)
                ? "file://" + path : "";
        };
        return content(img) || content(n.appIcon ?? "");
    }
    // Texto sin etiquetas (búsqueda, historial, resumen para la IA)
    function plain(s): string { return String(s ?? "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'"); }

    // ---------- historial persistente ----------
    property var history: []
    property var huid: ({})               // id del aviso → uid de su entrada (para los reemplazos)
    readonly property bool keepHistory: Settings.get("notifyHistory", true) !== false
    function record(n) {
        if (!keepHistory || !n || n.transient || ruleOf(n).allow === false) return;
        const img = String(n.image ?? "");
        const icon = String(n.appIcon ?? "");
        let uid = huid[n.id];
        if (!uid) { uid = Date.now().toString(36) + "-" + n.id; const h = Object.assign({}, huid); h[n.id] = uid; huid = h; }
        const e = { uid: uid, app: appOf(n), key: keyOf(n), entry: n.desktopEntry || "",
                    icon: icon.startsWith("image://qsimage") ? "" : icon,
                    image: img.startsWith("image://qsimage") ? "" : root.previewOf(n),
                    summary: plain(n.summary).slice(0, 300), body: plain(n.body).slice(0, 1200),
                    urgency: isCritical(n) ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1, t: Date.now() };
        history = [e].concat(history.filter(h => h.uid !== uid)).slice(0, 300);
        histSave.restart();
    }
    function clearHistory() { history = []; histSave.restart(); }
    function forget(uid: string) { history = history.filter(h => h.uid !== uid); histSave.restart(); }
    FileView {
        id: histFile
        path: Paths.state + "/notify-history.json"
        printErrors: false
        onLoaded: { try { const h = JSON.parse(text()); if (Array.isArray(h) && root.history.length === 0) root.history = h; } catch (e) {} }
    }
    Timer { id: histSave; interval: 1200; onTriggered: histFile.setText(JSON.stringify(root.history) + "\n") }

    // Inicial y color de la "baldosa" del aviso, como en el diseño (WhatsApp → pc, Calendario → sc, sistema → s4)
    function glyph(n): string {
        const a = (n.appName || n.summary || "?").trim();
        return a.charAt(0).toUpperCase();
    }
    function tone(n): string {
        const a = ((n.appName || "") + " " + (n.desktopEntry || "") + " " + (n.hints?.category ?? "")).toLowerCase();
        if (/whatsapp|telegram|signal|discord|slack|element|im\.|chat|mensaj|kdeconnect|valent/.test(a)) return "pc";
        if (/calend|evolution|thunderbird|mail|correo|gmail|email/.test(a)) return "sc";
        return "s4";
    }

    NotificationServer {
        id: server
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        keepOnReload: true
        onNotification: n => {
            n.tracked = true;
            const a = Object.assign({}, root.arrived); a[n.id] = Date.now(); root.arrived = a;
            n.closed.connect(() => root.hidePopup(n));
            // replace-id: la app actualiza el mismo aviso (no vuelve a llegar por aquí)
            n.summaryChanged.connect(() => bumpT.queue(n));
            n.bodyChanged.connect(() => bumpT.queue(n));
            root.record(n);
            if (root.canPopup(n)) root.showPopup(n);
            root.announce(n);
        }
    }

    // Sophia lee en voz alta los avisos urgentes (recordatorios del asistente, batería…): aiAnnounceUrgent.
    // Nunca en «no molestar» ni de apps silenciadas; el mismo aviso repetido en menos de 1 min, una sola vez.
    property string lastSpoken: ""
    property real lastSpokenT: 0
    function announce(n) {
        if (!isCritical(n) || dnd || !Settings.get("aiAnnounceUrgent", false) || ruleOf(n).allow === false) return;
        const text = [n.summary, n.body].filter(Boolean).join(". ");
        if (!text.trim() || (text === lastSpoken && Date.now() - lastSpokenT < 60000)) return;
        lastSpoken = text; lastSpokenT = Date.now();
        Quickshell.execDetached([Paths.script("hf-ai"), "announce", text]);
    }

    // Estado inicial de «no molestar» (y su hora de fin, si la tiene)
    Process {
        running: true
        command: ["sh", "-c", '[ -e "$1" ] && { echo on; cat "$1"; }; true', "sh", Paths.state + "/dnd"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.dnd = l[0] === "on";
                const until = Number(l[1] ?? "") || 0;
                root.dndUntil = root.dnd && until > 0 ? until : 0;
                root.dndKind = root.dnd && !(until > 0) ? "siempre" : "";
                if (root.dnd && until > 0 && until <= Date.now()) root.setDnd(false);
            }
        }
    }
    Process { id: dndWriter }
    // summary y body cambian juntos al reemplazar: un solo «bump»
    Timer {
        id: bumpT
        property var pending: []
        function queue(n) { if (!pending.includes(n)) pending = pending.concat([n]); restart(); }
        interval: 30
        onTriggered: { const p = pending; pending = []; for (const n of p) root.bump(n); }
    }

    IpcHandler {
        target: "notifs"
        function toggleDnd(): void { root.setDnd(!root.dnd); }
        function setDnd(on: bool): void { root.setDnd(on); }
        function dndFor(minutes: int): void { root.setDndUntil(true, Date.now() + minutes * 60000); }
        function dndPreset(key: string): void { root.dndPreset(key); }
        function dndLeft(): string { return root.dndLeft; }
        function clear(): void { root.clearAll(); }
        function count(): int { return root.count; }
        function clearHistory(): void { root.clearHistory(); }
        // Para la IA (hf-ai): avisos sin leer + últimos del historial, en JSON
        function recent(max: int): string {
            const m = max > 0 ? max : 20;
            return JSON.stringify({
                dnd: root.dnd, dndLeft: root.dndLeft,
                current: root.list.values.slice().reverse().slice(0, m).map(n => ({ id: n.id, app: root.appOf(n), summary: root.plain(n.summary),
                    body: root.plain(n.body).slice(0, 400), urgent: root.isCritical(n), when: root.ago(n),
                    actions: (n.actions ?? []).filter(a => a.identifier !== "default").map(a => a.text) })),
                history: root.history.slice(0, m).map(h => ({ app: h.app, summary: h.summary, body: String(h.body).slice(0, 300), when: root.agoT(h.t) }))
            });
        }
    }
}

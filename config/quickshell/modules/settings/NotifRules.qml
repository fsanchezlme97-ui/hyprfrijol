// Reglas de Ajustes › Notificaciones sobre el servidor de avisos (Notifs), sin tocarlo:
//  · apps que han avisado → ~/.local/state/hyprfrijol/notify-apps.json (la lista por aplicación de Ajustes)
//  · por app (notifyApps: { "<app>": { allow, popups, sound } }): descartar el aviso, no mostrarlo emergente o callar
//  · sonido al llegar un aviso (notifySound, notifySoundName) con canberra-gtk-play / pw-play
//  · «no molestar» programado (notifyDndSchedule, notifyDndFrom, notifyDndTo, notifyDndDays)
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../.."

Scope {
    id: root
    property var seen: ({})       // clave → { name, entry, icon, last, count }
    // Iconos que son archivos temporales (p. ej. «notify-send -i captura.png» de las capturas, en /run/user/…): no
    // sirven como icono de la app y desaparecen al reiniciar (el aviso «Could not load icon» en Ajustes › Notificaciones)
    function tempPath(p): bool { return /^(file:\/\/)?\/(run|tmp)\//.test(String(p ?? "")); }
    readonly property var rules: Settings.get("notifyApps", ({}))

    function keyOf(n): string { return String(n.appName || n.desktopEntry || "").trim().toLowerCase(); }
    function rule(n) { return rules[keyOf(n)] ?? {}; }

    function handle(n): void {
        if (!n) return;
        const t = Notifs.arrived[n.id];
        if (!t || Date.now() - t > 5000) return;     // solo avisos nuevos (no los que vuelven tras recargar)
        const k = keyOf(n);
        if (k) {
            const s = Object.assign({}, seen);
            const prev = s[k] ?? { count: 0 };
            s[k] = { name: n.appName || n.desktopEntry, entry: n.desktopEntry || prev.entry || "", icon: (root.tempPath(n.appIcon) ? "" : n.appIcon) || (String(n.image || "").startsWith("image://icon/") ? String(n.image) : "") || (root.tempPath(prev.icon) ? "" : prev.icon) || "",
                     last: Date.now(), count: (prev.count || 0) + 1 };
            seen = s;
            saveT.restart();
        }
        const r = rule(n);
        const critical = n.urgency === NotificationUrgency.Critical;
        if (r.allow === false && !critical) { n.dismiss(); return; }
        const shown = Notifs.popups.includes(n);
        if (r.popups === false && !critical) Notifs.hidePopup(n);
        else if (shown && Settings.get("notifySound", false) && Settings.get("systemSounds", true) !== false && r.sound !== false && !(n.hints?.["suppress-sound"] ?? false)) play();
    }
    function play(): void {
        const s = Settings.get("notifySoundName", "message-new-instant");
        Quickshell.execDetached(["sh", "-c", "canberra-gtk-play -i \"$1\" 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/\"$1\".oga 2>/dev/null "
            + "|| pw-play /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null || true", "sh", s]);
    }

    Connections {
        target: Notifs.list
        // se emite dentro de onNotification, antes de que Notifs lo ponga en «popups»: se procesa justo después
        function onObjectInsertedPost(object, index) { Qt.callLater(root.handle, object); }
    }

    FileView {
        id: store
        path: Paths.state + "/notify-apps.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.seen = JSON.parse(text()) ?? {}; } catch (e) {} }
    }
    Timer { id: saveT; interval: 1500; onTriggered: store.setText(JSON.stringify(root.seen, null, 1) + "\n") }

    // ---------- no molestar programado ----------
    property var lastIn: null
    function hm(s: string): int { const p = String(s || "0:0").split(":"); return parseInt(p[0]) * 60 + (parseInt(p[1]) || 0); }
    function tick(): void {
        if (!Settings.get("notifyDndSchedule", false)) { lastIn = null; return; }
        const d = new Date(), now = d.getHours() * 60 + d.getMinutes();
        const a = hm(Settings.get("notifyDndFrom", "22:00")), b = hm(Settings.get("notifyDndTo", "07:00"));
        // días en que empieza la franja (notifyDndDays, 0 = domingo); la parte de después de medianoche es del día anterior
        const days = Settings.get("notifyDndDays", [0, 1, 2, 3, 4, 5, 6]) ?? [];
        const today = d.getDay(), yday = (today + 6) % 7;
        const inside = a <= b ? (now >= a && now < b && days.includes(today))
                              : ((now >= a && days.includes(today)) || (now < b && days.includes(yday)));
        // solo al cruzar el horario: si lo cambias a mano dentro de la franja, se respeta
        if (inside !== lastIn) {
            if (lastIn !== null || inside) Notifs.setDnd(inside);
            lastIn = inside;
        }
    }
    // la primera comprobación espera a que Notifs lea el estado guardado de «no molestar» (si no, lo pisaría)
    property bool ready: false
    Timer { interval: 3000; running: Settings.loaded; onTriggered: { root.ready = true; root.tick(); } }
    Timer { interval: 30000; repeat: true; running: root.ready; onTriggered: root.tick() }
    Connections {
        target: Settings
        function onDataChanged() { if (root.ready) Qt.callLater(root.tick); }
    }
}

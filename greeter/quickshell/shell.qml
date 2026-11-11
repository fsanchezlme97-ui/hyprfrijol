// hyprfrijol · inicio de sesión (greetd + Quickshell), diseño «Login / LoginReposo / LoginSesion / LoginClaro».
//
// Lo ejecuta greetd dentro de un Hyprland mínimo (greeter/hyprland-greeter.lua) como el usuario «greeter»,
// así que es AUTÓNOMO: no lee nada del repo ni del $HOME de nadie. Todo lo que necesita está en esta carpeta
// (/etc/greetd/quickshell): shell.qml, Landscape.qml, VideoBackdrop.qml, palettes.json y, opcionalmente, greeter.json y wallpaper.*
// live/ (opcional, propiedad del usuario para que hf-greeter-sync la actualice sin contraseña cada vez que cambias de fondo
// o de foto): live/greeter.json (manda sobre greeter.json), live/wallpaper.jpg, live/wallpaper.mp4, live/avatars/<usuario>
//   wallpaperVideo: vídeo de fondo en bucle y sin sonido (necesita QtMultimedia: qt6-multimedia + qt6-multimedia-ffmpeg;
//                   si falta, o con «Reducir movimiento», se queda la imagen fija «wallpaper»)
//
//   greeter.json (opcional):
//     { "palette": "atardecer", "scene": "amanecer", "wallpaper": "/etc/greetd/quickshell/wallpaper.jpg",
//       "layouts": "es,us", "gameCommand": "gamescope -e -f -- steam -gamepadui" }
//     palette: cualquiera de palettes.json (claro / monoclaro → variante clara)
//     scene:   amanecer · lago · bosque · noche · bruma (se usa si no hay wallpaper)
//     theme:   el tema resuelto de tu sesión (copia de ~/.local/state/hyprfrijol/theme.json: c = colores,
//              S = estilo flat/aurora (o tonal con «Reducir transparencia»), light, font, reduceMotion). Lo escribe scripts/hf-greeter-sync
//              y, si está, manda sobre «palette».  defaultUser: usuario preseleccionado la primera vez.
//
// Vista previa sin greetd (no inicia nada, imprime el comando):
//   HF_GREETER_PREVIEW=1 qs -p greeter/quickshell                  (contraseña «error» → simula fallo)
//   HF_GREETER_PREVIEW=1 HF_GREETER_PALETTE=claro HF_GREETER_SCENE=bruma qs -p greeter/quickshell
//   HF_GREETER_OPEN=1 abre directamente el formulario (sin cortina) · HF_GREETER_MENU=sesion|a11y abre ese menú
//   HF_GREETER_CONFIG=/ruta/greeter.json usa ese archivo en lugar del de esta carpeta
//   HF_GREETER_ESTILO=flat|aurora fuerza el estilo (con sus valores por defecto; tonal = Aurora con «Reducir
//   transparencia»; liquid queda solo por compatibilidad)
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import Quickshell.Services.UPower

ShellRoot {
    id: root

    // ───────────── Modo y configuración ─────────────
    readonly property bool preview: Quickshell.env("HF_GREETER_PREVIEW") === "1" || !Greetd.available
    property var cfgBase: ({})
    property var cfgLive: ({})
    readonly property var cfg: Object.assign({}, cfgBase, cfgLive)
    readonly property string paletteKey: Quickshell.env("HF_GREETER_PALETTE") || cfg.palette || "atardecer"
    readonly property string sceneKey: Quickshell.env("HF_GREETER_SCENE") || cfg.scene || (th.light ? "bruma" : "amanecer")
    // Tema copiado de la sesión del usuario (hf-greeter-sync). HF_GREETER_PALETTE lo ignora para probar paletas.
    readonly property var theme: !Quickshell.env("HF_GREETER_PALETTE") && cfg.theme && cfg.theme.c ? cfg.theme : null
    readonly property string wallpaper: Quickshell.env("HF_GREETER_WALLPAPER") ?? cfg.wallpaper ?? ""
    readonly property string wallVideo: Quickshell.env("HF_GREETER_VIDEO") ?? cfg.wallpaperVideo ?? ""
    property var palettes: ({})
    readonly property var palette: palettes[paletteKey] ?? palettes.atardecer ?? fallbackPalette
    readonly property var fallbackPalette: ({ bg: "#14151B", s1: "#1C1D24", s3: "#272832", s4: "#31323D", p: "#EDBFA5", onP: "#4A2414",
        pc: "#4A3A45", onPc: "#F6DCCF", sc: "#3A3D4C", onSc: "#E2E3EE", ter: "#A9B4D6", t: "#E6E5EC", tv: "#B6B5C2",
        o: "#8E8D9B", ov: "#3A3A46", light: false })

    FileView {
        path: Quickshell.shellPath("palettes.json")
        blockLoading: true
        onLoaded: { try { root.palettes = JSON.parse(text()); } catch (e) { console.warn("palettes.json:", e); } }
    }
    FileView {
        path: Quickshell.env("HF_GREETER_CONFIG") || Quickshell.shellPath("greeter.json")
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.cfgBase = JSON.parse(text()); } catch (e) { console.warn("greeter.json:", e); } }
    }
    FileView {
        path: Quickshell.env("HF_GREETER_CONFIG") ? "" : Quickshell.shellPath("live/greeter.json")
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.cfgLive = JSON.parse(text()); } catch (e) { console.warn("live/greeter.json:", e); } }
    }

    // ───────────── Tema ─────────────
    // Colores: theme.c (tu sesión) o la paleta. Estilo: theme.S con los tokens del shell (scripts/hf-apply);
    // lo que falte se completa con los valores por defecto de cada estilo:
    //   liquid  vidrio muy translúcido y desenfocado, borde especular arriba a la izquierda, radios grandes
    //   flat    «Material» (Material 3 Expressive): superficies tonales sólidas, sin bordes, controles en píldora
    //   tonal   superficies tonales sólidas con borde fino
    //   aurora  vidrio esmerilado con brillo de color (tint → tint2) y borde luminoso
    QtObject {
        id: th
        readonly property var tm: root.theme
        readonly property var c: tm?.c ?? root.palette
        readonly property bool light: tm ? tm.light === true : c.light === true
        readonly property bool contrast: root.highContrast
        readonly property bool reduceMotion: tm?.reduceMotion === true
        // Estilo del shell en los nombres de antes: desde 0.9.0 es siempre Math y el material (S.material) dice
        // si es sólido (flat), cristal (skysoul) o tonal
        readonly property string shellEstilo: tm?.S?.material
            ? ({ cristal: "skysoul", solido: "flat", tonal: "tonal" })[tm.S.material] ?? "flat" : tm?.S?.estilo ?? ""
        readonly property string estilo: {
            // «liquid» ya no se ofrece en el shell: un theme.json antiguo con liquid pasa a Aurora
            const e = Quickshell.env("HF_GREETER_ESTILO") || shellEstilo || "aurora";
            // SkySoul (cristal) y Chroma (de antes) se muestran con su pariente más cercano del login: aurora y flat
            const m = ({ skysoul: "aurora", mica: "flat", chroma: "flat", suave: "flat", soft: "flat" })[e] ?? e;
            return ["liquid", "flat", "tonal", "aurora"].includes(m) ? m : "aurora";
        }
        // Solo se usan los tokens si son de este estilo (HF_GREETER_ESTILO puede forzar otro)
        readonly property var st: tm?.S && shellEstilo === estilo ? tm.S : ({})
        readonly property bool isLiquid: estilo === "liquid"
        readonly property bool isFlat: estilo === "flat"
        readonly property bool isTonal: estilo === "tonal"
        readonly property bool isAurora: estilo === "aurora"

        function tok(k, d) { const v = st[k]; return v === undefined || v === null || v === "" ? d : v; }
        function mix(a, b, t) { a = Qt.color(a); b = Qt.color(b); return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1); }
        function w(a) { return Qt.rgba(1, 1, 1, a); }
        function k0(a) { return Qt.rgba(0, 0, 0, a); }
        readonly property color none: "transparent"
        readonly property bool lt: light

        readonly property color bg: c.bg
        readonly property color p: c.p
        readonly property color pText: c.onP
        readonly property color pc: c.pc
        readonly property color pcText: c.onPc
        readonly property color sc: c.sc
        readonly property color scText: c.onSc
        readonly property color ter: c.ter
        readonly property color s1: c.s1
        readonly property color s3: c.s3
        readonly property color s4: c.s4
        readonly property color t: c.t
        readonly property color tv: contrast ? c.t : c.tv
        readonly property color ov: c.ov

        // Superficies: chip = S.bg (pastillas sobre el fondo) · card = S.bgPanel · popup = S.bgPopup · field = S.bg2
        readonly property color chip: contrast ? Qt.alpha(c.s1, 0.94) : tok("bg",
            isLiquid ? Qt.alpha(c.s1, lt ? .40 : .26) : isAurora ? Qt.alpha(mix(c.s1, c.p, .10), lt ? .52 : .40)
            : isTonal ? c.s3 : c.s1)
        readonly property color card: contrast ? Qt.alpha(c.s1, 0.96) : tok("bgPanel",
            isLiquid ? Qt.alpha(c.s1, lt ? .50 : .34) : isAurora ? Qt.alpha(mix(c.s1, c.p, .10), lt ? .62 : .50)
            : isTonal ? c.s3 : mix(c.s1, c.s3, .5))
        readonly property color popup: contrast ? Qt.alpha(c.s1, 0.97) : tok("bgPopup",
            isLiquid ? Qt.alpha(c.s1, lt ? .58 : .42) : isAurora ? Qt.alpha(mix(c.s1, c.p, .12), lt ? .70 : .58) : c.s3)
        readonly property color field: contrast ? Qt.alpha(c.s3, 0.96) : tok("bg2",
            isLiquid ? (lt ? w(.42) : Qt.alpha(c.t, .08)) : isAurora ? Qt.alpha(mix(c.s3, c.p, .16), lt ? .55 : .50) : c.s4)
        readonly property color fill2: Qt.alpha(c.t, lt ? .07 : .09)          // hover / fondos suaves
        readonly property color panel: card                                    // (compatibilidad)
        readonly property color border: contrast ? c.t : tok("border",
            isLiquid ? w(lt ? .55 : .10) : isAurora ? Qt.alpha(c.p, lt ? .30 : .22) : isTonal ? c.ov : none)
        readonly property real borderWidth: contrast ? 1.5 : tok("borderWidth", isFlat ? 0 : 1)
        readonly property color highlight: tok("highlight", isLiquid ? w(lt ? .85 : .22) : isAurora ? w(lt ? .6 : .16) : none)
        readonly property color glow: contrast ? none : tok("glow", isLiquid ? w(lt ? .30 : .05) : isAurora ? Qt.alpha(c.p, .18) : none)
        readonly property color rimTop: contrast ? none : tok("rimTop", isLiquid ? w(lt ? .95 : .42) : isAurora ? Qt.alpha(c.p, lt ? .75 : .60) : none)
        readonly property color rimBottom: contrast ? none : tok("rimBottom", isLiquid ? w(lt ? .35 : .06) : isAurora ? Qt.alpha(c.ter, lt ? .45 : .32) : none)
        readonly property color tint: contrast ? none : tok("tint", isAurora ? Qt.alpha(c.p, lt ? .20 : .18) : none)
        readonly property color tint2: contrast ? none : tok("tint2", isAurora ? Qt.alpha(c.ter, lt ? .16 : .13) : none)
        readonly property color shadow: tok("shadow", isFlat ? k0(lt ? .10 : .18) : isTonal ? k0(.2) : k0(lt ? .10 : .22))
        readonly property color shadowBig: tok("shadowBig", isFlat ? k0(lt ? .18 : .32) : isTonal ? k0(.35) : k0(lt ? .16 : .38))
        readonly property bool blur: tok("blur", isLiquid || isAurora) === true
        readonly property bool hasRim: rimTop.a > 0 || rimBottom.a > 0

        // Radios: el login es una superficie grande → algo más redondeado que los paneles del shell
        readonly property real panelRad: tok("panelRad", isLiquid ? 24 : isFlat ? 28 : isTonal ? 12 : 20)
        readonly property real barRad: tok("barRad", isLiquid ? 16 : isFlat ? 20 : isTonal ? 8 : 14)
        readonly property real ctlRad: tok("ctlRad", isLiquid ? 12 : isFlat ? 20 : isTonal ? 8 : 10)
        readonly property bool pill: tok("pill", isLiquid || isFlat) === true
        readonly property real cardRad: Math.min(40, panelRad + (isTonal ? 4 : 8))
        readonly property real popRad: Math.max(8, Math.round(panelRad * 0.75))
        function ctl(h) { return pill ? h / 2 : Math.min(h / 2, ctlRad); }       // botones y campos
        function chipR(h) { return pill ? h / 2 : Math.min(h / 2, Math.max(barRad, ctlRad)); }

        // Segmento elegido (método de acceso)
        readonly property color segOn: isFlat ? c.sc : isTonal ? Qt.alpha(c.p, .22) : isAurora ? Qt.alpha(c.p, lt ? .30 : .26) : (lt ? w(.85) : w(.14))
        readonly property color segOnText: isFlat ? c.onSc : c.t
        // Sombra suave del texto que va directamente sobre el fondo (reloj, fecha, usuarios)
        readonly property color textShadow: light ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.55)
        readonly property color veil: light ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, contrast ? 0.45 : 0.16)

        readonly property string font: {
            const f = Qt.fontFamilies();
            const want = tm?.font;
            return want && f.includes(want) ? want : f.includes("Inter") ? "Inter" : "Noto Sans";
        }
        readonly property real k: (root.bigText ? 1.22 : 1) * (tm?.fontScale ?? 1)
        function px(n) { return Math.round(n * k); }
        function dur(ms) { return reduceMotion ? 0 : ms; }
        // color del texto sobre una baldosa de color (como lg.* del diseño)
        function onTile(tile) { return tile === "p" ? pText : tile === "ter" ? bg : tile === "pc" ? pcText : tile === "sc" ? scText : t; }
        function tileColor(tile) { return tile === "p" ? p : tile === "ter" ? ter : tile === "pc" ? pc : tile === "sc" ? sc : s4; }
    }

    // ───────────── Usuarios (/etc/passwd, uid ≥ 1000) ─────────────
    property var users: []
    property int userIdx: 0
    property bool otherUser: false
    readonly property var user: otherUser ? ({ name: "", real: "Otro usuario", ini: "+" }) : (users[userIdx] ?? ({ name: "", real: "", ini: "?" }))
    property var lastLogins: ({})

    FileView {
        path: "/etc/passwd"
        blockLoading: true
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                const f = line.split(":");
                if (f.length < 7) continue;
                const uid = parseInt(f[2]);
                if (uid < 1000 || uid >= 60000 || /nologin|false$/.test(f[6])) continue;
                const real = (f[4] || "").split(",")[0].trim() || f[0];
                out.push({ name: f[0], real: real, ini: real.charAt(0).toUpperCase(), home: f[5] });
            }
            if (root.preview && out.length === 0) out.push({ name: "usuario", real: "Usuario", ini: "U", home: "" });
            root.users = out;
            root.restoreLast();
            lastProc.running = true;
        }
    }
    // «Última sesión: hoy 09:12» (wtmp; si no hay datos, no se muestra)
    Process {
        id: lastProc
        command: ["sh", "-c", 'for u in "$@"; do printf "%s " "$u"; last -n 1 --time-format iso "$u" 2>/dev/null | awk "NR==1 && NF>3 {print \\$4}" ; echo; done', "sh", ...root.users.map(u => u.name)]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.split("\n")) { const [u, d] = l.trim().split(" "); if (u && d) m[u] = d; }
                root.lastLogins = m;
            }
        }
    }
    function lastLine(name: string): string {
        const iso = lastLogins[name];
        if (!iso) return "";
        const d = new Date(iso);
        if (isNaN(d.getTime())) return "";
        const now = new Date();
        const hm = Qt.formatDateTime(d, "HH:mm");
        if (d.toDateString() === now.toDateString()) return "Última sesión: hoy " + hm;
        const y = new Date(now); y.setDate(now.getDate() - 1);
        if (d.toDateString() === y.toDateString()) return "Última sesión: ayer " + hm;
        return "Última sesión: " + Qt.locale("es_ES").toString(d, "d 'de' MMMM") + " " + hm;
    }

    // ───────────── Sesiones (/usr/share/wayland-sessions + Modo juego) ─────────────
    property var sessions: []
    property int sessIdx: 0
    readonly property var session: sessions[sessIdx] ?? ({ key: "", name: "Hyprland", g: "H", tile: "p", exec: "hf-session" })
    property bool hasGamescope: false

    Process {
        running: true
        command: ["sh", "-c", 'command -v gamescope >/dev/null && echo gs; command -v steam >/dev/null && echo steam; '
            + 'for f in /usr/share/wayland-sessions/*.desktop; do [ -f "$f" ] || continue; echo "@@ $(basename "$f" .desktop)"; '
            + 'grep -E "^(Name|Comment|Exec|DesktopNames|Hidden|NoDisplay)=" "$f"; done']
        stdout: StdioCollector { onStreamFinished: root.parseSessions(text) }
    }
    function parseSessions(txt: string): void {
        const list = [];
        let cur = null, gs = false, steam = false;
        for (const l of txt.split("\n")) {
            if (l === "gs") gs = true;
            else if (l === "steam") steam = true;
            else if (l.startsWith("@@ ")) { cur = { key: l.slice(3) }; list.push(cur); }
            else if (cur) {
                const i = l.indexOf("=");
                if (i > 0 && cur[l.slice(0, i)] === undefined) cur[l.slice(0, i)] = l.slice(i + 1);
            }
        }
        hasGamescope = gs;
        const out = [];
        let liquid = null, safe = null;
        for (const s of list) {
            if (s.Hidden === "true" || s.NoDisplay === "true" || !s.Exec) continue;
            const exec = s.Exec.replace(/\s%[a-zA-Z]/g, "");
            const desk = s.DesktopNames || s.Name;
            // Modo seguro (hf-session --safe): al final de la lista, para reparar si el escritorio no arranca
            if (s.key === "hyprfrijol-seguro") { safe = { key: s.key, name: "HyprFrijol (modo seguro)", sub: "Mínimo, sin shell ni plugins · para reparar", g: "S", tile: "sc", exec: exec, desk: "Hyprland" }; continue; }
            // hypr-liquid: nombre anterior de la sesión (instalaciones sin migrar)
            if (s.key === "hyprfrijol" || s.key === "hypr-liquid") { if (liquid && liquid.key === "hyprfrijol") continue; liquid = { key: s.key, name: "Hyprland", sub: "Este escritorio · Liquid sobrio", g: "H", tile: "p", exec: exec, desk: "Hyprland" }; continue; }
            const isHypr = /^hyprland/i.test(s.key);
            const name = isHypr ? (s.key === "hyprland-uwsm" ? "Hyprland (uwsm)" : "Hyprland (tu configuración)") : s.Name.replace(/\s*\(Wayland\)/i, "");
            const sub = isHypr ? "Hyprland con ~/.config/hypr" : ("Escritorio " + (/plasma/i.test(s.key) ? "KDE Plasma" : name));
            out.push({ key: s.key, name: name, sub: sub, g: name.charAt(0).toUpperCase().replace("P", /plasma/i.test(s.key) ? "K" : "P"), tile: "sc", exec: exec, desk: desk });
        }
        // «Hyprland (HyprFrijol)» siempre primero; si no está instalada (vista previa), una entrada que usa hf-session
        out.unshift(liquid ?? { key: "hyprfrijol", name: "Hyprland", sub: "Este escritorio · Liquid sobrio", g: "H", tile: "p", exec: "hf-session", desk: "Hyprland" });
        if (steam || root.preview) {
            out.splice(1, 0, { key: "game", name: "Modo juego (Steam)", g: "◈", tile: "ter", desk: "gamescope",
                               sub: gs ? "Steam a pantalla completa · gamescope" : "Necesita gamescope (no instalado)",
                               exec: root.cfg.gameCommand || "gamescope -e -f -- steam -gamepadui -steamos3", disabled: !gs && !root.preview });
        }
        if (safe || root.preview) out.push(safe ?? { key: "hyprfrijol-seguro", name: "HyprFrijol (modo seguro)", sub: "Mínimo, sin shell ni plugins · para reparar", g: "S", tile: "sc", exec: "hf-session --safe", desk: "Hyprland" });
        sessions = out;
        restoreLast();
    }

    // ───────────── Recordar último usuario y sesión ─────────────
    // El usuario «greeter» tiene HOME=/ (o «//»), donde no puede escribir: por eso no recordaba nada. Su carpeta
    // propia la crean install.sh --greeter y hf-greeter-sync (/var/lib/hyprfrijol-greeter, del usuario greeter).
    readonly property string memPath: {
        const st = Quickshell.env("HF_GREETER_STATE");
        if (st) return st + "/hf-greeter.json";
        const home = (Quickshell.env("HOME") || "").replace(/\/+$/, "");
        if (!home) return "/var/lib/hyprfrijol-greeter/hf-greeter.json";
        return (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/hf-greeter.json";
    }
    property var mem: ({})
    FileView {
        id: memFile
        path: root.preview ? "" : root.memPath
        blockLoading: true
        printErrors: false
        onLoaded: { try { root.mem = JSON.parse(text()); } catch (e) {} root.restoreLast(); }
    }
    function restoreLast(): void {
        const ui = users.findIndex(u => u.name === (mem.user ?? cfg.defaultUser));
        if (ui >= 0) userIdx = ui;
        const si = root.sessionIndex((mem.sessions ?? {})[user.name]);
        if (si >= 0) sessIdx = si;
    }
    // Sesión recordada; «hypr-liquid» (nombre anterior) es la de este escritorio
    function sessionIndex(key: string): int {
        const k = key === "hypr-liquid" ? sessions[0]?.key : key;
        return sessions.findIndex(s => s.key === k);
    }
    function remember(): void {
        if (preview) return;
        const s = Object.assign({}, mem.sessions ?? {});
        if (session.key !== "hyprfrijol-seguro") s[user.name] = session.key;   // el modo seguro no se recuerda: la próxima vez, la sesión normal
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", memPath,
                                 JSON.stringify({ user: user.name, sessions: s })]);
    }
    onUserIdxChanged: { const si = sessionIndex((mem.sessions ?? {})[user.name]); if (si >= 0) sessIdx = si; }

    // ───────────── Estado de la pantalla ─────────────
    property bool curtain: Quickshell.env("HF_GREETER_OPEN") !== "1"
    property string method: "pass"            // pass | finger | key
    property string phase: "idle"             // idle | auth | busy
    property string msg: ""
    property bool msgError: false
    property int step: 0
    property bool sessOpen: Quickshell.env("HF_GREETER_MENU") === "sesion"
    property bool a11yOpen: Quickshell.env("HF_GREETER_MENU") === "a11y"
    property bool highContrast: false
    property bool bigText: false
    property bool caps: false
    property string password: ""
    property string otherName: ""
    property bool pendingPrompt: false        // greetd espera una respuesta
    property bool sentPassword: false
    property bool hasFprint: false
    property bool hasU2f: false
    readonly property var methods: {
        const m = [{ key: "pass", label: "Contraseña" }];
        if (hasFprint || preview) m.push({ key: "finger", label: "Huella" });
        if (hasU2f || preview) m.push({ key: "key", label: "Llave" });
        return m;
    }
    readonly property var steps: ["Comprobando…", "Iniciando " + session.name + "…", "Restaurando tus espacios…", "Bienvenido"]
    signal shake()
    signal clearPassword()
    signal focusPassword()

    Process {
        running: true
        command: ["sh", "-c", "command -v fprintd-verify >/dev/null && echo fp; ls /usr/lib/security/pam_u2f.so /usr/lib64/security/pam_u2f.so 2>/dev/null | head -n1 | grep -q . && echo u2f; true"]
        stdout: StdioCollector { onStreamFinished: { root.hasFprint = text.includes("fp"); root.hasU2f = text.includes("u2f"); } }
    }
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.trim() !== "" && text.trim() !== "0" }
    }
    function checkCaps(): void { capsProc.running = true; }

    // true mientras hay transiciones (el vidrio resincroniza su recorte del fondo cada fotograma)
    property bool moving: false
    Timer { id: movingTimer; interval: 700; onTriggered: root.moving = false }
    function bump(): void { moving = true; movingTimer.restart(); }
    onCurtainChanged: bump()
    onSessOpenChanged: bump()
    onA11yOpenChanged: bump()
    onPhaseChanged: bump()
    onOtherUserChanged: bump()

    function wake(): void { if (curtain) { curtain = false; idleTimer.restart(); Qt.callLater(() => focusPassword()); } }
    function activity(): void { idleTimer.restart(); }
    // Sin actividad, vuelve a la cortina (como un salvapantallas)
    Timer { id: idleTimer; interval: 90000; running: !root.curtain && root.phase === "idle"; onTriggered: { root.curtain = true; root.sessOpen = false; root.a11yOpen = false; } }

    function pickUser(i: int): void {
        cancelAuth();
        otherUser = i < 0;
        if (i >= 0) userIdx = i;
        msg = ""; msgError = false;
        clearPassword();
        focusPassword();
    }
    function setMethod(k: string): void {
        cancelAuth();
        method = k; msg = ""; msgError = false;
        if (k !== "pass") startAuth("");
        else focusPassword();
    }

    function loginName(): string { return otherUser ? otherName.trim() : user.name; }
    function submit(): void {
        if (phase === "busy") return;
        if (otherUser && loginName() === "") { fail("Escribe el nombre de usuario"); return; }
        if (method === "pass" && password === "") { fail("Escribe tu contraseña"); return; }
        if (session.disabled) { fail("Instala gamescope para el Modo juego"); return; }
        if (pendingPrompt && Greetd.state === GreetdState.Authenticating) {
            pendingPrompt = false; sentPassword = true; phase = "auth";
            Greetd.respond(password);
            return;
        }
        startAuth(password);
    }
    function startAuth(pw: string): void {
        msg = ""; msgError = false;
        phase = "auth";
        sentPassword = false;
        if (preview) { fakeAuth.pw = pw; fakeAuth.restart(); return; }
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
        Greetd.createSession(loginName());
    }
    function cancelAuth(): void {
        pendingPrompt = false;
        fakeAuth.stop();
        if (!preview && Greetd.state !== GreetdState.Inactive && Greetd.state !== GreetdState.Launching) Greetd.cancelSession();
        if (phase === "auth") phase = "idle";
    }
    function fail(m: string): void {
        phase = "idle";
        msg = m; msgError = true;
        pendingPrompt = false;
        password = "";
        clearPassword();
        shake();
        focusPassword();
    }
    function succeed(): void {
        remember();
        phase = "busy";
        step = 1;
        stepTimer.restart();
        // La sesión arranca ya: antes se esperaba a que pasaran los cuatro mensajes (≈2,6 s de espera de adorno).
        // Los mensajes siguen avanzando mientras greetd cierra el login.
        Qt.callLater(root.launch);
    }
    Timer {
        id: stepTimer
        interval: 450
        repeat: true
        onTriggered: { if (root.step < root.steps.length - 1) root.step++; else stop(); }
    }
    function launch(): void {
        const s = session;
        const env = ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=" + (s.desk || s.name), "XDG_SESSION_DESKTOP=" + s.key];
        // greetd (source_profile = true) une los argumentos con espacios: «sh -c exec …» se rompía y la sesión
        // volvía al login en ~20 ms. En palabras sueltas sirve igual con el envoltorio de greetd y sin él.
        const cmd = s.exec.trim().split(/\s+/);
        if (preview) {
            console.info("[greeter] (vista previa) iniciaría:", JSON.stringify(cmd), "como", loginName(), "env", JSON.stringify(env));
            resetPreview.restart();
            return;
        }
        Greetd.launch(cmd, env, true);
    }
    Timer { id: resetPreview; interval: 1500; onTriggered: { root.phase = "idle"; root.step = 0; root.password = ""; root.clearPassword(); } }

    // Vista previa: simula greetd (la contraseña «error» falla; la huella/llave tienen éxito a los 2 s)
    Timer {
        id: fakeAuth
        property string pw: ""
        interval: root.method === "pass" ? 700 : 2200
        onTriggered: {
            if (root.method === "pass" && pw === "error") root.fail("Contraseña incorrecta. Inténtalo de nuevo");
            else root.succeed();
        }
    }

    Connections {
        target: Greetd
        enabled: !root.preview
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool) {
            if (responseRequired) {
                // Primera petición: la contraseña ya escrita. Si llega otra (huella → contraseña, OTP…), se pide al usuario.
                if (root.method === "pass" && !root.sentPassword && root.password !== "") {
                    root.sentPassword = true;
                    Greetd.respond(root.password);
                } else {
                    root.pendingPrompt = true;
                    root.phase = "idle";
                    if (root.method !== "pass") root.method = "pass";
                    root.msg = /password|contraseña/i.test(message) ? "" : message.replace(/:\s*$/, "");
                    root.msgError = false;
                    root.focusPassword();
                }
            } else {
                // Aviso (p. ej. «Coloca el dedo en el lector»)
                root.msg = message; root.msgError = error;
                Greetd.respond("");
            }
        }
        function onAuthFailure(message: string) {
            root.fail(root.method === "pass" ? "Contraseña incorrecta. Inténtalo de nuevo" : (message || "No se pudo verificar"));
        }
        function onReadyToLaunch() { root.succeed(); }
        function onError(error: string) { root.fail("Error de greetd: " + error); }
    }

    // ───────────── Energía / teclado / estado ─────────────
    function power(what: string): void {
        const cmd = { suspend: "systemctl suspend", reboot: "systemctl reboot", poweroff: "systemctl poweroff" }[what];
        if (preview) { console.info("[greeter] (vista previa)", cmd); return; }
        Quickshell.execDetached(["sh", "-c", cmd]);
    }
    property string layout: "ES"
    Process {
        id: layoutProc
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main)][0].active_keymap // empty'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim().toLowerCase();
                const map = { spanish: "ES", english: "EN", latin: "LA", portuguese: "PT", french: "FR", german: "DE", italian: "IT", catalan: "CA" };
                for (const k in map) if (n.includes(k)) { root.layout = map[k]; return; }
                if (n) root.layout = n.slice(0, 2).toUpperCase();
            }
        }
    }
    function nextLayout(): void {
        if (preview) return;
        Quickshell.execDetached(["sh", "-c", "hyprctl switchxkblayout all next"]);
        layoutTimer.restart();
    }
    Timer { id: layoutTimer; interval: 250; onTriggered: layoutProc.running = true }
    Component.onCompleted: layoutProc.running = true

    property bool online: false
    Process {
        id: netProc
        running: true
        command: ["sh", "-c", "nmcli -t -f STATE g 2>/dev/null || cat /sys/class/net/*/operstate 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.online = /connected|^up$/m.test(text) && !/disconnected/.test(text) }
    }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: netProc.running = true }
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property int batteryPct: Math.round((battery?.percentage ?? 0) * 100)

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    readonly property string hhmm: Qt.formatDateTime(now, "HH:mm")
    readonly property string longDate: Qt.locale("es_ES").toString(now, "dddd, d 'de' MMMM")

    // A11y: lector de pantalla y teclado en pantalla (si están instalados)
    property bool reader: false
    property bool osk: false
    property string oskCmd: ""
    property bool hasOrca: false
    Process {
        running: true
        command: ["sh", "-c", "command -v orca >/dev/null && echo orca; for k in wvkbd-mobintl squeekboard onboard; do command -v $k >/dev/null && { echo osk:$k; break; }; done; true"]
        stdout: StdioCollector { onStreamFinished: { root.hasOrca = text.includes("orca"); const m = text.match(/osk:(\S+)/); root.oskCmd = m ? m[1] : ""; } }
    }
    function toggleReader(): void {
        reader = !reader;
        if (preview || !hasOrca) return;
        Quickshell.execDetached(["sh", "-c", reader ? "orca --replace &" : "pkill -x orca"]);
    }
    function toggleOsk(): void {
        osk = !osk;
        if (preview || !oskCmd) return;
        Quickshell.execDetached(["sh", "-c", osk ? oskCmd + " &" : "pkill -x " + oskCmd]);
    }

    // ───────────── Componentes ─────────────
    component GIcon: Item {
        id: ic
        property string name: ""
        property color color: th.t
        property real size: 14
        implicitWidth: size; implicitHeight: size
        readonly property var paths: ({
            eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
            eyeoff: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/><path d="M4 20 20 4"/>',
            arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
            wifi: '<path d="M2 9a15 15 0 0 1 20 0"/><path d="M5 12.5a10 10 0 0 1 14 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/>',
            wifioff: '<path d="M2 9a15 15 0 0 1 20 0"/><path d="M5 12.5a10 10 0 0 1 14 0"/><path d="M8.5 16a5 5 0 0 1 7 0"/><path d="M3 3l18 18"/>',
            battery: '<rect x="2" y="7" width="17" height="10" rx="2"/><path d="M22 11v2"/><rect x="5" y="10" width="10" height="4" rx="1" fill="currentColor" stroke="none"/>',
            a11y: '<circle cx="12" cy="4.5" r="1.8"/><path d="M5 8h14M12 8v6M9 21l3-7 3 7"/>',
            moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
            restart: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/>',
            power: '<path d="M12 2v10"/><path d="M18.4 6.6a9 9 0 1 1-12.8 0"/>',
            finger: '<path d="M12 11v4M8.5 8.5a5 5 0 0 1 8 4v2M7 13v1a5 5 0 0 0 2 4M17 17a8 8 0 0 1-1 3M5 10a7 7 0 0 1 12-4"/>',
            key: '<circle cx="8" cy="14" r="4"/><path d="M11 11l9-9M17 5l2 2M15 7l2 2"/>',
            check: '<path d="M5 12l5 5L20 7"/>',
            user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>'
        })
        function hex(c) { const h = n => Math.round(n * 255).toString(16).padStart(2, "0"); return "#" + h(c.r) + h(c.g) + h(c.b); }
        Image {
            anchors.fill: parent
            opacity: ic.color.a
            sourceSize: Qt.size(Math.ceil(ic.size * 2), Math.ceil(ic.size * 2))
            source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
                + ic.hex(ic.color) + '" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
                + (ic.paths[ic.name] ?? "").replace(/currentColor/g, ic.hex(ic.color)) + '</svg>')
        }
    }
    component GText: Text {
        property real size: 12.5
        property bool muted: false
        color: muted ? th.tv : th.t
        font.family: th.font
        font.pixelSize: th.px(size)
        renderType: Text.QtRendering
        verticalAlignment: Text.AlignVCenter
    }
    // Superficie con el estilo activo. Como el greeter no tiene desenfoque del compositor sobre su propio
    // contenido, el vidrio se emula con un recorte desenfocado del fondo (blurSource) bajo el tinte.
    //   capas: halo de color (aurora) · sombra · fondo desenfocado · tinte · brillo de color (aurora)
    //          · brillo interior arriba · borde · borde especular (degradado rimTop → rimBottom)
    component GlassBox: Item {
        id: gb
        property real radius: 16
        property color tint: th.card
        property bool showBorder: true
        property bool rim: true
        property bool aurora: false              // brillo de color (aurora) en superficies grandes
        property bool big: false                 // sombra grande
        property bool small: false               // sombra pequeña
        property bool focused: false             // anillo de foco (campos)
        property bool error: false
        property Item blurSource: null
        readonly property bool frosted: th.blur && blurSource !== null && tint.a < 0.985

        // Halo de color (aurora)
        RectangularShadow {
            anchors.fill: parent
            radius: gb.radius
            visible: gb.aurora && th.tint.a > 0
            blur: 80; spread: 4
            color: Qt.alpha(th.tint, Math.min(1, th.tint.a * 2.2))
        }
        RectangularShadow {
            anchors.fill: parent
            radius: gb.radius
            visible: (gb.big || gb.small) && color.a > 0
            offset.y: gb.big ? 18 : 4; blur: gb.big ? 52 : 16
            color: gb.big ? th.shadowBig : th.shadow
        }
        Item {
            id: clipMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: gb.radius }
        }
        ShaderEffectSource {
            id: cut
            anchors.fill: parent
            visible: false
            sourceItem: gb.frosted ? gb.blurSource : null
            live: gb.frosted
            property point at: Qt.point(0, 0)
            sourceRect: Qt.rect(at.x, at.y, gb.width, gb.height)
            function sync() { if (gb.frosted && gb.visible) at = gb.mapToItem(gb.blurSource, 0, 0); }
        }
        MultiEffect {
            anchors.fill: parent
            visible: gb.frosted
            source: cut
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.5
            maskSource: clipMask
        }
        // Mientras algo se mueve (transiciones) se resincroniza cada fotograma; en reposo, de vez en cuando
        FrameAnimation { running: gb.frosted && gb.visible && root.moving; onTriggered: cut.sync() }
        Timer { interval: 250; running: gb.frosted && gb.visible; repeat: true; triggeredOnStart: true; onTriggered: cut.sync() }

        Rectangle {
            anchors.fill: parent
            radius: gb.radius
            color: gb.tint
            Behavior on color { ColorAnimation { duration: th.dur(200) } }
        }
        // Aurora: dos manchas de luz difusas (tint arriba a la izquierda, tint2 abajo a la derecha)
        Item {
            id: auroraSrc
            anchors.fill: parent
            visible: false
            layer.enabled: auroraFx.visible
            Rectangle {
                width: Math.max(parent.width, parent.height) * 0.95; height: width; radius: width / 2
                x: -width * 0.38; y: -height * 0.62
                color: Qt.alpha(th.tint, Math.min(0.6, th.tint.a * (th.light ? 2.6 : 2.0)))
            }
            Rectangle {
                width: Math.max(parent.width, parent.height) * 0.85; height: width; radius: width / 2
                x: parent.width - width * 0.55; y: parent.height - height * 0.42
                color: Qt.alpha(th.tint2, Math.min(0.6, th.tint2.a * (th.light ? 2.6 : 2.0)))
            }
        }
        MultiEffect {
            id: auroraFx
            anchors.fill: parent
            visible: gb.aurora && (th.tint.a > 0 || th.tint2.a > 0) && gb.width > 0
            source: auroraSrc
            blurEnabled: true
            blur: 1
            blurMax: 64
            autoPaddingEnabled: false
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.5
            maskSource: clipMask
        }
        // Brillo interior arriba (luz que entra por el vidrio)
        Rectangle {
            anchors.fill: parent
            radius: gb.radius
            visible: th.glow.a > 0 && gb.rim
            gradient: Gradient {
                GradientStop { position: 0; color: th.glow }
                GradientStop { position: 0.5; color: Qt.alpha(th.glow, 0) }
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: gb.radius
            color: "transparent"
            border.width: gb.error ? 1.5 : gb.focused ? 1.5 : gb.showBorder ? th.borderWidth : 0
            border.color: gb.error ? Qt.alpha(th.ter, 0.85) : gb.focused ? Qt.alpha(th.p, th.isFlat ? 0.9 : 0.7) : th.border
            Behavior on border.color { ColorAnimation { duration: th.dur(160) } }
        }
        // Borde especular: degradado diagonal (arriba-izquierda → abajo-derecha) recortado a un anillo de 1 px
        Item {
            id: rimSrc
            anchors.fill: parent
            visible: false
            clip: true
            layer.enabled: rimFx.visible
            Rectangle {
                readonly property real d: Math.hypot(gb.width, gb.height)
                width: d; height: d
                anchors.centerIn: parent
                rotation: -45
                gradient: Gradient {
                    GradientStop { position: 0.0; color: th.rimTop }
                    GradientStop { position: 0.36; color: Qt.alpha(th.rimTop, 0) }
                    GradientStop { position: 0.64; color: Qt.alpha(th.rimBottom, 0) }
                    GradientStop { position: 1.0; color: th.rimBottom }
                }
            }
        }
        Rectangle {
            id: ring
            anchors.fill: parent
            radius: gb.radius
            color: "transparent"
            border.width: 1.25
            border.color: "white"
            antialiasing: true
            visible: false
            layer.enabled: rimFx.visible
            layer.smooth: true
        }
        MultiEffect {
            id: rimFx
            anchors.fill: parent
            visible: gb.rim && gb.showBorder && th.hasRim && !gb.error && !gb.focused && gb.width > 0
            source: rimSrc
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.5
            maskSource: ring
        }
    }
    component RoundBtn: Item {
        id: rb
        property string icon: ""
        property bool on: false
        property real size: 26
        signal clicked()
        implicitWidth: size; implicitHeight: size
        Rectangle { anchors.fill: parent; radius: width / 2; color: rb.on ? th.fill2 : rbMa.containsMouse ? th.fill2 : "transparent" }
        GIcon { anchors.centerIn: parent; name: rb.icon; color: th.t }
        MouseArea { id: rbMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    // ───────────── Ventanas: una por pantalla; el formulario solo en la principal ─────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            readonly property bool primary: modelData === Quickshell.screens[0]
            screen: modelData
            color: th.bg
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hf-greeter"
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }

            // Fondo nítido y su copia desenfocada (para el vidrio)
            Item {
                id: backdrop
                anchors.fill: parent
                Landscape { anchors.fill: parent; preset: root.sceneKey; visible: wallImg.status !== Image.Ready }
                Image {
                    id: wallImg
                    anchors.fill: parent
                    source: root.wallpaper ? "file://" + root.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(win.width, win.height)
                    visible: status === Image.Ready
                }
                // Vídeo en bucle por encima de la imagen fija (que sirve de póster mientras arranca). En un archivo
                // aparte: si QtMultimedia no está instalado, el Loader falla sin romper el login y queda la imagen.
                Loader {
                    id: wallVid
                    anchors.fill: parent
                    active: root.wallVideo !== "" && !th.reduceMotion
                    source: "VideoBackdrop.qml"
                    onLoaded: item.source = root.wallVideo
                    opacity: item?.ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 600 } }
                }
            }
            MultiEffect {
                id: blurred
                anchors.fill: parent
                source: backdrop
                blurEnabled: true
                blur: 1
                blurMax: 64
                // Vibrancia: el vidrio oscurece (o aclara) lo que tiene detrás para que el texto se lea sobre cualquier fondo
                saturation: 0.35
                brightness: th.light ? 0.16 : -0.26
                // Por debajo del fondo nítido: solo se usa como textura del vidrio
                z: -1
            }
            Rectangle { anchors.fill: parent; color: th.veil }
            // Con el formulario abierto el fondo se oscurece (o aclara) un poco
            Rectangle {
                anchors.fill: parent
                color: th.light ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.18)
                opacity: root.curtain ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: th.dur(500); easing.type: Easing.OutCubic } }
            }

            Item {
                id: ui
                anchors.fill: parent
                visible: win.primary
                focus: true
                Keys.onPressed: event => {
                    root.activity();
                    if (root.curtain) { root.wake(); event.accepted = true; return; }
                    if (event.key === Qt.Key_Escape) {
                        if (root.sessOpen || root.a11yOpen) { root.sessOpen = false; root.a11yOpen = false; }
                        else if (root.phase === "auth") root.cancelAuth();
                        else root.curtain = true;
                        event.accepted = true;
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: root.activity()
                    onClicked: { root.sessOpen = false; root.a11yOpen = false; if (root.curtain) root.wake(); else root.focusPassword(); }
                }

                // ── Cortina en reposo ──
                Item {
                    anchors.fill: parent
                    opacity: root.curtain ? 1 : 0
                    visible: opacity > 0
                    scale: root.curtain ? 1 : 1.06
                    Behavior on opacity { NumberAnimation { duration: th.dur(360); easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: th.dur(420); easing.type: Easing.OutCubic } }
                    ColumnLayout {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -4
                        spacing: 8
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: th.textShadow; shadowBlur: 0.9; shadowVerticalOffset: 1; shadowHorizontalOffset: 0 }
                        GText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.hhmm
                            font.pixelSize: 132
                            font.weight: Font.Light
                            font.letterSpacing: -0.045 * 132
                            font.features: { "tnum": 1 }
                        }
                        GText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -10; text: root.longDate; size: 19 }
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 26
                            implicitWidth: hint.implicitWidth + 28; implicitHeight: 30
                            GlassBox { anchors.fill: parent; radius: th.chipR(height); tint: th.chip; blurSource: blurred; small: true }
                            GText { id: hint; anchors.centerIn: parent; text: "Haz clic o presiona una tecla"; muted: true }
                            SequentialAnimation on opacity {
                                running: root.curtain; loops: Animation.Infinite
                                PauseAnimation { duration: 2500 }
                                NumberAnimation { to: 0.55; duration: 1100; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 26
                        spacing: 14
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: th.textShadow; shadowBlur: 0.9; shadowVerticalOffset: 1; shadowHorizontalOffset: 0 }
                        Repeater {
                            model: {
                                const a = [Quickshell.env("HOSTNAME") || "hyprfrijol"];
                                if (root.hasBattery) a.push("Batería " + root.batteryPct + " %");
                                if (root.caps) a.push("Bloq Mayús activado");
                                const out = [];
                                for (let i = 0; i < a.length; i++) { if (i) out.push("·"); out.push(a[i]); }
                                return out;
                            }
                            GText { required property var modelData; text: modelData; size: 12; muted: true }
                        }
                    }
                }

                // ── Formulario ──
                Item {
                    id: form
                    anchors.fill: parent
                    opacity: root.curtain ? 0 : 1
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: th.dur(400); easing.type: Easing.OutCubic } }
                    transform: Translate { y: root.curtain ? 14 : 0; Behavior on y { NumberAnimation { duration: th.dur(420); easing.type: Easing.OutCubic } } }

                    // Reloj pequeño arriba
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 56
                        spacing: 4
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: th.textShadow; shadowBlur: 0.9; shadowVerticalOffset: 1; shadowHorizontalOffset: 0 }
                        GText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.hhmm
                            font.pixelSize: 64
                            font.weight: Font.Light
                            font.letterSpacing: -0.035 * 64
                            font.features: { "tnum": 1 }
                        }
                        GText { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: -6; text: root.longDate; size: 14; muted: true }
                    }

                    // Centro: tarjeta con avatar (asomando por arriba), nombre y acceso
                    Item {
                        id: cardBox
                        readonly property real pad: 28
                        width: 340 + 2 * pad
                        height: center.implicitHeight + pad
                        x: (parent.width - width) / 2
                        y: Math.max(150, parent.height / 2 - 0.44 * 290)
                        transformOrigin: Item.Top
                        scale: root.curtain ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: th.dur(460); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                        Behavior on height { NumberAnimation { duration: th.dur(260); easing.type: Easing.OutCubic } }
                        GlassBox {
                            anchors.fill: parent
                            anchors.topMargin: 48
                            radius: th.cardRad
                            tint: th.card
                            blurSource: blurred
                            big: true
                            aurora: true
                        }
                        MouseArea { anchors.fill: parent; anchors.topMargin: 48; onClicked: root.focusPassword() }
                    ColumnLayout {
                        id: center
                        width: 340
                        x: cardBox.pad
                        y: 0
                        spacing: 12

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 96; implicitHeight: 96
                            RectangularShadow { anchors.fill: avatar; radius: 48; offset.y: 12; blur: 34; color: Qt.rgba(0, 0, 0, 0.22) }
                            Rectangle {
                                anchors.centerIn: parent; width: 110; height: 110; radius: 55
                                color: th.isFlat || th.isTonal ? th.card : Qt.alpha(th.p, 0.18)
                                border.width: th.isTonal ? th.borderWidth : 0; border.color: th.border
                            }
                            Rectangle {
                                id: avatar
                                anchors.fill: parent
                                radius: 48
                                color: root.otherUser ? th.s4 : th.pc
                                border.width: th.isFlat || th.isTonal ? 0 : 1; border.color: Qt.rgba(1, 1, 1, th.light ? 0.6 : 0.18)
                                clip: true
                                GText {
                                    anchors.centerIn: parent
                                    visible: face.status !== Image.Ready
                                    text: root.user.ini
                                    size: 36
                                    font.weight: Font.Medium
                                    color: root.otherUser ? th.t : th.pcText
                                }
                                Image {
                                    id: face
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    // Primero la copia de hf-greeter-sync (el greeter no puede leer ~/.face), luego AccountsService
                                    readonly property string uname: root.otherUser || !root.user.name ? "" : root.user.name
                                    property int alt: 0
                                    onUnameChanged: alt = 0
                                    onStatusChanged: if (status === Image.Error && alt < 1) alt++
                                    source: !uname ? "" : alt === 0 ? "file://" + Quickshell.shellPath("live/avatars/" + uname)
                                          : root.preview ? "" : "file:///var/lib/AccountsService/icons/" + uname
                                    sourceSize: Qt.size(192, 192)
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                    layer.enabled: visible
                                    layer.effect: MultiEffect { maskEnabled: true; maskThresholdMin: 0.5; maskSpreadAtMin: 0.5; maskSource: faceMask }
                                }
                                Item { id: faceMask; anchors.fill: parent; visible: false; layer.enabled: true; Rectangle { anchors.fill: parent; radius: 48 } }
                            }
                        }
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2
                            GText { Layout.alignment: Qt.AlignHCenter; text: root.user.real; size: 19; font.weight: Font.Medium }
                            GText {
                                Layout.alignment: Qt.AlignHCenter
                                readonly property string line: root.otherUser ? "Escribe usuario y contraseña" : root.lastLine(root.user.name)
                                visible: line !== ""
                                text: line; size: 12; muted: true
                            }
                        }

                        // Acceso (en reposo) o progreso (iniciando)
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            spacing: 10
                            visible: root.phase !== "busy"

                            // Usuario (solo «Otro usuario»)
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 44
                                visible: root.otherUser
                                GlassBox { anchors.fill: parent; radius: th.ctl(height); tint: th.field; rim: false; focused: nameInput.activeFocus && !th.isLiquid }
                                GText { anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; visible: nameInput.text === ""; text: "Usuario"; size: 14; muted: true }
                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: th.t; font.family: th.font; font.pixelSize: th.px(14)
                                    selectionColor: th.p; selectedTextColor: th.pText
                                    clip: true
                                    onTextChanged: root.otherName = text
                                    Keys.onReturnPressed: pwInput.forceActiveFocus()
                                    Keys.onTabPressed: event => { pwInput.forceActiveFocus(); event.accepted = true; }
                                }
                            }

                            Item {
                                id: field
                                Layout.fillWidth: true
                                implicitHeight: 44
                                transform: Translate { id: shakeT }
                                SequentialAnimation {
                                    id: shakeAnim
                                    NumberAnimation { target: shakeT; property: "x"; to: -10; duration: 50 }
                                    NumberAnimation { target: shakeT; property: "x"; to: 9; duration: 70 }
                                    NumberAnimation { target: shakeT; property: "x"; to: -6; duration: 70 }
                                    NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 60 }
                                    NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
                                }
                                Connections {
                                    target: root
                                    function onShake() { shakeAnim.restart(); }
                                    function onClearPassword() { pwInput.text = ""; }
                                    function onFocusPassword() {
                                        if (!win.primary) return;
                                        if (root.otherUser && nameInput.text === "") nameInput.forceActiveFocus();
                                        else pwInput.forceActiveFocus();
                                    }
                                }
                                GlassBox {
                                    anchors.fill: parent; radius: th.ctl(height); tint: th.field; rim: false
                                    error: root.msgError
                                    focused: pwInput.activeFocus && !th.isLiquid
                                }

                                // Contraseña
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16; anchors.rightMargin: 5
                                    spacing: 6
                                    visible: root.method === "pass"
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        GText { anchors.verticalCenter: parent.verticalCenter; visible: pwInput.text === ""; text: root.phase === "auth" ? "Comprobando…" : "Contraseña"; size: 14; color: th.t; opacity: 0.9 }
                                        TextInput {
                                            id: pwInput
                                            anchors.left: parent.left; anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            echoMode: showPw.on ? TextInput.Normal : TextInput.Password
                                            passwordCharacter: "●"
                                            color: th.t; font.family: th.font; font.pixelSize: th.px(14)
                                            selectionColor: th.p; selectedTextColor: th.pText
                                            clip: true
                                            enabled: root.phase !== "auth" || root.pendingPrompt
                                            onTextChanged: { root.password = text; if (text !== "" && root.msgError) { root.msg = ""; root.msgError = false; } }
                                            onAccepted: root.submit()
                                            Keys.onPressed: event => { root.activity(); root.checkCaps(); }
                                            Keys.onTabPressed: event => { if (root.otherUser) nameInput.forceActiveFocus(); event.accepted = true; }
                                        }
                                    }
                                    RoundBtn { id: showPw; icon: on ? "eyeoff" : "eye"; size: 30; onClicked: on = !on }
                                    Item {
                                        implicitWidth: 34; implicitHeight: 34
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: th.pill ? 17 : Math.max(4, th.ctl(44) - 5)
                                            color: goMa.containsMouse ? Qt.lighter(th.p, 1.08) : th.p
                                            scale: goMa.pressed ? 0.92 : 1
                                            Behavior on scale { NumberAnimation { duration: th.dur(120) } }
                                        }
                                        GIcon { anchors.centerIn: parent; name: "arrow"; color: th.pText; visible: root.phase !== "auth" }
                                        Rectangle {
                                            anchors.centerIn: parent; width: 14; height: 14; radius: 7
                                            color: "transparent"; border.width: 2; border.color: th.pText
                                            visible: root.phase === "auth"
                                            Rectangle { width: 6; height: 6; radius: 3; color: th.p; x: 7; y: -2 }
                                            RotationAnimation on rotation { running: root.phase === "auth"; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
                                        }
                                        MouseArea { id: goMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                                    }
                                }
                                // Huella / llave
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    visible: root.method !== "pass"
                                    GIcon {
                                        name: root.method === "finger" ? "finger" : "key"; size: 17; color: th.p
                                        SequentialAnimation on opacity {
                                            running: root.method !== "pass" && root.phase === "auth"; loops: Animation.Infinite
                                            NumberAnimation { to: 0.35; duration: 700 } NumberAnimation { to: 1; duration: 700 }
                                        }
                                    }
                                    GText { text: root.method === "finger" ? "Toca el lector de huellas" : "Conecta y toca tu llave de seguridad"; muted: true }
                                }
                            }
                            GText {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: 16
                                size: 12
                                color: root.msgError ? th.ter : th.tv
                                text: root.msg !== "" ? root.msg : root.method !== "pass" ? "" : root.caps ? "Bloq Mayús activado" : "Bloq Mayús desactivado"
                            }
                            // Método de acceso
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                visible: root.methods.length > 1
                                implicitWidth: segRow.implicitWidth + 8; implicitHeight: 32
                                radius: th.ctl(height)
                                color: th.field
                                border.width: th.isTonal ? th.borderWidth : 0; border.color: th.border
                                RowLayout {
                                    id: segRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Repeater {
                                        model: root.methods
                                        Item {
                                            required property var modelData
                                            readonly property bool on: root.method === modelData.key
                                            implicitWidth: segTxt.implicitWidth + 22; implicitHeight: 26
                                            GlassBox {
                                                anchors.fill: parent; radius: th.pill ? height / 2 : Math.max(4, th.ctl(32) - 3)
                                                tint: th.segOn; showBorder: th.isLiquid || th.isAurora
                                                opacity: parent.on ? 1 : 0
                                                Behavior on opacity { NumberAnimation { duration: th.dur(160) } }
                                            }
                                            GText { id: segTxt; anchors.centerIn: parent; text: modelData.label; size: 11.5; color: parent.on ? th.segOnText : th.tv; font.weight: parent.on ? Font.Medium : Font.Normal }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setMethod(modelData.key) }
                                        }
                                    }
                                }
                            }
                        }
                        // Iniciando sesión
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 18
                            Layout.bottomMargin: 8
                            spacing: 12
                            visible: root.phase === "busy"
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 160; implicitHeight: 3; radius: 2
                                color: th.fill2
                                Rectangle {
                                    height: 3; radius: 2; color: th.p
                                    width: 160 * (root.step + 1) / root.steps.length
                                    Behavior on width { NumberAnimation { duration: th.dur(600); easing.type: Easing.OutCubic } }
                                }
                            }
                            GText { Layout.alignment: Qt.AlignHCenter; text: root.steps[root.step] ?? ""; muted: true }
                        }
                    }
                    }

                    // Usuarios (abajo a la izquierda)
                    ColumnLayout {
                        x: 20
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 60
                        spacing: 4
                        layer.enabled: true
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha(th.textShadow, 0.75); shadowBlur: 0.7; shadowVerticalOffset: 1; shadowHorizontalOffset: 0 }
                        opacity: root.sessOpen ? 0 : 1
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: th.dur(160) } }
                        Repeater {
                            model: [...root.users.map((u, i) => ({ i: i, name: u.real, ini: u.ini, tile: "pc" })),
                                    { i: -1, name: "Otro usuario", ini: "+", tile: "s4" }]
                            Item {
                                id: uRow
                                required property var modelData
                                readonly property bool sel: modelData.i < 0 ? root.otherUser : (!root.otherUser && root.userIdx === modelData.i)
                                implicitWidth: uLine.implicitWidth + 16; implicitHeight: 40
                                GlassBox { anchors.fill: parent; radius: th.chipR(height); tint: th.chip; blurSource: blurred; small: true; opacity: uRow.sel ? 1 : 0; visible: opacity > 0; Behavior on opacity { NumberAnimation { duration: th.dur(180) } } }
                                Rectangle { anchors.fill: parent; radius: th.chipR(height); color: th.fill2; visible: !uRow.sel && uMa.containsMouse }
                                RowLayout {
                                    id: uLine
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 4
                                    spacing: 10
                                    Rectangle {
                                        implicitWidth: 32; implicitHeight: 32; radius: 16
                                        color: th.tileColor(uRow.modelData.tile)
                                        GText { anchors.centerIn: parent; text: uRow.modelData.ini; font.weight: Font.Medium; color: th.onTile(uRow.modelData.tile) }
                                    }
                                    GText { text: uRow.modelData.name; font.weight: uRow.sel ? Font.DemiBold : Font.Normal }
                                }
                                MouseArea { id: uMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pickUser(uRow.modelData.i) }
                            }
                        }
                    }

                    // Menú de sesión
                    Item {
                        x: 20
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 56
                        width: 300
                        height: sessCol.implicitHeight + 12
                        opacity: root.sessOpen ? 1 : 0
                        visible: opacity > 0
                        transform: Translate { y: root.sessOpen ? 0 : 8; Behavior on y { NumberAnimation { duration: th.dur(320); easing.type: Easing.OutCubic } } }
                        transformOrigin: Item.BottomLeft
                        scale: root.sessOpen ? 1 : 0.96
                        Behavior on scale { NumberAnimation { duration: th.dur(320); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on opacity { NumberAnimation { duration: th.dur(220); easing.type: Easing.OutCubic } }
                        GlassBox { anchors.fill: parent; radius: th.popRad; tint: th.popup; blurSource: blurred; big: true; aurora: true }
                        MouseArea { anchors.fill: parent }
                        ColumnLayout {
                            id: sessCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                            spacing: 2
                            Repeater {
                                model: root.sessions
                                Item {
                                    id: sRow
                                    required property var modelData
                                    required property int index
                                    readonly property bool sel: root.sessIdx === index
                                    Layout.fillWidth: true
                                    implicitHeight: 46
                                    opacity: modelData.disabled ? 0.55 : 1
                                    Rectangle {
                                        anchors.fill: parent; radius: Math.max(6, th.popRad - 6)
                                        color: sRow.sel ? (th.isFlat ? Qt.alpha(th.sc, 0.9) : th.fill2) : sMa.containsMouse ? th.fill2 : "transparent"
                                    }
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle {
                                            implicitWidth: 28; implicitHeight: 28; radius: th.isFlat ? 14 : th.pill ? 9 : 7
                                            color: th.tileColor(sRow.modelData.tile)
                                            GText { anchors.centerIn: parent; text: sRow.modelData.g; size: 11; font.weight: Font.DemiBold; color: th.onTile(sRow.modelData.tile) }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            GText { text: sRow.modelData.name; font.weight: Font.Medium; Layout.fillWidth: true; elide: Text.ElideRight }
                                            GText { text: sRow.modelData.sub; size: 11; muted: true; Layout.fillWidth: true; elide: Text.ElideRight }
                                        }
                                        GIcon { name: "check"; size: 13; color: th.p; visible: sRow.sel }
                                    }
                                    MouseArea { id: sMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.sessIdx = sRow.index; root.sessOpen = false; root.focusPassword(); } }
                                }
                            }
                        }
                    }

                    // Accesibilidad
                    Item {
                        anchors.right: parent.right; anchors.rightMargin: 20
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 56
                        width: 280
                        height: a11yCol.implicitHeight + 12
                        opacity: root.a11yOpen ? 1 : 0
                        visible: opacity > 0
                        transform: Translate { y: root.a11yOpen ? 0 : 8; Behavior on y { NumberAnimation { duration: th.dur(320); easing.type: Easing.OutCubic } } }
                        transformOrigin: Item.BottomRight
                        scale: root.a11yOpen ? 1 : 0.96
                        Behavior on scale { NumberAnimation { duration: th.dur(320); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on opacity { NumberAnimation { duration: th.dur(220); easing.type: Easing.OutCubic } }
                        GlassBox { anchors.fill: parent; radius: th.popRad; tint: th.popup; blurSource: blurred; big: true; aurora: true }
                        MouseArea { anchors.fill: parent }
                        ColumnLayout {
                            id: a11yCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6; leftMargin: 12; rightMargin: 12 }
                            spacing: 0
                            Repeater {
                                model: [
                                    { label: "Lector de pantalla", on: root.reader, act: () => root.toggleReader(), ok: root.hasOrca || root.preview },
                                    { label: "Teclado en pantalla", on: root.osk, act: () => root.toggleOsk(), ok: root.oskCmd !== "" || root.preview },
                                    { label: "Alto contraste", on: root.highContrast, act: () => root.highContrast = !root.highContrast, ok: true },
                                    { label: "Texto grande", on: root.bigText, act: () => root.bigText = !root.bigText, ok: true }
                                ]
                                Item {
                                    id: aRow
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    opacity: modelData.ok ? 1 : 0.5
                                    GText { anchors.verticalCenter: parent.verticalCenter; text: aRow.modelData.label + (aRow.modelData.ok ? "" : " (no instalado)") }
                                    Rectangle {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 36; height: 22; radius: 11
                                        color: aRow.modelData.on ? th.p : "transparent"
                                        border.width: aRow.modelData.on ? 0 : 1.5; border.color: th.ov
                                        Rectangle {
                                            width: aRow.modelData.on ? 16 : 12; height: width; radius: width / 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: aRow.modelData.on ? parent.width - width - 3 : 5
                                            color: aRow.modelData.on ? th.pText : th.tv
                                            Behavior on x { NumberAnimation { duration: th.dur(160) } }
                                        }
                                    }
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: th.ov; visible: aRow.index < 3; opacity: 0.6 }
                                    MouseArea { anchors.fill: parent; enabled: aRow.modelData.ok; cursorShape: Qt.PointingHandCursor; onClicked: aRow.modelData.act() }
                                }
                            }
                        }
                    }

                    // Barra inferior
                    Item {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                        height: 36
                        // Sesión
                        Item {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: sessBtn.implicitWidth + 24; implicitHeight: 32
                            width: implicitWidth; height: implicitHeight
                            GlassBox { anchors.fill: parent; radius: th.chipR(height); tint: th.chip; blurSource: blurred; small: true }
                            RowLayout {
                                id: sessBtn
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    implicitWidth: 18; implicitHeight: 18; radius: th.isFlat ? 9 : 5
                                    color: th.tileColor(root.session.tile)
                                    GText { anchors.centerIn: parent; text: root.session.g; size: 9.5; font.weight: Font.DemiBold; color: th.onTile(root.session.tile) }
                                }
                                GText { text: root.session.name }
                                GText { text: root.sessOpen ? "▴" : "▾"; muted: true; size: 11 }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.sessOpen = !root.sessOpen; root.a11yOpen = false; } }
                        }
                        // Estado y energía
                        Item {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: statusRow.implicitWidth + 16; implicitHeight: 32
                            width: implicitWidth; height: implicitHeight
                            GlassBox { anchors.fill: parent; radius: th.chipR(height); tint: th.chip; blurSource: blurred; small: true }
                            RowLayout {
                                id: statusRow
                                anchors.verticalCenter: parent.verticalCenter
                                x: 12
                                spacing: 6
                                Item {
                                    implicitWidth: layoutTxt.implicitWidth; implicitHeight: 26
                                    GText { id: layoutTxt; anchors.centerIn: parent; text: root.layout; font.weight: Font.Medium }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextLayout() }
                                }
                                Rectangle { implicitWidth: 1; implicitHeight: 14; color: th.ov; Layout.leftMargin: 4; Layout.rightMargin: 4 }
                                GIcon { name: root.online ? "wifi" : "wifioff"; color: th.tv }
                                GIcon { name: "battery"; color: th.tv; visible: root.hasBattery; Layout.leftMargin: 2 }
                                GText { text: root.batteryPct + " %"; size: 12; muted: true; visible: root.hasBattery; font.features: { "tnum": 1 } }
                                RoundBtn { icon: "a11y"; on: root.a11yOpen; onClicked: { root.a11yOpen = !root.a11yOpen; root.sessOpen = false; } }
                                Rectangle { implicitWidth: 1; implicitHeight: 14; color: th.ov; Layout.leftMargin: 2; Layout.rightMargin: 2 }
                                RoundBtn { icon: "moon"; onClicked: root.power("suspend") }
                                RoundBtn { icon: "restart"; onClicked: root.power("reboot") }
                                RoundBtn { icon: "power"; onClicked: root.power("poweroff") }
                            }
                        }
                    }
                }
            }
            Component.onCompleted: if (primary) ui.forceActiveFocus()
        }
    }
}

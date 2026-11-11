// App de Ajustes de hyprfrijol (design «Ajustes»): ventana flotante (hasta 1280×820, se adapta a la pantalla; F11 maximiza) con barra lateral desplazable y 28 secciones.
// Se abre con la vista "ajustesapp" (Shell.open("ajustesapp", "<sección>")) o por IPC:
//   qs -p <repo>/config/quickshell ipc call settings open teclado
// Buscador de ajustes concretos (search-index.json ← dev/gen-settings-index.py): abre la sección y resalta la fila;
// «sección#Etiqueta» hace lo mismo desde un enlace (ui/LinkRow.qml). Cabecera: restaurar valores por defecto de
// la sección. Barra «¿Se ve bien?» de services/Confirm.qml (ui/ConfirmBar.qml).
// También carga Daemons.qml: luz nocturna, esquinas calientes, ahorro con batería baja y reglas de avisos (la suspensión por inactividad es de hypridle).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import "../.."
import "../../components"
import "../../services"
import "ui"

Scope {
    id: root
    property bool open: false
    property string section: Quickshell.env("HF_SETTINGS_SECTION") || "apariencia"

    readonly property var nav: [
        { key: "apariencia", label: "Apariencia", icon: "palette", file: "Apariencia", sub: "matugen · hf-apply · settings.lua", kw: "tema color estilo math transparencia transparente cristal material vidrio paleta monocromo claro oscuro automático según la hora fondo esquinas redondeo forma squircle espacio gaps escala interfaz tipografía fuente letra tamaño del texto animaciones gtk qt" },
        { key: "animaciones", label: "Animaciones y efectos", icon: "sparkle", file: "Animaciones", sub: "hl.animation · decoration · blur", kw: "animaciones movimiento velocidad preset fluido rápido mínimo rebote espacios deslizar fundido vertical sombras resaltado borde ventana activa atenuar inactivas dim desenfoque blur cristal transparencia batería juegos modo juego gpu efectos rendimiento" },
        { key: "fondos", label: "Fondos de pantalla", icon: "image", file: "Fondos", sub: "hf-wallpaper · mpvpaper · matugen", kw: "fondo wallpaper video animado movimiento escenas cambio automático cada orden al azar según la hora colección transición fps wallhaven buscar descargar fondos internet caché clave api" },
        { key: "barra", label: "Barra", icon: "layout", file: "Barra", sub: "quickshell · bar/", kw: "barra posición arriba abajo izquierda derecha forma fija flotante isla tamaño altura grosor módulos reloj ocultar automáticamente ocultación inteligente esquivar ventanas comportamiento avisos emergentes osd onda audio título transparente" },
        { key: "escritorio", label: "Escritorio y gestos", icon: "grid", file: "Escritorio", sub: "hyprland · general:layout · gestures", kw: "modo de ventanas flotantes flotante mosaico escritorio clásico iconos del escritorio archivos carpeta widgets dock minimizar maximizar ocultación inteligente esquivar ocultar automáticamente numeración japonesa romana arábiga puntos kanji 1 9 esquinas calientes gestos touchpad mosaico dwindle master scrolling desplazamiento columnas cinta ancho de columna enfocar cursor acoplar espacios de trabajo nombres iconos emoji clima ciudad impresora 3d" },
        { key: "enfoque", label: "Enfoque y pomodoro", icon: "focus", file: "Enfoque", sub: "pomodoro + modo foco", kw: "pomodoro foco descanso ciclos sin distracciones ocultar barra gaps silenciar notificaciones sonido bloquear apps" },
        { key: "ia", label: "Asistente de IA", icon: "ai", file: "IA", sub: "servicio local del asistente", kw: "ia asistente claude ollama proveedor modelo servidor api clave permisos portapapeles terminal spotlight historial" },
        { key: "panel", label: "Panel lateral y PiP", icon: "pip", file: "Panel", sub: "window_rule · pin · float", kw: "panel lateral pip imagen en imagen ancho lado esquina margen opacidad vídeos transparente videollamadas meet teams reproductores spotify" },
        { key: "plugins", label: "Plugins", icon: "puzzle", file: "Plugins", sub: "Hyprland (hyprpm) y Omarchy", kw: "plugins hyprpm omarchy hf-plugin widgets temas extensiones módulos hyprexpo hyprspace hyprfocus hyprglass hyprgrass cursores vista de espacios" },
        { key: "omarchy", label: "Plugins de Omarchy", icon: "puzzle", file: "PluginsOmarchy", under: "plugins", sub: "hf-plugin · widgets, paneles y temas de Omarchy", kw: "omarchy plugins quickshell widgets barra panel superposición servicio temas colors.toml importar paleta marketplace probado" },
        { key: "aplicaciones", label: "Aplicaciones", icon: "package", file: "Aplicaciones", sub: "centro de aplicaciones · bienvenida", kw: "aplicaciones apps instalar programas tienda software herramientas catálogo bienvenida asistente inicial flathub aur" },
        { key: "pantallas", label: "Pantallas", icon: "monitor", file: "Pantallas", sub: "hyprctl monitors · hl.monitor", sep: true, kw: "pantalla monitor resolución frecuencia hz escala orientación girar rotar principal identificar disposición vrr hdr duplicar luz nocturna hyprsunset temperatura amanecer atardecer" },
        { key: "teclado", label: "Teclado y atajos", icon: "keyboard", file: "Teclado", sub: "input:kb_layout · hl.bind", kw: "teclado distribución cambiar distribución atajos combinaciones repetición retardo velocidad escritura bloq num mayús escape portapapeles" },
        { key: "raton", label: "Ratón y panel táctil", icon: "sliders", file: "Raton", sub: "input:sensitivity · accel_profile", kw: "ratón mouse touchpad panel táctil velocidad puntero aceleración zurdo botón principal rueda desplazamiento natural clic tocar arrastrar tableta wacom" },
        { key: "red", label: "Red", icon: "wifi", file: "Red", sub: "NetworkManager · nmcli", kw: "red wifi wi-fi vpn cortafuegos dns compartir conexión medida tailscale zerotier malla" },
        { key: "bluetooth", label: "Bluetooth", icon: "bluetooth", file: "Bluetooth", sub: "BlueZ · bluetoothctl", kw: "bluetooth emparejar auriculares ratón teclado dispositivos visible nombre confianza" },
        { key: "remoto", label: "Escritorio remoto", icon: "external", file: "Remoto", sub: "Remmina · FreeRDP · wayvnc", kw: "escritorio remoto rdp vnc remmina freerdp conexiones compartir pantalla acceso" },
        { key: "sonido", label: "Sonido", icon: "volume", file: "Sonido", sub: "PipeWire · WirePlumber", kw: "sonido audio salida entrada micrófono volumen por app aplicaciones altavoces hdmi bluetooth sobreamplificar supresión de ruido auriculares perfiles sonidos del sistema" },
        { key: "notificaciones", label: "Notificaciones", icon: "bell", file: "Notificaciones", sub: "por aplicación", kw: "notificaciones avisos no molestar horario emergentes posición duración sonido pantalla de bloqueo aplicaciones" },
        { key: "impresoras", label: "Impresoras y escáneres", icon: "printer", file: "Impresoras", sub: "CUPS · SANE", kw: "impresora escáner imprimir cola cups" },
        { key: "almacenamiento", label: "Almacenamiento", icon: "folder", file: "Almacenamiento", sub: "udisks2 · hf-devices · hf-download", kw: "almacenamiento discos disco usb memoria pendrive tarjeta sd expulsar montar desmontar automático espacio libre gnome discos particiones descargas descargar yt-dlp gallery-dl aria2 vídeo audio mp3 opus carpetas cola historial" },
        { key: "energia", label: "Energía y rendimiento", icon: "power", file: "Energia", sub: "power-profiles-daemon · hypridle", kw: "energía batería límite de carga 80 historial salud ahorro equilibrado rendimiento atenuar apagar pantalla suspender inactividad gráficos gpu brillo carga vidrio desenfoque juegos tapa botón de encendido hibernar memoria ram paneles carga diferida" },
        { key: "sistema", label: "Sistema y recuperación", icon: "restart", file: "Sistema", sub: "snapper · limine · paru", kw: "sistema snapper puntos de restauración copia de seguridad kernel lts actualizaciones firmware flatpak exportar importar ajustes" },
        { key: "privacidad", label: "Privacidad y seguridad", icon: "shield", file: "Privacidad", sub: "cámara · micrófono · ubicación", kw: "privacidad seguridad cámara micrófono ubicación historial archivos recientes portapapeles papelera bloqueo de pantalla bloquear cifrado tpm arranque seguro" },
        { key: "predeterminadas", label: "Apps predeterminadas e inicio", icon: "sliders", file: "Predeterminadas", sub: "xdg-mime · autostart", kw: "apps predeterminadas navegador correo abrir con inicio automático arranque" },
        { key: "fecha", label: "Fecha, hora e idioma", icon: "clock", file: "Fecha", sub: "timedatectl · localectl", kw: "fecha hora calendario calendarios ics google nextcloud zona horaria 24 horas semana relojes del mundo idioma región formatos ntp localectl locale" },
        { key: "usuarios", label: "Usuarios", icon: "user", file: "Usuarios", sub: "AccountsService · useradd", kw: "usuarios cuenta contraseña avatar administrador" },
        { key: "virtualizacion", label: "Máquinas virtuales", icon: "cpu", file: "Virtualizacion", sub: "Cockpit · libvirt · Boxes", kw: "máquinas virtuales vm cockpit libvirt qemu kvm boxes contenedores podman distrobox" },
        { key: "accesibilidad", label: "Accesibilidad", icon: "accessibility", file: "Accesibilidad", sub: "Orca · AT-SPI · screen_shader", kw: "accesibilidad lector de pantalla orca contraste transparencia movimiento lupa zoom cursor grande filtro daltonismo teclado en pantalla dictado voz subtítulos alertas visuales audio mono" },
        { key: "dictado", label: "Dictado", icon: "mic", file: "Dictado", sub: "local · sin IA", kw: "dictado dictar voz hablar micrófono transcribir transcripción whisper vosk distro órdenes comandos de voz superwhisper reconocimiento de voz escribir con la voz" },
        { key: "acerca", label: "Acerca del sistema", icon: "info", file: "Acerca", sub: "fastfetch · tu perfil de escritorio", kw: "acerca sistema equipo kernel cpu gpu memoria sincronizar perfil exportar perfil" }
    ]
    readonly property var current: nav.find(n => n.key === section) ?? nav[0]

    // ---------- búsqueda de ajustes concretos ----------
    // search-index.json (dev/gen-settings-index.py): filas { f: archivo, l: etiqueta, s: subtítulo, g: tarjeta, t }
    // y keys { archivo: [claves que escribe] } (→ «Restaurar valores por defecto» de la cabecera).
    property var index: ({ rows: [], keys: {} })
    FileView {
        path: Paths.root + "/config/quickshell/modules/settings/search-index.json"
        printErrors: false
        onLoaded: { try { root.index = JSON.parse(text()); } catch (e) {} }
    }
    function norm(s): string { return String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase(); }
    // Filas que contienen las palabras de q (etiqueta, subtítulo, tarjeta o sección); primero las de etiqueta
    function findRows(q): var {
        const words = norm(q).trim().split(/\s+/).filter(w => w);
        if (!words.length) return [];
        const out = [];
        for (const r of index.rows ?? []) {
            const n = nav.find(x => x.file === r.f);
            if (!n) continue;
            const lab = norm(r.l), own = lab + " " + norm(r.s) + " " + norm(r.g), sec = norm(n.label);
            // todas las palabras en la fila o en el nombre de la sección, y al menos una en la propia fila
            if (!words.every(w => own.includes(w) || sec.includes(w)) || !words.some(w => own.includes(w))) continue;
            const score = (lab.startsWith(words[0]) ? 0 : words.every(w => lab.includes(w)) ? 1 : 2) + (r.t === "card" ? 0 : 0.5);
            out.push({ row: r, sec: n, score: score });
        }
        out.sort((a, b) => a.score - b.score);
        return out.slice(0, 40);
    }
    // Claves de la sección que el usuario ha cambiado (presentes en settings.json)
    readonly property var changedKeys: ((index.keys ?? {})[current.file] ?? []).filter(k => k in Settings.user)
    // «Restaurar valores por defecto» de la sección actual: borra sus claves de settings.json (con «¿Se ve bien?»)
    function resetSection(): void {
        if (!changedKeys.length) return;
        Confirm.change("Valores por defecto de " + current.label, {}, { remove: changedKeys });
    }

    // Ir a una fila: abre la sección, desplaza hasta la fila y la resalta (find = { l, g?, t? })
    property var pendingFind: null
    signal findRequested()
    signal searchRequested(string q)
    function goto(sec, find): void {
        pendingFind = typeof find === "string" ? { l: find } : find;
        show(sec);
        findRequested();
    }

    function show(sec): void {
        // "seccion#Etiqueta de la fila" (LinkRow, IPC) → abre la sección y resalta la fila
        if (typeof sec === "string" && sec.includes("#")) {
            const i = sec.indexOf("#");
            pendingFind = { l: sec.slice(i + 1) };
            sec = sec.slice(0, i);
        }
        if (sec && nav.some(n => n.key === sec)) section = sec;
        if (!open && Date.now() - Shell.openedAt > 1000) Shell.stamp();
        open = true;
        if (pendingFind) findRequested();
    }

    Connections {
        target: Shell
        function onOpened(v) {
            if (v !== "ajustesapp") return;
            root.show(typeof Shell.arg === "string" ? Shell.arg : "");
            Shell.close();
        }
    }
    IpcHandler {
        target: "settings"
        function open(section: string): void { root.show(section); }
        function close(): void { root.open = false; }
        function toggle(): void { root.open = !root.open; }
        function section(): string { return root.section; }
        // Pruebas:  … ipc call settings search "escala"  ·  … ipc call settings goto pantallas "Escala"
        function search(q: string): void { root.show(""); root.searchRequested(q); }
        function goto(section: string, label: string): void { root.goto(section, label); }
        function results(q: string): string { return root.findRows(q).map(r => r.row.l + " · " + r.sec.label).join("\n"); }
        // «¿Se ve bien?»:  … confirm "Posición de la barra" barPos '"arriba"'  ·  keep  ·  revert
        function confirm(label: string, key: string, json: string): void { const o = {}; o[key] = JSON.parse(json); Confirm.change(label, o); }
        function keep(): void { Confirm.keep(); }
        function revert(): void { Confirm.revert(); }
        // Exportar / importar sin diálogo (rutas absolutas); el resultado queda en SettingsIO.msg
        function exportTo(path: string): void { SettingsIO.exportFile(path); }
        function importFrom(path: string): void { SettingsIO.importFile(path); }
        function ioMessage(): string { return SettingsIO.msg; }
        function resetSection(): string { const n = root.changedKeys.length; root.resetSection(); return n + " claves"; }
    }

    Daemons {}

    // Ajustes maximizado o no (estado de la ventana, no un ajuste: no pasa por hf-apply)
    property bool startMax: false
    FileView {
        id: maxState
        path: Paths.state + "/settings-maximized"
        printErrors: false
        onLoaded: root.startMax = text().trim() === "1"
    }

    LazyLoader {
        active: root.open
        FloatingWindow {
            id: win
            title: "Ajustes"
            // Cabe en la pantalla con foco (portátiles 1366×768, escalas 1.5–2…): como mucho 1280×820
            readonly property var scr: Shell.screen
            property bool maxed: false
            implicitWidth: Math.min(1280, Math.round((scr?.width ?? 1920) * 0.92))
            implicitHeight: Math.min(820, Math.round((scr?.height ?? 1080) * 0.86))
            minimumSize: Qt.size(Math.min(860, implicitWidth), Math.min(520, implicitHeight))
            visible: true
            // Maximizar / restaurar (botón de la cabecera, F11 o doble clic en el título). Se recuerda.
            function toggleMax() {
                maxed = !maxed;
                Shell.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })');
                root.startMax = maxed;
                maxState.setText(maxed ? "1\n" : "0\n");
            }
            Timer {
                running: root.startMax
                interval: 260
                onTriggered: { win.maxed = true; Shell.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", action = "set" })'); }
            }
            // Con transparencia: ventana translúcida (Hyprland la desenfoca); el resto, sólida
            color: Theme.blur ? Theme.winSolid : Theme.s1
            // Con alfa siempre: una ventana creada opaca (en Material) no puede volverse transparente después
            // (al activar la transparencia se quedaba negra)
            surfaceFormat.opaque: false
            onVisibleChanged: if (!visible) root.open = false

            OpenProbe { name: "ajustesapp"; shown: true }
            Shortcut { sequence: "Ctrl+W"; onActivated: root.open = false }
            Shortcut { sequence: "Ctrl+F"; onActivated: search.focusInput() }
            Shortcut { sequence: "F11"; onActivated: win.toggleMax() }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ---------- barra lateral ----------
                Rectangle {
                    Layout.preferredWidth: 252
                    Layout.fillHeight: true
                    color: Theme.glassy ? Qt.alpha(Theme.bg, 0.12) : Theme.bg
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        anchors.topMargin: 14
                        spacing: 2
                        Field {
                            id: search
                            Layout.fillWidth: true
                            Layout.bottomMargin: 12
                            h: 34
                            radius: Theme.ctl(34)
                            color: Theme.s3
                            icon: ""
                            placeholder: "Buscar ajuste…"
                            // Intro: el resultado elegido (o el primero); si no hay filas, la primera sección
                            onAccepted: {
                                const hit = results.list[results.sel];
                                if (hit) { results.pick(hit); return; }
                                const r = root.nav.filter(n => navList.matches(n));
                                if (r.length) root.section = r[0].key;
                            }
                            onKeyPressed: e => {
                                if (e.key === Qt.Key_Down || e.key === Qt.Key_Up) {
                                    const n = results.list.length;
                                    if (n) results.sel = (results.sel + (e.key === Qt.Key_Down ? 1 : n - 1)) % n;
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Escape && search.text !== "") { search.text = ""; e.accepted = true; }
                            }
                            Connections { target: search.input; function onTextChanged() { results.sel = 0; navFlick.contentY = 0; } }
                            Connections { target: root; function onSearchRequested(q) { search.text = q; search.focusInput(); } }
                        }
                        Flickable {
                            id: navFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: navCol.implicitHeight + 8
                            boundsBehavior: Flickable.StopAtBounds
                            QQC.ScrollBar.vertical: QQC.ScrollBar { policy: navFlick.contentHeight > navFlick.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff }
                            // Lleva a la vista la sección activa (al abrir por IPC/búsqueda en ventanas bajas)
                            function reveal() {
                                const i = root.nav.findIndex(n => n.key === root.section), it = navList.itemAt(i);
                                if (!it || contentHeight <= height) return;
                                const y0 = it.y, y1 = it.y + it.height;
                                if (y0 < contentY) contentY = Math.max(0, y0 - 8);
                                else if (y1 > contentY + height) contentY = Math.min(contentHeight - height, y1 - height + 8);
                            }
                            Connections { target: root; function onSectionChanged() { Qt.callLater(navFlick.reveal); } }
                            Component.onCompleted: Qt.callLater(reveal)
                        ColumnLayout {
                            id: navCol
                            width: navFlick.width - (navFlick.contentHeight > navFlick.height ? 8 : 0)
                            spacing: 2
                        // Resultados: ajustes concretos (fila · sección); al elegir uno se abre y se resalta
                        ColumnLayout {
                            id: results
                            readonly property var list: root.findRows(search.text)
                            property int sel: 0
                            function pick(hit) { root.goto(hit.sec.key, hit.row); }
                            visible: list.length > 0
                            Layout.fillWidth: true
                            Layout.bottomMargin: 8
                            spacing: 1
                            SectionLabel { text: "Ajustes"; Layout.leftMargin: 12; Layout.bottomMargin: 2 }
                            Repeater {
                                model: results.list.slice(0, 12)
                                Rectangle {
                                    id: res
                                    required property var modelData
                                    required property int index
                                    readonly property bool on: results.sel === index
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    radius: Theme.r(5)
                                    color: on ? Theme.selBg : rma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 10
                                        spacing: 0
                                        Item { Layout.fillHeight: true }
                                        Txt { Layout.fillWidth: true; text: res.modelData.row.l; color: res.on ? Theme.selText : Theme.t; weight: Font.Medium }
                                        Txt {
                                            Layout.fillWidth: true
                                            text: res.modelData.sec.label + (res.modelData.row.g ? " › " + res.modelData.row.g : "")
                                            size: 11; color: res.on ? Theme.selText : Theme.tv; opacity: res.on ? 0.8 : 1
                                        }
                                        Item { Layout.fillHeight: true }
                                    }
                                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: results.sel = res.index; onClicked: results.pick(res.modelData) }
                                }
                            }
                            Txt { visible: results.list.length > 12; Layout.leftMargin: 12; text: "+ " + (results.list.length - 12) + " más · afina la búsqueda"; muted: true; size: 11 }
                        }
                        SectionLabel { visible: search.text.trim() !== "" && root.nav.some(n => navList.matches(n)); text: "Secciones"; Layout.leftMargin: 12; Layout.bottomMargin: 2 }
                        Repeater {
                            id: navList
                            function matches(n) {
                                const q = root.norm(search.text).trim();
                                return !q || root.norm(n.label + " " + n.kw).includes(q);
                            }
                            model: root.nav
                            ColumnLayout {
                                id: it
                                required property var modelData
                                readonly property bool on: root.section === modelData.key || root.current.under === modelData.key
                                // las subsecciones (under) no van en la lista: se llega por las pestañas de su sección
                                readonly property bool shown: !modelData.under && navList.matches(modelData)
                                visible: shown
                                Layout.fillWidth: true
                                spacing: 0
                                Rectangle {
                                    visible: !!it.modelData.sep && search.text === ""
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 10; Layout.rightMargin: 10
                                    Layout.topMargin: 6; Layout.bottomMargin: 6
                                    implicitHeight: 1
                                    color: Theme.ov
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    radius: Theme.r(5)
                                    color: it.on ? Theme.selBg : ma.containsMouse ? Qt.alpha(Theme.t, 0.05) : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.durShort; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.ease } }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12
                                        Icon { name: it.modelData.icon; size: 16; stroke: 1.7; color: it.on ? Theme.selText : Theme.tv }
                                        Txt { Layout.fillWidth: true; text: it.modelData.label; color: it.on ? Theme.selText : Theme.t; weight: it.on ? Font.DemiBold : Font.Normal }
                                    }
                                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.section = it.modelData.key }
                                }
                            }
                        }
                        Txt {
                            visible: !root.nav.some(n => navList.matches(n)) && !results.visible
                            Layout.fillWidth: true; Layout.topMargin: 8; Layout.leftMargin: 12
                            text: "Sin resultados"; muted: true
                        }
                        }
                        }
                    }
                }

                // ---------- contenido ----------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 18
                        Layout.leftMargin: 22
                        Layout.rightMargin: 22
                        TapHandler { onDoubleTapped: win.toggleMax() }
                        Txt { text: root.current.label; size: 22; weight: Font.DemiBold; Layout.fillWidth: true }
                        Mono { text: root.current.sub; Layout.alignment: Qt.AlignBottom; bottomPadding: 2 }
                        // Restaurar valores por defecto: quita de settings.json las claves de esta sección
                        // (search-index.json → keys); se puede deshacer con la barra «¿Se ve bien?»
                        IconBtn {
                            visible: ((root.index.keys ?? {})[root.current.file] ?? []).length > 0 && !resetArm.running
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 6
                            implicitWidth: 30; implicitHeight: 26
                            icon: "restart"; iconSize: 15; fg: Theme.tv
                            opacity: root.changedKeys.length ? 1 : 0.45
                            tooltip: root.changedKeys.length ? "Restaurar valores por defecto" : "Esta sección ya usa los valores por defecto"
                            onClicked: if (root.changedKeys.length) { resetConfirm.armed = true; resetArm.restart(); }
                        }
                        ConfirmButton {
                            id: resetConfirm
                            visible: resetArm.running
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 6
                            h: 26
                            text: "Restaurar valores por defecto"
                            confirmText: "¿Restaurar " + root.changedKeys.length + (root.changedKeys.length === 1 ? " ajuste" : " ajustes") + " por defecto? Sí"
                            onConfirmed: { resetArm.stop(); root.resetSection(); }
                        }
                        Timer { id: resetArm; interval: 5000; onTriggered: resetConfirm.armed = false }
                        Connections { target: root; function onSectionChanged() { resetArm.stop(); resetConfirm.armed = false; } }
                        IconBtn {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 6
                            implicitWidth: 30; implicitHeight: 26
                            icon: "maximize"; iconSize: 15; fg: Theme.tv
                            tooltip: win.maxed ? "Restaurar (F11)" : "Maximizar (F11)"
                            onClicked: win.toggleMax()
                        }
                    }
                    Flickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: (page.item ? page.item.implicitHeight : 0) + 18
                        boundsBehavior: Flickable.StopAtBounds
                        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }
                        NumberAnimation { id: scrollAnim; target: flick; property: "contentY"; duration: Theme.dur ? 320 : 0; easing.type: Easing.OutCubic }

                        // ----- ir a una fila (búsqueda, LinkRow, IPC goto) -----
                        function walk(it, pred, out) {
                            if (!it) return;
                            if (pred(it)) out.push(it);
                            const ch = it.children;
                            if (ch) for (let i = 0; i < ch.length; i++) walk(ch[i], pred, out);
                        }
                        // f = { l: etiqueta, g?: título de la tarjeta, t?: row|card|head }
                        function locate(f) {
                            const L = f.l, isCard = it => it.title !== undefined && it.headerRight !== undefined;
                            const match = f.t === "card" ? (it => isCard(it) && it.title === L)
                                : f.t === "head" ? (it => it.text === L && it.label === undefined)
                                : f.t === "row" ? (it => it.label === L || (it.title === L && !isCard(it)))
                                : (it => it.label === L || it.title === L || it.text === L);
                            let scope = page.item;
                            if (f.g) { const s = []; walk(page.item, it => isCard(it) && it.title === f.g, s); scope = s.find(x => x.visible) ?? s[0] ?? page.item; }
                            const c = [];
                            walk(scope, match, c);
                            if (!c.length && scope !== page.item) walk(page.item, match, c);
                            let vis = c.find(x => x.visible && x.height > 0);
                            // encabezado suelto (Txt): resaltar el bloque que encabeza (título + control)
                            if (vis && vis.label === undefined && vis.title === undefined)
                                while (vis.parent && vis.parent !== page.item && (vis.height < 40 || vis.children.length < 2) && vis.parent.headerRight === undefined) vis = vis.parent;
                            if (vis) return vis;
                            // la fila existe pero está oculta (depende de otra opción): su contenedor visible
                            for (let x = c[0]?.parent; x && x !== page.item; x = x.parent) if (x.visible && x.height > 0) return x;
                            return null;
                        }
                        function place(it, animate) {
                            const p = it.mapToItem(flick.contentItem, 0, 0);
                            hl.x = p.x - 8; hl.y = p.y - 5; hl.width = it.width + 16; hl.height = it.height + 10;
                            const want = Math.max(0, Math.min(flick.contentHeight - flick.height, p.y - Math.max(24, (flick.height - it.height) / 3)));
                            if (animate) { scrollAnim.to = want; scrollAnim.restart(); }
                            else if (Math.abs(flick.contentY - want) > 2) flick.contentY = want;
                        }
                        Timer {
                            id: findTimer
                            interval: 140; repeat: true
                            property int tries: 0
                            onTriggered: {
                                const f = root.pendingFind;
                                if (!f || ++tries > 30) { stop(); root.pendingFind = null; return; }
                                if (page.status !== Loader.Ready || !page.item) return;
                                const it = f.l ? flick.locate(f) : null;
                                if (!it) return;
                                stop();
                                root.pendingFind = null;
                                hl.target = it;
                                flick.place(it, true);
                                pulse.restart();
                                settle.restart();
                            }
                        }
                        // las secciones cargan datos al abrirse y la altura cambia: recolocar una vez asentadas
                        Timer { id: settle; interval: 650; onTriggered: if (hl.target && hl.visible) flick.place(hl.target, false) }
                        function startFind() { hl.opacity = 0; hl.target = null; findTimer.tries = 0; findTimer.restart(); }
                        Connections { target: root; function onFindRequested() { flick.startFind(); } }
                        Component.onCompleted: if (root.pendingFind) startFind()
                        // Resaltado: pulso con el color de acento que se desvanece
                        Rectangle {
                            id: hl
                            property var target: null
                            z: 10
                            visible: opacity > 0
                            opacity: 0
                            radius: Theme.r(8)
                            color: Qt.alpha(Theme.p, 0.14)
                            border.width: 2
                            border.color: Qt.alpha(Theme.p, 0.75)
                            SequentialAnimation {
                                id: pulse
                                NumberAnimation { target: hl; property: "opacity"; to: 1; duration: 180 }
                                NumberAnimation { target: hl; property: "opacity"; to: 0.3; duration: 420; easing.type: Easing.InOutQuad }
                                NumberAnimation { target: hl; property: "opacity"; to: 1; duration: 420; easing.type: Easing.InOutQuad }
                                PauseAnimation { duration: 900 }
                                NumberAnimation { target: hl; property: "opacity"; to: 0; duration: 700 }
                            }
                        }
                        Loader {
                            id: page
                            x: 22
                            width: flick.width - 44
                            source: "sections/" + root.current.file + ".qml"
                            onSourceChanged: { scrollAnim.stop(); hl.opacity = 0; pulse.stop(); flick.contentY = 0; }
                            onLoaded: item.width = Qt.binding(() => page.width)
                        }
                    }
                }
            }

            // «¿Se ve bien? Se deshace en N s» (services/Confirm.qml) sobre el contenido
            ConfirmBar {
                z: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                x: 252 + (parent.width - 252 - width) / 2
                width: Math.min(implicitWidth, parent.width - 252 - 44)
            }
        }
    }
}

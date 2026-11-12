// Registro de módulos. Cada módulo es autónomo (normalmente un Overlay que se muestra con su vista).
// Para añadir uno: créalo en modules/<nombre>/ y ponlo aquí.
// Portapapeles y emojis no son módulos propios: son modos de Spotlight («:» y «;», ver Shell.redirects).
// Desarrollo: HF_DEV_MODULES="modules/x/X.qml,…" carga módulos extra sin tocar este archivo (lo usa dev/try.sh).
//
// Carga diferida (ajuste lazyModules, por defecto sí; components/LazyView): las vistas que solo hacen falta abiertas
// se crean al abrirlas y se descargan un rato después de cerrarlas. Lo que tiene que funcionar con la vista cerrada
// (IPC, atajos globales, vigilantes, avisos) va fuera del LazyView: en este archivo, en el módulo o en services/.
// Siempre cargados, y por qué: Lock y Polkit (seguridad, deben responder al instante), Osd y Dictado (reaccionan
// solos), Focus (bloqueo de apps), Pip (detecta vídeos), SidePanel (acopla las web apps; su chat sí es diferido),
// AltTab y Snap (atajos globales que actúan sin abrir nada y deben ser instantáneos), Desktop (dock e iconos),
// OmarchyHost (servicios; sus paneles ya se cargan al abrirlos) y SettingsApp, Tools, Firmar y Tareas (su ventana ya
// era diferida; queda el IPC y Daemons).
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"
import "spotlight"
import "power"
import "lock"
import "focus"
import "polkit"
import "quicksettings"
import "notifications"
import "osd"
import "sidepanel"
import "pip"
import "wallpapers"
import "capture"
import "colorpicker"
import "updates"
import "overview"
import "alttab"
import "snap"
import "desktop"
import "widgets"
import "settings"
import "welcome"
import "tools"
import "cheatsheet"
import "media"
import "dictado"
import "firmar"
import "tareas"
import "omarchy"
import "devices"
import "downloads"

Scope {
    // Alarmas: tienen que sonar aunque nunca se abra su ventana (el singleton se crea al nombrarlo)
    readonly property int alarmsAlive: Alarms.count
    // ── Siempre cargados ──
    Lock {}
    Focus {}
    Polkit {}
    Osd {}
    SidePanel {}
    Pip {}
    AltTab {}
    Snap {}
    Desktop {}
    SettingsApp {}
    Tools {}
    Dictado {}
    Firmar {}
    Tareas {}             // app «Tareas» (su ventana es diferida)
    OmarchyHost {}        // plugins de Omarchy: servicios y vistas (panel/overlay/menu); ver scripts/hf-plugin
    UpdatesCheck {}       // comprobación de actualizaciones en segundo plano (la vista es diferida)

    // ── Diferidos: se crean al abrir su vista ──
    LazyView { id: spotView; views: ["spotlight"]; warm: true; Spotlight {} }   // el más usado: tras la 1.ª vez se queda
    LazyView { views: ["ajustes"]; grace: 120000; warm: true; QuickSettings {} }      // centro de control: ajustes rápidos + notificaciones + agenda (se queda, como Spotlight)
    // Los dos paneles que más se abren, ya listos poco después de entrar (en segundo plano, sin bloquear): la primera
    // apertura con el teclado tardaba ~220 ms en crearlos; precargados, ~50 ms. Con lazyModules = false ya lo están.
    Timer { interval: 6000; running: Shell.lazyModules; onTriggered: { Shell.preload("spotlight"); Shell.preload("ajustes"); } }
    LazyView { views: ["energia"]; Energia {} }
    LazyView { views: ["ventana"]; WinMenu {} }                                     // menú de ventana (⋮ de la barra de título, Alt + Espacio)
    LazyView { views: ["fondos"]; WallpaperSelector {} }
    LazyView { id: capView; views: ["captura"]; keep: item?.busyState ?? false; Capture {} }
    LazyView { id: colorView; views: ["color"]; keep: item?.busyState ?? false; ColorPicker {} }
    LazyView { views: ["actualizaciones"]; Updates {} }
    LazyView { views: ["vista"]; Overview {} }
    LazyView { views: ["widgets", "w-clima", "w-sistema", "w-impresora", "w-pomodoro"]; Widgets {} }
    LazyView { views: ["bienvenida"]; Welcome {} }
    LazyView { views: ["atajos"]; Cheatsheet {} }
    LazyView { views: ["musica"]; MediaControls {} }
    LazyView { views: ["w-dispositivos"]; DevicesPopup {} }   // unidades extraíbles (icono USB de la barra; hf-devices)
    LazyView { views: ["w-descargas"]; DownloadsPopup {} }    // cola de descargas (indicador de la barra, Spotlight «descargar …»; hf-download)

    // Asistente de bienvenida en el primer arranque
    Timer {
        interval: 2500
        running: Settings.loaded && Settings.user.welcomeDone === undefined && Quickshell.env("HF_TRY") !== "1"
        onTriggered: Shell.open("bienvenida")
    }

    // IPC de los módulos diferidos (los crea si hace falta)
    IpcHandler {
        target: "spotlight"
        function state(): string { return spotView.item ? spotView.item.ipcState() : "{}"; }
        function apps(): void { Shell.open("spotlight", "mode:apps"); }
    }
    IpcHandler {
        target: "capture"
        // qs … ipc call capture region 380 200 680 440   (abre la vista con esa zona elegida)
        function region(x: int, y: int, w: int, h: int): void { capView.load()?.ipcRegion(x, y, w, h); }
        // qs … ipc call capture run texto   (copiar | guardar | anotar | editar | fijar | texto | lens | ia | grabar)
        function run(action: string): void { capView.load()?.run(action); }
        function stop(): void { if (capView.item?.recording) capView.item.stopRec(); }
        function shoot(): void { capView.item?.ipcShoot(); }
        function status(): string { return capView.item ? capView.item.ipcStatus() : "off"; }
        function unpinAll(): void { if (capView.item) capView.item.pins = []; }
    }
    IpcHandler {
        target: "color"
        function open(): void { Shell.open("color"); }
        // qs … ipc call color pick X Y   (elige el píxel X,Y de la pantalla congelada; para pruebas)
        function pick(x: int, y: int): void { colorView.item?.ipcPick(x, y); }
        function current(): string { return colorView.item ? colorView.item.ipcCurrent() : ""; }
        function last(): string {
            if (colorView.item) return colorView.item.history[0] ?? "";
            colores.reload();
            try { return (JSON.parse(colores.text() || "{}").history ?? [])[0] ?? ""; } catch (e) { return ""; }
        }
        function state(): string { return colorView.item ? colorView.item.ipcState() : "off"; }
    }
    FileView { id: colores; path: Paths.state + "/colores.json"; preload: false; blockLoading: true; blockAllReads: true; printErrors: false }

    Variants {
        model: (Quickshell.env("HF_DEV_MODULES") ?? "").split(",").filter(s => s.trim() !== "")
        LazyLoader {
            required property string modelData
            active: true
            source: Qt.resolvedUrl("../" + modelData.trim())
        }
    }
}

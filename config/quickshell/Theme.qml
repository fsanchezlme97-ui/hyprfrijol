pragma Singleton
// Tema del shell. Lo calcula scripts/hf-apply (paleta + modo de color + estilo, con los mismos tokens que el diseño)
// y lo deja en ~/.local/state/hyprfrijol/theme.json; aquí solo se lee, y se actualiza en vivo.
//
//  Colores (c.* del diseño):  bg s1 s3 s4 · p pText · pc pcText · sc scText · ter · t tv · o ov
//  Estilo  (S.* del diseño → Theme.st):  glass glassPanel glassPopup fill2 · border borderWidth highlight glow
//                             shadow shadowBig shBlur shY · card cardBorder · barRadius panelRadius winRadius · blur
//           estilo: Math (Material 3), sólido o con transparencia (cristal: transparente y desenfocado)
//                    · tonal (cristal con «Reducir transparencia»). La geometría (radios): Ajustes › Apariencia › Redondeo
//  Estados:    stateTone stHover stPress stDisabled focusRing focusWidth (components/StateLayer.qml)
//  Movimiento: dur durIn durOut · durShort durMedium durLong durXLong · ease easeIn easeOut · durWin easeWin (theme.json motion)
//  Tipografía: font, size(px) — tamaño base 12.5 como en el diseño
//  Nota: en QML los nombres "on" + mayúscula son manejadores, por eso pText (=onP), pcText (=onPc)…
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({})
    // Cristal según el fondo (transparencia + glassWallpaper): hf-apply deja en data.alt la variante del otro modo
    // (c, S, light) y aquí se usa la que casa con la luz del fondo de la pantalla principal en el lado de la barra
    // (Wallpaper.qml → wallLuma), con margen para no cambiar de ida y vuelta: clara por encima de 0,55, oscura por
    // debajo de 0,47. Solo el shell (barra, paneles, dock, Ajustes): las apps siguen el modo elegido (sysLight).
    property real wallLuma: -1
    // Luz del fondo de cada pantalla en la franja de la barra (Wallpaper.qml): { "HDMI-A-2": 0.72, … }
    property var wallLumas: ({})
    // Vidrio esmerilado (con Transparencia), como el de macOS: la barra, el dock, los paneles, las notificaciones, los
    // menús y el OSD usan el mismo (glass, glassPanel, glassPopup): la superficie del tema (lleva su tinte) translúcida,
    // para que Hyprland la desenfoque (su alfa pasa el ignore_alpha 0,2 de la capa). Una sola opacidad para todo y en
    // todas las pantallas: si el fondo de alguna, junto a la barra, es del tono contrario al cristal (cristal oscuro
    // sobre fondo claro o al revés), todo se vuelve más opaco poco a poco, hasta 0,74, y el texto se sigue leyendo.
    readonly property real frostAlpha: {
        const base = light ? _num("glassOpacityLight", 0.56) : _num("glassOpacity", 0.40);
        if (!Settings.get("glassWallpaper", true)) return base;
        let m = 0;
        for (const k in wallLumas) {
            const L = wallLumas[k];
            m = Math.max(m, Math.min(1, light ? (0.6 - L) / 0.2 : (L - 0.4) / 0.2));
        }
        const max = _num("glassMaxOpacity", 0.74);
        return base + Math.max(0, m) * Math.max(0, max - base);
    }
    readonly property color frost: Qt.alpha(s1, frostAlpha)
    readonly property bool sysLight: data.light ?? false
    readonly property bool followsWall: Settings.get("glassWallpaper", true) && !!data.alt && wallLuma >= 0
    readonly property var cur: followsWall && wallLight !== sysLight ? data.alt : data
    readonly property var c: cur.c ?? fallback.c
    readonly property var st: cur.S ?? fallback.st

    readonly property bool light: cur.light ?? false
    readonly property string paletteName: data.paletteName ?? "Grafito"
    readonly property bool reduceMotion: data.reduceMotion ?? false
    readonly property bool highContrast: data.highContrast ?? false     // Ajustes › Accesibilidad (hf-apply ya ajusta c y S)

    // Colores
    property color bg: c.bg
    property color s1: c.s1
    property color s3: c.s3
    property color s4: c.s4
    property color p: c.p
    property color pText: c.onP
    property color pc: c.pc
    property color pcText: c.onPc
    property color sc: c.sc
    property color scText: c.onSc
    property color ter: c.ter
    property color t: c.t
    property color tv: c.tv
    property color o: c.o
    property color ov: c.ov
    readonly property color danger: light ? "#B3261E" : "#F2B8B5"
    // Estados del asistente en el puntero (la onda de la barra usa primario y terciario): verde, azul y magenta del
    // tema (sus colores de terminal, c.ansi, que hf-apply pone siempre); los fijos solo si faltan
    readonly property var ansi: c.ansi ?? []
    readonly property color aiListen: ansi[2] ?? (light ? "#15803D" : "#22C55E")
    readonly property color aiThink: ansi[4] ?? (light ? "#1D4ED8" : "#3B82F6")
    readonly property color aiSpeak: ansi[5] ?? (light ? "#6D28D9" : "#8B5CF6")

    // Estilo
    property color glass: glassy ? frost : st.bg
    property color glassPanel: glassy ? frost : st.bgPanel
    property color glassPopup: glassy ? frost : st.bgPopup
    property color fill2: st.bg2
    property color border: st.border
    readonly property int borderWidth: st.borderWidth
    property color highlight: st.highlight
    readonly property color glow: st.glow
    readonly property color shadow: st.shadow
    readonly property color shadowBig: st.shadowBig
    property color win: st.win
    // Ventanas grandes (Ajustes, Centro de aplicaciones): con transparencia más opaco que los paneles, para que no se transparente
    // lo de detrás; en Material/tonal, sólido. (hf-apply: S.winSolid; ajustable con winOpacity)
    readonly property color winSolid: st.winSolid ?? (glassy ? Qt.alpha(win, _num("winOpacity", 0.94)) : s1)
    readonly property int barRadius: st.barRad
    readonly property int panelRadius: st.panelRad
    readonly property int winRadius: st.winRad
    readonly property bool blur: st.blur
    // Controles (botones, campos, segmentos): radio, o píldora completa si el estilo lo pide (st.pill)
    readonly property int ctlRadius: st.ctlRad ?? 7
    readonly property bool pill: st.pill ?? false
    function ctl(h: real): real { return pill ? h / 2 : Math.min(ctlRadius, h / 2); }
    // Radios fijos de los módulos (los del diseño) escalados según el estilo y el redondeo elegido
    readonly property real roundK: st.roundK ?? 1
    function r(n: real): real { return Math.round(n * roundK); }
    // Radios concéntricos (Math): lo que va dentro de otra superficie redondeada, a `pad` px de su borde, lleva el
    // radio de fuera menos ese margen (y nunca menos de r(4)), para que las curvas vayan paralelas
    function inner(outer: real, pad: real): real { return Math.max(r(4), Math.round(outer - pad)); }
    // Lee un ajuste numérico con default; protege contra NaN/undefined cuando Settings aún no está listo.
    function _num(k, d): real { const v = Settings.get(k, d); return Number.isFinite(v) ? v : d; }
    // Multiplica el alfa de un color (para sliders sheenOpacity/rimOpacity); transparente si no hay color.
    function _mulAlpha(c, f): color {
        const factor = parseFloat(f) || 0;
        if (!c || c.a <= 0 || factor <= 0) return "transparent";
        return Qt.alpha(c, Math.min(1, c.a * factor));
    }
    // Cristal (transparencia): filo interior de luz (arriba → abajo), filo exterior, esmerilado y resplandor.
    // sheenOpacity y rimOpacity de Ajustes › Apariencia permiten apagar o atenuar estos detalles.
    readonly property color rimTop: _mulAlpha(st.rimTop ?? "transparent", _num("rimOpacity", 1.0))
    readonly property color rimBottom: _mulAlpha(st.rimBottom ?? "transparent", _num("rimOpacity", 1.0))
    // Filo plano (Ajustes › Apariencia › «Filo del cristal»): sin la luz de arriba, el borde es un contorno
    // uniforme en todo el contorno (Glass.qml)
    readonly property bool flatRim: st.flatRim ?? true
    readonly property color sheen: _mulAlpha(st.sheen ?? "transparent", _num("sheenOpacity", 1.0))
    readonly property color tint: st.tint ?? "transparent"
    readonly property color tint2: st.tint2 ?? "transparent"
    readonly property color tint3: st.tint3 ?? "transparent"
    readonly property color edge: _mulAlpha(st.edge ?? "transparent", _num("rimOpacity", 1.0))   // cristal: filo exterior oscuro casi invisible
    // glassy: estilo Math con transparencia (S.material «cristal»). theme.json de antes de 0.9.0: el estilo SkySoul
    readonly property bool glassy: st.material ? st.material === "cristal" : ["skysoul", "aurora", "liquid"].includes(st.estilo)
    // Marca deslizante de los segmentos (y su texto): el contenedor primario (Material)
    readonly property color segThumb: pc
    readonly property color segText: pcText
    // Selección en listas: el contenedor secundario; con cristal, una capa de cristal más clara
    readonly property color selBg: glassy ? Qt.alpha("#FFFFFF", light ? 0.7 : 0.13) : sc
    readonly property color selText: glassy ? t : scText
    // Tarjetas (secciones de Ajustes): con cristal, cristal con borde; si no, c.s3
    readonly property color card: st.card ?? (glassy ? fill2 : s3)
    readonly property int cardBorder: st.cardBorder ?? (glassy ? 1 : 0)
    // Estados de los controles (Math, como Material 3): una capa del color del texto encima del control, con la misma
    // opacidad en todos (components/StateLayer.qml); el foco del teclado (Tab) se ve como un anillo del acento, y
    // lo deshabilitado baja a stDisabled.
    readonly property color stateTone: light ? "#000000" : "#FFFFFF"
    readonly property real stHover: 0.07
    readonly property real stPress: 0.12
    readonly property real stDisabled: 0.4
    readonly property color focusRing: p
    readonly property int focusWidth: 2
    // Lo activo (mosaicos, deslizadores): el color de acento
    readonly property color fillOn: p
    readonly property color fillOnText: pText
    // Sombras de los paneles (Glass): radio y desplazamiento del material y de Ajustes › Apariencia › Sombras
    readonly property real shBlur: st.shBlur ?? 14
    readonly property real shY: st.shY ?? 3
    readonly property real shBigBlur: st.shBigBlur ?? 52
    readonly property real shBigY: st.shBigY ?? 18
    readonly property real shSpread: st.shSpread ?? -2

    // Tipografía y movimiento
    readonly property string font: data.font ?? "Inter"
    readonly property string mono: "JetBrains Mono"
    readonly property real scale: data.fontScale ?? 1.0
    function px(n: real): real { return Math.round(n * scale * 2) / 2; }
    // Escala tipográfica (components/Txt.qml): leyenda · secundario · cuerpo · cuerpo grande · subtítulo · títulos
    readonly property var typeScale: [9.5, 10.5, 11.5, 12.5, 14, 16, 18, 20, 24, 28, 32, 40, 48, 56, 72, 96]
    function typeStep(n: real): real {
        let best = typeScale[0];
        for (const v of typeScale) if (Math.abs(v - n) <= Math.abs(best - n)) best = v;   // <=: empate hacia arriba
        return best;
    }
    // Movimiento (Ajustes › Apariencia › Movimiento → hf-apply → theme.json motion): duraciones y curvas del
    // preajuste (Fluido · Equilibrado · Rápido · Mínimo · Ninguna) ya divididas por la velocidad elegida.
    // «Reducir movimiento» o animaciones apagadas → 0.
    readonly property var motion: data.motion ?? ({})
    readonly property string motionPreset: motion.preset ?? "fluido"
    readonly property bool still: reduceMotion || motionPreset === "ninguno"
    readonly property int dur: still ? 0 : (motion.dur ?? 260)            // transiciones de estado
    readonly property int durIn: still ? 0 : (motion.durIn ?? 420)        // aparición de paneles
    readonly property int durOut: still ? 0 : (motion.durOut ?? 180)      // cierre de paneles
    // Tokens de movimiento de Math (como Material 3): salen del preset y la velocidad, como dur/durIn/durOut.
    //   durShort   hover, cambios de color, interruptores      (Equilibrado ≈ 130 ms)
    //   durMedium  chips, menús, tooltips                       (≈ 220 ms)
    //   durLong    paneles, popups, deslizamientos               (≈ 360 ms)
    //   durXLong   transiciones de pantalla completa, overview   (≈ 500 ms)
    readonly property int durShort: Math.round(dur * 0.5)
    readonly property int durMedium: Math.round(dur * 0.85)
    readonly property int durLong: Math.round(durIn * 0.85)
    readonly property int durXLong: Math.round(durIn * 1.2)
    // Duración fija que sigue a un dato o al tiempo real (nivel del micro, progreso, cuenta atrás): sigue la
    // velocidad elegida y se anula con «Reducir movimiento», pero no el preset. Lo demás usa los tokens.
    function ms(n: real): int { return still ? 0 : Math.round(n / (motion.speed || 1)); }
    // Curvas: «ease» desacelera al entrar; «easeIn» es la de aparición (con un leve rebote en Fluido);
    // «easeOut» acelera al salir
    readonly property var ease: motion.ease ?? [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var easeOut: motion.easeOut ?? [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var easeIn: motion.easeIn ?? ease
    // El movimiento de las ventanas en Hyprland (windowsMove del preset): para seguir a una ventana mientras se anima
    readonly property int durWin: still ? 0 : (motion.winMove ?? durLong)
    readonly property var easeWin: motion.winEase ?? ease

    function alpha(col, a) { return Qt.alpha(col, a); }

    // Cambio de tema, de paleta o de claro a oscuro: los colores pasan con un fundido (todo el shell a la vez) en vez de
    // saltar. No al arrancar (de los colores de reserva al tema) ni con «Reducir movimiento».
    property bool fades: false
    readonly property int fadeDur: still || !fades ? 0 : Math.round(durIn * 0.9)
    Behavior on bg { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on s1 { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on s3 { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on s4 { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on p { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on pText { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on pc { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on pcText { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on sc { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on scText { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on ter { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on t { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on tv { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on o { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on ov { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on glass { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on glassPanel { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on glassPopup { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on fill2 { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on border { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on highlight { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Behavior on win { enabled: root.fadeDur > 0; ColorAnimation { duration: root.fadeDur; easing.type: Easing.InOutQuad } }
    Timer { id: fadeOn; interval: 600; onTriggered: root.fades = true }

    FileView {
        path: Paths.state + "/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} if (!root.fades) fadeOn.start(); }
    }

    // Grafito con transparencia, por si theme.json aún no existe
    QtObject {
        id: fallback
        readonly property var c: ({ bg: "#121314", s1: "#1A1C1E", s3: "#25272A", s4: "#2F3235", p: "#A9C1D9", onP: "#0E2A40",
            pc: "#2C3E50", onPc: "#D5E3F0", sc: "#353A40", onSc: "#E1E4E8", ter: "#C9B79C", t: "#E4E6E8", tv: "#AEB4BA",
            o: "#8A9097", ov: "#383C41" })
        readonly property var st: ({ estilo: "math", material: "cristal", blur: true, bg: "#571A1C1E", bgPanel: "#701A1C1E", bgPopup: "#851A1C1E",
            bg2: "#17E4E6E8", border: "#1FFFFFFF", borderWidth: 1, highlight: "#2EFFFFFF", glow: "#09FFFFFF",
            shadow: "#29000000", shadowBig: "#42000000", win: "#8F1A1C1E", barRad: 7, panelRad: 10, winRad: 8,
            ctlRad: 6, pill: false, roundK: 1.0, rimTop: "#6BFFFFFF", rimBottom: "#0FFFFFFF", sheen: "#12FFFFFF" })
    }
}

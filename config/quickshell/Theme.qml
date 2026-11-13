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
//  Movimiento: dur durIn durOut · durShort durMedium durLong durXLong · ease easeIn easeOut (theme.json motion)
//  Tipografía: font, size(px) — tamaño base 12.5 como en el diseño
//  Nota: en QML los nombres "on" + mayúscula son manejadores, por eso pText (=onP), pcText (=onPc)…
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({})
    readonly property var c: data.c ?? fallback.c
    readonly property var st: data.S ?? fallback.st

    readonly property bool light: data.light ?? false
    readonly property string paletteName: data.paletteName ?? "Grafito"
    readonly property bool reduceMotion: data.reduceMotion ?? false
    readonly property bool highContrast: data.highContrast ?? false     // Ajustes › Accesibilidad (hf-apply ya ajusta c y S)

    // Colores
    readonly property color bg: c.bg
    readonly property color s1: c.s1
    readonly property color s3: c.s3
    readonly property color s4: c.s4
    readonly property color p: c.p
    readonly property color pText: c.onP
    readonly property color pc: c.pc
    readonly property color pcText: c.onPc
    readonly property color sc: c.sc
    readonly property color scText: c.onSc
    readonly property color ter: c.ter
    readonly property color t: c.t
    readonly property color tv: c.tv
    readonly property color o: c.o
    readonly property color ov: c.ov
    readonly property color danger: light ? "#B3261E" : "#F2B8B5"

    // Estilo
    readonly property color glass: st.bg
    readonly property color glassPanel: st.bgPanel
    readonly property color glassPopup: st.bgPopup
    readonly property color fill2: st.bg2
    readonly property color border: st.border
    readonly property int borderWidth: st.borderWidth
    readonly property color highlight: st.highlight
    readonly property color glow: st.glow
    readonly property color shadow: st.shadow
    readonly property color shadowBig: st.shadowBig
    readonly property color win: st.win
    // Ventanas grandes (Ajustes, Centro de aplicaciones): con transparencia más opaco que los paneles, para que no se transparente
    // lo de detrás; en Material/tonal, sólido. (hf-apply: S.winSolid)
    readonly property color winSolid: st.winSolid ?? (glassy ? Qt.alpha(st.win, 0.94) : c.s1)
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
    // Cristal (transparencia): filo interior de luz (arriba → abajo), filo exterior, esmerilado y resplandor
    readonly property color rimTop: st.rimTop ?? "transparent"
    readonly property color rimBottom: st.rimBottom ?? "transparent"
    readonly property color sheen: st.sheen ?? "transparent"
    readonly property color tint: st.tint ?? "transparent"
    readonly property color tint2: st.tint2 ?? "transparent"
    readonly property color tint3: st.tint3 ?? "transparent"
    readonly property color edge: st.edge ?? "transparent"           // cristal: filo exterior oscuro casi invisible
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

    function alpha(col, a) { return Qt.alpha(col, a); }

    FileView {
        path: Paths.state + "/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
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

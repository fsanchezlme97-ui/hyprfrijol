.pragma library
// Nombre legible de una tecla de hl.bind («SUPER» → «Super», «APOSTROPHE» → «'»); solo para enseñar, no para guardar
const names = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Mayús", RETURN: "Enter", SPACE: "Espacio", PRINT: "Impr", TAB: "Tab",
                ESCAPE: "Esc", APOSTROPHE: "'", SEMICOLON: ";", COMMA: ",", PERIOD: ".", MINUS: "-", EQUAL: "=", SLASH: "/",
                BACKSLASH: "\\", GRAVE: "º", BRACKETLEFT: "`", BRACKETRIGHT: "+" };
function label(k) { return names[String(k).toUpperCase()] ?? k; }

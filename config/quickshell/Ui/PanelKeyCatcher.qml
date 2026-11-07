// Compatibilidad con Omarchy · qs.Ui.PanelKeyCatcher: teclado de un panel (flechas/hjkl, Intro, Espacio, Esc,
// Tab, Supr/x) convertido en señales. Mismas teclas que en Omarchy.
import QtQuick

Item {
    id: root
    property bool blocked: false
    property bool reorderable: false
    property bool reorderableSideways: false
    signal moveRequested(int dx, int dy)
    signal reorderRequested(int dy)
    signal reorderSidewaysRequested(int dx)
    signal activateRequested()
    signal returnRequested()
    signal closeRequested()
    signal deleteRequested()
    signal tabRequested(int direction)
    signal textKey(string text, int modifiers)
    focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: event => {
        if (blocked) return;
        const k = event.key, t = event.text, ctrl = event.modifiers & Qt.ControlModifier;
        const done = () => { event.accepted = true; };
        if (k === Qt.Key_Escape) { closeRequested(); return done(); }
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab) { tabRequested((event.modifiers & Qt.ShiftModifier) || k === Qt.Key_Backtab ? -1 : 1); return done(); }
        if (reorderable && ctrl && (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Down || k === Qt.Key_J)) { reorderRequested(k === Qt.Key_Down || k === Qt.Key_J ? 1 : -1); return done(); }
        if (reorderableSideways && ctrl && (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Right || k === Qt.Key_L)) { reorderSidewaysRequested(k === Qt.Key_Right || k === Qt.Key_L ? 1 : -1); return done(); }
        if (k === Qt.Key_Down || t === "j") { moveRequested(0, 1); return done(); }
        if (k === Qt.Key_Up || t === "k") { moveRequested(0, -1); return done(); }
        if (k === Qt.Key_Right || t === "l") { moveRequested(1, 0); return done(); }
        if (k === Qt.Key_Left || t === "h") { moveRequested(-1, 0); return done(); }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) { returnRequested(); activateRequested(); return done(); }
        if (k === Qt.Key_Space) { activateRequested(); return done(); }
        if (k === Qt.Key_Delete || t === "x" || t === "X") { deleteRequested(); return done(); }
        if (t && t.length === 1) textKey(t, event.modifiers);
    }
}

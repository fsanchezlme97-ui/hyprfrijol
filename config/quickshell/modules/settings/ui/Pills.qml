// Antes era una fila de pastillas sueltas con la elegida en el color de acento; ahora es el mismo control
// segmentado que Seg, para que Ajustes tenga un solo selector (misma API: model, current, h, fill, picked).
//   Pills { model: [0, 6, 10]; current: 6; onPicked: v => … }   (o [["k","Etiqueta"],…])
import QtQuick

Seg {
    tabular: true
}

// Gato bongo dibujado con trazos lisos (Canvas 2D). Las líneas siguen el centro de los dibujos del Bongo Cat de
// VS Code (kitgore/BongoCat, MIT · assets/bongocat): su fuente se ve ondulada a tamaño de icono, así que aquí se
// calcan como curvas suaves (Catmull-Rom) en unidades de la fuente (y hacia arriba) y se escalan a píxeles.
//   draw(ctx, s, ox, oy, left, right, asleep, ink, lineWidth)
//   s = píxeles por unidad · (ox, oy) = esquina superior izquierda · left/right = esa pata golpeando
.pragma library

// Trazos que no cambian: orejas, lomo y lado derecho
const TOP = [[600, 750], [690, 812], [792, 930], [912, 856], [960, 818], [1280, 790], [1476, 712], [1628, 826], [1646, 670], [1632, 520], [1700, 470], [1840, 262]];
// Cara
const EYE_L = [640, 484], EYE_R = [1190, 420];
const MOUTH = [[790, 452], [834, 404], [882, 458], [930, 404], [978, 430]];
// Mitad izquierda: pata arriba (bulto con la pata levantada) o golpeando (la cabeza baja hasta la mesa)
const LEFT_UP = {
    lines: [
        [[600, 750], [500, 650], [430, 548], [458, 466]],                                   // mejilla hasta la pata
        [[458, 466], [400, 540], [300, 562], [222, 520], [200, 420], [226, 300], [270, 248]], // pata levantada
        [[270, 248], [700, 244], [1024, 238]]                                               // mesa / barriga
    ],
    sparks: []
};
const LEFT_DOWN = {
    lines: [
        [[600, 750], [440, 620], [300, 430], [222, 262], [262, 150], [420, 180], [604, 262], [700, 266], [1024, 262]]
    ],
    sparks: [[[52, 80], [118, 132]], [[214, 22], [232, 50]], [[410, 30], [420, -6]]]
};
// Mitad derecha: pata arriba (arco) o golpeando (la barriga baja y salen chispas)
const RIGHT_UP = {
    lines: [
        [[1024, 238], [1400, 232], [1840, 262]],
        [[1316, 270], [1286, 430], [1356, 548], [1450, 524], [1522, 448]]
    ],
    sparks: []
};
const RIGHT_DOWN = {
    lines: [
        [[1024, 262], [1196, 262], [1214, 166], [1300, 120], [1440, 160], [1560, 246], [1840, 262]],
        [[1256, 302], [1204, 230]]
    ],
    sparks: [[[1084, 30], [1130, 58]], [[1250, 10], [1258, -30]], [[1416, 40], [1462, 2]]]
};

function curve(c, pts, X, Y) {
    c.beginPath();
    c.moveTo(X(pts[0][0]), Y(pts[0][1]));
    if (pts.length === 2) { c.lineTo(X(pts[1][0]), Y(pts[1][1])); c.stroke(); return; }
    for (let i = 0; i < pts.length - 1; i++) {
        const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)];
        c.bezierCurveTo(X(p1[0] + (p2[0] - p0[0]) / 6), Y(p1[1] + (p2[1] - p0[1]) / 6),
                        X(p2[0] - (p3[0] - p1[0]) / 6), Y(p2[1] - (p3[1] - p1[1]) / 6),
                        X(p2[0]), Y(p2[1]));
    }
    c.stroke();
}

function draw(c, s, ox, oy, left, right, asleep, ink, lw) {
    const X = x => ox + x * s, Y = y => oy + (940 - y) * s;
    c.lineCap = "round"; c.lineJoin = "round";
    c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = lw;
    curve(c, TOP, X, Y);
    const L = left ? LEFT_DOWN : LEFT_UP, R = right ? RIGHT_DOWN : RIGHT_UP;
    for (const part of [L, R]) {
        for (const l of part.lines) curve(c, l, X, Y);
        for (const sp of part.sparks) curve(c, sp, X, Y);
    }
    // ojos (cerrados al dormir) y boca «ω»
    const er = Math.max(lw * 0.95, 52 * s);
    for (const e of [EYE_L, EYE_R]) {
        c.beginPath();
        if (asleep) { c.moveTo(X(e[0] - 60), Y(e[1])); c.lineTo(X(e[0] + 60), Y(e[1])); c.stroke(); }
        else { c.arc(X(e[0]), Y(e[1]), er, 0, Math.PI * 2); c.fill(); }
    }
    c.lineWidth = lw * 0.85;
    curve(c, MOUTH, X, Y);
}

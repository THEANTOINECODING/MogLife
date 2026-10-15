"""
Équipement de musculation (stations d'exercice, salle de quartier, garages, futures zones).
À exécuter dans Blender après props_lib.py :  build_gym(Props(pal, "Props_Gym"))
"""


def plate(center, radius, thick, axis="X", col="charcoal", hole="steel"):
    x, y, z = center
    off = {"X": (thick / 2, 0, 0), "Y": (0, thick / 2, 0)}[axis]
    base = (x - off[0], y - off[1], z)
    return [
        (cylinder(base, radius, thick, 12, axis=axis, bevel=min(0.08, thick * 0.3)), col),
        (cylinder((base[0] - 0.01 if axis == "X" else base[0], base[1] - 0.01 if axis == "Y" else base[1], z),
                  radius * 0.25, thick + 0.02, 8, axis=axis), hole),
    ]


def barbell_parts(z, length=9.0, plate_r=1.4, plates=2, y=0.0, col="charcoal"):
    parts = [(cylinder((-length / 2, y, z), 0.12, length, 8, axis="X"), "chrome")]
    for s in (-1, 1):
        parts.append((cylinder((s * (length / 2 - 1.6) - (0.12 if s > 0 else 0), y, z), 0.2, 0.12, 8, axis="X"),
                      "chrome"))
        for k in range(plates):
            r = plate_r * (1 - k * 0.18)
            cx = s * (length / 2 - 1.35 + k * 0.32)
            parts += plate((cx, y, z), r, 0.28, "X", col)
        parts.append((cylinder((s * (length / 2 - 0.55) - 0.12, y, z), 0.22, 0.24, 8, axis="X"), "steel"))
    return parts


def dumbbell(P):
    parts = [(cylinder((-0.7, 0, 0.55), 0.13, 1.4, 8, axis="X"), "chrome")]
    for s in (-1, 1):
        for k, (r, w) in enumerate(((0.55, 0.3), (0.45, 0.22))):
            x = s * (0.55 + k * 0.28)
            parts.append((cylinder((x - w / 2, 0, 0.55), r, w, 8, axis="X", bevel=0.04), "charcoal"))
    P.prop("Dumbbell", parts)


def watermelon_dumbbell(P):
    """L'haltère du curl de MOG LIFE : une barre et deux pastèques."""
    parts = [(cylinder((-1.9, 0, 0.95), 0.15, 3.8, 8, axis="X"), "chrome")]
    for s in (-1, 1):
        parts.append((sphere((s * 2.1, 0, 0.95), (1.1, 0.9, 0.9), 10, 7), "melonskin"))
        parts.append((cylinder((s * 1.05 - (0.12 if s > 0 else 0), 0, 0.95), 0.3, 0.12, 8, axis="X"), "steel"))
    P.prop("WatermelonDumbbell", parts)


def dumbbell_rack(P):
    parts = []
    for x in (-3.4, 3.4):
        parts.append((extrude([(-1.0, 0), (1.0, 0), (0.7, 3.2), (-0.2, 3.2)], 0.3, y0=-0.15, axis="X"), "darkgrey"))
        parts[-1] = (move(parts[-1][0], (x, 0, 0)), "darkgrey")
    for k, z in enumerate((1.0, 2.2)):
        tray = box((0, -0.2 + k * 0.5, z), (7.2, 1.0, 0.12))
        parts.append((rotate(tray, -12, "X", (0, 0, z)), "steel"))
    colors = ["red", "blue", "yellow", "green", "charcoal"]
    for row, z in enumerate((1.35, 2.55)):
        for k in range(5):
            x = -2.6 + k * 1.3
            y = -0.25 + row * 0.5
            parts.append((cylinder((x - 0.45, y, z), 0.09, 0.9, 6, axis="X"), "chrome"))
            for s in (-1, 1):
                parts.append((cylinder((x + s * 0.38 - 0.1, y, z), 0.3 - row * 0.05, 0.2, 8, axis="X"),
                              colors[(k + row) % 5]))
    P.prop("DumbbellRack", parts)


def barbell(P):
    P.prop("Barbell", barbell_parts(1.45))


def plate_stack(P):
    parts = [(cylinder((0, 0, 0), 0.25, 3.0, 6), "chrome"), (cylinder((0, 0, 0), 1.0, 0.12, 8), "darkgrey")]
    z = 0.12
    for k, (r, c) in enumerate(((1.5, "charcoal"), (1.5, "red"), (1.3, "blue"), (1.1, "yellow"), (0.9, "green"))):
        parts.append((cylinder((0, 0, z), r, 0.3, 12, bevel=0.05), c))
        z += 0.32
    P.prop("PlateStack", parts)


def bench_press(P):
    parts = [
        (box((0, 0.5, 1.75), (1.6, 5.0, 0.45), bevel=0.12), "fabricred"),
        (box((0, 0.5, 1.4), (1.0, 4.4, 0.25)), "charcoal"),
    ]
    for y in (-1.6, 2.6):
        parts.append((box((0, y, 0.7), (0.35, 0.35, 1.4)), "charcoal"))
        parts.append((box((0, y, 0.12), (2.2, 0.5, 0.24)), "charcoal"))
    # Montants avec crochets
    for x in (-1.5, 1.5):
        parts.append((box((x, -2.3, 2.3), (0.3, 0.3, 4.6)), "darkgrey"))
        parts.append((box((x, -2.55, 3.7), (0.3, 0.5, 0.2)), "darkgrey"))
        parts.append((box((x, -2.3, 0.15), (0.5, 1.6, 0.3)), "darkgrey"))
    # La barre est un décor à part (Barbell, posé sur les crochets par la carte) : elle bouge pendant la série
    P.prop("BenchPress", parts)


def squat_rack(P):
    parts = []
    for x in (-2.4, 2.4):
        for y in (-1.6, 1.6):
            parts.append((box((x, y, 4.0), (0.35, 0.35, 8.0)), "red"))
        parts.append((box((x, 0, 0.15), (0.5, 4.0, 0.3)), "darkgrey"))
        parts.append((box((x, 0, 7.9), (0.35, 3.6, 0.3)), "red"))
        for z in (1.8, 3.4, 4.6):
            parts.append((box((x, -1.85, z), (0.35, 0.3, 0.12)), "steel"))
    parts.append((box((0, -1.6, 7.9), (5.2, 0.35, 0.3)), "red"))
    parts.append((box((0, 1.6, 7.9), (5.2, 0.35, 0.3)), "red"))
    parts.append((cylinder((-2.6, -1.6, 7.6), 0.1, 5.2, 8, axis="X"), "chrome"))
    # La barre est un décor à part (Barbell, posé sur les crochets par la carte) : elle bouge pendant la série
    P.prop("SquatRack", parts)


def pullup_bar(P):
    parts = []
    for x in (-2.2, 2.2):
        parts.append((segment((x, -1.2, 0), (x, 0, 8.0), 0.18, 6), "darkgrey"))
        parts.append((segment((x, 1.2, 0), (x, 0, 8.0), 0.18, 6), "darkgrey"))
        parts.append((box((x, 0, 0.1), (0.5, 3.0, 0.2)), "charcoal"))
    parts.append((cylinder((-2.6, 0, 7.9), 0.12, 5.2, 8, axis="X"), "chrome"))
    for x in (-1.2, 1.2):
        parts.append((cylinder((x - 0.4, 0, 7.9), 0.17, 0.8, 8, axis="X"), "black"))
    P.prop("PullUpBar", parts)


def kettlebell(P):
    parts = [
        (sphere((0, 0, 0.8), (0.85, 0.85, 0.8), 10, 6), "charcoal"),
        (cylinder((0, 0, 0), 0.55, 0.15, 10), "charcoal"),
        (torus((0, 0, 1.75), 0.48, 0.13, 10, 5, axis="Y"), "charcoal"),
    ]
    P.prop("Kettlebell", parts)


def medicine_ball(P):
    parts = [(sphere((0, 0, 0.9), 0.9, 10, 7), "red"), (torus((0, 0, 0.9), 0.9, 0.06, 12, 4), "black"),
             (torus((0, 0, 0.9), 0.9, 0.06, 12, 4, axis="X"), "black")]
    P.prop("MedicineBall", parts)


def punching_bag(P):
    parts = [
        (box((0, 0, 0.15), (3.0, 3.0, 0.3)), "darkgrey"),
        (box((1.2, 0, 4.5), (0.35, 0.35, 9.0)), "darkgrey"),
        (box((0.2, 0, 8.9), (2.4, 0.35, 0.3)), "darkgrey"),
        (segment((-0.6, 0, 8.8), (-0.6, 0, 7.4), 0.05, 4), "steel"),
        (cylinder((-0.6, 0, 2.2), 0.95, 5.0, 10, bevel=0.15), "fabricred"),
        (cylinder((-0.6, 0, 6.8), 0.7, 0.4, 10), "black"),
        (torus((-0.6, 0, 3.3), 0.96, 0.05, 10, 4), "black"),
    ]
    P.prop("PunchingBag", parts)


def treadmill(P):
    parts = [
        (box((0, 0.6, 0.45), (2.6, 6.0, 0.6), bevel=0.1), "charcoal"),
        (box((0, 0.6, 0.78), (2.0, 5.6, 0.06)), "rubber"),
    ]
    for x in (-1.1, 1.1):
        parts.append((segment((x, -2.0, 0.6), (x, -2.4, 4.2), 0.12, 6), "darkgrey"))
        parts.append((segment((x, -2.4, 3.6), (x, -1.0, 3.6), 0.1, 6), "steel"))
    parts.append((box((0, -2.5, 4.4), (2.6, 0.8, 1.2), bevel=0.1), "charcoal"))
    parts.append((box((0, -2.75, 4.5), (1.6, 0.1, 0.7)), "screentex"))
    P.prop("Treadmill", parts)


def exercise_bike(P):
    parts = [
        (box((0, 0, 0.15), (2.4, 4.4, 0.3)), "charcoal"),
        (segment((0, 1.2, 0.3), (0, 0.6, 2.8), 0.15, 6), "darkgrey"),
        (segment((0, -1.0, 0.3), (0, -1.4, 3.8), 0.15, 6), "darkgrey"),
        (box((0, 0.6, 3.0), (1.0, 1.4, 0.35), bevel=0.1), "black"),
        (cylinder((-0.2, -0.8, 1.4), 1.0, 0.4, 12, axis="X"), "red"),
        (segment((-0.9, -1.5, 3.9), (0.9, -1.5, 3.9), 0.1, 6), "chrome"),
        (box((0, -1.55, 3.6), (0.7, 0.3, 0.5)), "screentex"),
    ]
    for s in (-1, 1):
        parts.append((box((s * 0.55, -0.4, 1.4), (0.15, 0.9, 0.15)), "steel"))
    P.prop("ExerciseBike", parts)


def yoga_mat(P):
    parts = [(cylinder((-1.4, 0, 0.45), 0.45, 2.8, 10, axis="X"), "purple"),
             (cylinder((-1.42, 0, 0.45), 0.2, 2.84, 8, axis="X"), "magenta")]
    P.prop("YogaMatRolled", parts)


def pushup_mat(P):
    """Le tapis rapiécé des pompes, avec un coussin pour le visage (humour)."""
    parts = [
        (box((0, 0, 0.08), (3.0, 6.0, 0.16), bevel=0.05), "blue"),
        (box((0.6, 1.4, 0.18), (1.0, 1.2, 0.06)), "red"),
        (box((-0.7, -1.6, 0.18), (0.9, 0.8, 0.06)), "yellow"),
        (box((0, -2.4, 0.4), (1.6, 0.9, 0.5), bevel=0.2), "pink"),
    ]
    P.prop("PushUpMat", parts)


def jump_rope(P):
    parts = []
    for x in (-1.6, 1.6):
        parts.append((cylinder((x, 0, 0.25), 0.22, 1.4, 8, axis="Y"), "red"))
    pts = [(-1.6, 1.4, 0.25), (-1.0, 2.4, 0.1), (0, 2.8, 0.1), (1.0, 2.4, 0.1), (1.6, 1.4, 0.25)]
    for a, b in zip(pts, pts[1:]):
        parts.append((segment(a, b, 0.07, 5), "black"))
    P.prop("JumpRope", parts)


def protein_shaker(P):
    parts = [
        (cylinder((0, 0, 0), 0.55, 1.6, 10, radius_top=0.62), "hotpink"),
        (cylinder((0, 0, 1.6), 0.64, 0.3, 10), "charcoal"),
        (cylinder((0, 0, 1.9), 0.18, 0.4, 6, radius_top=0.12), "charcoal"),
        (torus((0, 0, 0.9), 0.6, 0.05, 10, 4), "white"),
    ]
    P.prop("ProteinShaker", parts)


def protein_tub(P):
    parts = [
        (cylinder((0, 0, 0), 1.1, 2.4, 12, bevel=0.06), "black"),
        (cylinder((0, 0, 2.4), 1.15, 0.4, 12), "red"),
        (box((0, -1.08, 1.2), (1.2, 0.08, 1.2)), "gold"),
        (box((0, -1.12, 1.2), (0.7, 0.06, 0.7)), "white"),
    ]
    P.prop("ProteinTub", parts)


def water_cooler(P):
    parts = [
        (box((0, 0, 1.6), (1.6, 1.5, 3.2), bevel=0.08), "white"),
        (cylinder((0, 0, 3.2), 0.75, 1.9, 10, radius_top=0.7), "water_tex"),
        (sphere((0, 0, 5.1), (0.7, 0.7, 0.35), 10, 4), "water_tex"),
        (box((-0.35, -0.8, 2.2), (0.3, 0.2, 0.3)), "blue"),
        (box((0.35, -0.8, 2.2), (0.3, 0.2, 0.3)), "red"),
        (box((0, -0.65, 1.6), (1.0, 0.35, 0.1)), "steel"),
    ]
    P.prop("WaterCooler", parts)


def lockers(P):
    parts = []
    for k in range(4):
        x = -2.7 + k * 1.8
        parts.append((box((x, 0, 3.5), (1.7, 1.6, 7.0)), "blue" if k % 2 == 0 else "navy"))
        for z in (5.6, 5.9, 6.2):
            parts.append((box((x, -0.82, z), (1.1, 0.06, 0.12)), "darkgrey"))
        parts.append((box((x + 0.55, -0.83, 3.6), (0.12, 0.08, 0.6)), "chrome"))
    parts.append((box((0, 0, 7.1), (7.4, 1.7, 0.2)), "darkgrey"))
    parts.append((box((0, -1.6, 1.0), (7.0, 1.2, 0.2)), "woodlight"))
    for x in (-3.0, 3.0):
        parts.append((box((x, -1.6, 0.45), (0.2, 1.0, 0.9)), "darkgrey"))
    P.prop("Lockers", parts)


def weighing_scale(P):
    parts = [
        (box((0, 0, 0.15), (2.2, 2.2, 0.3), bevel=0.06), "white"),
        (box((0, 0.7, 2.5), (0.3, 0.3, 4.4)), "steel"),
        (cylinder((0, 0.55, 4.8), 0.75, 0.25, 12, axis="Y"), "white"),
        (cylinder((0, 0.5, 4.8), 0.6, 0.05, 12, axis="Y"), "paper"),
        (box((0, 0.46, 5.0), (0.06, 0.04, 0.5)), "red"),
    ]
    P.prop("WeighingScale", parts)


def giant_tire(P):
    parts = [(torus((0, 0, 1.0), 2.6, 1.0, 16, 6), "rubber"), (cylinder((0, 0, 0.6), 1.7, 0.8, 12), "darkgrey")]
    P.prop("GiantTire", parts)


def trophy(P):
    parts = [
        (box((0, 0, 0.5), (2.4, 2.4, 1.0), bevel=0.06), "marbleblack"),
        (cylinder((0, 0, 1.0), 0.5, 0.4, 8, radius_top=0.3), "gold"),
        (cylinder((0, 0, 1.4), 0.2, 1.2, 8), "gold"),
        (cylinder((0, 0, 2.6), 0.4, 1.8, 10, radius_top=1.2), "gold"),
        (torus((0, 0, 4.4), 1.2, 0.12, 10, 4), "darkgold"),
    ]
    for s in (-1, 1):
        parts.append((torus((s * 1.25, 0, 3.4), 0.5, 0.12, 8, 4, axis="Y"), "gold"))
    # L'haltère doré au sommet
    parts.append((cylinder((-0.8, 0, 4.9), 0.12, 1.6, 8, axis="X"), "gold"))
    for s in (-1, 1):
        parts.append((cylinder((s * 0.8 - 0.2, 0, 4.9), 0.5, 0.4, 10, axis="X", bevel=0.05), "gold"))
    P.prop("GoldTrophy", parts)


def build_gym(P):
    for fn in (dumbbell, watermelon_dumbbell, dumbbell_rack, barbell, plate_stack, bench_press, squat_rack,
               pullup_bar, kettlebell, medicine_ball, punching_bag, treadmill, exercise_bike, yoga_mat, pushup_mat,
               jump_rope, protein_shaker, protein_tub, water_cooler, lockers, weighing_scale, giant_tire, trophy):
        fn(P)

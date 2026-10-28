"""
Contrôle des collisions du Colisée du Pump (D89) : compare, point par point, le sol que l'on voit (calculé avec les
mêmes cotes que les modèles Blender, LAYOUT du manifeste) et le sol sur lequel on marche (blocs invisibles générés
dans world/Map/Town/Colosseum.model.json). Signale les trous (on tomberait sous le stade) et les bosses.

Usage :  py -3 tools/check_colosseum.py
"""
import json, math, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
man = json.load(open(os.path.join(ROOT, "assets", "export", "props", "colosseum_manifest.json"), encoding="utf-8"))
L = man["layout"]
tree = json.load(open(os.path.join(ROOT, "world", "Map", "Town", "Colosseum.model.json"), encoding="utf-8"))

CENTER = (-330.0, -330.0)
YAW = -135.0
TOP = 0.1 + L["podium"]


def boxes():
    """Blocs de collision : (centre, axes, demi-tailles) pour les pièces pleines (pas les cylindres)."""
    out, cylinders = [], []
    for node in tree["children"]:
        props = node.get("properties", {})
        if node.get("className") not in ("Part", "WedgePart") or not props.get("CanCollide", True):
            continue
        cf = props["CFrame"]["CFrame"]
        pos, rotm = cf["position"], cf["orientation"]
        size = props["Size"]
        if props.get("Shape") == "Cylinder":
            # cylindre debout (axe X tourné vers Y) : rayon = Size.Y / 2, hauteur = Size.X
            cylinders.append((pos, size[1] / 2, size[0]))
            continue
        out.append((pos, rotm, [s / 2 for s in size]))
    return out, cylinders


BOXES, CYLS = boxes()


def ground_at(x, z, below):
    """Hauteur du plus haut dessus de collision sous `below` au point (x, z)."""
    best = -1e9
    for pos, r, half in BOXES:
        d = [x - pos[0], 0, z - pos[2]]
        # coordonnées locales : rotm a les axes en lignes (orientation) -> local = R^T * d
        lx = r[0][0] * d[0] + r[1][0] * d[1] + r[2][0] * d[2]
        lz = r[0][2] * d[0] + r[1][2] * d[1] + r[2][2] * d[2]
        if abs(lx) <= half[0] and abs(lz) <= half[2]:
            top = pos[1] + half[1]
            if top <= below and top > best:
                best = top
    for pos, radius, height in CYLS:
        if math.hypot(x - pos[0], z - pos[2]) <= radius:
            top = pos[1] + height / 2
            if top <= below and top > best:
                best = top
    return best


def expected(r, along_deg, lateral, k):
    """Sol visible (repère : z au-dessus du podium) au rayon r, dans le secteur k ; lateral = écart au milieu du secteur."""
    if r < L["pit_radius"]:
        return 0.0
    if r < L["wall_outer"]:
        return L["wall_height"] + 0.8  # chaperon du mur
    if r < L["walk_outer"]:
        return L["walk_top"]
    # Grand escalier d'entrée
    if k == 0 and abs(lateral) < L["entrance_width"] / 2:
        steps = 14
        depth = (L["facade_outer"] - L["walk_outer"]) / steps
        # marches droites (pas en arc) : on mesure la profondeur sur l'axe de l'escalier
        n = min(int((L["facade_outer"] - r * math.cos(math.radians(along_deg))) / depth), steps - 1)
        return L["walk_top"] * (n + 1) / steps
    if r >= L["stand_outer"]:
        return None  # façade
    if k == 0 and abs(lateral) < L["entrance_width"] / 2 + 1.9:
        return None  # murs d'échiffre de l'escalier (pleins, plus hauts que tout)
    i = int((r - L["walk_outer"]) / L["tier_depth"])
    if k == L["tribune"] and i < 5 and abs(lateral) < 7.0:
        return L["walk_top"]  # renfoncement sous la tribune
    if k != 0 and abs(lateral) < L["aisle_width"] / 2 and not (k == L["tribune"] and i < 5):
        frac = (r - L["walk_outer"]) / L["tier_depth"] - i
        return L["walk_top"] + L["tier_rise"] * (i + (1 if frac >= 0.5 else 0.5))
    return L["walk_top"] + L["tier_rise"] * (i + 1)


problems = []
checked = 0
for k in range(12):
    yaw = YAW + L["sector"] * k
    for r10 in range(int(L["pit_radius"] * 10) + 5, int(L["stand_outer"] * 10), 7):
        r = r10 / 10
        for a10 in range(-145, 146, 6):
            a = a10 / 10
            lateral = r * math.sin(math.radians(a))
            # bords d'une marche ou d'une rangée : on évite les 0,15 stud autour d'une arête
            frac = ((r - L["walk_outer"]) / (L["tier_depth"] / 2)) % 1
            if r > L["walk_outer"] and (frac < 0.07 or frac > 0.93):
                continue
            near_step = k == 0 and abs(lateral) < L["entrance_width"] / 2 and (
                ((L["facade_outer"] - r) / ((L["facade_outer"] - L["walk_outer"]) / 14)) % 1 < 0.05)
            if near_step or abs(abs(lateral) - L["aisle_width"] / 2) < 0.2 or abs(abs(lateral) - 7.0) < 0.2:
                continue
            exp = expected(r, a, lateral, k)
            if exp is None:
                continue
            ang = math.radians(yaw + a)
            # direction du secteur : -Z local tourné de yaw (convention de build_map : Ry)
            dx, dz = -math.sin(ang), -math.cos(ang)
            x, z = CENTER[0] + dx * r, CENTER[1] + dz * r
            got = ground_at(x, z, TOP + exp + 0.6) - TOP
            checked += 1
            if got < exp - 0.6:
                problems.append((k, round(r, 1), round(a, 1), round(exp, 2), round(got, 2), "TROU"))
            elif got > exp + 0.6:
                problems.append((k, round(r, 1), round(a, 1), round(exp, 2), round(got, 2), "BOSSE"))

print(f"{checked} points vérifiés, {len(problems)} problèmes")
seen = set()
for p in problems:
    key = (p[0], int(p[1] // 2), int(p[2] // 3), p[5])
    if key not in seen:
        seen.add(key)
        print(f"secteur {p[0]:2d} r={p[1]:5.1f} angle={p[2]:5.1f} attendu={p[3]:6.2f} collision={p[4]:6.2f} {p[5]}")

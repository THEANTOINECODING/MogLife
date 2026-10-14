"""
Générateur de la carte de MUSCLE CITY (structure en blocs Roblox, versionnée dans Git via Rojo).

Écrit :
- world/Map/*.model.json  : garage, rue, maisons, salle de quartier, place des boss
- repositionne les emplacements de jeu existants (stations, boss, habitants, miroir) dans ce décor.

Usage :  py -3 tools/build_map.py   (puis Rojo synchronise tout seul)
Convention Roblox : Y vers le haut ; yaw 0 = regarde vers -Z, yaw 180 = regarde vers +Z,
yaw 90 = regarde vers -X, yaw -90 = regarde vers +X. Le sol (Baseplate) est à y = 0.
Les personnages regardent dans la direction de leur dalle (LookVector).
"""
import json, math, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WORLD = os.path.join(ROOT, "world")


# ------------------------------------------------------------------ outils
def rot(yaw=0.0, roll=0.0):
    """Matrice de rotation (lignes) : Ry(yaw) * Rz(roll), angles en degrés."""
    y, r = math.radians(yaw), math.radians(roll)
    cy, sy, cr, sr = math.cos(y), math.sin(y), math.cos(r), math.sin(r)
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]
    m = [[sum(ry[i][k] * rz[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return [[round(v, 6) for v in row] for row in m]


def rgb(r, g, b):
    return {"Color3uint8": [r, g, b]}


def part(name, pos, size, color, material="SmoothPlastic", yaw=0, roll=0, cls="Part", shape=None,
         collide=True, transparency=0, children=None, extra=None):
    props = {
        "Anchored": True,
        "Size": [round(s, 3) for s in size],
        "CFrame": {"CFrame": {"position": [round(p, 3) for p in pos], "orientation": rot(yaw, roll)}},
        "Color": rgb(*color),
        "Material": material,
        "CanCollide": collide,
    }
    if transparency:
        props["Transparency"] = transparency
    if shape:
        props["Shape"] = shape
    if extra:
        props.update(extra)
    node = {"name": name, "className": cls, "properties": props}
    if children:
        node["children"] = children
    return node


def wedge(name, pos, size, color, material="SmoothPlastic", yaw=0):
    return part(name, pos, size, color, material, yaw=yaw, cls="WedgePart")


def light(color=(255, 230, 190), brightness=1.5, range_=26):
    return {"name": "Light", "className": "PointLight",
            "properties": {"Brightness": brightness, "Range": range_,
                           "Color": {"Color3": [round(v / 255, 4) for v in color]}}}


def model(name, children):
    return {"className": "Model", "children": children}


def write(path, node):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(node, f, indent=1, ensure_ascii=False)
        f.write("\n")


# ------------------------------------------------------------------ palette (design/05_ART_SON.md)
CONCRETE = (128, 126, 122)
CONCRETE_LIGHT = (196, 194, 188)
TIN = (150, 170, 182)
TIN_DARK = (84, 94, 104)
WOOD = (130, 92, 60)
CARDBOARD = (176, 136, 90)
ASPHALT = (52, 52, 58)
GRASS = (108, 160, 84)
BRICK = (150, 72, 60)
GYM_FLOOR = (58, 58, 64)
PASTELS = [(238, 178, 190), (168, 222, 198), (244, 228, 160), (200, 186, 228), (248, 200, 160), (170, 204, 234),
           (240, 210, 230)]

ROAD_Z = 54          # axe de la rue
NEAR_WALK_Z = 40     # trottoir côté garage
FAR_WALK_Z = 68      # trottoir côté maisons
X0, X1 = -60, 260    # étendue de la rue


# ------------------------------------------------------------------ 1. le garage de maman (départ)
def garage():
    c = []
    c.append(part("Floor", (0, 0.1, 0), (60, 0.2, 40), CONCRETE, "Concrete"))
    c.append(part("OilStain", (6, 0.21, 6), (0.02, 4, 4), (82, 78, 72), "SmoothPlastic", roll=90, cls="Part",
                  shape="Cylinder", collide=False))
    c.append(part("WallBack", (0, 8, -20.5), (61, 16, 1), TIN, "Metal"))
    c.append(part("WallLeft", (-30.5, 8, 0), (1, 16, 42), TIN, "Metal"))
    c.append(part("WallRight", (30.5, 8, 0), (1, 16, 42), TIN, "Metal"))
    c.append(part("WallFrontL", (-21.5, 8, 20.5), (17, 16, 1), TIN, "Metal"))
    c.append(part("WallFrontR", (21.5, 8, 20.5), (17, 16, 1), TIN, "Metal"))
    c.append(part("Lintel", (0, 14, 20.5), (26, 4, 1), TIN_DARK, "CorrodedMetal"))
    c.append(part("RolledDoor", (0, 13, 19.4), (26, 2, 1.8), (170, 172, 168), "Metal"))
    c.append(part("Roof", (0, 16.5, 0), (63, 1, 43), TIN_DARK, "CorrodedMetal"))
    for i, x in enumerate((-15, 0, 15)):
        c.append(part(f"CeilingLamp{i}", (x, 15.6, -2), (6, 0.4, 1), (255, 244, 214), "Neon",
                      children=[light()]))
    # Coin de Kevin : canapé défoncé et vieille télé
    c.append(part("CouchSeat", (16, 1.2, -13), (11, 2.4, 4.5), (122, 82, 62), "Fabric"))
    c.append(part("CouchBack", (16, 3.4, -15), (11, 2.6, 1), (112, 74, 56), "Fabric"))
    c.append(part("CouchArmL", (10.3, 2.4, -13), (1, 2.2, 4.5), (112, 74, 56), "Fabric"))
    c.append(part("CouchArmR", (21.7, 2.4, -13), (1, 2.2, 4.5), (112, 74, 56), "Fabric"))
    c.append(part("PizzaBox", (13, 2.5, -12.6), (2.6, 0.3, 2.6), CARDBOARD, "Cardboard", yaw=20))
    c.append(part("TvStand", (28, 1, -4), (2, 2, 6), WOOD, "WoodPlanks"))
    c.append(part("Tv", (28, 3.6, -4), (1.6, 3.2, 5), (30, 30, 34), "SmoothPlastic"))
    c.append(part("TvScreen", (27.18, 3.6, -4), (0.05, 2.6, 4.4), (90, 140, 200), "Neon", collide=False))
    # Coin bricolage : établi, étagères, cartons, frigo de maman, machine à laver
    c.append(part("Workbench", (-27.5, 1.9, -8), (4, 3.8, 12), WOOD, "WoodPlanks"))
    c.append(part("Shelf", (-29.4, 7, -8), (1.2, 0.4, 12), WOOD, "WoodPlanks"))
    for i, (x, y, z, s) in enumerate([(-25, 1.2, 15, 2.4), (-22, 1.0, 16.5, 2.0), (-25, 3.4, 15.2, 2.0),
                                      (24, 1.3, 14, 2.6), (26.5, 1.0, 16, 2.0), (27, 7.6, -8, 1.6)]):
        c.append(part(f"Box{i}", (x, y, z), (s, s, s), CARDBOARD, "Cardboard", yaw=i * 17))
    c.append(part("Fridge", (-27, 3.6, 4), (4, 7.2, 4), (232, 230, 220), "SmoothPlastic"))
    c.append(part("WashingMachine", (-27, 1.8, 9.5), (3.6, 3.6, 3.6), (220, 220, 225), "SmoothPlastic"))
    # Allée et pelouse devant le garage
    c.append(part("Lawn", (0, 0.05, 28.5), (60, 0.1, 15), GRASS, "Grass"))
    c.append(part("Driveway", (0, 0.12, 28.5), (24, 0.1, 15), (150, 148, 142), "Concrete"))
    c.append(part("MailboxPost", (-14, 2, 34), (0.4, 4, 0.4), WOOD, "WoodPlanks"))
    c.append(part("Mailbox", (-14, 4.3, 34), (1.2, 1.2, 2), (40, 90, 160), "Metal"))
    return model("MomsGarage", c)


# ------------------------------------------------------------------ 2. la rue
def street():
    c = []
    length = X1 - X0
    mid = (X0 + X1) / 2
    c.append(part("Road", (mid, 0.08, ROAD_Z), (length, 0.16, 20), ASPHALT, "Asphalt"))
    for i, x in enumerate(range(X0 + 6, X1 - 4, 12)):
        c.append(part(f"Dash{i}", (x, 0.17, ROAD_Z), (6, 0.02, 0.6), (235, 230, 200), "SmoothPlastic", collide=False))
    c.append(part("SidewalkNear", (mid, 0.25, NEAR_WALK_Z), (length, 0.5, 8), CONCRETE_LIGHT, "Concrete"))
    c.append(part("SidewalkFar", (mid, 0.25, FAR_WALK_Z), (length, 0.5, 8), CONCRETE_LIGHT, "Concrete"))
    c.append(part("YardsFar", (mid, 0.05, 92), (length, 0.1, 40), GRASS, "Grass"))
    for i, x in enumerate(range(X0 + 10, X1, 30)):
        c.append(part(f"LampPost{i}", (x, 6, NEAR_WALK_Z - 3), (0.5, 12, 0.5), (60, 60, 66), "Metal"))
        c.append(part(f"LampHead{i}", (x, 12.2, NEAR_WALK_Z - 2), (1.4, 0.6, 2.4), (255, 236, 190), "Neon",
                      children=[light((255, 220, 170), 1.2, 30)]))
    # Voiture du voisin (aide « pousser la voiture »), garée au bord de la route
    car_x, car_z = 40, ROAD_Z + 6
    c.append(part("CarBody", (car_x, 1.9, car_z), (11, 2.2, 5), (200, 60, 50), "SmoothPlastic"))
    c.append(part("CarCabin", (car_x - 0.5, 3.9, car_z), (6, 1.8, 4.6), (180, 52, 44), "SmoothPlastic"))
    c.append(part("CarWindows", (car_x - 0.5, 3.9, car_z), (6.1, 1.4, 4.7), (120, 170, 210), "Glass",
                  transparency=0.3, collide=False))
    for i, (dx, dz) in enumerate([(-3.6, -2.4), (3.6, -2.4), (-3.6, 2.4), (3.6, 2.4)]):
        c.append(part(f"Wheel{i}", (car_x + dx, 1, car_z + dz), (1, 2, 2), (25, 25, 28), "SmoothPlastic",
                      yaw=90, shape="Cylinder"))
    return model("Street", c)


# ------------------------------------------------------------------ 3. les maisons pastel (côté habitants)
HOUSE_XS = [0, 40, 70, 100, 150, 185, 215]


def houses():
    c = []
    depth, width, height = 16, 22, 13
    hz = FAR_WALK_Z + 4 + 10 + depth / 2      # derrière le trottoir et un jardinet
    for i, x in enumerate(HOUSE_XS):
        col = PASTELS[i % len(PASTELS)]
        front = hz - depth / 2
        c.append(part(f"House{i}", (x, height / 2, hz), (width, height, depth), col, "SmoothPlastic"))
        c.append(wedge(f"Roof{i}Front", (x, height + 2.5, hz - depth / 4), (width + 1, 5, depth / 2 + 0.5), (150, 70, 60)))
        c.append(wedge(f"Roof{i}Back", (x, height + 2.5, hz + depth / 4), (width + 1, 5, depth / 2 + 0.5), (150, 70, 60),
                       yaw=180))
        c.append(part(f"Door{i}", (x, 3.5, front - 0.1), (4, 7, 0.2), (110, 70, 50), "WoodPlanks", collide=False))
        for j, dx in enumerate((-7, 7)):
            c.append(part(f"Window{i}_{j}", (x + dx, 7.5, front - 0.1), (4.5, 3.5, 0.2), (150, 195, 225), "Glass",
                          collide=False))
        c.append(part(f"Path{i}", (x, 0.12, front - 5), (4, 0.1, 10), (170, 168, 160), "Concrete"))
    # Cabane dans l'arbre du petit voisin
    c.append(part("TreeTrunk", (80, 7, 80), (14, 2.6, 2.6), (110, 78, 50), "Wood", roll=90, shape="Cylinder"))
    c.append(part("TreeCanopy", (80, 16, 80), (13, 13, 13), (80, 140, 60), "Grass", shape="Ball"))
    c.append(part("Treehouse", (80, 11, 80), (6, 4.5, 6), WOOD, "WoodPlanks"))
    # Piano de Mme Do-Ré, sorti dans le jardin
    c.append(part("Piano", (106, 2.2, 76), (5, 4.4, 2.4), (20, 20, 22), "SmoothPlastic"))
    c.append(part("PianoKeys", (106, 3, 74.7), (4.6, 0.3, 0.6), (240, 240, 235), "SmoothPlastic"))
    # Épicerie : auvent rayé et cagettes de fruits
    for k in range(5):
        c.append(part(f"Awning{k}", (150 - 8 + k * 4, 10, hz - depth / 2 - 2), (4, 0.4, 4),
                      (210, 50, 50) if k % 2 == 0 else (245, 245, 240), "Fabric"))
    for k, colr in enumerate([(220, 60, 50), (250, 200, 60), (120, 180, 60)]):
        c.append(part(f"Crate{k}", (144 + k * 4, 1, 76), (3, 2, 2.5), WOOD, "WoodPlanks"))
        c.append(part(f"Fruit{k}", (144 + k * 4, 2.3, 76), (2.4, 0.8, 2), colr, "SmoothPlastic"))
    # Piscine et chaise du maître-nageur
    c.append(part("PoolRim", (185, 0.4, 76), (18, 0.6, 9), (230, 230, 225), "Concrete"))
    c.append(part("PoolWater", (185, 0.75, 76), (16, 0.2, 7), (70, 170, 230), "Glass", transparency=0.25, collide=False))
    c.append(part("LifeguardChair", (196, 4, 80), (2.4, 8, 2.4), (245, 245, 245), "WoodPlanks"))
    c.append(part("Suitcase", (219, 1.4, 74), (2.6, 2.6, 1.2), (60, 120, 170), "SmoothPlastic"))
    return model("Houses", c)


# ------------------------------------------------------------------ 4. la salle de quartier
GYM = dict(x0=108, x1=172, z0=-30, z1=30)


def gym():
    c = []
    x0, x1, z0, z1 = GYM["x0"], GYM["x1"], GYM["z0"], GYM["z1"]
    cx, cz, w, d, h = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, 18
    c.append(part("Floor", (cx, 0.1, cz), (w, 0.2, d), GYM_FLOOR, "SmoothPlastic"))
    c.append(part("WallBack", (cx, h / 2, z0 - 0.5), (w + 1, h, 1), BRICK, "Brick"))
    c.append(part("WallLeft", (x0 - 0.5, h / 2, cz), (1, h, d + 2), BRICK, "Brick"))
    c.append(part("WallRight", (x1 + 0.5, h / 2, cz), (1, h, d + 2), BRICK, "Brick"))
    door = 16
    side = (w - door) / 2
    c.append(part("WallFrontL", (x0 + side / 2, h / 2, z1 + 0.5), (side, h, 1), BRICK, "Brick"))
    c.append(part("WallFrontR", (x1 - side / 2, h / 2, z1 + 0.5), (side, h, 1), BRICK, "Brick"))
    c.append(part("Lintel", (cx, h - 3, z1 + 0.5), (door, 6, 1), BRICK, "Brick"))
    for j, wx in enumerate((x0 + side / 2, x1 - side / 2)):
        c.append(part(f"Window{j}", (wx, 9, z1 + 1.05), (side - 6, 6, 0.2), (150, 195, 225), "Glass", collide=False))
    c.append(part("Roof", (cx, h + 0.5, cz), (w + 3, 1, d + 3), (90, 50, 44), "Slate"))
    for i, x in enumerate((x0 + 14, cx, x1 - 14)):
        c.append(part(f"CeilingLamp{i}", (x, h - 0.6, cz), (8, 0.4, 1.2), (255, 244, 214), "Neon", children=[light()]))
    # Haltère géant sur le toit : repère visible de loin
    c.append(part("SignBar", (cx, h + 5, z1 - 4), (24, 1.2, 1.2), (180, 180, 186), "Metal", shape="Cylinder"))
    for j, dx in enumerate((-12, 12)):
        c.append(part(f"SignPlate{j}", (cx + dx, h + 5, z1 - 4), (2, 8, 8), (40, 40, 44), "Metal", shape="Cylinder"))
    # Estrade de Coach Turbo
    c.append(part("CoachStage", (cx, 0.6, 8), (14, 1, 10), (170, 40, 40), "Fabric"))
    # Miroirs de salle et râteliers d'haltères le long du mur du fond
    c.append(part("GymMirror", (cx, 7, z0 + 0.1), (w - 10, 9, 0.2), (200, 225, 240), "Glass",
                  collide=False, extra={"Reflectance": 0.4}))
    for k in range(6):
        c.append(part(f"Rack{k}", (x0 + 8 + k * 9.5, 1.4, z0 + 3), (7, 2.8, 2), (70, 70, 76), "Metal"))
    return model("NeighborhoodGym", c)


# ------------------------------------------------------------------ 5. la place des boss
def plaza():
    c = []
    c.append(part("PlazaFloor", (220, 0.1, -4), (84, 0.2, 72), (205, 190, 180), "Pavement"))
    c.append(part("NoLegsStage", (192, 0.5, 6), (12, 1, 12), (170, 40, 40), "Fabric"))
    c.append(part("KingStage", (216, 0.5, 6), (16, 1, 16), (110, 40, 130), "Fabric"))
    c.append(part("KingCarpet", (216, 0.25, 22), (5, 0.1, 18), (190, 30, 40), "Fabric", collide=False))
    # Temple du Dieu du Pump (statue en attendant son combat)
    c.append(part("TempleBase", (246, 1, -14), (26, 2, 26), (235, 232, 222), "Marble"))
    for i, (dx, dz) in enumerate([(-11, -11), (11, -11), (-11, 11), (11, 11)]):
        c.append(part(f"Column{i}", (246 + dx, 11, -14 + dz), (18, 3, 3), (240, 238, 230), "Marble",
                      roll=90, shape="Cylinder"))
    c.append(part("TempleTop", (246, 20.5, -14), (28, 1.5, 28), (225, 200, 120), "Marble"))
    return model("BossPlaza", c)


# ------------------------------------------------------------------ 6. emplacements de jeu (dalles taguées)
SPOTS = {
    # fichier : (x, y, z, yaw)  — yaw = direction du regard du personnage
    "Stations/CurlStation": (-20, 0.5, -10, 0),
    "Stations/PushUpStation": (-6, 0.5, -12, 0),
    "Stations/BenchPressStation": (118, 0.5, -18, 0),
    "Stations/SquatStation": (132, 0.5, -18, 0),
    "Stations/PullUpStation": (148, 0.5, -18, 0),
    "Stations/JumpRopeStation": (162, 0.5, -18, 0),
    "Bosses/KevinSpot": (16, 0.5, -5, 180),
    "Bosses/BrayanSpot": (16, 0.5, 30, 0),
    "Bosses/CoachTurboSpot": (140, 1.6, 8, 180),
    "Bosses/NoLegsSpot": (192, 1.5, 6, 180),
    "Bosses/BlockKingSpot": (216, 1.5, 6, 180),
    "Bosses/PumpGodSpot": (246, 2.5, -14, 180),
    "Helpers/OpenJarSpot": (-22, 0.5, 10, -90),
    "Helpers/PumpTireSpot": (-20, 0.5, 30, 0),
    "Helpers/PushCarSpot": (32, 1.0, FAR_WALK_Z, 0),
    "Helpers/NailsSpot": (74, 1.0, FAR_WALK_Z, 0),
    "Helpers/PianoSpot": (100, 1.0, FAR_WALK_Z, 0),
    "Helpers/BeachChairsSpot": (180, 1.0, FAR_WALK_Z, 0),
    "Helpers/GroceriesSpot": (150, 1.0, FAR_WALK_Z, 0),
    "Helpers/DirectionsSpot": (215, 1.0, FAR_WALK_Z, 0),
}
SPOT_COLORS = {"Bosses": (140, 40, 40), "Helpers": (90, 150, 100)}


def move_spot(rel, x, y, z, yaw):
    """Déplace une dalle (et ses enfants, en gardant leur position relative) et l'oriente."""
    path = os.path.join(WORLD, rel + ".model.json")
    with open(path, encoding="utf-8") as f:
        node = json.load(f)
    old = node["properties"]["CFrame"]["CFrame"]["position"]
    R = rot(yaw)
    node["properties"]["CFrame"]["CFrame"] = {"position": [x, y, z], "orientation": R}
    folder = rel.split("/")[0]
    if folder in SPOT_COLORS and not rel.endswith("PumpGodSpot"):
        node["properties"]["Color"] = rgb(*SPOT_COLORS[folder])
    for child in node.get("children", []):
        cf = child["properties"]["CFrame"]["CFrame"]
        off = [cf["position"][i] - old[i] for i in range(3)]
        rotated = [sum(R[i][k] * off[k] for k in range(3)) for i in range(3)]
        cf["position"] = [round(x + rotated[0], 3), round(y + rotated[1], 3), round(z + rotated[2], 3)]
        o = cf.get("orientation", [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
        cf["orientation"] = [[round(sum(R[i][k] * o[k][j] for k in range(3)), 6) for j in range(3)] for i in range(3)]
    write(path, node)


def mirror():
    """Miroir de style, au mur du fond du garage, face à l'entrée."""
    node = part("Mirror", (3, 5, -19.6), (6, 9, 0.6), (200, 230, 255), "Glass",
                extra={"Reflectance": 0.6, "Tags": {"Tags": ["Mirror"]}},
                children=[part("Frame", (3, 5, -19.95), (7, 10, 0.4), (230, 180, 40), "SmoothPlastic", collide=False)])
    node.pop("name")
    write(os.path.join(WORLD, "Shop", "Mirror.model.json"), node)


# ------------------------------------------------------------------ écriture
if __name__ == "__main__":
    for name, fn in (("MomsGarage", garage), ("Street", street), ("Houses", houses), ("NeighborhoodGym", gym),
                     ("BossPlaza", plaza)):
        write(os.path.join(WORLD, "Map", f"{name}.model.json"), fn())
    for rel, (x, y, z, yaw) in SPOTS.items():
        move_spot(rel, x, y, z, yaw)
    mirror()
    print("Muscle City générée :", len(SPOTS), "emplacements repositionnés")

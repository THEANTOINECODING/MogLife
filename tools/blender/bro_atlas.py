"""
Texture des « bros » (boss et corps des joueurs) : atlas 256 px peint par cases, éclairage cuit façon PS1.
À charger avec exec après lowpoly_lib.py.
"""
import random

ATLAS_SIZE = 256  # 8 x 8 cases de 32 px


# ------------------------------------------------------------------ texture (éclairage « cuit » façon PS1)
def lit(rgb, y, amt=0.22):
    """Plus clair en haut de chaque pièce, plus sombre en bas : la lumière cuite des jeux PS1."""
    k = 1 - amt + amt * 1.6 * (y / (C - 1))
    return tuple(max(0.0, min(1.0, c * k)) for c in rgb)


# ------------------------------------------------------------------ voiles teintables (corps des joueurs, D55)
# Dans Roblox, un pixel semi-transparent de la texture laisse voir la couleur de la pièce (MeshPart.Color) : la peau,
# les cheveux, les yeux, le haut et le short sont peints comme des voiles d'ombre et de lumière posés sur la couleur
# choisie par le joueur. Une seule texture par corps sert ainsi toutes les teintes.
def veil(k):
    """Voile qui multiplie la couleur de la pièce par environ k (ombre si k < 1, lumière si k > 1)."""
    if k <= 1:
        return (0.0, 0.0, 0.0, max(0.0, min(0.85, 1 - k)))
    return (1.0, 1.0, 1.0, max(0.0, min(0.5, (k - 1) * 1.4)))


def tinge(rgb, a):
    """Voile coloré (joues, veines, lèvres) : se pose sur n'importe quelle teinte."""
    return (rgb[0], rgb[1], rgb[2], a)


def lit_k(y, amt=0.22):
    """Facteur de l'éclairage cuit (même courbe que lit) : plus clair en haut de la pièce."""
    return 1 - amt + amt * 1.6 * (y / (C - 1))


def grain(amt=0.03):
    return 1 + random.uniform(-amt, amt)


def paint_tint_cells(a, cfg):
    """Cases teintables des corps de joueurs, aux mêmes positions que paint_bro_atlas."""
    a.cell("skin", 0, 0, lambda x, y: veil(lit_k(y) * grain()))
    a.cell("shade", 1, 0, lambda x, y: veil(0.8 * lit_k(y) * grain()))

    def chest(x, y):
        k = grain()
        if abs(x - 15.5) < 1.2 and y > 8:
            k *= 0.8
        if 6 <= y <= 9 and 3 < x < 29:
            k *= 0.8
        if cfg.get("veins") and (x * 5 + y * 3) % 29 == 0:
            return tinge((0.35, 0.08, 0.3), 0.35)
        return veil(k * lit_k(y))
    a.cell("chest", 2, 0, chest)

    def abs_(x, y):
        k = grain()
        if abs(x - 15.5) < 1.0 or (y % 8 in (0, 1) and 7 < x < 25):
            k *= 0.8
        return veil(k * lit_k(y, 0.15))
    a.cell("abs", 3, 0, abs_)

    def veiny(x, y):
        if cfg.get("veins") and ((x + y // 3) % 9 == 0 or (2 * x - y) % 15 == 0):
            return tinge((0.35, 0.08, 0.3), 0.35)
        return veil(lit_k(y) * grain())
    a.cell("veiny", 4, 0, veiny)

    def face(x, y):
        if cfg.get("stubble") and y < 13 and random.random() < 0.3:
            return tinge((0.12, 0.08, 0.06), 0.4)
        if 13 <= y <= 17 and (3 <= x <= 8 or 23 <= x <= 28):
            return tinge((0.95, 0.25, 0.3), 0.24 if cfg.get("fem") else 0.14)   # joues roses (plus pour les corps féminins)
        if cfg.get("cleft") and 15 <= x <= 16 and y < 6:
            return veil(0.8)
        return veil(lit_k(y, 0.15) * grain(0.02))
    a.cell("face", 5, 0, face)

    a.cell("top", 6, 0, lambda x, y: veil(lit_k(y) * grain()))

    def top_front(x, y):
        kind = cfg.get("top")
        if kind == "tank" and 30 <= (x - 16) ** 2 + (y - 33) ** 2 < 42:
            return veil(0.72)                              # couture de l'encolure
        if kind == "sports" and y > 26:
            return veil(0.75)                              # bord élastique de la brassière de sport
        return veil(lit_k(y) * grain())
    a.cell("top_front", 7, 0, top_front)

    a.cell("shorts", 0, 1, lambda x, y: veil(lit_k(y) * grain()) if y % 31 > 2 else veil(0.75))
    a.cell("hair", 1, 1, lambda x, y: veil(grain(0.12) * (0.8 if (x * 3 + y) % 7 == 0 else 1.0)))
    a.cell("iris", 3, 1, lambda x, y: veil(0.7) if (x - 15.5) ** 2 + (y - 15.5) ** 2 > 200 else veil(grain(0.05)))
    # Lèvres : plus colorées (rose framboise) pour les corps féminins
    a.cell("lips", 5, 1, lambda x, y: tinge((0.62, 0.06, 0.22), 0.55) if cfg.get("fem") else tinge((0.45, 0.06, 0.1), 0.32))
    a.cell("brow", 4, 2, lambda x, y: veil(0.75 * grain(0.08)))


def paint_bro_atlas(name, cfg):
    random.seed(sum(ord(ch) for ch in name))
    a = Atlas(name, ATLAS_SIZE)
    skin = cfg["skin"]
    shade = darker(skin, 0.8)
    vein = (skin[0] * 0.7, skin[1] * 0.35, skin[2] * 0.45)

    a.cell("skin", 0, 0, lambda x, y: lit(noise(skin, 0.025), y))
    a.cell("shade", 1, 0, lambda x, y: lit(noise(shade, 0.025), y))

    def chest(x, y):                                  # pectoraux : sillon central et ombre douce dessous
        c = noise(skin, 0.025)
        if abs(x - 15.5) < 1.2 and y > 8:
            c = shade
        if 6 <= y <= 9 and 3 < x < 29:
            c = shade
        if cfg.get("veins") and (x * 5 + y * 3) % 29 == 0:
            c = vein
        return lit(c, y)
    a.cell("chest", 2, 0, chest)

    def abs_(x, y):                                   # abdominaux en ombres douces
        c = noise(skin, 0.025)
        if abs(x - 15.5) < 1.0 or (y % 8 in (0, 1) and 7 < x < 25):
            c = shade
        return lit(c, y, 0.15)
    a.cell("abs", 3, 0, abs_)

    def veiny(x, y):                                  # peau veineuse
        c = noise(skin, 0.025)
        if cfg.get("veins") and ((x + y // 3) % 9 == 0 or (2 * x - y) % 15 == 0):
            c = vein
        return lit(c, y)
    a.cell("veiny", 4, 0, veiny)

    def face(x, y):                                   # barbe naissante, joues un peu rouges
        c = noise(skin, 0.025)
        if cfg.get("stubble") and y < 13 and random.random() < 0.3:
            c = darker(skin, 0.62)
        if 13 <= y <= 17 and (3 <= x <= 8 or 23 <= x <= 28):
            c = (min(1, c[0] * 1.08), c[1] * 0.9, c[2] * 0.9)
        if cfg.get("cleft") and 15 <= x <= 16 and y < 6:
            c = shade
        return lit(c, y, 0.15)
    a.cell("face", 5, 0, face)

    top = cfg.get("top_color", (0.2, 0.2, 0.2))
    a.cell("top", 6, 0, lambda x, y: lit(noise(top, 0.025), y))

    def top_front(x, y):
        kind = cfg.get("top")
        if kind == "tank" and (x - 16) ** 2 + (y - 33) ** 2 < 36:
            return lit(noise(skin, 0.025), y)        # encolure ronde
        if kind == "jacket":
            if x in (15, 16):
                return (0.85, 0.85, 0.85)            # fermeture éclair
            if x in (2, 3, 28, 29):
                return lit((0.92, 0.92, 0.92), y)    # bandes de survêtement
        return lit(noise(top, 0.025), y)
    a.cell("top_front", 7, 0, top_front)

    a.cell("shorts", 0, 1, lambda x, y: lit(noise(cfg.get("shorts", (0.15, 0.15, 0.2)), 0.025), y))
    a.cell("hair", 1, 1, lambda x, y: noise(cfg.get("hair", (0.1, 0.07, 0.05)), 0.05))
    a.cell("white", 2, 1, lambda x, y: lit(noise((0.95, 0.93, 0.88), 0.015), y, 0.12))
    a.cell("iris", 3, 1, lambda x, y: noise(cfg.get("iris", (0.35, 0.22, 0.12)), 0.04))
    a.cell("black", 4, 1, lambda x, y: (0.03, 0.03, 0.03))
    lips = darker((skin[0], skin[1] * 0.8, skin[2] * 0.8), 0.72)
    a.cell("lips", 5, 1, lambda x, y: noise(lips, 0.02))
    a.cell("teeth", 6, 1, lambda x, y: (0.6, 0.55, 0.5) if x % 6 == 0 else noise((0.95, 0.94, 0.86), 0.02))
    a.cell("gold", 7, 1, lambda x, y: lit(noise((0.9, 0.7, 0.18), 0.05), y))
    a.cell("accent", 0, 2, lambda x, y: lit(noise(cfg.get("accent", (0.5, 0.1, 0.6)), 0.025), y))
    a.cell("accent2", 1, 2, lambda x, y: lit(noise(cfg.get("accent2", (0.9, 0.9, 0.9)), 0.025), y))
    a.cell("shoe", 2, 2, lambda x, y: lit(noise(cfg.get("shoe", (0.9, 0.9, 0.9)), 0.03), y))
    a.cell("laurel", 3, 2, lambda x, y: noise((0.32, 0.5, 0.15), 0.06) if (x + y) % 4 else (0.85, 0.7, 0.2))
    hair = cfg.get("hair", (0.1, 0.07, 0.05))
    a.cell("brow", 4, 2, lambda x, y: noise(hair, 0.04) if y > 18 else lit(noise(shade, 0.02), y))   # sourcils sur l'arcade
    # Cils (corps féminins) et ombre de paupière : opaques
    a.cell("lash", 5, 2, lambda x, y: (0.05, 0.04, 0.05))
    if cfg.get("tint"):
        paint_tint_cells(a, cfg)
    return a

"""
Réexporte seulement le banc et le rack de squat (sans leur barre, qui est un décor à part et bouge pendant
la série) : assets/export/props/MogLife_GymStations.fbx.
Dans Blender : exec(open(r"...\tools\blender\export_gym_stations.py", encoding="utf-8").read())
Import dans Studio : Accueil -> Importer 3D, puis tools/install_props.luau.
"""
import os

D = r"C:\Users\antoi\Documents\MogLife\tools\blender"
OUT = r"C:\Users\antoi\Documents\MogLife\assets\export\props"

ns = {}
exec(open(os.path.join(D, "props_lib.py"), encoding="utf-8").read(), ns)
exec(open(os.path.join(D, "props_gym.py"), encoding="utf-8").read(), ns)

pal = ns["build_palette"]()
P = ns["Props"](pal, "Props_GymStations", spacing=16, columns=4)
P.clear()
ns["bench_press"](P)
ns["squat_rack"](P)
path = os.path.join(OUT, "MogLife_GymStations.fbx")
print(ns["export_fbx"](["Props_GymStations"], path), "pièces ->", path)
print("\n".join(P.report))

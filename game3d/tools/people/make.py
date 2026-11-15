import bpy, sys, os, json
argv = sys.argv[sys.argv.index("--") + 1:]
name, out = argv[0], argv[1]
from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.objectservice import ObjectService

C = {
 "sailor": dict(ph=dict(gender=1.0, age=0.55, muscle=0.7, weight=0.55, height=0.55, race=dict(asian=0.3, caucasian=0.6, african=0.1)),
   proxy="male_generic/male_generic.proxy", skin="young_caucasian_male/young_caucasian_male.mhmat",
   hair="short02/short02.mhclo", eyebrows="eyebrow001/eyebrow001.mhclo", eyes_mat="brown",
   clothes=["male_casualsuit06/male_casualsuit06.mhclo", "shoes03/shoes03.mhclo"], top=(0.80,0.76,0.66), bottom=(0.24,0.30,0.42), hat=None, hairtint=None),
 "trader": dict(ph=dict(gender=0.0, age=0.6, muscle=0.5, weight=0.65, height=0.57, race=dict(asian=0.6, caucasian=0.35, african=0.05)),
   proxy="female_generic/female_generic.proxy", skin="middleage_asian_female/middleage_asian_female.mhmat",
   hair="braid01/braid01.mhclo", eyebrows="eyebrow010/eyebrow010.mhclo", eyes_mat="brownlight",
   clothes=["female_elegantsuit01/female_elegantsuit01.mhclo", "shoes01/shoes01.mhclo"], top=(0.19,0.28,0.19), bottom=(0.45,0.34,0.22), hat=None, hairtint=None),
 "oldman": dict(ph=dict(gender=1.0, age=1.0, muscle=0.35, weight=0.45, height=0.42, race=dict(asian=0.2, caucasian=0.75, african=0.05)),
   proxy="male_generic/male_generic.proxy", skin="old_caucasian_male/old_caucasian_male.mhmat",
   hair="short04/short04.mhclo", eyebrows="eyebrow002/eyebrow002.mhclo", eyes_mat="grey",
   clothes=["male_casualsuit05/male_casualsuit05.mhclo", "shoes06/shoes06.mhclo", "fedora01/fedora01.mhclo"], top=(0.36,0.28,0.20), bottom=(0.20,0.23,0.19), hat=(0.24,0.19,0.14), hairtint=(0.72,0.71,0.69)),
 "child": dict(ph=dict(gender=0.85, age=0.16, muscle=0.5, weight=0.5, height=0.5, race=dict(asian=0.4, caucasian=0.55, african=0.05)),
   proxy="male_generic/male_generic.proxy", skin="young_caucasian_male/young_caucasian_male.mhmat",
   hair="short01/short01.mhclo", eyebrows="eyebrow001/eyebrow001.mhclo", eyes_mat="blue",
   clothes=["male_casualsuit02/male_casualsuit02.mhclo", "shoes03/shoes03.mhclo"], top=(0.74,0.67,0.52), bottom=(0.42,0.31,0.21), hat=None, hairtint=None),
}[name]

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)

hi = HumanService._create_default_human_info_dict()
ph = hi["phenotype"]; ph.update({k: v for k, v in C["ph"].items() if k != "race"}); ph["race"] = C["ph"]["race"]
hi.update(name=name, rig="game_engine", proxy=C["proxy"], skin_mhmat=C["skin"], skin_material_type="MAKESKIN",
          eyes="low-poly/low-poly.mhclo", eyes_material_type="MAKESKIN", eyebrows=C["eyebrows"],
          eyelashes="eyelashes01/eyelashes01.mhclo", hair=C["hair"], clothes=C["clothes"], clothes_material_type="MAKESKIN")
s = HumanService.get_default_deserialization_settings()
s.update(subdiv_levels=0, load_clothes=True)
basemesh = HumanService.deserialize_from_dict(hi, s)

# eye colour: swap eye texture to the chosen CC0 colour
eyes = ObjectService.find_object_of_type_amongst_nearest_relatives(basemesh, "Eyes")
assets = os.environ["MH_ASSETS"]
if eyes:
    img = bpy.data.images.load(os.path.join(assets, "eyes/materials", C["eyes_mat"] + "_eye.png"))
    for slot in eyes.material_slots:
        for n in slot.material.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "diffuse" in n.label.lower() + n.name.lower() + n.image.name.lower() or (n.type == "TEX_IMAGE" and n.image and "eye" in n.image.name.lower()):
                n.image = img

rig = basemesh.parent
objs = [rig] + [o for o in rig.children if o is not basemesh]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "restyle.py")).read())
# Downscale textures to keep the glb small
for im in bpy.data.images:
    if im.size[0] > 1024:
        im.scale(1024, int(1024 * im.size[1] / im.size[0]))
        im.pack()


CLIP = ("eyebrow", "eyelash", "short", "braid", "bob", "ponytail", "long", "afro")
for o in objs:
    if o.type != "MESH": continue
    for slot in o.material_slots:
        m = slot.material
        if not m or not m.use_nodes: continue
        nt = m.node_tree
        for b in [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"]:
            a = b.inputs["Alpha"]
            src = a.links[0].from_socket if a.links else None
            for l in list(a.links): nt.links.remove(l)
            if src is not None and any(k in m.name.lower() for k in CLIP):
                r = nt.nodes.new("ShaderNodeMath"); r.operation = "ROUND"
                nt.links.new(src, r.inputs[0]); nt.links.new(r.outputs[0], a)
                m.blend_method = "CLIP"
            else:
                a.default_value = 1.0
                m.blend_method = "OPAQUE"

bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.hide_set(False); o.select_set(True)
bpy.context.view_layer.objects.active = rig

# stats
dg = bpy.context.evaluated_depsgraph_get()
tris = 0
zmin, zmax = 1e9, -1e9
for o in objs:
    if o.type != "MESH": continue
    e = o.evaluated_get(dg); m = e.to_mesh(); m.calc_loop_triangles()
    tris += len(m.loop_triangles)
    for v in m.vertices:
        z = (e.matrix_world @ v.co).z; zmin = min(zmin, z); zmax = max(zmax, z)
    e.to_mesh_clear()

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_yup=True,
    export_apply=True, export_skins=True, export_animations=False, export_morph=False,
    export_image_format="JPEG", export_jpeg_quality=85)
print("STATS", json.dumps(dict(name=name, tris=tris, height_m=round(zmax - zmin, 3),
      objects=[o.name for o in objs], bones=len(rig.data.bones))))

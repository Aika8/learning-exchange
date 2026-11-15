# executed inside make.py: has C, rig, basemesh, objs, name
import numpy as np, math
from mathutils import Vector, Matrix

def img_np(im):
    a = np.empty(im.size[0]*im.size[1]*4, dtype=np.float32); im.pixels.foreach_get(a); return a.reshape(-1, 4)

def tinted(src, col, tag, flatten=0.7, gain=1.0):
    a = img_np(src); lum = a[:, :3] @ np.array([0.299, 0.587, 0.114], np.float32)
    m = lum[a[:, 3] > 0.1].mean() if (a[:, 3] > 0.1).any() else lum.mean()
    l = flatten*m + (1-flatten)*lum            # compress contrast: kills logos/stripes, keeps folds
    f = (l / max(m, 1e-3)) * gain
    out = a.copy(); out[:, :3] = np.clip(np.array(col, np.float32)[None, :] * f[:, None], 0, 1)
    # subtle cloth grain so flat colour reads painterly
    rng = np.random.default_rng(7); out[:, :3] *= (1 + rng.normal(0, 0.025, (len(out), 1))).astype(np.float32)
    im = bpy.data.images.new(src.name + "_" + tag, src.size[0], src.size[1], alpha=True)
    im.pixels.foreach_set(np.clip(out, 0, 1).ravel()); im.pack(); return im

def diffuse_node(m):
    c = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and not any(k in n.image.name.lower() for k in ("normal", "bump", "_nm"))]
    c = [n for n in c if not any(l.to_node.type == "NORMAL_MAP" for l in n.outputs["Color"].links)] or c
    return c[0] if c else None

def retint_material(m, col, tag, **kw):
    m2 = m.copy(); m2.name = m.name + "." + tag
    n = diffuse_node(m2)
    if n: n.image = tinted(n.image, col, tag, **kw)
    return m2

pelvis = rig.pose.bones.get("pelvis"); 
waist_z = (rig.matrix_world @ rig.data.bones["thigh_l"].head_local).z + (0.07 if name == "trader" else -0.07 if name != "child" else -0.05)
LEATHER = (0.24, 0.16, 0.10)
for o in objs:
    if o.type != "MESH" or not o.material_slots: continue
    lname = o.name.lower()
    base = o.material_slots[0].material
    if any(k in lname for k in ("casualsuit", "elegantsuit", "worksuit")):
        mt = retint_material(base, C["top"], "top", flatten=0.9); mb = retint_material(base, C["bottom"], "bot", flatten=0.85)
        o.data.materials.clear(); o.data.materials.append(mt); o.data.materials.append(mb)
        mw = o.matrix_world
        for poly in o.data.polygons:
            z = (mw @ poly.center).z
            poly.material_index = 1 if z < waist_z else 0
    elif "shoes" in lname:
        o.material_slots[0].material = retint_material(base, LEATHER, "lea", flatten=0.4)
    elif "fedora" in lname and C["hat"]:
        o.material_slots[0].material = retint_material(base, C["hat"], "felt", flatten=0.5)
    elif C["hairtint"] and any(k in lname for k in ("short", "eyebrow")):
        o.material_slots[0].material = retint_material(base, C["hairtint"], "grey", flatten=0.2)

# ---- pose: relaxed stand ----
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")
def aim(bname, target):
    pb = rig.pose.bones[bname]; bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix
    head = M.translation.copy(); d = (M.to_3x3() @ Vector((0, 1, 0))).normalized()
    R = d.rotation_difference(Vector(target).normalized()).to_matrix().to_4x4()
    pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ M)
    bpy.context.view_layer.update()
def bend(bname, deg, axis="X"):
    pb = rig.pose.bones[bname]; bpy.context.view_layer.update()
    M = rig.matrix_world @ pb.matrix; head = M.translation.copy()
    R = Matrix.Rotation(math.radians(deg), 4, axis)
    pb.matrix = rig.matrix_world.inverted() @ (Matrix.Translation(head) @ R @ Matrix.Translation(-head) @ M)
    bpy.context.view_layer.update()

old = name == "oldman"
if old:
    for b, a in (("spine_01", 4), ("spine_02", 6), ("spine_03", 6), ("neck_01", -4), ("head", -6)):
        if b in rig.pose.bones: bend(b, a)
# figure faces -Y; +X is character's left side? sign from bone position
for side, s_out, s_fwd, el in (("l", 0.20, -0.04, -0.18), ("r", 0.15, 0.02, -0.10)):
    sx = 1 if rig.data.bones["upperarm_" + side].head_local.x > 0 else -1
    aim("upperarm_" + side, (sx * s_out, s_fwd - (0.12 if old else 0), -1))
    aim("lowerarm_" + side, (sx * 0.07, el - (0.15 if old else 0), -1))
    aim("hand_" + side, (sx * 0.02, el * 0.6, -1))
bend("head", 2.5, "Y") if "head" in rig.pose.bones else None
bpy.ops.object.mode_set(mode="OBJECT")

# apply pose to meshes, then pose as rest; keep the armature modifier
for o in objs:
    if o.type != "MESH": continue
    if o.data.shape_keys:
        o.shape_key_clear()
    bpy.context.view_layer.objects.active = o
    am = [m for m in o.modifiers if m.type == "ARMATURE"]
    for m in am:
        nm, obj = m.name, m.object
        bpy.ops.object.modifier_apply(modifier=nm)
        nmod = o.modifiers.new(nm, "ARMATURE"); nmod.object = obj
        # move armature modifier to front
        while o.modifiers.find(nm) > 0: bpy.ops.object.modifier_move_up(modifier=nm)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE"); bpy.ops.pose.select_all(action="SELECT")
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode="OBJECT")
